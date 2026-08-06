import Link from 'next/link';
import { ArrowRight, Flower2, Leaf, Snowflake, Sun } from 'lucide-react';
import { JsonLd } from '@/components/json-ld';
import { MenuSolutionCard } from '@/components/site/cards';
import { CtaBand } from '@/components/site/cta-band';
import { PageHero } from '@/components/site/page-hero';
import { Section, SectionHeading } from '@/components/site/section';
import { Button } from '@/components/ui/button';
import { PRIMARY_CTA } from '@/content/navigation';
import { MENU_SOLUTIONS, SEASONAL_APPROACH } from '@/content/menus';
import { breadcrumbJsonLd, pageMetadata } from '@/lib/seo';
import type { LucideIcon } from 'lucide-react';
import type { Crumb } from '@/components/site/page-hero';

/**
 * Menü çözümleri.
 *
 * Bu sayfa bir sipariş ekranı DEĞİL: sepet, fiyat ve "ekle" butonu yok.
 * Amacı, teklif görüşmesinden önce menü kurgusunun nasıl düşünüldüğünü
 * göstermek. Günlük sipariş akışı `/menu` altında yaşıyor.
 */

const CRUMBS: readonly Crumb[] = [{ href: '/menu-cozumleri', label: 'Menü Çözümleri' }];

/** Mevsim adına göre ikon; eşleşme bulunamazsa bant ikonsuz basılır. */
const SEASON_ICONS: Record<string, LucideIcon> = {
  İlkbahar: Flower2,
  Yaz: Sun,
  Sonbahar: Leaf,
  Kış: Snowflake,
};

export const metadata = pageMetadata({
  title: 'Menü Çözümleri',
  description:
    'Kurumsal dört kap, personel üç kap, öğrenci menüsü, kahvaltı ve ikram paketleri, davet menüsü ve özel beslenme alternatifleri için örnek menü kurguları.',
  path: '/menu-cozumleri',
});

export default function MenuSolutionsPage() {
  return (
    <>
      <JsonLd data={breadcrumbJsonLd(CRUMBS)} />

      <PageHero
        crumbs={CRUMBS}
        eyebrow="Menü Çözümleri"
        title="Menü, kurumun günlük düzenine göre kurulur"
        description="Aşağıdaki kurgular, bir menünün hangi kaplardan oluştuğunu ve neye göre planlandığını göstermek için hazırlanmış örneklerdir. Uygulanacak menü, teklif aşamasında sizinle birlikte belirlenir."
      />

      <Section aria-labelledby="menu-kurgulari">
        <SectionHeading
          id="menu-kurgulari"
          eyebrow="Örnek kurgular"
          title="Menü çözümleri"
          description="Her kurgu farklı bir öğün molası, farklı bir katılımcı profili ve farklı bir servis hızı için düşünülmüştür."
        />

        <div className="mt-12 grid gap-5 lg:grid-cols-2">
          {MENU_SOLUTIONS.map((solution) => (
            <MenuSolutionCard
              key={solution.slug}
              title={solution.title}
              summary={solution.summary}
              audience={solution.audience}
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
            Aynı menü yıl boyunca tekrar etmez; sebzenin mevsiminde olduğu dönemde öğünler yeniden
            dengelenir.
          </p>
        </div>

        <ul className="mt-12 grid gap-8 sm:grid-cols-2 lg:grid-cols-4">
          {SEASONAL_APPROACH.map((entry) => {
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

      <Section tone="muted" aria-labelledby="planlama-ilkeleri">
        <SectionHeading
          id="planlama-ilkeleri"
          eyebrow="Planlama"
          title="Her menüyü belirleyen ilke"
          description="Bir menü kurgusunu diğerinden ayıran şey kap sayısı değil, hangi kısıtı önceliklendirdiğidir."
        />

        <dl className="mt-12 space-y-6">
          {MENU_SOLUTIONS.map((solution) => (
            <div
              key={solution.slug}
              className="border-t pt-6 md:grid md:grid-cols-[16rem_1fr] md:gap-10"
            >
              <dt className="font-display text-lg font-semibold tracking-tight">
                {solution.title}
              </dt>
              <dd className="mt-2 max-w-2xl text-base/7 text-muted-foreground md:mt-0">
                {solution.principle}
              </dd>
            </div>
          ))}
        </dl>
      </Section>

      <Section aria-labelledby="fiyat-neden-yok">
        <div className="grid gap-10 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)] lg:gap-16">
          <SectionHeading
            id="fiyat-neden-yok"
            eyebrow="Fiyatlandırma"
            title="Bu sayfada neden fiyat yok?"
          />

          <div>
            <p className="text-base/7">
              Catering fiyatı tek bir liste rakamına sığmıyor: kişi sayısı, haftalık hizmet günü,
              kap sayısı, teslim konumu ve servis biçimi birlikte belirliyor. Gerçek koşullarınıza
              karşılık gelmeyen bir rakam yayınlamak yerine, ihtiyacınıza göre teklif hazırlıyoruz.
            </p>
            <p className="mt-4 text-base/7 text-muted-foreground">
              Menü önerisi ve fiyatlandırma aynı yanıtta gelir; menüyü görmeden karar vermeniz
              gerekmez.
            </p>

            <div className="mt-8 flex flex-wrap gap-3">
              <Button asChild size="lg">
                <Link href={PRIMARY_CTA.href}>
                  İhtiyacınıza özel teklif alın
                  <ArrowRight aria-hidden="true" />
                </Link>
              </Button>
              <Button asChild size="lg" variant="outline">
                <Link href="/hizmetler">Hizmetleri inceleyin</Link>
              </Button>
            </div>
          </div>
        </div>
      </Section>

      <CtaBand />
    </>
  );
}
