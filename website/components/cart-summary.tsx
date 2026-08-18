'use client';

import { useSyncExternalStore } from 'react';
import Link from 'next/link';
import { ShoppingBasket } from 'lucide-react';
import { MinOrderProgress } from '@/components/min-order-progress';
import { Button } from '@/components/ui/button';
import { Money } from '@/components/money';
import {
  getCartSummary,
  getCartSummaryServerSnapshot,
  subscribeCartSummary,
  type CartSummary,
} from '@/lib/cart-summary-store';
import { businessToday, isBusinessDate, serviceDayTitle } from '@/lib/business-date';

/**
 * Sepet özetini paylaşılan depodan okur (`lib/cart-summary-store.ts`).
 *
 * Sepet `httpOnly` cookie'de olduğu için tarayıcı tutarı kendisi hesaplayamaz;
 * ayrıntılı gerekçe `/api/sepet-ozeti` başındaki notta. Yoklama yok — yalnızca
 * ilk yükleme, sepet değişimi ve sekmeye dönüş.
 *
 * ESKİDEN HER BİLEŞEN KENDİ İSTEĞİNİ ATIYORDU. Kutu ve çubuk aynı sayfada
 * daima birlikte monteli (görünürlükleri yalnız CSS ile ayrılıyor), yani her
 * tazelemede uç noktaya iki istek gidiyor ve platformda `resolveCart()` iki
 * kez koşuyordu. Depo isteği tekilleştiriyor.
 */
function useCartSummary(): CartSummary | null {
  return useSyncExternalStore(
    subscribeCartSummary,
    getCartSummary,
    getCartSummaryServerSnapshot,
  );
}

/** Masaüstünde menünün yanında duran yapışkan sepet kutusu. */
export function CartSummaryPanel() {
  const summary = useCartSummary();
  const count = summary?.count ?? 0;

  return (
    <aside
      aria-label="Sepet özeti"
      className="sticky top-32 hidden h-fit rounded-md bg-card p-5 text-card-foreground shadow-card lg:block dark:shadow-none dark:inset-ring dark:inset-ring-white/5"
      data-testid="cart-summary-panel"
    >
      <h2 className="flex items-center gap-2 font-display text-h3 font-semibold text-heading">
        <ShoppingBasket
          strokeWidth={1.75}
          aria-hidden="true"
          className="size-5 text-primary-text"
        />
        Sepetim
      </h2>

      {/* Sepet bir güne bağlı; hangi gün olduğu tutardan önce gelir. */}
      {summary?.serviceDate && isBusinessDate(summary.serviceDate) && (
        <p className="mt-1 text-body-sm text-muted-foreground">
          {serviceDayTitle(summary.serviceDate, businessToday())}
        </p>
      )}

      {count === 0 ? (
        <p className="mt-3 text-body-sm text-muted-foreground">
          Sepetiniz henüz boş. Bir gün seçip o günün menüsünü ekledikçe tutar burada görünür.
        </p>
      ) : (
        <>
          <dl className="mt-4 space-y-2 text-body-sm">
            <div className="flex justify-between gap-3">
              <dt className="text-muted-foreground">Ürün</dt>
              <dd className="font-medium">{count} adet</dd>
            </div>
            <div className="flex justify-between gap-3">
              <dt className="text-muted-foreground">Ara toplam</dt>
              <dd>
                <Money kurus={summary?.subtotal ?? 0} size="lg" />
              </dd>
            </div>
          </dl>

          {summary && (
            <MinOrderProgress
              subtotal={summary.subtotal}
              minOrderTotal={summary.minOrderTotal}
              className="mt-3"
            />
          )}

          {summary?.hasUnavailable && (
            <p className="mt-3 rounded-sm bg-danger-surface px-3 py-2 text-body-sm text-danger-foreground">
              Sepetinizde tükenen ürün var, sipariş öncesi çıkarmanız gerekiyor.
            </p>
          )}

          <Button asChild className="mt-4 w-full">
            <Link href="/sepet">Sepete git</Link>
          </Button>
        </>
      )}
    </aside>
  );
}

/**
 * Mobilde ekranın altına sabitlenen sepet çubuğu. Sepet boşken hiç
 * çizilmez — küçük ekranda boş bir çubuk yer israfıdır.
 */
export function CartSummaryBar() {
  const summary = useCartSummary();
  if (!summary || summary.count === 0) return null;

  return (
    <div
      className="fixed inset-x-0 bottom-0 z-40 border-t bg-card/95 pb-[env(safe-area-inset-bottom)] shadow-overlay backdrop-blur-sm lg:hidden"
      data-testid="cart-summary-bar"
    >
      <div className="mx-auto flex max-w-content items-center gap-3 px-4 py-3">
        <div className="min-w-0 flex-1">
          <p className="truncate text-body-sm font-semibold">
            {summary.count} ürün · <Money kurus={summary.subtotal} size="sm" />
          </p>
          {summary.serviceDate && isBusinessDate(summary.serviceDate) && (
            <p className="truncate text-caption text-muted-foreground">
              {serviceDayTitle(summary.serviceDate, businessToday())}
            </p>
          )}
          {summary.minOrderTotal > 0 && summary.remainingToMinimum > 0 && (
            <p className="truncate text-caption text-muted-foreground">
              Asgari tutara <Money kurus={summary.remainingToMinimum} size="sm" tone="muted" />{' '}
              kaldı
            </p>
          )}
        </div>
        <Button asChild className="shrink-0">
          <Link href="/sepet">
            <ShoppingBasket strokeWidth={1.75} aria-hidden="true" />
            Sepete git
          </Link>
        </Button>
      </div>
    </div>
  );
}
