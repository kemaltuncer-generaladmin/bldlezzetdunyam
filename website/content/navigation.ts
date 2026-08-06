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
  { href: '/kurumsal', label: 'Kurumsal' },
  {
    href: '/hizmetler',
    label: 'Hizmetlerimiz',
    children: [
      {
        href: '/hizmetler/kurumsal-toplu-yemek',
        label: 'Kurumsal toplu yemek',
        summary: 'Ofis, fabrika ve iş yerleri için düzenli öğün hizmeti',
      },
      {
        href: '/hizmetler/tasima-yemek',
        label: 'Taşıma yemek',
        summary: 'Merkez mutfakta üretim, sıcaklık kontrollü teslimat',
      },
      {
        href: '/hizmetler/yerinde-uretim',
        label: 'Yerinde üretim',
        summary: 'Kurumun kendi mutfağında ekiple üretim',
      },
      {
        href: '/hizmetler/okul-yemek-hizmeti',
        label: 'Okul yemek hizmeti',
        summary: 'Yaş grubuna göre planlanmış öğün ve alerjen takibi',
      },
      {
        href: '/hizmetler/saglik-kuruluslari',
        label: 'Sağlık kuruluşları',
        summary: 'Diyetisyen onaylı menü ve refakatçi öğünleri',
      },
      {
        href: '/hizmetler/santiye-yemek',
        label: 'Şantiye yemek hizmeti',
        summary: 'Vardiyalı çalışmaya uygun, sahada teslim',
      },
      {
        href: '/hizmetler/davet-organizasyon',
        label: 'Davet ve organizasyon',
        summary: 'Düğün, açılış ve kurumsal etkinlik catering',
      },
      {
        href: '/hizmetler/toplanti-ikram',
        label: 'Toplantı ikramları',
        summary: 'Kahvaltı, coffee break ve seminer ikram paketleri',
      },
    ],
  },
  { href: '/menu-cozumleri', label: 'Menü Çözümleri' },
  { href: '/kalite-hijyen', label: 'Kalite ve Hijyen' },
  { href: '/calistigimiz-alanlar', label: 'Çalıştığımız Alanlar' },
  { href: '/bilgi-merkezi', label: 'Bilgi Merkezi' },
  { href: '/iletisim', label: 'İletişim' },
];

/** Header'daki birincil eylem. Her sayfada aynı yere gider. */
export const PRIMARY_CTA = { href: '/teklif-al', label: 'Teklif Al' } as const;

export const FOOTER_NAV: readonly {
  readonly title: string;
  readonly links: readonly NavLink[];
}[] = [
  {
    title: 'Hizmetler',
    links: [
      { href: '/hizmetler/kurumsal-toplu-yemek', label: 'Kurumsal toplu yemek' },
      { href: '/hizmetler/tasima-yemek', label: 'Taşıma yemek' },
      { href: '/hizmetler/yerinde-uretim', label: 'Yerinde üretim' },
      { href: '/hizmetler/okul-yemek-hizmeti', label: 'Okul yemek hizmeti' },
      { href: '/hizmetler/davet-organizasyon', label: 'Davet ve organizasyon' },
      { href: '/hizmetler', label: 'Tüm hizmetler' },
    ],
  },
  {
    title: 'Kurumsal',
    links: [
      { href: '/kurumsal', label: 'Hakkımızda' },
      { href: '/kalite-hijyen', label: 'Kalite ve hijyen' },
      { href: '/menu-cozumleri', label: 'Menü çözümleri' },
      { href: '/calistigimiz-alanlar', label: 'Çalıştığımız alanlar' },
      { href: '/bilgi-merkezi', label: 'Bilgi merkezi' },
    ],
  },
  {
    title: 'Sipariş',
    links: [
      { href: '/menu', label: 'Günün menüsü' },
      { href: '/siparislerim', label: 'Siparişlerim' },
      { href: '/giris', label: 'Giriş yap' },
    ],
  },
];

export const LEGAL_NAV: readonly NavLink[] = [
  { href: '/kvkk', label: 'KVKK Aydınlatma Metni' },
  { href: '/gizlilik', label: 'Gizlilik Politikası' },
  { href: '/cerez-politikasi', label: 'Çerez Politikası' },
  { href: '/mesafeli-satis', label: 'Mesafeli Satış Sözleşmesi' },
];
