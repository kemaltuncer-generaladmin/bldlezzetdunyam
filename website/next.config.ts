import type { NextConfig } from 'next';
import createNextIntlPlugin from 'next-intl/plugin';

// Tek dil (tr) ile başlıyoruz; yönlendirmede locale öneki yok (docs/06 §5).
const withNextIntl = createNextIntlPlugin('./i18n/request.ts');

/**
 * `NEXT_PUBLIC_API_URL`'in konağını `next/image` izin listesine çevirir.
 *
 * Adres okunamazsa boş döner: yapılandırma dosyasında hata fırlatmak, tek bir
 * yazım hatası yüzünden derlemenin tamamını durdurur. Görselin çıkmaması daha
 * küçük bir arıza ve nedeni tarayıcı konsolunda yazıyor.
 */
function apiImagePattern(): { protocol: 'http' | 'https'; hostname: string; port?: string }[] {
  const raw = process.env.NEXT_PUBLIC_API_URL;
  if (!raw) return [];

  try {
    const { protocol, hostname, port } = new URL(raw);
    if (protocol !== 'http:' && protocol !== 'https:') return [];
    return [
      { protocol: protocol === 'http:' ? 'http' : 'https', hostname, ...(port ? { port } : {}) },
    ];
  } catch {
    return [];
  }
}

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
    /*
     * Menü görselleri API'den mutlak URL olarak gelir (`MenuItem.image_url`);
     * dosyalar platformun medya kütüphanesindedir, yönetici panelden
     * değiştirir. Bu yüzden izin listesi API adresini içermek zorunda.
     *
     * Üretim alan adları sabit yazılı. Geliştirme/staging adresi ise
     * `NEXT_PUBLIC_API_URL`'den TÜRETİLİR: sabit `localhost:8080` yazsaydık
     * her yeni ortamda burayı elle düzenlemek gerekirdi ve unutulduğunda hata
     * "görsel yüklenmedi" diye değil, 400 ile karşımıza çıkardı.
     *
     * Rastgele bir host eklenmiyor: yalnızca sitenin zaten konuştuğu API.
     */
    remotePatterns: [
      { protocol: 'https', hostname: 'api.benimlezzetdunyam.com.tr' },
      { protocol: 'https', hostname: 'www.benimlezzetdunyam.com.tr' },
      ...apiImagePattern(),
    ],
  },
};

export default withNextIntl(nextConfig);
