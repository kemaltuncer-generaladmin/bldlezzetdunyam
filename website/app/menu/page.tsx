import type { Metadata } from 'next';
import Image from 'next/image';
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
import { PHOTO } from '@/lib/site-images';
import type { CatalogSnapshot } from '@/lib/api/catalog';

/** ISR 60 sn — `docs/06` §2/§7. */
export const revalidate = 60;

export const metadata: Metadata = {
  title: 'Günün Menüsü',
  description:
    'Bugün mutfaktan çıkanlar: çorbalar, ana yemekler, salatalar ve tatlılar. Fiyatlarıyla bakın, adrese teslim ya da gel-al sipariş verin.',
  alternates: { canonical: '/menu' },
  openGraph: {
    title: 'Günün Menüsü | Benim Lezzet Dünyam',
    description: 'Bugün mutfaktan ne çıktı? Fiyatlarıyla bakın.',
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

      {/*
        Sipariş başlığı da kurumsal sayfalarla aynı dili konuşuyor: fotoğraflı
        koyu bant. Önceki sürüm `from-brand-50` gradyanı ve doğrudan
        `text-neutral-*` sınıfları kullanıyordu; karanlık temada soluk kalıyor
        ve sitenin geri kalanından kopuk duruyordu.

        Vitrin bilgileri (asgari sepet, teslimat ücreti, tahmini süre) bandın
        içinde: sipariş kararını etkileyen sayılar, menüye inmeden görünmeli.
      */}
      <div className="relative isolate border-b bg-charcoal text-cream">
        <Image
          alt={PHOTO.menuVitrin.alt}
          src={PHOTO.menuVitrin.src}
          fill
          priority
          sizes="100vw"
          className="-z-10 object-cover"
        />
        <div
          aria-hidden="true"
          className="absolute inset-0 -z-10 bg-linear-to-r from-charcoal/90 via-charcoal/80 to-charcoal/50"
        />

        <div className="mx-auto max-w-content px-4 py-10 sm:px-6 sm:py-14">
          <p className="text-xs font-semibold tracking-[0.14em] text-brand-300 uppercase">
            Günün menüsü
          </p>
          <h1 className="mt-2 font-display text-3xl font-semibold tracking-tight sm:text-5xl">
            Bugün ne var?
          </h1>
          <p className="mt-4 max-w-2xl text-base/7 text-cream/80">
            Her sabah pişirdiklerimiz. Fiyatlar porsiyon başına ve KDV dâhil.
          </p>

          <LocationFacts location={snapshot.location} className="mt-6" />
        </div>
      </div>

      {/* Alt sepet çubuğu içeriği kapatmasın diye mobilde alttan boşluk. */}
      <div className="mx-auto max-w-content px-4 pt-6 pb-28 sm:pt-8 lg:pb-16">
        <div className="space-y-3 empty:hidden">
          {!orderingOpen && <OrderingClosedBanner location={snapshot.location} />}
          <KitchenBusyBanner />
        </div>

        {categories.length === 0 ? (
          <EmptyState
            className="mt-8"
            icon={<IconPlate className="h-8 w-8" />}
            title="Bugün henüz bir şey çıkmadı"
            message="Menü hazırlanınca burada görünecek. Biraz sonra tekrar bakın."
            actionHref="/"
            actionLabel="Ana sayfaya dön"
          />
        ) : (
          <div className="mt-4 grid gap-8 lg:grid-cols-[minmax(0,1fr)_18rem]">
            {/*
             * `min-w-0`: ızgara öğeleri varsayılan olarak `min-width: auto`
             * taşır, yani içeriklerinden dar olamazlar. Kategori şeridi
             * (`bld-rail`) telefonda ekrandan geniş olduğu için sütun onunla
             * birlikte büyüyor ve SAYFA yatay kayıyordu — oysa şeridin kendi
             * içinde kayması gerekiyor. 390 px'te belge 529 px'e çıkıyordu.
             */}
            <div className="min-w-0">
              <MenuBrowser categories={categories} orderingOpen={orderingOpen} />
            </div>
            <CartSummaryPanel />
          </div>
        )}
      </div>

      <CartSummaryBar />
    </>
  );
}
