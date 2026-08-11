/// Fiş şablonlarının girdi modelleri — `docs/05-mutfakapp.md` §5.3.
///
/// **Neden `bld_api_client` DTO'ları doğrudan kullanılmıyor:** `bld_api_client`
/// zaten `bld_core`'a bağımlıdır; ters yönde bağımlılık döngü yaratırdı. Bu
/// yüzden yazdırma motoru kendi saf girdi tiplerini tanımlar, DTO → girdi
/// dönüşümü `mutfakapp` tarafındadır.
///
/// Tüm alanlar **hazır veridir**: şablonlar hesap yapmaz, saat okumaz, ağa
/// çıkmaz. Bu sayede golden testler belirlenimcidir.
library;

import '../delivery_type.dart';

/// Fiş tipi.
///
/// "Teslim" fişi öğrenci kanalıyla birlikte iptal edilmiştir
/// (`docs/BILINMEYENLER.md` #1). [kurye] ise K-14 ile eklendi: sipariş
/// düzenleme akışında kuryenin eline giden bilgi (ad, telefon, adres,
/// tahsil edilecek fark) mutfak fişine de müşteri fişine de sığmıyordu —
/// mutfak fişinde adres yok, müşteri fişi ise müşteride kalıyor.
enum ReceiptKind {
  mutfak('mutfak'),
  musteri('musteri'),
  kurye('kurye');

  const ReceiptKind(this.wireName);

  final String wireName;
}

/// Fişe basılacak ödeme yöntemi.
///
/// `bld_api_client`'taki `PaymentMethod`'un fiş karşılığıdır; etiketleri
/// ayrıdır çünkü fiş satırı dardır (`Kapıda` ↔ arayüzdeki `Kapıda ödeme`).
enum ReceiptPaymentMethod {
  online('Online'),
  cash('Kapıda'),
  account('Cari hesap'),
  unknown('Bilinmeyen');

  const ReceiptPaymentMethod(this.label);

  final String label;
}

/// Fişe basılacak ödeme durumu.
enum ReceiptPaymentStatus {
  pending('Bekliyor'),
  paid('Ödendi'),
  unknown('Belirsiz');

  const ReceiptPaymentStatus(this.label);

  final String label;
}

/// Mutfak fişindeki tek satır. Fiyat **yoktur**.
class KitchenReceiptLine {
  const KitchenReceiptLine({
    required this.quantity,
    required this.name,
    this.options = const <String>[],
    this.note,
  });

  final int quantity;
  final String name;

  /// Seçenek adları, ör. `['Büyük', 'Acılı']`.
  final List<String> options;

  /// Satıra özel not; fişte `>> ... <<` ile vurgulanır.
  final String? note;
}

/// Müşteri fişindeki tek satır. Fiyat **vardır** (kuruş).
class CustomerReceiptLine {
  const CustomerReceiptLine({
    required this.quantity,
    required this.name,
    required this.lineTotal,
    this.options = const <String>[],
  });

  final int quantity;
  final String name;

  /// Satır toplamı, kuruş.
  final int lineTotal;

  final List<String> options;
}

/// Teslimat adresi. Yalnızca `delivery` siparişte doludur.
class ReceiptAddress {
  const ReceiptAddress({
    required this.line1,
    required this.district,
    required this.city,
    this.note,
    this.latitude,
    this.longitude,
  });

  final String line1;
  final String district;
  final String city;
  final String? note;

  /// Müşterinin haritadan seçtiği nokta. İkisi birden doluysa fişe QR
  /// basılır ve kurye okutunca doğrudan oraya gider.
  final double? latitude;
  final double? longitude;

  /// QR basılabilir mi?
  bool get hasPin => latitude != null && longitude != null;

  /// QR'a gömülecek adres.
  ///
  /// ## Neden `https://…maps`, `geo:` DEĞİL
  ///
  /// `geo:` şeması Android'de çalışıyor ama iOS kamerası çoğu durumda hiçbir
  /// şey açmıyor ve kurye QR'ı okutup boş ekranla kalıyor. `https` bağlantısı
  /// her telefonun kamerasında tıklanabilir çıkıyor ve harita uygulaması
  /// kuruluysa doğrudan ona devrediliyor.
  ///
  /// Bu bir bağlantıdır, bir API çağrısı değil: anahtar ya da faturalandırma
  /// gerektirmez. Haritayı OpenStreetMap'ten seçmemizle çelişmiyor.
  ///
  /// Yedi ondalık: sütun `DECIMAL(10,7)` ve ~1 cm çözünürlük veriyor. Daha
  /// azına yuvarlamak iğneyi metrelerce kaydırırdı.
  String get mapUrl =>
      'https://www.google.com/maps?q='
      '${latitude!.toStringAsFixed(7)},${longitude!.toStringAsFixed(7)}';
}

/// Mutfak fişi verisi — fiyat ve adres içermez, müşteri telefonu içerir.
class KitchenReceiptData {
  const KitchenReceiptData({
    required this.orderNumber,
    required this.deliveryType,
    required this.lines,
    required this.printedAt,
    this.requestedAt,
    this.customerPhone,
    this.customerNote,
  });

  final String orderNumber;
  final DeliveryType deliveryType;
  final List<KitchenReceiptLine> lines;

  /// Fişin basıldığı an (UTC).
  ///
  /// Sözleşmedeki `KitchenReceipt` şemasında sipariş oluşturma zamanı yoktur;
  /// başlıktaki tarih bu yüzden **basım zamanıdır**. Fiş sipariş düştüğü anda
  /// otomatik basıldığı için (`docs/05` §5.5) ikisi pratikte aynıdır.
  final DateTime printedAt;

  /// İstenen teslim zamanı (UTC). Varsa başlıkta `Teslim:` satırı basılır.
  final DateTime? requestedAt;

  /// Müşterinin telefonu. Varsa başlıkta `Tel:` satırı basılır.
  ///
  /// Fiş, mutfak kapsamının müşteri telefonunu gördüğü tek yerdir; KDS
  /// kartlarında telefon yoktur (`docs/05-mutfakapp.md` §5.3).
  final String? customerPhone;

  /// Sipariş notu. Varsa fişin sonunda `NOT:` bloğu basılır — asla gizlenmez.
  final String? customerNote;
}

/// BBD Store fişi verisi (K-16).
///
/// **BBD Store bir KİTAP e-ticaret sitesidir**, catering değil. Bu fiş
/// bir mutfak fişi değil, bir **paketleme/sevkiyat fişi**: aynı termal
/// yazıcıdan çıkıyor çünkü işletme tek mekânda ve tek yazıcı var.
///
/// BLD'nin kendi fişlerinden AYRI bir tip olmasının sebebi de bu: BBD'nin
/// ürünleri BLD menüsünde yok, fiyatları BLD'nin fiyat listesinde değil,
/// müşterisi BLD müşterisi değil ve **iş akışı bile farklı** — biri
/// pişiriliyor, diğeri raftan alınıp kutulanıyor.
///
/// FİŞİN BAŞLIĞI BÜYÜK VE FARKLI: personel bu kâğıdı BLD siparişleriyle
/// karıştırmamalı — BBD siparişi KDS panosunda yok, yalnız kâğıtta var ve
/// panoda arayan kişi onu bulamaz.
class BbdReceiptData {
  const BbdReceiptData({
    required this.orderNumber,
    required this.lines,
    required this.printedAt,
    this.customerLabel,
    this.customerPhone,
    this.address,
    this.note,
    this.deliveryType,
    this.amount,
    this.createdAt,
    this.cargoCompany,
    this.trackingNumber,
    this.paymentLabel,
  });

  /// BBD'nin kendi sipariş numarası.
  final String orderNumber;

  final List<BbdReceiptLine> lines;
  final DateTime printedAt;

  final String? customerLabel;
  final String? customerPhone;

  /// Serbest metin adres — BLD'nin yapılandırılmış adres modeli DEĞİL.
  ///
  /// BBD'nin adres biçimi bizimkiyle aynı olmak zorunda değil ve
  /// ayrıştırmaya çalışmak, ilk farklı biçimde yanlış satır basardı.
  final String? address;

  final String? note;

  /// `delivery` (kargo) / `pickup` (mağazadan teslim).
  ///
  /// Kitap satışında `delivery` **kargo** demek; kurye değil. Fiş bu
  /// yüzden kargo firması ve takip numarası taşıyor.
  final String? deliveryType;

  /// Kuruş. `null` ise tutar satırı hiç basılmaz.
  final int? amount;

  /// BBD'de siparişin oluştuğu an.
  final DateTime? createdAt;

  /// Kargo firması — paketleyen kişi doğru etiketi/poşeti seçsin diye.
  final String? cargoCompany;

  /// Kargo takip numarası. Varsa fişe basılıyor; paket eşleştirmesi
  /// kâğıt üzerinden yapılabilsin diye.
  final String? trackingNumber;

  /// "Ödendi (kredi kartı)" / "Kapıda ödeme" gibi serbest metin.
  ///
  /// SERBEST METİN, enum DEĞİL: BBD'nin ödeme yöntemleri bizimkilerle
  /// aynı olmak zorunda değil ve bilinmeyen bir değeri "Bilinmeyen"e
  /// düşürmek, paketleyen kişiye yanlış bilgi vermek olurdu.
  final String? paymentLabel;

  /// Kapıda tahsilat var mı? [amount] dolu ve ödeme "kapıda" ise fişte
  /// büyük punto tahsilat satırı basılır.
  bool get isPickup => deliveryType == 'pickup';
}

/// BBD fişindeki tek satır — bir kitap kalemi.
///
/// SATIR FİYATI YOKTUR: BBD'nin fiyatlandırması bizim değil ve yanlış bir
/// kaynaktan alınmış sayıyı kâğıda basmak, paketleyen kişiye güvenilmez
/// bilgi vermek olurdu. Toplam tutar (varsa) tek satır olarak basılıyor.
class BbdReceiptLine {
  const BbdReceiptLine({
    required this.quantity,
    required this.name,
    this.sku,
    this.attributes = const <String>[],
    this.note,
  });

  final int quantity;

  /// Kitap adı. **Uzun olabilir** ve şablon buna göre yazılmıştır:
  /// çift boyda basılmaz, satıra sarılır.
  final String name;

  /// Stok kodu / ISBN — raftan bulmanın en hızlı yolu.
  final String? sku;

  /// Yazar, cilt, baskı gibi ek nitelikler. Ürün adının altına, küçük
  /// puntoyla basılır.
  final List<String> attributes;

  final String? note;
}

/// Üretim planı fişi verisi (K-15).
///
/// NEDEN FİŞ: mutfak akşam kapatırken yarının listesini **kâğıda** basıp
/// tezgâha asıyor. Ekrana bakmak için elini yıkayıp kasaya gitmek gerekir;
/// kâğıt tezgâhın üstünde durur ve elleri hamurlu kişi ona bakabilir.
///
/// SİPARİŞ FİŞİ DEĞİL: müşteri, adres, fiyat yok. Yalnız "ne kadar
/// pişecek" ve "kaçta çıkacak". Sipariş fişleriyle karışmasın diye
/// başlığı çift boy ve tarihi büyük.
class ProductionPlanData {
  const ProductionPlanData({
    required this.date,
    required this.totals,
    required this.printedAt,
    this.deliveries = const <ProductionPlanDelivery>[],
    this.warnings = const <String>[],
  });

  /// Planın günü (yerel gün başı).
  final DateTime date;

  /// Ürün bazında toplam — listenin ana gövdesi.
  final List<ProductionPlanTotal> totals;

  /// Teslimat noktası ve saat kırılımı.
  final List<ProductionPlanDelivery> deliveries;

  /// "Üretim koşmadı", "kapalı gün" gibi uyarılar.
  ///
  /// FİŞE BASILIR: ekranda görünüp kâğıtta görünmezse, kâğıda bakan
  /// kişi eksik bilgiyle çalışır.
  final List<String> warnings;

  final DateTime printedAt;
}

/// Üretim planındaki tek ürün satırı.
class ProductionPlanTotal {
  const ProductionPlanTotal({required this.name, required this.quantity});

  final String name;
  final int quantity;
}

/// Üretim planındaki tek teslimat satırı.
class ProductionPlanDelivery {
  const ProductionPlanDelivery({
    required this.label,
    this.time,
    this.itemCount = 0,
  });

  /// Kurum/müşteri adı.
  final String label;

  /// `HH:mm` — yoksa saat basılmaz.
  final String? time;

  final int itemCount;
}

/// Kurye fişi verisi (K-14).
///
/// NEDEN ÜÇÜNCÜ TİP: kurye üç şeye ihtiyaç duyuyor ve hiçbiri tek bir
/// mevcut fişte birlikte yok — **kime** (ad + telefon), **nereye**
/// (adres + harita QR), **ne kadar tahsil edilecek**. Mutfak fişinde
/// adres yok (mutfak teslimat yapmıyor), müşteri fişi ise müşteride
/// kalıyor.
///
/// REVİZYON BİLGİSİ ZORUNLU: sipariş düzenlendiyse kuryenin elindeki
/// fiş eski olabilir. Başlıktaki `REVİZE #N` ve değişiklik özeti,
/// kuryenin yanlış tutarı tahsil etmesini engelliyor.
class CourierReceiptData {
  const CourierReceiptData({
    required this.orderNumber,
    required this.deliveryType,
    required this.lines,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.printedAt,
    this.customerName,
    this.customerPhone,
    this.address,
    this.requestedAt,
    this.customerNote,
    this.revisionNo = 0,
    this.revisionSummary = const <String>[],
    this.collectAmount = 0,
  });

  final String orderNumber;
  final DeliveryType deliveryType;
  final List<CustomerReceiptLine> lines;

  /// Kuruş — siparişin toplamı.
  final int total;

  final ReceiptPaymentMethod paymentMethod;
  final ReceiptPaymentStatus paymentStatus;
  final DateTime printedAt;

  final String? customerName;
  final String? customerPhone;

  /// `pickup` siparişte `null` — kurye fişi zaten basılmaz.
  final ReceiptAddress? address;

  final DateTime? requestedAt;
  final String? customerNote;

  /// Kaçıncı revizyon; 0 = hiç düzenlenmedi.
  final int revisionNo;

  /// İnsan okuyabilir değişiklik satırları ("Mercimek: 20 → 10").
  final List<String> revisionSummary;

  /// Kapıda tahsil edilecek tutar (kuruş).
  ///
  /// Ödenmiş siparişte 0'dır ve satır basılmaz. Düzenleme sonrası fark
  /// doğduysa burada görünür — kuryenin yanlış tutar tahsil etmesinin
  /// önündeki tek engel bu satır.
  final int collectAmount;

  bool get isRevised => revisionNo > 0;
}

/// Müşteri fişi verisi — fiyatlı, adrese gönderimde adresli.
class CustomerReceiptData {
  const CustomerReceiptData({
    required this.orderNumber,
    required this.deliveryType,
    required this.lines,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.printedAt,
    this.address,
    this.requestedAt,
  });

  final String orderNumber;
  final DeliveryType deliveryType;
  final List<CustomerReceiptLine> lines;

  /// Kuruş.
  final int subtotal;

  /// Kuruş. `pickup` siparişte her zaman `0` ve satır basılmaz.
  final int deliveryFee;

  /// Kuruş.
  final int total;

  final ReceiptPaymentMethod paymentMethod;
  final ReceiptPaymentStatus paymentStatus;

  /// Fişin basıldığı an (UTC). Gerekçe: [KitchenReceiptData.printedAt].
  final DateTime printedAt;

  /// `pickup` siparişte `null` — adres bloğu yerine `GEL-AL` basılır.
  final ReceiptAddress? address;

  final DateTime? requestedAt;
}
