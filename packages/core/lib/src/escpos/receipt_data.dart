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

/// Fiş tipi. İkiden fazlası yoktur — "teslim" fişi öğrenci kanalıyla birlikte
/// iptal edilmiştir (`docs/BILINMEYENLER.md` #1).
enum ReceiptKind {
  mutfak('mutfak'),
  musteri('musteri');

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
