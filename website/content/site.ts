/**
 * Site geneli marka ve iletişim bilgileri — TEK KAYNAK.
 *
 * Telefon, adres, e-posta gibi değerler hiçbir bileşene tekrar yazılmaz;
 * hepsi buradan okunur.
 *
 * ## `null` ne demek?
 *
 * Bu repoda BLD'ye ait **doğrulanmış** iletişim bilgisi yok. Uydurulmuş bir
 * telefon numarası sahte bir güven yaratır ve arayan kişiyi yanlış yere
 * yönlendirir; bu yüzden bilinmeyen her alan `null`.
 *
 * `null` bir eksiklik işareti değil, arayüzün anladığı bir durumdur: bileşenler
 * `null` alanı yer tutucu metinle doldurmaz, o satırı/bağlantıyı hiç
 * göstermez. Firma sahibi değeri girdiği anda ilgili blok kendiliğinden
 * görünür hâle gelir — başka hiçbir dosyaya dokunmak gerekmez.
 *
 * Doldurulması gereken alanların listesi: `PENDING_CONTACT_FIELDS`.
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
  tagline: 'Kalabalık sofralar için planlı, hijyenik ve lezzetli catering çözümleri.',
  description:
    'Kurumlara, okullara, sağlık kuruluşlarına ve organizasyonlara toplu yemek ve catering hizmeti.',
} as const;

/**
 * Marka simgesi.
 *
 * Repoda BLD'nin kurumsal logo dosyası (şef şapkalı küre + birbirine bağlı BLD
 * harfleri) **yok**. Elimizdeki tek görsel `mutfakapp/assets/icons/bld_*.png` —
 * turuncu zeminde genel bir servis kapağı, uygulama simgesi olarak üretilmiş.
 *
 * Logoyu yeniden çizmek marka kimliğini uydurmak olurdu. Bunun yerine harf
 * işareti kullanıyoruz; gerçek dosya `public/logo.svg` olarak eklendiğinde
 * `logoSrc` doldurulur ve `BrandMark` bileşeni otomatik olarak görsele geçer.
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

/**
 * Firma sahibinin doldurması gereken alanlar.
 *
 * İletişim sayfası bu listeyi okuyup, henüz girilmemiş kanallar yüzünden
 * sayfanın boş kalmasını engelleyen bir yönlendirme gösterir (form her hâlükârda
 * çalışır). Liste boşaldığında o yönlendirme kendiliğinden kaybolur.
 */
export const PENDING_CONTACT_FIELDS: readonly string[] = [
  CONTACT.phone ? null : 'telefon',
  CONTACT.whatsapp ? null : 'WhatsApp',
  CONTACT.email ? null : 'e-posta',
  CONTACT.address ? null : 'adres',
  CONTACT.workingHours.length > 0 ? null : 'çalışma saatleri',
].filter((field): field is string => field !== null);

export const HAS_ANY_CONTACT_CHANNEL =
  CONTACT.phone !== null || CONTACT.whatsapp !== null || CONTACT.email !== null;
