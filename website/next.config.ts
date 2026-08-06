import type { NextConfig } from 'next';
import createNextIntlPlugin from 'next-intl/plugin';

// Tek dil (tr) ile başlıyoruz; yönlendirmede locale öneki yok (docs/06 §5).
const withNextIntl = createNextIntlPlugin('./i18n/request.ts');

const nextConfig: NextConfig = {
  // Konteyner dağıtımı için: `next build` çalıştırılabilir bir sunucu ve
  // yalnızca gerçekten kullanılan node_modules'ü .next/standalone altına
  // toplar. Onsuz imaja tüm bağımlılık ağacını kopyalamak gerekir —
  // ~800 MB yerine ~180 MB.
  output: 'standalone',
  reactStrictMode: true,
  poweredByHeader: false,
  experimental: {
    /*
     * `radix-ui` ve `lucide-react` barrel paketlerdir: shadcn bileşenleri
     * `import { Slot } from 'radix-ui'` yazar ve bu tek satır, ağaç sarsma
     * tam çalışmadığında Radix'in tamamını istemci paketine sokar. Ölçtük:
     * hiçbir Radix bileşeni kullanmayan /kvkk sayfası bile 239 kB'lık ortak
     * parçayı indiriyordu.
     *
     * Bu ayar, barrel'dan yapılan içe aktarımları derleme sırasında doğrudan
     * alt modüle çevirir.
     */
    optimizePackageImports: ['radix-ui', 'lucide-react'],
  },
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
