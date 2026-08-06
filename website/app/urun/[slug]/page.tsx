import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { AddToCartForm } from '@/components/add-to-cart-form';
import { CartSummaryBar } from '@/components/cart-summary';
import { IconChevronRight, IconInfo } from '@/components/icons';
import { JsonLd } from '@/components/json-ld';
import { OrderingClosedBanner } from '@/components/ordering-banner';
import { ProductCard } from '@/components/product-card';
import { ProductImage } from '@/components/product-image';
import { ProductOptions } from '@/components/product-options';
import { SITE_URL } from '@/lib/api/client';
import {
  fetchCatalog,
  findCategoryOf,
  findItemById,
  flattenItems,
  isOrderingOpen,
} from '@/lib/api/catalog';
import { formatPrice, schemaOrgPrice } from '@/lib/format';
import { menuIdFromSlug, productSlug } from '@/lib/slug';
import type { MenuItem } from '@/lib/api/types';

/** SSR/ISR — SEO zorunluluğu (`docs/06` §2). */
export const revalidate = 60;
export const dynamicParams = true;

type Params = { slug: string };

/**
 * Ürün adresleri derleme zamanında önceden üretilir. API o an erişilemezse
 * derleme kırılmaz; sayfalar ilk istekte üretilip önbelleklenir.
 */
export async function generateStaticParams(): Promise<Params[]> {
  try {
    const { categories } = await fetchCatalog();
    return flattenItems(categories).map((item) => ({ slug: productSlug(item) }));
  } catch {
    return [];
  }
}

async function loadItem(slug: string): Promise<{ item: MenuItem; canonicalSlug: string } | null> {
  const menuId = menuIdFromSlug(slug);
  if (menuId === null) return null;

  const { categories } = await fetchCatalog();
  const item = findItemById(categories, menuId);
  if (!item) return null;

  return { item, canonicalSlug: productSlug(item) };
}

export async function generateMetadata({ params }: { params: Promise<Params> }): Promise<Metadata> {
  const { slug } = await params;

  let found: Awaited<ReturnType<typeof loadItem>> = null;
  try {
    found = await loadItem(slug);
  } catch {
    found = null;
  }

  if (!found) {
    return { title: 'Ürün bulunamadı', robots: { index: false, follow: true } };
  }

  const { item, canonicalSlug } = found;
  const description =
    item.description ??
    `${item.name} — Benim Lezzet Dünyam catering menüsünden ${formatPrice(item.price)} fiyatla sipariş verin.`;

  return {
    title: item.name,
    description,
    alternates: { canonical: `/urun/${canonicalSlug}` },
    openGraph: {
      title: `${item.name} | Benim Lezzet Dünyam`,
      description,
      url: `/urun/${canonicalSlug}`,
      type: 'website',
      ...(item.image_url ? { images: [{ url: item.image_url }] } : {}),
    },
  };
}

function productJsonLd(item: MenuItem, canonicalSlug: string): Record<string, unknown> {
  const url = `${SITE_URL}/urun/${canonicalSlug}`;

  return {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'Product',
        name: item.name,
        ...(item.description ? { description: item.description } : {}),
        ...(item.image_url ? { image: [item.image_url] } : {}),
        url,
        category: 'Yiyecek',
        brand: { '@type': 'Brand', name: 'Benim Lezzet Dünyam' },
        offers: {
          '@type': 'Offer',
          url,
          price: schemaOrgPrice(item.price),
          priceCurrency: item.currency,
          availability: item.is_available
            ? 'https://schema.org/InStock'
            : 'https://schema.org/OutOfStock',
          seller: { '@type': 'Restaurant', name: 'Benim Lezzet Dünyam', url: SITE_URL },
        },
      },
      {
        '@type': 'Restaurant',
        name: 'Benim Lezzet Dünyam',
        url: SITE_URL,
        servesCuisine: 'Türk mutfağı',
        priceRange: '₺₺',
        hasMenu: `${SITE_URL}/menu`,
      },
    ],
  };
}

export default async function ProductPage({ params }: { params: Promise<Params> }) {
  const { slug } = await params;
  const { categories, location } = await fetchCatalog();

  const menuId = menuIdFromSlug(slug);
  if (menuId === null) notFound();

  const item = findItemById(categories, menuId);
  if (!item) notFound();

  // Ürün adı değişmişse eski bağlantı kalıcı olarak yeni slug'a taşınır.
  const canonicalSlug = productSlug(item);
  if (canonicalSlug !== slug) redirect(`/urun/${canonicalSlug}`);

  const category = findCategoryOf(categories, item.id);
  const orderingOpen = isOrderingOpen(location);
  const soldOut = !item.is_available;
  const allergens = item.allergens ?? [];
  const hasOptions = (item.options ?? []).length > 0;
  const related = (category?.items ?? [])
    .filter((other) => other.id !== item.id && other.is_available)
    .slice(0, 3);

  return (
    <div className="mx-auto max-w-content px-4 pt-6 pb-28 sm:pt-10 lg:pb-16">
      <JsonLd data={productJsonLd(item, canonicalSlug)} />

      <nav aria-label="Ekmek kırıntısı" className="mb-5 text-sm text-neutral-600">
        <ol className="flex flex-wrap items-center gap-1.5">
          <li>
            <Link href="/" className="rounded-sm hover:text-brand-700 hover:underline">
              Ana sayfa
            </Link>
          </li>
          <li aria-hidden="true">/</li>
          <li>
            <Link href="/menu" className="rounded-sm hover:text-brand-700 hover:underline">
              Menü
            </Link>
          </li>
          {category && (
            <>
              <li aria-hidden="true">/</li>
              <li>
                <Link
                  href={`/menu#kategori-${category.id}`}
                  className="rounded-sm hover:text-brand-700 hover:underline"
                >
                  {category.name}
                </Link>
              </li>
            </>
          )}
          <li aria-hidden="true">/</li>
          <li className="font-medium text-neutral-800" aria-current="page">
            {item.name}
          </li>
        </ol>
      </nav>

      <div className="grid gap-8 lg:grid-cols-2 lg:items-start">
        <div className="relative aspect-4/3 overflow-hidden rounded-card border border-neutral-200 bg-neutral-100">
          <ProductImage
            src={item.image_url}
            alt={item.name}
            sizes="(max-width: 1024px) 100vw, 560px"
            priority
            className={soldOut ? 'grayscale' : undefined}
          />
          {soldOut && (
            <span className="absolute inset-0 grid place-items-center bg-neutral-900/40">
              <span className="bld-badge bg-neutral-0 px-4 py-2 text-base text-neutral-900">
                Tükendi
              </span>
            </span>
          )}
        </div>

        <div className="lg:sticky lg:top-24">
          {category && (
            <p className="text-sm font-semibold tracking-wide text-brand-700 uppercase">
              {category.name}
            </p>
          )}
          <h1 className="mt-1 text-2xl font-bold sm:text-3xl">{item.name}</h1>
          {item.description && (
            <p className="mt-2 text-base leading-relaxed text-neutral-800">{item.description}</p>
          )}

          <p className="mt-4 flex flex-wrap items-baseline gap-2">
            <span className="text-3xl font-bold">{formatPrice(item.price)}</span>
            {hasOptions && (
              <span className="text-sm text-neutral-600">
                başlangıç fiyatı — seçtiğiniz ekstralara göre değişir
              </span>
            )}
          </p>

          {allergens.length > 0 && (
            <div className="mt-4 rounded-card border border-warning/40 bg-warning/10 px-4 py-3">
              <p className="flex items-center gap-2 text-sm font-semibold">
                <IconInfo className="h-4 w-4" />
                Alerjen bilgisi
              </p>
              <ul className="mt-2 flex flex-wrap gap-1.5">
                {allergens.map((allergen) => (
                  <li key={allergen} className="bld-badge bg-neutral-0 text-neutral-800">
                    {allergen}
                  </li>
                ))}
              </ul>
            </div>
          )}

          {soldOut && (
            <p
              role="status"
              className="mt-4 rounded-card border border-neutral-200 bg-neutral-100 px-4 py-3 text-sm text-neutral-800"
            >
              Bu ürün şu anda tükendi. Menüdeki diğer seçeneklere göz atabilirsiniz.
            </p>
          )}

          {!orderingOpen && (
            <div className="mt-4">
              <OrderingClosedBanner location={location} />
            </div>
          )}

          <div className="mt-6 bld-card p-4 sm:p-5">
            <AddToCartForm
              menuId={item.id}
              disabled={soldOut || !orderingOpen}
              disabledReason={soldOut ? 'Tükendi' : 'Sipariş alımı kapalı'}
              label="Sepete ekle"
              showMessage
            >
              <ProductOptions item={item} />

              <div className="grid gap-3 sm:grid-cols-2">
                <div>
                  <label htmlFor="quantity" className="block text-sm font-semibold">
                    Adet
                  </label>
                  <input
                    id="quantity"
                    name="quantity"
                    type="number"
                    min={1}
                    max={99}
                    step={1}
                    defaultValue={1}
                    inputMode="numeric"
                    className="mt-1 bld-field"
                  />
                </div>

                <div>
                  <label htmlFor="note" className="block text-sm font-semibold">
                    Ürün notu
                  </label>
                  <input
                    id="note"
                    name="note"
                    type="text"
                    maxLength={255}
                    placeholder="Örn. az acılı"
                    aria-describedby="note-aciklama"
                    className="mt-1 bld-field"
                  />
                  <p id="note-aciklama" className="mt-1 text-xs text-neutral-600">
                    İsteğe bağlı, en fazla 255 karakter.
                  </p>
                </div>
              </div>
            </AddToCartForm>

            <div className="mt-3 grid gap-2 sm:grid-cols-2">
              <Link href="/sepet" className="bld-btn-secondary">
                Sepete git
              </Link>
              <Link href="/menu" className="bld-btn-secondary">
                Menüye dön
              </Link>
            </div>
          </div>
        </div>
      </div>

      {related.length > 0 && (
        <section aria-labelledby="benzer-urunler" className="mt-14">
          <div className="flex flex-wrap items-baseline justify-between gap-2">
            <h2 id="benzer-urunler" className="text-xl font-bold sm:text-2xl">
              {category ? `${category.name} kategorisinden` : 'Bunlar da ilginizi çekebilir'}
            </h2>
            <Link
              href="/menu"
              className="inline-flex items-center gap-1 rounded-sm text-sm font-semibold text-brand-700 underline-offset-2 hover:underline"
            >
              Tüm menü
              <IconChevronRight className="h-4 w-4" />
            </Link>
          </div>

          <div className="mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {related.map((other) => (
              <ProductCard key={other.id} item={other} orderingOpen={orderingOpen} />
            ))}
          </div>
        </section>
      )}

      <CartSummaryBar />
    </div>
  );
}
