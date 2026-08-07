/**
 * Kurumsal sayfaların fotoğrafları.
 *
 * ## Neden API'den gelmiyor?
 *
 * Fotoğrafı `site-content` sözleşmesine alan olarak eklemek, `docs/openapi.yaml`
 * değişikliği + panel formu + istemci tip üretimi demekti. Buradaki fotoğraflar
 * ise BLD'nin kendi fotoğrafları değil; gerçek çekimler geldiğinde **dosyalar**
 * değişecek, içerik değil. Sözleşmeye kalıcı bir alan açmak, geçici bir durum
 * için kalıcı bir yüzey açmak olurdu.
 *
 * Bu yüzden eşleşme slug üzerinden, derleme zamanında kuruluyor: panelde bir
 * hizmet eklenirse fotoğrafı olmaz (`null` döner) ve bileşen fotoğrafsız düzene
 * geçer — kırık görsel çıkmaz.
 *
 * Menü ürünlerinin fotoğrafı burada DEĞİL: onlar gerçekten canlı veridir,
 * `MenuItem.image_url` ile API'den gelir ve panelden değiştirilir.
 *
 * Dosyalar, oranlar ve lisans: `public/gorseller/KAYNAK.md`.
 */

/** Slug tabanlı kümeler — dosyası olmayan slug `null` döner. */
const SERVICE_SLUGS = new Set([
  'kurumsal-toplu-yemek',
  'tasima-yemek',
  'yerinde-uretim',
  'okul-yemek-hizmeti',
  'saglik-kuruluslari',
  'santiye-yemek',
  'davet-organizasyon',
  'toplanti-ikram',
]);

const SECTOR_SLUGS = new Set([
  'sanayi',
  'egitim',
  'saglik',
  'kamu',
  'ofis',
  'insaat',
  'organizasyon',
]);

const MENU_SLUGS = new Set([
  'kurumsal-dort-kap',
  'personel-uc-kap',
  'ogrenci-menusu',
  'kahvalti-ikram',
  'davet-menusu',
  'ozel-beslenme',
]);

/** Yazı slug'ları dosya adıyla birebir aynı değil; eşleşme elle kuruluyor. */
const POST_IMAGES: Record<string, string> = {
  'toplu-yemek-firmasi-secerken': 'yazi-firma-secimi',
  'kurumsal-catering-nedir': 'yazi-catering-nedir',
  'is-yerleri-icin-menu-planlamasi': 'yazi-menu-planlamasi',
  'catering-hizmetinde-hijyen': 'yazi-hijyen',
  'organizasyon-menusu-nasil-secilir': 'yazi-organizasyon-menusu',
  'kalabalik-etkinliklerde-yemek-planlamasi': 'yazi-kalabalik-etkinlik',
};

export function serviceImage(slug: string): string | null {
  return SERVICE_SLUGS.has(slug) ? `/gorseller/hizmet-${slug}.webp` : null;
}

export function sectorImage(slug: string): string | null {
  return SECTOR_SLUGS.has(slug) ? `/gorseller/sektor-${slug}.webp` : null;
}

export function menuSolutionImage(slug: string): string | null {
  return MENU_SLUGS.has(slug) ? `/gorseller/menu-${slug}.webp` : null;
}

export function postImage(slug: string): string | null {
  const name = POST_IMAGES[slug];
  return name ? `/gorseller/${name}.webp` : null;
}

/**
 * Anlatı fotoğrafları — sabit yerlerde kullanılır, slug'a bağlı değil.
 *
 * Hiçbiri "bizim mutfağımız" iddiası taşımaz; alt metinleri de bu yüzden
 * sahneyi tarif eder, sahibini değil (gerekçe: `KAYNAK.md`).
 */
export const PHOTO = {
  hero: {
    src: '/gorseller/hero-catering.webp',
    alt: 'Catering büfesinde tabaklara yemek konulurken',
  },
  mutfakEkip: {
    src: '/gorseller/mutfak-ekip.webp',
    alt: 'Endüstriyel mutfakta çalışan aşçı ekibi',
  },
  mutfakTencere: {
    src: '/gorseller/mutfak-tencere.webp',
    alt: 'Buğusu tüten endüstriyel mutfak tezgâhı',
  },
  mutfakSef: { src: '/gorseller/mutfak-sef.webp', alt: 'Tezgâhta yemek hazırlayan aşçı' },
  servisBufe: {
    src: '/gorseller/servis-bufe.webp',
    alt: 'Sıcak tutuculu büfede servis edilen yemekler',
  },
  sofraMezze: {
    src: '/gorseller/sofra-mezze.webp',
    alt: 'Küçük kaplarda dizilmiş meze ve yemek çeşitleri',
  },
  izgaraTabak: {
    src: '/gorseller/izgara-tabak.webp',
    alt: 'Izgara et ve sebzelerden oluşan tabak',
  },
  kahvalti: { src: '/gorseller/kahvalti-sofrasi.webp', alt: 'Kalabalık bir kahvaltı sofrası' },
  kaliteEldiven: {
    src: '/gorseller/kalite-eldiven.webp',
    alt: 'Eldivenle malzeme hazırlayan mutfak çalışanı',
  },
  kaliteMutfak: {
    src: '/gorseller/kalite-mutfak.webp',
    alt: 'İş kıyafetiyle ocak başında çalışan aşçı',
  },
  menuVitrin: {
    src: '/gorseller/menu-vitrin.webp',
    alt: 'Servise hazırlanmış salata ve yemek kapları',
  },
  siparisPaket: {
    src: '/gorseller/siparis-paket.webp',
    alt: 'Yola çıkmaya hazır kapalı yemek kapları',
  },
} as const;
