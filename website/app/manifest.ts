import type { MetadataRoute } from 'next';
import { fetchSiteContent } from '@/lib/api/site-content';

/**
 * Web uygulaması bildirimi.
 *
 * Android'de "ana ekrana ekle" dendiğinde kullanılıyor. Olmadığında tarayıcı
 * kısayolu sayfa başlığıyla ve genel bir simgeyle oluşturuyor.
 *
 * `display: 'browser'` — BİLİNÇLİ. Site tam ekran bir uygulama gibi açılsaydı
 * adres çubuğu kaybolurdu; kurumsal bir ziyaretçinin adresi görüp firmayı
 * doğrulayabilmesi güven açısından daha değerli. Ayrıca gerçek mobil
 * uygulamamız var (`musteriapp`); siteyi onun taklidi hâline getirmek
 * kafa karıştırır.
 */
export default async function manifest(): Promise<MetadataRoute.Manifest> {
  const { brand } = await fetchSiteContent();

  return {
    name: brand.name,
    short_name: brand.shortName,
    description: brand.description,
    start_url: '/',
    display: 'browser',
    lang: 'tr',
    dir: 'ltr',
    // Adres çubuğu rengi sayfa zemininin açık tema değeriyle aynı
    // (`--background`); layout'taki `themeColor` ile tutarlı.
    background_color: '#fafaf9',
    theme_color: '#fafaf9',
    icons: [
      { src: '/icon.svg', sizes: 'any', type: 'image/svg+xml' },
      { src: '/apple-icon', sizes: '180x180', type: 'image/png' },
    ],
  };
}
