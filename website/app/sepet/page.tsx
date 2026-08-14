import type { Metadata } from 'next';
import Link from 'next/link';
import { CalendarDays, ChevronRight, ShoppingBasket, Truck, UtensilsCrossed } from 'lucide-react';
import { clearCartAction } from '@/app/actions/cart';
import { CartLineControls } from '@/components/cart-line-controls';
import { EtaSummary } from '@/components/delivery-eta';
import { EmptyState } from '@/components/empty-state';
import { ErrorState } from '@/components/error-state';
import { KitchenBusyBanner } from '@/components/kitchen-busy-banner';
import { MinOrderProgress } from '@/components/min-order-progress';
import { Money } from '@/components/money';
import { OrderingClosedBanner } from '@/components/ordering-banner';
import { ProductImage } from '@/components/product-image';
import { Button } from '@/components/ui/button';
import { isOrderingOpen } from '@/lib/api/catalog';
import { businessToday, formatLongDate, serviceDayTitle } from '@/lib/business-date';
import { resolveCart, type ResolvedCart, type ResolvedCartLine } from '@/lib/cart';
import { readLocationEta } from '@/lib/eta';
import { dayUnavailableCopy } from '@/lib/labels';

/** Sepet cookie'ye bağlıdır — her istekte taze render edilir. */
export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Sepetim',
  description: 'Sepetinizdeki ürünleri gözden geçirin ve siparişinizi tamamlayın.',
  robots: { index: false, follow: true },
};

/**
 * Paket satırı ve içindekiler İÇ İÇE.
 *
 * PARAYI PAKET TAŞIYOR: içindekilerin fiyatı sözleşmede sıfır ve burada hiç
 * gösterilmiyor. "0,00 ₺" yazmak müşteriye "bunlar bedava" dedirtiyor,
 * paketin fiyatını da tartışmaya açıyordu. Liste bir alt seviyede ve sol
 * kenarlıkla bağlı: neyin neyin içinde olduğu bakışta anlaşılmalı.
 */
function PackageComponents({ line }: { line: ResolvedCartLine }) {
  if (!line.isPackage || line.components.length === 0) return null;

  return (
    <ul className="mt-2 space-y-1 border-l-2 border-border pl-3">
      {line.components.map((component) => (
        <li
          key={component.menu_id}
          className="flex items-start gap-2 text-body-sm text-muted-foreground"
        >
          <UtensilsCrossed
            aria-hidden="true"
            strokeWidth={1.75}
            className="mt-0.5 size-3.5 shrink-0"
          />
          <span>
            {component.name}
            {component.quantity > 1 && ` × ${component.quantity}`}
          </span>
        </li>
      ))}
    </ul>
  );
}

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

  const today = businessToday();
  const orderingOpen = isOrderingOpen(cart.location);
  const minOrderTotal = cart.location?.min_order_total ?? 0;
  const deliveryFee = cart.location?.delivery_fee ?? 0;
  const belowMinimum = cart.subtotal < minOrderTotal;
  const isToday = cart.serviceDate === today;
  /*
   * TAHMİN YALNIZ BUGÜNE. `EtaService` "şimdiden N dakika" diyor; cuma
   * menüsüne verilen bir sipariş için bu sayı anlamsız, hatta yanıltıcı —
   * müşteri yemeğin bugün geleceğini sanır.
   */
  const eta = isToday ? readLocationEta(cart.location) : null;
  const dayBlocked = cart.lines.length > 0 && !cart.dayOrderable;
  const canCheckout =
    cart.lines.length > 0 && orderingOpen && !cart.hasUnavailable && !belowMinimum && !dayBlocked;

  const dayCopy =
    cart.serviceDate !== null
      ? dayUnavailableCopy(cart.dayUnavailableReason, cart.serviceDate)
      : null;

  return (
    <div className="mx-auto max-w-content px-4 py-8 sm:py-12">
      <h1 className="font-display text-h1 font-semibold text-heading">Sepetim</h1>

      {cart.serviceDate !== null && (
        <p className="mt-2 flex flex-wrap items-center gap-x-2 gap-y-1 text-body text-muted-foreground">
          <CalendarDays aria-hidden="true" strokeWidth={1.75} className="size-4" />
          <span className="font-medium text-foreground">
            {serviceDayTitle(cart.serviceDate, today)}
          </span>
          <span>· {formatLongDate(cart.serviceDate)}</span>
          <span>
            · {cart.itemCount} ürün, {cart.lines.length} kalem
          </span>
        </p>
      )}

      <div className="mt-5 space-y-3 empty:mt-0">
        {!orderingOpen && <OrderingClosedBanner location={cart.location} />}
        <KitchenBusyBanner />
      </div>

      {/*
        v1 çerezi düşürüldü (`lib/cart.ts`). Sessizce boş bir sepet
        göstermek, müşterinin hazırladığı sepetin nereye gittiğini
        sormasına yol açardı.
      */}
      {cart.legacyDiscarded && (
        <p
          role="status"
          className="mt-5 rounded-sm bg-warning-surface px-4 py-3 text-body-sm text-warning-foreground"
        >
          Sipariş düzenimiz değişti: artık her sipariş bir güne bağlı. Eski sepetiniz bu yüzden
          boşaltıldı — günü seçip yeniden ekleyebilirsiniz.
        </p>
      )}

      {cart.missingMenuIds.length > 0 && (
        <p
          role="status"
          className="mt-5 rounded-sm bg-warning-surface px-4 py-3 text-body-sm text-warning-foreground"
        >
          Sepetinizdeki {cart.missingMenuIds.length} ürün o günün menüsünde bulunmadığı için
          çıkarıldı.
        </p>
      )}

      {dayBlocked && dayCopy && (
        <div
          role="alert"
          className="mt-5 rounded-md bg-danger-surface px-4 py-3 text-danger-foreground"
        >
          <p className="text-label">{dayCopy.title}</p>
          <p className="mt-1 text-body-sm">{dayCopy.message}</p>
          <form action={clearCartAction} className="mt-3">
            <Button type="submit" size="sm" variant="outline">
              Sepeti boşalt ve başka gün seç
            </Button>
          </form>
        </div>
      )}

      {cart.lines.length === 0 ? (
        <EmptyState
          className="mt-10"
          icon={<ShoppingBasket aria-hidden="true" strokeWidth={1.75} />}
          title="Sepetiniz boş"
          message="Bir gün seçin, o günün menüsünü paket olarak ya da tek tek sepete ekleyin."
          actionHref="/menu"
          actionLabel="Günün menüsüne git"
        />
      ) : (
        <div className="mt-8 grid gap-8 lg:grid-cols-[minmax(0,1fr)_21rem]">
          <ul className="space-y-3">
            {cart.lines.map((line) => (
              <li
                key={line.key}
                className="flex gap-3 rounded-md bg-card p-3 text-card-foreground shadow-card sm:gap-4 sm:p-4 dark:shadow-none dark:inset-ring dark:inset-ring-white/5"
              >
                <div className="relative size-14 shrink-0 overflow-hidden rounded-sm sm:size-20">
                  <ProductImage
                    src={line.imageUrl}
                    alt=""
                    sizes="80px"
                    className={line.unavailable ? 'grayscale' : undefined}
                  />
                </div>

                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-start justify-between gap-2">
                    <h2 className="text-title font-semibold">
                      {line.isPackage && (
                        <span className="mr-2 bld-badge bg-accent text-accent-foreground">
                          Menü paketi
                        </span>
                      )}
                      {line.name}
                    </h2>
                    <Money kurus={line.lineTotal} size="md" />
                  </div>

                  <PackageComponents line={line} />

                  {line.optionValues.length > 0 && (
                    <ul className="mt-1 flex flex-wrap gap-1.5">
                      {line.optionValues.map((value) => (
                        <li key={value.id} className="bld-badge bg-muted text-foreground">
                          {value.name}
                        </li>
                      ))}
                    </ul>
                  )}

                  {line.note && (
                    <p className="mt-1 text-body-sm text-muted-foreground">
                      <span className="font-medium">Not:</span> {line.note}
                    </p>
                  )}

                  <p className="mt-1 text-body-sm text-muted-foreground">
                    Birim: <Money kurus={line.unitPrice} size="sm" tone="muted" />
                  </p>

                  {line.unavailable && (
                    <p
                      role="status"
                      className="mt-2 rounded-xs bg-danger-surface px-2 py-1 text-body-sm text-danger-foreground"
                    >
                      {line.unavailableReason ??
                        'Bu ürün tükendi, siparişe eklenemez. Lütfen sepetten çıkarın.'}
                    </p>
                  )}

                  <div className="mt-3">
                    <CartLineControls
                      lineKey={line.key}
                      quantity={line.quantity}
                      itemName={line.name}
                    />
                  </div>
                </div>
              </li>
            ))}
          </ul>

          <aside
            aria-labelledby="siparis-ozeti"
            className="h-fit rounded-md bg-card p-5 text-card-foreground shadow-card lg:sticky lg:top-24 dark:shadow-none dark:inset-ring dark:inset-ring-white/5"
          >
            <h2 id="siparis-ozeti" className="font-display text-h3 font-semibold text-heading">
              Sipariş özeti
            </h2>

            {cart.serviceDate !== null && (
              <p className="mt-1 text-body-sm text-muted-foreground">
                {formatLongDate(cart.serviceDate)} için
              </p>
            )}

            <dl className="mt-4 space-y-2 text-body-sm">
              <div className="flex justify-between gap-3">
                <dt className="text-muted-foreground">Ürünler ({cart.itemCount} adet)</dt>
                <dd>
                  <Money kurus={cart.subtotal} size="sm" />
                </dd>
              </div>
              <div className="flex justify-between gap-3">
                <dt className="flex items-center gap-1.5 text-muted-foreground">
                  <Truck aria-hidden="true" strokeWidth={1.75} className="size-4" />
                  Teslimat ücreti
                </dt>
                <dd className="text-right">
                  {deliveryFee > 0 ? <Money kurus={deliveryFee} size="sm" /> : 'Ücretsiz'}
                </dd>
              </div>
            </dl>
            <p className="mt-2 text-caption text-muted-foreground">
              Teslimat ücreti yalnızca adrese teslim siparişlerde eklenir; gel-al seçerseniz
              alınmaz.
            </p>

            <div className="mt-4 flex items-baseline justify-between gap-3 border-t pt-4">
              <span className="text-label">Ara toplam</span>
              <Money kurus={cart.subtotal} size="lg" />
            </div>
            <p className="mt-1 text-caption text-muted-foreground">
              Kesin tutar siparişi oluştururken sunucuda hesaplanır.
            </p>

            {/* Sunucu tahmini vermiyorsa ya da gün ileriyse kutu hiç çizilmez. */}
            {eta && <EtaSummary eta={eta} className="mt-4" />}

            <MinOrderProgress
              subtotal={cart.subtotal}
              minOrderTotal={minOrderTotal}
              className="mt-4"
            />

            {cart.hasUnavailable && (
              <p
                role="status"
                className="mt-4 rounded-sm bg-danger-surface px-3 py-2 text-body-sm text-danger-foreground"
              >
                Sepetinizde tükenen ürün var. Devam etmek için çıkarın.
              </p>
            )}

            {canCheckout ? (
              <Button asChild className="mt-5 w-full">
                <Link href="/odeme">
                  Siparişi tamamla
                  <ChevronRight strokeWidth={1.75} aria-hidden="true" />
                </Link>
              </Button>
            ) : (
              <Button
                type="button"
                className="mt-5 w-full"
                disabled
                disabledReason={
                  dayBlocked
                    ? (dayCopy?.title ?? 'Bu güne sipariş alınmıyor')
                    : !orderingOpen
                      ? 'Sipariş alımı kapalı'
                      : cart.hasUnavailable
                        ? 'Sepette tükenen ürün var'
                        : 'Asgari sepet tutarına ulaşılmadı'
                }
              >
                {orderingOpen ? 'Siparişi tamamla' : 'Sipariş alımı kapalı'}
              </Button>
            )}

            <Button asChild variant="secondary" className="mt-3 w-full">
              <Link href={cart.serviceDate ? `/menu?gun=${cart.serviceDate}` : '/menu'}>
                Menüye dön
              </Link>
            </Button>
          </aside>
        </div>
      )}
    </div>
  );
}
