import type { Metadata } from 'next';
import { JsonLd } from '@/components/json-ld';
import { PostCard } from '@/components/site/cards';
import { CtaBand } from '@/components/site/cta-band';
import { PageHero, type Crumb } from '@/components/site/page-hero';
import { Section, SectionHeading } from '@/components/site/section';
import { fetchSiteContent } from '@/lib/api/site-content';
import { PHOTO, postImage } from '@/lib/site-images';
import { breadcrumbJsonLd, pageMetadata } from '@/lib/seo';

const TITLE = 'Bilgi Merkezi';
const DESCRIPTION =
  'Firma seçimi, menü planlaması, hijyen ve organizasyon lojistiği üzerine yazdıklarımız. Teklif istemeden önce okunursa görüşme kısalıyor.';

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

      <PageHero crumbs={CRUMBS} title={TITLE} description={DESCRIPTION} image={PHOTO.mutfakTencere.src}>
        <ul className="flex flex-wrap gap-2">
          {categories.map((category) => (
            <li
              key={category}
              className="rounded-full border border-cream/30 px-3 py-1 text-xs font-semibold text-cream"
            >
              {category}
            </li>
          ))}
        </ul>
      </PageHero>

      <Section aria-labelledby="tum-yazilar">
        <SectionHeading
          id="tum-yazilar"
          title="Tüm yazılar"
          description="Aynı soruları çok duyduk, oturup yazdık."
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
              image={postImage(post.slug)}
            />
          ))}
        </div>
      </Section>

      <CtaBand
        title="Aradığınız cevap burada yoksa"
        description="Sorun, cevaplayalım. Teklif formunda açıklama alanı var."
      />
    </>
  );
}
