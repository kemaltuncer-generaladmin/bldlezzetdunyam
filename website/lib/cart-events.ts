import { watchBrowserCookie } from '@/lib/browser-cookie';

/**
 * Sepet değişince başlıktaki rozet yenilensin diye kullanılan tarayıcı olayı.
 * Sunucu eylemi bittikten sonra istemci bunu yayınlar; rozet cookie'yi tekrar
 * okur. JavaScript kapalıysa form yine de gönderilir ve sayfa yenilenince
 * rozet doğru değeri alır.
 */
export const CART_CHANGED_EVENT = 'bld:cart-changed';

/**
 * Sepetteki adedi taşıyan, `httpOnly` OLMAYAN cookie. Kaynak tanımı sunucu
 * tarafındaki `lib/cart.ts` içinde (`CART_COUNT_COOKIE`); o modül `server-only`
 * olduğu için istemciye açılamıyor ve ad burada ikinci kez yazılıyor.
 *
 * Adı DEĞİŞTİRİRKEN İKİSİ BİRDEN değişmeli: aksi hâlde sunucu yazar, istemci
 * bakmaz ve rozet sessizce sıfırda kalır.
 */
export const CART_COUNT_COOKIE = 'bld_cart_n';

export function announceCartChanged(): void {
  if (typeof window === 'undefined') return;
  window.dispatchEvent(new Event(CART_CHANGED_EVENT));
}

/**
 * Sepet göstergelerinin "artık tekrar oku" sinyali — TEK yerden.
 *
 * Üç kaynağı birleştiriyor ve üçü de gerekli:
 *
 *  1. `CART_CHANGED_EVENT` — aynı sekmedeki HIZLI yol. Sepete ekleme başarılı
 *     olduğu anda yayınlanıyor, rozet ağ turu beklemeden güncelleniyor.
 *  2. `focus` — başka sekmede sepeti değiştirip geri dönen kullanıcı.
 *  3. `bld_cart_n` ÇEREZİNİN KENDİSİ — güvenlik ağı.
 *
 * Üçüncüsü v2.0'da eklendi ve asıl düzeltme o. Öncesinde rozet yalnız (1) ve
 * (2) ile besleniyordu; yani doğruyu öğrenmesi, sepete ekleme eyleminin
 * istemci tarafındaki başarı dalının ÇALIŞMASINA bağlıydı. Ölçtük: sunucu
 * eylemi başarıyla bitip çerez tarayıcıya yazıldığı hâlde React geçişi bazen
 * hiç sonuçlanmıyor ve o dal çalışmıyor — sepette ürün varken başlık
 * "Sepetiniz boş" demeye devam ediyor. Çerezi doğrudan izlemek, rozeti o
 * dalın sağlığından ayırıyor: kaynak zaten tarayıcıda, haberciye gerek yok.
 *
 * Ayrıntılı gerekçe ve tarayıcı farkları: `lib/browser-cookie.ts`.
 */
export function subscribeCartChanged(onChange: () => void): () => void {
  if (typeof window === 'undefined') return () => {};

  window.addEventListener(CART_CHANGED_EVENT, onChange);
  window.addEventListener('focus', onChange);
  const unwatchCookie = watchBrowserCookie(CART_COUNT_COOKIE, onChange);

  return () => {
    window.removeEventListener(CART_CHANGED_EVENT, onChange);
    window.removeEventListener('focus', onChange);
    unwatchCookie();
  };
}
