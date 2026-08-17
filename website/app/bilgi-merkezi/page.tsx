import { Newspaper } from 'lucide-react';
import { JsonLd } from '@/components/json-ld';
import { EmptyState } from '@/components/empty-state';
import { PostCard } from '@/components/site/cards';
import { CtaBand } from '@/components/site/cta-band';
import { PageHero } from '@/components/site/page-hero';
import { Section } from '@/components/site/section';
import { fetchSiteContent } from '@/lib/api/site-content';
import { breadcrumbJsonLd, pageMetadata } from '@/lib/seo';
import { PHOTO, postImage } from '@/lib/site-images';
import type { Crumb } from '@/components/site/page-hero';

/**
 * Bilgi merkezi — yazı listesi.
 *
 * ## Adres neden aynı?
 *
 * Blog v2.0'da kaldırılmış ve `/bilgi-merkezi` ile `/bilgi-merkezi/{slug}`
 * **kalıcı (308)** olarak `/kurumsal`'a yönlendirilmişti. Yönlendirmeler
 * silindi ama 308'i tarayıcı KALICI önbelleğe alır: o adresi daha önce
 * ziyaret etmiş bir tarayıcı sunucuya hiç sormadan `/kurumsal`'a gidecek ve
 * bunu temizlemenin uzaktan bir yolu yok. Bu yüzden `/kurumsal` sayfasında
 * buraya belirgin bir bağlantı duruyor — etkilenen ziyaretçinin geri dönüş
 * yolu o.
 *
 * ## Boş liste bir arıza değil
 *
 * Yedek içerik BİLEREK boş (`content/posts.ts`): panelde silinmiş bir yazıyı
 * repodan yeniden yayınlamak içerik yalanı olurdu. Dolayısıyla hem "panelde
 * henüz yazı yok" hem de "API kapalı" durumunda burası boş çıkar ve dürüst
 * bir boş durum çizer — uydurma bir arşiv değil.
 */

const CRUMBS: readonly Crumb[] = [{ href: '/bilgi-merkezi', label: 'Bilgi Merkezi' }];

export const revalidate = 300;

export async function generateMetadata() {
  const { brand } = await fetchSiteContent();

  return pageMetadata({
    title: 'Bilgi Merkezi',
    description:
      'Toplu yemek, catering ve organizasyon üzerine yazılar: menü planlaması, hijyen, firma seçimi ve sahadan notlar.',
    path: '/bilgi-merkezi',
    brandName: brand.name,
  });
}

export default async function BilgiMerkeziPage() {
  const { posts } = await fetchSiteContent();

  return (
    <>
      <JsonLd data={breadcrumbJsonLd(CRUMBS)} />

      <PageHero
        crumbs={CRUMBS}
        eyebrow="Bilgi merkezi"
        title="Sahadan notlar"
        description="Toplu yemek işinin gündelik soruları: kaç kişiye ne kadar yemek gider, menü nasıl kurulur, hijyen nerede başlar."
        image={PHOTO.mutfakSef.src}
      />

      <Section aria-labelledby="yazilar-baslik">
        <h2 id="yazilar-baslik" className="sr-only">
          Yazılar
        </h2>

        {posts.length === 0 ? (
          <EmptyState
            icon={<Newspaper strokeWidth={1.75} aria-hidden="true" />}
            title="Henüz yayınlanmış yazı yok"
            message="Bu bölüm hazırlanıyor. Aklınızdaki soruyu beklemeden sorabilirsiniz; teklif formundaki açıklama alanı tam olarak bunun için var."
            actionHref="/teklif-al"
            actionLabel="Teklif al"
          />
        ) : (
          <ul className="grid bld-reveal gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {posts.map((post) => (
              <li key={post.slug} className="h-full">
                <PostCard
                  href={`/bilgi-merkezi/${post.slug}`}
                  category={post.category}
                  title={post.title}
                  description={post.description}
                  publishedAt={post.publishedAt}
                  readingMinutes={post.readingMinutes}
                  // Panelden eklenen yeni bir yazının dosyası olmaz; `null`
                  // döner ve kart fotoğrafsız düzene geçer.
                  image={postImage(post.slug)}
                />
              </li>
            ))}
          </ul>
        )}
      </Section>

      <CtaBand />
    </>
  );
}
