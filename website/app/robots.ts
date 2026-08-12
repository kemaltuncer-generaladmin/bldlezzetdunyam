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
        /*
         * Kişisel veri taşıyan ve oturum gerektiren alanlar dizinlenmez.
         * Kurumsal sayfaların tamamı serbesttir.
         *
         * `/kurumsal-kayit` BİLEREK LİSTEDE DEĞİL (v2.0). Yerini aldığı
         * `/kayit` buradaydı ve doğruydu — bireysel kayıt aranacak bir
         * sayfa değildi. Kurumsal kayıt ise bir DÖNÜŞÜM sayfası: "kurumsal
         * yemek hesabı" arayan bir satın alma sorumlusunun inebileceği
         * yer ve boş bir form olduğu için kişisel veri taşımıyor.
         * `sitemap.ts` de onu ilan ediyor; ikisi tutarlı olmak zorunda.
         */
        disallow: ['/sepet', '/odeme', '/siparis/', '/siparislerim', '/hesabim', '/giris', '/api/'],
      },
    ],
    sitemap: `${SITE_URL}/sitemap.xml`,
    host: SITE_URL,
  };
}
