/// ESC/POS golden testleri — `AGENTS.md` §5, `docs/05-mutfakapp.md` §10.
///
/// İki fiş tipi × iki teslimat tipi = dört sabit bayt dizisi. Beklenen çıktılar
/// `test/golden/*.hex` dosyalarındadır; şablonda istemeden yapılan her değişim
/// bu testleri kırar.
///
/// Golden dosyaları yenilemek (yalnızca bilinçli bir şablon değişiminden sonra):
///
/// ```bash
/// BLD_UPDATE_GOLDEN=1 dart test test/escpos_golden_test.dart
/// git diff packages/core/test/golden   # değişimi satır satır gözden geçir
/// ```
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:bld_core/bld_core.dart';
import 'package:bld_core/escpos.dart';
import 'package:test/test.dart';

/// Fişteki tarih: 04.08.2026 14:32 (Türkiye) = 11:32 UTC.
final DateTime printedAt = DateTime.utc(2026, 8, 4, 11, 32);

/// İstenen teslim: 05.08 09:30 (Türkiye) = 06:30 UTC.
final DateTime requestedAt = DateTime.utc(2026, 8, 5, 6, 30);

final KitchenReceiptData kitchenDelivery = KitchenReceiptData(
  orderNumber: 'S-5012',
  deliveryType: DeliveryType.delivery,
  printedAt: printedAt,
  requestedAt: requestedAt,
  customerPhone: '0555 123 45 67',
  customerNote: 'Fatura kurumsal',
  lines: const [
    KitchenReceiptLine(
      quantity: 2,
      name: 'Tavuk Sote',
      options: ['Normal'],
      note: 'Az acılı',
    ),
    KitchenReceiptLine(quantity: 1, name: 'Mercimek Çorbası'),
  ],
);

final KitchenReceiptData kitchenPickup = KitchenReceiptData(
  orderNumber: 'S-5013',
  deliveryType: DeliveryType.pickup,
  printedAt: printedAt,
  lines: const [
    KitchenReceiptLine(quantity: 12, name: 'Karnıyarık'),
    KitchenReceiptLine(
      quantity: 3,
      name: 'Şehriye Çorbası',
      options: ['Büyük', 'Limonlu'],
    ),
  ],
);

final CustomerReceiptData customerDelivery = CustomerReceiptData(
  orderNumber: 'S-5012',
  deliveryType: DeliveryType.delivery,
  printedAt: printedAt,
  requestedAt: requestedAt,
  lines: const [
    CustomerReceiptLine(quantity: 2, name: 'Tavuk Sote', lineTotal: 37000),
    CustomerReceiptLine(quantity: 1, name: 'Mercimek Çorbası', lineTotal: 8500),
  ],
  subtotal: 45500,
  deliveryFee: 4000,
  total: 49500,
  paymentMethod: ReceiptPaymentMethod.online,
  paymentStatus: ReceiptPaymentStatus.paid,
  address: const ReceiptAddress(
    line1: 'Örnek Mah. 12. Sk No:3',
    district: 'Selçuklu',
    city: 'Konya',
  ),
);

/// Haritadan iğne bırakılmış sipariş — fişe QR basılmalı.
/// Takip ve ödeme QR'lı müşteri fişi (K-18/K-19).
///
/// `pending` ödeme durumu KASITLI: ödeme QR'ı yalnız ödenmemiş siparişte
/// basılıyor ve golden bu kuralı da sabitliyor.
final CustomerReceiptData customerDeliveryWithQrs = CustomerReceiptData(
  orderNumber: 'S-5015',
  deliveryType: DeliveryType.delivery,
  printedAt: printedAt,
  lines: const [
    CustomerReceiptLine(quantity: 2, name: 'Tavuk Sote', lineTotal: 37000),
  ],
  subtotal: 37000,
  deliveryFee: 4000,
  total: 41000,
  paymentMethod: ReceiptPaymentMethod.cash,
  paymentStatus: ReceiptPaymentStatus.pending,
  address: const ReceiptAddress(
    line1: 'Örnek Mah. 12. Sk No:3',
    district: 'Selçuklu',
    city: 'Konya',
  ),
  trackUrl: 'https://benimlezzetdunyam.com.tr/takip/5015?e=1786512000&s=Ab3',
  payUrl:
      'https://api.benimlezzetdunyam.com.tr/odeme-simulasyon/abc123'
      '?return=https%3A%2F%2Fbenimlezzetdunyam.com.tr%2Ftakip%2F5015'
      '%3Fe%3D1786512000%26s%3DAb3',
);

/// Ödenmiş sipariş: takip QR'ı var, ödeme QR'ı YOK.
final CustomerReceiptData customerPaidWithTrackQr = CustomerReceiptData(
  orderNumber: 'S-5016',
  deliveryType: DeliveryType.pickup,
  printedAt: printedAt,
  lines: const [
    CustomerReceiptLine(quantity: 1, name: 'Mercimek Çorbası', lineTotal: 8500),
  ],
  subtotal: 8500,
  deliveryFee: 0,
  total: 8500,
  paymentMethod: ReceiptPaymentMethod.online,
  paymentStatus: ReceiptPaymentStatus.paid,
  trackUrl: 'https://benimlezzetdunyam.com.tr/takip/5016?e=1786512000&s=Cd4',
);

final CustomerReceiptData customerDeliveryWithPin = CustomerReceiptData(
  orderNumber: 'S-5014',
  deliveryType: DeliveryType.delivery,
  printedAt: printedAt,
  lines: const [
    CustomerReceiptLine(quantity: 2, name: 'Tavuk Sote', lineTotal: 37000),
  ],
  subtotal: 37000,
  deliveryFee: 4000,
  total: 41000,
  paymentMethod: ReceiptPaymentMethod.cash,
  paymentStatus: ReceiptPaymentStatus.pending,
  address: const ReceiptAddress(
    line1: 'Örnek Mah. 12. Sk No:3',
    district: 'Selçuklu',
    city: 'Konya',
    latitude: 37.8901234,
    longitude: 32.4876543,
  ),
);

final CustomerReceiptData customerPickup = CustomerReceiptData(
  orderNumber: 'S-5013',
  deliveryType: DeliveryType.pickup,
  printedAt: printedAt,
  lines: const [
    CustomerReceiptLine(quantity: 12, name: 'Karnıyarık', lineTotal: 108000),
    CustomerReceiptLine(
      quantity: 3,
      name: 'Şehriye Çorbası',
      lineTotal: 25500,
      options: ['Büyük', 'Limonlu'],
    ),
  ],
  subtotal: 133500,
  deliveryFee: 0,
  total: 133500,
  paymentMethod: ReceiptPaymentMethod.cash,
  paymentStatus: ReceiptPaymentStatus.pending,
);

/// BİRLEŞİK müşteri fişi — en zor vaka (K-20).
///
/// EN ZOR VAKA BİLİNÇLİ SEÇİLDİ: revizyon bandı, değişiklik listesi, ad,
/// çift boy telefon, harita QR'lı adres, sipariş notu, tahsilat satırı ve
/// üç QR bir arada. Bloklardan biri yer değiştirirse bu dosya kırılır;
/// kolay vakayı sabitlemek asıl kırılgan yolu korumasız bırakırdı.
final CustomerReceiptData customerMerged = CustomerReceiptData(
  orderNumber: 'S-5020',
  deliveryType: DeliveryType.delivery,
  printedAt: printedAt,
  requestedAt: requestedAt,
  lines: const [
    CustomerReceiptLine(quantity: 10, name: 'Mercimek Çorbası', lineTotal: 85000),
    CustomerReceiptLine(
      quantity: 2,
      name: 'Tavuk Sote',
      lineTotal: 37000,
      options: ['Az acılı'],
    ),
  ],
  subtotal: 122000,
  deliveryFee: 4000,
  total: 126000,
  paymentMethod: ReceiptPaymentMethod.cash,
  paymentStatus: ReceiptPaymentStatus.pending,
  customerName: 'Ayşe Yılmaz',
  customerPhone: '0555 123 45 67',
  customerNote: 'Zili çalmayın',
  collectAmount: 126000,
  revisionNo: 2,
  revisionSummary: const ['Mercimek Çorbası: 20 → 10', 'ÇIKARILDI: Ayran ×5'],
  address: const ReceiptAddress(
    line1: 'Örnek Mah. 12. Sk No:3',
    district: 'Selçuklu',
    city: 'Konya',
    latitude: 37.8901234,
    longitude: 32.4876543,
  ),
  trackUrl: 'https://benimlezzetdunyam.com.tr/takip/5020?e=1786512000&s=Ef5',
  payUrl: 'https://api.benimlezzetdunyam.com.tr/odeme-simulasyon/xyz789',
  deliverUrl:
      'https://api.benimlezzetdunyam.com.tr/teslimat/5020?e=1786339200&s=Gh6',
);

/// Ödenmiş, düzenlenmemiş adrese gönderim — tahsilat satırı ve ödeme QR'ı YOK.
final CustomerReceiptData customerMergedPaid = CustomerReceiptData(
  orderNumber: 'S-5021',
  deliveryType: DeliveryType.delivery,
  printedAt: printedAt,
  lines: const [
    CustomerReceiptLine(quantity: 2, name: 'Tavuk Sote', lineTotal: 37000),
  ],
  subtotal: 37000,
  deliveryFee: 4000,
  total: 41000,
  paymentMethod: ReceiptPaymentMethod.online,
  paymentStatus: ReceiptPaymentStatus.paid,
  customerName: 'Mehmet Demir',
  customerPhone: '0532 987 65 43',
  address: const ReceiptAddress(
    line1: 'Örnek Mah. 12. Sk No:3',
    district: 'Selçuklu',
    city: 'Konya',
  ),
  deliverUrl:
      'https://api.benimlezzetdunyam.com.tr/teslimat/5021?e=1786339200&s=Ij7',
);

/// Gel-al + revizyon — bant var, kurye mobilyası YOK.
///
/// Bu dosyanın işi: birleşmenin gel-al fişine sızmadığını sabitlemek. Ad,
/// telefon, adres, tahsilat ve teslim QR'ı burada hiç basılmamalı.
final CustomerReceiptData customerPickupRevised = CustomerReceiptData(
  orderNumber: 'S-5022',
  deliveryType: DeliveryType.pickup,
  printedAt: printedAt,
  lines: const [
    CustomerReceiptLine(quantity: 1, name: 'Mercimek Çorbası', lineTotal: 8500),
  ],
  subtotal: 8500,
  deliveryFee: 0,
  total: 8500,
  paymentMethod: ReceiptPaymentMethod.cash,
  paymentStatus: ReceiptPaymentStatus.pending,
  revisionNo: 1,
  revisionSummary: const ['ÇIKARILDI: Tavuk Sote ×2'],
  // Sunucu gel-al'da bunları zaten null gönderiyor; yine de DOLU
  // veriliyor ki şablonun kendi kapısı (`showsCourierBlock`) sınansın.
  customerName: 'Ali Kaya',
  customerPhone: '0533 111 22 33',
  collectAmount: 8500,
  deliverUrl: 'https://api.benimlezzetdunyam.com.tr/teslimat/5022?e=1&s=Kl8',
);

/// Düzenlenmiş MUTFAK fişi (K-20) — `docs/10` S9-13'ün kapattığı açık.
final KitchenReceiptData kitchenRevised = KitchenReceiptData(
  orderNumber: 'S-5020',
  deliveryType: DeliveryType.delivery,
  printedAt: printedAt,
  requestedAt: requestedAt,
  customerPhone: '5551234567',
  customerNote: 'Fatura kurumsal',
  revisionNo: 2,
  revisionSummary: const ['Mercimek Çorbası: 20 → 10', 'ÇIKARILDI: Ayran ×5'],
  lines: const [
    KitchenReceiptLine(quantity: 10, name: 'Mercimek Çorbası'),
  ],
);

/// Kurye fişi — düzenlenmiş, kapıda ödemeli, haritalı sipariş (K-14).
///
/// EN ZOR VAKA BİLİNÇLİ SEÇİLDİ: revizyon başlığı, değişiklik listesi,
/// harita QR'ı ve tahsilat satırı bir arada. Kolay vakayı sabitlemek,
/// asıl kırılgan yolu korumasız bırakırdı.
final CourierReceiptData courierRevised = CourierReceiptData(
  orderNumber: 'S-5012',
  deliveryType: DeliveryType.delivery,
  printedAt: printedAt,
  requestedAt: requestedAt,
  customerName: 'Ayşe Yılmaz',
  customerPhone: '0555 123 45 67',
  customerNote: 'Zili çalmayın',
  revisionNo: 1,
  revisionSummary: const ['Mercimek Çorbası: 20 → 10', 'ÇIKARILDI: Ayran ×5'],
  collectAmount: 41000,
  total: 41000,
  paymentMethod: ReceiptPaymentMethod.cash,
  paymentStatus: ReceiptPaymentStatus.pending,
  lines: const [
    CustomerReceiptLine(quantity: 10, name: 'Mercimek Çorbası', lineTotal: 85000),
  ],
  address: const ReceiptAddress(
    line1: 'Örnek Mah. 12. Sk No:3',
    district: 'Selçuklu',
    city: 'Konya',
    latitude: 37.8901234,
    longitude: 32.4876543,
  ),
);

/// Ödenmiş, düzenlenmemiş sipariş — tahsilat satırı basılmamalı.
final CourierReceiptData courierPaid = CourierReceiptData(
  orderNumber: 'S-5014',
  deliveryType: DeliveryType.delivery,
  printedAt: printedAt,
  customerName: 'Mehmet Demir',
  customerPhone: '0532 987 65 43',
  total: 49500,
  paymentMethod: ReceiptPaymentMethod.online,
  paymentStatus: ReceiptPaymentStatus.paid,
  lines: const [
    CustomerReceiptLine(quantity: 2, name: 'Tavuk Sote', lineTotal: 37000),
  ],
  address: const ReceiptAddress(
    line1: 'Örnek Mah. 12. Sk No:3',
    district: 'Selçuklu',
    city: 'Konya',
  ),
);

/// Üretim planı — uyarılı, dolu bir gün (K-15).
///
/// UYARILI VAKA SEÇİLDİ: uyarısız plan kolay yol. "Üretim koşmamış"
/// satırının kâğıda gerçekten bastığını sabitlemek, ekranda görünüp
/// kâğıtta görünmeyen bir uyarının sessizce doğmasını engelliyor.
final ProductionPlanData productionPlan = ProductionPlanData(
  date: DateTime.utc(2026, 8, 12, 3),
  printedAt: printedAt,
  totals: const [
    ProductionPlanTotal(name: 'Mercimek Çorbası', quantity: 120),
    ProductionPlanTotal(name: 'Tavuk Sote', quantity: 85),
  ],
  deliveries: const [
    ProductionPlanDelivery(label: 'Konya Sanayi A.Ş.', time: '11:30', itemCount: 60),
    ProductionPlanDelivery(label: 'Meram Belediyesi', time: '12:00', itemCount: 45),
  ],
  warnings: const [
    'Abonelik #7 — bugün atlanıyor (istisna).',
  ],
);

/// Boş gün — "ÜRETİM YOK" satırı.
final ProductionPlanData productionPlanEmpty = ProductionPlanData(
  date: DateTime.utc(2026, 8, 12, 3),
  printedAt: printedAt,
  totals: const [],
  warnings: const [
    'Bu gün için 3 abonelik bekleniyor ama hiç sipariş üretilmemiş.',
  ],
);

/// BBD Store fişi (K-16) — **kitap** siparişi, kargolu, kapıda ödemeli.
///
/// UZUN KİTAP ADI BİLİNÇLİ SEÇİLDİ: şablonun ürün adını çift boyda
/// basmadığını ve satıra sardığını sabitliyor. Çift boyda 80 mm kâğıt
/// 24 sütun demek ve bu başlık üç satıra bölünürdü.
final BbdReceiptData bbdDelivery = BbdReceiptData(
  orderNumber: 'BBD-123',
  printedAt: printedAt,
  createdAt: DateTime.utc(2026, 8, 4, 11, 28),
  customerLabel: 'Ayşe Yılmaz',
  customerPhone: '0555 123 45 67',
  address: 'Örnek Mah. 12. Sk No:3, Selçuklu / Konya',
  deliveryType: 'delivery',
  cargoCompany: 'Yurtiçi Kargo',
  trackingNumber: '1234567890123',
  paymentLabel: 'Kapıda ödeme',
  note: 'Hediye paketi yapılsın',
  amount: 18500,
  lines: const [
    BbdReceiptLine(
      quantity: 2,
      name: "Türkiye'nin Yakın Tarihi — Cilt II",
      sku: '9789750718533',
      attributes: ['Ahmet Yılmaz', 'Ciltli, 3. baskı'],
      note: 'Kapağı çizik olmasın',
    ),
    BbdReceiptLine(quantity: 1, name: 'Sessiz Ev', sku: '9789750802942'),
  ],
);

/// Mağazadan teslim, tutarsız — BBD tutar göndermediğinde satır
/// basılmamalı ve adres bloğu hiç çıkmamalı.
final BbdReceiptData bbdPickup = BbdReceiptData(
  orderNumber: 'BBD-124',
  printedAt: printedAt,
  deliveryType: 'pickup',
  address: 'Basılmamalı Mah.',
  customerLabel: 'Mehmet Demir',
  lines: const [BbdReceiptLine(quantity: 1, name: 'Kürk Mantolu Madonna')],
);

void main() {
  // Golden klasörü çalışma dizininden yukarı doğru aranarak bulunur.
  //
  // NEDEN `Isolate.resolvePackageUri` DEĞİL: o çözüm `dart test` altında
  // çalışıyordu ama `mutfakapp` pub workspace'e katılınca testler
  // `flutter test` ile koşmaya başladı ve orada
  // `Isolate.resolvePackageUriSync` desteklenmiyor — tüm golden testleri
  // setUpAll'da patlıyordu.
  //
  // Yukarı arama her iki koşucuda da, hem paket içinden hem repo kökünden
  // çalışır ve hiçbir SDK ayrıntısına bağlı değildir.
  setUpAll(() {
    var dizin = Directory.current;

    for (var i = 0; i < 6; i++) {
      final aday = Directory('${dizin.path}/packages/core/test/golden');
      if (aday.existsSync()) {
        _goldenDir = aday;
        return;
      }

      final yerel = Directory('${dizin.path}/test/golden');
      if (yerel.existsSync() && dizin.path.endsWith('core')) {
        _goldenDir = yerel;
        return;
      }

      final ust = dizin.parent;
      if (ust.path == dizin.path) break;
      dizin = ust;
    }

    fail(
      'Golden klasörü bulunamadı. Çalışma dizini: ${Directory.current.path}',
    );
  });

  group('Golden — mutfak fişi', () {
    test('adrese gönderim', () {
      expectGolden(
        'receipt_mutfak_delivery',
        buildKitchenReceipt(kitchenDelivery),
      );
    });

    test('gel-al', () {
      expectGolden('receipt_mutfak_pickup', buildKitchenReceipt(kitchenPickup));
    });

    test('düzenlenmiş sipariş — GÜNCEL FİŞ bandı (K-20)', () {
      expectGolden('receipt_mutfak_revize', buildKitchenReceipt(kitchenRevised));
    });
  });

  group('Golden — müşteri fişi', () {
    test('adrese gönderim', () {
      expectGolden(
        'receipt_musteri_delivery',
        buildCustomerReceipt(customerDelivery),
      );
    });

    test('gel-al', () {
      expectGolden(
        'receipt_musteri_pickup',
        buildCustomerReceipt(customerPickup),
      );
    });

    test('haritadan seçilmiş konumla (QR)', () {
      expectGolden(
        'receipt_musteri_delivery_qr',
        buildCustomerReceipt(customerDeliveryWithPin),
      );
    });

    test('takip ve ödeme QR\'lı (K-18/K-19)', () {
      expectGolden(
        'receipt_musteri_qr_takip_odeme',
        buildCustomerReceipt(customerDeliveryWithQrs),
      );
    });

    test('ödenmiş siparişte ödeme QR\'ı basılmaz', () {
      expectGolden(
        'receipt_musteri_qr_yalniz_takip',
        buildCustomerReceipt(customerPaidWithTrackQr),
      );
    });

    test('birleşik fiş — revizyonlu, tahsilatlı, üç QR\'lı (K-20)', () {
      expectGolden(
        'receipt_musteri_birlesik_revize',
        buildCustomerReceipt(customerMerged),
      );
    });

    test('birleşik fiş — ödenmiş, tahsilat satırı yok (K-20)', () {
      expectGolden(
        'receipt_musteri_birlesik_odenmis',
        buildCustomerReceipt(customerMergedPaid),
      );
    });

    test('gel-al + revizyon — kurye bloğu sızmaz (K-20)', () {
      expectGolden(
        'receipt_musteri_pickup_revize',
        buildCustomerReceipt(customerPickupRevised),
      );
    });
  });

  /// Fiş birleşmesinin KURALLARI — K-20.
  ///
  /// Golden dosyaları baytları donduruyor ve şablon bilinçli değiştiğinde
  /// yenileniyor. Buradakiler ise kararın kendisini sabitliyor: bandın
  /// fişin en üstünde olması ya da gel-al fişinde tahsilat satırının hiç
  /// bulunmaması bir tasarım kararı, bayt dizisinin yan etkisi değil.
  group('Birleşik fiş kuralları (K-20)', () {
    test('GÜNCEL FİŞ bandı yalnız revizyonda basılır', () {
      final duz = buildCustomerReceipt(customerMergedPaid);

      expect(customerMergedPaid.isRevised, isFalse);
      expect(_contains(duz, Pc857.encode('GÜNCEL FİŞ')), isFalse);
      expect(
        _contains(buildCustomerReceipt(customerMerged), Pc857.encode('GÜNCEL')),
        isTrue,
      );
    });

    test('bant fişin EN ÜSTÜNDE — işletme adından önce', () {
      final bytes = buildCustomerReceipt(customerMerged);

      // Bandın tek işi, elde duran ÖNCEKİ kâğıdı geçersiz kılmak. Bir
      // satır aşağıda olsaydı katlanmış bir fişte görünmezdi.
      expect(
        _indexOf(bytes, Pc857.encode('GÜNCEL')),
        lessThan(_indexOf(bytes, Pc857.encode('BENİM'))),
      );
    });

    test('mutfak fişinde de REVİZE bandı vardır', () {
      // `docs/10-test-kabul.md` S9-13 bunu zaten şart koşuyordu; K-20'ye
      // kadar yalnız kurye fişinde vardı.
      final bytes = buildKitchenReceipt(kitchenRevised);

      expect(_contains(bytes, Pc857.encode('REVİZE #2')), isTrue);
      expect(_contains(bytes, Pc857.encode('ÖNCEKİ FİŞİ ATIN')), isTrue);
    });

    test('düzenlenmemiş mutfak fişinde bant YOK', () {
      expect(
        _contains(buildKitchenReceipt(kitchenDelivery), Pc857.encode('GÜNCEL')),
        isFalse,
      );
    });

    test('DEĞİŞİKLİKLER listesi boşsa blok hiç basılmaz', () {
      final data = CustomerReceiptData(
        orderNumber: 'S-1',
        deliveryType: DeliveryType.delivery,
        printedAt: printedAt,
        lines: const [
          CustomerReceiptLine(quantity: 1, name: 'Çorba', lineTotal: 8500),
        ],
        subtotal: 8500,
        deliveryFee: 0,
        total: 8500,
        paymentMethod: ReceiptPaymentMethod.cash,
        paymentStatus: ReceiptPaymentStatus.pending,
        revisionNo: 1,
      );

      final bytes = buildCustomerReceipt(data);

      // Bant basılır (kâğıt eskimiş olabilir) ama başlıksız boş bir liste
      // personele bir şeyin kayıp olduğunu düşündürürdü.
      expect(_contains(bytes, Pc857.encode('REVİZE #1')), isTrue);
      expect(_contains(bytes, Pc857.encode('DEĞİŞİKLİKLER')), isFalse);
    });

    test('müşteri fişi kurye bilgisini taşır', () {
      final bytes = buildCustomerReceipt(customerMerged);

      // Ayrı kurye fişi artık basılmıyor; bu üçü burada yoksa kurye
      // kapıda kime, nereye ve ne kadar sorusunu cevaplayamaz.
      expect(_contains(bytes, Pc857.encode('AYŞE YILMAZ')), isTrue);
      expect(_contains(bytes, Pc857.encode('Tel: 0555 123 45 67')), isTrue);
      expect(_contains(bytes, Pc857.encode('Örnek Mah. 12. Sk No:3')), isTrue);
      expect(_contains(bytes, Pc857.encode('TAHSİL: 1.260,00')), isTrue);
    });

    test('sipariş notu kurye bloğunda — adresin yanında', () {
      final bytes = buildCustomerReceipt(customerMerged);

      // "Zili çalmayın" bir KAPI TALİMATI: kurye onu yola çıkmadan
      // okumalı, fişin dibinde değil. Kurye fişi kalkarken taşınmasaydı
      // talimat kuryenin elinden tamamen silinirdi.
      expect(_contains(bytes, Pc857.encode('NOT: Zili çalmayın')), isTrue);
      expect(
        _indexOf(bytes, Pc857.encode('NOT: Zili çalmayın')),
        lessThan(_indexOf(bytes, Pc857.encode('Ara Toplam'))),
      );
    });

    test('telefon ÇİFT BOY basılır', () {
      final bytes = buildCustomerReceipt(customerMerged);
      final phone = _indexOf(bytes, Pc857.encode('Tel: 0555'));

      expect(
        _lastIndexOf(bytes.sublist(0, phone), EscPosCommands.doubleSizeOn),
        greaterThan(
          _lastIndexOf(bytes.sublist(0, phone), EscPosCommands.doubleSizeOff),
        ),
        reason: 'kurye numarayı araçta, kötü ışıkta, tek elle okuyor',
      );
    });

    test('teslimat bloğu fiyat tablosunun ÜSTÜNDE', () {
      final bytes = buildCustomerReceipt(customerMerged);

      // Kurye önce nereye gideceğine bakıyor; kalem fiyatlarına hiç
      // bakmıyor. Blok aşağıda kalsaydı her teslimatta fişin tamamı
      // okunmak zorunda olurdu.
      expect(
        _indexOf(bytes, Pc857.encode('Örnek Mah')),
        lessThan(_indexOf(bytes, Pc857.encode('Ara Toplam'))),
      );
    });

    test('DEĞİŞİKLİKLER toplam ile tahsilat ARASINDA', () {
      final bytes = buildCustomerReceipt(customerMerged);

      // "Toplam bu → çünkü şunlar değişti → şu kadar al" zinciri, kapıda
      // tutar tartışması çıktığında okunacak sıradır.
      final toplam = _indexOf(bytes, Pc857.encode('TOPLAM'));
      final degisiklik = _indexOf(bytes, Pc857.encode('DEĞİŞİKLİKLER'));
      final tahsil = _indexOf(bytes, Pc857.encode('TAHSİL:'));

      expect(toplam, lessThan(degisiklik));
      expect(degisiklik, lessThan(tahsil));
    });

    test('ödenmiş siparişte TAHSİL satırı hiç basılmaz', () {
      // Sıfırlık bir "tahsil edilecek" satırı, kuryenin bir sonraki fişte
      // gerçek tutarı gözden kaçırmasına yol açıyordu.
      expect(
        _contains(buildCustomerReceipt(customerMergedPaid), Pc857.encode('TAHSİL')),
        isFalse,
      );
    });

    test('GEL-AL fişinde kurye mobilyası YOKTUR', () {
      final bytes = buildCustomerReceipt(customerPickupRevised);

      // Veri DOLU geliyor; kapı şablonun kendisinde olmalı.
      expect(customerPickupRevised.customerName, isNotNull);
      expect(customerPickupRevised.collectAmount, greaterThan(0));

      expect(_contains(bytes, Pc857.encode('ALİ KAYA')), isFalse);
      expect(_contains(bytes, Pc857.encode('Tel:')), isFalse);
      expect(_contains(bytes, Pc857.encode('TAHSİL')), isFalse);
      expect(_contains(bytes, Pc857.encode('GEL-AL')), isTrue);

      // Bant gel-al fişinde de basılır: o kâğıt da eskimiş olabilir.
      expect(_contains(bytes, Pc857.encode('REVİZE #1')), isTrue);
    });

    test('gel-al fişinde teslim QR\'ı basılmaz', () {
      expect(customerPickupRevised.deliverUrl, isNotNull);
      expect(customerPickupRevised.hasDeliverQr, isFalse);
    });

    test('teslim QR\'ı başlıklı basılır', () {
      // Kâğıt teslimden sonra müşteride kalıyor; kurye bunu kapıda,
      // kâğıdı vermeden ÖNCE okutmalı. Başlıksız üçüncü bir kare
      // hangisinin kimin olduğunu belirsiz bırakırdı.
      expect(
        _contains(
          buildCustomerReceipt(customerMerged),
          Pc857.encode('KURYE: TESLİMDEN ÖNCE OKUT'),
        ),
        isTrue,
      );
    });
  });

  /// QR'ların KURALI — golden baytlardan bağımsız, okunabilir doğrulama.
  ///
  /// Golden dosyası "bayt bayt aynı mı" diye bakıyor ve şablon bilinçli
  /// değiştiğinde yenileniyor. Bu testler ise kuralın kendisini sabitliyor:
  /// ödenmiş siparişe ödeme QR'ı basılmaması bir tasarım kararı, bayt
  /// dizisinin yan etkisi değil.
  group('Fiş QR kuralları', () {
    test('bağlantı yoksa QR hiç basılmaz', () {
      final data = CustomerReceiptData(
        orderNumber: 'S-1',
        deliveryType: DeliveryType.pickup,
        printedAt: printedAt,
        lines: const [
          CustomerReceiptLine(quantity: 1, name: 'Çorba', lineTotal: 8500),
        ],
        subtotal: 8500,
        deliveryFee: 0,
        total: 8500,
        paymentMethod: ReceiptPaymentMethod.cash,
        paymentStatus: ReceiptPaymentStatus.pending,
      );

      expect(data.hasTrackQr, isFalse);
      expect(data.hasPayQr, isFalse);
    });

    test('boş dize bağlantı sayılmaz', () {
      final data = CustomerReceiptData(
        orderNumber: 'S-1',
        deliveryType: DeliveryType.pickup,
        printedAt: printedAt,
        lines: const [
          CustomerReceiptLine(quantity: 1, name: 'Çorba', lineTotal: 8500),
        ],
        subtotal: 8500,
        deliveryFee: 0,
        total: 8500,
        paymentMethod: ReceiptPaymentMethod.cash,
        paymentStatus: ReceiptPaymentStatus.pending,
        trackUrl: '   ',
        payUrl: '',
      );

      // Boş dize geçseydi QR yerine kare bir gürültü basılırdı.
      expect(data.hasTrackQr, isFalse);
      expect(data.hasPayQr, isFalse);
    });

    test('ödeme QR\'ı olan fiş takip QR\'ını da taşır', () {
      expect(customerDeliveryWithQrs.hasPayQr, isTrue);
      expect(customerDeliveryWithQrs.hasTrackQr, isTrue);
    });

    test('ödenmiş siparişte yalnız takip QR\'ı kalır', () {
      expect(customerPaidWithTrackQr.hasPayQr, isFalse);
      expect(customerPaidWithTrackQr.hasTrackQr, isTrue);
    });
  });

  group('Golden — kurye fişi', () {
    test('revize edilmiş, kapıda ödemeli', () {
      expectGolden('receipt_kurye_revize', buildCourierReceipt(courierRevised));
    });

    test('ödenmiş sipariş', () {
      expectGolden('receipt_kurye_odenmis', buildCourierReceipt(courierPaid));
    });
  });

  group('Kurye fişi kuralları', () {
    test('REVİZE başlığı yalnız düzenlenmiş siparişte basılır', () {
      // Kuryenin elinde eski bir fiş olabilir; başlık yanlış tutar
      // tahsil edilmesinin önündeki tek engel.
      expect(
        _contains(buildCourierReceipt(courierRevised), 'REVİZE'.codeUnits),
        isFalse,
        reason: 'Türkçe harfler PC857 ile kodlanır; ham ASCII eşleşmemeli.',
      );

      final revised = buildCourierReceipt(courierRevised);
      final plain = buildCourierReceipt(courierPaid);

      expect(revised.length, greaterThan(plain.length));
    });

    test('ÖDENMİŞ SİPARİŞTE tahsilat satırı YOKTUR', () {
      // Sıfırlık bir "tahsil edilecek" satırı, kuryenin bir sonraki
      // fişte gerçek tutarı gözden kaçırmasına yol açıyor.
      final bytes = buildCourierReceipt(courierPaid);

      expect(_contains(bytes, Money.formatForReceipt(0).codeUnits), isFalse);
    });

    test('adres iğnesi varsa QR basılır', () {
      expect(
        _contains(buildCourierReceipt(courierRevised), EscPosCommands.qrPrint),
        isTrue,
      );
    });

    test('iğne yoksa QR basılmaz', () {
      expect(
        _contains(buildCourierReceipt(courierPaid), EscPosCommands.qrPrint),
        isFalse,
      );
    });
  });

  group('Golden — üretim planı fişi', () {
    test('dolu gün, uyarılı', () {
      expectGolden(
        'receipt_uretim_plani',
        buildProductionPlanReceipt(productionPlan),
      );
    });

    test('boş gün', () {
      expectGolden(
        'receipt_uretim_plani_bos',
        buildProductionPlanReceipt(productionPlanEmpty),
      );
    });
  });

  group('Üretim planı kuralları', () {
    test('UYARILAR listeden ÖNCE basılır', () {
      // Alta konsaydı, listeyi okuyup üstünü çizen personel oraya hiç
      // bakmazdı.
      // ASCII parçalarla aranıyor: Türkçe harfler PC857 ile kodlanıyor
      // ve Dart'ın UTF-16 kod birimleriyle eşleşmiyor.
      final bytes = buildProductionPlanReceipt(productionPlan);
      final warningAt = _indexOf(bytes, 'KKAT'.codeUnits);
      final firstItemAt = _indexOf(bytes, 'MERC'.codeUnits);

      expect(warningAt, greaterThanOrEqualTo(0));
      expect(firstItemAt, greaterThan(warningAt));
    });

    test('boş günde ÜRETİM YOK yazar, sessiz kalmaz', () {
      // Boş bir kâğıt "yazıcı bozuk mu" sorusunu doğurur.
      expect(
        _contains(
          buildProductionPlanReceipt(productionPlanEmpty),
          'YOK'.codeUnits,
        ),
        isTrue,
      );
    });

    test('teslimatı olmayan planda TESLİMAT bloğu basılmaz', () {
      expect(
        _contains(
          buildProductionPlanReceipt(productionPlanEmpty),
          'TESL'.codeUnits,
        ),
        isFalse,
      );
    });

    test('plan fişi MÜŞTERİ ve FİYAT taşımaz', () {
      // Sipariş fişi değil, üretim raporu.
      final bytes = buildProductionPlanReceipt(productionPlan);

      expect(_contains(bytes, 'Tel'.codeUnits), isFalse);
      expect(_contains(bytes, 'TOPLAM'.codeUnits), isFalse);
    });
  });

  group('Golden — BBD Store fişi', () {
    test('adrese gönderim, tutarlı', () {
      expectGolden('receipt_bbd_delivery', buildBbdReceipt(bbdDelivery));
    });

    test('gel-al, tutarsız', () {
      expectGolden('receipt_bbd_pickup', buildBbdReceipt(bbdPickup));
    });
  });

  group('BBD fişi kuralları', () {
    test('BLD fişinden AYIRT EDİLEBİLİR — başlıkta BBD STORE yazar', () {
      // Bu sipariş KDS panosunda YOK. Kâğıdı BLD fişiyle karıştıran
      // personel, panoda olmayan bir siparişi arar ve bulamaz.
      expect(
        _contains(buildBbdReceipt(bbdDelivery), 'BBD STORE'.codeUnits),
        isTrue,
      );
    });

    test('panoda görünmediği fişin üstünde YAZAR', () {
      expect(
        _contains(buildBbdReceipt(bbdDelivery), 'panosunda'.codeUnits),
        isTrue,
      );
    });

    test('KİTAP ADI ÇİFT BOY BASILMAZ — uzun başlık satıra sarılır', () {
      // Mutfak fişinde ürün adı çift boydur (bir metreden okunuyor).
      // Kitap adları uzun ve 80 mm kâğıtta çift boy 24 sütun demek;
      // başlık üç satıra bölünür ve fiş okunmaz hâle gelir.
      //
      // ASCII bir başlık aranıyor: Türkçe harfler PC857 ile kodlanıyor ve
      // Dart'ın kod birimleriyle eşleşmiyor.
      final bytes = buildBbdReceipt(bbdDelivery);
      final titleAt = _indexOf(bytes, 'Sessiz Ev'.codeUnits);

      expect(titleAt, greaterThan(0));

      // Başlıktan ÖNCEKİ son boyut komutu "kapat" olmalı: açıksa ad çift
      // boyda basılıyor demektir.
      final head = bytes.sublist(0, titleAt);
      expect(
        _lastIndexOf(head, EscPosCommands.doubleSizeOff),
        greaterThan(_lastIndexOf(head, EscPosCommands.doubleSizeOn)),
        reason: 'Kitap adı çift boyda basılmamalı.',
      );
    });

    test('ADET ÇİFT BOY BASILIR — okunması gereken sayı odur', () {
      final bytes = buildBbdReceipt(bbdDelivery);
      final qtyAt = _indexOf(bytes, '2x'.codeUnits);

      expect(qtyAt, greaterThan(0));

      final head = bytes.sublist(0, qtyAt);
      expect(
        _lastIndexOf(head, EscPosCommands.doubleSizeOn),
        greaterThan(_lastIndexOf(head, EscPosCommands.doubleSizeOff)),
      );
    });

    test('STOK KODU basılır — raftan bulmanın en hızlı yolu', () {
      expect(
        _contains(buildBbdReceipt(bbdDelivery), '9789750718533'.codeUnits),
        isTrue,
      );
    });

    test('KARGO TAKİP NUMARASI basılır', () {
      // Paketin üstündeki etiketle elle karşılaştırılıyor.
      expect(
        _contains(buildBbdReceipt(bbdDelivery), '1234567890123'.codeUnits),
        isTrue,
      );
    });

    test('MAĞAZADAN TESLİMDE adres bloğu BASILMAZ', () {
      // Basılan adres, paketin yanlışlıkla kargoya verilmesine yol açar.
      final bytes = buildBbdReceipt(bbdPickup);

      expect(_contains(bytes, 'Bas'.codeUnits), isFalse);
      expect(_contains(bytes, 'MA'.codeUnits), isTrue);
    });

    test('kargo bilgisi yoksa boş "Kargo:" satırı basılmaz', () {
      // Boş bir başlık, paketleyene bir şeyin eksik olduğunu düşündürür.
      expect(
        _contains(buildBbdReceipt(bbdPickup), 'Kargo'.codeUnits),
        isFalse,
      );
    });

    test('TUTAR gönderilmediyse satır BASILMAZ', () {
      // Uydurulmuş ya da sıfır bir tutar, kapıda ödemede yanlış
      // tahsilata yol açar.
      expect(
        _contains(buildBbdReceipt(bbdPickup), 'TUTAR'.codeUnits),
        isFalse,
      );
      expect(
        _contains(buildBbdReceipt(bbdDelivery), 'TUTAR'.codeUnits),
        isTrue,
      );
    });

    test('satır bazında FİYAT basılmaz', () {
      // BBD'nin fiyatlandırması bizim değil; yanlış kaynaktan alınmış
      // bir sayı, paketleyene güvenilmez bilgi vermek olurdu.
      final bytes = buildBbdReceipt(bbdDelivery);
      final text = String.fromCharCodes(
        bytes.where((b) => b >= 32 && b < 127),
      );

      // Tek para tutarı toplam satırındaki olmalı.
      expect(',00'.allMatches(text).length, 1);
    });
  });

  group('QR kod', () {
    test('iğne yoksa QR komutu hiç basılmaz', () {
      // Koordinatsız sipariş fişinde QR bloğu bulunmamalı; boş bir QR
      // yazıcıda çöp sembol üretir.
      final bytes = buildCustomerReceipt(customerDelivery);
      expect(_contains(bytes, EscPosCommands.qrPrint), isFalse);
    });

    test('iğne varsa QR basma komutu bulunur', () {
      final bytes = buildCustomerReceipt(customerDeliveryWithPin);
      expect(_contains(bytes, EscPosCommands.qrPrint), isTrue);
    });

    test('QR verisi harita bağlantısını taşır', () {
      final bytes = buildCustomerReceipt(customerDeliveryWithPin);
      final url = customerDeliveryWithPin.address!.mapUrl;

      expect(_contains(bytes, url.codeUnits), isTrue);
      // Yedi ondalık korunmalı: yuvarlama iğneyi metrelerce kaydırır.
      expect(url, contains('37.8901234,32.4876543'));
    });

    test('uzunluk baytı cn+fn+m dahil sayılır', () {
      // En sık yapılan hata yalnızca veri uzunluğunu yazmak. O durumda
      // yazıcı eksik bayt bekler, sonraki komutları veri sanar ve fişin
      // geri kalanı çöp basar.
      final store = EscPosCommands.qrStore(List<int>.filled(10, 0x41));

      expect(store[3], 13, reason: 'pL = veri + 3 olmalı');
      expect(store[4], 0, reason: 'pH');
      expect(store.length, 18);
    });

    test('uzunluk 255i aşınca pH kullanılır', () {
      // Uzun bir URL (ör. ondalıkları tam koordinat + ek parametre) 255
      // baytı aşabilir; tek baytlık uzunluk sessizce taşardı.
      final store = EscPosCommands.qrStore(List<int>.filled(300, 0x41));

      expect(store[3], (303) & 0xFF);
      expect(store[4], (303) >> 8);
    });
  });

  group('Şablon değişmezleri', () {
    test('mutfak fişinde fiyat geçmez', () {
      final text = _decode(buildKitchenReceipt(kitchenDelivery));
      expect(text, isNot(contains('370,00')));
      expect(text, isNot(contains('TOPLAM')));
      expect(text, isNot(contains('Ödeme')));
    });

    test('mutfak fişinde adres geçmez', () {
      final text = _decode(buildKitchenReceipt(kitchenDelivery));
      expect(text, isNot(contains('Teslimat:')));
      expect(text, isNot(contains('Konya')));
    });

    test('mutfak fişinde müşteri telefonu çift boy basılır', () {
      // Kurye kapıda kaldığında arayacağı numara fişte olmalı — ve mutfağın
      // ışığında bir metre öteden okunabilmeli.
      final bytes = buildKitchenReceipt(kitchenDelivery);
      final text = _decode(bytes);
      expect(text, contains('Tel: 0555 123 45 67'));

      // Çift boy komutu telefon satırından ÖNCE gelmeli.
      expect(
        _contains(bytes, [
          ...EscPosCommands.doubleSizeOn,
          ...EscPosCommands.boldOn,
          ...'Tel: '.codeUnits,
        ]),
        isTrue,
      );
    });

    test('telefon çift boyda satıra sığar', () {
      // Çift boyda bir satır 24 karakter: taşan numara yazıcının kendi
      // kaydırmasına düşer ve ikiye bölünmüş bir telefon okunmaz olur.
      final text = _decode(buildKitchenReceipt(kitchenDelivery));
      final line = text
          .split('\n')
          .firstWhere((row) => row.startsWith('Tel: '));

      expect(line.length, lessThanOrEqualTo(ReceiptStyle.standard.doubleColumns));
    });

    test('telefon yoksa Tel satırı hiç basılmaz', () {
      // Boş bir "Tel:" satırı kuryeye numara olduğunu düşündürüp aratırdı.
      final text = _decode(buildKitchenReceipt(kitchenPickup));
      expect(text, isNot(contains('Tel:')));
    });

    test('gel-al müşteri fişinde teslimat ücreti satırı yoktur', () {
      final text = _decode(buildCustomerReceipt(customerPickup));
      expect(text, isNot(contains('Teslimat')));
      expect(text, contains('GEL-AL'));
    });

    test('adrese gönderim müşteri fişinde adres bloğu vardır', () {
      // BAŞLIK `TESLİMAT:` DEĞİL `TESLİMAT` (K-20): blok artık yalnız adres
      // değil, kuryenin tüm bloğu — ad, telefon, adres, kapı notu.
      final text = _decode(buildCustomerReceipt(customerDelivery));
      expect(text, contains('TESLİMAT'));
      expect(text, contains('Örnek Mah. 12. Sk No:3'));
      expect(text, contains('Selçuklu / Konya'));
      expect(text, isNot(contains('GEL-AL')));
    });

    test('her fiş sıfırlama ile başlar, kesme ile biter', () {
      for (final bytes in [
        buildKitchenReceipt(kitchenDelivery),
        buildKitchenReceipt(kitchenPickup),
        buildCustomerReceipt(customerDelivery),
        buildCustomerReceipt(customerPickup),
      ]) {
        expect(bytes.sublist(0, 5), [
          ...EscPosCommands.initialize,
          ...EscPosCommands.selectCodePage(EscPosCommands.turkishCodePage),
        ]);
        expect(bytes.sublist(bytes.length - 4), EscPosCommands.cut);
      }
    });

    test('sipariş notu asla kırpılmaz', () {
      final data = KitchenReceiptData(
        orderNumber: 'S-9001',
        deliveryType: DeliveryType.pickup,
        printedAt: printedAt,
        customerNote:
            'Kapıda arayın, asansör bozuk, üçüncü kata elden çıkarılacak '
            've fatura kurumsal kesilecek',
        lines: const [KitchenReceiptLine(quantity: 1, name: 'Ayran')],
      );
      final text = _decode(buildKitchenReceipt(data)).replaceAll('\n', ' ');
      expect(text, contains('elden çıkarılacak'));
      expect(text, contains('fatura kurumsal kesilecek'));
    });

    test('uzun ürün adı satıra sığdırılır, taşma yapmaz', () {
      final data = CustomerReceiptData(
        orderNumber: 'S-9002',
        deliveryType: DeliveryType.pickup,
        printedAt: printedAt,
        lines: const [
          CustomerReceiptLine(
            quantity: 1,
            name: 'Fırında Kaşarlı Karnıyarık Özel Porsiyon Büyük Boy',
            lineTotal: 19900,
          ),
        ],
        subtotal: 19900,
        deliveryFee: 0,
        total: 19900,
        paymentMethod: ReceiptPaymentMethod.account,
        paymentStatus: ReceiptPaymentStatus.pending,
      );
      for (final line in _decode(buildCustomerReceipt(data)).split('\n')) {
        expect(line.length, lessThanOrEqualTo(ReceiptStyle.standard.columns));
      }
    });

    test('şablonlar saftır — aynı girdi aynı baytları verir', () {
      expect(
        buildCustomerReceipt(customerDelivery),
        buildCustomerReceipt(customerDelivery),
      );
    });
  });
}

// ───────────────────────────── Golden altyapısı ─────────────────────────────

/// Golden dosyalarının bulunduğu klasör; `setUpAll` doldurur.
late Directory _goldenDir;

void expectGolden(String name, Uint8List actual) {
  final file = File('${_goldenDir.path}/$name.hex');

  if (Platform.environment['BLD_UPDATE_GOLDEN'] == '1') {
    _goldenDir.createSync(recursive: true);
    file.writeAsStringSync(_toHexDump(name, actual));
    return;
  }

  if (!file.existsSync()) {
    fail(
      'Golden dosyası yok: ${file.path}\n'
      'Bilinçli bir şablon değişimiyse: BLD_UPDATE_GOLDEN=1 dart test',
    );
  }

  final expected = _parseHexDump(file.readAsStringSync());
  expect(
    actual,
    expected,
    reason:
        'Fiş çıktısı ${file.path} ile uyuşmuyor.\n'
        '── Üretilen ──\n${_decode(actual)}\n'
        '── Beklenen ──\n${_decode(Uint8List.fromList(expected))}',
  );
}

/// Baytları gözden geçirilebilir bir hex dökümüne çevirir.
///
/// Ham `.bin` yerine hex metin tutulur: `git diff` okunabilir olsun, fişin
/// hangi satırının değiştiği review'da görülebilsin.
String _toHexDump(String name, Uint8List bytes) {
  final buffer = StringBuffer()
    ..writeln('# $name — beklenen ESC/POS baytları (${bytes.length} bayt)')
    ..writeln('# Üreten: packages/core/test/escpos_golden_test.dart')
    ..writeln('# Yenileme: BLD_UPDATE_GOLDEN=1 dart test')
    ..writeln('#')
    ..writeln('# Okunabilir karşılığı (kontrol baytları noktayla gösterilir):');

  for (final line in _decode(bytes).split('\n')) {
    buffer.writeln('#   $line');
  }
  buffer.writeln();

  for (var offset = 0; offset < bytes.length; offset += 16) {
    final end = (offset + 16 < bytes.length) ? offset + 16 : bytes.length;
    buffer.writeln(
      bytes
          .sublist(offset, end)
          .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
          .join(' '),
    );
  }
  return buffer.toString();
}

List<int> _parseHexDump(String content) => content
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('#'))
    .expand((line) => line.trim().split(RegExp(r'\s+')))
    .where((token) => token.isNotEmpty)
    .map((token) => int.parse(token, radix: 16))
    .toList(growable: false);

/// Baytları insan okuması için geri çevirir.
///
/// Kontrol dizileri (`ESC ...`, `GS ...`) atılır, satır beslemesi `\n` olur,
/// PC857 baytları Unicode'a döner. Yalnızca teşhis içindir.
/// [bytes] içinde [pattern] SON nerede geçiyor? Yoksa `-1`.
///
/// "Bu metinden önceki son boyut komutu hangisiydi" sorusu için.
int _lastIndexOf(List<int> bytes, List<int> pattern) {
  for (var i = bytes.length - pattern.length; i >= 0; i--) {
    var eslesti = true;
    for (var j = 0; j < pattern.length; j++) {
      if (bytes[i + j] != pattern[j]) {
        eslesti = false;
        break;
      }
    }
    if (eslesti) return i;
  }
  return -1;
}

/// [bytes] içinde [pattern] ilk nerede geçiyor? Yoksa `-1`.
///
/// Sıra sınamak için: "uyarı listeden önce mi basılıyor" sorusunun cevabı
/// iki konumun karşılaştırılmasıdır.
int _indexOf(List<int> bytes, List<int> pattern) {
  if (pattern.isEmpty || pattern.length > bytes.length) return -1;

  for (var i = 0; i <= bytes.length - pattern.length; i++) {
    var eslesti = true;
    for (var j = 0; j < pattern.length; j++) {
      if (bytes[i + j] != pattern[j]) {
        eslesti = false;
        break;
      }
    }
    if (eslesti) return i;
  }
  return -1;
}

/// [bytes] içinde [pattern] dizisi geçiyor mu?
///
/// Metne çevirip aramıyoruz: QR komutları yazdırılabilir olmayan baytlar
/// içeriyor ve PC857 çözümü onları bozar.
bool _contains(List<int> bytes, List<int> pattern) {
  if (pattern.isEmpty || pattern.length > bytes.length) return false;

  for (var i = 0; i <= bytes.length - pattern.length; i++) {
    var eslesti = true;
    for (var j = 0; j < pattern.length; j++) {
      if (bytes[i + j] != pattern[j]) {
        eslesti = false;
        break;
      }
    }
    if (eslesti) return true;
  }
  return false;
}

String _decode(List<int> bytes) {
  final buffer = StringBuffer();
  var index = 0;

  while (index < bytes.length) {
    final byte = bytes[index];

    if (byte == 0x1B) {
      // ESC @ iki bayt, diğerleri (ESC a n / ESC E n / ESC t n) üç bayt.
      index += (index + 1 < bytes.length && bytes[index + 1] == 0x40) ? 2 : 3;
      continue;
    }
    if (byte == 0x1D) {
      // GS ! n üç bayt, GS V B n dört bayt.
      index += (index + 1 < bytes.length && bytes[index + 1] == 0x56) ? 4 : 3;
      continue;
    }
    if (byte == EscPosCommands.lineFeed) {
      buffer.write('\n');
      index++;
      continue;
    }

    buffer.write(_reverseTable[byte] ?? String.fromCharCode(byte));
    index++;
  }

  return buffer.toString();
}

/// PC857 baytı → karakter. [Pc857.encode] üzerinden türetilir ki tablonun tek
/// kaynağı kalsın.
final Map<int, String> _reverseTable = {
  for (var codeUnit = 0xA0; codeUnit <= 0x2600; codeUnit++)
    if (Pc857.canEncode(String.fromCharCode(codeUnit)))
      Pc857.encode(String.fromCharCode(codeUnit)).single: String.fromCharCode(
        codeUnit,
      ),
};
