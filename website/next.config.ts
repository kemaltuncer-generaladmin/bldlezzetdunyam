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
  /*
   * v2.0 BİLGİ MİMARİSİ SADELEŞTİRMESİ — W-08.
   *
   * On küsur tanıtım sayfası dörde indi: ana sayfa, kurumsal, iletişim ve
   * teklif. Kaldırılan sayfaların içeriği kaybolmadı; `/` ve `/kurumsal`
   * içinde bölüm oldu.
   *
   * KALICI (308) YÖNLENDİRME, SİLME DEĞİL. Bu adreslerin bir kısmı arama
   * motorlarında kayıtlı ve bir kısmı müşterilere e-postayla gönderildi.
   * Sayfayı 404'e bırakmak, o bağlantıların hem sıralamasını hem de
   * ziyaretçisini çöpe atmak olurdu; yönlendirme sıralamayı hedefe taşır.
   *
   * `permanent: true` → 308. Tarayıcı ve arama motoru bunu önbelleğe alır,
   * yani karar geri alınırsa eski bağlantılar bir süre daha yönlenmeye
   * devam eder. Bilinçli: bu sayfalar geri gelmeyecek.
   *
   * Alt sayfalar ÖNCE geliyor (`/hizmetler/:slug`), çünkü Next.js listeyi
   * sırayla eşleştiriyor ve `/hizmetler` kuralı önce yazılsaydı alt
   * sayfaları da yakalar, hepsini ana sayfaya gönderirdi.
   */
  async redirects() {
    return [
      // Hizmet detayları → ana sayfadaki hizmetler bölümü.
      { source: '/hizmetler/:slug', destination: '/#hizmetler', permanent: true },
      { source: '/hizmetler', destination: '/#hizmetler', permanent: true },

      // Menü çözümleri → gerçek menü. Ziyaretçinin aradığı zaten buydu.
      { source: '/menu-cozumleri', destination: '/menu', permanent: true },

      // Kalite/hijyen ve çalıştığımız alanlar → kurumsal sayfanın bölümleri.
      { source: '/kalite-hijyen', destination: '/kurumsal#kalite', permanent: true },
      { source: '/calistigimiz-alanlar', destination: '/kurumsal#alanlar', permanent: true },

      // Bilgi merkezi (blog) tamamen kaldırıldı. Yazıların kendi adresleri
      // için hedef yok; kurumsal sayfa en yakın karşılık.
      { source: '/bilgi-merkezi/:slug', destination: '/kurumsal', permanent: true },
      { source: '/bilgi-merkezi', destination: '/kurumsal', permanent: true },

      /*
       * BİREYSEL KAYIT → KURUMSAL KAYIT.
       *
       * Sipariş kapısı kurumsal hesaplarda açık (`docs/00` B2B kararı) ve
       * sunucu zaten her yeni kaydı kurumsal işaretliyor. Eski `/kayit`
       * formu ise unvan ve vergi bilgisi sormuyordu; yani
       * faturalandırılamayan "kurumsal" hesaplar üretiyordu. İki yol
       * arasındaki bu tutarsızlık, formu doldurduktan sonra fark edilen
       * bir sorun olurdu.
       *
       * `permanent: false` (307) — bu bir iş kuralı, kalıcı bir adres
       * taşıması değil. Bireysel kayıt geri açılırsa tarayıcıda önbelleğe
       * alınmış bir 308 yolu tıkamamalı.
       */
      { source: '/kayit', destination: '/kurumsal-kayit', permanent: false },
    ];
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
