import Link from 'next/link';
import { notFound } from 'next/navigation';
import {
  ArrowRight,
  Check,
  ClipboardList,
  CookingPot,
  MessagesSquare,
  RefreshCw,
  Users,
} from 'lucide-react';
import { JsonLd } from '@/components/json-ld';
import { ProcessStepCard, ServiceCard } from '@/components/site/cards';
import { CtaBand } from '@/components/site/cta-band';
import { PageHero } from '@/components/site/page-hero';
import { Section, SectionHeading } from '@/components/site/section';
import { Button } from '@/components/ui/button';
import { PRIMARY_CTA } from '@/content/navigation';
import { SERVICES, findService } from '@/content/services';
import { breadcrumbJsonLd, pageMetadata, serviceJsonLd } from '@/lib/seo';
import type { LucideIcon } from 'lucide-react';
import type { Crumb } from '@/components/site/page-hero';
import type { Service } from '@/content/services';

/**
 * Hizmet detayı.
 *
 * Sekiz hizmetin tamamı derleme anında üretiliyor; sayfada dinamik veri yok,
 * içeriğin tek kaynağı `content/services.ts`. Bu yüzden `dynamicParams`
 * kapalı: katalogda olmayan bir slug 404 döner, boş bir sayfa üretilmez.
 */
export const dynamicParams = false;

/**
 * Adım ikonları.
 *
 * `Service.howItWorks` ikon taşımıyor — adımların anlamı her hizmette benzer
 * (görüşme → planlama → üretim → takip), bu yüzden ikonlar sırayla buradan
 * veriliyor. Adım sayısı değişirse mod işlemi diziyi başa sarar.
 */
const STEP_ICONS: readonly LucideIcon[] = [MessagesSquare, ClipboardList, CookingPot, RefreshCw];

function crumbsFor(service: Service): readonly Crumb[] {
  return [
    { href: '/hizmetler', label: 'Hizmetlerimiz' },
    { href: `/hizmetler/${service.slug}`, label: service.title },
  ];
}

/** Diğer hizmetler — listeyi bu hizmetten sonra başlatıp başa sararak seçiyoruz,
 *  böylece her sayfa farklı üç komşu gösteriyor. */
function relatedServices(service: Service): readonly Service[] {
  const index = SERVICES.findIndex((item) => item.slug === service.slug);
  return [...SERVICES.slice(index + 1), ...SERVICES.slice(0, index)].slice(0, 3);
}

export function generateStaticParams() {
  return SERVICES.map((service) => ({ slug: service.slug }));
}

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const service = findService(slug);

  if (!service) return {};

  return pageMetadata({
    title: service.title,
    description: service.summary,
    path: `/hizmetler/${service.slug}`,
  });
}

export default async function ServiceDetailPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const service = findService(slug);

  if (!service) notFound();

  const crumbs = crumbsFor(service);
  const path = `/hizmetler/${service.slug}`;
  const others = relatedServices(service);

  return (
    <>
      <JsonLd data={serviceJsonLd({ name: service.title, description: service.summary, path })} />
      <JsonLd data={breadcrumbJsonLd(crumbs)} />

      <PageHero
        crumbs={crumbs}
        eyebrow="Hizmetlerimiz"
        title={service.title}
        description={service.intro}
      />

      <Section aria-labelledby="kimler-icin">
        <div className="grid gap-10 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.1fr)] lg:gap-16">
          <SectionHeading
            id="kimler-icin"
            eyebrow="Uygunluk"
            title="Kimler için uygun?"
            description="Aşağıdaki tarife yakın bir düzeniniz varsa bu hizmet doğrudan uygulanabilir."
          />

          <ul className="space-y-4">
            {service.audience.map((item) => (
              <li key={item} className="flex items-start gap-3">
                <span
                  aria-hidden="true"
                  className="mt-0.5 grid size-7 shrink-0 place-items-center rounded-lg bg-accent text-accent-foreground"
                >
                  <Users className="size-4" />
                </span>
                <span className="text-base/7">{item}</span>
              </li>
            ))}
          </ul>
        </div>
      </Section>

      <Section tone="muted" aria-labelledby="nasil-isler">
        <SectionHeading
          id="nasil-isler"
          eyebrow="Süreç"
          title="Nasıl işler?"
          description="İlk görüşmeden düzenli servise kadar izlediğimiz sıra."
        />

        {/* Sıralı liste: adımların sırası anlamlı, görsel numaralar da buradan geliyor. */}
        <ol className="mt-12">
          {service.howItWorks.map((step, index) => (
            <ProcessStepCard
              key={step.title}
              index={index + 1}
              icon={STEP_ICONS[index % STEP_ICONS.length] ?? ClipboardList}
              title={step.title}
              body={step.body}
            />
          ))}
        </ol>
      </Section>

      <Section aria-labelledby="ne-kazandirir">
        <SectionHeading
          id="ne-kazandirir"
          eyebrow="Karşılığı"
          title="Ne kazandırır?"
          description="Bu hizmeti devraldığımızda kurumun üzerinden kalkan işler ve kazandığı öngörülebilirlik."
        />

        <ul className="mt-10 grid gap-x-10 gap-y-5 sm:grid-cols-2">
          {service.benefits.map((benefit) => (
            <li key={benefit} className="flex items-start gap-3 border-t pt-5">
              <Check aria-hidden="true" className="mt-1 size-5 shrink-0 text-primary" />
              <span className="text-base/7">{benefit}</span>
            </li>
          ))}
        </ul>
      </Section>

      {/* Menü planlama tek paragraflık bir anlatı; koyu bantta okunması kolay
          ve sayfanın ortasında ritmi kırıyor. */}
      <Section tone="olive" aria-labelledby="menu-planlama">
        <div className="max-w-3xl">
          <p className="text-xs font-semibold tracking-[0.14em] uppercase opacity-80">Menü</p>
          <h2
            id="menu-planlama"
            className="mt-3 font-display text-3xl font-semibold tracking-tight sm:text-4xl"
          >
            Menü nasıl planlanır?
          </h2>
          <p className="mt-6 text-lg/8 opacity-90">{service.menuPlanning}</p>

          <p className="mt-8 text-sm/6 opacity-75">
            Örnek menü kurgularını{' '}
            <Link href="/menu-cozumleri" className="font-semibold underline underline-offset-4">
              Menü Çözümleri
            </Link>{' '}
            sayfasında görebilirsiniz.
          </p>
        </div>
      </Section>

      <Section tone="warm" aria-labelledby="teklif-icin">
        <div className="grid gap-10 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.1fr)] lg:gap-16">
          <SectionHeading
            id="teklif-icin"
            eyebrow="Teklif"
            title="Teklif için ne gerekiyor?"
            description="Bu birkaç bilgiyle çalışılabilir bir teklif hazırlayabiliyoruz; eksik kalan noktaları görüşmede tamamlıyoruz."
          />

          <div>
            <ul className="space-y-3">
              {service.quoteNeeds.map((need, index) => (
                <li key={need} className="flex items-start gap-4 rounded-xl border bg-card p-4">
                  <span
                    aria-hidden="true"
                    className="mt-0.5 text-sm font-semibold text-muted-foreground tabular-nums"
                  >
                    {String(index + 1).padStart(2, '0')}
                  </span>
                  <span className="text-base/7">{need}</span>
                </li>
              ))}
            </ul>

            <Button asChild size="lg" className="mt-8">
              <Link href={PRIMARY_CTA.href}>
                {PRIMARY_CTA.label}
                <ArrowRight aria-hidden="true" />
              </Link>
            </Button>
          </div>
        </div>
      </Section>

      <Section tone="muted" aria-labelledby="diger-hizmetler">
        <SectionHeading
          id="diger-hizmetler"
          eyebrow="Devamı"
          title="Diğer hizmetler"
          description="Aynı kurum içinde birden fazla hizmet birlikte yürütülebilir."
        />

        <div className="mt-10 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {others.map((other) => (
            <ServiceCard
              key={other.slug}
              href={`/hizmetler/${other.slug}`}
              icon={other.icon}
              title={other.title}
              summary={other.summary}
            />
          ))}
        </div>

        <Link
          href="/hizmetler"
          className="mt-8 inline-flex items-center gap-1.5 text-sm font-semibold text-primary underline-offset-4 hover:underline"
        >
          Tüm hizmetler
          <ArrowRight aria-hidden="true" className="size-4" />
        </Link>
      </Section>

      <CtaBand />
    </>
  );
}
