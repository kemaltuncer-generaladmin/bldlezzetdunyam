/// `K-06` / `K-20` tetik testleri — `docs/05-mutfakapp.md` §5.5.
///
/// K-20 KURALI: sipariş başına tam **iki** kâğıt. Kurye fişi otomatik
/// basılmıyor; düzenlemeler tek güncel kâğıtta birleşiyor.
///
/// 14.08.2026 EKİ: o iki kâğıt **asla aynı turda** çıkmaz. Sahadaki şikâyet
/// "arka arkaya fiş basılıyor"du; bir turda sipariş başına en çok bir iş
/// üretiliyor, mutfak önce, ertelenen iş bir sonraki yoklamada çıkıyor.
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

  /// Siparişin İKİ fişini de bastırıp "hepsi basıldı" durumuna getirir.
  ///
  /// İki tur sürüyor: turda sipariş başına tek kâğıt kuralıyla mutfak ve
  /// müşteri fişi aynı yoklamada çıkmıyor. Revizyon testlerinin çoğu
  /// "her iki tip de basılmış" durumundan başladığı için bu kurulum
  /// tek satırda toplandı.
  void printBothReceipts(int id, {int revisionNo = 0}) {
    final order = makeOrder(
      id: id,
      status: OrderStatus.hazir,
      revisionNo: revisionNo,
    );
    triggers.jobsFor([order]);
    triggers.jobsFor([order]);
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
        PrintTriggers(
          clock: () => now,
        ).jobsFor([makeOrder(id: 11, status: status)]),
      );
    }

    expect(produced.map((j) => j.type), isNot(contains(ReceiptType.kurye)));
  });

  test('iki fiş de çıktıktan sonra hazir tekrar yayınlanırsa fiş çıkmaz', () {
    printBothReceipts(1);

    expect(
      triggers.jobsFor([makeOrder(id: 1, status: OrderStatus.hazir)]),
      isEmpty,
    );
  });

  test('hazir olarak ilk kez görülen sipariş ÖNCE mutfak, SONRAKİ turda '
      'müşteri fişi tetikler', () {
    // Şikâyetin ta kendisi: iki eşik aynı yoklamada aşılıyordu ve tezgâha
    // 1,2 saniye arayla iki kâğıt birden düşüyordu. Sipariş iki yoklama
    // arasında `yeni`den `hazir`a atlarsa bu her seferinde oluyor.
    final order = makeOrder(id: 9, status: OrderStatus.hazir);

    expect(triggers.jobsFor([order]), [
      const PrintTriggerJob(9, ReceiptType.mutfak),
    ]);
    expect(triggers.jobsFor([order]), [
      const PrintTriggerJob(9, ReceiptType.musteri),
    ]);
  });

  test('yolda durumu da müşteri fişi tetikler', () {
    // hazir iken kapanıp yolda iken açılan uygulamada fiş hiç basılmamış
    // olabilir; tetiği kaçırmaktansa fazladan çağırmak yeğdir (idempotent).
    final order = makeOrder(id: 4, status: OrderStatus.yolda);

    triggers.jobsFor([order]); // turun kâğıdı mutfak fişi

    expect(
      triggers.jobsFor([order]),
      contains(const PrintTriggerJob(4, ReceiptType.musteri)),
    );
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

  test('gel-al: hazir atlanıp teslim edildi görülürse ÖNCE mutfak, SONRAKİ '
      'turda müşteri fişi çıkar', () {
    // Gel-al siparişi `hazir`dan doğrudan `teslim_edildi`ye geçer. Arada
    // bir yayın kaçarsa müşteri fişi hiç basılmamış olurdu; iki tura
    // yayılsa da her iki kâğıt da çıkar.
    final order = makeOrder(
      id: 8,
      status: OrderStatus.teslimEdildi,
      deliveryType: DeliveryType.pickup,
    );

    expect(triggers.jobsFor([order]), [
      const PrintTriggerJob(8, ReceiptType.mutfak),
    ]);
    expect(triggers.jobsFor([order]), [
      const PrintTriggerJob(8, ReceiptType.musteri),
    ]);
  });

  test('ERTELENEN MÜŞTERİ FİŞİ BİR SONRAKİ TURDA MUTLAKA ÇIKAR', () {
    // Ertelemenin bedeli fişin kaybolması olamaz. `_readyOrders` mutfak
    // fişi çıkarken kasten işaretlenmiyor; işaretlenseydi sipariş "müşteri
    // fişi basıldı" sayılır ve kâğıt hiçbir turda çıkmazdı.
    final order = makeOrder(id: 31, status: OrderStatus.hazir);

    expect(triggers.jobsFor([order]), [
      const PrintTriggerJob(31, ReceiptType.mutfak),
    ]);
    expect(triggers.jobsFor([order]), [
      const PrintTriggerJob(31, ReceiptType.musteri),
    ]);
    expect(
      triggers.jobsFor([order]),
      isEmpty,
      reason: 'sipariş başına tam iki kâğıt — üçüncüsü yok',
    );
  });

  test('ERTELENEN MÜŞTERİ FİŞİ SİPARİŞ LİSTEDEN DÜŞSE BİLE ÇIKAR', () {
    // BUGÜN KAYBOLAN TAM SENARYO. Gel-al siparişi ilk kez `hazir` görülüyor
    // (mutfak fişi çıkıyor, müşteri fişi ertelenıyor), sonra teslim ediliyor
    // ve `PollingOrderSource` onu listeden düşürüyor. İş yalnız eşiğin
    // yeniden değerlendirilmesine bırakılsaydı o eşik bir daha hiç
    // yoklanmaz, kuryenin adres ve tahsilat bilgisini taşıyan tek kâğıt
    // sessizce kaybolurdu.
    expect(
      triggers.jobsFor([
        makeOrder(
          id: 34,
          status: OrderStatus.hazir,
          deliveryType: DeliveryType.pickup,
        ),
      ]),
      [const PrintTriggerJob(34, ReceiptType.mutfak)],
    );

    expect(triggers.jobsFor(const []), [
      const PrintTriggerJob(34, ReceiptType.musteri),
    ]);
    expect(triggers.jobsFor(const []), isEmpty, reason: 'yalnız bir kez');
  });

  test('ERTELENEN FİŞ, LİSTEDEN DÜŞMEDEN ÖNCEKİ REVİZYONLA ÇIKAR', () {
    // Erteleme sırasında sipariş düzenlenirse bekleyen kâğıt eski sürümü
    // basmamalı: sipariş listede görüldükçe kayıt tazeleniyor.
    triggers.jobsFor([makeOrder(id: 35, status: OrderStatus.hazir)]);

    expect(
      triggers.jobsFor([
        makeOrder(id: 35, status: OrderStatus.hazir, revisionNo: 4),
      ]),
      [const PrintTriggerJob(35, ReceiptType.musteri, 4)],
    );
  });

  test('ertelenen müşteri fişi sipariş ilerlese bile çıkar', () {
    // Erteleme sırasında durum `hazir`dan `yolda`ya geçebilir. Eşik "o
    // durum ya da ötesi" diye okunduğu için fiş yine çıkar.
    triggers.jobsFor([makeOrder(id: 32, status: OrderStatus.hazir)]);

    expect(triggers.jobsFor([makeOrder(id: 32, status: OrderStatus.yolda)]), [
      const PrintTriggerJob(32, ReceiptType.musteri),
    ]);
  });

  test('ERTELENEN İŞ, SİPARİŞ İPTAL OLURSA HİÇ ÇIKMAZ', () {
    // Mutfak fişi çıktı, müşteri fişi bir sonraki tura ertelendi; o tur
    // gelmeden sipariş iptal edildi. İptal edilen siparişin fişi çöpe
    // giden kâğıttır.
    expect(triggers.jobsFor([makeOrder(id: 33, status: OrderStatus.hazir)]), [
      const PrintTriggerJob(33, ReceiptType.mutfak),
    ]);

    expect(
      triggers.jobsFor([makeOrder(id: 33, status: OrderStatus.iptal)]),
      isEmpty,
    );
    expect(
      triggers.jobsFor(const []),
      isEmpty,
      reason: 'sipariş listeden düşünce de ertelenen iş dirilmemeli',
    );
  });

  test('BEKLEYEN REVİZE FİŞ İLE İLK MÜŞTERİ FİŞİ AYNI TURDA ÇIKMAZ', () {
    // Sipariş `onaylandi` iken mutfak fişi çıktı, sonra düzenlendi. Bekletme
    // penceresinin dolduğu turda sipariş `hazir` oluyor: bir yanda salınacak
    // revize mutfak fişi, öbür yanda hiç basılmamış müşteri fişi var. İkisi
    // aynı turda çıksaydı şikâyet edilen "arka arkaya" durumu geri gelirdi.
    triggers.jobsFor([makeOrder(id: 41, status: OrderStatus.onaylandi)]);
    tick([makeOrder(id: 41, status: OrderStatus.onaylandi, revisionNo: 1)]);

    expect(
      tick([
        makeOrder(id: 41, status: OrderStatus.hazir, revisionNo: 1),
      ], after: const Duration(seconds: 25)),
      [const PrintTriggerJob(41, ReceiptType.mutfak, 1)],
    );

    expect(
      tick([makeOrder(id: 41, status: OrderStatus.hazir, revisionNo: 1)]),
      [const PrintTriggerJob(41, ReceiptType.musteri, 1)],
    );
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
      printBothReceipts(3);

      final order = makeOrder(id: 3, status: OrderStatus.hazir, revisionNo: 1);

      expect(tick([order]), isEmpty, reason: 'revizyon anında basılmamalı');
      expect(tick([order], after: const Duration(seconds: 5)), isEmpty);
      expect(tick([order], after: const Duration(seconds: 5)), isEmpty);
    });

    test('pencere dolunca basılmış fişler GÜNCEL hâliyle, TURDA BİRER TANE '
        'yeniden çıkar', () {
      printBothReceipts(3);

      final order = makeOrder(id: 3, status: OrderStatus.hazir, revisionNo: 1);
      tick([order]);

      expect(tick([order], after: const Duration(seconds: 25)), [
        const PrintTriggerJob(3, ReceiptType.mutfak, 1),
      ]);
      expect(tick([order]), [const PrintTriggerJob(3, ReceiptType.musteri, 1)]);
    });

    test('REVİZYON SALINIMINDA hiçbir tur iki iş birden döndürmez', () {
      printBothReceipts(21);

      final rounds = <List<PrintTriggerJob>>[
        tick([makeOrder(id: 21, status: OrderStatus.hazir, revisionNo: 1)]),
        tick([
          makeOrder(id: 21, status: OrderStatus.hazir, revisionNo: 1),
        ], after: const Duration(seconds: 25)),
        tick([makeOrder(id: 21, status: OrderStatus.hazir, revisionNo: 1)]),
        tick([makeOrder(id: 21, status: OrderStatus.hazir, revisionNo: 1)]),
      ];

      for (final round in rounds) {
        expect(round.length, lessThanOrEqualTo(1), reason: '$round');
      }

      // Bekletilen iki tip iki ayrı yoklamaya dağıldı, sıra mutfak önce.
      expect(rounds.expand((round) => round).toList(), [
        const PrintTriggerJob(21, ReceiptType.mutfak, 1),
        const PrintTriggerJob(21, ReceiptType.musteri, 1),
      ]);
    });

    test('HIZLI ARKA ARKAYA ÜÇ KAYIT YALNIZ SON SÜRÜMÜ BASAR', () {
      // Bu turun başlık testi. Personel müşteriyle telefonda konuşurken
      // birkaç kez kaydediyor; eski davranışta her kayıt iki kâğıt demekti
      // ve iki kez düzenlenmiş sipariş yedi kâğıt çıkarıyordu.
      printBothReceipts(3);

      tick([makeOrder(id: 3, status: OrderStatus.hazir, revisionNo: 1)]);
      tick([
        makeOrder(id: 3, status: OrderStatus.hazir, revisionNo: 2),
      ], after: const Duration(seconds: 5));
      tick([
        makeOrder(id: 3, status: OrderStatus.hazir, revisionNo: 3),
      ], after: const Duration(seconds: 5));

      final first = tick([
        makeOrder(id: 3, status: OrderStatus.hazir, revisionNo: 3),
      ], after: const Duration(seconds: 25));
      final second = tick([
        makeOrder(id: 3, status: OrderStatus.hazir, revisionNo: 3),
      ]);

      // Ara sürümler (1 ve 2) hiç kâğıda çıkmıyor; yalnız sonuncusu — ve o
      // da tek turda değil, art arda iki yoklamada.
      expect(first, [const PrintTriggerJob(3, ReceiptType.mutfak, 3)]);
      expect(second, [const PrintTriggerJob(3, ReceiptType.musteri, 3)]);
    });

    test('düzenleme durmazsa üst sınırda basılır', () {
      // Beş dakika düzenlemeye devam eden personel yüzünden mutfak ASIL
      // siparişi pişirmeye devam etmemeli.
      printBothReceipts(3);

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

      final afterWindow = tick([revised], after: const Duration(seconds: 25));

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
      printBothReceipts(5, revisionNo: 2);

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
      // bekletmek boşuna gecikme olurdu. İki kâğıt art arda yoklamalarda
      // çıkıyor — bekletme penceresi hiç beklenmiyor.
      final order = makeOrder(id: 6, status: OrderStatus.hazir, revisionNo: 3);

      expect(triggers.jobsFor([order]), [
        const PrintTriggerJob(6, ReceiptType.mutfak, 3),
      ]);
      expect(triggers.jobsFor([order]), [
        const PrintTriggerJob(6, ReceiptType.musteri, 3),
      ]);

      expect(tick([order], after: const Duration(seconds: 30)), isEmpty);
    });

    test('iptal edilen siparişin bekleyen revize fişi basılmaz', () {
      printBothReceipts(14);
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
      printBothReceipts(15);
      tick([makeOrder(id: 15, status: OrderStatus.hazir, revisionNo: 1)]);

      expect(tick([], after: const Duration(seconds: 30)), [
        const PrintTriggerJob(15, ReceiptType.mutfak, 1),
      ]);
      expect(tick([]), [const PrintTriggerJob(15, ReceiptType.musteri, 1)]);
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
