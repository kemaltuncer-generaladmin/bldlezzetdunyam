/// `K-06` tetik testleri — `docs/05-mutfakapp.md` §5.5.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/printing/print_triggers.dart';

import 'fake_kitchen_service.dart';

void main() {
  late PrintTriggers triggers;

  setUp(() => triggers = PrintTriggers());

  test('YENİ durumda hiçbir fiş çıkmaz', () {
    // Sipariş henüz kabul edilmedi ve müşteri iptal edebilir. `yeni`de
    // basmak, iptal edilen her sipariş için çöpe giden bir fiş demekti.
    expect(triggers.jobsFor([makeOrder(id: 5012)]), isEmpty);
  });

  test('mutfak onaylayınca mutfak fişi tetiklenir', () {
    triggers.jobsFor([makeOrder(id: 5012)]);

    expect(
      triggers.jobsFor([makeOrder(id: 5012, status: OrderStatus.onaylandi)]),
      [const PrintTriggerJob(5012, ReceiptType.mutfak)],
    );
  });

  test('aynı sipariş ikinci yayında tekrar tetiklemez', () {
    triggers.jobsFor([makeOrder(id: 5012, status: OrderStatus.onaylandi)]);

    expect(
      triggers.jobsFor([makeOrder(id: 5012, status: OrderStatus.onaylandi)]),
      isEmpty,
    );
  });

  test('iptal edilen sipariş hiç fiş üretmez', () {
    expect(
      triggers.jobsFor([makeOrder(id: 3, status: OrderStatus.iptal)]),
      isEmpty,
    );
  });

  test('durum hazir olunca müşteri fişi tetiklenir', () {
    triggers.jobsFor([makeOrder(id: 5012, status: OrderStatus.hazirlaniyor)]);

    expect(triggers.jobsFor([makeOrder(id: 5012, status: OrderStatus.hazir)]), [
      const PrintTriggerJob(5012, ReceiptType.musteri),
    ]);
  });

  test('hazir durumu tekrar yayınlanırsa ikinci fiş çıkmaz', () {
    triggers.jobsFor([makeOrder(id: 1, status: OrderStatus.hazir)]);

    expect(
      triggers.jobsFor([makeOrder(id: 1, status: OrderStatus.hazir)]),
      isEmpty,
    );
  });

  test('hazir olarak ilk kez görülen sipariş iki fiş birden tetikler', () {
    final jobs = triggers.jobsFor([
      makeOrder(id: 9, status: OrderStatus.hazir),
    ]);

    expect(jobs, [
      const PrintTriggerJob(9, ReceiptType.mutfak),
      const PrintTriggerJob(9, ReceiptType.musteri),
    ]);
  });

  test('yolda durumu da müşteri fişi tetikler', () {
    // hazir iken kapanıp yolda iken açılan uygulamada fiş hiç basılmamış
    // olabilir; tetiği kaçırmaktansa fazladan çağırmak yeğdir (idempotent).
    final jobs = triggers.jobsFor([
      makeOrder(id: 4, status: OrderStatus.yolda),
    ]);

    expect(jobs, contains(const PrintTriggerJob(4, ReceiptType.musteri)));
  });

  test('hazir öncesi durumlar müşteri fişi tetiklemez', () {
    for (final status in [OrderStatus.onaylandi, OrderStatus.hazirlaniyor]) {
      final fresh = PrintTriggers();
      final jobs = fresh.jobsFor([makeOrder(id: 1, status: status)]);
      expect(jobs.map((j) => j.type), [
        ReceiptType.mutfak,
      ], reason: '$status müşteri fişi tetiklememeli');
    }
  });

  test('gel-al: hazir atlanıp teslim edildi görülürse iki fiş de çıkar', () {
    // Gel-al siparişi `hazir`dan doğrudan `teslim_edildi`ye geçer. Arada
    // bir yayın kaçarsa müşteri fişi hiç basılmamış olurdu.
    final jobs = triggers.jobsFor([
      makeOrder(id: 8, status: OrderStatus.teslimEdildi),
    ]);

    expect(jobs, [
      const PrintTriggerJob(8, ReceiptType.mutfak),
      const PrintTriggerJob(8, ReceiptType.musteri),
    ]);
  });

  test('durum makinesi boyunca tam olarak iki fiş çıkar', () {
    final produced = <PrintTriggerJob>[];
    for (final status in [
      OrderStatus.yeni,
      OrderStatus.onaylandi,
      OrderStatus.hazirlaniyor,
      OrderStatus.hazir,
      OrderStatus.yolda,
    ]) {
      produced.addAll(triggers.jobsFor([makeOrder(id: 7, status: status)]));
    }

    expect(produced, [
      const PrintTriggerJob(7, ReceiptType.mutfak),
      const PrintTriggerJob(7, ReceiptType.musteri),
    ]);
  });

  test('birden çok sipariş sırayla işlenir', () {
    final jobs = triggers.jobsFor([
      makeOrder(id: 1, status: OrderStatus.onaylandi),
      makeOrder(id: 2, status: OrderStatus.onaylandi),
      makeOrder(id: 3, status: OrderStatus.onaylandi),
    ]);

    expect(jobs.map((j) => j.orderId), [1, 2, 3]);
  });
}
