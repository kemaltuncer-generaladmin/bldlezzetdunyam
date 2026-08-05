import type { Metadata } from 'next';
import { ErrorState } from '@/components/error-state';
import { JsonLd } from '@/components/json-ld';
import { MenuFilter, type MenuSection } from '@/components/menu-filter';
import { KitchenBusyBanner } from '@/components/kitchen-busy-banner';
import { OrderingClosedBanner } from '@/components/ordering-banner';
import { ProductCard } from '@/components/product-card';
import { SITE_URL } from '@/lib/api/client';
import { fetchCatalog, isOrderingOpen } from '@/lib/api/catalog';
import { schemaOrgPrice } from '@/lib/format';
import { productSlug } from '@/lib/slug';
import type { CatalogSnapshot } from '@/lib/api/catalog';

/** ISR 60 sn — `docs/06` §2/§7. */
export const revalidate = 60;

export const metadata: Metadata = {
  title: 'Catering Menüsü',
  description:
    'Günlük catering menümüz: çorbalar, ana yemekler, salatalar ve tatlılar. Fiyatlarıyla birlikte inceleyin, adrese teslim veya gel-al sipariş verin.',
  alternates: { canonical: '/menu' },
  openGraph: {
    title: 'Catering Menüsü | Benim Lezzet Dünyam',
    description: 'Günlük catering menümüzü fiyatlarıyla inceleyin.',
    url: '/menu',
    type: 'website',
  },
};

function menuJsonLd(snapshot: CatalogSnapshot): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'Menu',
    name: 'Benim Lezzet Dünyam catering menüsü',
    url: `${SITE_URL}/menu`,
    inLanguage: 'tr-TR',
    hasMenuSection: snapshot.categories.map((category) => ({
      '@type': 'MenuSection',
      name: category.name,
      hasMenuItem: (category.items ?? []).map((item) => ({
        '@type': 'MenuItem',
        name: item.name,
        ...(item.description ? { description: item.description } : {}),
        url: `${SITE_URL}/urun/${productSlug(item)}`,
        offers: {
          '@type': 'Offer',
          price: schemaOrgPrice(item.price),
          priceCurrency: item.currency,
          availability: item.is_available
            ? 'https://schema.org/InStock'
            : 'https://schema.org/OutOfStock',
        },
      })),
    })),
  };
}

export default async function MenuPage() {
  let snapshot: CatalogSnapshot;
  try {
    snapshot = await fetchCatalog();
  } catch {
    return (
      <div className="mx-auto max-w-content px-4 py-16">
        <ErrorState
          title="Menü yüklenemedi"
          message="Menü yüklenemedi, tekrar deneyin."
          retryHref="/menu"
        />
      </div>
    );
  }

  const orderingOpen = isOrderingOpen(snapshot.location);
  const categories = snapshot.categories.filter((category) => (category.items ?? []).length > 0);

  const sections: MenuSection[] = categories.map((category) => {
    const items = category.items ?? [];
    return {
      id: category.id,
      name: category.name,
      count: items.length,
      content: (
        <section aria-labelledby={`kategori-${category.id}`}>
          <h2
            id={`kategori-${category.id}`}
            className="text-xl font-bold text-neutral-900 sm:text-2xl"
          >
            {category.name}
          </h2>
          <div className="mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {items.map((item, index) => (
              <ProductCard
                key={item.id}
                item={item}
                orderingOpen={orderingOpen}
                priority={index < 3}
              />
            ))}
          </div>
        </section>
      ),
    };
  });

  return (
    <div className="mx-auto max-w-content px-4 py-8 sm:py-12">
      <JsonLd data={menuJsonLd(snapshot)} />

      <header className="mb-6">
        <h1 className="text-3xl font-bold text-neutral-900 sm:text-4xl">Catering menüsü</h1>
        <p className="mt-2 max-w-2xl text-sm text-neutral-600 sm:text-base">
          Günlük olarak hazırladığımız yemekler. Fiyatlar porsiyon başınadır, KDV dahildir.
        </p>
      </header>

      {!orderingOpen && (
        <div className="mb-6">
          <OrderingClosedBanner location={snapshot.location} />
          <KitchenBusyBanner />
        </div>
      )}

      {sections.length === 0 ? (
        <ErrorState
          title="Menü şu an boş"
          message="Bugün için henüz ürün yayınlanmadı. Kısa süre içinde tekrar bakın."
          retryHref="/menu"
        />
      ) : (
        <MenuFilter sections={sections} />
      )}
    </div>
  );
}
