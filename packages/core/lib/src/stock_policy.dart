/// Stok politikası — sepete en fazla kaç tane eklenebilir, rozet ne yazar?
///
/// Stok iki katmanlıdır (`CLAUDE.md` §4): **gün toplamı** ve **ürün bazlı**
/// tavan; hangisi önce dolarsa satışı o kapatır. Satır yoksa o katman
/// sınırsızdır. Bu dosya o kararın Dart tarafındaki tek uygulamasıdır.
///
/// ## Neden burada
///
/// Aynı aritmetik **üç dilde** yaşıyor: bu dosya (Dart), `website/lib/stock-policy.ts`
/// (TypeScript) ve
/// `platform/extensions/veykemtu/bridgeapi/src/Services/StockPolicy.php` (PHP).
/// Üçü DEĞİŞİRSE BİRLİKTE değişir; biri unutulursa saha hatası "sitede 3
/// eklenebiliyor, uygulamada 2" biçiminde çıkar ve müşteri hangisine
/// inanacağını bilemez.
///
/// Kuralın **normatif kaynağı bu dosya değil**,
/// `docs/contract/sales-rules.cases.json` altın veri kümesidir. Üç test onu
/// okur (`packages/core`, `website/e2e`, `platform/tests/Unit`); kural
/// değişirse üçü birden kırılır ve tek bir dilde sessizce sapmak mümkün
/// olmaz. Buradaki kod ile o dosya çelişirse **dosya kazanır**.
///
/// Sözleşme tarafı: `docs/openapi.yaml` içindeki `DailyMenu.remaining_portions`,
/// `DailyMenuPackage.remaining_portions` ve `MenuItem.remaining_portions`
/// (`docs/03-api-sozlesmesi.md` §15.7).
///
/// ## Kararın nihai sahibi sunucudur
///
/// Buradaki hesap istemcinin **kullanıcıya olmayan bir adedi teklif etmemesi**
/// içindir. Rezervasyonu sunucu yapar; iki müşteri son porsiyonu aynı anda
/// isterse birine `422` döner ve istemci haksızdır, sunucu değil.
library;

/// Kalan porsiyonun anlatıldığı band — rozet, renk ve "sepete ekle"nin durumu.
///
/// Band **sepetten bağımsızdır**: ham kalanı anlatır, müşterinin sepetindeki
/// adedi düşmez. "Son 3 porsiyon" rozeti bu yüzden herkes için aynı sayıdır;
/// sepete göre değişseydi iki müşteri aynı menüde farklı sayı görür ve rozet
/// bir stok bilgisi olmaktan çıkardı.
enum StockLevel {
  /// Tavan konmamış — kalan bilinmiyor değil, **sınır yok**.
  unlimited('unlimited'),

  /// Eşiğin üstünde; sayı gösterilmez.
  plenty('plenty'),

  /// Eşik dahil altı — "son N porsiyon" rozeti.
  low('low'),

  /// Bitti; satış kapalı.
  soldOut('soldOut');

  const StockLevel(this.wireName);

  /// Altın veri kümesindeki ve diğer iki dildeki değer.
  ///
  /// Dart adıyla şu an birebir aynı; yine de ayrı durur, çünkü Dart adı
  /// ileride değişirse üç dil arasındaki eşleşme sessizce bozulurdu.
  final String wireName;

  /// Bilinmeyen değerde `null` döner — üç dile yeni bir band eklenirse
  /// istemci çökmez.
  static StockLevel? tryParse(String value) {
    for (final level in StockLevel.values) {
      if (level.wireName == value) return level;
    }
    return null;
  }
}

/// Bu satıra **en fazla kaç tane daha** eklenebilir?
///
/// [dayRemaining] o servis gününün toplam kalanı, [itemRemaining] tek bir
/// kalemin kalanı. İkisi de `null` olabilir ve **`null` SINIRSIZ demektir,
/// asla sıfır değil** — `null`'ı sıfır sayan istemci, tavanı hiç konmamış bir
/// günü tükenmiş gösterir ve satışı kapatır.
///
/// [alreadyInCartForDay] sepette o gün için duran toplam adet,
/// [alreadyInCartForItem] aynı satırda duran adet. İkisi **ayrı ayrı** düşülür:
/// gün tavanından yalnız gün toplamı, kalem tavanından yalnız o satır. İkisini
/// birbirine karıştıran uygulama, sepette başka yemekler varken bu yemeği
/// olduğundan az gösterir.
///
/// [hardMax] satır başı toplam tavandır (`website/lib/cart.ts` içindeki
/// `MAX_QUANTITY`) ve o satırda hâlihazırda duran adet **ondan da** düşülür;
/// düşülmezse 95 adetlik bir satır 194'e çıkabilir.
///
/// Sonuç **asla negatif olmaz**. Sepet bir tavanı aşmış olabilir — yönetici
/// tavanı sepet doldurulduktan sonra indirmiş ya da eski bir çerezden 120
/// adetlik satır gelmiş olabilir; cevap `0`'dır, eksi değil. Eksi bir değer,
/// çağıranın adım kontrolünde `-2` gibi anlamsız bir üst sınıra dönüşürdü.
int maxAddable({
  int? dayRemaining,
  int? itemRemaining,
  required int alreadyInCartForDay,
  required int alreadyInCartForItem,
  required int hardMax,
}) {
  // Satır başı boşluk her zaman bağlar; iki stok tavanı ona min() ile eklenir.
  var gap = hardMax - alreadyInCartForItem;

  if (dayRemaining != null) {
    final dayGap = dayRemaining - alreadyInCartForDay;
    if (dayGap < gap) gap = dayGap;
  }

  if (itemRemaining != null) {
    final itemGap = itemRemaining - alreadyInCartForItem;
    if (itemGap < gap) gap = itemGap;
  }

  return gap < 0 ? 0 : gap;
}

/// Kalan porsiyonun bandı.
///
/// [remaining] `null` ise tavan konmamıştır → [StockLevel.unlimited].
///
/// Eşiğin **kendisi** `low` sayılır (`remaining == lowThreshold` → `low`);
/// `<` yazan uygulama tam eşikte rozeti göstermez ve üç dil ayrışır.
///
/// [lowThreshold] `0` ise `low` bandı hiç oluşmaz: 1 kalan `plenty`, 0 kalan
/// yine `soldOut`'tur — tükenme denetimi eşikten **önce** gelir.
///
/// Sözleşme negatif kalan üretmez (`minimum: 0`), ama fazla satış düzeltmesi
/// gibi bir hata negatif getirirse üç dil de aynı biçimde `soldOut` demelidir.
StockLevel stockLevel({int? remaining, required int lowThreshold}) {
  if (remaining == null) return StockLevel.unlimited;
  if (remaining <= 0) return StockLevel.soldOut;
  if (remaining <= lowThreshold) return StockLevel.low;
  return StockLevel.plenty;
}
