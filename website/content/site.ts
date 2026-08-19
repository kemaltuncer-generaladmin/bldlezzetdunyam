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

export interface LegalIdentity {
  /** Ticari unvan. Şahıs işletmesinde ad-soyad. */
  readonly tradeName: Nullable<string>;
  readonly legalForm: Nullable<string>;
  /** Vergi levhasındaki merkez adresi — iletişim adresinden ayrı. */
  readonly registeredAddress: Nullable<string>;
  readonly taxOffice: Nullable<string>;
  readonly taxNumber: Nullable<string>;
  /** Ticaret siciline kayıtlı olmayan işletmelerde yoktur. */
  readonly mersisNo: Nullable<string>;
  readonly kepAddress: Nullable<string>;
  /** Kart verisini işleyen sağlayıcı. Gerçek POS yokken `null`. */
  readonly paymentProvider: Nullable<string>;
}

/**
 * İşletmenin yasal kimliği — **YEDEK / BAŞLANGIÇ DEĞERİ**, tek kaynak panel.
 *
 * Dosyanın başındaki "doğrulanmamış hiçbir değeri yazma" kuralı burada da
 * geçerli ve İHLAL EDİLMİYOR: aşağıdaki değerler 2024 vergi levhasından
 * (Gelir İdaresi Başkanlığı onay kodu WVVA0KN3E20) birebir alınmıştır. BLD,
 * BBD ile aynı gerçek kişi işletmesi altında faaliyet gösterir.
 *
 * `null` kalanlar gerçekten yok:
 *  - `mersisNo` / `kepAddress` — işletme gerçek kişi tacirdir, ticaret
 *    siciline kayıtlı bir tüzel kişi değildir; bu numaralar mevcut değildir.
 *    Mesafeli Sözleşmeler Yönetmeliği bunları "varsa" kaydıyla ister.
 *  - `paymentProvider` — kodda gerçek bir sanal POS entegrasyonu YOK;
 *    `veykemtu/payment` altında yalnız nakit, havale ve SİMÜLASYON geçidi var
 *    (bkz. `docs/03-api-sozlesmesi.md` §"Faz 1 notu"). Gerçek geçit devreye
 *    girmeden gizlilik metninde sağlayıcı adı iddia edilmez.
 *
 * `contact` bloğundan neden ayrı: iletişim bilgisi eksikse yalnızca bir kanal
 * gizlenir; yasal kimlik eksikse sayfa yayına uygun değildir. İkisi farklı
 * arayüz davranışı gerektiriyor.
 */
export const LEGAL: LegalIdentity = {
  tradeName: 'Hasan Hüseyin Bardakcı',
  legalForm: 'Gerçek kişi (şahıs) işletmesi',
  registeredAddress: 'Parsana Mah. Kaletaş Cad. No: 102/A, Selçuklu / Konya',
  taxOffice: 'Meram',
  taxNumber: '1420702970',
  mersisNo: null,
  kepAddress: null,
  paymentProvider: null,
};

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

/**
 * İletişim kanalları — **YEDEK**, tek kaynak panel.
 *
 * Telefon ve e-posta 19.08.2026'da işletme sahibi tarafından doğrulandı: BLD,
 * BBD ile aynı gerçek kişi işletmesi olduğu için aynı hattı ve aynı destek
 * kutusunu kullanıyor. Dosyanın başındaki "doğrulanmamış hiçbir değeri yazma"
 * kuralı ihlal edilmiyor — burada uydurulmuş değil, teyit edilmiş bir değer var.
 *
 * E-posta `bbdstore.com.tr` alanında: işletme sahibinin kararı. BLD kendi
 * alanında bir kutu açtığında panelden değiştirilir, koda dokunmak gerekmez.
 *
 * `whatsapp`, `address` ve `workingHours` HÂLÂ `null`/boş: bunlar için
 * doğrulanmış bir değer yok. Yasal metinlerin ihtiyaç duyduğu merkez adresi
 * ayrı bir alandan geliyor (bkz. `LEGAL.registeredAddress`) — buradaki adres
 * müşteriye gösterilecek ziyaret adresidir ve catering mutfağının nerede
 * olduğu teyit edilmedi.
 */
export const CONTACT = {
  phone: { display: '0543 943 9725', href: 'tel:+905439439725' } as Nullable<ContactChannel>,
  whatsapp: null as Nullable<ContactChannel>,
  email: {
    display: 'destek@bbdstore.com.tr',
    href: 'mailto:destek@bbdstore.com.tr',
  } as Nullable<ContactChannel>,
  address: null as Nullable<PostalAddress>,
  workingHours: [] as readonly WorkingHours[],
} as const;

export const SOCIAL: readonly { readonly label: string; readonly href: string }[] = [];
