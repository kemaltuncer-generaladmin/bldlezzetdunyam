import 'package:bld_core/bld_core.dart';
import 'package:test/test.dart';

void main() {
  group('OrderStatus tel üzerindeki adlar', () {
    test('sözleşmedeki 7 kod birebir karşılanır', () {
      // docs/02-veri-modeli.md §3 — bu liste değişirse sunucu da değişmeli.
      expect(
        OrderStatus.values.map((s) => s.wireName),
        equals([
          'yeni',
          'onaylandi',
          'hazirlaniyor',
          'hazir',
          'yolda',
          'teslim_edildi',
          'iptal',
        ]),
      );
    });

    test('bilinmeyen değer null döner, çökmez', () {
      expect(OrderStatus.tryParse('ogrenci_bekliyor'), isNull);
      expect(OrderStatus.tryParse('teslim_edildi'), OrderStatus.teslimEdildi);
    });

    test('terminal durumlar doğru işaretli', () {
      expect(OrderStatus.teslimEdildi.isTerminal, isTrue);
      expect(OrderStatus.iptal.isTerminal, isTrue);
      expect(OrderStatus.hazir.isTerminal, isFalse);
    });
  });

  group('Geçiş matrisi — adrese gönderim', () {
    const type = DeliveryType.delivery;

    test('sözleşmedeki her izinli geçiş kabul edilir', () {
      expect(
        OrderStatusMachine.canTransition(
          OrderStatus.yeni,
          OrderStatus.onaylandi,
          type,
        ),
        isTrue,
      );
      expect(
        OrderStatusMachine.canTransition(
          OrderStatus.onaylandi,
          OrderStatus.hazirlaniyor,
          type,
        ),
        isTrue,
      );
      expect(
        OrderStatusMachine.canTransition(
          OrderStatus.hazirlaniyor,
          OrderStatus.hazir,
          type,
        ),
        isTrue,
      );
      expect(
        OrderStatusMachine.canTransition(
          OrderStatus.hazir,
          OrderStatus.yolda,
          type,
        ),
        isTrue,
      );
      expect(
        OrderStatusMachine.canTransition(
          OrderStatus.yolda,
          OrderStatus.teslimEdildi,
          type,
        ),
        isTrue,
      );
    });

    test('adrese gönderimde hazir → teslim_edildi atlanamaz', () {
      expect(
        OrderStatusMachine.canTransition(
          OrderStatus.hazir,
          OrderStatus.teslimEdildi,
          type,
        ),
        isFalse,
        reason: 'Kurye adımı atlanamaz; önce yolda olmalı',
      );
    });

    test('adım atlamak yasak (docs/10 S6)', () {
      expect(
        OrderStatusMachine.canTransition(
          OrderStatus.yeni,
          OrderStatus.hazir,
          type,
        ),
        isFalse,
      );
    });
  });

  group('Geçiş matrisi — gel-al', () {
    const type = DeliveryType.pickup;

    test('hazir → teslim_edildi doğrudan yapılır', () {
      expect(
        OrderStatusMachine.canTransition(
          OrderStatus.hazir,
          OrderStatus.teslimEdildi,
          type,
        ),
        isTrue,
      );
    });

    test('gel-al siparişte yolda durumu kullanılamaz', () {
      expect(
        OrderStatusMachine.canTransition(
          OrderStatus.hazir,
          OrderStatus.yolda,
          type,
        ),
        isFalse,
        reason: 'docs/02 §3: yolda yalnızca delivery_type=delivery için',
      );
    });
  });

  group('İptal', () {
    test('teslim_edildi hariç her durumdan iptal edilebilir', () {
      for (final type in DeliveryType.values) {
        for (final from in OrderStatus.values) {
          final canCancel = OrderStatusMachine.canTransition(
            from,
            OrderStatus.iptal,
            type,
          );
          expect(
            canCancel,
            from.isTerminal ? isFalse : isTrue,
            reason: '${from.wireName} → iptal (${type.wireName})',
          );
        }
      }
    });

    test('terminal durumlardan hiçbir yere gidilemez', () {
      for (final terminal in [OrderStatus.teslimEdildi, OrderStatus.iptal]) {
        for (final to in OrderStatus.values) {
          expect(
            OrderStatusMachine.canTransition(
              terminal,
              to,
              DeliveryType.delivery,
            ),
            isFalse,
            reason: '${terminal.wireName} → ${to.wireName}',
          );
        }
      }
    });

    test('müşteri yalnızca yeni ve onaylandi durumunda iptal edebilir', () {
      expect(OrderStatusMachine.customerCanCancel(OrderStatus.yeni), isTrue);
      expect(
        OrderStatusMachine.customerCanCancel(OrderStatus.onaylandi),
        isTrue,
      );
      expect(
        OrderStatusMachine.customerCanCancel(OrderStatus.hazirlaniyor),
        isFalse,
        reason: 'docs/10 S6 adım 3',
      );
    });
  });

  group('nextForward — KDS butonu', () {
    test('adrese gönderim zinciri sonuna kadar yürür', () {
      var current = OrderStatus.yeni;
      final path = <OrderStatus>[current];

      while (true) {
        final next = OrderStatusMachine.nextForward(
          current,
          DeliveryType.delivery,
        );
        if (next == null) break;
        path.add(next);
        current = next;
      }

      expect(path, [
        OrderStatus.yeni,
        OrderStatus.onaylandi,
        OrderStatus.hazirlaniyor,
        OrderStatus.hazir,
        OrderStatus.yolda,
        OrderStatus.teslimEdildi,
      ]);
    });

    test('gel-al zincirinde yolda adımı yok', () {
      expect(
        OrderStatusMachine.nextForward(OrderStatus.hazir, DeliveryType.pickup),
        OrderStatus.teslimEdildi,
      );
    });

    test('ileri adım her zaman matriste izinlidir', () {
      for (final type in DeliveryType.values) {
        for (final from in OrderStatus.values) {
          final next = OrderStatusMachine.nextForward(from, type);
          if (next == null) continue;
          expect(
            OrderStatusMachine.canTransition(from, next, type),
            isTrue,
            reason:
                'nextForward matrisle çelişiyor: ${from.wireName} → '
                '${next.wireName} (${type.wireName})',
          );
        }
      }
    });

    test('terminal durumda buton gösterilmez', () {
      expect(
        OrderStatusMachine.nextForward(
          OrderStatus.teslimEdildi,
          DeliveryType.delivery,
        ),
        isNull,
      );
      expect(
        OrderStatusMachine.nextForward(OrderStatus.iptal, DeliveryType.pickup),
        isNull,
      );
    });
  });

  test('her durumun Türkçe etiketi var', () {
    for (final status in OrderStatus.values) {
      expect(orderStatusLabelsTr[status], isNotNull, reason: status.wireName);
    }
  });
}
