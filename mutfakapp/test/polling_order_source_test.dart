/// `K-05` davranış testleri — `docs/05-mutfakapp.md` §4,
/// `docs/10-test-kabul.md` S4 (ağ hatası → geri çekilme → kurtarma).
///
/// Zamanlayıcılar gerçek ama aralıklar milisaniyeye indirilmiştir; testin
/// 5 saniye beklemesi gerekmez.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/data/polling_order_source.dart';

import 'fake_kitchen_service.dart';

/// Zamanlayıcıların ilerlemesine izin verir.
Future<void> settle([int milliseconds = 40]) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

void main() {
  group('Geri çekilme takvimi', () {
    const base = Duration(seconds: 5);
    const max = Duration(seconds: 60);

    test('5 → 10 → 20 → 40 → 60 ve orada kalır', () {
      Duration at(int failures) => PollingOrderSource.backoffDelay(
        base: base,
        consecutiveFailures: failures,
        max: max,
      );

      expect(at(1), const Duration(seconds: 5));
      expect(at(2), const Duration(seconds: 10));
      expect(at(3), const Duration(seconds: 20));
      expect(at(4), const Duration(seconds: 40));
      expect(at(5), max);
      expect(at(9), max);
      expect(at(1000), max);
    });

    test('hata yokken normal aralık', () {
      expect(
        PollingOrderSource.backoffDelay(
          base: base,
          consecutiveFailures: 0,
          max: max,
        ),
        base,
      );
    });
  });

  group('Artımlı çekme', () {
    late FakeKitchenService kitchen;
    late PollingOrderSource source;

    setUp(() => kitchen = FakeKitchenService());
    tearDown(() => source.dispose());

    PollingOrderSource build() => source = PollingOrderSource(
      kitchen: kitchen,
      interval: const Duration(milliseconds: 10),
      heartbeatInterval: const Duration(milliseconds: 15),
    );

    test('ilk istek tam listedir: since yok, tamamlananlar yok', () async {
      kitchen.responses.add(makePage([makeOrder(id: 1)]));
      build().start();
      await settle();

      expect(kitchen.ordersCalls.first.since, isNull);
      expect(kitchen.ordersCalls.first.includeCompleted, isFalse);
    });

    test('sonraki istekler yanıttaki server_time ile since gönderir', () async {
      final serverTime = DateTime.utc(2026, 8, 4, 12, 30);
      kitchen.responses.add(
        makePage([makeOrder(id: 1)], serverTime: serverTime),
      );
      build().start();
      await settle();

      expect(kitchen.ordersCalls.length, greaterThan(1));
      expect(kitchen.ordersCalls[1].since, serverTime);
      // Tamamlanmış sipariş ancak böyle görünür; yoksa kart ekranda kalırdı.
      expect(kitchen.ordersCalls[1].includeCompleted, isTrue);
    });

    test('teslim edilen sipariş listeden düşer', () async {
      kitchen.responses
        ..add(makePage([makeOrder(id: 1), makeOrder(id: 2)]))
        ..add(makePage([makeOrder(id: 1, status: OrderStatus.teslimEdildi)]));

      build().start();
      await settle();

      expect(source.snapshot.map((o) => o.id), [2]);
    });

    test('iptal edilen sipariş listeden düşer', () async {
      kitchen.responses
        ..add(makePage([makeOrder(id: 7)]))
        ..add(makePage([makeOrder(id: 7, status: OrderStatus.iptal)]));

      build().start();
      await settle();

      expect(source.snapshot, isEmpty);
    });

    test('liste oluşturma zamanına göre sıralı gelir', () async {
      kitchen.responses.add(
        makePage([
          makeOrder(id: 3, createdAt: DateTime.utc(2026, 8, 4, 11)),
          makeOrder(id: 1, createdAt: DateTime.utc(2026, 8, 4, 9)),
          makeOrder(id: 2, createdAt: DateTime.utc(2026, 8, 4, 10)),
        ]),
      );

      build().start();
      await settle();

      expect(source.snapshot.map((o) => o.id), [1, 2, 3]);
    });

    test('watch abone olur olmaz son bilinen listeyi verir', () async {
      kitchen.responses.add(makePage([makeOrder(id: 5)]));
      build().start();
      await settle();

      expect(await source.watch().first, hasLength(1));
    });
  });

  group('Bağlantı kaybı ve kurtarma', () {
    late FakeKitchenService kitchen;
    late PollingOrderSource source;

    setUp(() => kitchen = FakeKitchenService());
    tearDown(() => source.dispose());

    test('ağ hatasında liste korunur, durum "bağlantı yok" olur', () async {
      kitchen.responses
        ..add(makePage([makeOrder(id: 1)]))
        ..add(const ApiException.network());

      source = PollingOrderSource(
        kitchen: kitchen,
        interval: const Duration(milliseconds: 10),
        heartbeatInterval: const Duration(hours: 1),
      )..start();
      await settle();

      expect(source.connectionState, OrderSourceConnection.disconnected);
      // S4 adım 4: son bilinen liste ekranda kalır.
      expect(source.snapshot, hasLength(1));
    });

    test('bağlantı geri gelince tam yenileme yapılır', () async {
      kitchen.responses
        ..add(makePage([makeOrder(id: 1)]))
        ..add(const ApiException.network())
        ..add(makePage([makeOrder(id: 2)]));

      source = PollingOrderSource(
        kitchen: kitchen,
        interval: const Duration(milliseconds: 10),
        heartbeatInterval: const Duration(hours: 1),
      )..start();
      await settle(80);

      // Üçüncü çağrı kurtarma çağrısıdır: `since` yok, tam liste istenir.
      expect(kitchen.ordersCalls[2].since, isNull);
      expect(kitchen.ordersCalls[2].includeCompleted, isFalse);
      expect(source.connectionState, OrderSourceConnection.connected);
      // Tam yenileme eskisini siler: artık yalnızca sunucunun dediği vardır.
      expect(source.snapshot.map((o) => o.id), [2]);
    });

    test('geri çekilme uygulanır — hemen tekrar denenmez', () async {
      kitchen.responses.add(const ApiException.network());

      source = PollingOrderSource(
        kitchen: kitchen,
        interval: const Duration(milliseconds: 200),
        heartbeatInterval: const Duration(hours: 1),
      )..start();
      await settle(60);

      expect(kitchen.ordersCalls, hasLength(1));
    });

    test('cihaz iptal edilirse yeniden denenmez', () async {
      kitchen.responses.add(
        const ApiException(
          code: ApiErrorCode.deviceRevoked,
          message: 'Cihaz iptal edildi.',
          statusCode: 403,
        ),
      );

      source = PollingOrderSource(
        kitchen: kitchen,
        interval: const Duration(milliseconds: 10),
        heartbeatInterval: const Duration(milliseconds: 10),
      )..start();
      await settle(60);

      expect(source.connectionState, OrderSourceConnection.revoked);
      expect(kitchen.ordersCalls, hasLength(1));
      expect(kitchen.heartbeatCount, isZero);
    });

    test('401 de eşleme ekranına götürür', () async {
      kitchen.responses.add(
        const ApiException(
          code: ApiErrorCode.unauthenticated,
          message: 'Oturum yok.',
          statusCode: 401,
        ),
      );

      source = PollingOrderSource(
        kitchen: kitchen,
        interval: const Duration(milliseconds: 10),
        heartbeatInterval: const Duration(hours: 1),
      )..start();
      await settle();

      expect(source.connectionState, OrderSourceConnection.revoked);
    });

    test('beklenmeyen hata tipi de polling\'i durdurmaz', () async {
      kitchen.responses
        ..add(StateError('bilinmeyen çökme') as Object)
        ..add(makePage([makeOrder(id: 1)]));

      source = PollingOrderSource(
        kitchen: kitchen,
        interval: const Duration(milliseconds: 10),
        heartbeatInterval: const Duration(hours: 1),
      )..start();
      await settle(80);

      expect(source.connectionState, OrderSourceConnection.connected);
    });
  });

  group('Canlılık bildirimi', () {
    test('düzenli aralıklarla gönderilir', () async {
      final kitchen = FakeKitchenService()
        ..responses.add(makePage([makeOrder(id: 1)]));

      final source = PollingOrderSource(
        kitchen: kitchen,
        interval: const Duration(milliseconds: 200),
        heartbeatInterval: const Duration(milliseconds: 10),
      )..start();
      await settle(60);
      await source.dispose();

      expect(kitchen.heartbeatCount, greaterThanOrEqualTo(2));
    });
  });

  group('refresh()', () {
    test('tam liste ister', () async {
      final kitchen = FakeKitchenService()
        ..responses.add(makePage([makeOrder(id: 1)]));

      final source = PollingOrderSource(
        kitchen: kitchen,
        interval: const Duration(hours: 1),
        heartbeatInterval: const Duration(hours: 1),
      )..start();
      await settle();

      await source.refresh();
      await source.dispose();

      expect(kitchen.ordersCalls.last.since, isNull);
      expect(kitchen.ordersCalls.last.includeCompleted, isFalse);
    });
  });
}
