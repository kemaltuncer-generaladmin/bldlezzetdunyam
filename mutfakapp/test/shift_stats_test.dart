/// Vardiya sayaçları.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/kds/shift_stats.dart';

import 'fake_kitchen_service.dart';

/// `createdAt` sabit, `updatedAt` [prep] kadar sonra: ölçülebilir bir sipariş.
KitchenOrder timed({
  required int id,
  required OrderStatus status,
  Duration prep = const Duration(minutes: 10),
}) {
  final created = DateTime.utc(2026, 8, 5, 10);
  return KitchenOrder(
    id: id,
    orderNumber: 'S-$id',
    status: status,
    deliveryType: DeliveryType.delivery,
    items: const [KitchenOrderItem(name: 'Tavuk Sote', quantity: 1)],
    createdAt: created,
    updatedAt: created.add(prep),
  );
}

void main() {
  test('boş vardiyada sayaç yoktur', () {
    final tracker = ShiftStatsTracker();
    expect(tracker.apply(const []), ShiftStats.empty);
    expect(ShiftStats.empty.averagePrep, isNull);
  });

  test('görülen sipariş sayılır, tekrarlar sayılmaz', () {
    final tracker = ShiftStatsTracker()
      ..apply([makeOrder(id: 1), makeOrder(id: 2)]);
    final stats = tracker.apply([makeOrder(id: 1), makeOrder(id: 2)]);

    expect(stats.seenCount, 2);
  });

  test('sipariş ekrandan düşse bile sayılmış kalır', () {
    // Teslim edilen sipariş listeden çıkar; vardiya sayacı onu unutmamalı.
    final tracker = ShiftStatsTracker()..apply([makeOrder(id: 1)]);
    expect(tracker.apply(const []).seenCount, 1);
  });

  test('hazır olan siparişin süresi ölçülür', () {
    final tracker = ShiftStatsTracker();
    final stats = tracker.apply([
      timed(id: 1, status: OrderStatus.hazir, prep: const Duration(minutes: 8)),
    ]);

    expect(stats.readyCount, 1);
    expect(stats.averagePrep, const Duration(minutes: 8));
    expect(stats.slowestOrderNumber, 'S-1');
  });

  test('hazır olmayan sipariş ölçülmez', () {
    final tracker = ShiftStatsTracker();
    final stats = tracker.apply([
      timed(id: 1, status: OrderStatus.hazirlaniyor),
      timed(id: 2, status: OrderStatus.yeni),
    ]);

    expect(stats.readyCount, isZero);
    expect(stats.averagePrep, isNull);
  });

  test('bir sipariş yalnızca BİR KEZ ölçülür', () {
    // `yolda` ve `teslim_edildi` geçişleri `updated_at`'i ileri taşır; her
    // yayında yeniden ölçmek ortalamayı şişirirdi.
    final tracker = ShiftStatsTracker()
      ..apply([
        timed(
          id: 1,
          status: OrderStatus.hazir,
          prep: const Duration(minutes: 10),
        ),
      ]);

    final stats = tracker.apply([
      timed(
        id: 1,
        status: OrderStatus.teslimEdildi,
        prep: const Duration(minutes: 90),
      ),
    ]);

    expect(stats.readyCount, 1);
    expect(stats.averagePrep, const Duration(minutes: 10));
  });

  test('ortalama birden çok siparişten hesaplanır', () {
    final tracker = ShiftStatsTracker()
      ..apply([
        timed(
          id: 1,
          status: OrderStatus.hazir,
          prep: const Duration(minutes: 10),
        ),
        timed(
          id: 2,
          status: OrderStatus.hazir,
          prep: const Duration(minutes: 20),
        ),
      ]);

    expect(tracker.stats.averagePrep, const Duration(minutes: 15));
    expect(tracker.stats.slowestOrderNumber, 'S-2');
    expect(tracker.stats.slowestPrep, const Duration(minutes: 20));
  });

  test('negatif süre ölçüme girmez', () {
    // Kasa saati sunucudan ileriyse fark negatif çıkar; bu ölçüm değil hatadır
    // ve ortalamayı bozar.
    final created = DateTime.utc(2026, 8, 5, 10);
    final broken = KitchenOrder(
      id: 1,
      orderNumber: 'S-1',
      status: OrderStatus.hazir,
      deliveryType: DeliveryType.delivery,
      items: const [KitchenOrderItem(name: 'Pilav', quantity: 1)],
      createdAt: created,
      updatedAt: created.subtract(const Duration(minutes: 5)),
    );

    final stats = ShiftStatsTracker().apply([broken]);
    expect(stats.readyCount, isZero);
    expect(stats.seenCount, 1);
  });
}
