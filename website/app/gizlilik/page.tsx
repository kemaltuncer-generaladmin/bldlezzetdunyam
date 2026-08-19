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

const TITLE = 'Gizlilik Politikası';
const DESCRIPTION =
  'Bu sitede hangi kişisel verilerin toplandığı, hangi amaçla işlendiği, kimlerle paylaşıldığı ve kullanıcı haklarının çerçevesi.';

const CRUMBS: readonly Crumb[] = [{ href: '/gizlilik', label: TITLE }];

export async function generateMetadata(): Promise<Metadata> {
  const { brand } = await fetchSiteContent();

  return pageMetadata({
    title: TITLE,
    description: DESCRIPTION,
    path: '/gizlilik',
    brandName: brand.name,
  });
}

export default async function GizlilikPage() {
  const { brand, contact, legal } = await fetchSiteContent();
  const controller = identityFields(contact, legal);
  const pending = pendingLegalFields(controller, legal);

  return (
    <>
      <JsonLd data={breadcrumbJsonLd(CRUMBS)} />

      <PageHero crumbs={CRUMBS} title={TITLE} description={DESCRIPTION} />

      <Section>
        <div className="max-w-3xl">
          {/*
            Bu metin bir taslaktır ve hukuki görüş yerine geçmez. Uyarı sayfanın
            en üstünde duruyor: aşağı kaydırmadan görülmezse işlevi kalmıyor.
            (`LegalNotice` bileşeni yerine `Alert variant="warning"` kullanılıyor:
            eski bileşenin renkleri açık temaya sabitlenmişti ve dört yasal
            metnin ikisi onu, ikisi Alert'i kullanıyordu. Bileşen B-19'da
            kaldırıldı, dördü de bu kalıba geçti.)
          */}
          <Alert variant="warning">
            <TriangleAlert strokeWidth={1.75} aria-hidden="true" />
            <AlertTitle>Bu metin taslaktır, hukuk danışmanı onayı gerekir</AlertTitle>
            <AlertDescription>
              Aşağıdaki içerik sitenin gerçekte ne yaptığını anlatmak için hazırlandı; hukuki
              danışmanlık değildir ve bağlayıcı bir taahhüt oluşturmaz. Yayına çıkmadan önce metnin
              bir hukuk danışmanı tarafından incelenip onaylanması gerekir.
            </AlertDescription>
          </Alert>

          <PendingLegalNotice items={pending} />

          <div className="bld-prose mt-10">
            <h2>1. Bu politika neyi kapsar?</h2>
            <p>
              Bu metin, {brand.name} web sitesi üzerinden toplanan verilerin nasıl işlendiğini
              anlatır. Kişisel verilerin korunmasına ilişkin ayrıntılı aydınlatma{' '}
              <Link href="/kvkk">KVKK Aydınlatma Metni</Link> sayfasında, sitede kullanılan çerezler
              ise <Link href="/cerez-politikasi">Çerez Politikası</Link> sayfasında yer alıyor.
            </p>
            <p>
              Politika yalnızca bu siteyi kapsar. Sitede yer alan bağlantılar üzerinden gidilen
              üçüncü taraf hizmetlerin kendi gizlilik uygulamaları geçerlidir.
            </p>

            <h2>2. Veri sorumlusu</h2>
            <p>
              Verilerin işlenmesinden sorumlu işletmenin kimlik ve iletişim bilgileri aşağıdadır.
              Henüz girilmemiş alanlar açıkça işaretlenmiştir; bu alanlar tamamlanmadan metin yayına
              alınmamalıdır.
            </p>
          </div>

          <LegalIdentityTable fields={controller} />

          <div className="bld-prose">
            <h2>3. Hangi veriler toplanıyor?</h2>
            <p>
              Site, ziyaret sırasında kendiliğinden profil oluşturmaz. Veriler yalnızca aşağıdaki
              durumlarda toplanır:
            </p>
            <ul>
              <li>
                <strong>Hesap oluşturma ve giriş:</strong> ad, soyad, e-posta adresi ve telefon
                numarası.
              </li>
              <li>
                <strong>Sipariş verme:</strong> teslimat adresi ve adres notu, sipariş içeriği,
                sipariş notu, teslimat türü, ödeme yöntemi ve ödeme durumu, sipariş tarih-saat
                kayıtları.
              </li>
              <li>
                <strong>Teklif veya iletişim formu:</strong> forma yazdığınız iletişim bilgileri ile
                talebin içeriği (örneğin kişi sayısı ve hizmet türü).
              </li>
              <li>
                <strong>Sitenin çalışması için gereken çerezler:</strong> oturum ve sepet bilgisi.
                Ayrıntısı <Link href="/cerez-politikasi">Çerez Politikası</Link> sayfasındadır.
              </li>
              <li>
                <strong>Sunucu kayıtları:</strong> barındırma altyapısı düzeyinde istek kayıtları
                (tarih-saat, IP adresi gibi) oluşabilir. Bu kayıtların saklama süresi yukarıdaki
                tamamlanacak bilgiler listesindedir.
              </li>
            </ul>
            <p>
              Kart bilgileri site tarafında saklanmaz. Ödeme adımı, ödeme hizmeti sağlayıcısının
              altyapısı üzerinden yürütülür.
            </p>

            <h2>4. Veriler hangi amaçlarla işleniyor?</h2>
            <ul>
              <li>Siparişin alınması, hazırlanması, teslim edilmesi ve takip edilebilmesi</li>
              <li>Hesabınızın oluşturulması ve oturumun sürdürülmesi</li>
              <li>Teklif ve bilgi taleplerinin yanıtlanması</li>
              <li>Ödeme ve tahsilat süreçlerinin yürütülmesi</li>
              <li>Talep, itiraz ve şikâyetlerin karşılanması</li>
              <li>Mevzuattan doğan belge düzenleme ve saklama yükümlülüklerinin karşılanması</li>
            </ul>
            <p>
              Verileriniz, izniniz olmadan pazarlama amacıyla kullanılmaz ve üçüncü taraflara
              pazarlama amacıyla aktarılmaz.
            </p>

            <h2>5. Veriler kimlerle paylaşılıyor?</h2>
            <p>Paylaşım, hizmetin yürütülmesi için gereken en dar çerçevede yapılır:</p>
            <ul>
              <li>
                Teslimatı yapan görevliyle, teslimat adresi ve sipariş içeriğiyle sınırlı olarak
              </li>
              <li>Ödeme hizmeti sağlayıcısıyla, ödeme işleminin gerçekleştirilmesi için</li>
              <li>Barındırma sağlayıcısıyla, verilerin sunucu üzerinde tutulması kapsamında</li>
              <li>Yetkili kamu kurumlarıyla, yasal bir talep olduğunda</li>
            </ul>
            <p>
              Mutfak ekranına düşen sipariş kaydında fiyat ve müşteri iletişim bilgisi bulunmaz;
              adres yalnızca teslimat fişinde yer alır.
            </p>

            <h2>6. Veriler ne kadar süre saklanıyor?</h2>
            <p>
              Sipariş ve fatura kayıtları, mevzuatın öngördüğü saklama ve zamanaşımı süreleri
              boyunca tutulur. Hesabınızı sildirdiğinizde, yasal saklama yükümlülüğü kapsamında
              tutulması gerekenler dışındaki veriler silinir veya anonim hâle getirilir. Uygulanacak
              somut süreler, hukuki inceleme sonrasında bu bölüme eklenecektir.
            </p>
            <p>
              Çerezlerin süreleri ayrıdır ve <Link href="/cerez-politikasi">Çerez Politikası</Link>{' '}
              sayfasındaki tabloda tek tek belirtilmiştir.
            </p>

            <h2>7. Güvenlik</h2>
            <p>
              Sitenin veri işleme biçiminde, gereksiz veri tutmamayı esas alan birkaç somut tercih
              var:
            </p>
            <ul>
              <li>
                Oturum bilgisi tarayıcı tarafındaki koda kapalı (
                <code className="rounded-xs bg-muted px-1 py-0.5 text-body-sm">httpOnly</code>) bir
                çerezde tutulur; sayfadaki JavaScript bu değeri okuyamaz.
              </li>
              <li>
                Sepet çerezi ürün adı ve fiyat taşımaz, yalnızca ürün kimliği ve adet tutar; tutar
                her istekte sunucuda yeniden hesaplanır.
              </li>
              <li>Ödeme kartı bilgisi sitede hiçbir aşamada saklanmaz.</li>
            </ul>
            <p>
              Bu tercihler makul bir teknik zemin sağlar; hiçbir sistemin mutlak güvenlik
              sunamayacağı ise açıktır. Yayın öncesi kontrol listesinde, sitenin tüm trafiğinin
              şifreli bağlantı üzerinden sunulduğunun doğrulanması da yer alır.
            </p>

            <h2>8. Haklarınız</h2>
            <p>
              Kişisel verilerinize ilişkin olarak; verilerin işlenip işlenmediğini öğrenme, bilgi
              talep etme, düzeltilmesini veya silinmesini isteme, işlemeye itiraz etme ve aktarım
              yapılan tarafları öğrenme haklarınız bulunur. Bu hakların yasal dayanağı ve kullanım
              usulü <Link href="/kvkk">KVKK Aydınlatma Metni</Link> sayfasında açıklanmıştır.
            </p>

            <h2>9. Başvuru</h2>
            <p>
              Bu metne ve verilerinize ilişkin taleplerinizi{' '}
              <Link href="/iletisim">iletişim sayfasındaki</Link> kanallardan iletebilirsiniz.
            </p>
          </div>

          {(contact.email !== null || contact.phone !== null) && (
            <ul className="mt-4 space-y-1 text-body-sm">
              {contact.email && (
                <li>
                  E-posta:{' '}
                  <a
                    className="text-primary underline underline-offset-4"
                    href={contact.email.href}
                  >
                    {contact.email.display}
                  </a>
                </li>
              )}
              {contact.phone && (
                <li>
                  Telefon:{' '}
                  <a
                    className="text-primary underline underline-offset-4"
                    href={contact.phone.href}
                  >
                    {contact.phone.display}
                  </a>
                </li>
              )}
            </ul>
          )}

          <div className="bld-prose">
            <h2>10. Bu metindeki değişiklikler</h2>
            <p>
              Sitenin işleyişi değiştiğinde bu metin de güncellenir. Güncel sürüm her zaman bu
              adreste yayımlanır; metin yürürlüğe girdiğinde bu bölüme yürürlük tarihi eklenecektir.
            </p>
          </div>
        </div>
      </Section>
    </>
  );
}
