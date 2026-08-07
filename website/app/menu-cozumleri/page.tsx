import Link from 'next/link';
import { ArrowRight, Flower2, Leaf, Snowflake, Sun } from 'lucide-react';
import { JsonLd } from '@/components/json-ld';
import { MenuSolutionCard } from '@/components/site/cards';
import { CtaBand } from '@/components/site/cta-band';
import { PageHero } from '@/components/site/page-hero';
import { Section, SectionHeading } from '@/components/site/section';
import { Button } from '@/components/ui/button';
import { PRIMARY_CTA } from '@/content/navigation';
import { fetchSiteContent } from '@/lib/api/site-content';
import { breadcrumbJsonLd, pageMetadata } from '@/lib/seo';
import { PHOTO, menuSolutionImage } from '@/lib/site-images';
import type { LucideIcon } from 'lucide-react';
import type { Crumb } from '@/components/site/page-hero';

/**
 * Menü çözümleri.
 *
 * Bu sayfa bir sipariş ekranı DEĞİL: sepet, fiyat ve "ekle" butonu yok.
 * Amacı, teklif görüşmesinden önce menü kurgusunun nasıl düşünüldüğünü
 * göstermek. Günlük sipariş akışı `/menu` altında yaşıyor.
 *
 * Kurgular admin panelinden geliyor; API kapalıysa yedek kurgular basılır.
 */

const CRUMBS: readonly Crumb[] = [{ href: '/menu-cozumleri', label: 'Menü Çözümleri' }];

/** Mevsim adına göre ikon; eşleşme bulunamazsa bant ikonsuz basılır. */
const SEASON_ICONS: Record<string, LucideIcon> = {
  İlkbahar: Flower2,
  Yaz: Sun,
  Sonbahar: Leaf,
  Kış: Snowflake,
};

export async function generateMetadata() {
  const { brand, menus } = await fetchSiteContent();

  return pageMetadata({
    title: 'Menü Çözümleri',
    description: `Örnek menü kurguları: ${menus.solutions.map((solution) => solution.title).join(', ')}.`,
    path: '/menu-cozumleri',
    brandName: brand.name,
  });
}

export default async function MenuSolutionsPage() {
  const { menus } = await fetchSiteContent();

  return (
    <>
      <JsonLd data={breadcrumbJsonLd(CRUMBS)} />

      <PageHero
        crumbs={CRUMBS}
        eyebrow="Menü çözümleri"
        title="Menüyü günlük düzeniniz belirler"
        description="Aşağıdakiler örnek. Bir menünün hangi kaplardan kurulduğunu ve neye bakıldığını gösteriyor; sizinki teklif aşamasında birlikte çıkacak."
        image={PHOTO.kahvalti.src}
      />

      <Section aria-labelledby="menu-kurgulari">
        <SectionHeading
          id="menu-kurgulari"
          eyebrow="Örnekler"
          title="Altı ayrı kurgu"
          description="Her biri başka bir mola süresine, başka bir kalabalığa ve başka bir servis hızına göre."
        />

        <div className="mt-12 grid gap-6 lg:grid-cols-2">
          {menus.solutions.map((solution) => (
            <MenuSolutionCard
              key={solution.slug}
              title={solution.title}
              summary={solution.summary}
              audience={solution.audience}
              image={menuSolutionImage(solution.slug)}
            >
              {/* Kap listesi tanım listesi: solda kabın adı, sağda örnekler.
                  Örnekler nokta ile ayrılmış tek satır — tablo görünümü
                  sipariş ekranını çağrıştırırdı. */}
              <dl className="space-y-4">
                {solution.courses.map((course) => (
                  <div key={course.label} className="sm:grid sm:grid-cols-[9rem_1fr] sm:gap-4">
                    <dt className="text-sm font-semibold">{course.label}</dt>
                    <dd className="mt-1 text-sm/6 text-muted-foreground sm:mt-0">
                      {course.examples.join(' · ')}
                    </dd>
                  </div>
                ))}
              </dl>

              <p className="mt-5 border-t pt-5 text-sm/6 text-muted-foreground italic">
                {solution.principle}
              </p>
            </MenuSolutionCard>
          ))}
        </div>
      </Section>

      {/* Koyu bant: dört mevsim tek şerit halinde, sayfanın ortasında nefes alanı. */}
      <Section tone="olive" aria-labelledby="mevsim-yaklasimi">
        <div className="max-w-2xl">
          <p className="text-xs font-semibold tracking-[0.14em] uppercase opacity-80">Mevsim</p>
          <h2
            id="mevsim-yaklasimi"
            className="mt-3 font-display text-3xl font-semibold tracking-tight sm:text-4xl"
          >
            Menü mevsime göre değişir
          </h2>
          <p className="mt-4 text-base/7 opacity-85">
            Aynı liste bütün yıl dönmüyor. Sebzenin mevsimi geldiğinde menü de yerini değiştiriyor.
          </p>
        </div>

        <ul className="mt-12 grid gap-8 sm:grid-cols-2 lg:grid-cols-4">
          {menus.seasonal.map((entry) => {
            const Icon = SEASON_ICONS[entry.season];
            return (
              <li key={entry.season} className="border-t border-white/20 pt-6">
                {Icon && (
                  <span
                    aria-hidden="true"
                    className="grid size-10 place-items-center rounded-xl bg-white/10"
                  >
                    <Icon className="size-5" />
                  </span>
                )}
                <h3 className="mt-4 font-display text-lg font-semibold tracking-tight">
                  {entry.season}
                </h3>
                <p className="mt-2 text-sm/6 opacity-80">{entry.note}</p>
              </li>
            );
          })}
        </ul>
      </Section>

      <Section tone="muted" aria-labelledby="fiyat-neden-yok">
        <div className="grid gap-10 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)] lg:gap-16">
          <SectionHeading
            id="fiyat-neden-yok"
            eyebrow="Fiyatlandırma"
            title="Neden fiyat yazmıyor?"
          />

          <div>
            <p className="text-base/7">
              Kişi sayısı, haftada kaç gün, kaç kap, nereye ve nasıl servis — beşi birden fiyatı
              değiştiriyor. Size uymayan bir rakam yazmak yerine ihtiyacınıza göre çıkarıyoruz.
            </p>
            <p className="mt-4 text-base/7 text-muted-foreground">
              Menü önerisi ve fiyat aynı cevapta geliyor. Menüyü görmeden karar vermeniz
              gerekmiyor.
            </p>

            <div className="mt-8 flex flex-wrap gap-3">
              <Button asChild size="lg">
                <Link href={PRIMARY_CTA.href}>
                  Teklif alın
                  <ArrowRight aria-hidden="true" />
                </Link>
              </Button>
              <Button asChild size="lg" variant="outline">
                <Link href="/hizmetler">Hizmetlere bakın</Link>
              </Button>
            </div>
          </div>
        </div>
      </Section>

      <CtaBand />
    </>
  );
}
