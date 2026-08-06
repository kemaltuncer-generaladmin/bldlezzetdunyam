import { Info } from 'lucide-react';
import { JsonLd } from '@/components/json-ld';
import { SectorCard } from '@/components/site/cards';
import { CtaBand } from '@/components/site/cta-band';
import { PageHero } from '@/components/site/page-hero';
import { Section, SectionHeading } from '@/components/site/section';
import { SECTORS } from '@/content/sectors';
import { breadcrumbJsonLd, pageMetadata } from '@/lib/seo';
import type { Crumb } from '@/components/site/page-hero';

/**
 * Çalıştığımız alanlar.
 *
 * Sayfa sektörleri anlatır, referans firma değil: repoda doğrulanmış müşteri
 * bilgisi yok ve izinsiz logo yayımlamak hem yanlış hem hukuki sorumluluk.
 * Bu tercih gizlenmiyor, ayrı bir bantta açıkça yazılıyor.
 */

const CRUMBS: readonly Crumb[] = [{ href: '/calistigimiz-alanlar', label: 'Çalıştığımız Alanlar' }];

export const metadata = pageMetadata({
  title: 'Çalıştığımız Alanlar',
  description:
    'Sanayi, eğitim, sağlık, kamu, ofis, şantiye ve organizasyon: her alanın yemek hizmetinden beklentisi ve bizim verdiğimiz karşılık.',
  path: '/calistigimiz-alanlar',
});

export default function CalistigimizAlanlarPage() {
  return (
    <>
      <JsonLd data={breadcrumbJsonLd(CRUMBS)} />

      <PageHero
        crumbs={CRUMBS}
        eyebrow="Çalıştığımız Alanlar"
        title="Her alanın kendi kısıtı var"
        description="Vardiya saatine kilitlenen bir fabrikayla, alerjen listesi takip eden bir okulun ihtiyacı aynı değil. Hizmeti alanın kısıtına göre kuruyoruz."
      />

      <Section aria-labelledby="giris-baslik">
        <SectionHeading
          id="giris-baslik"
          eyebrow="Nasıl okumalı"
          title="Önce beklenti, sonra karşılığı"
          description="Aşağıdaki her kart iki bölümden oluşuyor: o alanın yemek hizmetinden asıl beklediği şey ve bizim buna verdiğimiz karşılık. Kendinize en yakın başlıktan ilgili hizmet sayfasına geçebilirsiniz."
        />
      </Section>

      {/* Referans bölümünün yerine geçen dürüstlük notu; koyu bant, sayfada
          atlanacak bir dipnot gibi görünmesin diye. */}
      <Section tone="olive" aria-labelledby="referans-notu-baslik">
        <div className="flex max-w-3xl bld-reveal gap-5">
          <Info aria-hidden="true" className="mt-1 size-6 shrink-0" />
          <div>
            <h2
              id="referans-notu-baslik"
              className="font-display text-2xl font-semibold tracking-tight sm:text-3xl"
            >
              Neden referans logosu yok?
            </h2>
            <p className="mt-4 text-base/7 opacity-85">
              Bu sayfada müşteri logosu veya firma adı göstermiyoruz. Bir kurumun adını izni olmadan
              yayımlamak doğru değil; izinli olanları da doğrulamadan listelemek sayfayı süslemekten
              başka işe yaramaz.
            </p>
            <p className="mt-4 text-base/7 opacity-85">
              Bunun yerine hangi alanlarda çalıştığımızı ve o alanın neye ihtiyaç duyduğunu
              yazıyoruz. Benzer ölçekte bir çalışma örneği görmek isterseniz görüşmede
              paylaşabiliriz.
            </p>
          </div>
        </div>
      </Section>

      <Section tone="muted" aria-labelledby="sektorler-baslik">
        <SectionHeading
          id="sektorler-baslik"
          eyebrow="Sektörler"
          title="Hizmet verdiğimiz alanlar"
        />

        <ul className="mt-10 grid bld-reveal gap-6 md:grid-cols-2 lg:grid-cols-3">
          {SECTORS.map((sector) => (
            // `grid`: kart, satırdaki en uzun kartla aynı yüksekliğe uzasın diye.
            <li key={sector.slug} className="grid">
              <SectorCard
                icon={sector.icon}
                title={sector.title}
                need={sector.need}
                answer={sector.answer}
                href={`/hizmetler/${sector.serviceSlug}`}
              />
            </li>
          ))}
        </ul>
      </Section>

      <CtaBand />
    </>
  );
}
