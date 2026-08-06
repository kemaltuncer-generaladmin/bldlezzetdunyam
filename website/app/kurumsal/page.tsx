import { Compass, Target } from 'lucide-react';
import { JsonLd } from '@/components/json-ld';
import { FeatureItem, ProcessStepCard } from '@/components/site/cards';
import { CtaBand } from '@/components/site/cta-band';
import { PageHero } from '@/components/site/page-hero';
import { Section, SectionHeading } from '@/components/site/section';
import {
  DIFFERENTIATORS,
  GROUP_RELATION,
  MISSION,
  PROCESS_STEPS,
  VALUES,
  VISION,
} from '@/content/company';
import { BRAND } from '@/content/site';
import { breadcrumbJsonLd, pageMetadata } from '@/lib/seo';
import type { Crumb } from '@/components/site/page-hero';

/**
 * Kurumsal sayfası.
 *
 * Tarihçe bölümü bilerek yok: kuruluş yılı, ölçek ve dönüm noktaları için
 * repoda doğrulanmış bir kaynak bulunmuyor. Anlatım rakam yerine çalışma
 * biçimi üzerinden kuruluyor — içeriğin tamamı `content/company.ts`'ten gelir.
 */

const CRUMBS: readonly Crumb[] = [{ href: '/kurumsal', label: 'Kurumsal' }];

export const metadata = pageMetadata({
  title: 'Kurumsal',
  description:
    'Benim Lezzet Dünyam nasıl çalışır: misyonu, değerleri, ilk görüşmeden düzenli hizmete uzanan süreci ve catering yaklaşımı.',
  path: '/kurumsal',
});

export default function KurumsalPage() {
  return (
    <>
      <JsonLd data={breadcrumbJsonLd(CRUMBS)} />

      <PageHero crumbs={CRUMBS} eyebrow="Kurumsal" title="Hakkımızda" description={BRAND.tagline} />

      <Section aria-labelledby="hakkimizda-baslik">
        <SectionHeading
          id="hakkimizda-baslik"
          eyebrow="Ne yapıyoruz"
          title="Kalabalık sofraların işletmesi"
          description={BRAND.description}
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
            <p className="mt-3 text-base/7 opacity-85">{MISSION}</p>
          </div>

          <div>
            <span
              aria-hidden="true"
              className="grid size-11 place-items-center rounded-xl bg-white/10 text-white"
            >
              <Compass className="size-5" />
            </span>
            <h3 className="mt-4 font-display text-xl font-semibold tracking-tight">Vizyonumuz</h3>
            <p className="mt-3 text-base/7 opacity-85">{VISION}</p>
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
          {VALUES.map((value) => (
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
          {PROCESS_STEPS.map((step, index) => (
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
          <p className="mt-5 text-base/7 opacity-85">{GROUP_RELATION}</p>
        </div>
      </Section>

      <Section aria-labelledby="neden-bld-baslik">
        <SectionHeading
          id="neden-bld-baslik"
          eyebrow={`Neden ${BRAND.shortName}`}
          title="Farkı yaratan, vaat değil çalışma biçimi"
        />

        <div className="mt-10 grid bld-reveal gap-8 sm:grid-cols-2 lg:grid-cols-4">
          {DIFFERENTIATORS.map((item) => (
            <FeatureItem key={item.title} icon={item.icon} title={item.title} body={item.body} />
          ))}
        </div>
      </Section>

      <CtaBand />
    </>
  );
}
