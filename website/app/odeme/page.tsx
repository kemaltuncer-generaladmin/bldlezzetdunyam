import type { Metadata } from 'next';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { CheckoutForm } from '@/components/checkout-form';
import { ErrorState } from '@/components/error-state';
import { KitchenBusyBanner, OrderingClosedBanner } from '@/components/ordering-banner';
import { isOrderingOpen } from '@/lib/api/catalog';
import { resolveCart } from '@/lib/cart';
import { formatPrice } from '@/lib/format';
import { requireSession } from '@/lib/require-session';
import { istanbulNowLocalValue } from '@/lib/timezone';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Siparişi tamamla',
  description: 'Teslimat bilgilerinizi girin ve siparişinizi onaylayın.',
  robots: { index: false, follow: false },
};

export default async function CheckoutPage() {
  const { customer } = await requireSession('/odeme');
  const cart = await resolveCart();

  if (cart.lines.length === 0) redirect('/sepet');

  const orderingOpen = isOrderingOpen(cart.location);
  const minOrderTotal = cart.location?.min_order_total ?? 0;
  const belowMinimum = cart.subtotal < minOrderTotal;
  const paymentMethods = cart.location?.payment_methods ?? [];

  const blocked = !orderingOpen || cart.hasUnavailable || belowMinimum;

  return (
    <div className="mx-auto max-w-content px-4 py-8 sm:py-12">
      <h1 className="text-3xl font-bold text-neutral-900">Siparişi tamamla</h1>
      <p className="mt-2 text-sm text-neutral-600">
        {customer.first_name} {customer.last_name} adına sipariş veriyorsunuz.
      </p>

      {!orderingOpen && (
        <div className="mt-5">
          <OrderingClosedBanner location={cart.location} />
          <KitchenBusyBanner location={cart.location} />
        </div>
      )}

      {cart.hasUnavailable && (
        <p role="alert" className="mt-5 rounded-card bg-danger/10 px-4 py-3 text-sm text-danger">
          Sepetinizde tükenen ürün var. Siparişi tamamlayabilmek için sepetten çıkarın.
        </p>
      )}

      {belowMinimum && (
        <p
          role="alert"
          className="mt-5 rounded-card bg-warning/10 px-4 py-3 text-sm text-neutral-900"
        >
          Minimum sipariş tutarı {formatPrice(minOrderTotal)}. Sepet tutarınız{' '}
          {formatPrice(cart.subtotal)}.
        </p>
      )}

      <div className="mt-8 grid gap-8 lg:grid-cols-[1fr_20rem]">
        <div>
          {blocked ? (
            <ErrorState
              title="Sipariş şu anda tamamlanamıyor"
              message="Yukarıdaki uyarıyı giderdikten sonra siparişinizi onaylayabilirsiniz."
              retryHref="/sepet"
              retryLabel="Sepete dön"
            />
          ) : paymentMethods.length === 0 ? (
            <ErrorState
              title="Ödeme yöntemi bulunamadı"
              message="Şu anda açık bir ödeme yöntemi yok. Kısa süre sonra tekrar deneyin."
              retryHref="/sepet"
              retryLabel="Sepete dön"
            />
          ) : (
            <CheckoutForm
              paymentMethods={paymentMethods}
              minRequestedAt={istanbulNowLocalValue(30)}
              orderCutoff={cart.location?.order_cutoff ?? null}
            />
          )}
        </div>

        <aside className="bld-card h-fit p-5 lg:sticky lg:top-24">
          <h2 className="text-lg font-semibold text-neutral-900">Sipariş özeti</h2>

          <ul className="mt-4 space-y-3">
            {cart.lines.map((line) => (
              <li key={line.key} className="flex justify-between gap-3 text-sm">
                <span className="min-w-0">
                  <span className="block font-medium text-neutral-900">
                    {line.quantity} × {line.item.name}
                  </span>
                  {line.optionValues.length > 0 && (
                    <span className="block text-neutral-600">
                      {line.optionValues.map((value) => value.name).join(', ')}
                    </span>
                  )}
                  {line.note && <span className="block text-neutral-600">Not: {line.note}</span>}
                </span>
                <span className="shrink-0 font-medium text-neutral-900">
                  {formatPrice(line.lineTotal)}
                </span>
              </li>
            ))}
          </ul>

          <div className="mt-4 space-y-2 border-t border-neutral-200 pt-4 text-sm">
            <div className="flex justify-between">
              <span className="text-neutral-600">Ara toplam</span>
              <span className="font-semibold text-neutral-900">{formatPrice(cart.subtotal)}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-neutral-600">Teslimat ücreti</span>
              <span className="text-neutral-600">Adrese teslimde eklenir</span>
            </div>
          </div>

          <p className="mt-3 text-xs text-neutral-600">
            Kesin tutar sipariş oluşturulurken sunucuda hesaplanır ve sipariş takip ekranında
            görünür.
          </p>

          <Link
            href="/sepet"
            className="mt-5 block rounded-lg border border-neutral-200 px-4 py-2.5 text-center text-sm font-semibold text-neutral-900 hover:bg-neutral-100"
          >
            Sepeti düzenle
          </Link>
        </aside>
      </div>
    </div>
  );
}
