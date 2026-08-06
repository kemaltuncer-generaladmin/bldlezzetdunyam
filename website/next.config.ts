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
  /*
   * `output: 'standalone'` yalnızca kodun izini sürdüğü dosyaları kopyalar.
   * Paylaşım kartının fontları `readFile` ile okunuyor ve statik analizle
   * görülemiyor; bu satır olmadan üretim imajında dosya bulunamıyor ve kart
   * çalışma anında patlıyor. Yerelde çalıştığı için gözden kaçması çok kolay.
   */
  outputFileTracingIncludes: {
    '/opengraph-image': ['./assets/fonts/*.ttf'],
  },
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
    // picsum.photos KALDIRILDI: mock artık ürün görseli döndürmüyor
    // (gerekçe infra/mock/src/seed.js başında). İzin listesinde bırakmak,
    // ileride biri yanlışlıkla stok fotoğraf koyduğunda bunun sessizce
    // çalışmasına izin vermek olurdu.
    remotePatterns: [
      { protocol: 'https', hostname: 'api.benimlezzetdunyam.com.tr' },
      { protocol: 'https', hostname: 'www.benimlezzetdunyam.com.tr' },
    ],
  },
};

export default withNextIntl(nextConfig);
