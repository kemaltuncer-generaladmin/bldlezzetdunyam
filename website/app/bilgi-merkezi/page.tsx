import type { Metadata } from 'next';
import { JsonLd } from '@/components/json-ld';
import { PostCard } from '@/components/site/cards';
import { CtaBand } from '@/components/site/cta-band';
import { PageHero, type Crumb } from '@/components/site/page-hero';
import { Section, SectionHeading } from '@/components/site/section';
import { fetchSiteContent } from '@/lib/api/site-content';
import { breadcrumbJsonLd, pageMetadata } from '@/lib/seo';

const TITLE = 'Bilgi Merkezi';
const DESCRIPTION =
  'Catering firması seçimi, menü planlaması, hijyen zinciri ve organizasyon lojistiği üzerine yazılar. Teklif almadan önce netleştirilmesi gereken başlıklar.';

const CRUMBS: readonly Crumb[] = [{ href: '/bilgi-merkezi', label: TITLE }];

export async function generateMetadata(): Promise<Metadata> {
  const { brand } = await fetchSiteContent();

  return pageMetadata({
    title: TITLE,
    description: DESCRIPTION,
    path: '/bilgi-merkezi',
    brandName: brand.name,
  });
}

export default async function BilgiMerkeziPage() {
  const { posts } = await fetchSiteContent();

  /**
   * Kategori listesi yazılardan türetiliyor, elle yazılmıyor: panelde yeni bir
   * kategori kullanıldığında burada kendiliğinden beliriyor.
   *
   * Kategoriler bağlantı değil, etiket: kategori arşiv sayfası yok ve olmayan
   * bir adrese bağlantı vermek 404 üretirdi.
   */
  const categories: readonly string[] = [...new Set(posts.map((post) => post.category))];

  return (
    <>
      <JsonLd data={breadcrumbJsonLd(CRUMBS)} />

      <PageHero crumbs={CRUMBS} title={TITLE} description={DESCRIPTION}>
        <ul className="flex flex-wrap gap-2">
          {categories.map((category) => (
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
          {posts.map((post) => (
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
