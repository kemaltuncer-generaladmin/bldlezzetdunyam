import { Info } from 'lucide-react';
import { JsonLd } from '@/components/json-ld';
import { SectorCard } from '@/components/site/cards';
import { CtaBand } from '@/components/site/cta-band';
import { PageHero } from '@/components/site/page-hero';
import { Section, SectionHeading } from '@/components/site/section';
import { fetchSiteContent } from '@/lib/api/site-content';
import { PHOTO, sectorImage } from '@/lib/site-images';
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

export async function generateMetadata() {
  const { brand, sectors } = await fetchSiteContent();

  return pageMetadata({
    title: 'Çalıştığımız Alanlar',
    description: `${sectors.map((sector) => sector.title).join(', ')}: her alanın yemek hizmetinden beklentisi ve bizim verdiğimiz karşılık.`,
    path: '/calistigimiz-alanlar',
    brandName: brand.name,
  });
}

export default async function CalistigimizAlanlarPage() {
  const { sectors } = await fetchSiteContent();

  return (
    <>
      <JsonLd data={breadcrumbJsonLd(CRUMBS)} />

      <PageHero
        crumbs={CRUMBS}
        eyebrow="Çalıştığımız alanlar"
        title="Her yerin kendi kısıtı var"
        description="Vardiya zilinde yemek isteyen fabrikayla alerjen listesi takip eden okul aynı şeyi istemiyor. Hizmeti oranın kısıtına göre kuruyoruz."
        image={PHOTO.sofraMezze.src}
      />

      <Section aria-labelledby="sektorler-baslik">
        <SectionHeading
          id="sektorler-baslik"
          eyebrow="Sektörler"
          title="Kimlere gidiyoruz"
          description="Her kartta önce o alanın beklentisi, sonra bizim karşılığımız."
        />

        <ul className="mt-10 grid bld-reveal gap-6 md:grid-cols-2 lg:grid-cols-3">
          {sectors.map((sector) => (
            // `grid`: kart, satırdaki en uzun kartla aynı yüksekliğe uzasın diye.
            <li key={sector.slug} className="grid">
              <SectorCard
                icon={sector.icon}
                title={sector.title}
                need={sector.need}
                answer={sector.answer}
                href={`/hizmetler/${sector.serviceSlug}`}
                image={sectorImage(sector.slug)}
              />
            </li>
          ))}
        </ul>
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
              Bir kurumun adını izni olmadan yayımlamak doğru değil. İzin alınmış olsa bile
              doğrulanmadan sıralanan logolar sayfayı süslemekten başka işe yaramıyor.
            </p>
            <p className="mt-4 text-base/7 opacity-85">
              Onun yerine nerelerde çalıştığımızı yazıyoruz. Benzer ölçekte bir örnek görmek
              isterseniz görüşmede anlatırız.
            </p>
          </div>
        </div>
      </Section>

      <CtaBand />
    </>
  );
}
