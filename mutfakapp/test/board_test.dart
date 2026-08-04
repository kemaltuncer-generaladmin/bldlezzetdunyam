/// Pano mantığı testleri — `docs/05-mutfakapp.md` §3.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/kds/board.dart';

import 'fake_kitchen_service.dart';

void main() {
  group('Sütun dağılımı', () {
    test('beş aktif durumun tamamı bir sütuna düşer', () {
      for (final status in OrderStatus.values.where((s) => !s.isTerminal)) {
        expect(
          columnOf(status),
          isNotNull,
          reason: '$status hiçbir sütuna düşmüyor',
        );
      }
    });

    test('terminal durumlar panoda görünmez', () {
      expect(columnOf(OrderStatus.teslimEdildi), isNull);
      expect(columnOf(OrderStatus.iptal), isNull);
    });

    test('onaylanan sipariş YENİ sütunundan çıkar', () {
      expect(columnOf(OrderStatus.yeni), KdsColumn.yeni);
      expect(columnOf(OrderStatus.onaylandi), KdsColumn.hazirlaniyor);
    });

    test('yola çıkan sipariş HAZIR sütununda kalır', () {
      expect(columnOf(OrderStatus.hazir), KdsColumn.hazir);
      expect(columnOf(OrderStatus.yolda), KdsColumn.hazir);
    });

    test('gruplama gelen sırayı korur', () {
      final board = groupIntoColumns([
        makeOrder(id: 1, status: OrderStatus.yeni),
        makeOrder(id: 2, status: OrderStatus.hazirlaniyor),
        makeOrder(id: 3, status: OrderStatus.yeni),
        makeOrder(id: 4, status: OrderStatus.hazir),
        makeOrder(id: 5, status: OrderStatus.teslimEdildi),
      ]);

      expect(board[KdsColumn.yeni]!.map((o) => o.id), [1, 3]);
      expect(board[KdsColumn.hazirlaniyor]!.map((o) => o.id), [2]);
      expect(board[KdsColumn.hazir]!.map((o) => o.id), [4]);
    });

    test('boş listede üç sütun da vardır ve boştur', () {
      final board = groupIntoColumns(const []);
      expect(board.keys, containsAll(KdsColumn.values));
      expect(board.values.every((column) => column.isEmpty), isTrue);
    });
  });

  group('Üretim listesi', () {
    test('yalnızca onaylandi ve hazirlaniyor sayılır', () {
      final totals = productionTotals([
        makeOrder(
          id: 1,
          status: OrderStatus.yeni,
          items: const [KitchenOrderItem(name: 'Pilav', quantity: 100)],
        ),
        makeOrder(
          id: 2,
          status: OrderStatus.onaylandi,
          items: const [KitchenOrderItem(name: 'Tavuk Sote', quantity: 25)],
        ),
        makeOrder(
          id: 3,
          status: OrderStatus.hazirlaniyor,
          items: const [KitchenOrderItem(name: 'Tavuk Sote', quantity: 15)],
        ),
        makeOrder(
          id: 4,
          status: OrderStatus.hazir,
          items: const [KitchenOrderItem(name: 'Ayran', quantity: 50)],
        ),
      ]);

      expect(totals.map((t) => t.name), ['Tavuk Sote']);
      expect(totals.single.quantity, 40);
    });

    test('çoktan aza sıralı, eşitlikte ada göre', () {
      final totals = productionTotals([
        makeOrder(
          id: 1,
          status: OrderStatus.hazirlaniyor,
          items: const [
            KitchenOrderItem(name: 'Mercimek', quantity: 5),
            KitchenOrderItem(name: 'Pilav', quantity: 18),
            KitchenOrderItem(name: 'Ayran', quantity: 18),
          ],
        ),
      ]);

      expect(totals.map((t) => t.name), ['Ayran', 'Pilav', 'Mercimek']);
    });

    test('hazırlanacak bir şey yoksa boştur', () {
      expect(
        productionTotals([makeOrder(id: 1, status: OrderStatus.yeni)]),
        isEmpty,
      );
    });
  });

  group('İstenen teslim saati', () {
    final now = DateTime.utc(2026, 8, 4, 12);

    test('geçmiş saat geç sayılır', () {
      final order = makeOrder(
        id: 1,
        requestedAt: DateTime.utc(2026, 8, 4, 11, 59),
      );
      expect(isRequestedTimeLate(order, now), isTrue);
    });

    test('gelecek saat geç değildir', () {
      final order = makeOrder(
        id: 1,
        requestedAt: DateTime.utc(2026, 8, 4, 12, 1),
      );
      expect(isRequestedTimeLate(order, now), isFalse);
    });

    test('saat verilmemişse geç değildir', () {
      expect(isRequestedTimeLate(makeOrder(id: 1), now), isFalse);
    });
  });
}
