import type { Metadata } from 'next';
import Image from 'next/image';
import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { AddToCartForm } from '@/components/add-to-cart-form';
import { JsonLd } from '@/components/json-ld';
import { OrderingClosedBanner } from '@/components/ordering-banner';
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
  const hasOptions = (item.options ?? []).length > 0;

  return (
    <div className="mx-auto max-w-content px-4 py-6 sm:py-10">
      <JsonLd data={productJsonLd(item, canonicalSlug)} />

      <nav aria-label="Ekmek kırıntısı" className="mb-5 text-sm text-neutral-600">
        <ol className="flex flex-wrap items-center gap-1.5">
          <li>
            <Link href="/" className="rounded hover:text-brand-700 hover:underline">
              Ana sayfa
            </Link>
          </li>
          <li aria-hidden="true">/</li>
          <li>
            <Link href="/menu" className="rounded hover:text-brand-700 hover:underline">
              Menü
            </Link>
          </li>
          {category && (
            <>
              <li aria-hidden="true">/</li>
              <li className="text-neutral-800">{category.name}</li>
            </>
          )}
        </ol>
      </nav>

      <div className="grid gap-8 lg:grid-cols-2">
        <div className="relative aspect-[4/3] overflow-hidden rounded-card bg-neutral-100">
          {item.image_url ? (
            <Image
              src={item.image_url}
              alt={item.name}
              fill
              sizes="(max-width: 1024px) 100vw, 560px"
              className="object-cover"
              priority
            />
          ) : (
            <span
              aria-hidden="true"
              className="grid h-full w-full place-items-center text-5xl text-neutral-400"
            >
              🍽️
            </span>
          )}
        </div>

        <div>
          <h1 className="text-2xl font-bold text-neutral-900 sm:text-3xl">{item.name}</h1>
          {item.description && (
            <p className="mt-2 text-base leading-relaxed text-neutral-800">{item.description}</p>
          )}

          <p className="mt-4 text-3xl font-bold text-neutral-900">{formatPrice(item.price)}</p>
          {hasOptions && (
            <p className="mt-1 text-sm text-neutral-600">
              Seçtiğiniz ekstralara göre tutar değişebilir.
            </p>
          )}

          {(item.allergens ?? []).length > 0 && (
            <div className="mt-4 rounded-card bg-neutral-100 px-4 py-3">
              <p className="text-sm font-semibold text-neutral-900">Alerjen bilgisi</p>
              <p className="mt-1 text-sm text-neutral-800">{(item.allergens ?? []).join(', ')}</p>
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

          <div className="bld-card mt-6 p-4 sm:p-5">
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
                  <label
                    htmlFor="quantity"
                    className="block text-sm font-semibold text-neutral-900"
                  >
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
                    className="mt-1 w-full rounded-lg border border-neutral-200 px-3 py-2.5 text-sm text-neutral-900"
                  />
                </div>

                <div>
                  <label htmlFor="note" className="block text-sm font-semibold text-neutral-900">
                    Ürün notu
                  </label>
                  <input
                    id="note"
                    name="note"
                    type="text"
                    maxLength={255}
                    placeholder="Örn. az acılı"
                    aria-describedby="note-aciklama"
                    className="mt-1 w-full rounded-lg border border-neutral-200 px-3 py-2.5 text-sm text-neutral-900"
                  />
                  <p id="note-aciklama" className="mt-1 text-xs text-neutral-600">
                    İsteğe bağlı, en fazla 255 karakter.
                  </p>
                </div>
              </div>
            </AddToCartForm>

            <Link
              href="/sepet"
              className="mt-3 block rounded-lg border border-neutral-200 px-4 py-3 text-center text-sm font-semibold text-neutral-900 hover:bg-neutral-100"
            >
              Sepete git
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
