'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { ShoppingBasket } from 'lucide-react';
import { MinOrderProgress } from '@/components/min-order-progress';
import { Button } from '@/components/ui/button';
import { CART_CHANGED_EVENT } from '@/lib/cart-events';
import { Money } from '@/components/money';
import { businessToday, isBusinessDate, serviceDayTitle } from '@/lib/business-date';

type CartSummary = {
  count: number;
  subtotal: number;
  minOrderTotal: number;
  remainingToMinimum: number;
  hasUnavailable: boolean;
  orderingOpen: boolean;
  /** Sepetin bağlı olduğu servis günü (`YYYY-AA-GG`); boş sepette `null`. */
  serviceDate: string | null;
  dayOrderable: boolean;
};

function parseSummary(value: unknown): CartSummary | null {
  if (typeof value !== 'object' || value === null) return null;
  const raw = value as Record<string, unknown>;
  const num = (key: string): number => (typeof raw[key] === 'number' ? raw[key] : 0);

  return {
    count: num('count'),
    subtotal: num('subtotal'),
    minOrderTotal: num('min_order_total'),
    remainingToMinimum: num('remaining_to_minimum'),
    hasUnavailable: raw.has_unavailable === true,
    orderingOpen: raw.ordering_open === true,
    serviceDate: typeof raw.service_date === 'string' ? raw.service_date : null,
    dayOrderable: raw.day_orderable === true,
  };
}

/**
 * Sepet özetini `/api/sepet-ozeti` üzerinden okur.
 *
 * Sepet `httpOnly` cookie'de olduğu için tarayıcı tutarı kendisi hesaplayamaz;
 * ayrıntılı gerekçe uç noktanın başındaki notta. Yoklama yok — yalnızca ilk
 * yükleme, sepet değişimi ve sekmeye dönüş.
 */
function useCartSummary(): CartSummary | null {
  const [summary, setSummary] = useState<CartSummary | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function load(): Promise<void> {
      try {
        const response = await fetch('/api/sepet-ozeti', { cache: 'no-store' });
        if (!response.ok) return;
        const parsed = parseSummary(await response.json());
        if (!cancelled && parsed) setSummary(parsed);
      } catch {
        // Ağ hatasında son bilinen özet korunur; sepeti boş göstermek yanıltıcı.
      }
    }

    void load();
    window.addEventListener(CART_CHANGED_EVENT, load);
    window.addEventListener('focus', load);
    return () => {
      cancelled = true;
      window.removeEventListener(CART_CHANGED_EVENT, load);
      window.removeEventListener('focus', load);
    };
  }, []);

  return summary;
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
