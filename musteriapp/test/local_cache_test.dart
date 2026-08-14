/// Çevrimdışı davranışın temeli — `docs/07-musteriapp.md` §5.
///
/// Son çekilen menü cihazda durmalı, bozuk kayıt uygulamayı kilitlememeli.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musteriapp/src/data/local_cache.dart';
import 'package:musteriapp/src/data/token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _location = Location(
  id: 1,
  name: 'Benim Lezzet Dünyam',
  slug: 'catering',
  isOpen: true,
  orderingEnabled: true,
  minOrderTotal: 25000,
  paymentMethods: [PaymentMethod.cash, PaymentMethod.account],
  orderCutoff: '16:00',
);

const _categories = [
  MenuCategory(
    id: 10,
    name: 'Ana Yemekler',
    sort: 1,
    items: [
      MenuItem(
        id: 101,
        name: 'Tavuk Sote',
        price: 18500,
        currency: 'TRY',
        isAvailable: true,
        options: [
          MenuOption(
            id: 1,
            name: 'Porsiyon',
            type: 'radio',
            required: true,
            values: [
              MenuOptionValue(id: 11, name: 'Tam', priceDelta: 0),
              MenuOptionValue(id: 12, name: 'Bol', priceDelta: 2500),
            ],
          ),
        ],
      ),
    ],
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late LocalCache cache;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cache = LocalCache(prefs);
  });

  group('LocalCache — menü', () {
    test('yazılan menü aynı vitrin için geri okunur', () async {
      await cache.writeMenu(1, _categories);

      final restored = cache.readMenu(1);
      expect(restored, isNotNull);
      expect(restored!.single.name, 'Ana Yemekler');

      final item = restored.single.items.single;
      expect(item.id, 101);
      expect(item.price, 18500);
      expect(item.options.single.values.last.priceDelta, 2500);
      expect(cache.readMenuTimestamp(), isNotNull);
    });

    test('başka vitrinin menüsü döndürülmez', () async {
      await cache.writeMenu(1, _categories);

      expect(cache.readMenu(2), isNull);
    });

    test('hiç menü yazılmadıysa null döner', () {
      expect(cache.readMenu(1), isNull);
      expect(cache.readMenuTimestamp(), isNull);
    });

    test('bozuk kayıt çökme değil null üretir', () async {
      await cache.writeMenu(1, _categories);
      await prefs.setString('bld.cache.menu', '{bozuk json');

      expect(cache.readMenu(1), isNull);
    });
  });

  group('LocalCache — vitrin', () {
    test('vitrin geri okunur', () async {
      await cache.writeLocation(_location);

      final restored = cache.readLocation();
      expect(restored, _location);
      expect(restored!.selectablePaymentMethods, [
        PaymentMethod.cash,
        PaymentMethod.account,
      ]);
    });

    test('bozuk kayıt null üretir', () async {
      await prefs.setString('bld.cache.location', 'null');

      expect(cache.readLocation(), isNull);
    });
  });

  group('LocalCache — sepet şema sürümü', () {
    test('yazılan sepet geri okunur', () async {
      await cache.writeCart({'locationId': 1, 'serviceDate': '2026-08-20'});

      expect(cache.readCart(), {'locationId': 1, 'serviceDate': '2026-08-20'});
    });

    test('SÜRÜMSÜZ eski sepet okunmaz ve SİLİNİR', () async {
      // B-19 öncesi sepet doğrudan `Cart` JSON'uydu ve servis günü yoktu.
      // Ona bugünün tarihini yazarak göç ettirmek, dünkü menüden doldurulmuş
      // bir sepeti sessizce bugüne bağlamak olurdu.
      await prefs.setString(
        'bld.cart',
        '{"lines":[],"locationId":1}',
      );

      expect(cache.readCart(), isNull);
      // Silme beklenmiyor (`unawaited`); mikro görev kuyruğunun dönmesi için
      // bir kere await ediliyor.
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getString('bld.cart'), isNull);
    });

    test('BAŞKA bir sürümden kalan sepet de okunmaz', () async {
      await prefs.setString(
        'bld.cart',
        '{"v":${LocalCache.cartSchemaVersion + 1},"cart":{"locationId":9}}',
      );

      expect(cache.readCart(), isNull);
    });

    test('null yazmak kaydı siler', () async {
      await cache.writeCart({'locationId': 1});
      await cache.writeCart(null);

      expect(cache.readCart(), isNull);
    });
  });

  group('LocalCache — günün menüsü', () {
    DailyMenu menu(String date) => DailyMenu(
      id: 7,
      date: date,
      currency: 'TRY',
      closed: false,
      isOrderable: true,
      title: 'Ev Yemeği Menüsü',
      items: const [
        MenuItem(
          id: 101,
          name: 'Mercimek Çorbası',
          price: 6000,
          currency: 'TRY',
          isAvailable: true,
        ),
      ],
    );

    test('gün başına ayrı kayıt tutulur', () async {
      await cache.writeDailyMenu(1, menu('2999-08-20'));
      await cache.writeDailyMenu(1, menu('2999-08-21'));

      // Gün şeridinde ileri geri gezinen kullanıcı çevrimdışı kalırsa
      // gezdiği günlerin hepsi elinde kalmalı.
      expect(cache.readDailyMenu(1, '2999-08-20')?.title, 'Ev Yemeği Menüsü');
      expect(cache.readDailyMenu(1, '2999-08-21')?.date, '2999-08-21');
    });

    test('başka vitrinin menüsü döndürülmez', () async {
      await cache.writeDailyMenu(1, menu('2999-08-20'));

      expect(cache.readDailyMenu(2, '2999-08-20'), isNull);
    });

    test('GEÇMİŞ günler yazma sırasında budanır', () async {
      // Geçmişe sipariş verilemiyor; o kayıtlar bir daha okunmayacak.
      await prefs.setString('bld.cache.gunun-menusu.1.2000-01-01', '{}');
      await cache.writeDailyMenu(1, menu('2999-08-20'));

      expect(prefs.getString('bld.cache.gunun-menusu.1.2000-01-01'), isNull);
      expect(cache.readDailyMenu(1, '2999-08-20'), isNotNull);
    });

    test('bozuk kayıt null üretir', () async {
      await prefs.setString('bld.cache.gunun-menusu.1.2999-08-20', 'null');

      expect(cache.readDailyMenu(1, '2999-08-20'), isNull);
    });
  });

  group('LocalCache — menü takvimi', () {
    const days = [
      MenuCalendarDay(
        date: '2000-01-01',
        hasMenu: true,
        closed: false,
        isOrderable: false,
      ),
      MenuCalendarDay(
        date: '2999-08-20',
        hasMenu: true,
        closed: false,
        isOrderable: true,
      ),
    ];

    test('geçmiş günler OKUMA sırasında ayıklanır', () async {
      await cache.writeMenuCalendar(1, days);

      // Kayıt dün yazılmış olabilir; içindeki "dün" bugün artık
      // seçilebilir bir gün değil.
      final restored = cache.readMenuCalendar(1, today: '2026-08-20');
      expect(restored, hasLength(1));
      expect(restored!.single.date, '2999-08-20');
    });

    test('başka vitrinin takvimi döndürülmez', () async {
      await cache.writeMenuCalendar(1, days);

      expect(cache.readMenuCalendar(2, today: '2026-08-20'), isNull);
    });
  });

  group('SharedPreferencesTokenStore', () {
    test('yaz, oku, sil', () async {
      final store = SharedPreferencesTokenStore(prefs);

      expect(await store.read(), isNull);

      await store.write('tok_123');
      expect(await store.read(), 'tok_123');

      await store.clear();
      expect(await store.read(), isNull);
    });

    test('boş dize token sayılmaz', () async {
      final store = SharedPreferencesTokenStore(prefs);
      await store.write('');

      expect(await store.read(), isNull);
    });

    test('varsayılan hatırlamaktır', () async {
      // Güncelleyen kullanıcı oturumundan düşmemeli: kayıt yokken de
      // uygulamanın bugüne kadarki davranışı geçerli olmalı.
      expect(SharedPreferencesTokenStore(prefs).remember, isTrue);
    });

    test('hatırlanmayan oturumun token\'ı diske yazılmaz', () async {
      final store = SharedPreferencesTokenStore(prefs);
      await store.setRemember(value: false);
      await store.write('tok_gecici');

      // Aynı örnek okuyabilmeli — uygulama açık kaldığı sürece oturum sürer.
      expect(await store.read(), 'tok_gecici');
      // Ama diskte iz kalmamalı: yeni bir örnek (= uygulama yeniden açıldı)
      // oturumu görmemeli.
      expect(await SharedPreferencesTokenStore(prefs).read(), isNull);
    });

    test('hatırlamaya geçilince açık oturum diske taşınır', () async {
      final store = SharedPreferencesTokenStore(prefs);
      await store.setRemember(value: false);
      await store.write('tok_gecici');

      await store.setRemember(value: true);

      expect(await SharedPreferencesTokenStore(prefs).read(), 'tok_gecici');
    });

    test('hatırlamayı kapatmak diskteki token\'ı siler', () async {
      final store = SharedPreferencesTokenStore(prefs);
      await store.write('tok_kalici');

      await store.setRemember(value: false);

      // Oturum bu örnekte sürüyor ama disk temiz.
      expect(await store.read(), 'tok_kalici');
      expect(await SharedPreferencesTokenStore(prefs).read(), isNull);
    });

    test('hatırlanmayan giriş önceki oturumun token\'ını siler', () async {
      // Eski token diskte kalsaydı, "beni hatırlama" diyen kullanıcının
      // uygulaması yeniden açıldığında ÖNCEKİ hesapla oturum açardı.
      final store = SharedPreferencesTokenStore(prefs);
      await store.write('tok_eski');

      await store.setRemember(value: false);
      await store.write('tok_yeni');

      expect(prefs.getString('bld.auth.token'), isNull);
    });
  });
}
