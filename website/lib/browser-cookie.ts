/**
 * Tarayıcıda `httpOnly` olmayan cookie okuma. Yalnızca görsel ipuçları için
 * kullanılır (sepet rozeti, başlıktaki ad) — yetki kararı **asla** buna
 * dayandırılmaz, oturum token'ı `httpOnly`'dir.
 */
export function readBrowserCookie(name: string): string | null {
  if (typeof document === 'undefined') return null;
  const prefix = `${encodeURIComponent(name)}=`;
  for (const part of document.cookie.split('; ')) {
    if (part.startsWith(prefix)) {
      return decodeURIComponent(part.slice(prefix.length));
    }
  }
  return null;
}

/**
 * Cookie Store API — TS'in DOM tanımlarında henüz yok, burada dar bir yüzeyle
 * tarif ediliyor. `any` yasak (AGENTS §4), bu yüzden yalnız kullandığımız iki
 * alan yazılıyor.
 */
type CookieChange = { readonly name: string };
type CookieChangeEvent = Event & {
  readonly changed?: readonly CookieChange[];
  readonly deleted?: readonly CookieChange[];
};

function cookieStore(): EventTarget | null {
  return (globalThis as { cookieStore?: EventTarget }).cookieStore ?? null;
}

/**
 * `document.cookie` yoklama aralığı — yalnızca `cookieStore` YOKKEN kullanılır.
 *
 * Bir saniye, kullanıcının fark edemeyeceği kadar kısa; okuma da bellek içi bir
 * metin ayrıştırması, ağ ya da disk işi değil.
 */
const POLL_MS = 1000;

/**
 * Bir çerezin değişimini izler; değiştiğinde `onChange` çağrılır.
 *
 * ## NEDEN GEREKLİ — ölçülmüş bir müşteri hatası
 *
 * Sepet rozeti `bld_cart_n` çerezini yansıtır ama çerezi yalnız EL İLE
 * YAYINLANAN bir olayda (`bld:cart-changed`) yeniden okuyordu. O olayı
 * yayınlayan şey, sepete ekleme sunucu eyleminin istemci tarafındaki başarı
 * dalıydı — yani rozetin doğruyu öğrenmesi, React'in eylemi commit etmesine
 * bağlıydı.
 *
 * Ölçüm: sunucu eylemi başarıyla bitip `Set-Cookie: bld_cart_n=1` tarayıcıya
 * ULAŞTIĞI hâlde (tıklamadan 221 ms sonra), React geçişi bazen hiç
 * sonuçlanmıyor. O durumda müşterinin sepetinde ürün VAR, çerez doğru, sunucu
 * doğru — ama başlık "Sepetiniz boş" demeye devam ediyor. Müşteri ya aynı
 * ürünü ikinci kez ekliyor ya da vazgeçiyor.
 *
 * Çözüm, haberi beklemek yerine KAYNAĞA bakmak: çerez zaten tarayıcıda ve
 * değiştiği an duyurulabiliyor. Böylece rozet, eylemin istemci tarafının
 * sağlığından bağımsız olarak doğruyu söylüyor.
 *
 * ## İki yol
 *
 * `cookieStore` (Chromium, güvenli bağlam) `Set-Cookie` YANIT BAŞLIĞIYLA gelen
 * değişimi de olay olarak veriyor — aradığımız tam olarak bu. Desteklemeyen
 * tarayıcıda (bugün Safari ve Firefox) çerez değişiminin olayı yok; oradaki
 * yedek, yalnız sekme GÖRÜNÜRKEN dönen kısa bir yoklama. Arka plan sekmesinde
 * hiç çalışmıyor: görünmeyen bir rozetin tazeliğinin değeri yok.
 */
export function watchBrowserCookie(name: string, onChange: () => void): () => void {
  if (typeof document === 'undefined') return () => {};

  const store = cookieStore();
  if (store !== null) {
    const listener = (event: Event) => {
      const { changed = [], deleted = [] } = event as CookieChangeEvent;
      // Silinme de bir değişim: sepet boşalınca çerez `delete` ediliyor.
      if (changed.some((c) => c.name === name) || deleted.some((c) => c.name === name)) {
        onChange();
      }
    };
    store.addEventListener('change', listener);
    return () => store.removeEventListener('change', listener);
  }

  let last = readBrowserCookie(name);
  const timer = window.setInterval(() => {
    if (document.visibilityState !== 'visible') return;
    const current = readBrowserCookie(name);
    if (current === last) return;
    last = current;
    onChange();
  }, POLL_MS);

  return () => window.clearInterval(timer);
}
