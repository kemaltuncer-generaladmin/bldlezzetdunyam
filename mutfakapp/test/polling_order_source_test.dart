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

    test('süren istek bitmeden çağrılsa bile TAM liste ister', () async {
      // HATA: bayrak beklemeden önce kuruluyordu. O sırada tamamlanan istek
      // başarıyla bitip bayrağı sıfırlıyor, elle yenileme sessizce artımlı bir
      // çekmeye dönüşüyor ve kaçırılan durum değişimleri toparlanmıyordu.
      final kitchen = FakeKitchenService()
        ..responses.add(makePage([makeOrder(id: 1)]));

      final source = PollingOrderSource(
        kitchen: kitchen,
        interval: const Duration(hours: 1),
        heartbeatInterval: const Duration(hours: 1),
      )..start();

      // `settle` YOK: ilk istek hâlâ uçarken yenileme isteniyor.
      await source.refresh();
      await source.dispose();

      expect(kitchen.ordersCalls, hasLength(greaterThanOrEqualTo(2)));
      expect(kitchen.ordersCalls.last.since, isNull);
    });
  });

  group('Listenin yaşı', () {
    test('başarılı çekmeden önce bilinmez', () async {
      final source = PollingOrderSource(kitchen: FakeKitchenService());
      expect(source.lastUpdatedAt, isNull);
      await source.dispose();
    });

    test('başarılı çekmede damgalanır', () async {
      final kitchen = FakeKitchenService()
        ..responses.add(makePage([makeOrder(id: 1)]));

      final source = PollingOrderSource(
        kitchen: kitchen,
        interval: const Duration(hours: 1),
        heartbeatInterval: const Duration(hours: 1),
        clock: () => DateTime.utc(2026, 8, 5, 9),
      )..start();
      await settle();

      expect(source.lastUpdatedAt, DateTime.utc(2026, 8, 5, 9));
      await source.dispose();
    });

    test('hata damgayı GERİYE ALMAZ', () async {
      // Ekrandaki liste hâlâ o andaki listedir; yaşı da o andan sayılmalı.
      final kitchen = FakeKitchenService()
        ..responses.addAll([
          makePage([makeOrder(id: 1)]),
          const ApiException.network(),
        ]);

      final source = PollingOrderSource(
        kitchen: kitchen,
        interval: const Duration(milliseconds: 10),
        heartbeatInterval: const Duration(hours: 1),
        clock: () => DateTime.utc(2026, 8, 5, 9),
      )..start();
      await settle();

      expect(source.lastUpdatedAt, DateTime.utc(2026, 8, 5, 9));
      await source.dispose();
    });
  });

  group('Aralık değişikliği', () {
    test('kaynağı yeniden kurmadan uygulanır', () async {
      // HATA: aralık sağlayıcıda `watch` ediliyordu; ayarlar ekranındaki artı
      // düğmesine her basış kaynağı kapatıp yenisini açıyor ve pano ilk yanıt
      // gelene kadar BOŞ kalıyordu.
      final kitchen = FakeKitchenService()
        ..responses.add(makePage([makeOrder(id: 1)]));

      final source = PollingOrderSource(
        kitchen: kitchen,
        interval: const Duration(hours: 1),
        heartbeatInterval: const Duration(hours: 1),
      )..start();
      await settle();

      final before = kitchen.ordersCalls.length;
      source.interval = const Duration(milliseconds: 10);
      await settle();

      expect(source.snapshot, hasLength(1), reason: 'Liste silinmemeli.');
      expect(
        kitchen.ordersCalls.length,
        greaterThan(before),
        reason: 'Yeni aralık hemen uygulanmalı.',
      );
      await source.dispose();
    });

    test('aynı değer bir şey değiştirmez', () async {
      final kitchen = FakeKitchenService()
        ..responses.add(makePage([makeOrder(id: 1)]));

      final source = PollingOrderSource(
        kitchen: kitchen,
        interval: const Duration(hours: 1),
        heartbeatInterval: const Duration(hours: 1),
      )..start();
      await settle();

      final before = kitchen.ordersCalls.length;
      source.interval = const Duration(hours: 1);
      await settle();

      expect(kitchen.ordersCalls, hasLength(before));
      await source.dispose();
    });

    test(
      'elden çıkarıldıktan sonra aralık yazmak zamanlayıcı kurmaz',
      () async {
        final kitchen = FakeKitchenService()
          ..responses.add(makePage([makeOrder(id: 1)]));

        final source = PollingOrderSource(
          kitchen: kitchen,
          interval: const Duration(hours: 1),
          heartbeatInterval: const Duration(hours: 1),
        )..start();
        await settle();
        await source.dispose();

        final before = kitchen.ordersCalls.length;
        source.interval = const Duration(milliseconds: 5);
        await settle();

        expect(kitchen.ordersCalls, hasLength(before));
      },
    );
  });

  group('Akışa geç katılma', () {
    test('dinlemeye başlayan güncel listeyi alır', () async {
      final kitchen = FakeKitchenService()
        ..responses.add(makePage([makeOrder(id: 1)]));

      final source = PollingOrderSource(
        kitchen: kitchen,
        interval: const Duration(hours: 1),
        heartbeatInterval: const Duration(hours: 1),
      )..start();
      await settle();

      // Yayın çoktan olmuş; yeni dinleyici yine de listeyi görmeli.
      expect(await source.watch().first, hasLength(1));
      expect(await source.connection.first, OrderSourceConnection.connected);
      await source.dispose();
    });

    test('güncel değerden SONRAKİ yayınlar kaybolmaz', () async {
      // HATA: `yield mevcut; yield* akış;` deseninde iki adım arasına düşen
      // olay hiçbir dinleyiciye ulaşmadan kayboluyordu.
      final kitchen = FakeKitchenService()
        ..responses.addAll([
          makePage(const []),
          makePage([makeOrder(id: 7)]),
        ]);

      final source = PollingOrderSource(
        kitchen: kitchen,
        interval: const Duration(hours: 1),
        heartbeatInterval: const Duration(hours: 1),
      )..start();
      await settle();

      final seen = <List<KitchenOrder>>[];
      final subscription = source.watch().listen(seen.add);
      // Abonelik kurulur kurulmaz — güncel değer henüz teslim edilmeden —
      // yeni bir yayın tetikleniyor.
      await source.refresh();
      await settle();
      await subscription.cancel();

      expect(seen.last, hasLength(1));
      expect(seen.last.single.id, 7);
      await source.dispose();
    });
  });

  /// Gün dönümü — B-19.
  ///
  /// Kasa kesintisiz çalışıyor ve tam yenileme yalnızca açılışta ve bağlantı
  /// koptuğunda yapılıyordu. Gece yarısının iki bedeli vardı: dünün kartları
  /// tahtada kalıyordu ve ileri tarihli siparişler pişecekleri gün hiç
  /// görünmüyordu.
  group('İşletme günü dönümü', () {
    /// Değiştirilebilir sahte saat: gece yarısını testin içinde geçiyoruz.
    ({DateTime Function() read, void Function(DateTime) set}) fakeClock(
      DateTime start,
    ) {
      var now = start;
      return (read: () => now, set: (DateTime value) => now = value);
    }

    test('gün değişince tam yenileme yapılır', () async {
      final kitchen = FakeKitchenService()
        ..responses.addAll([
          makePage([makeOrder(id: 1)]),
          makePage([makeOrder(id: 2)]),
        ]);

      // 21:00 UTC = 00:00 İstanbul ertesi gün. Bir dakika öncesinden
      // başlıyoruz ki ilk çekme hâlâ "dün" olsun.
      final clock = fakeClock(DateTime.utc(2026, 8, 4, 20, 59));

      final source = PollingOrderSource(
        kitchen: kitchen,
        interval: const Duration(milliseconds: 10),
        heartbeatInterval: const Duration(hours: 1),
        clock: clock.read,
      )..start();
      await settle();

      // İlk çekme zaten tam yenileme; sonraki çekmeler artımlı.
      expect(kitchen.ordersCalls.first.since, isNull);
      final beforeMidnight = kitchen.ordersCalls
          .where((call) => call.since == null)
          .length;
      expect(beforeMidnight, 1, reason: 'Gün dönmeden ikinci tam yenileme olmamalı.');

      // Gece yarısını geç.
      clock.set(DateTime.utc(2026, 8, 4, 21, 1));
      await settle(60);

      // Gün dönümü İKİNCİ bir tam yenileme tetiklemeli. `.last` bakmıyoruz:
      // 10 ms aralıkta tam yenilemeden sonra artımlı çekmeler sürüyor ve son
      // çağrı doğal olarak artımlı oluyor.
      final afterMidnight = kitchen.ordersCalls
          .where((call) => call.since == null)
          .length;
      expect(
        afterMidnight,
        2,
        reason: 'Gün dönümünde tam yenileme bekleniyordu.',
      );

      await source.dispose();
    });

    test('dünün kartları gün dönümünde tahtadan kalkar', () async {
      // Sunucu gece yarısından sonra dünkü siparişi BİR DAHA GÖNDERMEZ
      // (bugünün siparişlerini filtreliyor). Tam yenileme olmadan kart
      // `_known` içinde sonsuza dek kalırdı.
      final kitchen = FakeKitchenService()
        ..responses.addAll([
          makePage([makeOrder(id: 1, status: OrderStatus.hazir)]),
          makePage(const []),
        ]);

      final clock = fakeClock(DateTime.utc(2026, 8, 4, 20, 59));

      final source = PollingOrderSource(
        kitchen: kitchen,
        interval: const Duration(milliseconds: 10),
        heartbeatInterval: const Duration(hours: 1),
        clock: clock.read,
      )..start();
      await settle();

      final seen = <List<KitchenOrder>>[];
      final subscription = source.watch().listen(seen.add);

      clock.set(DateTime.utc(2026, 8, 4, 21, 1));
      await settle(60);
      await subscription.cancel();

      expect(
        seen.last,
        isEmpty,
        reason: 'Dünün hâlâ `hazir` kartı tahtada kalmamalı.',
      );

      await source.dispose();
    });

    test('aynı gün içinde tam yenileme TETİKLENMEZ', () async {
      // Aksi hâlde her yoklama tam liste isterdi ve artımlı çekmenin anlamı
      // kalmazdı.
      final kitchen = FakeKitchenService()
        ..responses.addAll([
          makePage([makeOrder(id: 1)]),
          makePage([makeOrder(id: 1)]),
          makePage([makeOrder(id: 1)]),
        ]);

      final clock = fakeClock(DateTime.utc(2026, 8, 4, 9));

      final source = PollingOrderSource(
        kitchen: kitchen,
        interval: const Duration(milliseconds: 10),
        heartbeatInterval: const Duration(hours: 1),
        clock: clock.read,
      )..start();
      await settle();

      clock.set(DateTime.utc(2026, 8, 4, 15));
      await settle(60);

      expect(
        kitchen.ordersCalls.length,
        greaterThanOrEqualTo(2),
        reason: 'En az iki çekme olmalıydı.',
      );
      expect(
        kitchen.ordersCalls.last.since,
        isNotNull,
        reason: 'Gün değişmediği için artımlı çekme sürmeli.',
      );

      await source.dispose();
    });

    test('gün dönümündeki hata tam yenilemeyi YUTMAZ', () async {
      // Gün işareti başarıdan SONRA konuyor: gece yarısına denk gelen tek bir
      // ağ hatası tam yenilemeyi sessizce atlatmamalı.
      final kitchen = FakeKitchenService()
        ..responses.addAll([
          makePage([makeOrder(id: 1)]),
          const ApiException.network(),
          makePage([makeOrder(id: 2)]),
        ]);

      final clock = fakeClock(DateTime.utc(2026, 8, 4, 20, 59));

      final source = PollingOrderSource(
        kitchen: kitchen,
        interval: const Duration(milliseconds: 10),
        heartbeatInterval: const Duration(hours: 1),
        clock: clock.read,
      )..start();
      await settle();

      clock.set(DateTime.utc(2026, 8, 4, 21, 1));
      // Gün dönümündeki çekme hata alıyor. Gün işareti başarıdan sonra
      // konduğu için bayrak DURUYOR; bir sonraki başarılı çekme hâlâ tam
      // yenileme olmalı. (Geri çekilme 5 sn, o yüzden elle tetikliyoruz.)
      await settle(60);
      await source.refresh();
      await settle(60);

      final fullRefreshes = kitchen.ordersCalls
          .where((call) => call.since == null)
          .length;
      expect(
        fullRefreshes,
        greaterThanOrEqualTo(2),
        reason: 'Hatadan sonra da tam yenileme beklenmeli.',
      );

      await source.dispose();
    });
  });
}
