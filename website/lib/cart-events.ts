/**
 * Sepet değişince başlıktaki rozet yenilensin diye kullanılan tarayıcı olayı.
 * Sunucu eylemi bittikten sonra istemci bunu yayınlar; rozet cookie'yi tekrar
 * okur. JavaScript kapalıysa form yine de gönderilir ve sayfa yenilenince
 * rozet doğru değeri alır.
 */
export const CART_CHANGED_EVENT = 'bld:cart-changed';

export function announceCartChanged(): void {
  if (typeof window === 'undefined') return;
  window.dispatchEvent(new Event(CART_CHANGED_EVENT));
}
