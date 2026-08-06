import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { Lightbulb } from 'lucide-react';
import { JsonLd } from '@/components/json-ld';
import { PostCard } from '@/components/site/cards';
import { CtaBand } from '@/components/site/cta-band';
import { PageHero, type Crumb } from '@/components/site/page-hero';
import { Section, SectionHeading } from '@/components/site/section';
import { POSTS, POSTS_BY_DATE, findPost, type Post, type PostBlock } from '@/content/posts';
import { articleJsonLd, breadcrumbJsonLd, pageMetadata } from '@/lib/seo';

/** Yazı sayısı sabit ve küçük; hepsi derleme anında üretilir. */
export function generateStaticParams(): { slug: string }[] {
  return POSTS.map((post) => ({ slug: post.slug }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const post = findPost(slug);

  // Bilinmeyen slug'da sayfa zaten `notFound()` çağırıyor; metadata da buna
  // uygun olsun ki 404 sayfası son yazının başlığını taşımasın.
  if (!post) return { title: 'Yazı bulunamadı' };

  return pageMetadata({
    title: post.title,
    description: post.description,
    path: `/bilgi-merkezi/${post.slug}`,
  });
}

const DATE_FORMAT = new Intl.DateTimeFormat('tr-TR', {
  day: 'numeric',
  month: 'long',
  year: 'numeric',
});

/**
 * İlgili yazılar: önce aynı kategoriden olanlar, yetmezse en yeni yazılarla
 * tamamlanır. Böylece tek yazılık bir kategoride bile bölüm boş kalmıyor.
 */
function relatedPosts(current: Post): readonly Post[] {
  const others = POSTS_BY_DATE.filter((post) => post.slug !== current.slug);
  const sameCategory = others.filter((post) => post.category === current.category);
  const rest = others.filter((post) => post.category !== current.category);
  return [...sameCategory, ...rest].slice(0, 3);
}

/**
 * Gövde render'ı.
 *
 * Blok dizisi HTML'e değil, tipli bileşenlere çevriliyor: `dangerouslySetInnerHTML`
 * yok, dolayısıyla içerik kaynağı bir gün CMS'e taşınsa bile enjeksiyon yüzeyi
 * açılmıyor. Başlık bloğu her zaman `h2` — sayfadaki tek `h1` PageHero'da.
 */
function PostBody({ blocks }: { blocks: readonly PostBlock[] }) {
  return (
    <div className="bld-prose">
      {blocks.map((block, index) => {
        const key = `${block.kind}-${index}`;

        switch (block.kind) {
          case 'heading':
            return <h2 key={key}>{block.text}</h2>;

          case 'list':
            return (
              <ul key={key}>
                {block.items.map((item) => (
                  <li key={item}>{item}</li>
                ))}
              </ul>
            );

          case 'callout':
            return (
              <aside
                key={key}
                className="my-8 flex gap-4 rounded-r-xl border-l-4 border-primary bg-accent px-5 py-4"
              >
                <Lightbulb aria-hidden="true" className="mt-1 size-5 shrink-0 text-primary" />
                <p>{block.text}</p>
              </aside>
            );

          case 'paragraph':
            return <p key={key}>{block.text}</p>;
        }
      })}
    </div>
  );
}

export default async function YaziPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const post = findPost(slug);
  if (!post) notFound();

  const path = `/bilgi-merkezi/${post.slug}`;
  const crumbs: readonly Crumb[] = [
    { href: '/bilgi-merkezi', label: 'Bilgi Merkezi' },
    { href: path, label: post.title },
  ];
  const related = relatedPosts(post);

  return (
    <>
      <JsonLd data={breadcrumbJsonLd(crumbs)} />
      <JsonLd
        data={articleJsonLd({
          title: post.title,
          description: post.description,
          path,
          publishedAt: post.publishedAt,
        })}
      />

      <PageHero
        crumbs={crumbs}
        eyebrow={post.category}
        title={post.title}
        description={post.description}
      >
        <p className="text-sm opacity-70">
          <time dateTime={post.publishedAt}>{DATE_FORMAT.format(new Date(post.publishedAt))}</time>
          <span aria-hidden="true"> · </span>
          {post.readingMinutes} dakika okuma
        </p>
      </PageHero>

      <Section>
        {/* Ölçü satır uzunluğu için dar kolon; gövde metni tam genişlikte okunmaz. */}
        <article className="max-w-2xl">
          <PostBody blocks={post.body} />
        </article>
      </Section>

      {related.length > 0 && (
        <Section tone="muted" aria-labelledby="ilgili-yazilar">
          <SectionHeading
            id="ilgili-yazilar"
            title="İlgili yazılar"
            description="Aynı konuyu farklı açıdan ele alan diğer yazılar."
          />

          <div className="mt-10 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {related.map((item) => (
              <PostCard
                key={item.slug}
                href={`/bilgi-merkezi/${item.slug}`}
                category={item.category}
                title={item.title}
                description={item.description}
                publishedAt={item.publishedAt}
                readingMinutes={item.readingMinutes}
              />
            ))}
          </div>
        </Section>
      )}

      <CtaBand />
    </>
  );
}
