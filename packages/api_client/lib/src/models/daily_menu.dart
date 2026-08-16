/// Günün menüsü DTO'ları — `docs/openapi.yaml` `DailyMenu`,
/// `DailyMenuPackage`, `MenuCalendarDay` (B-19).
///
/// **Neden tarihler `String`:** buradaki `date` bir AN değil, işletme
/// takvimindeki bir GÜN (Europe/Istanbul). `DateTime`'a çevirseydik cihazın
/// zaman dilimi hesaba karışırdı: `DateTime.parse('2026-08-20')` yerel gece
/// yarısını üretir, geri serileştirilince tam bir zaman damgası olur ve
/// gün UTC−3'teki bir cihazda 19 Ağustos'a kayardı. Oysa bu değer sunucudan
/// nasıl geldiyse öyle geri gidiyor: takvimden okunan gün, `daily-menu?date=`
/// sorgusuna ve oradan `OrderCreateRequest.service_date`'e aynen taşınıyor.
/// Aradaki her dönüşüm, kaybedecek bir şeyi olan bir dönüşümdür.
/// Biçimleme ve gün aritmetiği için `bld_core`'daki `BusinessDate`.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import 'catalog.dart';

part 'daily_menu.freezed.dart';
part 'daily_menu.g.dart';

/// `DailyMenu.is_orderable` yanlışken sebebin makine okunur hâli.
///
/// **Gevşek enum** (`converters.dart` §katılık politikası): bilinmeyen değer
/// [unknown]'a düşer, çökertmez. `OrderStatus`/`DeliveryType` katıdır çünkü
/// onlar iş kuralı taşır; bu alan yalnızca müşteriye hangi cümleyi
/// kuracağımızı seçtirir. Sunucu yeni bir sebep eklediğinde (ör. "kontenjan
/// doldu") eski uygulamanın gün seçiciyi çizmeyi bırakmasının anlamı yok —
/// gün zaten sipariş edilemez işaretli, yalnızca gerekçe geneldir.
enum DailyMenuUnavailableReason {
  /// Sebep yok — `unavailable_reason: null`. `is_orderable` doğruyken gelir.
  none(null),

  /// İşletme o gün kapalı (`veykemtu_closed_days`). Menü girilmiş olsa bile
  /// kapalı gün kazanır.
  closedDay('closed_day'),

  /// O güne menü girilmemiş ya da menü hâlâ taslak. Müşteri açısından ikisi
  /// aynı şeydir: pişmeyecek yemek satılmaz.
  notPublished('not_published'),

  /// Günlük son sipariş saati geçti.
  cutoffPassed('cutoff_passed'),

  /// Geçmiş bir gün.
  past('past'),

  /// Azami ileri görüş penceresinin ötesi (`Location.max_lookahead_days`).
  tooFar('too_far'),

  /// O gün servis yok — `Location.service_weekdays` listesinde değil.
  ///
  /// [closedDay]'den AYRI tutuldu çünkü müşteriye kurulacak cümle ayrı: biri
  /// "hafta sonu servisimiz yok", öbürü "o gün kapalıyız". Aynı değere
  /// sıkıştırılsalardı istemci her hafta sonunu tatil gibi anlatırdı.
  noServiceDay('no_service_day'),

  /// Stok tükendi — gün tavanı doldu ya da bütün kalemler bitti.
  soldOut('sold_out'),

  /// Sözleşmeye sonradan eklenmiş, bu istemcinin bilmediği bir sebep.
  ///
  /// [wireName] `null`: bu alan **yalnızca okunur**, istemci hiçbir uca geri
  /// göndermez. Bilmediğimiz bir kodu saklayıp geri yollamak, saklamamaktan
  /// daha dürüst olmazdı — gösterecek metnimiz zaten yok.
  unknown(null);

  const DailyMenuUnavailableReason(this.wireName);

  /// Sözleşmedeki karşılığı; [none] ve [unknown] için `null`.
  final String? wireName;

  static DailyMenuUnavailableReason parse(String? value) {
    if (value == null || value.isEmpty) return none;
    for (final reason in DailyMenuUnavailableReason.values) {
      if (reason.wireName == value) return reason;
    }
    return unknown;
  }
}

/// Sebep başına varsayılan Türkçe metin.
///
/// `paymentMethodLabelsTr` ile aynı gerekçe: üç ekran aynı durumu üç ayrı
/// cümleyle anlatmasın. Sözleşme (`docs/openapi.yaml` `unavailable_reason`)
/// metni **sunucudan almayı yasaklıyor**; burada olması onu istemci tarafında
/// tutar. Ekran daha iyi bir cümle kurabiliyorsa (ör. kapalı günün adını
/// `MenuCalendarDay.note`'tan ekleyerek) bunu kullanmak zorunda değildir.
const Map<DailyMenuUnavailableReason, String> dailyMenuUnavailableLabelsTr = {
  DailyMenuUnavailableReason.none: '',
  DailyMenuUnavailableReason.closedDay: 'Bu gün kapalıyız.',
  DailyMenuUnavailableReason.notPublished: 'Bu güne henüz menü girilmedi.',
  DailyMenuUnavailableReason.cutoffPassed: 'Bugünün sipariş saati doldu.',
  DailyMenuUnavailableReason.past: 'Geçmiş bir güne sipariş verilemez.',
  DailyMenuUnavailableReason.tooFar: 'Bu tarihe henüz sipariş alınmıyor.',
  DailyMenuUnavailableReason.noServiceDay: 'Bu gün servisimiz yok.',
  DailyMenuUnavailableReason.soldOut: 'Bu günün porsiyonları tükendi.',
  DailyMenuUnavailableReason.unknown: 'Bu güne şu anda sipariş verilemiyor.',
};

class DailyMenuUnavailableReasonConverter
    implements JsonConverter<DailyMenuUnavailableReason, String?> {
  const DailyMenuUnavailableReasonConverter();

  @override
  DailyMenuUnavailableReason fromJson(String? json) =>
      DailyMenuUnavailableReason.parse(json);

  @override
  String? toJson(DailyMenuUnavailableReason object) => object.wireName;
}

/// Paketin içindeki tek bir yemek — `DailyMenuPackage.components[]`.
///
/// Fiyatı **yoktur**, bilerek: paketin parası üst satırda durur. Bileşene
/// fiyat vermek, müşterinin toplamı kendi toplamasına ve paket fiyatıyla
/// çelişen bir sayı görmesine yol açardı.
@freezed
abstract class DailyMenuPackageComponent with _$DailyMenuPackageComponent {
  const factory DailyMenuPackageComponent({
    /// Ürünün gerçek kimliği. Sipariş satırına **yazılmaz** — paket tek bir
    /// `menu_id` ile sipariş edilir; bu kimlik yalnızca ürün detayını
    /// eşleştirmek için.
    required int menuId,
    required String name,

    /// Bir pakette bu kalemden kaç porsiyon var.
    required int quantity,
    String? imageUrl,
    @Default(<String>[]) List<String> allergens,
  }) = _DailyMenuPackageComponent;

  factory DailyMenuPackageComponent.fromJson(Map<String, dynamic> json) =>
      _$DailyMenuPackageComponentFromJson(json);
}

/// Menünün bütün olarak satılan hâli — `DailyMenu.package`.
@freezed
abstract class DailyMenuPackage with _$DailyMenuPackage {
  const factory DailyMenuPackage({
    /// **Sipariş verirken `OrderCreateItem.menuId` alanına yazılacak değer.**
    ///
    /// Paket, sözleşme açısından bir ürün gibi sipariş edilir; sunucu bu
    /// kimliği tanır, fiyatı o günün paket fiyatından alır ve içindekileri
    /// satırın altına kendisi açar. İstemci "paket mi ürün mü" ayrımını
    /// istek biçiminde taşımaz.
    required int menuId,
    required String name,

    /// Paketin o günkü fiyatı (kuruş). Kalemlerin toplamından ucuz olabilir.
    required int price,

    /// Paket bugün satılabilir mi?
    ///
    /// İçindeki **zorunlu** bir kalem tükendiyse bu da yanlıştır: ana yemeği
    /// olmayan bir menüyü satmak, bir telefon özrünü kırka çevirir.
    required bool isAvailable,
    String? soldOutReason,

    /// Paketten kalan porsiyon. **`null` SINIRSIZ, `0` tükendi** — ikisi asla
    /// karıştırılmaz; `null`'ı `0` sayan istemci, tavanı hiç konmamış bir
    /// paketi satıştan düşürür.
    ///
    /// Günün toplam tavanı (`DailyMenu.remainingPortions`) ile birlikte
    /// değerlendirilir: sepete eklenebilecek azami adet ikisinin `min()`'idir.
    /// Aritmetiğin normatif vaka tablosu
    /// `docs/contract/sales-rules.cases.json`; uygulaması `bld_core`'da,
    /// **burada değil** — aynı çarpımı iki pakette tutmak iki farklı sonucun
    /// en kısa yoludur.
    ///
    /// Aboneliklerin rezervasyonu bu sayıdan **önceden düşülmüştür**.
    int? remainingPortions,
    @Default(<DailyMenuPackageComponent>[])
    List<DailyMenuPackageComponent> components,
  }) = _DailyMenuPackage;

  const DailyMenuPackage._();

  factory DailyMenuPackage.fromJson(Map<String, dynamic> json) =>
      _$DailyMenuPackageFromJson(json);

  /// Pakette toplam kaç porsiyon var? ("4 kap" gibi bir rozet için.)
  int get portionCount =>
      components.fold(0, (sum, component) => sum + component.quantity);
}

/// Bir günün menüsü — `GET /locations/{id}/daily-menu?date=`.
///
/// Menü olmayan gün de **200** döner ([id] `null`, [items] boş): boş gün bir
/// hata değil, bir cevaptır.
@freezed
abstract class DailyMenu with _$DailyMenu {
  const factory DailyMenu({
    /// `YYYY-AA-GG`, işletme takviminde (Europe/Istanbul).
    required String date,
    required String currency,

    /// İşletmenin kapalı olduğu gün. Menü girilmiş olsa bile sipariş alınmaz.
    required bool closed,

    /// Bu güne **şu anda** sipariş verilebilir mi?
    ///
    /// Bağlayıcı olan yine `POST /orders` anındaki denetimdir; bu alan
    /// arayüzü doğru çizmek içindir, karar vermek için değil.
    required bool isOrderable,

    /// O günün yayınlanmış menüsünün kimliği; **`null` ise o gün menü yok**.
    int? id,

    /// Günün adı, örn. "Ev Yemeği Menüsü".
    String? title,
    String? description,

    /// Yöneticinin o güne elle yüklediği **kapak** görseli.
    ///
    /// Varsa [imageUrls] ızgarasına tercih edilir — kararı tek yerde tutmak
    /// için [cardImageUrls] getter'ına bakın.
    String? imageUrl,

    /// Menünün **ilk dört kaleminin** görselleri, yöneticinin verdiği sırada.
    ///
    /// İstemci bunları 2×2 bir ızgarada dizer (`AGENTS.md` iş kuralı 6);
    /// dörtten az görsel varsa ızgara o kadar hücreyle çizilir. Görseli
    /// olmayan kalem diziye **girmez** — boş yer tutulmaz, çünkü `null`
    /// hücreyi üç uygulama üç farklı yer tutucuyla doldururdu.
    ///
    /// Dizilim istemcide yapılır, sunucuda değil: ızgara bir görüntüleme
    /// kararıdır ve mobilde 2×2, dar kartta 1×2 olabilir.
    @Default(<String>[]) List<String> imageUrls,

    /// Menünün paket hâli; o gün paket satılmıyorsa `null` — kalemler yine
    /// tek tek satılabilir.
    DailyMenuPackage? package,

    /// Kalemlerin tek tek alınması hâlindeki toplam (kuruş).
    ///
    /// Sunucu hesaplar; para hesabı tek yerde kalsın diye alan olarak
    /// veriliyor.
    int? itemsTotal,

    /// Bu güne sipariş kabulünün **bittiği mutlak an** (UTC); gün kapandıysa
    /// ya da kesim tanımlı değilse `null`.
    ///
    /// **Neden saat değil de an:** kesim kuralını üç dilde yeniden hesaplamak
    /// (TS `Intl`, Dart'ta sabit UTC+3, PHP'de `Europe/Istanbul`) sapmanın
    /// kaynağıdır; üstüne cihaz saatleri yalan söyler. Sunucu tek bir an
    /// gönderir, istemci onunla **yalnız geri sayım gösterir**.
    ///
    /// Geri sayım sıfırlandığında ekran KİLİTLENMEZ: menü yeniden çekilir ve
    /// [isOrderable]'a bakılır. Karar kapısı her zaman odur — cihaz saati beş
    /// dakika ileriyken açık bir günü kapalı göstermek satış kaybıdır, tersi
    /// ise sunucunun zaten reddedeceği bir istektir.
    DateTime? cutoffAt,

    /// O gün için **toplam** kalan porsiyon (gün tavanı).
    ///
    /// **`null` SINIRSIZ, `0` tükendi.** İkisi asla karıştırılmaz. Kalem bazlı
    /// tavan ayrıca `items[].remainingPortions` ve
    /// `package.remainingPortions` alanlarındadır; hangisi önce dolarsa
    /// satışı o kapatır. Bu alan da [cutoffAt] gibi yalnız **bant ve geri
    /// sayım** içindir — "bu gün kapanmıştır" sonucunu istemci kendi
    /// çıkarmaz, [isOrderable]'a bakar.
    int? remainingPortions,

    /// [isOrderable] yanlışken sebebin makine okunur hâli.
    @DailyMenuUnavailableReasonConverter()
    @Default(DailyMenuUnavailableReason.none)
    DailyMenuUnavailableReason unavailableReason,

    /// Menüyü oluşturan kalemler, yöneticinin verdiği sırada.
    ///
    /// `price` **o gün için geçerli** birim fiyattır (ürünün kendi fiyatı ya
    /// da o güne girilmiş istisna); istemci ayrıca fiyat hesaplamaz.
    @Default(<MenuItem>[]) List<MenuItem> items,
  }) = _DailyMenu;

  const DailyMenu._();

  factory DailyMenu.fromJson(Map<String, dynamic> json) =>
      _$DailyMenuFromJson(json);

  /// O gün yayınlanmış bir menü var mı?
  ///
  /// [items] boşluğuna değil [id]'ye bakar: kalemleri silinmiş ama yayında
  /// duran bir menü de "menü var" demektir ve o günü takvimde göstermek
  /// yöneticinin hatasını görünür kılar.
  bool get exists => id != null;

  /// Menü paket olarak da satılıyor mu?
  bool get sellsPackage => package != null;

  /// Paketi seçmenin kazandırdığı fark (kuruş); avantaj yoksa `null`.
  ///
  /// **Yalnızca POZİTİF fark döner.** Yönetici paket fiyatını kalemlerin
  /// toplamından yüksek girebilir (sözleşme yasaklamıyor); o durumda
  /// "−12,00 ₺ avantaj" yazmak müşteriye paketi almamasını söylemek olurdu.
  /// Karar tek yerde kalsın diye çıkarma burada yapılıyor.
  int? get packageSavingKurus {
    final total = itemsTotal;
    final packagePrice = package?.price;
    if (total == null || packagePrice == null) return null;
    final saving = total - packagePrice;
    return saving > 0 ? saving : null;
  }

  /// Bugün sepete eklenebilecek kalemler.
  ///
  /// Tükenmiş kalem listeden **düşmez** (`MenuItem.isAvailable` soluk
  /// gösterilir); bu getter sepet/adet mantığı için, çizim için değil.
  List<MenuItem> get availableItems =>
      items.where((item) => item.isAvailable).toList(growable: false);

  /// Satılacak hiçbir şeyi olmayan bir gün mü?
  bool get isEmpty => !exists || (items.isEmpty && package == null);

  /// Gün kartında çizilecek görseller, sözleşmedeki öncelikle.
  ///
  /// NEDEN BURADA: sözleşme "[imageUrl] varsa ızgaraya tercih edilir" diyor
  /// (`docs/openapi.yaml` `DailyMenu.image_urls`). Bu tek cümleyi üç istemci
  /// ayrı ayrı uygularsa biri kapağı, öbürü ızgarayı öne alır ve aynı gün iki
  /// uygulamada iki farklı kartla çıkar. Seçim burada, dizilim ekranda.
  ///
  /// Tek elemanlı liste "kapak var" demektir; birden fazlası ızgaradır. Boş
  /// liste görseli hiç olmayan gündür — kart yer tutucuyla çizilir.
  List<String> get cardImageUrls {
    final cover = imageUrl;
    if (cover != null && cover.isNotEmpty) return <String>[cover];
    // Sunucu zaten dörtle sınırlıyor; kısıt burada da var ki bozuk bir yanıt
    // ızgarayı taşırmasın.
    return imageUrls.take(4).toList(growable: false);
  }

  /// Kimliğe göre günün kalemi; o gün o kalem yoksa `null`.
  ///
  /// Derin bağlantı ve "tekrar sipariş ver" dünkü bir kimliği taşıyabiliyor;
  /// çağıranın önce bugünün menüsünde olup olmadığını sorabilmesi gerekiyor.
  MenuItem? itemFor(int menuId) {
    for (final item in items) {
      if (item.id == menuId) return item;
    }
    return null;
  }

  /// Paketin **ürün** karşılığı; o gün paket satılmıyorsa `null`.
  ///
  /// NEDEN VAR: paket sözleşme açısından zaten bir üründür — tek bir
  /// [DailyMenuPackage.menuId] ile sipariş edilir, sunucu içindekileri
  /// satırın altına kendi açar. İstemci tarafında ise sepet, adet sayacı,
  /// "tekrar sipariş ver" ve sipariş satırı hep [MenuItem] üzerinden
  /// çalışıyor. Paket için ikinci bir sepet kalemi türü tanımlamak, bu dört
  /// yerin her birine "paket mi ürün mü" dalı eklemek demekti; dönüşüm tek
  /// yerde durunca hiçbiri paketi bilmek zorunda kalmıyor.
  ///
  /// [MenuItem.options] bilerek BOŞ: paketin seçeneği yok, kalemleri o günün
  /// menüsünde sabit. [MenuItem.imageUrl] menünün kendi görselidir — paketin
  /// ayrı bir fotoğrafı yok, günün fotoğrafı paketin fotoğrafıdır.
  ///
  /// [DailyMenuPackage.remainingPortions] de taşınır: sepetin adet sayacı
  /// kalem tavanını [MenuItem.remainingPortions] üzerinden okuyor ve tavan
  /// burada düşerse paket sınırsızmış gibi eklenirdi.
  MenuItem? get packageAsMenuItem {
    final package = this.package;
    if (package == null) return null;

    return MenuItem(
      id: package.menuId,
      name: package.name,
      price: package.price,
      currency: currency,
      isAvailable: package.isAvailable,
      soldOutReason: package.soldOutReason,
      remainingPortions: package.remainingPortions,
      description: description,
      imageUrl: imageUrl,
    );
  }
}

/// Takvimdeki tek bir gün — `GET /locations/{id}/menu-calendar?from=&to=`.
///
/// Yalnız **menüsü olan ya da kapalı olan** günler döner; hiçbir şeyi olmayan
/// gün listede yer almaz. Gün seçici, listede olmayan günü "menü yok" diye
/// çizer.
@freezed
abstract class MenuCalendarDay with _$MenuCalendarDay {
  const factory MenuCalendarDay({
    /// `YYYY-AA-GG`.
    required String date,
    required bool hasMenu,
    required bool closed,
    required bool isOrderable,

    /// O günün sipariş kabulünün bittiği **mutlak an** (UTC); kesim yoksa ya
    /// da gün kapandıysa `null`. `DailyMenu.cutoffAt` ile aynı değer, aynı
    /// gerekçe (bkz. orası).
    ///
    /// Takvimde veriliyor ki gün seçici, her günü ayrı ayrı sorgulamadan
    /// "bugün 08:00'e kadar" bandını çizebilsin.
    DateTime? cutoffAt,

    /// O günün stoku tükendi mi?
    ///
    /// Tükenmiş gün takvimde **görünmeye devam eder** ([isBrowsable] hâlâ
    /// doğrudur): müşteri menüyü okuyabilmeli, yalnız sipariş verememelidir.
    /// Günü listeden düşürseydik "menü girilmemiş" ile "kapış kapış gitti"
    /// aynı boşluğa düşerdi.
    ///
    /// Kalan porsiyonun **sayısı** takvimde YOKTUR — takvim doksan güne kadar
    /// çizilir ve her gün için stok okumak listenin maliyetini büyütürdü.
    /// Sayı gün açıldığında `DailyMenu.remainingPortions` ile gelir.
    @Default(false) bool soldOut,

    /// Bu gün servis günü **dışında** mı? (`Location.serviceWeekdays`
    /// listesinde yok.)
    ///
    /// Adı "hafta sonu" ama anlamı "servis yok". Ayrı bir alan olması,
    /// istemcinin haftanın gününü kendi hesaplayıp yorumlamasını gereksiz
    /// kılar — takvimdeki her hücre kendi durumunu taşır.
    ///
    /// **Satış kanalı kapalı DEĞİLDİR:** cumartesi günü pazartesiye sipariş
    /// verilebilir. Bu alan yalnız o hücrenin kendi servis gününü anlatır.
    @Default(false) bool weekend,
    String? title,

    /// Paket fiyatı (kuruş); o gün paket satılmıyorsa `null`.
    int? packagePrice,

    /// Kapalı günün açıklaması ("Kurban Bayramı") ya da `null`.
    String? note,
  }) = _MenuCalendarDay;

  const MenuCalendarDay._();

  factory MenuCalendarDay.fromJson(Map<String, dynamic> json) =>
      _$MenuCalendarDayFromJson(json);

  /// Gün seçicide dokunulabilir mi?
  ///
  /// [isOrderable] ile aynı şey **değildir**: kapalı ya da kesim saati geçmiş
  /// bir günün menüsü de görüntülenebilir olmalı — müşteri "yarın ne var"
  /// diye bakarken sipariş veremeyeceği güne de dokunabilmeli. Sepete ekleme
  /// kapısı [isOrderable]'dır.
  bool get isBrowsable => hasMenu;
}
