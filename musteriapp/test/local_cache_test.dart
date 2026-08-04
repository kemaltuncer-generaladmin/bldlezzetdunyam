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
  });
}
