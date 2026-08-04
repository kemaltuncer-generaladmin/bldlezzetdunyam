import type { MetadataRoute } from 'next';
import { SITE_URL } from '@/lib/api/client';
import { fetchCatalog, flattenItems } from '@/lib/api/catalog';
import { productSlug } from '@/lib/slug';

export const revalidate = 3600;

/**
 * `sitemap.xml` — `docs/06` §2 zorunluluğu. Ürün adresleri menüden türetilir;
 * API erişilemezse yalnızca statik sayfalar yayınlanır (site haritası boş
 * kalmasın).
 */
export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const now = new Date();

  const staticEntries: MetadataRoute.Sitemap = [
    { url: `${SITE_URL}/`, lastModified: now, changeFrequency: 'daily', priority: 1 },
    { url: `${SITE_URL}/menu`, lastModified: now, changeFrequency: 'daily', priority: 0.9 },
    { url: `${SITE_URL}/iletisim`, lastModified: now, changeFrequency: 'yearly', priority: 0.4 },
    { url: `${SITE_URL}/kvkk`, lastModified: now, changeFrequency: 'yearly', priority: 0.2 },
    {
      url: `${SITE_URL}/mesafeli-satis`,
      lastModified: now,
      changeFrequency: 'yearly',
      priority: 0.2,
    },
  ];

  try {
    const { categories } = await fetchCatalog();
    const productEntries: MetadataRoute.Sitemap = flattenItems(categories).map((item) => ({
      url: `${SITE_URL}/urun/${productSlug(item)}`,
      lastModified: now,
      changeFrequency: 'weekly',
      priority: 0.7,
    }));
    return [...staticEntries, ...productEntries];
  } catch {
    return staticEntries;
  }
}
