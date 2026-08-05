/// Riverpod bağlantı noktaları.
///
/// Ekran kodu somut sınıf bilmez: [orderSourceProvider] bugün
/// `PollingOrderSource`, Faz 1.5'te `WebSocketOrderSource` döndürecek ve
/// arayüzde tek satır değişmeyecek (ADR-05).
library;

import 'dart:async';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/escpos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../kds/board.dart';
import '../kds/order_alert.dart';
import '../kds/order_filter.dart';
import '../kds/urgency.dart';
import '../printing/print_queue.dart';
import '../printing/print_service.dart';
import '../printing/print_triggers.dart';
import '../printing/printer_device.dart';
import '../settings/kds_settings.dart';
import '../settings/kds_settings_store.dart';
import 'device_session.dart';
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

/// Yeni sipariş uyarı sesi. Ayardaki şalter burada uygulanır.
final orderAlertProvider = Provider<OrderAlert>((ref) {
  final enabled = ref.watch(
    kdsSettingsProvider.select((settings) => settings.soundEnabled),
  );
  return enabled ? const SystemOrderAlert() : const SilentOrderAlert();
});

/// Arama kutusundaki metin. Yalnızca çizimi daraltır, veriyi değil.
final searchQueryProvider = NotifierProvider<SearchQuery, String>(
  SearchQuery.new,
);

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
    // `select` şart: tüm ayar nesnesini izleseydik ses şalterine basmak
    // kaynağı yeniden kurar, listeyi baştan çektirir ve ekranı boşaltırdı.
    interval: Duration(
      seconds: ref.watch(
        kdsSettingsProvider.select((settings) => settings.pollSeconds),
      ),
    ),
  )..start();
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

final printerStatusProvider = StreamProvider<PrinterAvailability>(
  (ref) => PrinterProbe(
    ref.watch(
      kdsSettingsProvider.select((settings) => settings.printerDevicePath),
    ),
  ).watch(),
);

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

/// Personelin bastığı ileri adımı sunucuya iletir.
///
/// Kararı sunucu verir; istemcideki geçiş matrisi yalnızca geçersiz butonu
/// göstermemek içindir (`bld_core/order_status.dart`).
final orderStatusControllerProvider = Provider<OrderStatusController>(
  (ref) => OrderStatusController(
    kitchen: ref.watch(kitchenServiceProvider),
    source: ref.watch(orderSourceProvider),
  ),
);

/// Durum ilerletme isteğini atıp listeyi tazeler.
class OrderStatusController {
  const OrderStatusController({
    required KitchenService kitchen,
    required OrderSource source,
  }) : _kitchen = kitchen,
       _source = source;

  final KitchenService _kitchen;
  final OrderSource _source;

  /// [order]'ı bir sonraki duruma taşır. Terminal durumda hiçbir şey yapmaz.
  ///
  /// Hata çağırana bırakılır: mutfakta sessizce başarısız olan bir buton,
  /// personelin siparişi iki kez hazırlamasına yol açar.
  Future<void> advance(KitchenOrder order) async {
    final next = order.nextStatus;
    if (next == null) return;

    await _kitchen.setStatus(order.id, next);
    // Sunucu güncel siparişi döndürüyor ama listeyi kaynaktan tazelemek
    // üretim şeridini, sütun sayaçlarını ve yazdırma tetiklerini tek adımda
    // tutarlı kılar.
    await _source.refresh();
  }
}
