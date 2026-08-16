import type { CartActionState } from '@/lib/action-state';

/**
 * SEPET EYLEMLERİNİN STOK DURUMU.
 *
 * ## Neden `lib/action-state.ts` içinde değil?
 *
 * Aynı sebeple oradaki tipler `app/actions/*.ts` içinde değil: `'use server'`
 * işaretli bir modülden yalnızca async fonksiyon ihraç edilebilir, tip ve
 * sabit ihraç edilemez. Sepet eylemleri ile onları kullanan istemci
 * bileşenlerinin ortak sözlüğü bu yüzden ayrı bir modülde durmak zorunda.
 *
 * ## `limit` BEŞİNCİ BİR DURUM ve hatadan da başarıdan da ayrı
 *
 * "İstediğin adet eklenemedi, kalan bu kadardı" ne bir hata ne de düz bir
 * başarı: işlem KISMEN oldu. `error` olarak taşımak, iki porsiyonu sepetine
 * koyabilmiş müşteriye kırmızı bir uyarı gösterip hiçbir şey olmamış gibi
 * hissettirirdi; `ok` olarak taşımak ise üç isteyip iki alan müşteriye yeşil
 * bir onay gösterip farkı ödeme adımında fark ettirirdi. Stok tavanı günün
 * içinde dolan bir kaynak — kısmi sonuç istisna değil, beklenen hâl.
 *
 * Yeni bir `ErrorCode` AÇILMADI: bu durum ağdan gelmiyor, sepet çerezi ile o
 * günün canlı menüsü karşılaştırılarak istemci sunucusunda doğuyor. Sunucu
 * yine de kendi denetimini yapıyor ve tükenmişi `ITEM_UNAVAILABLE` ile
 * reddediyor.
 */
export type CartLimitState = {
  status: 'limit';
  message: string;
  /** Her işlemde değişir; istemci bunu tetikleyici olarak kullanır. */
  at: number;
  /**
   * Tavana takılmadan önce sepete GERÇEKTEN giren adet. `0` ise hiçbir şey
   * eklenmedi. Ekran metnini bu sayıya göre kurmak, "eklendi" ile
   * "eklenemedi" arasındaki farkı tek bir alanda tutuyor.
   */
  addedQuantity: number;
};

/** Sepete ekleme ve adet güncelleme eylemlerinin tam durum kümesi. */
export type DayCartState = CartActionState | CartLimitState;
