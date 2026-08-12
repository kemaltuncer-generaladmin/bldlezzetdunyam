/// `K-06` / `K-20` tetik testleri — `docs/05-mutfakapp.md` §5.5.
///
/// K-20 KURALI: sipariş başına tam **iki** kâğıt. Kurye fişi otomatik
/// basılmıyor; düzenlemeler tek güncel kâğıtta birleşiyor.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/printing/print_triggers.dart';

import 'fake_kitchen_service.dart';

void main() {
  late PrintTriggers triggers;

  /// Testlerin ilerlettiği sahte saat.
  ///
  /// Bekletme penceresi **yoklamayla** salınıyor, zamanlayıcıyla değil
  /// (`PollingOrderSource` zaten ~5 sn'de bir yayın yapıyor). Bu yüzden
  /// gerçek gecikme beklemeye gerek yok: saati ileri al, `jobsFor`'u
  /// yeniden çağır.
  late DateTime now;

  setUp(() {
    now = DateTime.utc(2026, 8, 14, 11, 30);
    triggers = PrintTriggers(clock: () => now);
  });

  /// Sipariş listesini değiştirmeden yeniden yayınlar — yoklama tıkı.
  List<PrintTriggerJob> tick(List<KitchenOrder> orders, {Duration? after}) {
    if (after != null) now = now.add(after);
    return triggers.jobsFor(orders);
  }

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

  test('durum hazir olunca YALNIZ müşteri fişi tetiklenir', () {
    // K-20: kuryenin ihtiyaç duyduğu her şey (ad, telefon, adres, harita
    // QR, tahsil edilecek tutar) artık müşteri fişinde. Ayrı bir kurye
    // kâğıdı basmak, aynı bilgiyi ikinci kez kâğıda dökmek olurdu.
    triggers.jobsFor([makeOrder(id: 5012, status: OrderStatus.hazirlaniyor)]);

    expect(triggers.jobsFor([makeOrder(id: 5012, status: OrderStatus.hazir)]), [
      const PrintTriggerJob(5012, ReceiptType.musteri),
    ]);
  });

  test('KURYE fişi hiçbir durumda otomatik tetiklenmez', () {
    final produced = <PrintTriggerJob>[];
    for (final status in OrderStatus.values) {
      produced.addAll(
        PrintTriggers(clock: () => now).jobsFor([
          makeOrder(id: 11, status: status),
        ]),
      );
    }

    expect(produced.map((j) => j.type), isNot(contains(ReceiptType.kurye)));
  });

  test('hazir durumu tekrar yayınlanırsa ikinci fiş çıkmaz', () {
    triggers.jobsFor([makeOrder(id: 1, status: OrderStatus.hazir)]);

    expect(
      triggers.jobsFor([makeOrder(id: 1, status: OrderStatus.hazir)]),
      isEmpty,
    );
  });

  test('hazir olarak ilk kez görülen sipariş İKİ fiş tetikler', () {
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
      final fresh = PrintTriggers(clock: () => now);
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

  test('adrese gönderim: durum makinesi boyunca tam olarak İKİ fiş çıkar', () {
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

  group('Revizyon (K-20)', () {
    test('sessiz pencere dolmadan hiçbir fiş çıkmaz', () {
      triggers.jobsFor([makeOrder(id: 3, status: OrderStatus.hazir)]);

      final order = makeOrder(
        id: 3,
        status: OrderStatus.hazir,
        revisionNo: 1,
      );

      expect(tick([order]), isEmpty, reason: 'revizyon anında basılmamalı');
      expect(tick([order], after: const Duration(seconds: 5)), isEmpty);
      expect(tick([order], after: const Duration(seconds: 5)), isEmpty);
    });

    test('pencere dolunca basılmış fişler GÜNCEL hâliyle yeniden çıkar', () {
      triggers.jobsFor([makeOrder(id: 3, status: OrderStatus.hazir)]);

      final order = makeOrder(id: 3, status: OrderStatus.hazir, revisionNo: 1);
      tick([order]);

      expect(tick([order], after: const Duration(seconds: 25)), [
        const PrintTriggerJob(3, ReceiptType.mutfak, 1),
        const PrintTriggerJob(3, ReceiptType.musteri, 1),
      ]);
    });

    test('HIZLI ARKA ARKAYA ÜÇ KAYIT TEK KÂĞIT ÜRETİR', () {
      // Bu turun başlık testi. Personel müşteriyle telefonda konuşurken
      // birkaç kez kaydediyor; eski davranışta her kayıt iki kâğıt demekti
      // ve iki kez düzenlenmiş sipariş yedi kâğıt çıkarıyordu.
      triggers.jobsFor([makeOrder(id: 3, status: OrderStatus.hazir)]);

      tick([makeOrder(id: 3, status: OrderStatus.hazir, revisionNo: 1)]);
      tick([
        makeOrder(id: 3, status: OrderStatus.hazir, revisionNo: 2),
      ], after: const Duration(seconds: 5));
      tick([
        makeOrder(id: 3, status: OrderStatus.hazir, revisionNo: 3),
      ], after: const Duration(seconds: 5));

      final jobs = tick([
        makeOrder(id: 3, status: OrderStatus.hazir, revisionNo: 3),
      ], after: const Duration(seconds: 25));

      // Ara sürümler (1 ve 2) hiç kâğıda çıkmıyor; yalnız sonuncusu.
      expect(jobs, [
        const PrintTriggerJob(3, ReceiptType.mutfak, 3),
        const PrintTriggerJob(3, ReceiptType.musteri, 3),
      ]);
    });

    test('düzenleme durmazsa üst sınırda basılır', () {
      // Beş dakika düzenlemeye devam eden personel yüzünden mutfak ASIL
      // siparişi pişirmeye devam etmemeli.
      triggers.jobsFor([makeOrder(id: 3, status: OrderStatus.hazir)]);

      var revision = 0;
      final produced = <PrintTriggerJob>[];
      for (var i = 0; i < 6; i++) {
        revision++;
        produced.addAll(
          tick([
            makeOrder(id: 3, status: OrderStatus.hazir, revisionNo: revision),
          ], after: const Duration(seconds: 15)),
        );
      }

      expect(produced, isNotEmpty, reason: 'üst sınır dolunca basılmalı');
    });

    test('HAZIR ÖNCESİ revizyon fazladan kâğıt ÜRETMEZ', () {
      // Düzenlemelerin çoğu `hazir` öncesi geliyor. O anda müşteri fişi
      // henüz basılmadı; kendi eşiğinde güncel veriyle bir kez çıkacak.
      // Yeniden basmak, hiç basılmamış bir fişi "yeniden" basmak olurdu.
      triggers.jobsFor([makeOrder(id: 12, status: OrderStatus.onaylandi)]);

      final revised = makeOrder(
        id: 12,
        status: OrderStatus.hazirlaniyor,
        revisionNo: 1,
      );
      tick([revised]);

      final afterWindow = tick(
        [revised],
        after: const Duration(seconds: 25),
      );

      // Mutfak fişi basılmıştı → yeniden çıkar. Müşteri fişi basılmamıştı.
      expect(afterWindow, [const PrintTriggerJob(12, ReceiptType.mutfak, 1)]);

      // `hazir`a geçince müşteri fişi ilk ve tek kez, güncel sürümle çıkar.
      expect(
        tick([makeOrder(id: 12, status: OrderStatus.hazir, revisionNo: 1)]),
        [const PrintTriggerJob(12, ReceiptType.musteri, 1)],
      );
    });

    test('İLK BASIM GECİKMEZ — mutfak yemeğe hemen başlamalı', () {
      final jobs = triggers.jobsFor([
        makeOrder(id: 13, status: OrderStatus.onaylandi),
      ]);

      expect(jobs, [const PrintTriggerJob(13, ReceiptType.mutfak)]);
    });

    test('aynı revizyon tekrar görülürse fiş çıkmaz', () {
      triggers.jobsFor([
        makeOrder(id: 5, status: OrderStatus.hazir, revisionNo: 2),
      ]);

      expect(
        tick([
          makeOrder(id: 5, status: OrderStatus.hazir, revisionNo: 2),
        ], after: const Duration(seconds: 30)),
        isEmpty,
      );
    });

    test('AÇILIŞTA revizyonlu sipariş GECİKMEDEN basılır', () {
      // Uygulama yeniden başladığında hafıza boş. Bu cihaz o sipariş için
      // henüz hiçbir şey basmadı, yani geçersiz kılınacak bir kâğıt yok:
      // bekletmek boşuna gecikme olurdu.
      final first = triggers.jobsFor([
        makeOrder(id: 6, status: OrderStatus.hazir, revisionNo: 3),
      ]);

      expect(first, [
        const PrintTriggerJob(6, ReceiptType.mutfak, 3),
        const PrintTriggerJob(6, ReceiptType.musteri, 3),
      ]);

      expect(
        tick([
          makeOrder(id: 6, status: OrderStatus.hazir, revisionNo: 3),
        ], after: const Duration(seconds: 30)),
        isEmpty,
      );
    });

    test('iptal edilen siparişin bekleyen revize fişi basılmaz', () {
      triggers.jobsFor([makeOrder(id: 14, status: OrderStatus.hazir)]);
      tick([makeOrder(id: 14, status: OrderStatus.hazir, revisionNo: 1)]);

      // Bekletme penceresi dolmadan sipariş iptal edildi.
      tick([
        makeOrder(id: 14, status: OrderStatus.iptal, revisionNo: 1),
      ], after: const Duration(seconds: 5));

      expect(
        tick([], after: const Duration(seconds: 30)),
        isEmpty,
        reason: 'iptal edilen siparişin fişi çöpe giden kâğıttır',
      );
    });

    test('sipariş listeden düşse bile bekleyen fiş basılır', () {
      // `PollingOrderSource` teslim edilen siparişi listeden çıkarıyor.
      // Bekletme sipariş listesinden bağımsız salınmalı, yoksa teslim
      // edilmiş bir siparişin güncel fişi hiç çıkmazdı.
      triggers.jobsFor([makeOrder(id: 15, status: OrderStatus.hazir)]);
      tick([makeOrder(id: 15, status: OrderStatus.hazir, revisionNo: 1)]);

      expect(
        tick([], after: const Duration(seconds: 30)),
        [
          const PrintTriggerJob(15, ReceiptType.mutfak, 1),
          const PrintTriggerJob(15, ReceiptType.musteri, 1),
        ],
      );
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
