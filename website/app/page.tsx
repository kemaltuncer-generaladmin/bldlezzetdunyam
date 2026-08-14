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
import { CartSummaryBar } from '@/components/cart-summary';
import { QuickOrder } from '@/components/site/quick-order';
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
      <section className="relative isolate border-b bg-neutral-950 text-neutral-50">
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
          garantiler. Ölçüldü — en açık bölgede bile metin/zemin 7:1 üstünde.

          Fotoğrafa MARKA RENGİ overlay ATILMIYOR: yemeğin gerçek rengi
          ürünün kendisi. Karartma nötr (`neutral-950`).
        */}
        <div
          aria-hidden="true"
          className="absolute inset-0 -z-10 bg-linear-to-r from-neutral-950 via-neutral-950/85 to-neutral-950/40"
        />

        <div className="mx-auto max-w-content px-4 py-20 sm:px-6 sm:py-28 lg:py-36">
          <div className="max-w-2xl">
            {/* Overline adımı: 11/700/0.14em. Sabit metin, İ/ı yok — `uppercase` güvenli. */}
            <p className="inline-flex items-center gap-2 rounded-full border border-neutral-50/25 bg-neutral-50/10 px-3 py-1.5 text-overline text-neutral-50 uppercase backdrop-blur-sm">
              <UtensilsCrossed strokeWidth={1.75} aria-hidden="true" className="size-3.5" />
              Kurumsal yemek ve catering
            </p>

            <h1 className="mt-6 font-display text-h1 font-semibold tracking-tight text-balance sm:text-display">
              Sabah beşte ocak yanar,
              <br />
              {/*
                Vurgu `brand-300`: koyu zeminde marka turuncusunun okunur
                adımı. `brand-500` ve daha koyusu bu zeminde metin olarak
                sönüyor.
              */}
              <span className="text-brand-300">öğlende yemeğiniz masada.</span>
            </h1>

            <p className="mt-6 max-w-xl text-body-lg text-neutral-50/80">
              Ofislere, fabrikalara, okullara ve davetlere yemek hazırlıyoruz. Menüyü birlikte
              kuruyoruz, teslim saatini siz söylüyorsunuz.
            </p>

            <div className="mt-9 flex flex-wrap gap-3">
              {/*
                Koyu zeminde BİRİNCİL eylem `brand-300` dolgu + koyu yazı
                (9,22:1). `--primary` (brand700) burada kullanılamaz: kahve
                dolgu, kahve-siyahı bandın içinde kayboluyor.
              */}
              <Button
                asChild
                size="lg"
                className="bg-brand-300 text-neutral-950 hover:bg-brand-200"
              >
                <Link href="/teklif-al">
                  Teklif Al
                  <ArrowRight strokeWidth={1.75} aria-hidden="true" />
                </Link>
              </Button>
              <Button
                asChild
                size="lg"
                variant="outline"
                className="border-neutral-50/35 bg-transparent text-neutral-50 hover:bg-neutral-50/10 hover:text-neutral-50"
              >
                <Link href="/menu">Günün menüsüne bak</Link>
              </Button>
            </div>
          </div>
        </div>
      </section>

      {/* ── 1b. Hızlı sipariş ─────────────────────────────────────────────
        HERO'NUN HEMEN ALTINDA VE BİLEREK. Site v2.0'da sipariş odaklı: geri
        dönen kurumsal müşteri sayfaya "bugün ne var, geçen siparişi
        tekrarlayayım" diye geliyor ve bunun için yedi bölüm kaydırması
        anlamsızdı.

        Kutu KENDİ VERİSİNİ İSTEMCİDEN çekiyor (`/api/hizli-siparis`), yani
        ana sayfa ISR'da kalmaya devam ediyor. Girişsiz ziyaretçide de
        çiziliyor ama içeriği değişiyor — orada "giriş yap / kurumsal kayıt"
        diyor.
      */}
      <Section aria-labelledby="hizli-siparis-baslik" className="!py-8 sm:!py-10">
        <h2 id="hizli-siparis-baslik" className="sr-only">
          Hızlı sipariş
        </h2>
        <QuickOrder />
      </Section>

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
      {/*
        `id="hizmetler"`: kaldırılan `/hizmetler` sayfasının kalıcı
        yönlendirme hedefi burası (W-08, `next.config.ts`). Bağlantı
        çapasız kalsaydı, eski adresten gelen ziyaretçi ana sayfanın en
        üstüne düşer ve aradığını bulamazdı.
      */}
      <Section id="hizmetler" tone="muted" aria-labelledby="hizmetler-baslik">
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
                /*
                  Hizmet detay sayfaları kaldırıldı (W-08). Kart artık
                  teklif formuna, hizmet önceden seçili gelecek şekilde
                  gidiyor — ziyaretçinin bir sonraki adımı zaten buydu;
                  detay sayfası araya giren bir duraktı.
                */
                href={`/teklif-al?hizmet=${service.slug}`}
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
            <Link href="/teklif-al">
              Size uygun düzeni konuşalım
              <ArrowRight strokeWidth={1.75} aria-hidden="true" />
            </Link>
          </Button>
        </div>
      </Section>

      {/* ── 4. Nasıl çalışıyoruz ──────────────────────────────────────────── */}
      <Section tone="dark" aria-labelledby="surec-baslik">
        <div className="grid gap-12 lg:grid-cols-[1fr_1.1fr] lg:items-start lg:gap-16">
          <div className="lg:sticky lg:top-28">
            <SectionHeading
              id="surec-baslik"
              eyebrow="Nasıl çalışıyoruz"
              title="İlk telefondan ilk servise"
              description="Dört adım. Hepsinde kimin ne yapacağı belli, sürpriz sevmiyoruz."
            />
            <div className="mt-8 overflow-hidden rounded-md">
              <Image
                alt={PHOTO.mutfakEkip.alt}
                src={PHOTO.mutfakEkip.src}
                width={1400}
                height={933}
                sizes="(max-width: 1024px) 100vw, 460px"
                className="h-full w-full bld-photo"
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
              className="mt-8 aspect-4/5 w-full rounded-md bld-photo"
            />
            <Image
              alt={PHOTO.kaliteEldiven.alt}
              src={PHOTO.kaliteEldiven.src}
              width={1400}
              height={933}
              sizes="(max-width: 1024px) 45vw, 280px"
              className="aspect-4/5 w-full rounded-md bld-photo"
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
              <Link href="/kurumsal#kalite">
                Zincirin tamamı
                <ArrowRight strokeWidth={1.75} aria-hidden="true" />
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
                href={`/teklif-al?hizmet=${sector.serviceSlug}`}
                image={sectorImage(sector.slug)}
              />
            </div>
          ))}
        </div>

        <div className="mt-10">
          <Button asChild variant="outline" size="lg">
            <Link href="/kurumsal#alanlar">
              Tüm alanlar
              <ArrowRight strokeWidth={1.75} aria-hidden="true" />
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
                <AccordionTrigger className="text-left text-title font-medium">
                  {item.question}
                </AccordionTrigger>
                <AccordionContent className="text-body text-muted-foreground">
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

      {/*
        SEPET ÇUBUĞU (W-10). "Bugün mutfakta" bölümünden sepete ekleme
        yapılabildiği için, eklenenin nereye gittiğinin görünmesi gerekiyor.
        Sepet boşken hiç çizilmiyor — bu yüzden ürün eklemeyen kurumsal
        ziyaretçi hiçbir şey görmüyor.

        Mobilde alta sabit (`lg:hidden`); masaüstünde header'daki sepet
        rozeti aynı işi görüyor — o da v2.0'da sepet doluyken kurumsal
        sayfalarda görünür oldu (`HeaderActions`). İki gösterge birden
        aynı ekranda fazlalık olurdu.
      */}
      <CartSummaryBar />
    </>
  );
}
