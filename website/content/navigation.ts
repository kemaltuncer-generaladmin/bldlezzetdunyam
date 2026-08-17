/**
 * Site gezinme yapısı — header, mobil menü, footer ve sitemap tek kaynaktan
 * beslenir. Yeni bir sayfa eklendiğinde yalnızca burası güncellenir.
 *
 * Diğer `content/*.ts` dosyalarının aksine bu dosya **yedek değil, hâlâ tek
 * kaynak**: gezinme yapısı `/site-content` sözleşmesinde yok ve olmamalı.
 * Menü bağlantıları var olan rotalara işaret etmek zorunda; panelden girilen
 * bir adres kolayca 404 üretir. Rotalar kodla birlikte değişir, içerikle değil.
 */

export interface NavLink {
  readonly href: string;
  readonly label: string;
  /** Alt menüde ve mobil menüde bağlantının altında görünen kısa açıklama. */
  readonly summary?: string;
}

export interface NavItem extends NavLink {
  readonly children?: readonly NavLink[];
}

export const MAIN_NAV: readonly NavItem[] = [
  /*
   * DÖRT SAYFA, ALT MENÜ YOK — W-08.
   *
   * Önceki yapı yedi başlık ve sekiz alt sayfalık bir açılır menüydü. İki
   * sorun vardı: 1280 px'te satır taşıyordu (bkz. `ORDERING_ROUTES`) ve
   * ziyaretçinin aradığı şey ("bugün ne var, nasıl sipariş veririm")
   * listenin hiçbir yerinde yoktu.
   *
   * MENÜ İLK SIRADA ve bilerek: site artık sipariş odaklı. Tanıtım
   * içeriği kaybolmadı, `/` ve `/kurumsal` içinde bölüm oldu.
   *
   * `children` alanı tip tanımında DURUYOR: alt menü ihtiyacı geri
   * gelirse `MainNav` onu doğru şekilde çiziyor (Radix, seçimde kapanma).
   */
  { href: '/menu', label: 'Menü' },
  { href: '/kurumsal', label: 'Kurumsal' },
  /*
   * BİLGİ MERKEZİ GERİ GELDİ — M4. Dört başlık 1280 px'te rahat sığıyor;
   * taşmayı yapan eski yedi başlık + sekiz alt sayfalık açılır menüydü.
   */
  { href: '/bilgi-merkezi', label: 'Bilgi Merkezi' },
  { href: '/iletisim', label: 'İletişim' },
];

/** Header'daki birincil eylem. Her sayfada aynı yere gider. */
export const PRIMARY_CTA = { href: '/teklif-al', label: 'Teklif Al' } as const;

/**
 * Sipariş akışı rotaları — header'ın davranışını değiştiren tek liste.
 *
 * Bu rotalarda pazarlama gezinmesi gizlenir, sepet/oturum göstergesi çıkar ve
 * hamburger her genişlikte görünür kalır. Sebep görsel değil, ölçülmüş: yedi
 * bölümlük menü + sepet + "Teklif Al" 1280 px'te satırı 1362 px'e taşıyor ve
 * sayfada yatay kaydırma çıkarıyordu.
 *
 * BURADA, ÇÜNKÜ ÜÇ BİLEŞEN AYNI SORUYU SORUYOR (`MainNav`, `MobileNav`,
 * `HeaderActions`). Liste üçünde de ayrı ayrı yazılıydı; yeni bir sipariş
 * rotası eklendiğinde üçünü birden güncellemeyi hatırlamak gerekiyordu ve
 * biri unutulduğunda belirti "header bazı sayfalarda tuhaf" gibi teşhisi zor
 * bir şey oluyordu.
 */
export const ORDERING_ROUTES: readonly string[] = [
  // `/urun` LİSTEDEN ÇIKTI (B-19): ürün detay sayfaları kaldırıldı ve adres
  // `/menu`ye yönlendiriliyor. Yönlendirilen bir yolu burada tutmak,
  // header'ı hiç uğranmayan bir rotaya göre ayarlamak olurdu.
  '/menu',
  '/sepet',
  '/odeme',
  '/siparis',
  '/siparislerim',
  '/hesabim',
];

/** Verilen yol bir sipariş akışı rotası mı? */
export function isOrderingRoute(pathname: string): boolean {
  return ORDERING_ROUTES.some((route) => pathname === route || pathname.startsWith(`${route}/`));
}

export const FOOTER_NAV: readonly {
  readonly title: string;
  readonly links: readonly NavLink[];
}[] = [
  {
    title: 'Sipariş',
    links: [
      { href: '/menu', label: 'Günün menüsü' },
      { href: '/sepet', label: 'Sepetim' },
      { href: '/siparislerim', label: 'Siparişlerim' },
      // `/hesabim/cari` LİSTEDEN ÇIKTI (B-19): cari hesap müşteri
      // arayüzünden kaldırıldı, sayfa artık yok. Footer'da bırakılsaydı
      // her sayfanın altında 404'e giden bir bağlantı dururdu.
      { href: '/hesabim/adresler', label: 'Adreslerim' },
      { href: '/hesabim/abonelikler', label: 'Aboneliklerim' },
    ],
  },
  {
    title: 'Kurumsal',
    links: [
      { href: '/kurumsal', label: 'Biz kimiz' },
      { href: '/kurumsal#kalite', label: 'Kalite ve hijyen' },
      { href: '/kurumsal#alanlar', label: 'Çalıştığımız alanlar' },
      // Altbilgideki bağlantı, eski 308 yönlendirmesini önbelleğine almış
      // tarayıcılar için ikinci bir giriş kapısı (bkz. `next.config.ts`).
      { href: '/bilgi-merkezi', label: 'Bilgi merkezi' },
      { href: '/teklif-al', label: 'Teklif al' },
    ],
  },
  {
    title: 'Hesap',
    links: [
      { href: '/giris', label: 'Giriş yap' },
      { href: '/kurumsal-kayit', label: 'Kurumsal kayıt' },
      { href: '/iletisim', label: 'İletişim' },
    ],
  },
];

export const LEGAL_NAV: readonly NavLink[] = [
  { href: '/kvkk', label: 'KVKK Aydınlatma Metni' },
  { href: '/gizlilik', label: 'Gizlilik Politikası' },
  { href: '/cerez-politikasi', label: 'Çerez Politikası' },
  { href: '/mesafeli-satis', label: 'Mesafeli Satış Sözleşmesi' },
];
