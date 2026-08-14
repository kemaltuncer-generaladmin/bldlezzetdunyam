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
    // Adres çubuğu ve açılış zemini: açık temanın `--background` değeri
    // (neutral50). `app/layout.tsx` içindeki `themeColor` ile aynı.
    background_color: '#FAF6F0',
    theme_color: '#FAF6F0',
    /*
     * `purpose` AYRIMI ZORUNLU.
     *
     * Android adaptive icon, verilen görseli cihaz temasının maskesiyle
     * (daire, squircle, teardrop…) KIRPAR. Tek bir "any" ikon verirsek
     * Android onu maskable sanmaz, kırpmaz ve simgeyi beyaz bir kutunun
     * içine yerleştirir — yanında duran uygulamalardan farklı görünür.
     * Maskable sürümde amblem kanvasın %60'ında kalıyor, yani en agresif
     * maske bile amblemi kesmiyor.
     *
     * SVG maskable olarak verilemez (Android yalnızca raster kabul ediyor),
     * bu yüzden PNG'ler `public/` altında duruyor.
     */
    icons: [
      { src: '/icon.svg', sizes: 'any', type: 'image/svg+xml', purpose: 'any' },
      { src: '/icon-192.png', sizes: '192x192', type: 'image/png', purpose: 'any' },
      { src: '/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any' },
      {
        src: '/icon-512-maskable.png',
        sizes: '512x512',
        type: 'image/png',
        purpose: 'maskable',
      },
      { src: '/apple-icon', sizes: '180x180', type: 'image/png', purpose: 'any' },
    ],
  };
}
