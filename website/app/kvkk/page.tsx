import type { Metadata } from 'next';
import Link from 'next/link';
import { TriangleAlert } from 'lucide-react';
import { JsonLd } from '@/components/json-ld';
import { PageHero, type Crumb } from '@/components/site/page-hero';
import { Section } from '@/components/site/section';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import {
  LegalIdentityTable,
  PendingLegalNotice,
  identityFields,
  pendingLegalFields,
} from '@/components/site/legal-identity';
import { fetchSiteContent } from '@/lib/api/site-content';
import { breadcrumbJsonLd, pageMetadata } from '@/lib/seo';

const TITLE = 'KVKK Aydınlatma Metni';
const DESCRIPTION =
  'Kişisel verilerin işlenmesine ilişkin aydınlatma metni: hangi veriler, hangi amaçla işlenir ve haklarınız.';

const CRUMBS: readonly Crumb[] = [{ href: '/kvkk', label: TITLE }];

export async function generateMetadata(): Promise<Metadata> {
  const { brand } = await fetchSiteContent();

  return pageMetadata({
    title: TITLE,
    description: DESCRIPTION,
    path: '/kvkk',
    brandName: brand.name,
  });
}

/**
 * KVKK aydınlatma metni.
 *
 * Düzeni `/gizlilik`, `/cerez-politikasi` ve `/mesafeli-satis` ile AYNI:
 * `PageHero` + `Section` + `bld-prose`. Önceki sürüm kendi başlık ve gövde
 * sınıflarını taşıyordu (`text-3xl font-bold`, gövde `text-sm`) ve aynı
 * menüden açılan dört yasal sayfa iki farklı tipografiyle çiziliyordu.
 *
 * Veri sorumlusunun kimlik bilgileri hâlâ işletmeden alınmadı; metnin
 * başındaki uyarı bunu açıkça söylüyor. Uydurma bilgi yazılmıyor.
 */
export default async function KvkkPage() {
  const { brand, contact, legal } = await fetchSiteContent();
  const controller = identityFields(contact, legal);
  const pending = pendingLegalFields(controller, legal);

  return (
    <>
      <JsonLd data={breadcrumbJsonLd(CRUMBS)} />

      <PageHero
        crumbs={CRUMBS}
        title={TITLE}
        description="6698 sayılı Kişisel Verilerin Korunması Kanunu kapsamında hazırlanmıştır."
      />

      <Section>
        <div className="max-w-3xl">
          {/*
            Sabit "kimlik bilgileri eklenecek" uyarısı KALDIRILDI: bilgiler artık
            `/site-content`in `legal` bloğundan geliyor ve aşağıdaki tabloda
            gerçekten görünüyor. Uyarı yalnızca hukuk danışmanı onayına dair
            olan; eksik alan varsa onu `PendingLegalNotice` kendi listesiyle
            söylüyor ve liste boşaldığında kendiliğinden kayboluyor.
          */}
          <Alert variant="warning">
            <TriangleAlert strokeWidth={1.75} aria-hidden="true" />
            <AlertTitle>Hukuk danışmanı onayı gerekir</AlertTitle>
            <AlertDescription>
              <p>
                Bu metin sitenin gerçekte hangi verileri, hangi amaçla işlediğini anlatmak için
                hazırlandı; hukuki danışmanlık değildir. Yayına çıkmadan önce bir hukuk danışmanı
                tarafından incelenmesi gerekir.
              </p>
            </AlertDescription>
          </Alert>

          <PendingLegalNotice items={pending} />

          <div className="bld-prose mt-10">
            <h2>1. Veri sorumlusu</h2>
            <p>
              6698 sayılı Kanun uyarınca kişisel verileriniz, aşağıda kimlik bilgileri yer alan
              işletme tarafından veri sorumlusu sıfatıyla işlenmektedir.
            </p>
          </div>

          <LegalIdentityTable fields={controller} />

          <div className="bld-prose mt-10">
            <h2>2. İşlenen kişisel veriler</h2>
            <p>
              Sipariş sürecini yürütebilmek için şu veriler işlenir: ad, soyad, e-posta adresi, cep
              telefonu numarası, teslimat adresi ve adres notu, sipariş içeriği ile sipariş notu,
              siparişin hangi hizmet günü için verildiği, ödeme yöntemi ve ödeme durumu, sipariş
              tarih-saat kayıtları.
            </p>

            <h2>3. İşleme amaçları</h2>
            <ul>
              <li>Siparişin alınması, hazırlanması ve teslim edilmesi</li>
              <li>Sipariş durumunun tarafınıza bildirilmesi ve takip ekranının sunulması</li>
              <li>Ödeme ve tahsilat süreçlerinin yürütülmesi</li>
              <li>Yasal saklama ve belge düzenleme yükümlülüklerinin yerine getirilmesi</li>
              <li>Talep ve şikâyetlerin karşılanması</li>
            </ul>

            <h2>4. Hukuki sebep</h2>
            <p>
              Veriler; sözleşmenin kurulması ve ifası, hukuki yükümlülüğün yerine getirilmesi ve
              meşru menfaat hukuki sebeplerine dayanılarak, kayıt sırasında verdiğiniz açık onay ile
              işlenir.
            </p>

            <h2>5. Aktarım</h2>
            <p>
              Kişisel verileriniz; teslimatın yapılabilmesi için görevli kuryeye teslimat adresi ile
              sınırlı olarak, ödeme işlemleri için ödeme hizmeti sağlayıcısına ve yasal talep
              hâlinde yetkili kamu kurumlarına aktarılabilir. Mutfak ekranına düşen sipariş kaydında
              fiyat ve iletişim bilgisi bulunmaz; adres yalnızca müşteri fişinde yer alır.
            </p>

            <h2>6. Saklama süresi</h2>
            <p>
              Veriler, ilgili mevzuatta öngörülen zamanaşımı ve saklama süreleri boyunca tutulur;
              süre dolduğunda silinir, yok edilir veya anonim hâle getirilir.
            </p>

            <h2>7. Haklarınız</h2>
            <p>
              Kanunun 11. maddesi uyarınca; verilerinizin işlenip işlenmediğini öğrenme, bilgi talep
              etme, düzeltilmesini veya silinmesini isteme, işlemeye itiraz etme ve zarara uğramanız
              hâlinde giderim talep etme haklarına sahipsiniz. Taleplerinizi{' '}
              <Link href="/iletisim">iletişim</Link> sayfamızdaki kanallardan iletebilirsiniz;
              başvurunuz en geç 30 gün içinde sonuçlandırılır.
            </p>

            <p>
              {brand.name} tarafından toplanan verilerin ayrıntısı için{' '}
              <Link href="/gizlilik">Gizlilik Politikası</Link>, sitede kullanılan çerezler için{' '}
              <Link href="/cerez-politikasi">Çerez Politikası</Link> sayfalarına bakabilirsiniz.
            </p>
          </div>
        </div>
      </Section>
    </>
  );
}
