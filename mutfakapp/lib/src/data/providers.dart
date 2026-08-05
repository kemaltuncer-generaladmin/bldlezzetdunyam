/// Riverpod bağlantı noktaları.
///
/// Ekran kodu somut sınıf bilmez: [orderSourceProvider] bugün
/// `PollingOrderSource`, Faz 1.5'te `WebSocketOrderSource` döndürecek ve
/// arayüzde tek satır değişmeyecek (ADR-05).
library;

import 'dart:async';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/escpos.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../kds/board.dart';
import '../kds/board_selection.dart';
import '../kds/order_filter.dart';
import '../kds/order_progress.dart';
import '../kds/shift_stats.dart';
import '../kds/urgency.dart';
import '../printing/print_queue.dart';
import '../printing/print_service.dart';
import '../printing/print_triggers.dart';
import '../printing/printer_device.dart';
import '../settings/kds_settings.dart';
import '../settings/kds_settings_store.dart';
import '../sound/alarm_asset.dart';
import '../sound/alarm_player.dart';
import '../sound/connection_alarm.dart';
import '../sound/new_order_alarm.dart';
import 'device_session.dart';
import 'kitchen_health.dart';
import 'polling_order_source.dart';
import 'printer_probe.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

// ─────────────────────────── Ayarlar (docs/05 §8) ───────────────────────────

/// Derleme zamanı değerlerinden türeyen ayar varsayılanları.
///
/// Kayıtlı ayar yoksa `--dart-define` ile verilen değer geçerlidir; personel
/// bir ayarı değiştirdiği anda kayıt derlemeyi ezer. `main` de açılışta
/// diskten okurken bunu taban alır — iki yerde iki farklı varsayılan olmasın.
KdsSettings defaultKdsSettings(AppConfig config) => KdsSettings(
  soundEnabled: true,
  pollSeconds: config.pollInterval.inSeconds,
  printerDevicePath: config.printerDevicePath,
  warningAfterMinutes: UrgencyThresholds.standard.warningAfter.inMinutes,
  lateAfterMinutes: UrgencyThresholds.standard.lateAfter.inMinutes,
);

final kdsSettingsStoreProvider = Provider<KdsSettingsStore>(
  (ref) => KdsSettingsStore(),
);

/// `main` diskten okunan ayarlarla geçersiz kılar; testler kendi değerini
/// verir. [deviceSessionProvider] ile aynı desen: asenkron okuma açılışta bir
/// kez yapılır, sağlayıcılar senkron kalır.
final initialKdsSettingsProvider = Provider<KdsSettings>(
  (ref) => defaultKdsSettings(ref.watch(appConfigProvider)),
);

final kdsSettingsProvider =
    NotifierProvider<KdsSettingsController, KdsSettings>(
      KdsSettingsController.new,
    );

/// Ayar değişikliklerini duruma yazar ve diske kaydeder.
class KdsSettingsController extends Notifier<KdsSettings> {
  @override
  KdsSettings build() => ref.watch(initialKdsSettingsProvider);

  /// Değeri doğrular, uygular ve kalıcılaştırır.
  ///
  /// Durum diske yazılmadan ÖNCE güncellenir: mutfak personeli düğmeye
  /// bastığında arayüzün diski beklemesi gereksiz gecikme olurdu ve yazma
  /// başarısız olsa bile bu oturumda ayar geçerlidir.
  Future<void> update(KdsSettings next) async {
    final sanitized = next.sanitized(
      fallback: ref.read(initialKdsSettingsProvider),
    );
    if (sanitized == state) return;

    state = sanitized;
    await ref.read(kdsSettingsStoreProvider).write(sanitized);
  }
}

/// Aciliyet eşikleri — ayarlardan türer.
final urgencyThresholdsProvider = Provider<UrgencyThresholds>((ref) {
  final settings = ref.watch(kdsSettingsProvider);
  return UrgencyThresholds(
    warningAfter: settings.warningAfter,
    lateAfter: settings.lateAfter,
  );
});

/// Panonun "şu an"ı.
///
/// Tek bir tik kaynağı olması bilinçli: 40 kartın her biri kendi
/// zamanlayıcısını kurarsa mutfak kasası saniyede 40 kez yeniden çizer.
/// Beş saniye, dakika çözünürlüğündeki bir sayaç için fazlasıyla yeterlidir.
final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now().toUtc();
  yield* Stream<void>.periodic(
    const Duration(seconds: 5),
  ).map((_) => DateTime.now().toUtc());
});

/// Zamanı okumanın kısa yolu; akış henüz değer üretmediyse gerçek saate düşer.
DateTime _now(Ref ref) =>
    ref.watch(clockProvider).value ?? DateTime.now().toUtc();

// ─────────────────────────── Yeni sipariş alarmı ───────────────────────────

/// Alarm sesini çalan oynatıcı. Ayardaki ses şalteri burada uygulanır.
///
/// Ses kapalıyken [SilentAlarmPlayer] döner ve `isMuted` doğru olur; arayüz
/// bunu görünür kılar — sessiz bir alarm, alarm olmadığını bilmemekten iyidir.
final alarmPlayerProvider = Provider<AlarmPlayer>((ref) {
  final enabled = ref.watch(
    kdsSettingsProvider.select((settings) => settings.soundEnabled),
  );

  final player = enabled
      ? ProcessAlarmPlayer(materialize: copyAlarmAssetToTempFile)
      : SilentAlarmPlayer();

  // Şalter kapatılırsa bu sağlayıcı yeniden kurulur ve ESKİ oynatıcı elden
  // çıkarılır. Durdurulmazsa süreç arkada çalmaya devam eder ve "sesi
  // kapattım ama susmuyor" olur.
  ref.onDispose(() => player.stop().ignore());
  return player;
});

/// Bağlantı uyarısının oynatıcısı.
///
/// Yeni sipariş alarmından AYRI bir oynatıcı: ikisi aynı anda çalabilir
/// (bağlantı koptu ve ekranda hâlâ onaylanmamış sipariş var) ve tek
/// oynatıcıyı paylaşsalardı biri diğerinin sesini keserdi.
final connectionAlarmPlayerProvider = Provider<AlarmPlayer>((ref) {
  final enabled = ref.watch(
    kdsSettingsProvider.select((settings) => settings.soundEnabled),
  );

  final player = enabled
      ? ProcessAlarmPlayer(
          assetPath: connectionAlarmAssetPath,
          materialize: copyAlarmAssetToTempFile,
        )
      : SilentAlarmPlayer();

  ref.onDispose(() => player.stop().ignore());
  return player;
});

/// Bağlantı kopma uyarısı.
final connectionAlarmProvider =
    NotifierProvider<ConnectionAlarmController, ConnectionAlarmState>(
      ConnectionAlarmController.new,
    );

/// Bağlantı durumunu [ConnectionAlarm]'a bağlar.
///
/// Karar mantığı burada DEĞİL; aralık, susturma ve tekrar kuralları
/// `ConnectionAlarm` içinde ve testleri oradadır.
class ConnectionAlarmController extends Notifier<ConnectionAlarmState> {
  ConnectionAlarm? _alarm;

  @override
  ConnectionAlarmState build() {
    final alarm = ConnectionAlarm(ref.watch(connectionAlarmPlayerProvider));
    _alarm = alarm;
    ref.onDispose(() {
      _alarm = null;
      alarm.dispose();
    });

    var initial = alarm.state;
    var built = false;

    ref.listen<AsyncValue<OrderSourceConnection>>(connectionProvider, (
      _,
      next,
    ) {
      final durum = next.value;
      if (durum == null) return;

      // `connecting` KOPUK SAYILMAZ. İlk açılışta ve her yeniden denemede
      // kısa süre bu durumdan geçiliyor; uyarı çalsaydı her açılış bir
      // alarmla başlardı.
      //
      // `revoked` de sayılmaz: o bir ağ sorunu değil, yönetici kararı.
      // Uygulama zaten eşleme ekranına dönüyor ve orada ne olduğu yazıyor.
      final kopuk = durum == OrderSourceConnection.disconnected;
      final sonraki = alarm.onConnectionChanged(disconnected: kopuk);

      if (built) {
        state = sonraki;
      } else {
        initial = sonraki;
      }
    }, fireImmediately: true);

    built = true;
    return initial;
  }

  /// "Sesi sustur" düğmesi.
  void silence() {
    final alarm = _alarm;
    if (alarm == null) return;
    state = alarm.silence();
  }

  /// Oynatıcının sessizlik durumunu yeniden okur.
  void refresh() {
    final alarm = _alarm;
    if (alarm == null) return;
    state = alarm.refresh();
  }
}

/// Alarmın durumu ve onu susturmanın tek yolu.
final newOrderAlarmProvider =
    NotifierProvider<NewOrderAlarmController, NewOrderAlarmState>(
      NewOrderAlarmController.new,
    );

/// Sipariş listesini [NewOrderAlarm]'a bağlar.
///
/// Karar mantığı burada DEĞİL: hangi durumda çalınacağı saf [NewOrderAlarmPolicy]
/// sınıfındadır ve testleri oradadır. Bu sınıf yalnızca kabloları çeker.
class NewOrderAlarmController extends Notifier<NewOrderAlarmState> {
  NewOrderAlarm? _alarm;

  @override
  NewOrderAlarmState build() {
    final alarm = NewOrderAlarm(ref.watch(alarmPlayerProvider));
    _alarm = alarm;
    ref.onDispose(() {
      _alarm = null;
      alarm.dispose().ignore();
    });

    // `build` bitmeden `state` atanamaz; ilk yayın bu yüzden yerel değişkene
    // düşer ve dönüş değeri olur.
    var initial = alarm.state;
    var built = false;
    void publish(NewOrderAlarmState next) {
      if (built) {
        state = next;
      } else {
        initial = next;
      }
    }

    ref.listen<AsyncValue<List<KitchenOrder>>>(kitchenOrdersProvider, (
      _,
      next,
    ) {
      final orders = next.value;
      if (orders != null) publish(alarm.onOrders(orders));
    }, fireImmediately: true);

    // Oynatıcı "ses çıkmıyor" kararını `start()` döndükten sonra veriyor;
    // pano saati bunu birkaç saniye içinde yakalar ve arayüz bildirir.
    ref.listen<AsyncValue<DateTime>>(
      clockProvider,
      (_, _) => publish(alarm.refresh()),
    );

    built = true;
    return initial;
  }

  /// "Sesi sustur" düğmesi — yalnızca o anki alarmı susturur.
  void silence() {
    final alarm = _alarm;
    if (alarm != null) state = alarm.silence();
  }
}

/// Arama kutusundaki metin. Yalnızca çizimi daraltır, veriyi değil.
final searchQueryProvider = NotifierProvider<SearchQuery, String>(
  SearchQuery.new,
);

/// Arama alanının odak düğümü.
///
/// Sağlayıcıda durmasının tek sebebi `F2` kısayolu: kısayolları kuran ekran
/// ile alanı çizen üst çubuk farklı ağaçlarda ve aralarında `GlobalKey`
/// dolaştırmak, sahibi belirsiz bir düğüm bırakırdı. Elden çıkarma burada.
final searchFocusProvider = Provider<FocusNode>((ref) {
  final node = FocusNode(debugLabel: 'kds-search');
  ref.onDispose(node.dispose);
  return node;
});

class SearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;

  void clear() => state = '';
}

/// `main` bunları gerçek örneklerle geçersiz kılar; testler kendi sahtesini
/// verir. Diskten okuma asenkron olduğu için açılışta bir kez yapılır ve
/// buraya enjekte edilir — sağlayıcılar senkron kalır.
final deviceSessionStoreProvider = Provider<DeviceSessionStore>(
  (ref) => DeviceSessionStore(),
);

final initialDeviceSessionProvider = Provider<DeviceSession>(
  (ref) => DeviceSession(baseUrl: ref.watch(appConfigProvider).baseUrl),
);

/// Cihazın hangi sunucuya, hangi token'la bağlı olduğu.
final deviceSessionProvider =
    NotifierProvider<DeviceSessionController, DeviceSession>(
      DeviceSessionController.new,
    );

/// Eşleme, eşlemeyi bozma ve adres değişikliği tek yerden geçer.
class DeviceSessionController extends Notifier<DeviceSession> {
  @override
  DeviceSession build() => ref.watch(initialDeviceSessionProvider);

  /// Eşleme kodunu token'a çevirir (`docs/05-mutfakapp.md` §7 adım 3).
  ///
  /// Adres önce kaydedilir ve duruma yazılır; [bldApiProvider] bu durumu
  /// izlediği için sonraki okumada **yeni adrese** kurulmuş bir istemci gelir.
  Future<void> pair({
    required String baseUrl,
    required String pairingCode,
    required String deviceName,
  }) async {
    final store = ref.read(deviceSessionStoreProvider);
    await store.writeBaseUrl(baseUrl);
    state = DeviceSession(baseUrl: baseUrl);

    final response = await ref
        .read(kitchenServiceProvider)
        .pair(PairRequest(pairingCode: pairingCode, deviceName: deviceName));

    // `BldApi.kitchen.pair` token'ı kendi deposuna zaten yazar; burada
    // açıkça yazmak bu yan etkiye bağımlılığı kaldırır — kaydın olduğundan
    // emin olmadan durumu "eşlendi"ye çevirmeyiz.
    await store.tokens.write(response.token);
    state = DeviceSession(baseUrl: baseUrl, token: response.token);
  }

  /// Ayarlar ekranından sunucu adresini değiştirir.
  ///
  /// Eşlemeyi **birlikte** bozar: token bir sunucuya aittir, adres değişince
  /// geçersizdir. İkisini ayrı işlemler yapmak, yanlış sunucuya geçerli
  /// görünen bir token'la bağlanma denemesi demek olurdu — ve o deneme
  /// `401` verip sessizce eşleme ekranına düşerdi, personel sebebini
  /// anlamadan.
  ///
  /// `docs/05` §7'deki tuzağın da çözümü budur: kayıtlı adres derlemeyi ezer,
  /// bu yüzden onu değiştirmenin bir yolu olmak zorunda.
  Future<void> changeBaseUrl(String baseUrl) async {
    final store = ref.read(deviceSessionStoreProvider);
    await store.writeBaseUrl(baseUrl);
    await store.clearToken();
    state = DeviceSession(baseUrl: baseUrl);
  }

  /// Token iptal edildi (`403 DEVICE_REVOKED`) ya da personel sıfırladı.
  Future<void> clearToken() async {
    if (!state.isPaired) return;
    await ref.read(deviceSessionStoreProvider).clearToken();
    state = DeviceSession(baseUrl: state.baseUrl);
  }
}

final bldApiProvider = Provider<BldApi>((ref) {
  final session = ref.watch(deviceSessionProvider);
  final api = BldApi(
    config: BldApiConfig(
      baseUrl: session.baseUrl,
      appId: AppConfig.appId,
      appVersion: AppConfig.appVersion,
    ),
    tokenStore: ref.watch(deviceSessionStoreProvider).tokens,
  );
  ref.onDispose(api.close);
  return api;
});

final kitchenServiceProvider = Provider<KitchenService>(
  (ref) => ref.watch(bldApiProvider).kitchen,
);

final orderSourceProvider = Provider<OrderSource>((ref) {
  final source = PollingOrderSource(
    kitchen: ref.watch(kitchenServiceProvider),
    interval: Duration(seconds: ref.read(kdsSettingsProvider).pollSeconds),
  )..start();

  // ARALIK DEĞİŞİNCE KAYNAK YENİDEN KURULMAZ. `watch` kullansaydık ayarlar
  // ekranındaki artı düğmesine her basış kaynağı kapatıp yenisini açardı;
  // yeni kaynağın anlık görüntüsü boş olduğu için pano ilk yanıt gelene kadar
  // bomboş kalırdı. Bir ayarı kurcalamak ekrandaki siparişleri silmemeli.
  ref.listen<int>(
    kdsSettingsProvider.select((settings) => settings.pollSeconds),
    (_, seconds) => source.interval = Duration(seconds: seconds),
  );

  ref.onDispose(() => unawaited(source.dispose()));
  return source;
});

/// Ekranda çizilecek tam liste. Her yayın diff değil, listenin tamamıdır.
final kitchenOrdersProvider = StreamProvider<List<KitchenOrder>>(
  (ref) => ref.watch(orderSourceProvider).watch(),
);

final connectionProvider = StreamProvider<OrderSourceConnection>(
  (ref) => ref.watch(orderSourceProvider).connection,
);

/// İlk liste hâlâ bekleniyor mu?
///
/// Ayrı bir durum olması şart: veri gelmeden önce boş listeyi çizmek ekrana
/// "Bekleyen sipariş yok" yazdırıyordu. Mutfak sabah bu yazıyı görüp sakin bir
/// gün sanabilir — oysa henüz hiçbir şey sorulmamıştır.
final boardLoadingProvider = Provider<bool>(
  (ref) => !ref.watch(kitchenOrdersProvider).hasValue,
);

/// Listenin en son ne zaman tazelendiği (UTC); hiç tazelenmediyse `null`.
///
/// Pano saatine bağlıdır: bağlantı koptuğunda ekrandaki listenin yaşı saniye
/// saniye büyümeli ki personel ona ne kadar güvenebileceğini bilsin.
final lastUpdatedAtProvider = Provider<DateTime?>((ref) {
  ref
    ..watch(clockProvider)
    ..watch(kitchenOrdersProvider);

  final Object source = ref.watch(orderSourceProvider);
  if (source is! TimestampedOrderSource) return null;
  return source.lastUpdatedAt;
});

final printerStatusProvider = StreamProvider<PrinterAvailability>(
  (ref) => PrinterProbe(
    ref.watch(
      kdsSettingsProvider.select((settings) => settings.printerDevicePath),
    ),
  ).watch(),
);

// ──────────────────────── Sağlık göstergesi (kitchen/health) ────────────────────────

/// `POST /kitchen/health` istemcisi.
///
/// `packages/api_client`'ta değil çünkü uç sözleşmeye yeni eklendi ve o paket
/// bu görevin kapsamı dışında (bkz. `kitchen_health.dart` başlığı).
final kitchenHealthApiProvider = Provider<KitchenHealthApi>((ref) {
  final session = ref.watch(deviceSessionProvider);
  final store = ref.watch(deviceSessionStoreProvider);

  final api = HttpKitchenHealthApi(
    baseUrl: session.baseUrl,
    appId: AppConfig.appId,
    appVersion: AppConfig.appVersion,
    readToken: store.tokens.read,
  );
  ref.onDispose(api.close);
  return api;
});

/// Sağlık bildiriminin sıklığı.
///
/// Yoklama aralığından **bağımsız**: personel yoklamayı 2 saniyeye
/// indirdiğinde sunucuya dakikada 30 sağlık isteği gitmemeli. Dakikada bir,
/// "bugün kaç sipariş" sayacı için fazlasıyla taze.
const Duration kitchenHealthInterval = Duration(minutes: 1);

final kitchenHealthProvider =
    NotifierProvider<KitchenHealthController, KitchenHealthState>(
      KitchenHealthController.new,
    );

/// Sağlık bildirimini düzenli gönderir ve sonucu tutar.
class KitchenHealthController extends Notifier<KitchenHealthState> {
  KitchenHealthMonitor? _monitor;

  @override
  KitchenHealthState build() {
    final monitor = KitchenHealthMonitor(
      api: ref.watch(kitchenHealthApiProvider),
      collect: _collect,
    );
    _monitor = monitor;

    // Yoklama aralığından BAĞIMSIZ kendi zamanlayıcısı var: personel yoklamayı
    // 2 saniyeye indirdiğinde sunucuya dakikada 30 sağlık isteği gitmemeli.
    final timer = Timer.periodic(
      kitchenHealthInterval,
      (_) => unawaited(poll()),
    );
    ref.onDispose(() {
      timer.cancel();
      _monitor = null;
    });

    // İlk bildirim beklenmez: `build` senkron kalmalı ve mutfak ekranı bir ağ
    // çağrısı için gecikmemeli.
    unawaited(poll());

    return monitor.state;
  }

  /// Bir bildirim gönderir. Hata yutulur; gösterge kendisi haber verir.
  Future<void> poll() async {
    final monitor = _monitor;
    if (monitor == null) return;

    final next = await monitor.poll();
    if (ref.mounted) state = next;
  }

  /// Bildirilen değerler GERÇEKTİR: yazıcı yoklamasından ve diskteki kuyruktan
  /// okunur. Sabit `true` göndermek göstergeyi yalancı yapardı.
  ///
  /// YAZICI DOĞRUDAN YOKLANIR, `printerStatusProvider` ÖNBELLEĞİNDEN
  /// OKUNMAZ. O bir akış sağlayıcısı ve ilk sağlık bildirimi açılışta,
  /// akış daha hiçbir şey yaymadan gönderiliyor; `.value` `null` oluyor,
  /// `null == ready` yanlış çıkıyor ve sunucuya "yazıcı arızalı"
  /// bildiriliyordu. Sahada tam olarak bu görüldü: yazıcı takılı, fişler
  /// basılıyor, gösterge "yok" diyor.
  Future<KitchenHealthReport> _collect() async {
    final probe = PrinterProbe(ref.read(kdsSettingsProvider).printerDevicePath);
    final service = ref.read(printServiceProvider);

    return KitchenHealthReport(
      printerOk: await probe.check() == PrinterAvailability.ready,
      printQueuePending: ref.read(printQueueProvider).pendingCount(),
      printQueueFailed: service.failedCount(),
      appVersion: AppConfig.appVersion,
    );
  }
}

// ────────────────────────── Yazdırma (K-04, K-06) ──────────────────────────

/// Diskteki kuyruk. `main` gerçek dosya yoluyla geçersiz kılar; varsayılan
/// bellek içi olması testlerin yanlışlıkla diske yazmasını önler.
final printQueueProvider = Provider<PrintQueue>((ref) {
  final queue = PrintQueue.inMemory();
  ref.onDispose(queue.close);
  return queue;
});

final printerDeviceProvider = Provider<PrinterDevice>(
  (ref) => UsbPrinterDevice(
    ref.watch(
      kdsSettingsProvider.select((settings) => settings.printerDevicePath),
    ),
  ),
);

final printServiceProvider = Provider<PrintService>((ref) {
  final config = ref.watch(appConfigProvider);
  final service = PrintService(
    queue: ref.watch(printQueueProvider),
    device: ref.watch(printerDeviceProvider),
    kitchen: ref.watch(kitchenServiceProvider),
    style: ReceiptStyle(codePage: config.printerCodePage),
  )..start();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

/// Bekleyen yazdırma işi sayısı — durum çubuğundaki "Kuyruk: n".
final printQueueCountProvider = StreamProvider<int>(
  (ref) => ref.watch(printServiceProvider).pendingCount,
);

/// Bekleyen ama en az bir kez hata almış iş sayısı.
///
/// Kendi akışı yok: deneme sayacı artınca kuyruk uzunluğu **değişmez**, bu
/// yüzden `pendingCount` akışına yaslanmak yetmez. Pano saatine bağlanıp beş
/// saniyede bir tek bir `COUNT` sorgusu atmak, ayrı bir bildirim mekanizması
/// kurmaktan hem ucuz hem sağlam.
final printQueueFailedCountProvider = Provider<int>((ref) {
  ref
    ..watch(clockProvider)
    ..watch(printQueueCountProvider);
  return ref.watch(printServiceProvider).failedCount();
});

/// Sipariş listesindeki olayları otomatik olarak fişe çevirir (`docs/05` §5.5).
///
/// Dinleyicisi olmayan bir sağlayıcı hiç kurulmaz; bu yüzden ekran kökü bunu
/// açıkça izler.
final printTriggersProvider = NotifierProvider<PrintTriggerRunner, int>(
  PrintTriggerRunner.new,
);

/// Kuyruğa eklenen toplam iş sayısını tutar.
///
/// Durum değerinin kendisi arayüzde kullanılmaz; tetiklerin çalıştığını
/// gözlenebilir kılar ve testte doğrulanmasını sağlar.
class PrintTriggerRunner extends Notifier<int> {
  final PrintTriggers _triggers = PrintTriggers();

  @override
  int build() {
    ref.listen<AsyncValue<List<KitchenOrder>>>(kitchenOrdersProvider, (
      _,
      next,
    ) {
      final orders = next.value;
      if (orders != null) _dispatch(orders);
    }, fireImmediately: true);

    return 0;
  }

  void _dispatch(List<KitchenOrder> orders) {
    final service = ref.read(printServiceProvider);
    var queued = 0;
    for (final job in _triggers.jobsFor(orders)) {
      if (service.enqueue(job.orderId, job.type)) queued++;
    }
    if (queued > 0) state = state + queued;
  }
}

// ────────────────────────────────── Pano ──────────────────────────────────

/// Sunucudan gelen, filtrelenmemiş aktif sipariş listesi.
///
/// Sayaçlar ve üretim listesi bunu kullanır: arama kutusuna bir şey yazmak
/// mutfağın toplam yükünü değiştirmez.
final activeOrdersProvider = Provider<List<KitchenOrder>>(
  (ref) => ref.watch(kitchenOrdersProvider).value ?? const <KitchenOrder>[],
);

/// Ekranda çizilecek sütunlar: filtrelenmiş ve aciliyete göre sıralanmış.
final boardProvider = Provider<Map<KdsColumn, List<KitchenOrder>>>((ref) {
  final visible = filterOrders(
    ref.watch(activeOrdersProvider),
    ref.watch(searchQueryProvider),
  );
  final now = _now(ref);
  final thresholds = ref.watch(urgencyThresholdsProvider);

  return {
    for (final entry in groupIntoColumns(visible).entries)
      entry.key: sortByUrgency(entry.value, now: now, thresholds: thresholds),
  };
});

/// Filtreden geçen kart sayısı — "3/12 sipariş" göstergesi için.
final visibleOrderCountProvider = Provider<int>((ref) {
  final board = ref.watch(boardProvider);
  return board.values.fold(0, (sum, orders) => sum + orders.length);
});

/// Geciken sipariş sayısı. **Filtreden bağımsızdır**: arama yaparken gecikmeyi
/// gözden kaçırmak, aramanın en pahalı yan etkisi olurdu.
final lateOrderCountProvider = Provider<int>(
  (ref) => lateOrderCount(
    ref.watch(activeOrdersProvider),
    now: _now(ref),
    thresholds: ref.watch(urgencyThresholdsProvider),
  ),
);

final productionTotalsProvider = Provider<List<ProductionTotal>>(
  (ref) => productionTotals(ref.watch(activeOrdersProvider)),
);

// ──────────────────────── Durum ilerletme (tek yön) ────────────────────────

/// Bir ileri adım denemesinin sonucu.
enum OrderAdvanceResult {
  /// Sunucu kabul etti.
  ok,

  /// Yapacak bir şey yoktu: sipariş kayboldu, terminal durumdaydı ya da aynı
  /// sipariş için bir istek zaten uçuyordu (çift dokunma).
  ignored,

  /// Sunucu `INVALID_TRANSITION` dedi — sipariş başka bir yerden ilerletilmiş.
  conflict,

  /// Ağ ya da sunucu hatası; [OrderAdvanceOutcome.message] personele gösterilir.
  failed,
}

class OrderAdvanceOutcome {
  const OrderAdvanceOutcome(this.result, [this.message]);

  final OrderAdvanceResult result;
  final String? message;
}

/// Şu an sunucuya isteği uçan sipariş kimlikleri.
///
/// Arayüz bunu izler ve o kartın düğmesini kilitler.
final orderActionProvider = NotifierProvider<OrderActionController, Set<int>>(
  OrderActionController.new,
);

/// Personelin bastığı ileri adımı sunucuya iletir.
///
/// Kararı sunucu verir; istemcideki geçiş matrisi yalnızca geçersiz butonu
/// göstermemek içindir (`bld_core/order_status.dart`).
class OrderActionController extends Notifier<Set<int>> {
  @override
  Set<int> build() => const <int>{};

  bool isBusy(int orderId) => state.contains(orderId);

  /// [orderId]'yi bir sonraki duruma taşır.
  ///
  /// ÇİFT DOKUNMA KORUMASI. Yağlı elle basılan 64 piksellik bir düğme kolayca
  /// iki kez tetiklenir. İkinci istek ya `422 INVALID_TRANSITION` ile döner
  /// (personel sebepsiz bir kırmızı uyarı görür) ya da — liste arada
  /// tazelenmişse — siparişi **bir adım fazla** ilerletir: "HAZIR"a basmak
  /// istenirken sipariş "YOLDA" olur. Uçan istek varken ikincisi yutulur.
  Future<OrderAdvanceOutcome> advance(int orderId) async {
    if (state.contains(orderId)) {
      return const OrderAdvanceOutcome(OrderAdvanceResult.ignored);
    }

    // KART BAYAT OLABİLİR. Kart çizildiği andaki siparişi taşır; parmak inene
    // kadar yoklama onu güncellemiş olabilir. Hedef durumu en güncel listeden
    // hesaplıyoruz, widget'ın elindeki kopyadan değil.
    final order = _currentOrder(orderId);
    final next = order?.nextStatus;
    if (order == null || next == null) {
      return const OrderAdvanceOutcome(OrderAdvanceResult.ignored);
    }

    state = {...state, orderId};
    try {
      await ref.read(kitchenServiceProvider).setStatus(orderId, next);
      // Sunucu güncel siparişi döndürüyor ama listeyi kaynaktan tazelemek
      // üretim şeridini, sütun sayaçlarını, alarmı ve yazdırma tetiklerini tek
      // adımda tutarlı kılar.
      await ref.read(orderSourceProvider).refresh();
      return const OrderAdvanceOutcome(OrderAdvanceResult.ok);
    } on ApiException catch (error) {
      if (error.code == ApiErrorCode.invalidTransition) {
        // Yarış: yönetici panelden ya da ikinci bir kasadan ilerletilmiş.
        // Kırmızı hata değil, bilgi: yapılacak şey listeyi tazelemek.
        await _refreshQuietly();
        return const OrderAdvanceOutcome(OrderAdvanceResult.conflict);
      }
      return OrderAdvanceOutcome(OrderAdvanceResult.failed, error.message);
    } on Object catch (error) {
      // `ApiException` dışında bir şey gelmemeli ama gelirse düğme sessizce
      // ölmemeli: mutfakta sessiz başarısızlık, iki kez hazırlanan yemektir.
      return OrderAdvanceOutcome(OrderAdvanceResult.failed, '$error');
    } finally {
      // Sağlayıcı bu arada elden çıkarılmış olabilir (eşleme iptali).
      if (ref.mounted) state = {...state}..remove(orderId);
    }
  }

  KitchenOrder? _currentOrder(int orderId) {
    for (final order in ref.read(activeOrdersProvider)) {
      if (order.id == orderId) return order;
    }
    return null;
  }

  Future<void> _refreshQuietly() async {
    try {
      await ref.read(orderSourceProvider).refresh();
    } on Object {
      // Tazeleme başarısızsa bağlantı göstergesi zaten haber verir.
    }
  }
}

// ──────────────────── Kalem işaretleri ve vardiya sayaçları ────────────────────

/// Kalem bazlı "hazır" işaretleri. Yereldir, sunucuya gitmez.
final orderItemProgressProvider =
    NotifierProvider<OrderItemProgressController, OrderItemProgress>(
      OrderItemProgressController.new,
    );

class OrderItemProgressController extends Notifier<OrderItemProgress> {
  @override
  OrderItemProgress build() {
    // Ekrandan düşen siparişin işaretleri silinir; yoksa harita vardiya
    // boyunca büyür ve kimlik yeniden kullanılırsa yanlış karta yapışır.
    ref.listen<List<KitchenOrder>>(activeOrdersProvider, (_, orders) {
      final live = <int>{for (final order in orders) order.id};
      final next = state.retaining(live);
      if (!identical(next, state)) state = next;
    });

    return OrderItemProgress.empty;
  }

  void toggle(int orderId, int itemIndex) =>
      state = state.toggle(orderId, itemIndex);
}

/// Uygulama açıldığından beri biriken vardiya sayaçları.
final shiftStatsProvider = NotifierProvider<ShiftStatsController, ShiftStats>(
  ShiftStatsController.new,
);

class ShiftStatsController extends Notifier<ShiftStats> {
  final ShiftStatsTracker _tracker = ShiftStatsTracker();

  @override
  ShiftStats build() {
    var initial = ShiftStats.empty;
    var built = false;

    ref.listen<AsyncValue<List<KitchenOrder>>>(kitchenOrdersProvider, (
      _,
      next,
    ) {
      final orders = next.value;
      if (orders == null) return;
      final stats = _tracker.apply(orders);
      if (built) {
        state = stats;
      } else {
        initial = stats;
      }
    }, fireImmediately: true);

    built = true;
    return initial;
  }
}

// ─────────────────────────── Klavyeyle seçim ───────────────────────────

/// Klavyeyle seçili kart. Mutfakta fare kullanılmıyor.
final boardSelectionProvider =
    NotifierProvider<BoardSelectionController, BoardSelection>(
      BoardSelectionController.new,
    );

class BoardSelectionController extends Notifier<BoardSelection> {
  @override
  BoardSelection build() => BoardSelection.none;

  /// Sütun boyutları — seçimi sınırların içinde tutmak için.
  Map<KdsColumn, int> get _sizes => {
    for (final entry in ref.read(boardProvider).entries)
      entry.key: entry.value.length,
  };

  void moveVertically(int delta) => state = state.moveVertically(delta, _sizes);

  void moveHorizontally(int delta) =>
      state = state.moveHorizontally(delta, _sizes);

  void clear() => state = BoardSelection.none;

  /// Seçili karttaki sipariş; seçim yoksa ya da kart kaybolduysa `null`.
  ///
  /// Her okumada listeden yeniden çözülür: seçili sipariş onaylanıp sütun
  /// değiştirebilir. Kimliği saklamak yerine yeri saklamak, "en üstteki kartı
  /// işle" alışkanlığını korur.
  KitchenOrder? selectedOrder() {
    final selection = state.clampedTo(_sizes);
    final column = selection.column;
    if (column == null) return null;

    final orders = ref.read(boardProvider)[column] ?? const <KitchenOrder>[];
    return selection.index < orders.length ? orders[selection.index] : null;
  }
}
