import type { NextConfig } from 'next';
import createNextIntlPlugin from 'next-intl/plugin';

// Tek dil (tr) ile başlıyoruz; yönlendirmede locale öneki yok (docs/06 §5).
const withNextIntl = createNextIntlPlugin('./i18n/request.ts');

const nextConfig: NextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  images: {
    // Menü görselleri API'den mutlak URL olarak gelir (MenuItem.image_url).
    // Üretimde yalnızca kendi CDN'imiz kalacak; mock picsum kullanıyor.
    remotePatterns: [
      { protocol: 'https', hostname: 'picsum.photos' },
      { protocol: 'https', hostname: 'fastly.picsum.photos' },
      { protocol: 'https', hostname: 'api.benimlezzetdunyam.com.tr' },
      { protocol: 'https', hostname: 'www.benimlezzetdunyam.com.tr' },
    ],
  },
};

export default withNextIntl(nextConfig);
