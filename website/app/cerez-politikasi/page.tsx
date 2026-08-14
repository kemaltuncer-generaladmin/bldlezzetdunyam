import type { Metadata } from 'next';
import Link from 'next/link';
import { TriangleAlert } from 'lucide-react';
import { JsonLd } from '@/components/json-ld';
import { PageHero, type Crumb } from '@/components/site/page-hero';
import { Section } from '@/components/site/section';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { fetchSiteContent } from '@/lib/api/site-content';
import { breadcrumbJsonLd, pageMetadata } from '@/lib/seo';

const TITLE = 'Çerez Politikası';
const DESCRIPTION =
  'Bu sitede kullanılan çerezler, ne işe yaradıkları, ne kadar süre saklandıkları ve tarayıcıdan nasıl yönetilecekleri.';

const CRUMBS: readonly Crumb[] = [{ href: '/cerez-politikasi', label: TITLE }];

export async function generateMetadata(): Promise<Metadata> {
  const { brand } = await fetchSiteContent();

  return pageMetadata({
    title: TITLE,
    description: DESCRIPTION,
    path: '/cerez-politikasi',
    brandName: brand.name,
  });
}

interface CookieRow {
  readonly name: string;
  readonly category: string;
  readonly purpose: string;
  readonly duration: string;
  /** Sayfadaki JavaScript bu çerezi okuyabiliyor mu? */
  readonly readableByScripts: string;
}

/**
 * Tablo, sitenin gerçekten yazdığı çerezlerden oluşuyor — kaynakları
 * `lib/session.ts` ve `lib/cart.ts`. Genel bir çerez şablonu kopyalanmadı;
 * burada olmayan bir çerez sitede de yok. Kod tarafında yeni bir çerez
 * eklenirse bu tabloya da satır eklenmelidir.
 */
const COOKIES: readonly CookieRow[] = [
  {
    name: 'bld_token',
    category: 'Zorunlu',
    purpose:
      'Giriş yapan kullanıcının oturumunu sürdürür. Bu çerez olmadan hesap gerektiren sayfalar (siparişlerim, ödeme) açılamaz.',
    duration: '30 gün',
    readableByScripts: 'Hayır (httpOnly)',
  },
  {
    name: 'bld_name',
    category: 'İşlevsel',
    purpose:
      'Sayfa başlığındaki alanda “Giriş yap” yerine adınızın görünmesini sağlar. Yalnızca adı tutar.',
    duration: '30 gün',
    readableByScripts: 'Evet',
  },
  {
    name: 'bld_cart',
    category: 'Zorunlu',
    purpose:
      'Sepetinizi tutar: ürün kimliği, adet, seçilen seçenekler ve varsa sipariş notu. Ürün adı ve fiyat taşımaz; tutar her seferinde sunucuda hesaplanır.',
    duration: '7 gün',
    readableByScripts: 'Hayır (httpOnly)',
  },
  {
    name: 'bld_cart_n',
    category: 'İşlevsel',
    purpose: 'Sepetteki toplam ürün adedini tutar; başlıktaki sepet rozeti bu değerden okunur.',
    duration: '7 gün',
    readableByScripts: 'Evet',
  },
];

export default async function CerezPolitikasiPage() {
  const { brand } = await fetchSiteContent();

  return (
    <>
      <JsonLd data={breadcrumbJsonLd(CRUMBS)} />

      <PageHero crumbs={CRUMBS} title={TITLE} description={DESCRIPTION} />

      <Section>
        <div className="max-w-3xl">
          {/* Uyarı en üstte: hukuki metinlerde taslak olma durumu okunmadan görülmeli. */}
          <Alert variant="warning">
            <TriangleAlert strokeWidth={1.75} aria-hidden="true" />
            <AlertTitle>Bu metin taslaktır, hukuk danışmanı onayı gerekir</AlertTitle>
            <AlertDescription>
              Aşağıdaki tablo sitenin bugün yazdığı çerezleri birebir anlatır; metnin kendisi hukuki
              danışmanlık değildir ve bağlayıcı bir taahhüt oluşturmaz. Yayına çıkmadan önce bir
              hukuk danışmanı tarafından incelenmelidir. Ayrıca siteye analitik, harita veya benzeri
              bir üçüncü taraf hizmet eklenirse hem bu tablo hem de çerez onayı yaklaşımı yeniden
              değerlendirilmelidir.
            </AlertDescription>
          </Alert>

          <div className="bld-prose mt-10">
            <h2>Çerez nedir?</h2>
            <p>
              Çerez, bir siteyi ziyaret ettiğinizde tarayıcınıza kaydedilen küçük bir metin
              dosyasıdır. Sonraki isteklerde tarayıcı bu dosyayı siteye geri gönderir; site de
              oturumunuzu ve sepetinizi böyle hatırlar.
            </p>
            <p>
              {brand.name} sitesinde çerezler yalnızca sitenin çalışması ve alışveriş akışının
              sürmesi için kullanılıyor. Reklam veya profilleme amaçlı bir çerez bulunmuyor.
            </p>

            <h2>Bu sitede kullanılan çerezler</h2>
          </div>

          {/* Geniş tablo yalnızca kendi kabında yatay kayar; sayfa gövdesi kaymaz. */}
          <div className="mt-6 overflow-x-auto rounded-md border">
            <table className="w-full min-w-[46rem] border-collapse text-left text-body-sm">
              <caption className="sr-only">
                Sitede kullanılan çerezlerin adı, türü, amacı, saklanma süresi ve tarayıcı
                betiklerine açık olup olmadığı.
              </caption>
              <thead className="bg-muted text-muted-foreground">
                <tr>
                  <th scope="col" className="px-4 py-3 font-semibold">
                    Çerez
                  </th>
                  <th scope="col" className="px-4 py-3 font-semibold">
                    Tür
                  </th>
                  <th scope="col" className="px-4 py-3 font-semibold">
                    Amacı
                  </th>
                  <th scope="col" className="px-4 py-3 font-semibold">
                    Süre
                  </th>
                  <th scope="col" className="px-4 py-3 font-semibold">
                    Betiklere açık mı?
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {COOKIES.map((cookie) => (
                  <tr key={cookie.name}>
                    <th scope="row" className="px-4 py-3 font-mono text-caption font-semibold">
                      {cookie.name}
                    </th>
                    <td className="px-4 py-3 whitespace-nowrap">{cookie.category}</td>
                    <td className="px-4 py-3 text-muted-foreground">{cookie.purpose}</td>
                    <td className="px-4 py-3 whitespace-nowrap">{cookie.duration}</td>
                    <td className="px-4 py-3 whitespace-nowrap">{cookie.readableByScripts}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="bld-prose">
            <h2>Çerez türleri ne anlama geliyor?</h2>
            <ul>
              <li>
                <strong>Zorunlu çerezler:</strong> sitenin temel işlevleri için gereklidir. Giriş ve
                sepet bu gruptadır; kapatılmaları hâlinde sipariş akışı çalışmaz.
              </li>
              <li>
                <strong>İşlevsel çerezler:</strong> arayüzün doğru görünmesini sağlar; içerdikleri
                bilgi sınırlıdır ve kimlik doğrulaması için kullanılmaz.
              </li>
              <li>
                <strong>Analitik ve reklam çerezleri:</strong> ziyaretçi davranışını ölçmek veya
                reklam göstermek için kullanılır. Bu sitede bu türde çerez kullanılmıyor.
              </li>
            </ul>

            <h2>Tema tercihi: çerez değil, tarayıcı deposu</h2>
            <p>
              Açık/koyu tema tercihiniz çerezde değil, tarayıcınızın yerel deposunda (localStorage)
              saklanır. Bu değer sunucuya gönderilmez, yalnızca sayfanın hangi temada açılacağını
              belirler. Tarayıcınızın site verilerini temizlediğinizde silinir.
            </p>

            <h2>Üçüncü taraf çerezleri</h2>
            <p>
              Sitede şu anda üçüncü taraf analitik, reklam veya sosyal medya çerezi bulunmuyor.
              İleride ödeme sağlayıcısı, harita veya ölçümleme hizmeti eklenirse bu bölüm
              güncellenecek ve gerekiyorsa çerez onayı alınacaktır.
            </p>

            <h2>Çerezleri nasıl yönetirsiniz?</h2>
            <p>
              Çerezleri tarayıcınızın ayarlarından görüntüleyebilir, silebilir veya sitelerin çerez
              yazmasını engelleyebilirsiniz. İlgili bölüm çoğu tarayıcıda “Gizlilik ve güvenlik”
              başlığı altındadır.
            </p>
            <ul>
              <li>Oturum çerezini silerseniz hesabınızdan çıkış yapmış olursunuz.</li>
              <li>Sepet çerezini silerseniz sepetinizdeki ürünler kaybolur.</li>
              <li>
                Zorunlu çerezleri tümüyle engellerseniz giriş yapma ve sipariş verme adımları
                çalışmaz.
              </li>
            </ul>

            <h2>İlgili metinler</h2>
            <p>
              Toplanan verilerin işlenme çerçevesi <Link href="/gizlilik">Gizlilik Politikası</Link>{' '}
              sayfasında, kişisel verilere ilişkin aydınlatma ise{' '}
              <Link href="/kvkk">KVKK Aydınlatma Metni</Link> sayfasında yer alıyor. Sorularınız
              için <Link href="/iletisim">iletişim sayfasını</Link> kullanabilirsiniz.
            </p>

            <h2>Bu metindeki değişiklikler</h2>
            <p>
              Sitede kullanılan çerezler değiştiğinde bu sayfa da güncellenir. Metin yürürlüğe
              girdiğinde bu bölüme yürürlük tarihi eklenecektir.
            </p>
          </div>
        </div>
      </Section>
    </>
  );
}
