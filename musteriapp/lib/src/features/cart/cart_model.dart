/// Sepet modeli ve hesabı.
///
/// **Buradaki tutarlar yalnızca gösterim içindir.** Siparişin gerçek tutarını
/// her zaman sunucu hesaplar; istemcinin gönderdiği tutar alanları yok sayılır
/// (`docs/openapi.yaml` `createOrder`). İkisi çelişirse sunucu haklıdır.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'cart_model.freezed.dart';
part 'cart_model.g.dart';

/// Bir satırda durabilecek azami adet.
///
/// Stok tavanlarından BAĞIMSIZ bir tavandır: tavanı hiç konmamış bir yemekte
/// bile parmak kaymasıyla 400 porsiyon istenmesini engeller. Değer
/// `website/lib/cart.ts` içindeki `MAX_QUANTITY` ile aynı ve altın veri
/// kümesindeki `defaults.hard_max` da budur
/// (`docs/contract/sales-rules.cases.json`) — üçü birlikte değişir.
const int kMaxCartLineQuantity = 99;

/// Sepetteki tek bir kalem: ürün + seçilen seçenekler + adet + not.
@freezed
abstract class CartLine with _$CartLine {
  const factory CartLine({
    required MenuItem item,
    required int quantity,

    /// Seçilen `MenuOptionValue` kimlikleri. Sıra anlamlı değildir; kimlik
    /// karşılaştırması [signature] üzerinden sıralı yapılır.
    @Default(<int>[]) List<int> optionValueIds,
    String? note,

    /// Bu satır GÜNÜN MENÜSÜ PAKETİ ise içindeki yemekler; değilse boş.
    ///
    /// Yalnızca GÖSTERİM içindir: pakete tek bir `menu_id` ile sipariş
    /// veriliyor ve içindekileri sunucu kendisi açıyor
    /// (`OrderCreateItem.menuId`). Buradaki liste sepette "ne alıyorum"
    /// sorusunu cevaplamak için duruyor — paketi satın alırken içindekileri
    /// görmeyen müşteri sepeti ödeme ekranında terk ediyor.
    ///
    /// İstek gövdesine GİRMEZ; [toOrderItem] onu okumaz.
    @Default(<DailyMenuPackageComponent>[])
    List<DailyMenuPackageComponent> packageComponents,
  }) = _CartLine;

  const CartLine._();

  factory CartLine.fromJson(Map<String, dynamic> json) =>
      _$CartLineFromJson(json);

  /// Günün menüsü paketi mi?
  ///
  /// Bileşen listesinden türetiliyor, ayrı bir bayraktan değil: içindekileri
  /// olmayan bir "paket" ile sıradan bir ürünün arayüzde hiçbir farkı yok —
  /// ikisi de tek satır, tek fiyat. İki alanı tutarlı tutmak zorunda kalmak,
  /// kazandırdığı ayrımdan pahalıydı.
  bool get isPackage => packageComponents.isNotEmpty;

  /// Seçenek farkları dahil birim fiyat (kuruş).
  int get unitPrice => item.unitPriceWith(optionValueIds.toSet());

  /// Kalem toplamı (kuruş).
  int get lineTotal => unitPrice * quantity;

  /// Seçilen seçeneklerin görünen adları, menüdeki sırayla.
  List<String> get optionLabels => [
    for (final option in item.options)
      for (final value in option.values)
        if (optionValueIds.contains(value.id)) value.name,
  ];

  /// İki kalemin "aynı" sayılıp birleştirileceğini belirleyen kimlik.
  ///
  /// Aynı ürün farklı seçenek veya farklı notla eklendiğinde ayrı kalem olur —
  /// mutfak fişinde de ayrı satır olarak basılacağı için birleştirmek yanlış
  /// olurdu.
  String get signature {
    final sortedIds = [...optionValueIds]..sort();
    return '${item.id}|${sortedIds.join(',')}|${note?.trim() ?? ''}';
  }

  /// Sipariş isteğindeki karşılığı (`docs/openapi.yaml` `OrderCreateRequest`).
  OrderCreateItem toOrderItem() => OrderCreateItem(
    menuId: item.id,
    quantity: quantity,
    optionValueIds: [...optionValueIds]..sort(),
    note: (note == null || note!.trim().isEmpty) ? null : note!.trim(),
  );
}

/// Sepetin tamamı.
@freezed
abstract class Cart with _$Cart {
  const factory Cart({
    @Default(<CartLine>[]) List<CartLine> lines,

    /// Sepet hangi vitrine ait? Vitrin değişirse sepet sıfırlanır — sipariş tek
    /// vitrine verilir (`OrderCreateRequest.location_id`).
    int? locationId,

    /// Sepetin bağlı olduğu SERVİS GÜNÜ (`YYYY-AA-GG`, Europe/Istanbul).
    ///
    /// Bir sipariş tek bir güne verilir (`OrderCreateRequest.service_date`):
    /// perşembe menüsünden bir yemekle cuma menüsünden bir yemeği aynı fişe
    /// koymak mutfağın karşılayamayacağı bir sipariş üretirdi. Bu yüzden gün
    /// değiştiğinde sepet [locationId] ile aynı kuralla SIFIRLANIR.
    ///
    /// `null` yalnızca boş sepette olur.
    String? serviceDate,
  }) = _Cart;

  const Cart._();

  factory Cart.fromJson(Map<String, dynamic> json) => _$CartFromJson(json);

  static const Cart empty = Cart();

  bool get isEmpty => lines.isEmpty;

  bool get isNotEmpty => lines.isNotEmpty;

  /// Farklı kalem sayısı (adetler değil).
  int get lineCount => lines.length;

  /// Toplam ürün adedi.
  int get itemCount => lines.fold(0, (total, line) => total + line.quantity);

  /// Kalem toplamlarının toplamı (kuruş). Teslimat ücreti **dahil değildir** —
  /// onu sunucu ekler.
  int get subtotal => lines.fold(0, (total, line) => total + line.lineTotal);

  /// Belirli bir kalem kimliğiyle eşleşen satırın konumu; yoksa `-1`.
  int indexOfSignature(String signature) =>
      lines.indexWhere((line) => line.signature == signature);

  /// Aynı ÜRÜNDEN sepette toplam kaç adet var?
  ///
  /// Satır değil ürün sayılıyor: aynı yemek farklı seçenek ya da farklı notla
  /// eklendiğinde ayrı satır olur ama mutfakta aynı tencereden çıkar. Stok
  /// tavanı satıra değil ürüne konuyor; satır başına sayan bir hesap, iki
  /// satıra bölünmüş bir yemeğin tavanı iki kez tüketmesine izin verirdi.
  int quantityOfItem(int menuId) => lines.fold(
    0,
    (total, line) => line.item.id == menuId ? total + line.quantity : total,
  );

  /// [date] gününe ait sepette toplam kaç adet var?
  ///
  /// Sepet başka bir güne bağlıysa `0`: o sepet ilk eklemede zaten
  /// boşalacak, dolayısıyla bu günün tavanından hiçbir şey tüketmiyor.
  int quantityOn(String date) => serviceDate == date ? itemCount : 0;

  /// [date] gününe ait sepette bu üründen kaç adet var? (bkz. [quantityOn])
  int quantityOfItemOn(String date, int menuId) =>
      serviceDate == date ? quantityOfItem(menuId) : 0;
}

/// Sepetin servis günüyle ilgili sorunu.
enum CartDayProblem {
  /// Dolu bir sepette gün YOK. Yalnızca bozuk bir kayıttan ya da bir
  /// hatadan doğabilir; sipariş gönderilemez.
  missing,

  /// Gün GEÇTİ. Telefonu gece açık kalan müşteride olağan: akşam doldurulan
  /// sepet sabah hâlâ dünkü güne bağlıdır.
  past,
}

/// Sepetin günü sipariş vermeye elverişli mi?
///
/// **Neden istemci de bakıyor:** bağlayıcı denetim `POST /orders`'ta ve orada
/// kalıyor. Ama geçmiş güne bağlı bir sepetle ödeme formunu doldurtup en
/// sonda `422` göstermek, müşteriye adresini boşuna yazdırmak demek. Buradaki
/// denetim erken ve kibar; kapı değil.
///
/// Kesim saati BURADA HESAPLANMIYOR: cihaz saati yanlış olabilir ve o bilgi
/// zaten `DailyMenu.is_orderable` ile sunucudan geliyor.
CartDayProblem? cartDayProblem(Cart cart, {required String today}) {
  if (cart.isEmpty) return null;

  final date = cart.serviceDate;
  if (date == null || !BusinessDate.isValid(date)) return CartDayProblem.missing;
  if (BusinessDate.isBefore(date, today)) return CartDayProblem.past;
  return null;
}

/// O günün menüsünde bu kimlikle satılan kalem — PAKET de dahil.
///
/// `DailyMenu.itemFor` yalnız tek tek satılan kalemlere bakıyor; paket ise
/// sepette sıradan bir satır olarak duruyor (`DailyMenu.packageAsMenuItem`).
/// Sepetteki bir satırın güncel stokunu ararken ikisine birden bakmak
/// gerekiyor, yoksa paketin tavanı hiç görülmez ve tükenmiş bir menü sepette
/// sınırsız görünürdü.
MenuItem? dailyMenuSellableFor(DailyMenu menu, int menuId) {
  final item = menu.itemFor(menuId);
  if (item != null) return item;

  final package = menu.packageAsMenuItem;
  return (package != null && package.id == menuId) ? package : null;
}

/// Sepet, o günün stok tavanını AŞIYOR mu?
///
/// **Neden istemci de bakıyor:** bağlayıcı denetim `POST /orders`'ta ve orada
/// kalıyor. Ama yönetici tavanı sepet doldurulduktan sonra indirebiliyor ve
/// abonelikler rezervasyonu önden düşüyor; müşteriye adresini yazdırıp en
/// sonda `422` göstermek yerine erken söylenir.
///
/// Sepetteki satırın kendi kopyası DEĞİL, [menu]'deki güncel kalan okunuyor:
/// satır sepete girdiği andaki sayıyı taşıyor ve o sayı eskimiş olabilir.
/// Kalemi o gün menüde bulunamayan satır için satırın kendi kopyasına
/// düşülüyor — menü değişmiş olabilir, ama elimizdeki tek bilgi o.
///
/// **`null` kalan SINIRSIZ demektir**, tükenmiş değil.
bool cartExceedsStock(Cart cart, DailyMenu menu) {
  if (cart.isEmpty || cart.serviceDate != menu.date) return false;

  final dayRemaining = menu.remainingPortions;
  if (dayRemaining != null && cart.itemCount > dayRemaining) return true;

  for (final line in cart.lines) {
    final remaining =
        dailyMenuSellableFor(menu, line.item.id)?.remainingPortions ??
        line.item.remainingPortions;
    if (remaining != null && cart.quantityOfItem(line.item.id) > remaining) {
      return true;
    }
  }
  return false;
}
