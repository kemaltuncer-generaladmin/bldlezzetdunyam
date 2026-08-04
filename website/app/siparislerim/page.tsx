import type { Metadata } from 'next';
import Link from 'next/link';
import { ErrorState } from '@/components/error-state';
import { fetchOrders } from '@/lib/api/orders';
import { formatDateTime, formatPrice } from '@/lib/format';
import { orderStatusLabel } from '@/lib/labels';
import { requireSession } from '@/lib/require-session';
import { cn } from '@/lib/cn';
import type { OrderListResponse, OrderStatus } from '@/lib/api/types';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Siparişlerim',
  description: 'Geçmiş ve devam eden siparişleriniz.',
  robots: { index: false, follow: false },
};

const STATUS_TONE: Record<OrderStatus, string> = {
  yeni: 'bg-info/10 text-info',
  onaylandi: 'bg-info/10 text-info',
  hazirlaniyor: 'bg-warning/15 text-[#713F12]',
  hazir: 'bg-success/10 text-[#14532D]',
  yolda: 'bg-brand-100 text-brand-800',
  teslim_edildi: 'bg-neutral-100 text-neutral-800',
  iptal: 'bg-danger/10 text-danger',
};

function statusTone(status: string): string {
  return STATUS_TONE[status as OrderStatus] ?? 'bg-neutral-100 text-neutral-800';
}

type SearchParams = { sayfa?: string | string[] };

function parsePage(value: string | string[] | undefined): number {
  const raw = Array.isArray(value) ? value[0] : value;
  const parsed = raw ? Number.parseInt(raw, 10) : 1;
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : 1;
}

export default async function MyOrdersPage({
  searchParams,
}: {
  searchParams: Promise<SearchParams>;
}) {
  const params = await searchParams;
  const page = parsePage(params.sayfa);
  const { token } = await requireSession('/siparislerim');

  let result: OrderListResponse;
  try {
    result = await fetchOrders(token, page);
  } catch {
    return (
      <div className="mx-auto max-w-3xl px-4 py-16">
        <ErrorState
          title="Siparişler yüklenemedi"
          message="Sipariş geçmişiniz yüklenemedi, tekrar deneyin."
          retryHref="/siparislerim"
        />
      </div>
    );
  }

  const { data: orders, meta } = result;

  return (
    <div className="mx-auto max-w-3xl px-4 py-8 sm:py-12">
      <h1 className="text-3xl font-bold text-neutral-900">Siparişlerim</h1>

      {orders.length === 0 ? (
        <div className="mt-8">
          <ErrorState
            title="Henüz siparişiniz yok"
            message="Menüden seçim yaparak ilk siparişinizi oluşturabilirsiniz."
            retryHref="/menu"
            retryLabel="Menüye git"
          />
        </div>
      ) : (
        <>
          <ul className="mt-6 space-y-3">
            {orders.map((order) => (
              <li key={order.id}>
                <Link
                  href={`/siparis/${order.id}`}
                  className="bld-card flex flex-wrap items-center justify-between gap-3 p-4 transition-shadow hover:shadow-md"
                >
                  <div className="min-w-0">
                    <p className="text-base font-semibold text-neutral-900">
                      {order.order_number}
                    </p>
                    <p className="mt-0.5 text-sm text-neutral-600">
                      {formatDateTime(order.created_at)} · {order.item_count} ürün
                    </p>
                  </div>

                  <div className="flex items-center gap-3">
                    <span
                      className={cn(
                        'rounded-full px-3 py-1 text-xs font-semibold',
                        statusTone(order.status),
                      )}
                    >
                      {orderStatusLabel(order.status)}
                    </span>
                    <span className="text-base font-bold text-neutral-900">
                      {formatPrice(order.total)}
                    </span>
                  </div>
                </Link>
              </li>
            ))}
          </ul>

          {meta.last_page > 1 && (
            <nav aria-label="Sayfalama" className="mt-8 flex items-center justify-between gap-3">
              {page > 1 ? (
                <Link
                  href={`/siparislerim?sayfa=${page - 1}`}
                  className="rounded-lg border border-neutral-200 px-4 py-2.5 text-sm font-semibold text-neutral-900 hover:bg-neutral-100"
                >
                  Önceki
                </Link>
              ) : (
                <span />
              )}

              <span className="text-sm text-neutral-600">
                Sayfa {meta.page} / {meta.last_page}
              </span>

              {page < meta.last_page ? (
                <Link
                  href={`/siparislerim?sayfa=${page + 1}`}
                  className="rounded-lg border border-neutral-200 px-4 py-2.5 text-sm font-semibold text-neutral-900 hover:bg-neutral-100"
                >
                  Sonraki
                </Link>
              ) : (
                <span />
              )}
            </nav>
          )}
        </>
      )}
    </div>
  );
}
