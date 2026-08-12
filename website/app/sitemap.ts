import type { MetadataRoute } from 'next';
import { SITE_URL } from '@/lib/api/client';
import { fetchCatalog, flattenItems } from '@/lib/api/catalog';
import { productSlug } from '@/lib/slug';

export const revalidate = 3600;

/**
 * `sitemap.xml` — `docs/06` §2 zorunluluğu.
 *
 * v2.0'DA KISALDI (W-08). Önceki sürüm hizmet ve blog yazılarının her birini
 * ayrı adres olarak listeliyordu; o sayfalar artık yok ve adresleri kalıcı
 * yönlendirmeye bağlı (`next.config.ts`). Yönlendirilen bir adresi site
 * haritasında ilan etmek, arama motoruna "buraya git" deyip kapıda başka
 * yere göndermek olurdu — tarama bütçesini boşa harcar.
 *
 * Geriye iki grup kalıyor: sabit sayfalar ve MENÜ ÜRÜNLERİ. Ürünler
 * kataloğdan geliyor, yani yeni bir yemek eklendiğinde harita kendiliğinden
 * güncelleniyor.
 *
 * Sipariş API'si erişilemezse yalnızca sabit sayfalar yayınlanır — harita
 * hiçbir koşulda boş kalmaz.
 */
export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const now = new Date();

  /*
   * Öncelik sırası ziyaret niyetini yansıtıyor: menü her gün değişiyor ve
   * sipariş oradan başlıyor, bu yüzden ana sayfadan hemen sonra geliyor.
   * Eski haritada `/menu` en alttaydı (0.6) ve blog ondan yüksekti (0.7).
   */
  const staticEntries: MetadataRoute.Sitemap = [
    { url: `${SITE_URL}/`, lastModified: now, changeFrequency: 'daily', priority: 1 },
    { url: `${SITE_URL}/menu`, lastModified: now, changeFrequency: 'daily', priority: 0.9 },
    { url: `${SITE_URL}/teklif-al`, lastModified: now, changeFrequency: 'monthly', priority: 0.8 },
    { url: `${SITE_URL}/kurumsal`, lastModified: now, changeFrequency: 'monthly', priority: 0.7 },
    {
      url: `${SITE_URL}/kurumsal-kayit`,
      lastModified: now,
      changeFrequency: 'monthly',
      priority: 0.6,
    },
    { url: `${SITE_URL}/iletisim`, lastModified: now, changeFrequency: 'yearly', priority: 0.5 },
  ];

  const legalEntries: MetadataRoute.Sitemap = [
    '/kvkk',
    '/gizlilik',
    '/cerez-politikasi',
    '/mesafeli-satis',
  ].map((path) => ({
    url: `${SITE_URL}${path}`,
    lastModified: now,
    changeFrequency: 'yearly',
    priority: 0.2,
  }));

  const baseEntries = [...staticEntries, ...legalEntries];

  try {
    const { categories } = await fetchCatalog();
    const productEntries: MetadataRoute.Sitemap = flattenItems(categories).map((item) => ({
      url: `${SITE_URL}/urun/${productSlug(item)}`,
      lastModified: now,
      changeFrequency: 'weekly',
      priority: 0.4,
    }));
    return [...baseEntries, ...productEntries];
  } catch {
    return baseEntries;
  }
}
