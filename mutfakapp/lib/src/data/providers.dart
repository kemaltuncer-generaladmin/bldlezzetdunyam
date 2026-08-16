/// Riverpod bağlantı noktaları.
///
/// Ekran kodu somut sınıf bilmez: [orderSourceProvider] bugün
/// `PollingOrderSource`, Faz 1.5'te `WebSocketOrderSource` döndürecek ve
/// arayüzde tek satır değişmeyecek (ADR-05).
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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
import '../printing/test_receipt.dart';
import '../printing/print_triggers.dart';
import '../printing/printer_device.dart';
import '../settings/kds_settings.dart';
import '../settings/kds_settings_store.dart';
import '../update/app_updater.dart';
import '../update/update_checker.dart';
import '../lock/unlock_password.dart';
import 'command_runner.dart';
import 'managed_settings.dart';
import '../sound/alarm_asset.dart';
import '../sound/alarm_player.dart';
import '../sound/connection_alarm.dart';
import '../sound/kds_sound_event.dart';
import '../sound/new_order_alarm.dart';
import '../sound/system_audio.dart';
import '../sound/tts_announcer.dart';
import 'bbd_monitor.dart';
import 'bbd_source.dart';
import 'device_session.dart';
import 'kitchen_health.dart';
import 'order_edit.dart';
import 'polling_order_source.dart';
import 'printer_probe.dart';
import 'sales_control.dart';
import 'subscription_plan.dart';

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

/// Seyrek tazeleme için ikinci bir tik kaynağı — dakikada bir.
///
/// NEDEN AYRI SAAT: [clockProvider] 5 saniyede bir tikliyor ve **arayüz
/// çizimi** için doğru (bekleme süresi saniye saniye büyümeli). Ama onu
/// bir `FutureProvider` izlediğinde her tikte YENİ BİR AĞ İSTEĞİ doğuyor.
///
/// SAHADA ÖLÇÜLDÜ (12.08.2026): satış şalteri ve abonelik listesi pano
/// saatine bağlıydı; ikisi 720'şer istek/saat üretiyordu. Sipariş
/// yoklaması (720) ve BBD kuyruğu (180) ile birlikte toplam ~2460
/// istek/saat — sunucudaki `bld-kitchen` sınırı **1200/saat**. Kasa
/// yarım vardiyada `429` almaya başlardı.
///
/// Bu saati izleyen veri, 60 saniyeye kadar bayat olabilir. Satış
/// şalteri ve abonelik listesi için bu fazlasıyla taze: ikisi de dakikada
/// bir değişen şeyler değil ve personel kendi değiştirdiğinde sağlayıcı
/// zaten `invalidate` ediliyor.
final slowClockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now().toUtc();
  yield* Stream<void>.periodic(
    const Duration(minutes: 1),
  ).map((_) => DateTime.now().toUtc());
});

/// Zamanı okumanın kısa yolu; akış henüz değer üretmediyse gerçek saate düşer.
DateTime _now(Ref ref) =>
    ref.watch(clockProvider).value ?? DateTime.now().toUtc();

/// Sunucudan gelen komutları çalıştıran koşucu.
///
/// Eylemler burada bağlanıyor; karar mantığı `CommandRunner` içinde ve
/// testleri orada.
final commandRunnerProvider = Provider<CommandRunner>((ref) {
  return CommandRunner(
    CommandActions(
      printTestReceipt: () async {
        final config = ref.read(kdsSettingsProvider);
        await ref
            .read(printServiceProvider)
            .printDiagnostic(
              buildTestReceipt(
                devicePath: config.printerDevicePath,
                printedAt: DateTime.now(),
                style: ref.read(receiptStyleProvider),
              ),
            );
        return null;
      },
      reprint: (orderId, type) async {
        final receiptType = ReceiptType.values
            .where((t) => t.wireName == type)
            .firstOrNull;
        if (receiptType == null) return 'Bilinmeyen fiş tipi: $type';

        return ref.read(printServiceProvider).reprint(orderId, receiptType)
            ? null
            : 'Sipariş #$orderId için fiş bulunamadı';
      },
      clearFailed: () async {
        ref.read(printServiceProvider).clearFailed();
        return null;
      },
      silenceAlarm: () async {
        ref.read(newOrderAlarmProvider.notifier).silence();
        return null;
      },
      // Süreci sonlandırmak yeterli: systemd `Restart=always` ile
      // beş saniyede geri getiriyor. Kendi başımıza yeniden başlatmaya
      // çalışmak, servis yöneticisinin işini ikiye bölerdi.
      restart: () async {
        // Sonucu bildirebilmek için hemen çıkmıyoruz; bir sonraki
        // bildirim gönderilsin diye kısa bir gecikme veriyoruz.
        unawaited(
          Future<void>.delayed(const Duration(seconds: 2), () => exit(0)),
        );
        return null;
      },

      // ── K-22 ile gelen üç komut ─────────────────────────────────────
      update: () => ref.read(appUpdaterProvider).install(),

      unpair: () async {
        // TOKEN SİLİNİYOR: `deviceSessionProvider` durumu değişince
        // `AppRoot` eşleme ekranına döner (`app.dart`, `docs/05` §7
        // adım 5) ve `_PairedRoot` ağacı sökülür.
        //
        // SONUCUN SUNUCUYA ULAŞMAMASI BEKLENEN DAVRANIŞ. Komut sonuçları
        // BİR SONRAKİ sağlık bildirimiyle gidiyor; o bildirimin token'ı
        // artık yok. Bunu "sessiz başarısızlık" yapan şey eksik bir geri
        // bildirim değil — yönetici kasanın eşlemeden düştüğünü panelde
        // doğrudan görür (cihaz çevrimdışına düşer, eşleme kodu ister).
        // Sonucu bekletmek için token'ı ayakta tutmak, komutun tam da
        // yapması istenen şeyi geciktirmek olurdu.
        await ref.read(deviceSessionProvider.notifier).clearToken();
        return null;
      },

      clearQueue: () async {
        ref.read(printServiceProvider).clearQueue();
        return null;
      },
    ),
  );
});

/// `update` komutunu yürüten kurulum akışı (K-22 §2).
///
/// Sağlayıcı olması, testin gerçek ağ ve gerçek `dpkg-deb` olmadan komut
/// yolunu doğrulayabilmesi için: `AppUpdater`'ın kendi testleri
/// `app_updater_test.dart` içinde, burada yalnızca bağlantı var.
final appUpdaterProvider = Provider<AppUpdater>((ref) {
  return AppUpdater(
    checkVersion: () =>
        ref.read(bldApiProvider).appVersion.check(AppConfig.appId),
    download: downloadBytes,
    run: runProcess,
    // `infra/kasa/derle.sh` ve `mutfakapp.service` ile AYNI YOL. Servis
    // `%h/.local/opt/mutfakapp/mutfakapp` çalıştırıyor; başka bir dizine
    // kurmak, kurulumun sessizce hiçbir işe yaramaması demek olurdu.
    installDir: Directory(
      '${Platform.environment['HOME'] ?? '.'}/.local/opt/mutfakapp',
    ),
    workDir: Directory.systemTemp,
    currentVersion: AppConfig.appVersion,
  );
});

/// Saatlik sürüm denetimi (`docs/05-mutfakapp.md` §9).
///
/// YALNIZ HABER VERİR. Kurulum ayarlar ekranındaki düğmeyle ya da Kontrol
/// Merkezi'nin `update` komutuyla, yani bilinçli olarak başlar; gerekçesi
/// `update_checker.dart` başlığında.
final updateCheckProvider =
    NotifierProvider<UpdateCheckController, UpdateStatus>(
      UpdateCheckController.new,
    );

class UpdateCheckController extends Notifier<UpdateStatus> {
  @override
  UpdateStatus build() {
    final timer = Timer.periodic(
      updateCheckInterval,
      (_) => unawaited(check()),
    );
    ref.onDispose(timer.cancel);

    // İLK DENETİM AÇILIŞTA: kasa elektrik kesintisinden sonra açıldığında
    // bir saat beklemeden durumu öğrenmeli.
    //
    // `unawaited(check())` DEĞİL, MİKROGÖREV. `check()` ilk satırında
    // `state` okuyor ve o satır, `await`'e gelmeden ÖNCE senkron çalışıyor;
    // `build` henüz dönmediği için sağlayıcının durumu daha atanmamış olur
    // ve Riverpod "uninitialized provider" ile patlar. Mikrogörev, içinde
    // bulunduğumuz senkron akış (yani `build`) bittikten sonra koşar.
    Future.microtask(check);

    return const UpdateStatus();
  }

  /// Bir denetim turu. Ayarlar ekranındaki düğme de bunu çağırır.
  Future<void> check() async {
    if (state.checking) return;

    state = state.copyWith(checking: true);

    final checker = UpdateChecker(
      check: () => ref.read(bldApiProvider).appVersion.check(AppConfig.appId),
      currentVersion: AppConfig.appVersion,
    );

    final sonuc = await checker.run(state);

    // Denetim sürerken ekran kapanmış olabilir (ayarlardan çıkış, kapanış).
    if (!ref.mounted) return;

    state = sonuc;
  }
}

/// Açılış kilidinin hatırlandığı depo.
final unlockStoreProvider = Provider<UnlockStore>(
  (ref) => SharedPreferencesUnlockStore(),
);

// ─────────────────────────── Yeni sipariş alarmı ───────────────────────────

/// Kasanın hoparlör denetimi — çıkış listesi ve sistem ses seviyesi.
final systemAudioProvider = Provider<SystemAudio>((ref) => SystemAudio());

/// Kasada bulunan ses çıkışları. Ayar ekranı bunu listeler.
final audioSinksProvider = FutureProvider.autoDispose<List<AudioSink>>(
  (ref) => ref.watch(systemAudioProvider).listSinks(),
);

/// Alarm sesini çalan oynatıcı. Ayardaki ses şalteri burada uygulanır.
///
/// Ses kapalıyken [SilentAlarmPlayer] döner ve `isMuted` doğru olur; arayüz
/// bunu görünür kılar — sessiz bir alarm, alarm olmadığını bilmemekten iyidir.
///
/// NEDEN `select` LİSTESİ UZUN: seviye ya da çıkış cihazı değiştiğinde
/// oynatıcının yeniden kurulması gerekir; ayarların tamamını izleseydik
/// alakasız bir ayar (yazıcı yolu) da alarmı sıfırlardı.
final alarmPlayerProvider = Provider<AlarmPlayer>((ref) {
  final enabled = ref.watch(
    kdsSettingsProvider.select(
      (settings) => settings.soundEnabledFor(KdsSoundEvent.newOrder),
    ),
  );
  final volume = ref.watch(
    kdsSettingsProvider.select((settings) => settings.volumePercent),
  );
  final sink = ref.watch(
    kdsSettingsProvider.select((settings) => settings.audioSinkName),
  );
  final repeatDelay = ref.watch(
    kdsSettingsProvider.select((settings) => settings.alarmRepeatDelay),
  );
  final maxRepeats = ref.watch(
    kdsSettingsProvider.select((settings) => settings.alarmMaxRepeats),
  );

  final player = enabled
      ? ProcessAlarmPlayer(
          assetPath: KdsSoundEvent.newOrder.assetPath,
          materialize: copyAlarmAsset,
          volumePercent: volume,
          sink: sink,
          repeatDelay: repeatDelay,
          maxRepeats: maxRepeats,
        )
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
  // GENEL SES ŞALTERİNE BAKMAZ — bilinçli.
  //
  // Yeni sipariş sesi kapatılabilir; personel ekrana bakıyorsa siparişi
  // zaten görür. Bağlantı kopması öyle değil: ekran son bilinen listeyi
  // gösterir ve DOĞRU görünür, yeni sipariş hiç gelmez. Bunu sessize
  // almak, tek uyarıyı kapatıp mutfağı kör bırakmaktır.
  //
  // Sesi durduran tek şey bağlantının geri gelmesidir.
  //
  // Seviye ve çıkış cihazı yine de uygulanır: "susturulamaz" demek
  // "yanlış hoparlörden çalsın" demek değil.
  final player = ProcessAlarmPlayer(
    assetPath: KdsSoundEvent.connectionLost.assetPath,
    materialize: copyAlarmAsset,
    volumePercent: ref.watch(
      kdsSettingsProvider.select((settings) => settings.volumePercent),
    ),
    sink: ref.watch(
      kdsSettingsProvider.select((settings) => settings.audioSinkName),
    ),
  );

  ref.onDispose(() => player.stop().ignore());
  return player;
});

/// Türkçe sesli anons. Ayardan kapalıysa sessiz sürüm döner.
final ttsAnnouncerProvider = Provider<TtsAnnouncer>((ref) {
  final enabled = ref.watch(
    kdsSettingsProvider.select((settings) => settings.ttsEnabled),
  );

  if (!enabled) return const SilentTtsAnnouncer();

  return ProcessTtsAnnouncer(
    ratePercent: ref.watch(
      kdsSettingsProvider.select((settings) => settings.ttsRatePercent),
    ),
  );
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
    final alarm = ConnectionAlarm(
      ref.watch(connectionAlarmPlayerProvider),
      interval: ref.watch(
        kdsSettingsProvider.select(
          (settings) => settings.connectionAlarmInterval,
        ),
      ),
    );
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
    final alarm = NewOrderAlarm(
      ref.watch(alarmPlayerProvider),
      announcer: ref.watch(ttsAnnouncerProvider),
    );
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
  ///
  /// Yönetici susturmayı tamamen kapatabilir (`alarm_silenceable`):
  /// susturmanın refleks hâline geldiği bir mutfakta alarmın hiç
  /// çalmamasıyla aynı sonuç doğuyor.
  void silence() {
    if (!ref.read(kdsSettingsProvider).alarmSilenceable) return;

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
    // Respect persisted pairing cooldown (set when server responded 429).
    final cooldownMs = await store.readPairCooldownMillis();
    if (cooldownMs != null) {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      if (now < cooldownMs) {
        final wait = ((cooldownMs - now) / 1000).ceil();
        throw ApiException(
          code: ApiErrorCode.rateLimited,
          message:
              'Sunucu yoğun. Lütfen $wait saniye sonra tekrar deneyin.',
        );
      }
    }
    await store.writeBaseUrl(baseUrl);
    state = DeviceSession(baseUrl: baseUrl);

    try {
      final response = await ref
          .read(kitchenServiceProvider)
          .pair(PairRequest(pairingCode: pairingCode, deviceName: deviceName));

      // `BldApi.kitchen.pair` token'ı kendi deposuna zaten yazar; burada
      // açıkça yazmak bu yan etkiye bağımlılığı kaldırır — kaydın olduğundan
      // emin olmadan durumu "eşlendi"ye çevirmeyiz.
      await store.tokens.write(response.token);
      state = DeviceSession(baseUrl: baseUrl, token: response.token);
    } on ApiException catch (e) {
      // If server replied RATE_LIMITED, persist a short cooldown to avoid
      // repeated immediate retries from the UI.
      if (e.code == ApiErrorCode.rateLimited) {
        await store.writePairCooldown(const Duration(seconds: 60));
      }
      rethrow;
    }
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

/// Bugün + yarının abonelik siparişleri (banner + döküm).
///
/// Ayrı bir zamanlayıcı KURMAZ (aksi halde widget testlerinde pumpAndSettle
/// asılı kalır): ana pano yoklaması [kitchenOrdersProvider] her tazelendiğinde
/// bu da yeniden çekilir. Böylece yeni üretilmiş/durum değiştirmiş abonelik
/// siparişleri panoyla aynı ritimde güncellenir, fazladan timer olmaz.
final subscriptionOrdersProvider =
    FutureProvider.autoDispose<KitchenSubscriptionOrders>((ref) {
      // YAVAŞ SAATLE, pano akışıyla DEĞİL (12.08.2026 düzeltmesi).
      //
      // Önceki sürüm `kitchenOrdersProvider`'ı izliyordu; o akış HER
      // YOKLAMADA yayın yapıyor (`_applyPage` her seferinde `_snapshot`
      // ekliyor), yani 5 saniyede bir. Sonuç: saatte 720 ekstra istek ve
      // `bld-kitchen` sınırının aşılması.
      //
      // Abonelik siparişleri gece 22:00'de bir kez üretiliyor; durum
      // değişimleri zaten ana panodan geliyor. Dakikada bir tazelemek
      // fazlasıyla taze.
      ref.watch(slowClockProvider);
      return ref.watch(kitchenServiceProvider).subscriptionOrders();
    });

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

// ─────────────────────────── Satış kontrolü (K-11) ──────────────────────────

final salesControlApiProvider = Provider<SalesControlApi>((ref) {
  final session = ref.watch(deviceSessionProvider);
  final store = ref.watch(deviceSessionStoreProvider);

  // Somut tip yerel değişkende tutuluyor: sağlayıcının açtığı tip
  // arayüz olmalı (testler sahte veriyor), ama `close()` yalnız somut
  // sınıfta var ve soket sızdırmamak için çağrılması şart.
  final api = HttpSalesControlApi(
    baseUrl: session.baseUrl,
    appId: AppConfig.appId,
    appVersion: AppConfig.appVersion,
    readToken: store.tokens.read,
  );
  ref.onDispose(api.close);
  return api;
});

/// Satış şalterinin durumu.
///
/// YAVAŞ SAATLE TAZELENİYOR (dakikada bir), pano saatiyle değil.
/// Durdurma başka bir kasadan ya da admin panelden de yapılabiliyor, o
/// yüzden yoklanması gerekiyor — ama 5 saniyede bir yoklamak saatte 720
/// istek demekti ve `bld-kitchen` sınırını tek başına yarılıyordu
/// ([slowClockProvider] yorumundaki hesap).
///
/// Personel kendisi açıp kapattığında sağlayıcı zaten `invalidate`
/// ediliyor; gecikme yalnız BAŞKA bir yerden yapılan değişiklikte
/// hissediliyor ve orada bir dakika kabul edilebilir.
///
/// Kırmızı şeritteki geri sayım bundan ETKİLENMEZ: kalan süre
/// `resumesAt`'ten yerel olarak hesaplanıyor ve şerit hızlı saati
/// izliyor.
final orderingStateProvider = FutureProvider<OrderingState>((ref) {
  ref.watch(slowClockProvider);

  return ref.watch(salesControlApiProvider).ordering();
});

/// Mutfağın ürün listesi ve "bugün tükendi" işaretleri.
///
/// `autoDispose`: yalnızca satış kontrolü ekranı açıkken gerekiyor ve
/// 80 kalemlik bir listeyi bellekte tutmanın anlamı yok.
final kitchenMenuProvider = FutureProvider.autoDispose<List<KitchenMenuItem>>(
  (ref) => ref.watch(salesControlApiProvider).menuAvailability(),
);

// ─────────────────────── BBD Store köprüsü (K-16) ───────────────────────────

final bbdApiProvider = Provider<BbdApi>((ref) {
  final session = ref.watch(deviceSessionProvider);
  final store = ref.watch(deviceSessionStoreProvider);

  final api = HttpBbdApi(
    baseUrl: session.baseUrl,
    appId: AppConfig.appId,
    appVersion: AppConfig.appVersion,
    readToken: store.tokens.read,
  );
  ref.onDispose(api.close);
  return api;
});

/// BBD fişlerinin çalınacağı oynatıcı.
///
/// AYRI OYNATICI: BBD sesi yeni sipariş alarmıyla aynı anda çalabilir ve
/// tek oynatıcıyı paylaşsalardı biri diğerinin sesini keserdi — panoda
/// olmayan bir siparişin fişi sessizce çıkardı.
final bbdAlarmPlayerProvider = Provider<AlarmPlayer>((ref) {
  final enabled = ref.watch(
    kdsSettingsProvider.select(
      (settings) => settings.soundEnabledFor(KdsSoundEvent.bbdOrder),
    ),
  );

  if (!enabled) return SilentAlarmPlayer();

  final player = ProcessAlarmPlayer(
    assetPath: KdsSoundEvent.bbdOrder.assetPath,
    materialize: copyAlarmAsset,
    volumePercent: ref.watch(
      kdsSettingsProvider.select((settings) => settings.volumePercent),
    ),
    sink: ref.watch(
      kdsSettingsProvider.select((settings) => settings.audioSinkName),
    ),
  );

  ref.onDispose(() => player.stop().ignore());
  return player;
});

/// BBD kuyruğunun yoklama aralığı.
///
/// Sipariş yoklamasından SEYREK: BBD hacmi mutfağınkinden küçük ve fiş
/// birkaç saniye geç çıkması sorun değil. Her 5 saniyede bir ikinci bir
/// istek atmak, kasa başına saatlik istek sayısını iki katına çıkarırdı.
const Duration bbdPollInterval = Duration(seconds: 20);

final bbdMonitorProvider =
    NotifierProvider<BbdMonitorController, BbdMonitorState>(
      BbdMonitorController.new,
    );

/// [BbdMonitor]'ü zamanlayıcıya ve yazıcıya bağlar.
///
/// Karar mantığı burada DEĞİL: sıralama (ses → fiş → ack) ve "başarısızsa
/// ack gönderme" kuralı `BbdMonitor` içinde ve testleri orada.
class BbdMonitorController extends Notifier<BbdMonitorState> {
  BbdMonitor? _monitor;

  @override
  BbdMonitorState build() {
    final player = ref.watch(bbdAlarmPlayerProvider);

    final monitor = BbdMonitor(
      api: ref.watch(bbdApiProvider),
      print: (bytes) => ref
          .read(printServiceProvider)
          .printDiagnostic(Uint8List.fromList(bytes)),
      playSound: player.playOnce,
      style: ref.watch(receiptStyleProvider),
    );
    _monitor = monitor;

    final timer = Timer.periodic(
      bbdPollInterval,
      (_) => unawaited(poll()),
    );
    ref.onDispose(() {
      timer.cancel();
      _monitor = null;
    });

    // İlk tur beklenmez: `build` senkron kalmalı ve pano bir ağ çağrısı
    // için gecikmemeli.
    unawaited(poll());

    return monitor.state;
  }

  Future<void> poll() async {
    final monitor = _monitor;
    if (monitor == null) return;

    final next = await monitor.poll();
    if (ref.mounted) state = next;
  }
}

// ────────────────────── Abonelik üretim planı (K-15) ────────────────────────

final subscriptionPlanApiProvider = Provider<SubscriptionPlanApi>((ref) {
  final session = ref.watch(deviceSessionProvider);
  final store = ref.watch(deviceSessionStoreProvider);

  final api = HttpSubscriptionPlanApi(
    baseUrl: session.baseUrl,
    appId: AppConfig.appId,
    appVersion: AppConfig.appVersion,
    readToken: store.tokens.read,
  );
  ref.onDispose(api.close);
  return api;
});

/// Seçili gün aralığının planı.
///
/// `family` ile aralık başına ayrı istek: hafta her açılışta değil,
/// yalnız sekmeye dokunulduğunda hesaplanıyor — mutfağın bakmadığı altı
/// gün için boşuna sorgu olmasın.
final subscriptionPlanProvider = FutureProvider.autoDispose
    .family<List<PlanDay>, PlanRange>(
      (ref, range) => ref.watch(subscriptionPlanApiProvider).plan(range),
    );

// ────────────────────────── Sipariş düzenleme (K-14) ────────────────────────

final orderEditApiProvider = Provider<OrderEditApi>((ref) {
  final session = ref.watch(deviceSessionProvider);
  final store = ref.watch(deviceSessionStoreProvider);

  final api = HttpOrderEditApi(
    baseUrl: session.baseUrl,
    appId: AppConfig.appId,
    appVersion: AppConfig.appVersion,
    readToken: store.tokens.read,
  );
  ref.onDispose(api.close);
  return api;
});

/// Düzenleme ekranı açılırken çekilen sipariş görüntüsü.
///
/// `autoDispose` + `family`: ekran kapanınca bellekte kalmıyor ve her
/// sipariş için ayrı istek. Panodaki kartın kopyası KULLANILMIYOR —
/// düzenleme, verinin en tazesiyle başlamak zorunda; kart 5 saniye eski
/// olabilir ve yanlış adet üstüne yazmak siparişi bozar.
final editableOrderProvider = FutureProvider.autoDispose
    .family<EditableOrder, int>(
      (ref, orderId) => ref.watch(orderEditApiProvider).editable(orderId),
    );

/// Ürün ekleme listesi — fiyatsız.
final kitchenAddableMenuProvider = FutureProvider
    .autoDispose<List<({int menuId, String name})>>(
      (ref) => ref.watch(orderEditApiProvider).menu(),
    );

/// Sağlık bildiriminin varsayılan sıklığı.
///
/// Yoklama aralığından **bağımsız**: personel yoklamayı 2 saniyeye
/// indirdiğinde sunucuya dakikada 30 sağlık isteği gitmemeli. Dakikada bir,
/// "bugün kaç sipariş" sayacı için fazlasıyla taze.
///
/// Yönetici bunu panelden değiştirebilir (`health_seconds`); ayar geldiğinde
/// zamanlayıcı yeniden kurulur.
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
      ref.watch(
        kdsSettingsProvider.select((settings) => settings.healthInterval),
      ),
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

  /// Bir sonraki bildirimde gönderilecek komut sonuçları.
  List<KitchenCommandResult> _pendingResults = const [];

  /// Bir bildirim gönderir. Hata yutulur; gösterge kendisi haber verir.
  ///
  /// Yanıttaki ayarları uygular ve komutları çalıştırır. Sonuçlar hemen
  /// gönderilmez, BİR SONRAKİ bildirime bırakılır: komutu çalıştırmak
  /// (fiş basmak, yeniden başlatmak) saniyeler sürebilir ve bunun için
  /// ikinci bir HTTP isteği açmak, ağ kopukken sonucun tamamen
  /// kaybolması demek olurdu. Sunucu zaten teslim edilmiş komutu
  /// sonucu gelmezse 10 dakika sonra yeniden gönderiyor.
  Future<void> poll() async {
    final monitor = _monitor;
    if (monitor == null) return;

    final next = await monitor.poll();
    if (!ref.mounted) return;
    state = next;

    final status = next.status;
    if (status == null) return;

    _applySettings(status.settings);

    if (status.commands.isEmpty) return;

    final results = await ref.read(commandRunnerProvider).run(status.commands);
    if (ref.mounted) _pendingResults = results;
  }

  /// Sunucudan gelen ayarları yerele uygular.
  ///
  /// Değişmediyse YAZMIYORUZ: her dakika aynı değeri diske yazmak, ayar
  /// sağlayıcısını gereksiz yere yeniden kurar ve ona bağlı olan yoklama
  /// aralığı, alarm oynatıcısı ve yazıcı yoklaması boşuna yeniden
  /// oluşturulurdu.
  void _applySettings(KitchenManagedSettings managed) {
    final current = ref.read(kdsSettingsProvider);
    final next = applyManagedSettings(current, managed);

    if (next == current) return;

    unawaited(ref.read(kdsSettingsProvider.notifier).update(next));
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
    final settings = ref.read(kdsSettingsProvider);
    final probe = PrinterProbe(settings.printerDevicePath);
    final service = ref.read(printServiceProvider);
    final player = ref.read(alarmPlayerProvider);

    final results = _pendingResults;
    _pendingResults = const [];

    return KitchenHealthReport(
      printerOk: await probe.check() == PrinterAvailability.ready,
      printQueuePending: ref.read(printQueueProvider).pendingCount(),
      printQueueFailed: service.failedCount(),
      appVersion: AppConfig.appVersion,

      // ── Zenginleştirilmiş telemetri (K-22 §3) ─────────────────────────
      //
      // Hepsi kasada ZATEN VAR olan ama sunucuya hiç gitmeyen bilgiler;
      // yönetici bunları görmek için mutfağa gitmek zorundaydı.
      lastError: service.lastError,
      alarmMuted: player.isMuted,
      alarmMuteReason: player.muteReason,
      queueOldestAt: service.oldestPendingAt(),

      // SES AÇIKKEN ÖLÇÜLEBİLİR, KAPALIYKEN ÖLÇÜLEMEZ.
      //
      // Ses kapalıyken oynatıcı `SilentAlarmPlayer` ve `isMuted` her zaman
      // `true` — ama bu bir arıza değil, bir tercih. `false` bildirmek
      // sağlam bir hoparlörü arızalı göstermek, `true` bildirmek ise hiç
      // denenmemiş bir altsistem için sağlık garantisi vermek olurdu.
      // İkisi de yalan; `null` ("bilinmiyor") tek dürüst cevap ve sunucu
      // bu alanı zaten üç hâlli tutuyor.
      soundOk: settings.soundEnabled ? !player.isMuted : null,

      commandResults: results,
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

/// Fiş biçimi — kod sayfası önce SUNUCU ayarından, yoksa derlemeden.
///
/// Yanlış kod sayfası Türkçe karakterleri bozar ve doğru değer donanıma
/// özgüdür (`docs/05` §5.2'de sahada `29` ölçüldü). Yeni bir kasada
/// değeri bulmak için `.deb` beklemek yerine yönetici panelden denesin.
final receiptStyleProvider = Provider<ReceiptStyle>(
  (ref) => ReceiptStyle(
    codePage:
        ref.watch(
          kdsSettingsProvider.select((settings) => settings.printerCodePage),
        ) ??
        ref.watch(appConfigProvider).printerCodePage,
  ),
);

final printServiceProvider = Provider<PrintService>((ref) {
  final service = PrintService(
    queue: ref.watch(printQueueProvider),
    device: ref.watch(printerDeviceProvider),
    kitchen: ref.watch(kitchenServiceProvider),
    style: ref.watch(receiptStyleProvider),
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
      if (service.enqueue(job.orderId, job.type, revision: job.revision)) {
        queued++;
      }
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

  /// Bir adım geri alır (K-10).
  ///
  /// PENCERE SUNUCUDA: burada süre saymıyoruz. İstemcinin saati yanlışsa
  /// ya da şerit ekranda unutulmuşsa geri alma sessizce geçmemeli;
  /// sunucu `UNDO_WINDOW_SECONDS` dışındaki isteği `422` ile reddeder ve
  /// personel bunu bir uyarı olarak görür.
  Future<OrderAdvanceOutcome> undo(int orderId, OrderStatus previous) async {
    if (state.contains(orderId)) {
      return const OrderAdvanceOutcome(OrderAdvanceResult.ignored);
    }

    state = {...state, orderId};
    try {
      await ref.read(kitchenServiceProvider).setStatus(orderId, previous);
      await ref.read(orderSourceProvider).refresh();
      return const OrderAdvanceOutcome(OrderAdvanceResult.ok);
    } on ApiException catch (error) {
      if (error.code == ApiErrorCode.invalidTransition) {
        await _refreshQuietly();
        return const OrderAdvanceOutcome(OrderAdvanceResult.conflict);
      }
      return OrderAdvanceOutcome(OrderAdvanceResult.failed, error.message);
    } on Object catch (error) {
      return OrderAdvanceOutcome(OrderAdvanceResult.failed, '$error');
    } finally {
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
