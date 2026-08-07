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
import { serviceImage } from '@/lib/site-images';
import { Section, SectionHeading } from '@/components/site/section';
import { Button } from '@/components/ui/button';
import { PRIMARY_CTA } from '@/content/navigation';
import { fetchSiteContent, findService, type SiteService } from '@/lib/api/site-content';
import { breadcrumbJsonLd, pageMetadata, serviceJsonLd } from '@/lib/seo';
import type { LucideIcon } from 'lucide-react';
import type { Crumb } from '@/components/site/page-hero';

/**
 * Hizmet detayı.
 *
 * İçeriğin tek kaynağı admin paneli; sayfalar derleme anında üretiliyor.
 *
 * `dynamicParams` AÇIK. Eskiden kapalıydı, çünkü katalog kodun içindeydi ve
 * derlemede bilinmeyen bir slug olamazdı. Artık olabilir: derleme sırasında
 * API'ye ulaşılamazsa yalnızca yedekteki slug'lar üretilir, panelde sonradan
 * eklenen bir hizmet ise hiç üretilmez. Kapalı bırakmak bu iki durumda da
 * gerçek bir sayfayı 404'e çevirirdi. Katalogda gerçekten olmayan slug yine
 * `notFound()` ile 404 döner.
 */
export const dynamicParams = true;

/**
 * Adım ikonları.
 *
 * `Service.howItWorks` ikon taşımıyor — adımların anlamı her hizmette benzer
 * (görüşme → planlama → üretim → takip), bu yüzden ikonlar sırayla buradan
 * veriliyor. Adım sayısı değişirse mod işlemi diziyi başa sarar.
 */
const STEP_ICONS: readonly LucideIcon[] = [MessagesSquare, ClipboardList, CookingPot, RefreshCw];

function crumbsFor(service: SiteService): readonly Crumb[] {
  return [
    { href: '/hizmetler', label: 'Hizmetlerimiz' },
    { href: `/hizmetler/${service.slug}`, label: service.title },
  ];
}

/** Diğer hizmetler — listeyi bu hizmetten sonra başlatıp başa sararak seçiyoruz,
 *  böylece her sayfa farklı üç komşu gösteriyor. */
function relatedServices(
  services: readonly SiteService[],
  service: SiteService,
): readonly SiteService[] {
  const index = services.findIndex((item) => item.slug === service.slug);
  return [...services.slice(index + 1), ...services.slice(0, index)].slice(0, 3);
}

/**
 * Slug listesi API'den geliyor. `fetchSiteContent` hata fırlatmadığı için
 * API kapalıyken yedek katalogla derleme sürüyor — içerik sunucusu ayakta
 * değil diye site derlenememezdi.
 */
export async function generateStaticParams(): Promise<{ slug: string }[]> {
  const { services } = await fetchSiteContent();
  return services.map((service) => ({ slug: service.slug }));
}

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const { brand, services } = await fetchSiteContent();
  const service = findService(services, slug);

  if (!service) return {};

  return pageMetadata({
    title: service.title,
    description: service.summary,
    path: `/hizmetler/${service.slug}`,
    brandName: brand.name,
  });
}

export default async function ServiceDetailPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const { brand, services } = await fetchSiteContent();
  const service = findService(services, slug);

  if (!service) notFound();

  const crumbs = crumbsFor(service);
  const path = `/hizmetler/${service.slug}`;
  const others = relatedServices(services, service);

  return (
    <>
      <JsonLd
        data={serviceJsonLd({
          name: service.title,
          description: service.summary,
          path,
          brandName: brand.name,
        })}
      />
      <JsonLd data={breadcrumbJsonLd(crumbs)} />

      <PageHero
        crumbs={crumbs}
        eyebrow="Hizmetler"
        title={service.title}
        description={service.intro}
        image={serviceImage(service.slug)}
      />

      {/*
       * Panelden gelen serbest gövde.
       *
       * `dangerouslySetInnerHTML` burada bilinçli: HTML sunucuda, kaydetme
       * anında bir izin listesinden geçirilerek temizleniyor (script, iframe,
       * olay öznitelikleri ve stil elenmiş durumda). İkinci bir temizlik
       * istemcide yapılamaz — istemci tarafı arındırma, sunucunun ürettiği
       * işaretlemeye güvenmemenin doğru yolu değil; kaynağı düzeltmek doğru
       * yol ve o düzeltme API tarafında zaten var.
       *
       * Yedek içerikte bu alan `null`; blok hiç basılmaz.
       */}
      {service.bodyHtml && (
        <Section aria-label={`${service.title} hakkında`}>
          <div
            className="bld-prose max-w-2xl"
            dangerouslySetInnerHTML={{ __html: service.bodyHtml }}
          />
        </Section>
      )}

      {service.audience.length > 0 && (
        <Section aria-labelledby="kimler-icin">
          <div className="grid gap-10 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.1fr)] lg:gap-16">
            <SectionHeading
              id="kimler-icin"
              eyebrow="Uygunluk"
              title="Kimlere uyar?"
              description="Aşağıdakilerden birine benziyorsanız bu hizmet size göre."
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
      )}

      {service.howItWorks.length > 0 && (
        <Section tone="muted" aria-labelledby="nasil-isler">
          <SectionHeading
            id="nasil-isler"
            eyebrow="İşleyiş"
            title="Nasıl yürüyor?"
            description="İlk telefondan düzenli servise kadar izlediğimiz sıra."
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
      )}

      {service.benefits.length > 0 && (
        <Section aria-labelledby="ne-kazandirir">
          <SectionHeading
            id="ne-kazandirir"
            eyebrow="Karşılığı"
            title="Size ne kalır?"
            description="Bu işi devraldığımızda sizin üzerinizden kalkanlar."
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
      )}

      {/* Menü planlama tek paragraflık bir anlatı; koyu bantta okunması kolay
          ve sayfanın ortasında ritmi kırıyor. */}
      {service.menuPlanning.length > 0 && (
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
      )}

      {service.quoteNeeds.length > 0 && (
        <Section tone="warm" aria-labelledby="teklif-icin">
          <div className="grid gap-10 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.1fr)] lg:gap-16">
            <SectionHeading
              id="teklif-icin"
              eyebrow="Teklif"
              title="Bize ne söylemeniz gerekiyor?"
              description="Şu birkaç bilgiyle çalışılabilir bir teklif çıkarıyoruz. Eksikleri görüşmede tamamlarız."
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
      )}

      {others.length > 0 && (
        <Section tone="muted" aria-labelledby="diger-hizmetler">
          <SectionHeading
            id="diger-hizmetler"
            eyebrow="Devamı"
            title="Diğer hizmetler"
            description="Aynı kurumda birden fazla hizmeti birlikte yürüttüğümüz oluyor."
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
      )}

      <CtaBand />
    </>
  );
}
