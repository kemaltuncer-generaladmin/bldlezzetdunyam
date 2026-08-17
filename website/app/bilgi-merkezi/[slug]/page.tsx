import Image from 'next/image';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ArrowLeft } from 'lucide-react';
import { JsonLd } from '@/components/json-ld';
import { PostCard } from '@/components/site/cards';
import { CtaBand } from '@/components/site/cta-band';
import { PageHero } from '@/components/site/page-hero';
import { Section, SectionHeading } from '@/components/site/section';
import { fetchSiteContent, findPost } from '@/lib/api/site-content';
import { articleJsonLd, breadcrumbJsonLd, pageMetadata } from '@/lib/seo';
import { postImage } from '@/lib/site-images';
import type { Crumb } from '@/components/site/page-hero';

/**
 * Bilgi merkezi — yazı detayı.
 *
 * ## Gövde HTML'i neden burada temizlenmiyor?
 *
 * Temizlik `lib/api/site-content.ts` içindeki zod dönüşümünde, TEK ÇAĞRI
 * YERİNDE yapılıyor ve sonucu ISR önbelleğine giriyor. Bu sayfaya ulaşan
 * `bodyHtml` izin listesinden geçmiş oluyor; burada ikinci bir temizlik
 * çalıştırmak her render'a maliyet eklerdi ve — asıl önemlisi — temizliğin
 * "hatırlanması gereken bir adım" hâline gelmesi demek olurdu.
 *
 * ## Gövdesi olmayan yazı
 *
 * Panelde başlık ve özet girilip gövde boş bırakılabiliyor. O durumda özet
 * tek başına basılıyor: boş bir sayfa göstermek yerine elimizdeki tek doğru
 * metni gösteriyoruz.
 */

export const revalidate = 300;

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const { brand, posts } = await fetchSiteContent();
  const post = findPost(posts, slug);

  /*
   * Bulunamayan yazı için `notFound()` ÇAĞRILMIYOR: `generateMetadata`
   * içinde atılan yönlendirme, sayfa gövdesindeki 404'ü de tetikler ama
   * hata mesajı okunmaz hâle gelir. Metadata'yı dizine girmeyecek şekilde
   * döndürüp kararı gövdeye bırakmak, iki yerde tek bir davranış üretiyor.
   */
  if (!post) {
    return { title: 'Yazı bulunamadı', robots: { index: false, follow: false } };
  }

  return pageMetadata({
    title: post.title,
    description: post.description,
    path: `/bilgi-merkezi/${post.slug}`,
    brandName: brand.name,
  });
}

export default async function YaziPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const { brand, posts } = await fetchSiteContent();
  const post = findPost(posts, slug);

  if (!post) notFound();

  const crumbs: readonly Crumb[] = [
    { href: '/bilgi-merkezi', label: 'Bilgi Merkezi' },
    { href: `/bilgi-merkezi/${post.slug}`, label: post.title },
  ];

  const image = postImage(post.slug);
  const others = posts.filter((entry) => entry.slug !== post.slug).slice(0, 3);

  return (
    <>
      <JsonLd data={breadcrumbJsonLd(crumbs)} />
      <JsonLd
        data={articleJsonLd({
          title: post.title,
          description: post.description,
          path: `/bilgi-merkezi/${post.slug}`,
          publishedAt: post.publishedAt,
          brandName: brand.name,
        })}
      />

      <PageHero
        crumbs={crumbs}
        eyebrow={post.category}
        title={post.title}
        description={post.description || undefined}
        image={image}
      />

      <Section>
        <article className="mx-auto max-w-3xl">
          <p className="text-caption text-muted-foreground">
            <time dateTime={post.publishedAt}>
              {new Date(post.publishedAt).toLocaleDateString('tr-TR', {
                day: 'numeric',
                month: 'long',
                year: 'numeric',
              })}
            </time>
            <span aria-hidden="true"> · </span>
            {post.readingMinutes} dakika okuma
          </p>

          {image && (
            <div className="relative mt-8 aspect-video overflow-hidden rounded-md bg-muted">
              {/* Fotoğraf dekoratif: başlık ve özet aynı bilgiyi metin olarak veriyor. */}
              <Image
                alt=""
                src={image}
                fill
                sizes="(max-width: 768px) 100vw, 768px"
                className="bld-photo"
              />
            </div>
          )}

          {post.bodyHtml ? (
            <div
              className="bld-prose mt-10"
              // Temizlik zod dönüşümünde yapıldı (`lib/api/site-content.ts`):
              // izin listesi dışındaki her etiket, her `on*`, `style` ve
              // `https:` olmayan her adres oraya varmadan düşüyor.
              dangerouslySetInnerHTML={{ __html: post.bodyHtml }}
            />
          ) : (
            <div className="bld-prose mt-10">
              <p>{post.description}</p>
            </div>
          )}

          <p className="mt-12 border-t pt-6">
            <Link
              href="/bilgi-merkezi"
              className="inline-flex min-h-11 items-center gap-2 text-label text-primary-text"
            >
              <ArrowLeft strokeWidth={1.75} aria-hidden="true" className="size-4" />
              Tüm yazılar
            </Link>
          </p>
        </article>
      </Section>

      {others.length > 0 && (
        <Section tone="muted" aria-labelledby="diger-yazilar-baslik">
          <SectionHeading id="diger-yazilar-baslik" eyebrow="Devamı" title="Diğer yazılar" />

          <ul className="mt-10 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {others.map((entry) => (
              <li key={entry.slug} className="h-full">
                <PostCard
                  href={`/bilgi-merkezi/${entry.slug}`}
                  category={entry.category}
                  title={entry.title}
                  description={entry.description}
                  publishedAt={entry.publishedAt}
                  readingMinutes={entry.readingMinutes}
                  image={postImage(entry.slug)}
                />
              </li>
            ))}
          </ul>
        </Section>
      )}

      <CtaBand />
    </>
  );
}
