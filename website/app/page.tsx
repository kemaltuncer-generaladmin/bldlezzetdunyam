import Image from 'next/image';
import Link from 'next/link';
import { ArrowRight, UtensilsCrossed } from 'lucide-react';
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
import { TodaysMenu } from '@/components/site/todays-menu';
import { fetchSiteContent } from '@/lib/api/site-content';
import { faqJsonLd, organizationJsonLd, pageMetadata } from '@/lib/seo';
import { PHOTO, sectorImage, serviceImage } from '@/lib/site-images';

/**
 * Kurumsal ana sayfa.
 *
 * ## Neden bu kadar az bölüm var?
 *
 * Önceki sürümde on bölüm vardı ve hepsi aynı işi yapıyordu: bir başlık, bir
 * açıklama, üç ile altı arası kart. Ziyaretçi dördüncü bölümden sonra okumayı
 * bırakıyordu. Şimdi yedi bölüm var ve her biri farklı bir soruya cevap veriyor
 * — ne yapıyoruz, nasıl çalışıyoruz, bugün ne pişti, temizlik nasıl, kimlere
 * gidiyoruz.
 *
 * "Menü çözümleri" ve "çalışma modelleri" bölümleri kaldırıldı: ikisi de kendi
 * sayfalarında zaten daha iyi anlatılıyordu ve ana sayfada hizmet listesinin
 * tekrarı gibi duruyorlardı.
 *
 * ## Katalog bağımlılığı
 *
 * "Bugün mutfakta" bölümü **canlı menüyü** gösterir, yani sipariş API'sine
 * bağlıdır. Ana sayfanın tamamının o API'nin sağlığına bağlanmaması için bölüm
 * kendi içinde hata yutuyor (`components/site/todays-menu.tsx`): menü
 * alınamazsa bölüm hiç basılmaz, sayfanın geri kalanı açılır. Kurumsal içerik
 * ise `lib/api/site-content.ts` üzerinden gelir ve kendi yedeğine düşer.
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

export default async function HomePage() {
  const content = await fetchSiteContent();
  const { brand, company, faq, quality, sectors, services } = content;

  /** Ana sayfada tam liste yerine öne çıkan altı hizmet gösteriliyor. */
  const featuredServices = services.slice(0, 6);

  return (
    <>
      <JsonLd data={organizationJsonLd(brand, content.contact)} />
      <JsonLd data={faqJsonLd(faq)} />

      {/* ── 1. Hero ───────────────────────────────────────────────────────── */}
      <section className="relative isolate border-b bg-charcoal text-cream">
        <Image
          alt={PHOTO.hero.alt}
          src={PHOTO.hero.src}
          fill
          priority
          sizes="100vw"
          className="-z-10 object-cover"
        />
        {/*
          İki katman: soldan sağa koyu geçiş metni taşır, alttaki hafif
          karartma fotoğrafın parlak bölgelerinde başlığın kontrastını
          garantiler. Ölçüldü — en açık bölgede bile krem/zemin 7:1 üstünde.
        */}
        <div
          aria-hidden="true"
          className="absolute inset-0 -z-10 bg-linear-to-r from-charcoal via-charcoal/85 to-charcoal/40"
        />

        <div className="mx-auto max-w-content px-4 py-20 sm:px-6 sm:py-28 lg:py-36">
          <div className="max-w-2xl">
            <p className="inline-flex items-center gap-2 rounded-full border border-cream/25 bg-cream/10 px-3 py-1.5 text-xs font-semibold text-cream backdrop-blur-sm">
              <UtensilsCrossed aria-hidden="true" className="size-3.5" />
              Kurumsal yemek ve catering
            </p>

            <h1 className="mt-6 font-display text-4xl font-semibold tracking-tight sm:text-6xl sm:leading-[1.05]">
              Sabah beşte ocak yanar,
              <br />
              <span className="text-brand-300">öğlende yemeğiniz masada.</span>
            </h1>

            <p className="mt-6 max-w-xl text-base/7 text-cream/80 sm:text-lg/8">
              Ofislere, fabrikalara, okullara ve davetlere yemek hazırlıyoruz. Menüyü birlikte
              kuruyoruz, teslim saatini siz söylüyorsunuz.
            </p>

            <div className="mt-9 flex flex-wrap gap-3">
              <Button asChild size="lg" className="bg-brand-500 text-charcoal hover:bg-brand-400">
                <Link href="/teklif-al">
                  Teklif Al
                  <ArrowRight aria-hidden="true" />
                </Link>
              </Button>
              <Button
                asChild
                size="lg"
                variant="outline"
                className="border-cream/35 bg-transparent text-cream hover:bg-cream/10 hover:text-cream"
              >
                <Link href="/menu">Günün menüsüne bak</Link>
              </Button>
            </div>
          </div>
        </div>
      </section>

      {/* ── 2. Fark şeridi ────────────────────────────────────────────────── */}
      <Section aria-labelledby="fark-baslik" className="!py-12 sm:!py-16">
        <h2 id="fark-baslik" className="sr-only">
          Bizi ayıran şeyler
        </h2>
        <div className="grid gap-8 sm:grid-cols-2 lg:grid-cols-4">
          {company.differentiators.map((item) => (
            <FeatureItem key={item.title} icon={item.icon} title={item.title} body={item.body} />
          ))}
        </div>
      </Section>

      {/* ── 3. Hizmetler ─────────────────────────────────────────────────── */}
      <Section tone="muted" aria-labelledby="hizmetler-baslik">
        <SectionHeading
          id="hizmetler-baslik"
          eyebrow="Hizmetler"
          title="Hangi düzende çalışmak isterseniz"
          description="Her gün gelen yemekten tek günlük davete kadar, kurulumu farklı beş altı iş yapıyoruz."
        />

        <div className="mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {featuredServices.map((service, index) => (
            <div key={service.slug} className="bld-reveal">
              <ServiceCard
                href={`/hizmetler/${service.slug}`}
                icon={service.icon}
                title={service.title}
                summary={service.summary}
                image={serviceImage(service.slug)}
                priority={index < 3}
              />
            </div>
          ))}
        </div>

        <div className="mt-10">
          <Button asChild variant="outline" size="lg">
            <Link href="/hizmetler">
              Tüm hizmetler
              <ArrowRight aria-hidden="true" />
            </Link>
          </Button>
        </div>
      </Section>

      {/* ── 4. Nasıl çalışıyoruz ──────────────────────────────────────────── */}
      <Section tone="charcoal" aria-labelledby="surec-baslik">
        <div className="grid gap-12 lg:grid-cols-[1fr_1.1fr] lg:items-start lg:gap-16">
          <div className="lg:sticky lg:top-28">
            <SectionHeading
              id="surec-baslik"
              eyebrow="Nasıl çalışıyoruz"
              title="İlk telefondan ilk servise"
              description="Dört adım. Hepsinde kimin ne yapacağı belli, sürpriz sevmiyoruz."
            />
            <div className="mt-8 overflow-hidden rounded-2xl">
              <Image
                alt={PHOTO.mutfakEkip.alt}
                src={PHOTO.mutfakEkip.src}
                width={1400}
                height={933}
                sizes="(max-width: 1024px) 100vw, 460px"
                className="h-full w-full object-cover"
              />
            </div>
          </div>

          <ol>
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
        </div>
      </Section>

      {/* ── 5. Bugün mutfakta (CANLI menü) ────────────────────────────────── */}
      <TodaysMenu />

      {/* ── 6. Kalite ve hijyen ───────────────────────────────────────────── */}
      <Section tone="warm" aria-labelledby="kalite-baslik">
        <div className="grid gap-12 lg:grid-cols-2 lg:items-center lg:gap-16">
          <div className="grid grid-cols-2 gap-4">
            <Image
              alt={PHOTO.kaliteMutfak.alt}
              src={PHOTO.kaliteMutfak.src}
              width={1400}
              height={933}
              sizes="(max-width: 1024px) 45vw, 280px"
              className="mt-8 aspect-4/5 w-full rounded-2xl object-cover"
            />
            <Image
              alt={PHOTO.kaliteEldiven.alt}
              src={PHOTO.kaliteEldiven.src}
              width={1400}
              height={933}
              sizes="(max-width: 1024px) 45vw, 280px"
              className="aspect-4/5 w-full rounded-2xl object-cover"
            />
          </div>

          <div>
            <SectionHeading
              id="kalite-baslik"
              eyebrow="Kalite ve hijyen"
              title="Zincir nerede kırılırsa orada dururuz"
              description="Mal girişinden teslimata kadar sekiz halka var. İlk dördü aşağıda."
            />

            <ul className="mt-10 grid gap-8 sm:grid-cols-2">
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

            <Button asChild variant="outline" size="lg" className="mt-10">
              <Link href="/kalite-hijyen">
                Zincirin tamamı
                <ArrowRight aria-hidden="true" />
              </Link>
            </Button>
          </div>
        </div>
      </Section>

      {/* ── 7. Çalıştığımız alanlar ───────────────────────────────────────── */}
      <Section aria-labelledby="alanlar-baslik">
        <SectionHeading
          id="alanlar-baslik"
          eyebrow="Çalıştığımız alanlar"
          title="Her yerin beklentisi başka"
          description="Aşağıda sektör adları var, müşteri logosu yok — doğrulanmadan referans göstermiyoruz."
        />

        <div className="mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {sectors.slice(0, 6).map((sector) => (
            <div key={sector.slug} className="bld-reveal">
              <SectorCard
                icon={sector.icon}
                title={sector.title}
                need={sector.need}
                answer={sector.answer}
                href={`/hizmetler/${sector.serviceSlug}`}
                image={sectorImage(sector.slug)}
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

      {/* ── 8. Sık sorulan sorular ────────────────────────────────────────── */}
      <Section tone="muted" aria-labelledby="sss-baslik">
        <div className="grid gap-12 lg:grid-cols-[1fr_1.4fr]">
          <SectionHeading
            id="sss-baslik"
            eyebrow="Sık sorulanlar"
            title="Teklif istemeden önce"
            description="Aradığınız cevap yoksa sorun; teklif formunda açıklama alanı var."
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

      {/* ── 9. Teklif çağrısı ─────────────────────────────────────────────── */}
      <CtaBand
        title={`${brand.shortName} ile başlamak için tek telefon`}
        description="Kaç kişisiniz, ne zaman ve nerede — bunları söyleyin, menü önerisi ve fiyatla birlikte dönelim."
      />
    </>
  );
}
