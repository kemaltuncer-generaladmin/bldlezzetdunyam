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
    this.revisionNo = 0,
    this.revisionSummary = const <String>[],
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

  /// Kaçıncı revizyon; `0` = düzenlenmedi (K-20).
  ///
  /// `>0` ise fişin **en üstüne** çift boy `GÜNCEL FİŞ / REVİZE #N / ÖNCEKİ
  /// FİŞİ ATIN` bandı basılır. K-20'ye kadar mutfak fişinde böyle bir bant
  /// hiç yoktu: düzenlenen sipariş için yeni kâğıt çıkıyor ama üstünde onu
  /// öncekinden ayıran hiçbir şey yazmıyordu ve tezgâhta iki kâğıt yan yana
  /// durduğunda hangisinin geçerli olduğu okunamıyordu.
  final int revisionNo;

  /// Neyin değiştiği — `Mercimek Çorbası: 20 -> 10`.
  ///
  /// Boşsa `DEĞİŞİKLİKLER` bloğu hiç basılmaz; bant yine basılır. Başlıksız
  /// boş bir blok, personele bir şeyin kayıp olduğunu düşündürürdü.
  final List<String> revisionSummary;

  bool get isRevised => revisionNo > 0;
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
/// **K-20'DEN BERİ OTOMATİK BASILMIYOR.** Kuryenin üç sorusunun cevabı —
/// kime, nereye, ne kadar tahsil edilecek — [CustomerReceiptData]'ya
/// taşındı ve sipariş başına iki kâğıt çıkıyor.
///
/// Bu tip ve şablonu **elle yeniden bastırma** kaçış kapısı için duruyor:
/// kâğıt sıkışırsa ya da kurye fişi kaybederse personelin onu geri
/// getirecek bir yolu olmalı. Golden dosyaları bilerek dondurulmuş
/// durumda — birleşmenin bu yola sızmadığı bayt düzeyinde doğrulanıyor.
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
///
/// **K-20: BU FİŞ ARTIK KURYENİN DE FİŞİ.** Ayrı bir kurye fişi otomatik
/// basılmıyor; kuryenin üç sorusunun cevabı — kime ([customerName],
/// [customerPhone]), nereye ([address] + harita QR), ne kadar tahsil
/// edilecek ([collectAmount]) — buraya taşındı.
///
/// Öncesinde adrese gönderim başına üç kâğıt, iki kez düzenlenmiş siparişte
/// yedi kâğıt çıkıyordu ve tezgâhta hangisinin güncel olduğu okunamıyordu.
/// Artık tek kâğıt: kurye kapıda okuyor, sonra müşteride kalıyor.
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
    this.trackUrl,
    this.payUrl,
    this.customerName,
    this.customerPhone,
    this.customerNote,
    this.collectAmount = 0,
    this.revisionNo = 0,
    this.revisionSummary = const <String>[],
    this.deliverUrl,
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

  /// Sipariş takip sayfası — fişe QR olarak basılır (K-18).
  ///
  /// Müşteri fişi elden veriliyor ve üstünde sipariş numarası yazıyor; ama
  /// durumu görmek için o numarayı siteye elle yazmak gerekiyordu.
  ///
  /// `null` ise QR basılmaz. Sunucu `FRONTEND_URL` tanımsızken null
  /// gönderiyor: çalışmayan bir kare basmak, okutup boş sayfa gören
  /// müşteri üretmekten iyi değil ve kâğıt harcıyor.
  final String? trackUrl;

  /// Ödeme sayfası — fişe QR olarak basılır (K-19).
  ///
  /// Kapıda ödeme seçen müşteri nakit bulundurmak zorunda kalmasın diye.
  /// YALNIZCA ödenmemiş siparişte dolu; ödenmiş siparişin fişine ödeme
  /// QR'ı basmak ikinci kez ödemeye davet etmek olurdu.
  final String? payUrl;

  /// Müşterinin tam adı — kurye kapıda "kime teslim ediyorum" der.
  ///
  /// Gel-al siparişinde `null`: kurye yok ve müşteri kâğıdı tezgâhtan
  /// alıyor, kendi adını okumaya ihtiyacı yok.
  final String? customerName;

  /// Müşterinin telefonu — kapı açılmadığında kuryenin arayacağı numara.
  ///
  /// Gel-al siparişinde `null`. Adrese gönderimde **çift boy** basılır:
  /// kurye numarayı araçta, kötü ışıkta, tek elle okuyor.
  final String? customerPhone;

  /// Sipariş notu ("Zili çalmayın").
  ///
  /// BU FİŞE TAŞINMASI ŞARTTI (K-20): kapı talimatı kuryeye bugüne kadar
  /// yalnız kurye fişiyle ulaşıyordu. O fişi otomatik basmaktan vazgeçip
  /// notu taşımasaydık, kuryenin elinden bir kapı talimatını silmiş
  /// olurduk.
  final String? customerNote;

  /// Kapıda tahsil edilecek tutar (kuruş).
  ///
  /// Ödenmiş siparişte ve gel-al'da `0` ve satır **hiç basılmaz**: sıfırlık
  /// bir "tahsil edilecek" satırı, kuryenin bir sonraki fişte gerçek tutarı
  /// gözden kaçırmasına yol açıyordu.
  final int collectAmount;

  /// Kaçıncı revizyon; `0` = düzenlenmedi.
  final int revisionNo;

  /// Neyin değiştiği. Boşsa `DEĞİŞİKLİKLER` bloğu basılmaz.
  final List<String> revisionSummary;

  /// "Teslim ettim" bağlantısı — fişe QR olarak basılır (K-20).
  ///
  /// Kurye okutuyor, tek düğmeli bir onay sayfası açılıyor, onaylayınca
  /// sipariş `teslim_edildi` oluyor ve bağlantı ölüyor.
  ///
  /// `null` olduğu hâller: gel-al siparişi ya da sunucuda imza sırrı
  /// yapılandırılmamış. İkisinde de kare hiç basılmaz.
  final String? deliverUrl;

  /// Kurye bloğu (ad, telefon, adres, tahsilat, teslim QR) basılacak mı?
  ///
  /// Tek kapı: gel-al fişinde bu bilgilerin hiçbiri basılmıyor. Ayrı ayrı
  /// `null` kontrolü yapılsaydı, bir alan dolu gelirse gel-al fişinde
  /// yalnız o satır belirirdi.
  bool get showsCourierBlock => deliveryType == DeliveryType.delivery;

  bool get isRevised => revisionNo > 0;

  /// Takip QR'ı basılabilir mi?
  bool get hasTrackQr => _hasUrl(trackUrl);

  /// Ödeme QR'ı basılabilir mi?
  bool get hasPayQr => _hasUrl(payUrl);

  /// Teslim QR'ı basılabilir mi? Gel-al'da asla.
  bool get hasDeliverQr => showsCourierBlock && _hasUrl(deliverUrl);

  /// Boş dize de `null` sayılır: sunucu tarafında bir alan boş string
  /// olarak gelirse QR yerine kare bir gürültü basılırdı.
  static bool _hasUrl(String? value) => value != null && value.trim().isNotEmpty;
}
