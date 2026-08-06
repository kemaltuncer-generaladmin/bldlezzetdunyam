import type { MetadataRoute } from 'next';
import { SITE_URL } from '@/lib/api/client';
import { fetchCatalog, flattenItems } from '@/lib/api/catalog';
import { fetchSiteContent } from '@/lib/api/site-content';
import { productSlug } from '@/lib/slug';

export const revalidate = 3600;

/**
 * `sitemap.xml` — `docs/06` §2 zorunluluğu.
 *
 * Hizmet ve yazı adresleri admin panelinden türetiliyor: yeni bir hizmet veya
 * yazı yayınlandığında site haritası kendiliğinden güncelleniyor, kimsenin
 * buraya elle satır eklemesi gerekmiyor. İçerik API'si erişilemezse yedek
 * katalogla üretilir — harita hiçbir koşulda hizmetsiz kalmaz.
 *
 * Ürün adresleri menüden geliyor; sipariş API'si erişilemezse yalnızca
 * kurumsal sayfalar yayınlanır (site haritası boş kalmasın).
 */
export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const now = new Date();
  const { posts, services } = await fetchSiteContent();

  const corporateEntries: MetadataRoute.Sitemap = [
    { url: `${SITE_URL}/`, lastModified: now, changeFrequency: 'weekly', priority: 1 },
    { url: `${SITE_URL}/hizmetler`, lastModified: now, changeFrequency: 'monthly', priority: 0.9 },
    { url: `${SITE_URL}/teklif-al`, lastModified: now, changeFrequency: 'monthly', priority: 0.9 },
    {
      url: `${SITE_URL}/menu-cozumleri`,
      lastModified: now,
      changeFrequency: 'monthly',
      priority: 0.8,
    },
    {
      url: `${SITE_URL}/kalite-hijyen`,
      lastModified: now,
      changeFrequency: 'monthly',
      priority: 0.8,
    },
    { url: `${SITE_URL}/kurumsal`, lastModified: now, changeFrequency: 'monthly', priority: 0.7 },
    {
      url: `${SITE_URL}/calistigimiz-alanlar`,
      lastModified: now,
      changeFrequency: 'monthly',
      priority: 0.7,
    },
    {
      url: `${SITE_URL}/bilgi-merkezi`,
      lastModified: now,
      changeFrequency: 'weekly',
      priority: 0.7,
    },
    { url: `${SITE_URL}/iletisim`, lastModified: now, changeFrequency: 'yearly', priority: 0.6 },
    { url: `${SITE_URL}/menu`, lastModified: now, changeFrequency: 'daily', priority: 0.6 },
  ];

  const serviceEntries: MetadataRoute.Sitemap = services.map((service) => ({
    url: `${SITE_URL}/hizmetler/${service.slug}`,
    lastModified: now,
    changeFrequency: 'monthly',
    priority: 0.8,
  }));

  const postEntries: MetadataRoute.Sitemap = posts.map((post) => ({
    url: `${SITE_URL}/bilgi-merkezi/${post.slug}`,
    lastModified: new Date(post.publishedAt),
    changeFrequency: 'yearly',
    priority: 0.5,
  }));

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

  const staticEntries = [...corporateEntries, ...serviceEntries, ...postEntries, ...legalEntries];

  try {
    const { categories } = await fetchCatalog();
    const productEntries: MetadataRoute.Sitemap = flattenItems(categories).map((item) => ({
      url: `${SITE_URL}/urun/${productSlug(item)}`,
      lastModified: now,
      changeFrequency: 'weekly',
      priority: 0.4,
    }));
    return [...staticEntries, ...productEntries];
  } catch {
    return staticEntries;
  }
}
