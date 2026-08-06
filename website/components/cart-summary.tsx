'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { IconCart } from '@/components/icons';
import { MinOrderProgress } from '@/components/min-order-progress';
import { CART_CHANGED_EVENT } from '@/lib/cart-events';
import { formatPrice } from '@/lib/format';

type CartSummary = {
  count: number;
  subtotal: number;
  minOrderTotal: number;
  remainingToMinimum: number;
  hasUnavailable: boolean;
  orderingOpen: boolean;
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
      className="bld-card sticky top-32 hidden h-fit p-5 lg:block"
      data-testid="cart-summary-panel"
    >
      <h2 className="flex items-center gap-2 text-base font-bold">
        <IconCart className="h-5 w-5 text-brand-700" />
        Sepetim
      </h2>

      {count === 0 ? (
        <p className="mt-3 text-sm text-neutral-600">
          Sepetiniz henüz boş. Beğendiğiniz ürünleri ekledikçe tutar burada görünür.
        </p>
      ) : (
        <>
          <dl className="mt-4 space-y-2 text-sm">
            <div className="flex justify-between gap-3">
              <dt className="text-neutral-600">Ürün</dt>
              <dd className="font-medium">{count} adet</dd>
            </div>
            <div className="flex justify-between gap-3">
              <dt className="text-neutral-600">Ara toplam</dt>
              <dd className="text-lg font-bold">{formatPrice(summary?.subtotal ?? 0)}</dd>
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
            <p className="mt-3 rounded-md bg-danger/10 px-3 py-2 text-xs text-danger">
              Sepetinizde tükenen ürün var, sipariş öncesi çıkarmanız gerekiyor.
            </p>
          )}

          <Link href="/sepet" className="bld-btn-primary mt-4 w-full">
            Sepete git
          </Link>
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
      className="fixed inset-x-0 bottom-0 z-40 border-t border-neutral-200 bg-neutral-0/95 pb-[env(safe-area-inset-bottom)] shadow-[0_-4px_16px_rgba(28,25,23,0.08)] backdrop-blur-sm lg:hidden"
      data-testid="cart-summary-bar"
    >
      <div className="mx-auto flex max-w-content items-center gap-3 px-4 py-3">
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm font-semibold">
            {summary.count} ürün · {formatPrice(summary.subtotal)}
          </p>
          {summary.minOrderTotal > 0 && summary.remainingToMinimum > 0 && (
            <p className="truncate text-xs text-neutral-600">
              Asgari tutara {formatPrice(summary.remainingToMinimum)} kaldı
            </p>
          )}
        </div>
        <Link href="/sepet" className="bld-btn-primary shrink-0">
          <IconCart className="h-5 w-5" />
          Sepete git
        </Link>
      </div>
    </div>
  );
}
