import Link from 'next/link';
import {
  ArrowRight,
  ChefHat,
  ClipboardList,
  PartyPopper,
  ShieldCheck,
  Truck,
  UtensilsCrossed,
} from 'lucide-react';
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from '@/components/ui/accordion';
import { Button } from '@/components/ui/button';
import { JsonLd } from '@/components/json-ld';
import { CtaBand } from '@/components/site/cta-band';
import { FeatureItem, ProcessStepCard, SectorCard, ServiceCard } from '@/components/site/cards';
import { Section, SectionHeading } from '@/components/site/section';
import { fetchSiteContent } from '@/lib/api/site-content';
import { faqJsonLd, organizationJsonLd, pageMetadata } from '@/lib/seo';

/**
 * Kurumsal ana sayfa.
 *
 * Sipariş kataloğuna **bağlı değil.** Önceki sürüm menüyü API'den çekiyordu ve
 * API erişilemediğinde ana sayfanın tamamı hata ekranına düşüyordu — kurumsal
 * bir ziyaretçinin ilk gördüğü şeyin sipariş altyapısının sağlığına bağlı
 * olması yanlış. İçerik admin panelinden gelir (`lib/api/site-content.ts`);
 * API erişilemezse yedeğe düşülür ve sayfa yine dolu açılır. Sipariş akışına
 * `/menu` üzerinden giriliyor.
 */
export async function generateMetadata() {
  const { brand } = await fetchSiteContent();

  return pageMetadata({
    title: 'Kurumsal Catering ve Toplu Yemek Hizmeti',
    description: brand.description,
    path: '/',
    brandName: brand.name,
  });
}

/** Hero altındaki güven şeridi — rakam değil, çalışma biçimi. */
const TRUST_STRIP = [
  { icon: ClipboardList, label: 'Menü haftalık olarak önceden paylaşılır' },
  { icon: ShieldCheck, label: 'Sıcaklık kontrollü üretim ve teslimat' },
  { icon: Truck, label: 'Teslimat saati vardiyanıza göre sabitlenir' },
] as const;

/**
 * Hizmet modelleri — "firma kapasitesi" bölümü.
 *
 * Günlük üretim adedi, araç sayısı, personel sayısı gibi rakamlar YOK: repoda
 * doğrulanmış kaynağı yok. Kapasite, hangi çalışma modellerini kurabildiğimizi
 * anlatarak gösteriliyor.
 */
const OPERATING_MODELS = [
  {
    icon: Truck,
    title: 'Taşıma yemek',
    body: 'Üretim merkez mutfakta yapılır, öğün servise hazır teslim edilir. Mutfak altyapısı gerektirmez.',
  },
  {
    icon: ChefHat,
    title: 'Yerinde üretim',
    body: 'Kurumun kendi mutfağında, bizim ekibimizle günlük üretim. Taşıma süresi ortadan kalkar.',
  },
  {
    icon: PartyPopper,
    title: 'Organizasyon catering',
    body: 'Tek seferlik davet ve etkinlikler için menü, kurulum, servis ve toplama tek pakette.',
  },
] as const;

export default async function HomePage() {
  const content = await fetchSiteContent();
  const { brand, company, faq, menus, quality, sectors, services } = content;

  /** Ana sayfada tam liste yerine öne çıkan altı hizmet gösteriliyor. */
  const featuredServices = services.slice(0, 6);

  return (
    <>
      <JsonLd data={organizationJsonLd(brand, content.contact)} />
      <JsonLd data={faqJsonLd(faq)} />

      {/* ── 1. Hero ───────────────────────────────────────────────────────── */}
      <section className="relative overflow-hidden border-b bg-surface-warm text-surface-warm-foreground">
        <div
          aria-hidden="true"
          className="pointer-events-none absolute -top-40 -right-32 size-[28rem] rounded-full bg-brand-200/40 blur-3xl dark:opacity-30"
        />

        <div className="relative mx-auto grid max-w-content items-center gap-12 px-4 py-16 sm:px-6 sm:py-24 lg:grid-cols-[1.15fr_1fr]">
          <div>
            <p className="inline-flex items-center gap-2 rounded-full border border-primary/25 bg-card px-3 py-1.5 text-xs font-semibold text-primary">
              <UtensilsCrossed aria-hidden="true" className="size-3.5" />
              Toplu yemek ve catering hizmetleri
            </p>

            <h1 className="mt-6 font-display text-4xl font-semibold tracking-tight sm:text-6xl sm:leading-[1.05]">
              Kalabalık sofralar için <span className="text-primary">planlı</span> catering
            </h1>

            <p className="mt-6 max-w-xl text-base/7 opacity-80 sm:text-lg/8">
              Kurumlara, okullara, sağlık kuruluşlarına ve organizasyonlara toplu yemek hizmeti
              veriyoruz. Menüyü planlıyor, hijyenik koşullarda üretiyor ve söz verdiğimiz saatte
              teslim ediyoruz.
            </p>

            <div className="mt-9 flex flex-wrap gap-3">
              <Button asChild size="lg">
                <Link href="/teklif-al">
                  Teklif Al
                  <ArrowRight aria-hidden="true" />
                </Link>
              </Button>
              <Button asChild size="lg" variant="outline">
                <Link href="/hizmetler">Hizmetleri İncele</Link>
              </Button>
            </div>

            <ul className="mt-10 space-y-3">
              {TRUST_STRIP.map((item) => (
                <li key={item.label} className="flex items-center gap-3 text-sm">
                  <item.icon aria-hidden="true" className="size-4 shrink-0 text-primary" />
                  <span className="opacity-80">{item.label}</span>
                </li>
              ))}
            </ul>
          </div>

          {/*
           * Görsel yerine tipografik pano.
           *
           * Projede BLD'ye ait catering fotoğrafı yok. Stok fotoğraf koymak,
           * "bu bizim mutfağımız" izlenimi yaratıp gerçek olmayan bir şey
           * göstermek olurdu. Bunun yerine hizmetin ne olduğunu okunur biçimde
           * anlatan bir pano kullanıyoruz. Gerçek fotoğraflar geldiğinde bu
           * blok görselle değiştirilecek.
           */}
          <div className="relative overflow-hidden rounded-3xl bg-charcoal p-8 text-cream sm:p-10">
            <div
              aria-hidden="true"
              className="pointer-events-none absolute -right-16 -bottom-20 size-64 rounded-full bg-brand-600/30 blur-3xl"
            />
            <div className="relative">
              <p className="text-xs font-semibold tracking-[0.16em] text-brand-300 uppercase">
                Nasıl çalışıyoruz
              </p>
              <ol className="mt-6 space-y-5">
                {company.processSteps.slice(0, 4).map((step, index) => (
                  <li key={step.title} className="flex gap-4">
                    <span
                      aria-hidden="true"
                      className="mt-0.5 grid size-7 shrink-0 place-items-center rounded-full border border-cream/25 text-xs font-semibold text-cream/70"
                    >
                      {index + 1}
                    </span>
                    <span>
                      <span className="block font-display text-base font-semibold">
                        {step.title}
                      </span>
                      <span className="mt-1 block text-sm/6 text-cream/65">{step.body}</span>
                    </span>
                  </li>
                ))}
              </ol>
            </div>
          </div>
        </div>
      </section>

      {/* ── 2. Hizmet kategorileri ────────────────────────────────────────── */}
      <Section aria-labelledby="hizmetler-baslik">
        <SectionHeading
          id="hizmetler-baslik"
          eyebrow="Hizmetlerimiz"
          title="Hangi düzende çalışmak istiyorsanız"
          description="Düzenli kurumsal yemekten tek seferlik organizasyona kadar farklı ihtiyaçlar için ayrı hizmet modelleri kuruyoruz."
        />

        <div className="mt-12 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {featuredServices.map((service) => (
            <div key={service.slug} className="bld-reveal">
              <ServiceCard
                href={`/hizmetler/${service.slug}`}
                icon={service.icon}
                title={service.title}
                summary={service.summary}
              />
            </div>
          ))}
        </div>

        <div className="mt-10">
          <Button asChild variant="outline" size="lg">
            <Link href="/hizmetler">
              Tüm hizmetleri gör
              <ArrowRight aria-hidden="true" />
            </Link>
          </Button>
        </div>
      </Section>

      {/* ── 3. Neden BLD? ─────────────────────────────────────────────────── */}
      <Section tone="olive" aria-labelledby="neden-baslik">
        <SectionHeading
          id="neden-baslik"
          eyebrow="Neden Benim Lezzet Dünyam"
          title="Vaat değil, çalışma biçimi"
          description="Aşağıdakiler reklam cümlesi değil; hizmetin nasıl yürüdüğünü anlatan pratik başlıklar."
        />

        <div className="mt-12 grid gap-10 sm:grid-cols-2 lg:grid-cols-4">
          {company.differentiators.map((item) => (
            <div key={item.title} className="bld-reveal">
              <FeatureItem icon={item.icon} title={item.title} body={item.body} tone="dark" />
            </div>
          ))}
        </div>
      </Section>

      {/* ── 4. İşleyiş süreci ─────────────────────────────────────────────── */}
      <Section tone="muted" aria-labelledby="surec-baslik">
        <SectionHeading
          id="surec-baslik"
          eyebrow="Süreç"
          title="İlk görüşmeden düzenli hizmete"
          description="Teklif aşamasından itibaren her adımın kimde olduğu belli; sürpriz çıkmaması için akış baştan sabitleniyor."
        />

        <ol className="mt-12 max-w-3xl">
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

      {/* ── 5. Menü örnekleri ─────────────────────────────────────────────── */}
      <Section aria-labelledby="menu-baslik">
        <SectionHeading
          id="menu-baslik"
          eyebrow="Menü çözümleri"
          title="Menü, kurumunuza göre kurulur"
          description="Aynı menü her yere uymaz. Çalışan profiline, yaş grubuna ve öğün düzenine göre farklı kurgular hazırlıyoruz."
        />

        <div className="mt-12 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {menus.solutions.slice(0, 3).map((solution) => (
            <article
              key={solution.slug}
              className="flex bld-reveal flex-col rounded-2xl border bg-card p-6 text-card-foreground"
            >
              <h3 className="font-display text-lg font-semibold tracking-tight">
                {solution.title}
              </h3>
              <p className="mt-2 text-sm/6 text-muted-foreground">{solution.summary}</p>

              <dl className="mt-5 flex-1 space-y-3 border-t pt-5">
                {solution.courses.slice(0, 3).map((course) => (
                  <div key={course.label}>
                    <dt className="text-xs font-semibold tracking-wider text-primary uppercase">
                      {course.label}
                    </dt>
                    <dd className="mt-1 text-sm text-muted-foreground">
                      {course.examples.slice(0, 3).join(' · ')}
                    </dd>
                  </div>
                ))}
              </dl>
            </article>
          ))}
        </div>

        <div className="mt-10">
          <Button asChild variant="outline" size="lg">
            <Link href="/menu-cozumleri">
              Menü çözümlerinin tamamı
              <ArrowRight aria-hidden="true" />
            </Link>
          </Button>
        </div>
      </Section>

      {/* ── 6. Kalite ve hijyen ───────────────────────────────────────────── */}
      <Section tone="warm" aria-labelledby="kalite-baslik">
        <div className="grid gap-12 lg:grid-cols-[1fr_1.2fr]">
          <SectionHeading
            id="kalite-baslik"
            eyebrow="Kalite ve hijyen"
            title="Zincirin her halkası kayıt altında"
            description="Hijyen tek bir aşamanın değil, hammaddeden teslimata uzanan bir zincirin işi. Aşağıda o zincirin ilk dört halkası var."
          />

          <div>
            <ul className="grid gap-6 sm:grid-cols-2">
              {quality.chain.slice(0, 4).map((principle) => (
                <li key={principle.title} className="bld-reveal">
                  <FeatureItem
                    icon={principle.icon}
                    title={principle.title}
                    body={principle.body}
                  />
                </li>
              ))}
            </ul>

            <Button asChild variant="outline" size="lg" className="mt-8">
              <Link href="/kalite-hijyen">
                Kalite yaklaşımımızın tamamı
                <ArrowRight aria-hidden="true" />
              </Link>
            </Button>
          </div>
        </div>
      </Section>

      {/* ── 7. Çalıştığımız alanlar ───────────────────────────────────────── */}
      <Section tone="muted" aria-labelledby="alanlar-baslik">
        <SectionHeading
          id="alanlar-baslik"
          eyebrow="Çalıştığımız alanlar"
          title="Her sektörün beklentisi farklı"
          description="Aşağıda sektör adları var, müşteri logosu yok: doğrulanmış referans verimiz olmadan firma adı veya logo göstermeyi doğru bulmuyoruz."
        />

        <div className="mt-12 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {sectors.slice(0, 6).map((sector) => (
            <div key={sector.slug} className="bld-reveal">
              <SectorCard
                icon={sector.icon}
                title={sector.title}
                need={sector.need}
                answer={sector.answer}
                href={`/hizmetler/${sector.serviceSlug}`}
              />
            </div>
          ))}
        </div>

        <div className="mt-10">
          <Button asChild variant="outline" size="lg">
            <Link href="/calistigimiz-alanlar">
              Tüm alanlar
              <ArrowRight aria-hidden="true" />
            </Link>
          </Button>
        </div>
      </Section>

      {/* ── 8. Hizmet modelleri (kapasite) ────────────────────────────────── */}
      <Section tone="charcoal" aria-labelledby="modeller-baslik">
        <SectionHeading
          id="modeller-baslik"
          eyebrow="Çalışma modelleri"
          title="Mutfağınız olsa da olmasa da"
          description="Hizmeti kurumun altyapısına göre kuruyoruz; tek bir modele uymak zorunda değilsiniz."
        />

        <div className="mt-12 grid gap-10 sm:grid-cols-3">
          {OPERATING_MODELS.map((model) => (
            <div key={model.title} className="bld-reveal">
              <FeatureItem icon={model.icon} title={model.title} body={model.body} tone="dark" />
            </div>
          ))}
        </div>
      </Section>

      {/* ── 9. Sık sorulan sorular ────────────────────────────────────────── */}
      <Section aria-labelledby="sss-baslik">
        <div className="grid gap-12 lg:grid-cols-[1fr_1.4fr]">
          <SectionHeading
            id="sss-baslik"
            eyebrow="Sık sorulan sorular"
            title="Teklif almadan önce merak edilenler"
            description="Aradığınız cevap yoksa doğrudan sorabilirsiniz; teklif formunda açıklama alanı var."
          />

          <Accordion type="single" collapsible className="w-full">
            {faq.map((item, index) => (
              <AccordionItem key={item.question} value={`sss-${index}`}>
                <AccordionTrigger className="text-left text-base font-medium">
                  {item.question}
                </AccordionTrigger>
                <AccordionContent className="text-sm/7 text-muted-foreground">
                  {item.answer}
                </AccordionContent>
              </AccordionItem>
            ))}
          </Accordion>
        </div>
      </Section>

      {/* ── 10. Teklif çağrısı ────────────────────────────────────────────── */}
      <CtaBand
        title={`${brand.shortName} ile çalışmak için ilk adım`}
        description="Kişi sayınızı, hizmet türünüzü ve konumunuzu iletin; menü önerisi ve fiyatlandırmayla birlikte size dönelim."
      />
    </>
  );
}
