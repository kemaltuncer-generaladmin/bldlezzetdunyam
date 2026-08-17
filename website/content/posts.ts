/**
 * Bilgi merkezi yazıları — **YEDEK / BAŞLANGIÇ DEĞERİ, BİLEREK BOŞ**.
 *
 * Diğer `content/*.ts` dosyaları API kapalıyken sayfayı ayakta tutan gerçek
 * metinler taşır. Bu dosya taşımıyor ve taşımayacak: liste **boş** doğar.
 *
 * ## Neden boş?
 *
 * `brand` ve `contact` için sabit bir yedek doğrudur — marka adı, sloganı ve
 * telefonu bir kesinti boyunca değişmez, yani yedek "eski" olamaz. Bir YAZI
 * ise öyle değil. Panelde silinmiş, düzeltilmiş ya da hiç yayınlanmamış bir
 * yazıyı repodan yeniden yayınlamak, ziyaretçiye **artık geçerli olmayan bir
 * içeriği** doğruymuş gibi göstermek olur; üstelik bu yalan kesintiden uzun
 * yaşar, çünkü kimse "yedek yazı hâlâ yayında mı" diye bakmaz. Kurum sayfası
 * bir kesintide eski sloganla açılabilir; bilgi merkezi eski bir yazıyla
 * açılmamalı.
 *
 * Bunun bedeli, API kapalıyken liste sayfasının boş çıkması. Ödenmesi gereken
 * doğru bedel bu: sayfa boş kaldığında dürüst bir boş durum çiziliyor
 * (`app/bilgi-merkezi/page.tsx`), uydurma bir arşiv değil.
 *
 * Yazı ekleme yeri **admin panelidir**; `GET /site-content` yanıtındaki
 * `posts` dizisi. Buraya yazı eklenirse yukarıdaki gerekçe çiğnenmiş olur.
 *
 * ## Görsel
 *
 * Yazının fotoğrafı bu dosyada değil: eşleşme `lib/site-images.ts` içinde
 * `postImage(slug)` ile slug üzerinden kuruluyor. Panelden eklenen yeni bir
 * yazının fotoğrafı olmaz (`null` döner) ve kart fotoğrafsız düzene geçer.
 */

export interface Post {
  readonly slug: string;
  /** Kart ve detay başlığı. */
  readonly title: string;
  /** Kartın üstündeki küçük etiket — "Rehber", "Hijyen" gibi. */
  readonly category: string;
  /** Kart özeti ve sayfa `description` metadata'sı. */
  readonly description: string;
  /** Yayın günü, `YYYY-MM-DD`. */
  readonly publishedAt: string;
  /** Tahmini okuma süresi (dakika) — panelde elle girilir. */
  readonly readingMinutes: number;
}

/** Bilerek boş. Gerekçe dosya başlığında. */
export const POSTS: readonly Post[] = [];
