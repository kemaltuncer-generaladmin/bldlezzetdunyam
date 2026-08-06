import type { Metadata } from 'next';
import { JsonLd } from '@/components/json-ld';
import { PostCard } from '@/components/site/cards';
import { CtaBand } from '@/components/site/cta-band';
import { PageHero, type Crumb } from '@/components/site/page-hero';
import { Section, SectionHeading } from '@/components/site/section';
import { POSTS_BY_DATE } from '@/content/posts';
import { breadcrumbJsonLd, pageMetadata } from '@/lib/seo';

const TITLE = 'Bilgi Merkezi';
const DESCRIPTION =
  'Catering firması seçimi, menü planlaması, hijyen zinciri ve organizasyon lojistiği üzerine yazılar. Teklif almadan önce netleştirilmesi gereken başlıklar.';

const CRUMBS: readonly Crumb[] = [{ href: '/bilgi-merkezi', label: TITLE }];

export const metadata: Metadata = pageMetadata({
  title: TITLE,
  description: DESCRIPTION,
  path: '/bilgi-merkezi',
});

/**
 * Kategori listesi yazılardan türetiliyor, elle yazılmıyor: `content/posts.ts`
 * içine yeni bir kategori girdiğinde burada kendiliğinden beliriyor.
 *
 * Kategoriler bağlantı değil, etiket: kategori arşiv sayfası yok ve olmayan
 * bir adrese bağlantı vermek 404 üretirdi.
 */
const CATEGORIES: readonly string[] = [...new Set(POSTS_BY_DATE.map((post) => post.category))];

export default function BilgiMerkeziPage() {
  return (
    <>
      <JsonLd data={breadcrumbJsonLd(CRUMBS)} />

      <PageHero crumbs={CRUMBS} title={TITLE} description={DESCRIPTION}>
        <ul className="flex flex-wrap gap-2">
          {CATEGORIES.map((category) => (
            <li
              key={category}
              className="rounded-full border border-primary/25 px-3 py-1 text-xs font-semibold text-primary"
            >
              {category}
            </li>
          ))}
        </ul>
      </PageHero>

      <Section tone="muted" aria-labelledby="tum-yazilar">
        <SectionHeading
          id="tum-yazilar"
          title="Tüm yazılar"
          description="Sık sorulan konuları tek tek cevaplamak yerine yazıya döktük; teklif görüşmesinden önce okunduğunda konuşmayı kısaltıyor."
        />

        <div className="mt-10 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {POSTS_BY_DATE.map((post) => (
            <PostCard
              key={post.slug}
              href={`/bilgi-merkezi/${post.slug}`}
              category={post.category}
              title={post.title}
              description={post.description}
              publishedAt={post.publishedAt}
              readingMinutes={post.readingMinutes}
            />
          ))}
        </div>
      </Section>

      <CtaBand
        title="Yazıda cevabını bulamadığınız bir konu mu var?"
        description="Kişi sayınızı ve hizmet türünüzü iletin; menü önerisi ve fiyatlandırmayla birlikte dönelim."
      />
    </>
  );
}
