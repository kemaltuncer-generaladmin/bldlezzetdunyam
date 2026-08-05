import type { Metadata } from 'next';
import { CartSummaryBar, CartSummaryPanel } from '@/components/cart-summary';
import { EmptyState } from '@/components/empty-state';
import { ErrorState } from '@/components/error-state';
import { IconPlate } from '@/components/icons';
import { JsonLd } from '@/components/json-ld';
import { LocationFacts } from '@/components/location-facts';
import { MenuBrowser } from '@/components/menu-browser';
import { KitchenBusyBanner } from '@/components/kitchen-busy-banner';
import { OrderingClosedBanner } from '@/components/ordering-banner';
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

  return (
    <>
      <JsonLd data={menuJsonLd(snapshot)} />

      <div className="border-b border-neutral-200 bg-gradient-to-b from-brand-50 to-neutral-50">
        <div className="mx-auto max-w-content px-4 py-8 sm:py-10">
          <p className="text-sm font-semibold uppercase tracking-wide text-brand-700">
            Günün menüsü
          </p>
          <h1 className="mt-2 text-3xl font-bold sm:text-4xl">Catering menüsü</h1>
          <p className="mt-2 max-w-2xl text-sm text-neutral-800 sm:text-base">
            Günlük olarak hazırladığımız yemekler. Fiyatlar porsiyon başınadır, KDV dahildir.
          </p>

          <LocationFacts location={snapshot.location} className="mt-5" />
        </div>
      </div>

      {/* Alt sepet çubuğu içeriği kapatmasın diye mobilde alttan boşluk. */}
      <div className="mx-auto max-w-content px-4 pb-28 pt-6 sm:pt-8 lg:pb-16">
        <div className="space-y-3 empty:hidden">
          {!orderingOpen && <OrderingClosedBanner location={snapshot.location} />}
          <KitchenBusyBanner />
        </div>

        {categories.length === 0 ? (
          <EmptyState
            className="mt-8"
            icon={<IconPlate className="h-8 w-8" />}
            title="Menü şu an boş"
            message="Bugün için henüz ürün yayınlanmadı. Kısa süre içinde tekrar bakın."
            actionHref="/"
            actionLabel="Ana sayfaya dön"
          />
        ) : (
          <div className="mt-4 grid gap-8 lg:grid-cols-[minmax(0,1fr)_18rem]">
            <MenuBrowser categories={categories} orderingOpen={orderingOpen} />
            <CartSummaryPanel />
          </div>
        )}
      </div>

      <CartSummaryBar />
    </>
  );
}
