import type { Metadata } from 'next';
import Link from 'next/link';
import { CartLineControls } from '@/components/cart-line-controls';
import { EtaSummary } from '@/components/delivery-eta';
import { EmptyState } from '@/components/empty-state';
import { ErrorState } from '@/components/error-state';
import { IconCart, IconChevronRight, IconTruck } from '@/components/icons';
import { KitchenBusyBanner } from '@/components/kitchen-busy-banner';
import { MinOrderProgress } from '@/components/min-order-progress';
import { OrderingClosedBanner } from '@/components/ordering-banner';
import { ProductImage } from '@/components/product-image';
import { isOrderingOpen } from '@/lib/api/catalog';
import { resolveCart, type ResolvedCart } from '@/lib/cart';
import { readLocationEta } from '@/lib/eta';
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
  const deliveryFee = cart.location?.delivery_fee ?? 0;
  const belowMinimum = cart.subtotal < minOrderTotal;
  const eta = readLocationEta(cart.location);
  const canCheckout =
    cart.lines.length > 0 && orderingOpen && !cart.hasUnavailable && !belowMinimum;

  return (
    <div className="mx-auto max-w-content px-4 py-8 sm:py-12">
      <h1 className="text-3xl font-bold">Sepetim</h1>
      {cart.lines.length > 0 && (
        <p className="mt-1 text-sm text-neutral-600">
          {cart.itemCount} ürün · {cart.lines.length} kalem
        </p>
      )}

      <div className="mt-5 space-y-3 empty:mt-0">
        {!orderingOpen && <OrderingClosedBanner location={cart.location} />}
        <KitchenBusyBanner />
      </div>

      {cart.missingMenuIds.length > 0 && (
        <p
          role="status"
          className="mt-5 rounded-card border border-warning/40 bg-warning/10 px-4 py-3 text-sm"
        >
          Sepetinizdeki {cart.missingMenuIds.length} ürün menüden kaldırıldığı için çıkarıldı.
        </p>
      )}

      {cart.lines.length === 0 ? (
        <EmptyState
          className="mt-10"
          icon={<IconCart className="h-8 w-8" />}
          title="Sepetiniz boş"
          message="Menüden ürün ekleyerek siparişinize başlayabilirsiniz. Günün yemekleri her sabah yenilenir."
          actionHref="/menu"
          actionLabel="Menüye git"
        />
      ) : (
        <div className="mt-8 grid gap-8 lg:grid-cols-[minmax(0,1fr)_21rem]">
          <ul className="space-y-4">
            {cart.lines.map((line) => (
              <li key={line.key} className="flex gap-3 bld-card p-3 sm:gap-4 sm:p-4">
                <Link
                  href={productPath(line.item)}
                  aria-hidden="true"
                  tabIndex={-1}
                  className="relative h-20 w-20 shrink-0 overflow-hidden rounded-lg bg-neutral-100 sm:h-24 sm:w-24"
                >
                  <ProductImage
                    src={line.item.image_url}
                    alt=""
                    sizes="96px"
                    className={line.unavailable ? 'grayscale' : undefined}
                  />
                </Link>

                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-start justify-between gap-2">
                    <h2 className="text-base font-semibold">
                      <Link
                        href={productPath(line.item)}
                        className="rounded-sm hover:text-brand-700"
                      >
                        {line.item.name}
                      </Link>
                    </h2>
                    <p className="text-base font-bold">{formatPrice(line.lineTotal)}</p>
                  </div>

                  {line.optionValues.length > 0 && (
                    <ul className="mt-1 flex flex-wrap gap-1.5">
                      {line.optionValues.map((value) => (
                        <li key={value.id} className="bld-badge bg-neutral-100 text-neutral-800">
                          {value.name}
                        </li>
                      ))}
                    </ul>
                  )}
                  {line.note && (
                    <p className="mt-1 text-sm text-neutral-600">
                      <span className="font-medium">Not:</span> {line.note}
                    </p>
                  )}
                  <p className="mt-1 text-sm text-neutral-600">
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

          <aside aria-labelledby="siparis-ozeti" className="h-fit bld-card p-5 lg:sticky lg:top-24">
            <h2 id="siparis-ozeti" className="text-lg font-semibold">
              Sipariş özeti
            </h2>

            <dl className="mt-4 space-y-2 text-sm">
              <div className="flex justify-between gap-3">
                <dt className="text-neutral-600">Ürünler ({cart.itemCount} adet)</dt>
                <dd className="font-medium">{formatPrice(cart.subtotal)}</dd>
              </div>
              <div className="flex justify-between gap-3">
                <dt className="flex items-center gap-1.5 text-neutral-600">
                  <IconTruck className="h-4 w-4" />
                  Teslimat ücreti
                </dt>
                <dd className="text-right text-neutral-800">
                  {deliveryFee > 0 ? `${formatPrice(deliveryFee)}` : 'Ücretsiz'}
                </dd>
              </div>
            </dl>
            <p className="mt-2 text-xs text-neutral-600">
              Teslimat ücreti yalnızca adrese teslim siparişlerde eklenir; gel-al seçerseniz
              alınmaz.
            </p>

            <div className="mt-4 flex items-baseline justify-between gap-3 border-t border-neutral-200 pt-4">
              <span className="text-sm font-semibold">Ara toplam</span>
              <span className="text-2xl font-bold">{formatPrice(cart.subtotal)}</span>
            </div>
            <p className="mt-1 text-xs text-neutral-600">
              Kesin tutar siparişi oluştururken sunucuda hesaplanır.
            </p>

            {/* Sunucu tahmini vermiyorsa (eski sürüm) kutu hiç çizilmez. */}
            {eta && <EtaSummary eta={eta} className="mt-4" />}

            <MinOrderProgress
              subtotal={cart.subtotal}
              minOrderTotal={minOrderTotal}
              className="mt-4"
            />

            {cart.hasUnavailable && (
              <p
                role="status"
                className="mt-4 rounded-md bg-danger/10 px-3 py-2 text-sm text-danger"
              >
                Sepetinizde tükenen ürün var. Devam etmek için çıkarın.
              </p>
            )}

            {canCheckout ? (
              <Link href="/odeme" className="mt-5 bld-btn-primary w-full">
                Siparişi tamamla
                <IconChevronRight className="h-4 w-4" />
              </Link>
            ) : (
              <p
                aria-disabled="true"
                className="mt-5 bld-btn w-full cursor-not-allowed bg-neutral-200 text-neutral-600"
              >
                {orderingOpen ? 'Siparişi tamamla' : 'Sipariş alımı kapalı'}
              </p>
            )}

            <Link href="/menu" className="mt-3 bld-btn-secondary w-full">
              Alışverişe devam et
            </Link>
          </aside>
        </div>
      )}
    </div>
  );
}
