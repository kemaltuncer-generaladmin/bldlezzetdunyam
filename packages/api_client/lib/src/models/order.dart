/// Sipariş DTO'ları — `docs/openapi.yaml` §Sipariş.
library;

import 'package:bld_core/bld_core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'converters.dart';

part 'order.freezed.dart';
part 'order.g.dart';

@freezed
abstract class Address with _$Address {
  const factory Address({
    required String line1,
    required String district,
    required String city,

    /// Mahalle.
    ///
    /// Beş yapılandırılmış alanın ([neighbourhood] … [doorNo]) hepsi isteğe
    /// bağlıdır (B-21): adresi elle tek satır yazan müşteri de sipariş
    /// verebilmeli. [line1] bu yüzden zorunlu kalıyor — fiş, kurye ekranı ve
    /// eski istemci sürümleri yalnız onu okuyor.
    String? neighbourhood,

    /// Cadde / sokak / bulvar.
    String? street,

    /// Bina / dış kapı numarası. **Metin, sayı değil:** `12/A`, `3-5` gibi
    /// değerler sahada yaygın.
    String? buildingNo,

    /// Kat. `Zemin`, `Bodrum` gibi değerler de geçerli olduğu için metin.
    String? floor,

    /// Daire / iç kapı numarası.
    String? doorNo,
    String? note,

    /// Haritadan seçilen teslimat noktası.
    ///
    /// İsteğe bağlı: konum izni vermeyen ya da adresi elle yazan müşteri de
    /// sipariş verebilir. [longitude] ile birlikte anlamlıdır — sunucu yarım
    /// çifti koordinat saymaz ve ikisini de `null` döndürür.
    double? latitude,
    double? longitude,
  }) = _Address;

  const Address._();

  /// Haritada gösterilebilir bir noktası var mı?
  ///
  /// Tek tek `!= null` denetimi yerine bunu kullanın: çiftin bütünlüğü tek
  /// yerde tanımlı kalsın.
  bool get hasPin => latitude != null && longitude != null;

  factory Address.fromJson(Map<String, dynamic> json) =>
      _$AddressFromJson(json);
}

/// Adres defterindeki kayıt — `GET /addresses`.
///
/// [Address] ile karıştırılmamalı. [Address] siparişin taşıdığı **kopyadır**;
/// bu ise müşterinin defterindeki kayıttır. Sipariş verilirken defterdeki
/// satır kopyalanır, bağlanmaz: müşteri adresini düzelttiğinde teslim edilmiş
/// bir siparişin nereye gittiği değişmemeli (`docs/openapi.yaml` §SavedAddress).
@freezed
abstract class SavedAddress with _$SavedAddress {
  const factory SavedAddress({
    required int id,
    required String line1,
    required String district,
    required String city,
    required bool isDefault,

    /// Müşterinin verdiği ad — "Ev", "Ofis", "Şantiye".
    String? label,

    /// Mahalle. Eski kayıtlarda `null`'dır ve öyle kalır: geçmiş adresleri
    /// geriye dönük ayrıştırmak, ayrıştırmanın yanlış olduğu her satırda
    /// kuryeyi yanlış kapıya götürürdü (B-21).
    String? neighbourhood,

    /// Cadde / sokak / bulvar.
    String? street,

    /// Bina / dış kapı numarası — metin (`12/A`).
    String? buildingNo,

    /// Kat (`Zemin` de geçerli bir değer).
    String? floor,

    /// Daire / iç kapı numarası.
    String? doorNo,

    /// Kuryeye not. Fişte görünür.
    String? note,

    /// Haritadan seçilen nokta — [longitude] ile birlikte anlamlıdır.
    double? latitude,
    double? longitude,
  }) = _SavedAddress;

  const SavedAddress._();

  /// Haritada gösterilebilir bir noktası var mı?
  bool get hasPin => latitude != null && longitude != null;

  factory SavedAddress.fromJson(Map<String, dynamic> json) =>
      _$SavedAddressFromJson(json);

  /// Siparişe gidecek kopya.
  ///
  /// Koordinat da kopyalanır: defterdeki iğne siparişe geçmezse kurye yine
  /// serbest metne bakmak zorunda kalır ve harita hiçbir işe yaramaz.
  Address toOrderAddress() => Address(
    line1: line1,
    district: district,
    city: city,
    neighbourhood: neighbourhood,
    street: street,
    buildingNo: buildingNo,
    floor: floor,
    doorNo: doorNo,
    note: note,
    latitude: latitude,
    longitude: longitude,
  );

  /// Tek satırda okunabilir hâli — liste ve seçicide kullanılır.
  String get summary => '$line1, $district / $city';
}

/// `POST /addresses` ve `PATCH /addresses/{id}` gövdesi.
@freezed
abstract class SavedAddressInput with _$SavedAddressInput {
  const factory SavedAddressInput({
    required String line1,
    required String district,
    required String city,
    String? label,
    String? note,
    bool? isDefault,

    /// ## Yapılandırılmış adres alanları (B-21)
    ///
    /// Beşi de aşağıdaki [latitude]/[longitude] ile **aynı güncelleme
    /// kuralına** tabidir (`docs/openapi.yaml` §SavedAddressInput `door_no`):
    ///
    ///   - alan yok   → mevcut değer korunur
    ///   - alan null  → değer **silinir**
    ///
    /// Bu yüzden aynı `@JsonKey(includeIfNull: true)` istisnası burada da
    /// geçerli: onsuz `null` hiç gönderilemez ve müşteri yanlış girdiği kat
    /// numarasını **boşaltamazdı** — düzeltmenin tek yolu adresi silip
    /// yeniden yazmak olurdu.
    ///
    /// KARŞILIĞI, çağıran bilmek zorunda: bu nesne her zaman kaydın
    /// TAMAMIYLA kurulur. Formu yarım doldurup `PATCH` göndermek, boş
    /// bıraktığın alanları sunucuda siler. Koordinat çiftinin aksine bunlar
    /// birbirinden bağımsızdır — katın bilinip daire numarasının bilinmemesi
    /// olağan bir durumdur.
    @JsonKey(includeIfNull: true) String? neighbourhood,
    @JsonKey(includeIfNull: true) String? street,
    @JsonKey(includeIfNull: true) String? buildingNo,
    @JsonKey(includeIfNull: true) String? floor,
    @JsonKey(includeIfNull: true) String? doorNo,

    /// Haritadan seçilen nokta.
    ///
    /// ## `@JsonKey(includeIfNull: true)` NEDEN GEREKLİ
    ///
    /// Paketin varsayılanı `include_if_null: false` (bkz. `build.yaml`), yani
    /// `null` alanlar gövdeden tamamen çıkarılır. Sunucu ise bu iki durumu
    /// AYIRT EDİYOR (`docs/openapi.yaml` §SavedAddressInput):
    ///
    ///   - alan yok   → mevcut iğne korunur
    ///   - alan null  → iğne silinir
    ///
    /// Varsayılan ayarla `null` hiç gönderilemezdi ve **iğne kaldırılamazdı**:
    /// müşteri haritadan noktayı silse bile eski koordinat kayıtta kalır,
    /// kurye bir daha oraya giderdi. Bu iki alan bilinçli olarak istisna.
    ///
    /// Karşılığı: iğnesiz adres kaydederken gövdede `"latitude": null` gider.
    /// Zararsız — sunucuda zaten `nullable`.
    @JsonKey(includeIfNull: true) double? latitude,
    @JsonKey(includeIfNull: true) double? longitude,
  }) = _SavedAddressInput;

  factory SavedAddressInput.fromJson(Map<String, dynamic> json) =>
      _$SavedAddressInputFromJson(json);
}

/// Geocoder'dan gelen tek bir adres adayı — `GET /addresses/suggest` ve
/// `GET /addresses/reverse`.
///
/// **Bu bir kayıt değildir, bir öneridir:** hiçbir yerde saklanmaz ve kimliği
/// yoktur. Müşteri seçtiğinde istemci alanları forma taşır; kaydedilen şey
/// [SavedAddressInput]'tur. Öneriye kimlik verip [SavedAddress]'e bağlamak,
/// sağlayıcı o kimliği değiştirdiği gün defterdeki adresleri kırardı.
///
/// Alan adları [SavedAddress] ile birebir aynıdır — [toInput] arada eşleme
/// tablosu tutmadan kopyalar.
@freezed
abstract class AddressSuggestion with _$AddressSuggestion {
  const factory AddressSuggestion({
    /// Listede gösterilecek tek satırlık metin; ilçe ve ili de içerir.
    ///
    /// **Sunucu kurar, istemci parçaları birleştirmez** — aynı öneri web'de
    /// ve mobilde farklı görünmesin. CSS/`toUpperCase` ile büyütülmez:
    /// Türkçe mahalle adlarının yarısı `İ`/`ı` taşıyor.
    required String label,

    /// Önerinin tek satırlık hâli — doğrudan [SavedAddressInput.line1]'e
    /// yazılabilir. [label]'dan farkı: ilçe ve ili **içermez**.
    required String line1,
    required String district,
    required String city,

    /// **Null olamaz.** Hizmet alanı elemesi koordinat üzerinden yapılıyor;
    /// koordinatı olmayan bir aday listeye zaten giremez. `/addresses/reverse`
    /// yanıtında bu değer isteğin kendi koordinatıdır — sağlayıcının
    /// oturttuğu (snap) nokta değil, yoksa iğne parmağın altından kayardı.
    required double latitude,
    required double longitude,

    /// Öneriyi üreten sürücü ("osm_nominatim").
    ///
    /// **Kapalı bir enum DEĞİL, bilerek** (`ErrorCode` ile aynı karar):
    /// sürücü değişebilir ve enum'a üye eklemek istemcilerdeki kapsayıcı
    /// `switch`'i kırardı. Dallanma için kullanılmaz; sağlayıcı atfını
    /// göstermek ve günlükte hangi sürücünün konuştuğunu bilmek için var.
    required String source,
    String? neighbourhood,
    String? street,
  }) = _AddressSuggestion;

  const AddressSuggestion._();

  factory AddressSuggestion.fromJson(Map<String, dynamic> json) =>
      _$AddressSuggestionFromJson(json);

  /// Öneriyi kaydedilebilir girdiye çevirir.
  ///
  /// [label] TAŞINMAZ: o, listede gösterilen satırdır — kaydın etiketi
  /// ("Ev", "Ofis") müşterinin verdiği addır ve öneriden gelemez. İkisini
  /// karıştırmak, defterde "Feritpaşa Mah., Kültür Sk. No:12, Selçuklu /
  /// Konya" adında bir adres üretirdi.
  SavedAddressInput toInput({String? addressLabel, String? note}) =>
      SavedAddressInput(
        line1: line1,
        district: district,
        city: city,
        label: addressLabel,
        note: note,
        neighbourhood: neighbourhood,
        street: street,
        latitude: latitude,
        longitude: longitude,
      );
}

@freezed
abstract class OrderCreateItem with _$OrderCreateItem {
  const factory OrderCreateItem({
    required int menuId,
    required int quantity,
    @Default(<int>[]) List<int> optionValueIds,
    String? note,
  }) = _OrderCreateItem;

  factory OrderCreateItem.fromJson(Map<String, dynamic> json) =>
      _$OrderCreateItemFromJson(json);
}

/// `POST /orders` gövdesi.
///
/// Tutar alanı **yoktur** — hesap sunucuda yapılır (`docs/10` S6 adım 5).
@freezed
abstract class OrderCreateRequest with _$OrderCreateRequest {
  const factory OrderCreateRequest({
    required int locationId,
    required List<OrderCreateItem> items,
    @DeliveryTypeConverter() required DeliveryType deliveryType,
    @PaymentMethodConverter() required PaymentMethod paymentMethod,

    /// `delivery` ise zorunlu, `pickup` ise sunucu yok sayar.
    Address? address,

    /// Siparişin **hangi gün için** olduğu — `YYYY-AA-GG`, Europe/Istanbul
    /// (B-19). Verilmezse sunucu [requestedAt]'in işletme saatindeki
    /// tarihini, o da yoksa bugünü kullanır.
    ///
    /// [requestedAt] ile birlikte gönderilirse **ikisinin günü aynı olmak
    /// zorundadır**, yoksa `422 VALIDATION_FAILED`. Aksi hâlde "cuma
    /// menüsünü perşembe 12:00'ye" gibi, mutfağın karşılayamayacağı bir
    /// sipariş doğardı.
    ///
    /// `DateTime` değil `String`: bu bir an değil, takvimdeki bir gün —
    /// gerekçe `daily_menu.dart` kitaplık açıklamasında.
    String? serviceDate,

    /// İstenen teslim zamanı (UTC). `order_cutoff`'a takılırsa `LOCATION_CLOSED`.
    DateTime? requestedAt,
    String? customerNote,
  }) = _OrderCreateRequest;

  factory OrderCreateRequest.fromJson(Map<String, dynamic> json) =>
      _$OrderCreateRequestFromJson(json);
}

@freezed
abstract class Payment with _$Payment {
  const factory Payment({
    @PaymentMethodConverter() required PaymentMethod method,
    @PaymentStatusConverter() required PaymentStatus status,

    /// Yalnızca `online` yönteminde dolu; istemci kullanıcıyı buraya yönlendirir.
    String? redirectUrl,
  }) = _Payment;

  const Payment._();

  factory Payment.fromJson(Map<String, dynamic> json) =>
      _$PaymentFromJson(json);

  /// Sanal POS'a yönlendirme gerekiyor mu?
  bool get requiresRedirect =>
      method == PaymentMethod.online &&
      status == PaymentStatus.pending &&
      redirectUrl != null;
}

/// `POST /orders` yanıtı (201).
@freezed
abstract class OrderCreated with _$OrderCreated {
  const factory OrderCreated({
    required int id,
    required String orderNumber,
    @OrderStatusConverter() required OrderStatus status,

    /// Kuruş.
    required int total,
    required String currency,
    required Payment payment,
    required DateTime createdAt,
  }) = _OrderCreated;

  factory OrderCreated.fromJson(Map<String, dynamic> json) =>
      _$OrderCreatedFromJson(json);
}

/// `GET /orders` listesindeki özet.
@freezed
abstract class OrderSummary with _$OrderSummary {
  const factory OrderSummary({
    required int id,
    required String orderNumber,
    @OrderStatusConverter() required OrderStatus status,
    required int total,
    required String currency,
    required int itemCount,
    required DateTime createdAt,

    /// Siparişin **hangi gün için** olduğu (`YYYY-AA-GG`, Europe/Istanbul).
    ///
    /// Listede "20 Ağustos menüsü" yazabilmek için gerekiyor: [createdAt]
    /// siparişin VERİLDİĞİ andır ve ileri tarihli siparişte o gün ile servis
    /// günü ayrıdır.
    ///
    /// **İsteğe bağlı ve öyle kalmalı:** alan sözleşmeye sonradan eklendi;
    /// eski sunucu ve cihazdaki eski önbellek kaydı onu içermez.
    String? serviceDate,

    /// Abonelikten üretildiyse abonelik kimliği; elle siparişte `null`.
    /// Sipariş kartındaki "Abonelik" rozeti bunu okur.
    int? subscriptionId,
  }) = _OrderSummary;

  factory OrderSummary.fromJson(Map<String, dynamic> json) =>
      _$OrderSummaryFromJson(json);
}

@freezed
abstract class OrderItem with _$OrderItem {
  const factory OrderItem({
    required int menuId,
    required String name,
    required int quantity,

    /// Seçenek farkları **dahil** birim fiyat (kuruş).
    required int unitPrice,
    required int lineTotal,
    @Default(<String>[]) List<String> options,
    String? note,

    /// Satırın rolü: `item` | `package` | `component` (B-19).
    ///
    /// Menü paketi FİYATLI bir ÜST satır + SIFIR FİYATLI bileşen satırları
    /// olarak geliyor; parayı `package` satırı taşır. Okunabilir hâli için
    /// [OrderItemRole] eklentisine bakın.
    ///
    /// **Düz `String`, enum değil** (`converters.dart` §katılık politikası):
    /// bilinmeyen bir rol çökertmemeli, ÇÜNKÜ o satır yine de siparişte
    /// duran gerçek bir yemektir. Katı bir enum `OrderStatus` gibi hata
    /// atardı ve sunucu dördüncü bir rol eklediği gün sipariş detayı hiç
    /// açılmazdı. Gevşek bir enum ise `unknown` üyesi + çevirici + eşleme
    /// tablosu getirirdi; üç yardımcının ([OrderItemRole]) okuduğu tek bir
    /// alan için bunların hiçbiri kazanç değil — [OrderItemRole.isPlainItem]
    /// tanımadığı rolü zaten sıradan satır sayıyor.
    ///
    /// Varsayılan `item` ve alan opsiyonel: sözleşmedeki `default: item`
    /// bunu söylüyor ve rolü göndermeyen bir sunucu sürümünde ekran bugünkü
    /// gibi düz liste çizer.
    @Default('item') String role,

    /// `role: component` satırlarında, ait olduğu paket satırının [OrderDetail.items]
    /// dizisindeki **sırası** (kimliği değil). Diğer satırlarda `null`.
    ///
    /// İstemci paketi ve içindekileri iç içe gösterebilsin diye.
    int? includedIn,

    /// Satır o günün menüsünden geldiyse menünün kimliği.
    int? dailyMenuId,
  }) = _OrderItem;

  factory OrderItem.fromJson(Map<String, dynamic> json) =>
      _$OrderItemFromJson(json);
}

/// [OrderItem.role] için okunabilir yardımcılar.
///
/// **Mutfak tarafında eşi YOK ve olmayacak.** `KitchenOrderItem` bir `role`
/// alanı taşımıyor: paketin üst satırı KDS'ye hiç gönderilmiyor
/// (`OrderPresenter::kitchenItems`), mutfak yalnızca pişecek yemekleri
/// görüyor. Rolü oraya da taşıyıp panoya ve fişe "bu bir başlık" mantığı
/// yazmak bir seçenekti; satırı hiç göndermemek daha az kod ve daha az
/// kavram oldu. Bu yüzden aşağıdaki üç yardımcı yalnızca müşteri
/// arayüzlerinin işine yarar.
extension OrderItemRole on OrderItem {
  /// Menü paketinin başlık satırı mı? Parayı bu satır taşır.
  bool get isPackageHeader => role == 'package';

  /// Bir menü paketinin içindeki yemek mi?
  ///
  /// Bu satırların [OrderItem.unitPrice] ve [OrderItem.lineTotal] değeri
  /// **sıfırdır**; parası paket satırındadır. Toplamı satırlardan hesaplamak
  /// zaten yasaktı (`subtotal`/`total` sunucudan gelir), ama bu satırlar
  /// yanlışlıkla fiyat gösterilirse "0,00 ₺" yazan bir liste üretir.
  bool get isPackageComponent => role == 'component';

  /// Sıradan ürün satırı mı? Bilinmeyen bir rol de buraya düşer: rolü
  /// tanımadığımız bir satırı gizlemek, siparişten bir yemeği yok etmek olur.
  bool get isPlainItem => !isPackageHeader && !isPackageComponent;
}

@freezed
abstract class StatusHistoryEntry with _$StatusHistoryEntry {
  const factory StatusHistoryEntry({
    @OrderStatusConverter() required OrderStatus status,
    required DateTime at,
  }) = _StatusHistoryEntry;

  factory StatusHistoryEntry.fromJson(Map<String, dynamic> json) =>
      _$StatusHistoryEntryFromJson(json);
}

/// `GET /orders/{id}` yanıtı.
@freezed
abstract class OrderDetail with _$OrderDetail {
  const factory OrderDetail({
    required int id,
    required String orderNumber,
    @OrderStatusConverter() required OrderStatus status,
    required List<OrderItem> items,
    required int subtotal,

    /// `pickup` siparişte her zaman `0`.
    required int deliveryFee,
    required int total,
    required String currency,
    @DeliveryTypeConverter() required DeliveryType deliveryType,
    required Payment payment,
    required List<StatusHistoryEntry> statusHistory,
    required DateTime createdAt,

    /// `pickup` siparişte `null`.
    Address? address,
    DateTime? requestedAt,

    /// Siparişin hangi gün için olduğu (`YYYY-AA-GG`, Europe/Istanbul).
    /// Mutfak panosu ve üretim listesi bu güne göre çalışır.
    ///
    /// [OrderSummary.serviceDate] ile aynı gerekçeyle isteğe bağlı.
    String? serviceDate,
    String? customerNote,

    /// Abonelikten üretildiyse abonelik kimliği; elle siparişte `null`.
    int? subscriptionId,
  }) = _OrderDetail;

  const OrderDetail._();

  factory OrderDetail.fromJson(Map<String, dynamic> json) =>
      _$OrderDetailFromJson(json);

  /// Listede kendi satırı olan kalemler — paketlerin İÇİ hariç.
  ///
  /// Bileşen satırları buradan düşer; onları [componentsOf] paketin altında
  /// verir. Düz çizilseydi müşteri "Günün Menüsü 250,00 ₺" satırının hemen
  /// altında "Mercimek Çorbası 0,00 ₺" görürdü ve bedavaya çorba verdiğimizi
  /// sanırdı.
  List<OrderItem> get topLevelItems =>
      items.where((item) => item.includedIn == null).toList(growable: false);

  /// [items] dizisinde [packageIndex] sırasındaki paket satırının içindekiler.
  ///
  /// Sıra kimlik değildir: `included_in` sözleşmede **dizideki konumdur**
  /// (`docs/openapi.yaml` `OrderItem.included_in`), bu yüzden çağıran
  /// [items] üzerindeki gerçek indeksi vermelidir — [topLevelItems]
  /// üzerindeki indeksi değil.
  List<OrderItem> componentsOf(int packageIndex) => items
      .where((item) => item.includedIn == packageIndex)
      .toList(growable: false);

  /// Müşteri bu siparişi iptal edebilir mi? (`docs/03` §4)
  bool get canBeCancelledByCustomer =>
      OrderStatusMachine.customerCanCancel(status);

  /// Takip ekranındaki adım çubuğu — gel-al siparişte `yolda` gösterilmez.
  List<OrderStatus> get trackingSteps => [
    OrderStatus.yeni,
    OrderStatus.onaylandi,
    OrderStatus.hazirlaniyor,
    OrderStatus.hazir,
    if (deliveryType == DeliveryType.delivery) OrderStatus.yolda,
    OrderStatus.teslimEdildi,
  ];
}

@freezed
abstract class PaginationMeta with _$PaginationMeta {
  const factory PaginationMeta({
    required int page,
    required int perPage,
    required int total,
    required int lastPage,
  }) = _PaginationMeta;

  const PaginationMeta._();

  factory PaginationMeta.fromJson(Map<String, dynamic> json) =>
      _$PaginationMetaFromJson(json);

  bool get hasNextPage => page < lastPage;
}

/// `GET /orders` yanıtının tamamı.
@freezed
abstract class OrderPage with _$OrderPage {
  const factory OrderPage({
    required List<OrderSummary> data,
    required PaginationMeta meta,
  }) = _OrderPage;

  factory OrderPage.fromJson(Map<String, dynamic> json) =>
      _$OrderPageFromJson(json);
}
