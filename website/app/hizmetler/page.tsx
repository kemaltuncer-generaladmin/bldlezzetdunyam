import Link from 'next/link';
import { ArrowRight, Compass } from 'lucide-react';
import { JsonLd } from '@/components/json-ld';
import { ServiceCard } from '@/components/site/cards';
import { CtaBand } from '@/components/site/cta-band';
import { PageHero } from '@/components/site/page-hero';
import { Section, SectionHeading } from '@/components/site/section';
import { Button } from '@/components/ui/button';
import { PRIMARY_CTA } from '@/content/navigation';
import { fetchSiteContent } from '@/lib/api/site-content';
import { PHOTO, serviceImage } from '@/lib/site-images';
import { breadcrumbJsonLd, pageMetadata } from '@/lib/seo';
import type { Crumb } from '@/components/site/page-hero';

/**
 * Hizmet listesi.
 *
 * Kartların tamamı panelden gelen hizmet kataloğundan üretiliyor: yeni bir
 * hizmet eklendiğinde bu dosyaya dokunmak gerekmiyor, hem liste hem detay
 * sayfası kendiliğinden oluşuyor. API kapalıysa yedek katalog basılır.
 */

const CRUMBS: readonly Crumb[] = [{ href: '/hizmetler', label: 'Hizmetlerimiz' }];

export async function generateMetadata() {
  const { brand, services } = await fetchSiteContent();

  return pageMetadata({
    title: 'Hizmetlerimiz',
    // Açıklama katalogdan türetiliyor: panelde hizmet eklenip çıkarıldığında
    // arama sonucundaki özet de kendiliğinden güncelleniyor.
    description: `Catering hizmetlerimiz: ${services.map((service) => service.title).join(', ')}.`,
    path: '/hizmetler',
    brandName: brand.name,
  });
}

export default async function ServicesPage() {
  const { services } = await fetchSiteContent();

  return (
    <>
      <JsonLd data={breadcrumbJsonLd(CRUMBS)} />

      <PageHero
        crumbs={CRUMBS}
        eyebrow="Hizmetler"
        title="Her iş için ayrı bir düzen"
        description="Bir fabrikanın vardiya yemeğiyle bir okulun ikindi ikramı aynı şekilde kurulmaz. Sekiz ayrı hizmetimiz var; hepsinin işleyişi kendi sayfasında yazıyor."
        image={PHOTO.servisBufe.src}
      />

      <Section aria-labelledby="hizmet-listesi">
        <SectionHeading
          id="hizmet-listesi"
          eyebrow="Katalog"
          title="Ne yapıyoruz?"
          description="Her başlığın sayfasında kimler için uygun olduğu, nasıl işlediği ve teklif için nelerin gerektiği yazıyor."
        />

        <div className="mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {services.map((service, index) => (
            <ServiceCard
              key={service.slug}
              href={`/hizmetler/${service.slug}`}
              icon={service.icon}
              title={service.title}
              summary={service.summary}
              image={serviceImage(service.slug)}
              priority={index < 3}
            />
          ))}
        </div>
      </Section>

      {/* Koyu bant: liste ile sayfa sonu çağrısı arasında bir duraklama noktası.
          Ziyaretçi hangi başlığa gireceğini bilemiyorsa akış burada teklife dönüyor. */}
      <Section tone="olive" aria-labelledby="hangi-hizmet">
        <div className="grid items-start gap-8 md:grid-cols-[auto_1fr] md:gap-10">
          <span
            aria-hidden="true"
            className="grid size-14 shrink-0 place-items-center rounded-2xl bg-white/10"
          >
            <Compass className="size-7" />
          </span>

          <div>
            <h2
              id="hangi-hizmet"
              className="font-display text-2xl font-semibold tracking-tight sm:text-3xl"
            >
              Hangisi size uyar, emin değil misiniz?
            </h2>
            <p className="mt-4 max-w-2xl text-base/7 opacity-85">
              Kaç kişisiniz, saat kaçta yiyorsunuz, mutfağınız var mı — bu üçünü söyleyin, gerisini
              birlikte çözelim. İki hizmeti birleştirdiğimiz de oluyor.
            </p>

            <div className="mt-8 flex flex-wrap gap-3">
              {/* Koyu bantta buton renkleri CtaBand ile aynı kalıpta: dolu buton
                  krem zemin, ikincil buton saydam + krem çerçeve. */}
              <Button asChild size="lg" className="bg-cream text-charcoal hover:bg-cream/90">
                <Link href={PRIMARY_CTA.href}>
                  {PRIMARY_CTA.label}
                  <ArrowRight aria-hidden="true" />
                </Link>
              </Button>
              <Button
                asChild
                size="lg"
                variant="outline"
                className="border-cream/30 bg-transparent text-cream hover:bg-cream/10 hover:text-cream dark:bg-transparent"
              >
                <Link href="/calistigimiz-alanlar">Çalıştığımız alanlar</Link>
              </Button>
            </div>
          </div>
        </div>
      </Section>

      <CtaBand />
    </>
  );
}
