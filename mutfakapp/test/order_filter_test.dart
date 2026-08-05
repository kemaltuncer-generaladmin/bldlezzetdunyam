/// Sipariş arama testleri.
///
/// Türkçe büyük/küçük harf tuzağı burada gerçek bir hata kaynağı: `"İ"`nin
/// küçüğü `"i"`dir ama Dart'ın dilden bağımsız `toLowerCase()`'i `"i̇"`
/// üretir ve arama tutmaz. Personel "İzmir" yazıp sonuç alamazsa arama
/// kutusuna bir daha dokunmaz.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/kds/order_filter.dart';

import 'fake_kitchen_service.dart';

void main() {
  final order = makeOrder(
    id: 5012,
    items: const [
      KitchenOrderItem(
        name: 'Mercimek Çorbası',
        quantity: 2,
        options: ['Büyük'],
        note: 'Limonsuz',
      ),
      KitchenOrderItem(name: 'Pilav', quantity: 1),
    ],
    customerNote: 'Kapıda zili çalmayın',
  );

  group('orderMatchesQuery', () {
    test('boş sorgu her siparişle eşleşir', () {
      expect(orderMatchesQuery(order, ''), isTrue);
      expect(orderMatchesQuery(order, '   '), isTrue);
    });

    test('sipariş numarasının parçası yakalar', () {
      expect(orderMatchesQuery(order, '5012'), isTrue);
      expect(orderMatchesQuery(order, 'S-5012'), isTrue);
      expect(orderMatchesQuery(order, '9999'), isFalse);
    });

    test('ürün adı aranabilir', () {
      expect(orderMatchesQuery(order, 'pilav'), isTrue);
      expect(orderMatchesQuery(order, 'lahmacun'), isFalse);
    });

    test('seçenek ve satır notu aranabilir', () {
      expect(orderMatchesQuery(order, 'büyük'), isTrue);
      expect(orderMatchesQuery(order, 'limonsuz'), isTrue);
    });

    test('sipariş notu aranabilir', () {
      expect(orderMatchesQuery(order, 'zili'), isTrue);
    });

    test('Türkçe büyük harf küçük harfle eşleşir', () {
      expect(orderMatchesQuery(order, 'MERCİMEK'), isTrue);
      expect(orderMatchesQuery(order, 'ÇORBASI'), isTrue);
    });

    test('birden çok terim VE ile bağlanır', () {
      expect(orderMatchesQuery(order, 'mercimek pilav'), isTrue);
      expect(orderMatchesQuery(order, 'mercimek lahmacun'), isFalse);
    });

    test('terim sırası önemsizdir', () {
      expect(orderMatchesQuery(order, 'pilav mercimek'), isTrue);
    });

    test('müşteri etiketi aranabilir', () {
      final labelled = order.copyWith(customerLabel: 'Ayşe Y.');
      expect(orderMatchesQuery(labelled, 'ayşe'), isTrue);
    });
  });

  group('filterOrders', () {
    final orders = [
      order,
      makeOrder(
        id: 5013,
        items: const [KitchenOrderItem(name: 'Pilav', quantity: 3)],
      ),
      makeOrder(
        id: 5014,
        items: const [KitchenOrderItem(name: 'Tost', quantity: 1)],
      ),
    ];

    test('boş sorguda liste aynen döner', () {
      expect(identical(filterOrders(orders, ''), orders), isTrue);
    });

    test('eşleşenleri sırayı bozmadan döndürür', () {
      final result = filterOrders(orders, 'pilav');
      expect(result.map((order) => order.id), [5012, 5013]);
    });

    test('hiçbiri eşleşmezse boş liste döner', () {
      expect(filterOrders(orders, 'kebap'), isEmpty);
    });
  });

  test('normalizeQuery kırpar ve Türkçeye duyarlı küçültür', () {
    expect(normalizeQuery('  İZMİR  '), 'izmir');
  });

  test('searchHaystack tüm aranabilir alanları toplar', () {
    final haystack = searchHaystack(order);

    expect(haystack, contains('s-5012'));
    expect(haystack, contains('mercimek çorbası'));
    expect(haystack, contains('büyük'));
    expect(haystack, contains('limonsuz'));
    expect(haystack, contains('kapıda zili çalmayın'));
  });
}
