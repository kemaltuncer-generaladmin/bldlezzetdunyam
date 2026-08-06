import type { Metadata } from 'next';
import Link from 'next/link';
import { ErrorState } from '@/components/error-state';
import {
  IconChevronRight,
  IconClock,
  IconLeaf,
  IconRoute,
  IconTruck,
  IconWallet,
} from '@/components/icons';
import { JsonLd } from '@/components/json-ld';
import { KitchenBusyBanner } from '@/components/kitchen-busy-banner';
import { LocationFacts } from '@/components/location-facts';
import { OrderingClosedBanner } from '@/components/ordering-banner';
import { ProductCard } from '@/components/product-card';
import { ProductImage } from '@/components/product-image';
import { SITE_URL } from '@/lib/api/client';
import { fetchCatalog, flattenItems, isOrderingOpen } from '@/lib/api/catalog';
import { formatPrice } from '@/lib/format';
import type { CatalogSnapshot } from '@/lib/api/catalog';
import type { MenuCategory, MenuItem } from '@/lib/api/types';

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

const TRUST_POINTS = [
  {
    key: 'fresh',
    icon: <IconLeaf className="h-6 w-6" />,
    title: 'Günlük üretim',
    body: 'Menü her sabah yeniden hazırlanır; sipariş verdiğiniz yemek o gün pişer.',
  },
  {
    key: 'tracking',
    icon: <IconRoute className="h-6 w-6" />,
    title: 'Adım adım takip',
    body: 'Sipariş mutfağa düştüğü anda ekranınıza yansır: onaylandı, hazırlanıyor, yolda.',
  },
  {
    key: 'delivery',
    icon: <IconTruck className="h-6 w-6" />,
    title: 'Adrese teslim veya gel-al',
    body: 'Siparişinizi kapınıza getirelim ya da hazır olduğunda gelip alın; seçim sizin.',
  },
  {
    key: 'payment',
    icon: <IconWallet className="h-6 w-6" />,
    title: 'Kurumsal ödeme',
    body: 'Kapıda ödeme ve cari hesap desteklenir; toplu siparişte tek hesapta toplanır.',
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

/** Kahraman görsel kolajı — menüdeki gerçek ürün görselleri kullanılır. */
function HeroCollage({ items }: { items: MenuItem[] }) {
  const [lead, ...rest] = items;
  if (!lead) return null;

  return (
    <div className="grid grid-cols-2 gap-3" aria-hidden="true">
      <div className="relative col-span-2 aspect-16/10 overflow-hidden rounded-card bg-neutral-100 shadow-xs">
        <ProductImage
          src={lead.image_url}
          alt=""
          sizes="(max-width: 1024px) 100vw, 520px"
          priority
        />
      </div>
      {rest.slice(0, 2).map((item) => (
        <div
          key={item.id}
          className="relative aspect-4/3 overflow-hidden rounded-card bg-neutral-100 shadow-xs"
        >
          <ProductImage src={item.image_url} alt="" sizes="(max-width: 1024px) 50vw, 250px" />
        </div>
      ))}
    </div>
  );
}

function CategoryShortcuts({ categories }: { categories: MenuCategory[] }) {
  if (categories.length === 0) return null;

  return (
    <section className="mx-auto max-w-content px-4 py-10 sm:py-14">
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <h2 className="text-2xl font-bold">Ne yemek istersiniz?</h2>
        <Link
          href="/menu"
          className="rounded-sm text-sm font-semibold text-brand-700 underline-offset-2 hover:underline"
        >
          Tüm kategoriler
        </Link>
      </div>

      <ul className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {categories.map((category) => {
          const items = category.items ?? [];
          const cover = items.find((item) => item.image_url) ?? items[0];

          return (
            <li key={category.id}>
              <Link
                href={`/menu#kategori-${category.id}`}
                className="group flex items-center gap-4 overflow-hidden rounded-card border border-neutral-200 bg-neutral-0 p-3 shadow-xs transition-shadow hover:shadow-md"
              >
                <span className="relative h-20 w-20 shrink-0 overflow-hidden rounded-lg bg-neutral-100">
                  <ProductImage
                    src={cover?.image_url}
                    alt=""
                    sizes="80px"
                    className="transition-transform duration-300 motion-safe:group-hover:scale-105"
                  />
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-base font-semibold">{category.name}</span>
                  <span className="mt-0.5 block text-sm text-neutral-600">{items.length} ürün</span>
                </span>
                <IconChevronRight className="h-5 w-5 shrink-0 text-neutral-400 transition-transform motion-safe:group-hover:translate-x-0.5" />
              </Link>
            </li>
          );
        })}
      </ul>
    </section>
  );
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
  const categories = snapshot.categories.filter((category) => (category.items ?? []).length > 0);
  const available = flattenItems(categories).filter((item) => item.is_available);
  const featured = available.slice(0, 6);
  const cheapest = available.reduce<number | null>(
    (min, item) => (min === null || item.price < min ? item.price : min),
    null,
  );

  return (
    <>
      <JsonLd data={restaurantJsonLd(snapshot)} />

      <section className="relative overflow-hidden bg-linear-to-b from-brand-50 via-brand-50 to-neutral-50">
        {/* Dekoratif ışık lekesi — içeriğin okunabilirliğini etkilemez. */}
        <div
          aria-hidden="true"
          className="pointer-events-none absolute -right-24 -top-32 h-80 w-80 rounded-full bg-brand-200/50 blur-3xl"
        />

        <div className="relative mx-auto grid max-w-content items-center gap-10 px-4 py-12 sm:py-16 lg:grid-cols-2 lg:py-20">
          <div>
            <p className="bld-badge bg-brand-100 px-3 py-1.5 text-brand-800">
              Kurumsal catering · Günlük menü
            </p>
            <h1 className="mt-4 text-3xl font-bold leading-tight sm:text-5xl">
              Her gün taze pişen yemek, <span className="text-brand-700">kapınıza kadar</span>
            </h1>
            <p className="mt-4 max-w-xl text-base text-neutral-800 sm:text-lg">
              Ofisiniz, atölyeniz veya etkinliğiniz için günlük menüler hazırlıyoruz. Sipariş verin,
              mutfaktan çıkışına kadar adım adım takip edin.
            </p>

            <div className="mt-7 flex flex-wrap gap-3">
              <Link href="/menu" className="bld-btn-primary px-6 py-3 text-base">
                Sipariş ver
                <IconChevronRight className="h-5 w-5" />
              </Link>
              <Link href="/siparislerim" className="bld-btn-secondary px-6 py-3 text-base">
                Siparişlerimi gör
              </Link>
            </div>

            {cheapest !== null && (
              <p className="mt-4 text-sm text-neutral-600">
                Porsiyon fiyatları {formatPrice(cheapest)} seviyesinden başlıyor.
              </p>
            )}

            <LocationFacts location={snapshot.location} className="mt-6" />

            <div className="mt-6 max-w-2xl space-y-3 empty:mt-0">
              {!orderingOpen && <OrderingClosedBanner location={snapshot.location} />}
              {/* Yoğunluk bandı sipariş açıkken de görünür: uyarıdır, kapı değil. */}
              <KitchenBusyBanner />
            </div>
          </div>

          <HeroCollage items={featured} />
        </div>
      </section>

      <CategoryShortcuts categories={categories} />

      {featured.length > 0 && (
        <section className="bg-neutral-0 py-12 sm:py-14">
          <div className="mx-auto max-w-content px-4">
            <div className="flex flex-wrap items-baseline justify-between gap-2">
              <h2 className="text-2xl font-bold">Öne çıkan ürünler</h2>
              <Link
                href="/menu"
                className="rounded-sm text-sm font-semibold text-brand-700 underline-offset-2 hover:underline"
              >
                Tüm menüyü gör
              </Link>
            </div>

            <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {featured.map((item) => (
                <ProductCard key={item.id} item={item} orderingOpen={orderingOpen} />
              ))}
            </div>
          </div>
        </section>
      )}

      <section className="mx-auto max-w-content px-4 py-12 sm:py-14">
        <h2 className="text-2xl font-bold">Nasıl çalışır?</h2>
        <ol className="mt-6 grid gap-4 sm:grid-cols-3">
          {STEPS.map((step, index) => (
            <li key={step.title} className="bld-card p-5">
              <span
                aria-hidden="true"
                className="grid h-10 w-10 place-items-center rounded-full bg-brand-100 text-base font-bold text-brand-800"
              >
                {index + 1}
              </span>
              <h3 className="mt-3 text-base font-semibold">{step.title}</h3>
              <p className="mt-1 text-sm leading-relaxed text-neutral-600">{step.body}</p>
            </li>
          ))}
        </ol>
      </section>

      <section className="border-y border-neutral-200 bg-neutral-0 py-12 sm:py-14">
        <div className="mx-auto max-w-content px-4">
          <h2 className="text-2xl font-bold">Neden Benim Lezzet Dünyam?</h2>
          <ul className="mt-6 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
            {TRUST_POINTS.map((point) => (
              <li key={point.key}>
                <span
                  aria-hidden="true"
                  className="grid h-11 w-11 place-items-center rounded-card bg-brand-50 text-brand-700"
                >
                  {point.icon}
                </span>
                <h3 className="mt-3 text-base font-semibold">{point.title}</h3>
                <p className="mt-1 text-sm leading-relaxed text-neutral-600">{point.body}</p>
              </li>
            ))}
          </ul>
        </div>
      </section>

      <section className="mx-auto max-w-content px-4 py-12 sm:py-16">
        <div className="rounded-card bg-brand-700 px-6 py-10 text-center sm:px-10">
          <h2 className="text-2xl font-bold text-neutral-0 sm:text-3xl">
            Yarının menüsünü bugünden ayırtın
          </h2>
          <p className="mx-auto mt-3 max-w-2xl text-sm text-brand-50 sm:text-base">
            {snapshot.location?.order_cutoff
              ? `Günlük son sipariş saatimiz ${snapshot.location.order_cutoff}. Bu saate kadar verilen siparişler aynı gün hazırlanır.`
              : 'Sipariş saatleri içinde verdiğiniz siparişler aynı gün hazırlanır.'}
          </p>
          <div className="mt-6 flex flex-wrap justify-center gap-3">
            <Link
              href="/menu"
              className="bld-btn bg-neutral-0 px-6 py-3 text-base text-brand-800 hover:bg-brand-50"
            >
              Menüyü aç
              <IconClock className="h-5 w-5" />
            </Link>
          </div>
        </div>
      </section>
    </>
  );
}
