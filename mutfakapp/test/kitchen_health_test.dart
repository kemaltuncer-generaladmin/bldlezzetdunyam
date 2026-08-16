/// Sağlık bildirimi — `POST /kitchen/health`.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/data/command_runner.dart';
import 'package:mutfakapp/src/data/kitchen_health.dart';
import 'package:mutfakapp/src/data/providers.dart';
import 'package:mutfakapp/src/printing/printer_device.dart';
import 'package:mutfakapp/src/sound/alarm_player.dart';

import 'fake_kds_settings_store.dart';
import 'fake_kitchen_health_api.dart';
import 'fake_kitchen_service.dart';

const KitchenHealthReport healthy = KitchenHealthReport(
  printerOk: true,
  printQueuePending: 0,
  printQueueFailed: 0,
  appVersion: '1.0.0',
);

void main() {
  test('ilk bildirim yazıcıyı ÖNBELLEKTEN değil doğrudan okur', () async {
    // SAHADA YAŞANDI: toplayıcı `printerStatusProvider` akışının önbelleğe
    // alınmış değerini okuyordu. İlk sağlık bildirimi açılışta, akış daha
    // hiçbir şey yaymadan gönderiliyor; `.value` null oluyor ve sunucuya
    // "yazıcı arızalı" bildiriliyordu. Yazıcı takılı, fişler basılıyor,
    // gösterge "yok" diyor.
    //
    // Toplayıcının asenkron olması bu yüzden: yazıcıyı gerçekten yoklamak
    // bir dosya sistemi çağrısı ve senkron imza çağıranı önbelleğe
    // bakmaya zorluyordu.
    var yoklandi = false;
    final api = FakeKitchenHealthApi();
    final monitor = KitchenHealthMonitor(
      api: api,
      collect: () async {
        yoklandi = true;
        return const KitchenHealthReport(
          printerOk: true,
          printQueuePending: 0,
          printQueueFailed: 0,
          appVersion: '1.0.0',
        );
      },
    );

    await monitor.poll();

    expect(yoklandi, isTrue);
    expect(api.reports.single.printerOk, isTrue);
  });

  group('KitchenHealthReport', () {
    test('sözleşmedeki alan adlarını üretir', () {
      expect(healthy.toJson(), {
        'printer_ok': true,
        'print_queue_pending': 0,
        'print_queue_failed': 0,
        'app_version': '1.0.0',
      });
    });

    test('sürüm verilmezse alan hiç gönderilmez', () {
      const report = KitchenHealthReport(
        printerOk: false,
        printQueuePending: 3,
        printQueueFailed: 1,
      );
      expect(report.toJson().containsKey('app_version'), isFalse);
      expect(report.toJson()['printer_ok'], isFalse);
    });

    test('negatif sayaç sıfıra çekilir', () {
      // Sunucu `min:0` istiyor; bozuk bir sayaç yüzünden 422 almak, sağlık
      // göstergesini tamamen kör bırakırdı.
      const report = KitchenHealthReport(
        printerOk: true,
        printQueuePending: -1,
        printQueueFailed: -5,
      );
      expect(report.toJson()['print_queue_pending'], 0);
      expect(report.toJson()['print_queue_failed'], 0);
    });

    // ── Zenginleştirilmiş telemetri (K-22 §3) ──────────────────────────

    test('TELEMETRİ ALANLARI bilinmiyorken HİÇ gönderilmez', () {
      // Bilinmeyen bir değeri iyimser bir varsayılanla doldurmak
      // göstergeyi yalancı yapardı; sunucu da bu sütunları üç hâlli
      // tutuyor (`null` = "kasa bildirmedi").
      final json = healthy.toJson();

      for (final key in [
        'last_error',
        'alarm_muted',
        'alarm_mute_reason',
        'queue_oldest_at',
        'sound_ok',
      ]) {
        expect(json.containsKey(key), isFalse, reason: '$key gönderilmemeli');
      }
    });

    test('telemetri alanları sözleşmedeki adlarla gider', () {
      final report = KitchenHealthReport(
        printerOk: false,
        printQueuePending: 3,
        printQueueFailed: 1,
        lastError: '#42 mutfak: /dev/thermal0 yok',
        alarmMuted: true,
        alarmMuteReason: 'Ses oynatıcısı bulunamadı',
        queueOldestAt: DateTime.utc(2026, 8, 18, 7, 30),
        soundOk: false,
      );

      final json = report.toJson();

      expect(json['last_error'], '#42 mutfak: /dev/thermal0 yok');
      expect(json['alarm_muted'], isTrue);
      expect(json['alarm_mute_reason'], 'Ses oynatıcısı bulunamadı');
      expect(json['queue_oldest_at'], '2026-08-18T07:30:00.000Z');
      expect(json['sound_ok'], isFalse);
    });

    test('kuyruk damgası UTC olarak gider', () {
      // Sunucu `date` doğruluyor ve saati Europe/Istanbul'a çeviriyor;
      // yerel saati damgasız göndermek üç saatlik bir yalan olurdu.
      final report = KitchenHealthReport(
        printerOk: true,
        printQueuePending: 1,
        printQueueFailed: 0,
        queueOldestAt: DateTime.utc(2026, 8, 18, 4).toLocal(),
      );

      expect(report.toJson()['queue_oldest_at'], endsWith('Z'));
    });

    test('UZUN HATA METNİ kırpılır, bildirim düşmez', () {
      // Sunucu sütunu 255 karakter. Uzun bir yığın izi yüzünden tüm
      // sağlık bildiriminin 422 alması, telemetri yüzünden asıl
      // göstergenin kör kalması demek olurdu.
      final report = KitchenHealthReport(
        printerOk: true,
        printQueuePending: 0,
        printQueueFailed: 0,
        lastError: 'x' * 400,
        alarmMuteReason: 'y' * 200,
      );

      expect((report.toJson()['last_error']! as String).length, 255);
      expect((report.toJson()['alarm_mute_reason']! as String).length, 120);
    });
  });

  group('KitchenHealthStatus', () {
    test('yanıtı ayrıştırır', () {
      final status = KitchenHealthStatus.fromJson(const {
        'server_time': '2026-08-05T09:00:00Z',
        'orders_today': 12,
        'orders_active': 3,
      });

      expect(status.ordersToday, 12);
      expect(status.ordersActive, 3);
      expect(status.serverTime, DateTime.utc(2026, 8, 5, 9));
    });

    test('eksik ya da bozuk alanlarda çökmez', () {
      // Sözleşme dışı bir yanıt, mutfak ekranını kapatma sebebi olamaz.
      final status = KitchenHealthStatus.fromJson(const {});
      expect(status.ordersToday, isZero);
      expect(status.ordersActive, isZero);
    });
  });

  group('KitchenHealthMonitor', () {
    test('başarılı bildirim durumu doldurur', () async {
      final api = FakeKitchenHealthApi(ordersToday: 12, ordersActive: 3);
      final monitor = KitchenHealthMonitor(
        api: api,
        collect: () async => healthy,
        clock: () => DateTime.utc(2026, 8, 5, 9),
      );

      final state = (await monitor.poll()).state;

      expect(state.reachable, isTrue);
      expect(state.everTried, isTrue);
      expect(state.status?.ordersToday, 12);
      expect(state.lastSuccessAt, DateTime.utc(2026, 8, 5, 9));
    });

    test('toplanan değerler olduğu gibi gönderilir', () {
      // Sabit `true` göndermek göstergeyi yalancı yapardı.
      final api = FakeKitchenHealthApi();
      final monitor = KitchenHealthMonitor(
        api: api,
        collect: () async => const KitchenHealthReport(
          printerOk: false,
          printQueuePending: 4,
          printQueueFailed: 2,
        ),
      );

      return monitor.poll().then((_) {
        expect(api.reports.single.printerOk, isFalse);
        expect(api.reports.single.printQueuePending, 4);
        expect(api.reports.single.printQueueFailed, 2);
      });
    });

    test('hata YUKARI ATILMAZ, durum "ulaşılamıyor" olur', () async {
      final api = FakeKitchenHealthApi()..fails = true;
      final monitor = KitchenHealthMonitor(
        api: api,
        collect: () async => healthy,
      );

      final state = (await monitor.poll()).state;

      expect(state.reachable, isFalse);
      expect(state.everTried, isTrue);
      expect(state.status, isNull);
    });

    test('kopukluk son bilinen sayıları SİLMEZ', () async {
      // "Bugün 12 sipariş (3 dk önce)" bilgisi, hiç sayı görmemekten iyidir.
      final api = FakeKitchenHealthApi(ordersToday: 12);
      final monitor = KitchenHealthMonitor(
        api: api,
        collect: () async => healthy,
        clock: () => DateTime.utc(2026, 8, 5, 9),
      );

      await monitor.poll();
      api.fails = true;
      final state = (await monitor.poll()).state;

      expect(state.reachable, isFalse);
      expect(state.status?.ordersToday, 12);
      expect(state.lastSuccessAt, DateTime.utc(2026, 8, 5, 9));
    });

    test('bağlantı geri gelince sayılar tazelenir', () async {
      final api = FakeKitchenHealthApi(ordersToday: 12)..fails = true;
      final monitor = KitchenHealthMonitor(
        api: api,
        collect: () async => healthy,
      );

      await monitor.poll();
      api
        ..fails = false
        ..ordersToday = 15;
      final state = (await monitor.poll()).state;

      expect(state.reachable, isTrue);
      expect(state.status?.ordersToday, 15);
    });

    test('sunucu hatası da yutulur', () async {
      final monitor = KitchenHealthMonitor(
        api: _ThrowingApi(),
        collect: () async => healthy,
      );

      await expectLater(monitor.poll(), completes);
      expect(monitor.state.reachable, isFalse);
    });

    // ── K-23: test fişi döngüsü ───────────────────────────────────────

    test('BAŞARISIZ YOKLAMA hiç komut yüzeye çıkarmaz', () async {
      // SAHADAKİ DÖNGÜNÜN İKİNCİ HALKASI. Başarısızlıkta durum
      // `copyWith(reachable: false)` ile güncelleniyordu; `copyWith`
      // önceki durumu — içindeki komut listesiyle birlikte — koruyor ve
      // çağıran her başarısız turda son BAŞARILI turun komutlarını
      // yeniden çalıştırıyordu. Bağlantı titrerken dakikada bir test
      // fişi demek.
      final api = FakeKitchenHealthApi(ordersToday: 12, ordersActive: 3)
        ..commands = const [
          KitchenCommand(id: 7, command: KitchenCommand.testReceipt),
        ];
      final monitor = KitchenHealthMonitor(
        api: api,
        collect: () async => healthy,
        clock: () => DateTime.utc(2026, 8, 24, 9),
      );

      expect((await monitor.poll()).state.status?.commands, hasLength(1));

      api.fails = true;
      final state = (await monitor.poll()).state;

      expect(state.status?.commands, isEmpty);

      // SAYAÇLAR BAYAT KALIR: "bugün 12 sipariş (3 dk önce)" bilgisi hiç
      // sayı görmemekten iyidir. Düzeltme komutu düşürmeli, sayıyı değil.
      expect(state.status?.ordersToday, 12);
      expect(state.status?.ordersActive, 3);
      expect(state.lastSuccessAt, DateTime.utc(2026, 8, 24, 9));
    });

    test('TESLİM EDİLEN RAPOR yalnız başarıda geri döner', () async {
      // Çağıran komut sonuçlarını ancak "sunucu aldı" görünce unutabilir;
      // `poll()` bunu söylemezse boşaltma tahmine dayanırdı.
      final api = FakeKitchenHealthApi();
      final monitor = KitchenHealthMonitor(
        api: api,
        collect: () async => healthy,
      );

      expect((await monitor.poll()).delivered, same(healthy));

      api.fails = true;
      expect((await monitor.poll()).delivered, isNull);
    });
  });

  // ── K-23: sonuçların kuyruğu (`KitchenHealthController`) ───────────────
  //
  // Mantık `providers.dart` içinde ve orada olması gerekiyor: sonucun ne
  // zaman unutulacağı, komutu çalıştıran ile raporu gönderen arasındaki
  // sıralamaya bağlı. Bu yüzden testler gerçek sağlayıcı üzerinden koşuyor,
  // ayrı bir taklit üzerinden değil.

  group('KitchenHealthController — komut sonuçları', () {
    test('BAŞARISIZ YOKLAMA komutu yeniden çalıştırmaz', () async {
      var basilanFis = 0;
      final api = FakeKitchenHealthApi()
        ..commands = const [
          KitchenCommand(id: 7, command: KitchenCommand.testReceipt),
        ];

      final kap = _kur(
        api: api,
        kosucu: _kosucu(testFisi: () => basilanFis++),
      );

      kap.read(kitchenHealthProvider);
      await _bekle();

      expect(basilanFis, 1);

      final denetleyici = kap.read(kitchenHealthProvider.notifier);
      api.fails = true;
      await denetleyici.poll();
      await denetleyici.poll();

      expect(
        basilanFis,
        1,
        reason: 'Mutfak her düşen sağlık atımında bir test fişi görmemeli.',
      );
    });

    test('SONUÇLAR düşen raporu atlatır, bir sonraki başarılıda gider', () async {
      // SAHADAKİ DÖNGÜNÜN ÜÇÜNCÜ HALKASI: `_collect()` sonuçları HTTP
      // çağrısından ÖNCE boşaltıyordu ve `poll()` her hatayı yutuyordu.
      // Düşen tek bir atım sonucu sonsuza kaybettiriyor, sunucu
      // `executed_at` yazamadığı için komutu on dakika sonra yeniden
      // gönderiyordu.
      final api = FakeKitchenHealthApi()
        ..commands = const [
          KitchenCommand(id: 7, command: KitchenCommand.testReceipt),
        ];

      final kap = _kur(api: api, kosucu: _kosucu());

      kap.read(kitchenHealthProvider);
      await _bekle();

      expect(api.reports.single.commandResults, isEmpty);

      final denetleyici = kap.read(kitchenHealthProvider.notifier);

      api.fails = true;
      await denetleyici.poll();
      expect(_kimlikler(api.reports[1]), [7]);

      api.fails = false;
      await denetleyici.poll();
      expect(
        _kimlikler(api.reports[2]),
        [7],
        reason: 'Düşen atım sonucu kaybetmemeli.',
      );

      await denetleyici.poll();
      expect(
        api.reports[3].commandResults,
        isEmpty,
        reason: 'Sunucu aldıktan sonra sonuç bir daha gönderilmemeli.',
      );
    });

    test('UÇUŞ SIRASINDA üretilen sonuç boşaltmayla kaybolmaz', () async {
      // Boşaltmanın "hepsini sil" hâli, `_collect()` ile yanıt arasında
      // biten bir komutun sonucunu da düşürürdü: o sonuç hiç
      // gönderilmemişken gönderilmiş sayılırdı. Bu yüzden unutma KİMLİĞE
      // GÖRE.
      final api = _KapiliSaglikApi()
        ..commands = const [
          KitchenCommand(id: 7, command: KitchenCommand.testReceipt),
        ];

      final kap = _kur(api: api, kosucu: _kosucu());

      kap.read(kitchenHealthProvider);
      await _bekle();

      final denetleyici = kap.read(kitchenHealthProvider.notifier);

      // 2. rapor kapıda bekletiliyor; kuyruğunda #7'nin sonucu var.
      api.gateAt = 2;
      final ucustaki = denetleyici.poll();
      await _bekle();

      // Kapı kapalıyken 3. tur baştan sona koşuyor ve YENİ bir sonuç
      // üretiyor (#8). Bu sonuç henüz hiçbir rapora binmedi.
      api.commands = const [
        KitchenCommand(id: 8, command: KitchenCommand.testReceipt),
      ];
      await denetleyici.poll();

      // Kapı açılıyor: 2. rapor yalnız #7'yi teslim etmişti.
      api.gate.complete();
      await ucustaki;

      await denetleyici.poll();

      expect(
        _kimlikler(api.reports.last),
        [8],
        reason: '#8 hiç gönderilmemişti; boşaltma onu düşürmemeli.',
      );
    });
  });
}

// ── Yardımcılar ─────────────────────────────────────────────────────────

List<int> _kimlikler(KitchenHealthReport report) =>
    report.commandResults.map((result) => result.id).toList();

/// Zamanlayıcısız bir sağlık turunun bitmesini bekler.
///
/// Kısa GERÇEK gecikme: toplayıcı yazıcı cihaz dosyasını gerçekten
/// yokluyor (`PrinterProbe.check` → `File.exists`) ve bu bir `dart:io`
/// çağrısı; mikro görev sırasını beklemek yetmez.
Future<void> _bekle() => Future<void>.delayed(const Duration(milliseconds: 30));

/// Dış dünyaya dokunmayan komut koşucusu.
CommandRunner _kosucu({void Function()? testFisi}) => CommandRunner(
  CommandActions(
    printTestReceipt: () async {
      testFisi?.call();
      return null;
    },
    reprint: (orderId, type) async => null,
    clearFailed: () async => null,
    silenceAlarm: () async => null,
    restart: () async => null,
    update: () async => null,
    unpair: () async => null,
    clearQueue: () async => null,
  ),
);

/// Alt süreç açan, diske yazan ve ağa çıkan her şeyi sahteleyen kap.
ProviderContainer _kur({
  required KitchenHealthApi api,
  required CommandRunner kosucu,
}) {
  final kap = ProviderContainer(
    overrides: [
      kitchenHealthApiProvider.overrideWithValue(api),
      commandRunnerProvider.overrideWithValue(kosucu),
      kdsSettingsStoreProvider.overrideWithValue(FakeKdsSettingsStore()),
      printerDeviceProvider.overrideWithValue(_NullPrinter()),
      kitchenServiceProvider.overrideWithValue(FakeKitchenService()),
      alarmPlayerProvider.overrideWithValue(SilentAlarmPlayer()),
    ],
  );
  addTearDown(kap.dispose);

  return kap;
}

class _NullPrinter implements PrinterDevice {
  @override
  Future<void> write(Uint8List bytes) async {}
}

class _ThrowingApi implements KitchenHealthApi {
  @override
  Future<KitchenHealthStatus> report(KitchenHealthReport report) async =>
      throw const ApiException(
        code: ApiErrorCode.serverError,
        message: 'Sunucu hatası',
        statusCode: 500,
      );
}

/// Belirli sıradaki çağrıyı uçuşta bekleten sahte uç.
///
/// [FakeKitchenHealthApi] anında dönüyor ve "istek yoldayken" olan bir
/// şeyi ölçmenin başka yolu yok.
class _KapiliSaglikApi implements KitchenHealthApi {
  final List<KitchenHealthReport> reports = <KitchenHealthReport>[];

  /// Kaçıncı çağrı kapıda bekletilecek (1'den başlar).
  int? gateAt;

  final Completer<void> gate = Completer<void>();

  /// Bir sonraki yanıtta inecek komutlar; teslim edildikten sonra boşalır.
  List<KitchenCommand> commands = const <KitchenCommand>[];

  int _calls = 0;

  @override
  Future<KitchenHealthStatus> report(KitchenHealthReport report) async {
    reports.add(report);
    _calls++;

    if (_calls == gateAt) await gate.future;

    final teslim = commands;
    commands = const <KitchenCommand>[];

    return KitchenHealthStatus(
      serverTime: DateTime.utc(2026, 8, 24, 12),
      ordersToday: 0,
      ordersActive: 0,
      commands: teslim,
    );
  }
}
