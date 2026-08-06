import type { Metadata } from 'next';
import Link from 'next/link';
import { EmptyState } from '@/components/empty-state';
import { ErrorState } from '@/components/error-state';
import { IconCart, IconChevronRight } from '@/components/icons';
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
        <EmptyState
          className="mt-8"
          icon={<IconCart className="h-8 w-8" />}
          title="Henüz siparişiniz yok"
          message="Menüden seçim yaparak ilk siparişinizi oluşturabilirsiniz."
          actionHref="/menu"
          actionLabel="Menüye git"
        />
      ) : (
        <>
          <ul className="mt-6 space-y-3">
            {orders.map((order) => (
              <li key={order.id}>
                <Link
                  href={`/siparis/${order.id}`}
                  className="flex flex-wrap items-center justify-between gap-3 bld-card p-4 transition-shadow hover:shadow-md"
                >
                  <div className="min-w-0">
                    <p className="text-base font-semibold text-neutral-900">{order.order_number}</p>
                    <p className="mt-0.5 text-sm text-neutral-600">
                      {formatDateTime(order.created_at)} · {order.item_count} ürün
                    </p>
                  </div>

                  <div className="flex items-center gap-3">
                    <span className={cn('bld-badge', statusTone(order.status))}>
                      {orderStatusLabel(order.status)}
                    </span>
                    <span className="text-base font-bold text-neutral-900">
                      {formatPrice(order.total)}
                    </span>
                    <IconChevronRight className="h-5 w-5 text-neutral-400" />
                  </div>
                </Link>
              </li>
            ))}
          </ul>

          {meta.last_page > 1 && (
            <nav aria-label="Sayfalama" className="mt-8 flex items-center justify-between gap-3">
              {page > 1 ? (
                <Link href={`/siparislerim?sayfa=${page - 1}`} className="bld-btn-secondary">
                  Önceki
                </Link>
              ) : (
                <span />
              )}

              <span className="text-sm text-neutral-600">
                Sayfa {meta.page} / {meta.last_page}
              </span>

              {page < meta.last_page ? (
                <Link href={`/siparislerim?sayfa=${page + 1}`} className="bld-btn-secondary">
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
