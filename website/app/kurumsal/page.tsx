import { Compass, Target } from 'lucide-react';
import { JsonLd } from '@/components/json-ld';
import { FeatureItem, ProcessStepCard } from '@/components/site/cards';
import { CtaBand } from '@/components/site/cta-band';
import { PageHero } from '@/components/site/page-hero';
import { Section, SectionHeading } from '@/components/site/section';
import { fetchSiteContent } from '@/lib/api/site-content';
import { breadcrumbJsonLd, pageMetadata } from '@/lib/seo';
import type { Crumb } from '@/components/site/page-hero';

/**
 * Kurumsal sayfası.
 *
 * Tarihçe bölümü bilerek yok: kuruluş yılı, ölçek ve dönüm noktaları için
 * doğrulanmış bir kaynak bulunmuyor. Anlatım rakam yerine çalışma biçimi
 * üzerinden kuruluyor — içeriğin tamamı admin panelinden gelir, API kapalıysa
 * `content/company.ts` yedeğinden.
 */

const CRUMBS: readonly Crumb[] = [{ href: '/kurumsal', label: 'Kurumsal' }];

export async function generateMetadata() {
  const { brand } = await fetchSiteContent();

  return pageMetadata({
    title: 'Kurumsal',
    description: `${brand.name} nasıl çalışır: misyonu, değerleri, ilk görüşmeden düzenli hizmete uzanan süreci ve catering yaklaşımı.`,
    path: '/kurumsal',
    brandName: brand.name,
  });
}

export default async function KurumsalPage() {
  const { brand, company } = await fetchSiteContent();

  return (
    <>
      <JsonLd data={breadcrumbJsonLd(CRUMBS)} />

      <PageHero crumbs={CRUMBS} eyebrow="Kurumsal" title="Hakkımızda" description={brand.tagline} />

      <Section aria-labelledby="hakkimizda-baslik">
        <SectionHeading
          id="hakkimizda-baslik"
          eyebrow="Ne yapıyoruz"
          title="Kalabalık sofraların işletmesi"
          description={brand.description}
        />
        <div className="bld-prose mt-8 max-w-2xl bld-reveal">
          <p>
            Bu sayfa nasıl çalıştığımızı anlatıyor: hangi adımlarla ilerlediğimizi, neye göre karar
            verdiğimizi ve bir kurumun bizden ne bekleyebileceğini.
          </p>
        </div>
      </Section>

      {/* Misyon ve vizyon koyu bantta: sayfanın en çok alıntılanan iki cümlesi,
          zemin değişimiyle görsel olarak da ayrılıyor. */}
      <Section tone="olive" aria-labelledby="misyon-vizyon-baslik">
        <h2
          id="misyon-vizyon-baslik"
          className="max-w-2xl font-display text-3xl font-semibold tracking-tight sm:text-4xl"
        >
          Ne için çalışıyoruz
        </h2>

        <div className="mt-10 grid bld-reveal gap-10 md:grid-cols-2 md:gap-14">
          <div>
            <span
              aria-hidden="true"
              className="grid size-11 place-items-center rounded-xl bg-white/10 text-white"
            >
              <Target className="size-5" />
            </span>
            <h3 className="mt-4 font-display text-xl font-semibold tracking-tight">Misyonumuz</h3>
            <p className="mt-3 text-base/7 opacity-85">{company.mission}</p>
          </div>

          <div>
            <span
              aria-hidden="true"
              className="grid size-11 place-items-center rounded-xl bg-white/10 text-white"
            >
              <Compass className="size-5" />
            </span>
            <h3 className="mt-4 font-display text-xl font-semibold tracking-tight">Vizyonumuz</h3>
            <p className="mt-3 text-base/7 opacity-85">{company.vision}</p>
          </div>
        </div>
      </Section>

      <Section aria-labelledby="degerler-baslik">
        <SectionHeading
          id="degerler-baslik"
          eyebrow="Değerlerimiz"
          title="Tartışmaya açmadığımız dört başlık"
          description="Her biri günlük işleyişte karşılığı olan, işler sıkıştığında da geçerli kalan ilkeler."
        />

        <ul className="mt-10 grid bld-reveal gap-6 sm:grid-cols-2">
          {company.values.map((value) => (
            <li
              key={value.title}
              className="rounded-2xl border border-l-4 border-l-primary bg-card p-6 text-card-foreground"
            >
              <h3 className="font-display text-lg font-semibold tracking-tight">{value.title}</h3>
              <p className="mt-2 text-sm/6 text-muted-foreground">{value.body}</p>
            </li>
          ))}
        </ul>
      </Section>

      <Section tone="muted" aria-labelledby="surec-baslik">
        <SectionHeading
          id="surec-baslik"
          eyebrow="Üretim ve hizmet anlayışı"
          title="İlk görüşmeden düzenli hizmete"
          description="Süreç her kurumda aynı sırayla ilerler; hangi aşamada olduğunuzu her zaman bilirsiniz."
        />

        <ol className="mt-10">
          {company.processSteps.map((step, index) => (
            <ProcessStepCard
              key={step.title}
              index={index + 1}
              icon={step.icon}
              title={step.title}
              body={step.body}
            />
          ))}
        </ol>
      </Section>

      <Section tone="warm" aria-labelledby="sirket-ailesi-baslik">
        <div className="max-w-3xl bld-reveal">
          <h2
            id="sirket-ailesi-baslik"
            className="font-display text-3xl font-semibold tracking-tight sm:text-4xl"
          >
            Şirket ailesi
          </h2>
          <p className="mt-5 text-base/7 opacity-85">{company.groupRelation}</p>
        </div>
      </Section>

      <Section aria-labelledby="neden-bld-baslik">
        <SectionHeading
          id="neden-bld-baslik"
          eyebrow={`Neden ${brand.shortName}`}
          title="Farkı yaratan, vaat değil çalışma biçimi"
        />

        <div className="mt-10 grid bld-reveal gap-8 sm:grid-cols-2 lg:grid-cols-4">
          {company.differentiators.map((item) => (
            <FeatureItem key={item.title} icon={item.icon} title={item.title} body={item.body} />
          ))}
        </div>
      </Section>

      <CtaBand />
    </>
  );
}
