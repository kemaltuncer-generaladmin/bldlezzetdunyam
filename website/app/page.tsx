import type { Metadata } from 'next';
import Link from 'next/link';
import { ErrorState } from '@/components/error-state';
import { JsonLd } from '@/components/json-ld';
import { OrderingClosedBanner } from '@/components/ordering-banner';
import { ProductCard } from '@/components/product-card';
import { SITE_URL } from '@/lib/api/client';
import { fetchCatalog, flattenItems, isOrderingOpen } from '@/lib/api/catalog';
import { formatPrice } from '@/lib/format';
import type { CatalogSnapshot } from '@/lib/api/catalog';

/**
 * ISR — `docs/06` §7. Next segment yapılandırması statik değer ister; asıl
 * veri tazeliği `fetch` seviyesindeki `REVALIDATE_SECONDS` ile de sınırlıdır.
 */
export const revalidate = 60;

export const metadata: Metadata = {
  title: 'Benim Lezzet Dünyam — Kurumsal Catering ve Günlük Yemek',
  description:
    'Her gün taze pişen kurumsal catering menüsü. Adrese teslim veya gel-al; online sipariş verin, siparişinizi anlık takip edin.',
  alternates: { canonical: '/' },
  openGraph: {
    title: 'Benim Lezzet Dünyam — Kurumsal Catering',
    description: 'Her gün taze pişen kurumsal catering menüsü. Adrese teslim veya gel-al.',
    url: '/',
    type: 'website',
  },
};

const STEPS = [
  {
    title: 'Menüden seçin',
    body: 'Günün çorbaları, ana yemekleri ve tatlıları menüde. Porsiyon ve ekstraları seçin.',
  },
  {
    title: 'Teslimatı belirleyin',
    body: 'Adrese teslim ya da gel-al. İstediğiniz saati bildirin, kesim saatine kadar sipariş alıyoruz.',
  },
  {
    title: 'Siparişinizi takip edin',
    body: 'Mutfak siparişinizi aldığı andan teslimata kadar durumu ekranınızda güncellenir.',
  },
] as const;

function restaurantJsonLd(snapshot: CatalogSnapshot): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'Restaurant',
    name: 'Benim Lezzet Dünyam',
    description: 'Kurumsal catering ve günlük yemek hizmeti.',
    url: SITE_URL,
    servesCuisine: 'Türk mutfağı',
    priceRange: '₺₺',
    hasMenu: `${SITE_URL}/menu`,
    areaServed: 'Türkiye',
    acceptsReservations: false,
    ...(snapshot.location
      ? {
          currenciesAccepted: 'TRY',
          paymentAccepted: snapshot.location.payment_methods.join(', '),
        }
      : {}),
  };
}

export default async function HomePage() {
  let snapshot: CatalogSnapshot;
  try {
    snapshot = await fetchCatalog();
  } catch {
    return (
      <div className="mx-auto max-w-content px-4 py-16">
        <ErrorState
          title="Menü yüklenemedi"
          message="Menü yüklenemedi, tekrar deneyin."
          retryHref="/"
        />
      </div>
    );
  }

  const orderingOpen = isOrderingOpen(snapshot.location);
  const featured = flattenItems(snapshot.categories)
    .filter((item) => item.is_available)
    .slice(0, 6);
  const cheapest = featured.reduce<number | null>(
    (min, item) => (min === null || item.price < min ? item.price : min),
    null,
  );

  return (
    <>
      <JsonLd data={restaurantJsonLd(snapshot)} />

      <section className="bg-gradient-to-b from-brand-50 to-neutral-50">
        <div className="mx-auto max-w-content px-4 py-12 sm:py-20">
          <p className="text-sm font-semibold uppercase tracking-wide text-brand-700">
            Kurumsal catering
          </p>
          <h1 className="mt-3 max-w-2xl text-3xl font-bold leading-tight text-neutral-900 sm:text-5xl">
            Her gün taze pişen yemek, kapınıza kadar
          </h1>
          <p className="mt-4 max-w-xl text-base text-neutral-800 sm:text-lg">
            Ofisiniz, atölyeniz veya etkinliğiniz için günlük menüler hazırlıyoruz. Sipariş verin,
            mutfaktan çıkışına kadar adım adım takip edin.
          </p>

          <div className="mt-8 flex flex-wrap gap-3">
            <Link
              href="/menu"
              className="rounded-lg bg-brand-600 px-6 py-3 text-base font-semibold text-neutral-0 hover:bg-brand-700"
            >
              Sipariş ver
            </Link>
            <Link
              href="/menu"
              className="rounded-lg border border-neutral-200 bg-neutral-0 px-6 py-3 text-base font-semibold text-neutral-900 hover:bg-neutral-100"
            >
              Menüyü incele
            </Link>
          </div>

          {cheapest !== null && (
            <p className="mt-4 text-sm text-neutral-600">
              Porsiyon fiyatları {formatPrice(cheapest)} seviyesinden başlıyor.
            </p>
          )}

          {!orderingOpen && (
            <div className="mt-8 max-w-2xl">
              <OrderingClosedBanner location={snapshot.location} />
            </div>
          )}
        </div>
      </section>

      <section className="mx-auto max-w-content px-4 py-12">
        <h2 className="text-2xl font-bold text-neutral-900">Nasıl çalışır?</h2>
        <ol className="mt-6 grid gap-4 sm:grid-cols-3">
          {STEPS.map((step, index) => (
            <li key={step.title} className="bld-card p-5">
              <span className="grid h-9 w-9 place-items-center rounded-full bg-brand-100 text-sm font-bold text-brand-800">
                {index + 1}
              </span>
              <h3 className="mt-3 text-base font-semibold text-neutral-900">{step.title}</h3>
              <p className="mt-1 text-sm text-neutral-600">{step.body}</p>
            </li>
          ))}
        </ol>
      </section>

      {featured.length > 0 && (
        <section className="mx-auto max-w-content px-4 pb-16">
          <div className="flex flex-wrap items-baseline justify-between gap-2">
            <h2 className="text-2xl font-bold text-neutral-900">Öne çıkan ürünler</h2>
            <Link
              href="/menu"
              className="rounded text-sm font-semibold text-brand-700 underline-offset-2 hover:underline"
            >
              Tüm menüyü gör
            </Link>
          </div>

          <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {featured.map((item, index) => (
              <ProductCard
                key={item.id}
                item={item}
                orderingOpen={orderingOpen}
                priority={index < 3}
              />
            ))}
          </div>
        </section>
      )}
    </>
  );
}
