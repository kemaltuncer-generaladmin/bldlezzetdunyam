/**
 * Site geneli marka ve iletişim bilgileri — **YEDEK / BAŞLANGIÇ DEĞERİ**.
 *
 * Tek kaynak artık **admin panelidir**; site bu değerleri `GET /site-content`
 * üzerinden okur (`lib/api/site-content.ts`). Bu dosya yalnızca API'ye
 * ulaşılamadığında ya da bir bölüm panelde henüz doldurulmadığında devreye
 * girer. Silinmez: onsuz API kapalıyken site bomboş açılırdı.
 *
 * Burada bir değeri değiştirmek **yayındaki siteyi değiştirmez** — panelde
 * karşılığı doldurulmuşsa panel kazanır.
 *
 * ## `null` ne demek?
 *
 * Bu repoda BLD'ye ait **doğrulanmış** iletişim bilgisi yok. Uydurulmuş bir
 * telefon numarası sahte bir güven yaratır ve arayan kişiyi yanlış yere
 * yönlendirir; bu yüzden bilinmeyen her alan `null`.
 *
 * `null` bir eksiklik işareti değil, arayüzün anladığı bir durumdur: bileşenler
 * `null` alanı yer tutucu metinle doldurmaz, o satırı/bağlantıyı hiç
 * göstermez. Firma sahibi değeri **panelden** girdiği anda ilgili blok
 * kendiliğinden görünür hâle gelir — koda dokunmak gerekmez.
 *
 * Bu felsefe korunuyor: panelden boş dönen bir kanal da `null` olarak
 * geçiyor ve aynı biçimde gizleniyor. Hangi alanların hâlâ eksik olduğunu
 * `pendingContactFields()` (bkz. `lib/api/site-content.ts`) hesaplar.
 */

export type Nullable<T> = T | null;

export interface ContactChannel {
  /** Ekranda görünen biçim, örn. "0212 000 00 00". */
  readonly display: string;
  /** `tel:` / `mailto:` / `https://wa.me/...` için ham değer. */
  readonly href: string;
}

export interface PostalAddress {
  readonly streetAddress: string;
  readonly district: string;
  readonly city: string;
  readonly postalCode: Nullable<string>;
  /** Google Maps yer gömme adresi. Yoksa harita bölümü gizlenir. */
  readonly mapEmbedUrl: Nullable<string>;
}

export interface WorkingHours {
  readonly label: string;
  readonly value: string;
}

export const BRAND = {
  name: 'Benim Lezzet Dünyam',
  shortName: 'BLD',
  /**
   * Şirket ailesi bağı. Site bir eğitim şirketi gibi görünmemeli; bu yüzden
   * bağ yalnızca Kurumsal sayfasında ve footer'da bir cümleyle geçiyor.
   */
  parentGroup: 'Benim Başarı Dünyam',
  tagline: 'Kurumlara günlük yemek, davetlere catering. Sıcak gelir, saatinde gelir.',
  description:
    'Ofislere, fabrikalara, okullara ve davetlere yemek hazırlıyoruz. Menüyü birlikte kuruyoruz, yemeği kendi mutfağımızda pişiriyoruz, teslim saatini siz söylüyorsunuz.',
} as const;

/**
 * Marka simgesi.
 *
 * Repoda BLD'nin kurumsal logo dosyası (şef şapkalı küre + birbirine bağlı BLD
 * harfleri) **yok**. Elimizdeki tek görsel `mutfakapp/assets/icons/bld_*.png` —
 * turuncu zeminde genel bir servis kapağı, uygulama simgesi olarak üretilmiş.
 *
 * Logoyu yeniden çizmek marka kimliğini uydurmak olurdu. Bunun yerine harf
 * işareti kullanıyoruz; panelden bir logo yüklendiğinde (`brand.logo_url`)
 * veya gerçek dosya `public/logo.svg` olarak eklenip `src` doldurulduğunda
 * `BrandMark` bileşeni kendiliğinden görsele geçer.
 */
export const LOGO = {
  src: null as Nullable<string>,
  /** Logo dosyası eklendiğinde ölçülüp güncellenecek. */
  width: 0,
  height: 0,
} as const;

export const CONTACT = {
  phone: null as Nullable<ContactChannel>,
  whatsapp: null as Nullable<ContactChannel>,
  email: null as Nullable<ContactChannel>,
  address: null as Nullable<PostalAddress>,
  workingHours: [] as readonly WorkingHours[],
} as const;

export const SOCIAL: readonly { readonly label: string; readonly href: string }[] = [];
