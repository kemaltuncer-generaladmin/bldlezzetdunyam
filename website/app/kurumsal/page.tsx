import Image from 'next/image';
import { Compass, Target } from 'lucide-react';
import { JsonLd } from '@/components/json-ld';
import { FeatureItem, ProcessStepCard } from '@/components/site/cards';
import { CtaBand } from '@/components/site/cta-band';
import { PageHero } from '@/components/site/page-hero';
import { Section, SectionHeading } from '@/components/site/section';
import { fetchSiteContent } from '@/lib/api/site-content';
import { breadcrumbJsonLd, pageMetadata } from '@/lib/seo';
import { PHOTO } from '@/lib/site-images';
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
    description: `${brand.name} nasıl çalışır: neye göre karar veririz, ilk telefondan ilk servise kadar hangi adımlardan geçeriz.`,
    path: '/kurumsal',
    brandName: brand.name,
  });
}

export default async function KurumsalPage() {
  const { brand, company } = await fetchSiteContent();

  return (
    <>
      <JsonLd data={breadcrumbJsonLd(CRUMBS)} />

      <PageHero
        crumbs={CRUMBS}
        eyebrow="Kurumsal"
        title="Biz kimiz"
        description={brand.tagline}
        image={PHOTO.mutfakEkip.src}
      />

      <Section aria-labelledby="hakkimizda-baslik">
        <div className="grid gap-12 lg:grid-cols-[1.1fr_1fr] lg:items-center lg:gap-16">
          <div>
            <SectionHeading
              id="hakkimizda-baslik"
              eyebrow="Ne yapıyoruz"
              title="Kalabalık sofralar kuruyoruz"
              description={brand.description}
            />
            <div className="bld-prose mt-8 max-w-xl">
              <p>
                Bir mutfağız. Sabah erken açılır, akşam geç kapanır. Arada yüzlerce tabak çıkar ve
                hepsinin bir yere yetişmesi gerekir.
              </p>
              <p>
                Bu sayfa o işin nasıl yürüdüğünü anlatıyor — neye göre karar verdiğimizi, hangi
                adımlardan geçtiğimizi ve bizden ne bekleyebileceğinizi.
              </p>
            </div>
          </div>

          <Image
            alt={PHOTO.mutfakSef.alt}
            src={PHOTO.mutfakSef.src}
            width={900}
            height={1125}
            sizes="(max-width: 1024px) 100vw, 480px"
            className="w-full rounded-md bld-photo"
          />
        </div>
      </Section>

      {/* Misyon ve vizyon koyu bantta: sayfanın en çok alıntılanan iki cümlesi,
          zemin değişimiyle görsel olarak da ayrılıyor. */}
      <Section tone="brand" aria-labelledby="misyon-vizyon-baslik">
        <h2
          id="misyon-vizyon-baslik"
          className="max-w-2xl font-display text-h2 font-semibold tracking-tight text-balance sm:text-h1"
        >
          Ne için çalışıyoruz
        </h2>

        <div className="mt-10 grid bld-reveal gap-10 md:grid-cols-2 md:gap-14">
          <div>
            <span
              aria-hidden="true"
              className="grid size-11 place-items-center rounded-sm bg-brand-50/15 text-brand-50"
            >
              <Target strokeWidth={1.75} className="size-5" />
            </span>
            <h3 className="mt-4 font-display text-h3 font-semibold tracking-tight">Misyonumuz</h3>
            <p className="mt-3 text-body-lg opacity-85">{company.mission}</p>
          </div>

          <div>
            <span
              aria-hidden="true"
              className="grid size-11 place-items-center rounded-sm bg-brand-50/15 text-brand-50"
            >
              <Compass strokeWidth={1.75} className="size-5" />
            </span>
            <h3 className="mt-4 font-display text-h3 font-semibold tracking-tight">Vizyonumuz</h3>
            <p className="mt-3 text-body-lg opacity-85">{company.vision}</p>
          </div>
        </div>
      </Section>

      <Section aria-labelledby="degerler-baslik">
        <SectionHeading
          id="degerler-baslik"
          eyebrow="Değerler"
          title="Pazarlık etmediğimiz dört şey"
          description="İşler sıkıştığında da geçerli olanlar."
        />

        <ul className="mt-10 grid bld-reveal gap-6 sm:grid-cols-2">
          {company.values.map((value) => (
            <li
              key={value.title}
              /*
                `bld-card` KULLANILMIYOR ve sebebi sıra: kısayol sınıfı
                `border` (dört kenar 1px) uyguluyor, sol kenarı kalınlaştıran
                `border-l-4` ile aynı katmanda üretiliyor ve hangisinin
                kazanacağı sıralamaya kalıyordu. Açıkça yazmak bu belirsizliği
                kaldırıyor.
              */
              className="rounded-md border border-l-4 border-l-primary bg-card p-6 text-card-foreground shadow-card dark:shadow-none dark:inset-ring dark:inset-ring-white/5"
            >
              <h3 className="font-display text-h3 font-semibold tracking-tight text-heading">
                {value.title}
              </h3>
              <p className="mt-2 text-body text-muted-foreground">{value.body}</p>
            </li>
          ))}
        </ul>
      </Section>

      <Section tone="muted" aria-labelledby="surec-baslik">
        <SectionHeading
          id="surec-baslik"
          eyebrow="İşleyiş"
          title="İlk telefondan ilk servise"
          description="Sıra her kurumda aynı. Hangi adımda olduğunuzu hep bilirsiniz."
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
            className="font-display text-h2 font-semibold tracking-tight text-balance sm:text-h1"
          >
            Şirket ailesi
          </h2>
          <p className="mt-5 text-body-lg opacity-85">{company.groupRelation}</p>
        </div>
      </Section>

      <Section aria-labelledby="neden-bld-baslik">
        <SectionHeading
          id="neden-bld-baslik"
          eyebrow={`Neden ${brand.shortName}`}
          title="Bizi ayıran şeyler"
          description="Reklam cümlesi değil, günlük işleyişten dört başlık."
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
