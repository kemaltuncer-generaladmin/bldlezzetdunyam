/// Aciliyet hesabı testleri.
///
/// Bu, mutfağın en çok güvendiği sayıdır: yanlış hesaplanan bir gecikme ya
/// panik yaratır ya da gerçek gecikmeyi gizler. Bu yüzden eşik sınırları
/// (tam eşikte ne olur) ayrıca ölçülür.
library;

import 'package:bld_core/bld_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/kds/urgency.dart';

import 'fake_kitchen_service.dart';

/// Testin sabit "şimdi"si. Gerçek saat kullanmıyoruz: 23:59'da koşan bir
/// test yeşil, 00:01'de kırmızı olmamalı.
final DateTime now = DateTime.utc(2026, 8, 5, 12);

const UrgencyThresholds thresholds = UrgencyThresholds(
  warningAfter: Duration(minutes: 10),
  lateAfter: Duration(minutes: 20),
);

void main() {
  group('Bekleme süresine göre aciliyet', () {
    test('yeni sipariş normaldir', () {
      final age = ageOf(
        makeOrder(id: 1, createdAt: now.subtract(const Duration(minutes: 2))),
        now: now,
        thresholds: thresholds,
      );

      expect(age.urgency, OrderUrgency.normal);
      expect(age.waiting, const Duration(minutes: 2));
      expect(age.isLate, isFalse);
    });

    test('uyarı eşiğinde sarıya döner — eşik dahildir', () {
      final age = ageOf(
        makeOrder(id: 1, createdAt: now.subtract(const Duration(minutes: 10))),
        now: now,
        thresholds: thresholds,
      );

      expect(age.urgency, OrderUrgency.warning);
    });

    test('gecikme eşiğinde kırmızıya döner — eşik dahildir', () {
      final age = ageOf(
        makeOrder(id: 1, createdAt: now.subtract(const Duration(minutes: 20))),
        now: now,
        thresholds: thresholds,
      );

      expect(age.urgency, OrderUrgency.late);
      expect(age.isLate, isTrue);
    });
  });

  group('İstenen teslim saati', () {
    test('saat geçtiyse sipariş yeni olsa bile geciktir', () {
      final age = ageOf(
        makeOrder(
          id: 1,
          createdAt: now.subtract(const Duration(minutes: 1)),
          requestedAt: now.subtract(const Duration(minutes: 5)),
        ),
        now: now,
        thresholds: thresholds,
      );

      expect(age.urgency, OrderUrgency.late);
      expect(age.requestedTimePassed, isTrue);
      expect(age.untilRequested, const Duration(minutes: -5));
    });

    test('tolerans penceresine giren teslim saati sarı yakar', () {
      final age = ageOf(
        makeOrder(
          id: 1,
          createdAt: now.subtract(const Duration(minutes: 1)),
          requestedAt: now.add(const Duration(minutes: 8)),
        ),
        now: now,
        thresholds: thresholds,
      );

      expect(age.urgency, OrderUrgency.warning);
      expect(age.requestedTimePassed, isFalse);
    });

    test('uzak teslim saati, uzun bekleyen bir siparişi aklamaz', () {
      // Sabah girilmiş, öğlene teslim edilecek sipariş: teslim saati uzak
      // ama sipariş iki saattir bekliyor ve mutfak bunu görmeli.
      final age = ageOf(
        makeOrder(
          id: 1,
          createdAt: now.subtract(const Duration(hours: 2)),
          requestedAt: now.add(const Duration(hours: 3)),
        ),
        now: now,
        thresholds: thresholds,
      );

      expect(age.urgency, OrderUrgency.late);
    });

    test('uzak teslim saati aciliyeti düşürmez, yalnızca yükseltebilir', () {
      final age = ageOf(
        makeOrder(
          id: 1,
          createdAt: now.subtract(const Duration(minutes: 1)),
          requestedAt: now.add(const Duration(hours: 5)),
        ),
        now: now,
        thresholds: thresholds,
      );

      expect(age.urgency, OrderUrgency.normal);
    });
  });

  group('lateOrderCount', () {
    test('yalnızca geciken siparişleri sayar', () {
      final orders = [
        makeOrder(id: 1, createdAt: now.subtract(const Duration(minutes: 1))),
        makeOrder(id: 2, createdAt: now.subtract(const Duration(minutes: 12))),
        makeOrder(id: 3, createdAt: now.subtract(const Duration(minutes: 25))),
        makeOrder(id: 4, createdAt: now.subtract(const Duration(hours: 2))),
      ];

      expect(lateOrderCount(orders, now: now, thresholds: thresholds), 2);
    });

    test('boş listede sıfırdır', () {
      expect(lateOrderCount(const [], now: now, thresholds: thresholds), 0);
    });
  });

  group('sortByUrgency', () {
    test('acil olan başa, eşitlikte eski olan öne gelir', () {
      final orders = [
        makeOrder(id: 1, createdAt: now.subtract(const Duration(minutes: 1))),
        makeOrder(id: 2, createdAt: now.subtract(const Duration(minutes: 25))),
        makeOrder(id: 3, createdAt: now.subtract(const Duration(minutes: 12))),
        makeOrder(id: 4, createdAt: now.subtract(const Duration(minutes: 40))),
        makeOrder(id: 5, createdAt: now.subtract(const Duration(minutes: 3))),
      ];

      final sorted = sortByUrgency(orders, now: now, thresholds: thresholds);

      expect(
        sorted.map((order) => order.id),
        // Geciken ikili (40 dk, 25 dk), sonra sarı (12 dk), sonra normaller
        // (3 dk, 1 dk) — her grupta eski önce.
        [4, 2, 3, 5, 1],
      );
    });

    test('girdi listesini değiştirmez', () {
      final orders = [
        makeOrder(id: 1, createdAt: now.subtract(const Duration(minutes: 1))),
        makeOrder(id: 2, createdAt: now.subtract(const Duration(minutes: 30))),
      ];

      sortByUrgency(orders, now: now, thresholds: thresholds);

      expect(orders.map((order) => order.id), [1, 2]);
    });

    test('aynı dakikada oluşan siparişlerde kimlik sırası belirleyicidir', () {
      final created = now.subtract(const Duration(minutes: 1));
      final orders = [
        makeOrder(id: 9, createdAt: created),
        makeOrder(id: 3, createdAt: created),
      ];

      final sorted = sortByUrgency(orders, now: now, thresholds: thresholds);

      expect(sorted.map((order) => order.id), [3, 9]);
    });
  });

  test('OrderUrgency.atLeast ağır basanı seçer', () {
    expect(
      OrderUrgency.normal.atLeast(OrderUrgency.warning),
      OrderUrgency.warning,
    );
    expect(OrderUrgency.late.atLeast(OrderUrgency.warning), OrderUrgency.late);
  });

  test('varsayılan eşikler 10 ve 20 dakikadır', () {
    expect(
      UrgencyThresholds.standard.warningAfter,
      const Duration(minutes: 10),
    );
    expect(UrgencyThresholds.standard.lateAfter, const Duration(minutes: 20));
  });

  test('durum ne olursa olsun bekleme sayacı işler', () {
    // `hazir` sütununda bekleyen yemek soğur: sayaç orada da çalışmalı.
    final age = ageOf(
      makeOrder(
        id: 1,
        status: OrderStatus.hazir,
        createdAt: now.subtract(const Duration(minutes: 45)),
      ),
      now: now,
      thresholds: thresholds,
    );

    expect(age.isLate, isTrue);
  });
}
