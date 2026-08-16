/**
 * STOK ARİTMETİĞİ — sepete kaç tane eklenebilir, stok bandı hangisi.
 *
 * ## Çapraz referans
 *
 * Bu dosya `packages/core/lib/src/stock_policy.dart`'ın BİREBİR AYNASIDIR.
 * Aynı kural üçüncü kez sunucuda da yazılı (`platform/extensions/veykemtu`).
 * Üçünün de normatif kaynağı `docs/contract/sales-rules.cases.json`; üç ayrı
 * test onu okur (burada `e2e/kurallar.spec.ts`, orada paket testi, sunucuda
 * `platform/tests/Unit`). Kural değişirse üçü birden kırılır — tek bir dilde
 * sessizce sapmak mümkün değildir. Sapmanın sahadaki hâli "web sitesinde 3
 * eklenebiliyor, uygulamada 2" olurdu ve müşteri hangisine inanacağını
 * bilemezdi.
 *
 * ## İki ayrı soru, iki ayrı fonksiyon
 *
 * `maxAddable` SEPETE BAĞLIDIR: müşterinin o gün ve o kalem için hâlihazırda
 * seçtiği adedi düşer, yani adet seçicinin üst sınırıdır.
 *
 * `stockLevel` SEPETTEN BAĞIMSIZDIR: ham kalan porsiyonu anlatır. "Son 3
 * porsiyon" rozeti ekranda herkes için aynı sayıyı gösterir. İkisini tek
 * fonksiyona sıkıştırmak, sepetine iki tane atan müşteriye başkasından farklı
 * bir rozet gösterirdi — oysa rozet bir SATIŞ BİLGİSİ, kişisel bir durum
 * değil.
 *
 * ## `null` SINIRSIZ demektir, asla sıfır değil
 *
 * Sözleşmedeki `remaining_portions` alanları isteğe bağlı ve `null`
 * olabiliyor (`docs/openapi.yaml`: `DailyMenu`, `DailyMenuPackage`,
 * `MenuItem`). `null`'ı `0` sayan istemci, tavanı hiç konmamış bir günü
 * tükenmiş gösterir ve satışı kendi eliyle keser. Bu dosyadaki her `== null`
 * denetimi o hatayı engellemek için var.
 */

/**
 * Satır başı azami adet — `lib/cart.ts` içindeki `MAX_QUANTITY` ile aynı
 * sayı. Stokla ilgisi yok: sepet çerezi 4 KB'ye sığmak zorunda ve tek satıra
 * üç haneli adet yazılması kullanıcı hatasıdır.
 */
export const DEFAULT_HARD_MAX = 99;

/** Bu sayıya kadar (dâhil) kalan porsiyon "az kaldı" bandındadır. */
export const DEFAULT_LOW_THRESHOLD = 5;

/** Ekranda çizilecek stok bandı. */
export type StockLevel = 'unlimited' | 'plenty' | 'low' | 'soldOut';

export type MaxAddableInput = {
  /** Günün toplam kalan porsiyonu; `null`/eksik SINIRSIZ. */
  dayRemaining: number | null | undefined;
  /** Bu kalemin kalan porsiyonu; `null`/eksik SINIRSIZ. */
  itemRemaining: number | null | undefined;
  /** Sepette O GÜN için duran toplam adet (bütün kalemler). */
  alreadyInCartForDay: number;
  /** Sepette BU KALEM için duran adet. */
  alreadyInCartForItem: number;
  /** Satır başı tavan; verilmezse {@link DEFAULT_HARD_MAX}. */
  hardMax?: number;
};

/**
 * Sepete daha kaç tane eklenebilir?
 *
 * Üç boşluğun en darı kazanır ve sonuç asla negatif olmaz:
 *
 *   * GÜN boşluğu — gün tavanından o gün için sepetteki adet düşülür.
 *   * KALEM boşluğu — kalem tavanından o kalem için sepetteki adet düşülür.
 *   * SATIR boşluğu — `hardMax`'tan o satırda duran adet düşülür.
 *
 * Sepetteki adetler İKİ TAVANDAN AYRI AYRI düşülür: gün adedi yalnız gün
 * tavanından, kalem adedi yalnız kalem tavanından. İkisini birbirine
 * karıştıran uygulama, aynı günde iki farklı yemek seçen müşteriye tavanı iki
 * kez uygular ve satışı erken keser.
 *
 * Negatif sonuç `0`'a yuvarlanır: yönetici tavanı sepet doldurulduktan sonra
 * indirmiş olabilir. Cevap "eksi iki" değil, "artık eklenemez"dir.
 */
export function maxAddable({
  dayRemaining,
  itemRemaining,
  alreadyInCartForDay,
  alreadyInCartForItem,
  hardMax = DEFAULT_HARD_MAX,
}: MaxAddableInput): number {
  const dayHeadroom =
    dayRemaining == null ? Number.POSITIVE_INFINITY : dayRemaining - alreadyInCartForDay;
  const itemHeadroom =
    itemRemaining == null ? Number.POSITIVE_INFINITY : itemRemaining - alreadyInCartForItem;
  // Satır boşluğu her zaman sonlu; bu yüzden `min()` asla sonsuz dönmez.
  const lineHeadroom = hardMax - alreadyInCartForItem;

  return Math.max(0, Math.min(dayHeadroom, itemHeadroom, lineHeadroom));
}

export type StockLevelInput = {
  /**
   * Ham kalan porsiyon; `null`/eksik SINIRSIZ. Gün ve kalem tavanı birlikte
   * değerlendirilecekse dar olanı verilir
   * (`lib/api/daily-menu.ts` → `itemStock`).
   */
  remaining: number | null | undefined;
  /** "Az kaldı" eşiği; verilmezse {@link DEFAULT_LOW_THRESHOLD}. */
  lowThreshold?: number;
};

/**
 * Kalan porsiyonun ekrandaki bandı.
 *
 * Sıra bağlayıcı: `soldOut` denetimi eşikten ÖNCE gelir, yoksa eşiği `0`
 * ayarlanmış bir vitrinde tükenmiş gün "bol" görünürdü. Eşiğin kendisi
 * `low` sayılır (`<=`); `<` yazan uygulama son beş porsiyonu rozetsiz satar.
 */
export function stockLevel({
  remaining,
  lowThreshold = DEFAULT_LOW_THRESHOLD,
}: StockLevelInput): StockLevel {
  if (remaining == null) return 'unlimited';
  if (remaining <= 0) return 'soldOut';
  if (remaining <= lowThreshold) return 'low';
  return 'plenty';
}
