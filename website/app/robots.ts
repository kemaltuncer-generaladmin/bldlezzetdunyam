import type { MetadataRoute } from 'next';
import { SITE_URL } from '@/lib/api/client';

/**
 * `robots.txt` — `docs/06` §2. Kişisel veri taşıyan ve oturum gerektiren
 * alanlar dizinlenmez; katalog sayfaları serbesttir.
 */
export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        // Kişisel veri taşıyan ve oturum gerektiren alanlar dizinlenmez.
        // Kurumsal sayfaların tamamı serbesttir.
        disallow: [
          '/sepet',
          '/odeme',
          '/siparis/',
          '/siparislerim',
          '/hesabim',
          '/giris',
          '/kayit',
          '/api/',
        ],
      },
    ],
    sitemap: `${SITE_URL}/sitemap.xml`,
    host: SITE_URL,
  };
}
