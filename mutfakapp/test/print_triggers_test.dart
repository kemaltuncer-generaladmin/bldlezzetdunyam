/// `K-06` tetik testleri — `docs/05-mutfakapp.md` §5.5.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
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

  test('durum hazir olunca müşteri VE kurye fişi tetiklenir', () {
    // Kurye fişi K-14 ile eklendi: kurye ad, telefon, adres ve tahsil
    // edilecek tutarı bir arada başka hiçbir fişte bulamıyor.
    triggers.jobsFor([makeOrder(id: 5012, status: OrderStatus.hazirlaniyor)]);

    expect(triggers.jobsFor([makeOrder(id: 5012, status: OrderStatus.hazir)]), [
      const PrintTriggerJob(5012, ReceiptType.musteri),
      const PrintTriggerJob(5012, ReceiptType.kurye),
    ]);
  });

  test('hazir durumu tekrar yayınlanırsa ikinci fiş çıkmaz', () {
    triggers.jobsFor([makeOrder(id: 1, status: OrderStatus.hazir)]);

    expect(
      triggers.jobsFor([makeOrder(id: 1, status: OrderStatus.hazir)]),
      isEmpty,
    );
  });

  test('hazir olarak ilk kez görülen adres siparişi ÜÇ fiş tetikler', () {
    final jobs = triggers.jobsFor([
      makeOrder(id: 9, status: OrderStatus.hazir),
    ]);

    expect(jobs, [
      const PrintTriggerJob(9, ReceiptType.mutfak),
      const PrintTriggerJob(9, ReceiptType.musteri),
      const PrintTriggerJob(9, ReceiptType.kurye),
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
    //
    // KURYE FİŞİ YOK: gel-al'da kurye yok, basılan kâğıt çöpe giderdi.
    final jobs = triggers.jobsFor([
      makeOrder(
        id: 8,
        status: OrderStatus.teslimEdildi,
        deliveryType: DeliveryType.pickup,
      ),
    ]);

    expect(jobs, [
      const PrintTriggerJob(8, ReceiptType.mutfak),
      const PrintTriggerJob(8, ReceiptType.musteri),
    ]);
  });

  test('GEL-AL siparişte kurye fişi HİÇ tetiklenmez', () {
    final jobs = triggers.jobsFor([
      makeOrder(
        id: 42,
        status: OrderStatus.hazir,
        deliveryType: DeliveryType.pickup,
      ),
    ]);

    expect(jobs.map((j) => j.type), isNot(contains(ReceiptType.kurye)));
  });

  test('adrese gönderim: durum makinesi boyunca tam olarak ÜÇ fiş çıkar', () {
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
      const PrintTriggerJob(7, ReceiptType.kurye),
    ]);
  });

  group('Revizyon (K-14)', () {
    test('revizyon artınca MUTFAK ve KURYE fişi yeniden tetiklenir', () {
      // Düzenlenen siparişin fişi yeniden basılmazsa mutfak eski adedi
      // hazırlamaya devam eder — düzenlemenin tamamı boşa gider.
      triggers.jobsFor([makeOrder(id: 3, status: OrderStatus.hazir)]);

      final jobs = triggers.jobsFor([
        makeOrder(id: 3, status: OrderStatus.hazir, revisionNo: 1),
      ]);

      expect(jobs, [
        const PrintTriggerJob(3, ReceiptType.mutfak, 1),
        const PrintTriggerJob(3, ReceiptType.kurye, 1),
      ]);
    });

    test('MÜŞTERİ fişi yeniden basılmaz', () {
      // O fiş müşterinin eline geçti; ikinci kopya yalnız kafa karıştırır.
      triggers.jobsFor([makeOrder(id: 4, status: OrderStatus.hazir)]);

      final jobs = triggers.jobsFor([
        makeOrder(id: 4, status: OrderStatus.hazir, revisionNo: 1),
      ]);

      expect(jobs.map((j) => j.type), isNot(contains(ReceiptType.musteri)));
    });

    test('aynı revizyon tekrar görülürse fiş çıkmaz', () {
      triggers.jobsFor([
        makeOrder(id: 5, status: OrderStatus.hazir, revisionNo: 2),
      ]);

      expect(
        triggers.jobsFor([
          makeOrder(id: 5, status: OrderStatus.hazir, revisionNo: 2),
        ]),
        isEmpty,
      );
    });

    test('AÇILIŞTA revizyonlu sipariş ikinci kez basılmaz', () {
      // Uygulama yeniden başladığında liste "revizyon 3" ile geliyor;
      // ilk görüşte fişler bir kez tetiklenir, sonra susar. Kuyruk
      // tekilliği zaten ikinciyi yutar ama tetikleyicinin kendisi de
      // gürültü üretmemeli.
      final first = triggers.jobsFor([
        makeOrder(id: 6, status: OrderStatus.hazir, revisionNo: 3),
      ]);
      final second = triggers.jobsFor([
        makeOrder(id: 6, status: OrderStatus.hazir, revisionNo: 3),
      ]);

      expect(first, hasLength(3));
      expect(second, isEmpty);
    });
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
