/// Sağlık bildirimi — `POST /kitchen/health`.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/data/kitchen_health.dart';

import 'fake_kitchen_health_api.dart';

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

      final state = await monitor.poll();

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

      final state = await monitor.poll();

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
      final state = await monitor.poll();

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
      final state = await monitor.poll();

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
  });
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
