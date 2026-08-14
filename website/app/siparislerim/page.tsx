import type { Metadata } from 'next';
import Link from 'next/link';
import { CalendarDays, ChevronRight, ShoppingBasket } from 'lucide-react';
import { EmptyState } from '@/components/empty-state';
import { ErrorState } from '@/components/error-state';
import { Money } from '@/components/money';
import { Button } from '@/components/ui/button';
import { fetchOrders } from '@/lib/api/orders';
import { businessToday, parseBusinessDate, serviceDayTitle } from '@/lib/business-date';
import { formatDateTime } from '@/lib/format';
import { orderStatusLabel } from '@/lib/labels';
import { requireSession } from '@/lib/require-session';
import { cn } from '@/lib/utils';
import type { OrderListResponse, OrderStatus } from '@/lib/api/types';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Siparişlerim',
  description: 'Geçmiş ve devam eden siparişleriniz.',
  robots: { index: false, follow: false },
};

/**
 * Durum rozetleri: her tonun ZEMİN + METİN çifti `app/tokens.css`'te
 * birlikte tanımlı ve koyu tema karşılıkları da orada. Eskiden zemin
 * `bg-info/10`, metin ise sabit hex'lerdi (`#713F12`, `#14532D`) — palette
 * karşılığı olmayan, karanlıkta okunmayan renkler.
 */
const STATUS_TONE: Record<OrderStatus, string> = {
  yeni: 'bg-info-surface text-info-foreground',
  onaylandi: 'bg-info-surface text-info-foreground',
  hazirlaniyor: 'bg-warning-surface text-warning-foreground',
  hazir: 'bg-success-surface text-success-foreground',
  yolda: 'bg-accent text-accent-foreground',
  teslim_edildi: 'bg-muted text-foreground',
  iptal: 'bg-danger-surface text-danger-foreground',
};

function statusTone(status: string): string {
  return STATUS_TONE[status as OrderStatus] ?? 'bg-muted text-foreground';
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
  const today = businessToday();

  return (
    <div className="mx-auto max-w-3xl px-4 py-8 sm:py-12">
      <h1 className="font-display text-h1 font-semibold text-heading">Siparişlerim</h1>

      {orders.length === 0 ? (
        <EmptyState
          className="mt-8"
          icon={<ShoppingBasket aria-hidden="true" strokeWidth={1.75} />}
          title="Henüz siparişiniz yok"
          message="Günün menüsüne göz atın, ilk siparişinizi buradan verin."
          actionHref="/menu"
          actionLabel="Günün menüsüne git"
        />
      ) : (
        <>
          <ul className="mt-6 space-y-3">
            {orders.map((order) => {
              /*
               * SERVİS GÜNÜ, OLUŞTURMA ANI DEĞİL. `created_at` siparişin
               * verildiği andır; ileri tarihli siparişte ikisi ayrı ve
               * müşterinin aradığı bilgi "hangi güne verdim". Alan sözleşmede
               * isteğe bağlı (eski sunucu sürümü göndermeyebilir), o yüzden
               * yokluğunda oluşturma zamanına düşülüyor.
               */
              const serviceDate = parseBusinessDate(order.service_date);

              return (
                <li key={order.id}>
                  <Link
                    href={`/siparis/${order.id}`}
                    className={cn(
                      'flex flex-wrap items-center justify-between gap-3 rounded-md bg-card p-4 text-card-foreground shadow-card',
                      'transition-[box-shadow,translate] duration-(--duration-base) ease-(--ease-out-soft)',
                      'hover:shadow-raised motion-safe:hover:-translate-y-0.5',
                      'dark:shadow-none dark:inset-ring dark:inset-ring-white/5',
                    )}
                  >
                    <div className="min-w-0">
                      <p className="text-title font-semibold">{order.order_number}</p>

                      {serviceDate ? (
                        <p className="mt-0.5 flex items-center gap-1.5 text-body-sm text-muted-foreground">
                          <CalendarDays aria-hidden="true" strokeWidth={1.75} className="size-4" />
                          {serviceDayTitle(serviceDate, today)} · {order.item_count} ürün
                        </p>
                      ) : (
                        <p className="mt-0.5 text-body-sm text-muted-foreground">
                          {formatDateTime(order.created_at)} · {order.item_count} ürün
                        </p>
                      )}
                    </div>

                    <div className="flex items-center gap-3">
                      <span className={cn('bld-badge', statusTone(order.status))}>
                        {orderStatusLabel(order.status)}
                      </span>
                      <Money kurus={order.total} size="md" />
                      <ChevronRight
                        aria-hidden="true"
                        strokeWidth={1.75}
                        className="size-5 text-neutral-400"
                      />
                    </div>
                  </Link>
                </li>
              );
            })}
          </ul>

          {meta.last_page > 1 && (
            <nav aria-label="Sayfalama" className="mt-8 flex items-center justify-between gap-3">
              {page > 1 ? (
                <Button asChild variant="secondary">
                  <Link href={`/siparislerim?sayfa=${page - 1}`}>Önceki</Link>
                </Button>
              ) : (
                <span />
              )}

              <span className="text-body-sm text-muted-foreground">
                Sayfa {meta.page} / {meta.last_page}
              </span>

              {page < meta.last_page ? (
                <Button asChild variant="secondary">
                  <Link href={`/siparislerim?sayfa=${page + 1}`}>Sonraki</Link>
                </Button>
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
