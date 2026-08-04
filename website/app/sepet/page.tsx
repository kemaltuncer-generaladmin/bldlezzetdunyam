import type { Metadata } from 'next';
import Image from 'next/image';
import Link from 'next/link';
import { CartLineControls } from '@/components/cart-line-controls';
import { ErrorState } from '@/components/error-state';
import { OrderingClosedBanner } from '@/components/ordering-banner';
import { isOrderingOpen } from '@/lib/api/catalog';
import { resolveCart, type ResolvedCart } from '@/lib/cart';
import { formatPrice } from '@/lib/format';
import { productPath } from '@/lib/slug';

/** Sepet cookie'ye bağlıdır — her istekte taze render edilir. */
export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Sepetim',
  description: 'Sepetinizdeki ürünleri gözden geçirin ve siparişinizi tamamlayın.',
  robots: { index: false, follow: true },
};

export default async function CartPage() {
  let cart: ResolvedCart;
  try {
    cart = await resolveCart();
  } catch {
    return (
      <div className="mx-auto max-w-content px-4 py-16">
        <ErrorState
          title="Sepet yüklenemedi"
          message="Sepetiniz yüklenemedi, tekrar deneyin."
          retryHref="/sepet"
        />
      </div>
    );
  }

  const orderingOpen = isOrderingOpen(cart.location);
  const minOrderTotal = cart.location?.min_order_total ?? 0;
  const belowMinimum = cart.subtotal < minOrderTotal;
  const canCheckout =
    cart.lines.length > 0 && orderingOpen && !cart.hasUnavailable && !belowMinimum;

  return (
    <div className="mx-auto max-w-content px-4 py-8 sm:py-12">
      <h1 className="text-3xl font-bold text-neutral-900">Sepetim</h1>

      {!orderingOpen && (
        <div className="mt-5">
          <OrderingClosedBanner location={cart.location} />
        </div>
      )}

      {cart.missingMenuIds.length > 0 && (
        <p
          role="status"
          className="mt-5 rounded-card border border-warning/40 bg-warning/10 px-4 py-3 text-sm text-neutral-900"
        >
          Sepetinizdeki {cart.missingMenuIds.length} ürün menüden kaldırıldığı için çıkarıldı.
        </p>
      )}

      {cart.lines.length === 0 ? (
        <div className="mt-8">
          <ErrorState
            title="Sepetiniz boş"
            message="Menüden ürün ekleyerek siparişinize başlayabilirsiniz."
            retryHref="/menu"
            retryLabel="Menüye git"
          />
        </div>
      ) : (
        <div className="mt-8 grid gap-8 lg:grid-cols-[1fr_20rem]">
          <ul className="space-y-4">
            {cart.lines.map((line) => (
              <li key={line.key} className="bld-card flex gap-3 p-3 sm:gap-4 sm:p-4">
                <Link
                  href={productPath(line.item)}
                  tabIndex={-1}
                  className="relative h-20 w-20 shrink-0 overflow-hidden rounded-lg bg-neutral-100 sm:h-24 sm:w-24"
                >
                  {line.item.image_url ? (
                    <Image
                      src={line.item.image_url}
                      alt=""
                      fill
                      sizes="96px"
                      className="object-cover"
                    />
                  ) : (
                    <span
                      aria-hidden="true"
                      className="grid h-full w-full place-items-center text-2xl text-neutral-400"
                    >
                      🍽️
                    </span>
                  )}
                </Link>

                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-start justify-between gap-2">
                    <h2 className="text-base font-semibold text-neutral-900">
                      <Link href={productPath(line.item)} className="rounded hover:text-brand-700">
                        {line.item.name}
                      </Link>
                    </h2>
                    <p className="text-base font-bold text-neutral-900">
                      {formatPrice(line.lineTotal)}
                    </p>
                  </div>

                  {line.optionValues.length > 0 && (
                    <p className="mt-0.5 text-sm text-neutral-600">
                      {line.optionValues.map((value) => value.name).join(', ')}
                    </p>
                  )}
                  {line.note && (
                    <p className="mt-0.5 text-sm text-neutral-600">
                      <span className="font-medium">Not:</span> {line.note}
                    </p>
                  )}
                  <p className="mt-0.5 text-sm text-neutral-600">
                    Birim: {formatPrice(line.unitPrice)}
                  </p>

                  {line.unavailable && (
                    <p className="mt-2 rounded-md bg-danger/10 px-2 py-1 text-sm text-danger">
                      Bu ürün tükendi, siparişe eklenemez. Lütfen sepetten çıkarın.
                    </p>
                  )}

                  <div className="mt-3">
                    <CartLineControls
                      lineKey={line.key}
                      quantity={line.quantity}
                      itemName={line.item.name}
                    />
                  </div>
                </div>
              </li>
            ))}
          </ul>

          <aside className="bld-card h-fit p-5 lg:sticky lg:top-24">
            <h2 className="text-lg font-semibold text-neutral-900">Sipariş özeti</h2>

            <dl className="mt-4 space-y-2 text-sm">
              <div className="flex justify-between">
                <dt className="text-neutral-600">Ürünler ({cart.itemCount} adet)</dt>
                <dd className="font-medium text-neutral-900">{formatPrice(cart.subtotal)}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-neutral-600">Teslimat ücreti</dt>
                <dd className="text-neutral-600">Sipariş adımında hesaplanır</dd>
              </div>
            </dl>

            <div className="mt-4 flex items-baseline justify-between border-t border-neutral-200 pt-4">
              <span className="text-sm font-semibold text-neutral-900">Ara toplam</span>
              <span className="text-xl font-bold text-neutral-900">
                {formatPrice(cart.subtotal)}
              </span>
            </div>
            <p className="mt-1 text-xs text-neutral-600">
              Kesin tutar siparişi oluştururken sunucuda hesaplanır.
            </p>

            {belowMinimum && (
              <p
                role="status"
                className="mt-4 rounded-md bg-warning/10 px-3 py-2 text-sm text-neutral-900"
              >
                Minimum sipariş tutarı {formatPrice(minOrderTotal)}. Devam etmek için{' '}
                {formatPrice(minOrderTotal - cart.subtotal)} tutarında ürün ekleyin.
              </p>
            )}

            {cart.hasUnavailable && (
              <p role="status" className="mt-4 rounded-md bg-danger/10 px-3 py-2 text-sm text-danger">
                Sepetinizde tükenen ürün var. Devam etmek için çıkarın.
              </p>
            )}

            {canCheckout ? (
              <Link
                href="/odeme"
                className="mt-5 block rounded-lg bg-brand-600 px-4 py-3 text-center text-sm font-semibold text-neutral-0 hover:bg-brand-700"
              >
                Siparişi tamamla
              </Link>
            ) : (
              <p
                aria-disabled="true"
                className="mt-5 block cursor-not-allowed rounded-lg bg-neutral-200 px-4 py-3 text-center text-sm font-semibold text-neutral-600"
              >
                {orderingOpen ? 'Siparişi tamamla' : 'Sipariş alımı kapalı'}
              </p>
            )}

            <Link
              href="/menu"
              className="mt-3 block rounded-lg border border-neutral-200 px-4 py-3 text-center text-sm font-semibold text-neutral-900 hover:bg-neutral-100"
            >
              Alışverişe devam et
            </Link>
          </aside>
        </div>
      )}
    </div>
  );
}
