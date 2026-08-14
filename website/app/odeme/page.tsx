import type { Metadata } from 'next';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { CalendarDays, UtensilsCrossed } from 'lucide-react';
import { CheckoutForm } from '@/components/checkout-form';
import { ErrorState } from '@/components/error-state';
import { KitchenBusyBanner } from '@/components/kitchen-busy-banner';
import { Money } from '@/components/money';
import { OrderingClosedBanner } from '@/components/ordering-banner';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { Button } from '@/components/ui/button';
import { fetchAddresses } from '@/lib/api/addresses';
import { isOrderingOpen } from '@/lib/api/catalog';
import { businessToday, formatLongDate, serviceDayTitle } from '@/lib/business-date';
import { resolveCart } from '@/lib/cart';
import { readLocationEta } from '@/lib/eta';
import { dayUnavailableCopy } from '@/lib/labels';
import { requireSession } from '@/lib/require-session';
import { istanbulNowLocalValue } from '@/lib/timezone';
import { isOfferedPaymentMethod } from '@/lib/validation/checkout';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Siparişi tamamla',
  description: 'Teslimat bilgilerinizi girin ve siparişinizi onaylayın.',
  robots: { index: false, follow: false },
};

export default async function CheckoutPage() {
  const { customer, token } = await requireSession('/odeme');

  /*
   * Kayıtlı adresler (W-15). Hata YUTULUYOR: adres defteri okunamazsa
   * ödeme adımının tamamen kapanması orantısız olurdu — müşteri adresini
   * elle yazıp siparişini yine verebilmeli.
   */
  const savedAddresses = await fetchAddresses(token)
    .then((response) => response.data)
    .catch(() => []);
  const cart = await resolveCart();

  if (cart.lines.length === 0 || cart.serviceDate === null) redirect('/sepet');

  const today = businessToday();
  const serviceDate = cart.serviceDate;
  const isToday = serviceDate === today;
  const orderingOpen = isOrderingOpen(cart.location);
  const minOrderTotal = cart.location?.min_order_total ?? 0;
  const deliveryFee = cart.location?.delivery_fee ?? 0;
  const belowMinimum = cart.subtotal < minOrderTotal;
  /*
   * `account` SÜZÜLÜYOR (B-19). Panelden açık bırakılmış olabilir ama cari
   * hesap müşteri arayüzünden kaldırıldı; borcunu göremeyeceği bir hesaba
   * yazdırma seçeneği sunmak müşteriyi ölçemediği bir yükümlülüğe sokardı.
   * Süzme LİSTE BOŞ MU denetiminden ÖNCE: yalnız `account` açıksa ekran
   * "ödeme yöntemi bulunamadı" demeli, tek seçenekli bir form değil.
   */
  const paymentMethods = (cart.location?.payment_methods ?? []).filter(isOfferedPaymentMethod);
  const dayCopy = dayUnavailableCopy(cart.dayUnavailableReason, serviceDate);

  const blocked = !orderingOpen || !cart.dayOrderable || cart.hasUnavailable || belowMinimum;

  return (
    <div className="mx-auto max-w-content px-4 py-8 sm:py-12">
      <h1 className="font-display text-h1 font-semibold text-heading">Siparişi tamamla</h1>
      <p className="mt-2 text-body text-muted-foreground">
        {customer.first_name} {customer.last_name} adına sipariş veriyorsunuz.
      </p>

      {/*
        SERVİS GÜNÜ ÖDEME EKRANININ EN ÜSTÜNDE. Sipariş "hangi gün için"
        sorusunun cevabı, onay anında görünür olmalı: ileri tarihli bir
        sipariş verdiğini fark etmeyen müşteri yemeği bugün bekler.
      */}
      <p className="mt-4 inline-flex flex-wrap items-center gap-2 rounded-sm bg-accent px-3 py-2 text-body text-accent-foreground">
        <CalendarDays aria-hidden="true" strokeWidth={1.75} className="size-4" />
        <span className="font-semibold">{serviceDayTitle(serviceDate, today)}</span>
        <span>· {formatLongDate(serviceDate)}</span>
      </p>

      {!orderingOpen && (
        <div className="mt-5">
          <OrderingClosedBanner location={cart.location} />
          <KitchenBusyBanner />
        </div>
      )}

      {!cart.dayOrderable && orderingOpen && (
        <div
          role="alert"
          className="mt-5 rounded-md bg-danger-surface px-4 py-3 text-danger-foreground"
        >
          <p className="text-label">{dayCopy.title}</p>
          <p className="mt-1 text-body-sm">{dayCopy.message}</p>
        </div>
      )}

      {cart.hasUnavailable && (
        <p
          role="alert"
          className="mt-5 rounded-md bg-danger-surface px-4 py-3 text-body-sm text-danger-foreground"
        >
          Sepetinizde tükenen ürün var. Siparişi tamamlayabilmek için sepetten çıkarın.
        </p>
      )}

      {belowMinimum && (
        <Alert variant="warning" role="alert" className="mt-5">
          <AlertDescription>
            Minimum sipariş tutarı <Money kurus={minOrderTotal} size="sm" />. Sepet tutarınız{' '}
            <Money kurus={cart.subtotal} size="sm" />.
          </AlertDescription>
        </Alert>
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
              savedAddresses={savedAddresses}
              paymentMethods={paymentMethods}
              serviceDate={serviceDate}
              /*
               * Saat seçicinin alt sınırı: bugüne sipariş veriliyorsa
               * "şimdi + 30 dk", ileri bir güne veriliyorsa o günün başı.
               * Sözleşme `requested_at` ile `service_date`in AYNI GÜN
               * olmasını şart koşuyor.
               */
              minRequestedAt={isToday ? istanbulNowLocalValue(30) : `${serviceDate}T00:00`}
              orderCutoff={cart.location?.order_cutoff ?? null}
              /*
               * Tahmin ÖZETTE değil formda gösteriliyor ve YALNIZ bugüne
               * verilen siparişte: "şimdiden 45 dakika" cuma menüsü için
               * anlamsız.
               */
              eta={isToday ? readLocationEta(cart.location) : null}
            />
          )}
        </div>

        <aside className="h-fit rounded-md bg-card p-5 text-card-foreground shadow-card lg:sticky lg:top-24 dark:shadow-none dark:inset-ring dark:inset-ring-white/5">
          <h2 className="font-display text-h3 font-semibold text-heading">Sipariş özeti</h2>
          <p className="mt-1 text-body-sm text-muted-foreground">
            {formatLongDate(serviceDate)} için
          </p>

          <ul className="mt-4 space-y-3">
            {cart.lines.map((line) => (
              <li key={line.key} className="flex justify-between gap-3 text-body-sm">
                <span className="min-w-0">
                  <span className="block font-medium">
                    {line.quantity} × {line.name}
                  </span>

                  {/* Paketin içindekiler: fiyatsız, bir alt seviyede. */}
                  {line.isPackage && line.components.length > 0 && (
                    <ul className="mt-1 space-y-0.5 border-l-2 border-border pl-2">
                      {line.components.map((component) => (
                        <li
                          key={component.menu_id}
                          className="flex items-start gap-1.5 text-caption text-muted-foreground"
                        >
                          <UtensilsCrossed
                            aria-hidden="true"
                            strokeWidth={1.75}
                            className="mt-0.5 size-3 shrink-0"
                          />
                          {component.name}
                          {component.quantity > 1 && ` × ${component.quantity}`}
                        </li>
                      ))}
                    </ul>
                  )}

                  {line.optionValues.length > 0 && (
                    <span className="block text-muted-foreground">
                      {line.optionValues.map((value) => value.name).join(', ')}
                    </span>
                  )}
                  {line.note && (
                    <span className="block text-muted-foreground">Not: {line.note}</span>
                  )}
                </span>
                <Money kurus={line.lineTotal} size="sm" className="shrink-0" />
              </li>
            ))}
          </ul>

          <div className="mt-4 space-y-2 border-t pt-4 text-body-sm">
            <div className="flex justify-between">
              <span className="text-muted-foreground">Ara toplam</span>
              <Money kurus={cart.subtotal} size="sm" />
            </div>
            <div className="flex justify-between gap-3">
              <span className="text-muted-foreground">Teslimat ücreti</span>
              <span className="text-right">
                {deliveryFee > 0 ? (
                  <>
                    <Money kurus={deliveryFee} size="sm" /> (adrese teslimde)
                  </>
                ) : (
                  'Ücretsiz'
                )}
              </span>
            </div>
          </div>

          <p className="mt-3 text-caption text-muted-foreground">
            Kesin tutar sipariş oluşturulurken sunucuda hesaplanır ve sipariş takip ekranında
            görünür.
          </p>

          <Button asChild variant="secondary" className="mt-5 w-full">
            <Link href="/sepet">Sepeti düzenle</Link>
          </Button>
        </aside>
      </div>
    </div>
  );
}
