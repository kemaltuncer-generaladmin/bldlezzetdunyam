import type { Metadata } from 'next';
import Link from 'next/link';
import { TriangleAlert } from 'lucide-react';
import { JsonLd } from '@/components/json-ld';
import { PageHero, type Crumb } from '@/components/site/page-hero';
import { Section } from '@/components/site/section';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { fetchSiteContent } from '@/lib/api/site-content';
import { breadcrumbJsonLd, pageMetadata } from '@/lib/seo';

const TITLE = 'Mesafeli Satış Sözleşmesi';
const DESCRIPTION =
  'Benim Lezzet Dünyam üzerinden verilen siparişlere uygulanan mesafeli satış sözleşmesi koşulları.';

const CRUMBS: readonly Crumb[] = [{ href: '/mesafeli-satis', label: TITLE }];

export async function generateMetadata(): Promise<Metadata> {
  const { brand } = await fetchSiteContent();

  return pageMetadata({
    title: TITLE,
    description: DESCRIPTION,
    path: '/mesafeli-satis',
    brandName: brand.name,
  });
}

/**
 * Mesafeli satış sözleşmesi.
 *
 * ## Düzen neden `/gizlilik` ve `/cerez-politikasi` ile aynı?
 *
 * Dört yasal metnin ikisi `PageHero` + `Section` + `bld-prose` kalıbını
 * kullanıyordu, ikisi (bu sayfa ve `/kvkk`) kendi başlık ve gövde sınıflarını
 * taşıyordu — sabit `text-neutral-900`, `text-3xl font-bold`, gövde `text-sm`.
 * Aynı menüden açılan dört sayfa iki farklı tipografiyle çiziliyordu. Bu
 * sürümde dördü de tek kalıpta.
 *
 * ## Ticari kimlik bilgileri
 *
 * Unvan, merkez adresi, vergi dairesi/numarası, MERSİS ve KEP hâlâ
 * işletmeden alınmadı. Uydurulmuyor: metnin başındaki uyarı eksikliği açıkça
 * söylüyor ve bilgiler girilene kadar sayfa yayına çıkmamalı.
 */
export default async function MesafeliSatisPage() {
  const { brand } = await fetchSiteContent();

  return (
    <>
      <JsonLd data={breadcrumbJsonLd(CRUMBS)} />

      <PageHero
        crumbs={CRUMBS}
        title={TITLE}
        description="6502 sayılı Tüketicinin Korunması Hakkında Kanun ve Mesafeli Sözleşmeler Yönetmeliği kapsamındadır."
      />

      <Section>
        <div className="max-w-3xl">
          {/*
            Uyarı sayfanın EN ÜSTÜNDE: aşağı kaydırmadan görülmezse işlevi
            kalmıyor. `variant="warning"` tint + metin adımını birlikte
            getiriyor; kutunun rengi elle yazılmıyor.
          */}
          <Alert variant="warning">
            <TriangleAlert strokeWidth={1.75} aria-hidden="true" />
            <AlertTitle>Yayın öncesi tamamlanacak</AlertTitle>
            <AlertDescription>
              <p>
                İşletmenin ticari unvanı, merkez adresi, vergi dairesi ve numarası, MERSİS numarası
                ile KEP adresi bu metne eklenecektir. Bilgiler işletmeden alınmadan yayına çıkılmaz.
                Metin ayrıca bir hukuk danışmanı tarafından incelenmelidir.
              </p>
            </AlertDescription>
          </Alert>

          <div className="bld-prose mt-10">
            <h2>1. Taraflar ve konu</h2>
            <p>
              Bu sözleşme; satıcı sıfatıyla {brand.name} ile bu site üzerinden sipariş veren alıcı
              arasında, siparişe konu yiyecek ürünlerinin satışı ve teslimi hakkındadır.
            </p>

            <h2>2. Sipariş ve fiyat</h2>
            <p>
              Sipariş, o hizmet günü için yayınlanan günün menüsü üzerinden verilir: menünün tamamı
              paket fiyatıyla ya da menüdeki yemekler tek tek alınabilir. Fiyatlar sipariş anında
              sitede gösterilen tutarlardır ve KDV dahildir. Sipariş toplamı her durumda sunucuda
              yeniden hesaplanır; ödenecek tutar sipariş onayında gösterilen tutardır. Adrese teslim
              siparişlerde varsa teslimat ücreti toplama eklenir; gel-al siparişlerde teslimat
              ücreti alınmaz.
            </p>

            <h2>3. Teslimat</h2>
            <p>
              Teslimat, sipariş sırasında belirtilen adrese ve seçilen zaman aralığında yapılır.
              Gel-al seçilmişse ürünler işletme adresinden teslim alınır. Sipariş, sepetin bağlı
              olduğu hizmet gününde teslim edilir; o gün için günlük son sipariş saati geçtikten
              sonra sipariş alınmaz.
            </p>

            <h2>4. Ödeme</h2>
            <p>
              Ödeme, sipariş ekranında gösterilen yöntemlerle yapılır: kapıda ödeme veya online kart
              ile ödeme. Hangi yöntemlerin açık olduğu sipariş ekranında görünür; kapalı bir yöntem
              seçilemez.
            </p>

            <h2>5. Cayma hakkı</h2>
            <p>
              Mesafeli Sözleşmeler Yönetmeliği&apos;nin 15. maddesi uyarınca çabuk bozulabilen veya
              son kullanma tarihi geçebilecek ürünler ile hazırlanması sipariş üzerine başlayan
              yiyecek teslimlerinde cayma hakkı kullanılamaz. Hazırlığa başlanmadan önce, sipariş
              &quot;Alındı&quot; veya &quot;Onaylandı&quot; durumundayken siparişinizi{' '}
              <Link href="/siparislerim">siparişlerim</Link> ekranından iptal edebilirsiniz.
            </p>

            <h2>6. Uyuşmazlık</h2>
            <p>
              Şikâyet ve itirazlarda, ilgili mevzuatta belirlenen parasal sınırlar dâhilinde
              alıcının yerleşim yerindeki Tüketici Hakem Heyetleri ile Tüketici Mahkemeleri
              yetkilidir.
            </p>
          </div>
        </div>
      </Section>
    </>
  );
}
