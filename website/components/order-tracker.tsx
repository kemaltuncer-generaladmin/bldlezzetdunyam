'use client';

import { useActionState, useEffect, useMemo, useRef } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { UtensilsCrossed } from 'lucide-react';
import { cancelOrderAction } from '@/app/actions/order';
import { IDLE_CANCEL_STATE } from '@/lib/action-state';
import { OrderEtaNote } from '@/components/delivery-eta';
import { OrderSteps } from '@/components/order-steps';
import { Money } from '@/components/money';
import { Button } from '@/components/ui/button';
import { businessToday, formatLongDate, type BusinessDate } from '@/lib/business-date';
import { formatDateTime } from '@/lib/format';
import {
  deliveryTypeLabel,
  isCancellable,
  isTerminalStatus,
  orderStatusLabel,
  paymentMethodLabel,
  paymentStatusLabel,
} from '@/lib/labels';
import { cn } from '@/lib/utils';
import type { EtaWindow, OrderDetail, OrderItem } from '@/lib/api/types';

/** 5 saniyede bir yoklama — `docs/06` §4 (Faz 1.5'te WebSocket). */
const POLL_INTERVAL_MS = 5000;

function isOrderDetail(value: unknown): value is OrderDetail {
  if (typeof value !== 'object' || value === null) return false;
  const candidate = value as Record<string, unknown>;
  return (
    typeof candidate.id === 'number' &&
    typeof candidate.order_number === 'string' &&
    typeof candidate.status === 'string' &&
    Array.isArray(candidate.items)
  );
}

async function fetchOrderFromBff(orderId: number): Promise<OrderDetail> {
  const response = await fetch(`/api/siparis/${orderId}`, {
    cache: 'no-store',
    headers: { Accept: 'application/json' },
  });

  if (!response.ok) {
    throw new Error(response.status === 401 ? 'oturum' : 'durum');
  }

  const body: unknown = await response.json();
  if (!isOrderDetail(body)) throw new Error('bicim');
  return body;
}

/** Kart yüzeyi — koyu temada gölge yerine açıklık adımı + iç halka. */
const CARD =
  'rounded-md bg-card p-5 text-card-foreground shadow-card dark:shadow-none dark:inset-ring dark:inset-ring-white/5';

/**
 * PAKET VE İÇİNDEKİLER İÇ İÇE (B-19).
 *
 * Sözleşme satırları düz bir dizi olarak veriyor; hiyerarşi `role` ve
 * `included_in` alanlarında: `component` satırının `included_in` değeri, ait
 * olduğu paket satırının DİZİDEKİ SIRASI. Burada o düz dizi ağaca çevriliyor.
 *
 * Bileşen satırlarının `unit_price` ve `line_total` değerleri SIFIR ve
 * GÖSTERİLMİYOR: parayı paket satırı taşıyor. "0,00 ₺" yazmak müşteriye
 * yemeklerin bedava olduğunu düşündürüyor, paketin fiyatını da tartışmaya
 * açıyordu.
 *
 * `included_in` bilinmeyen bir sıraya işaret ediyorsa satır KÖK seviyede
 * kalıyor: eksik göstermektense fazladan göstermek doğru — hiçbir satır
 * sessizce kaybolmuyor.
 */
type OrderLineNode = { item: OrderItem; index: number; children: OrderItem[] };

function buildLineTree(items: readonly OrderItem[]): OrderLineNode[] {
  const nodes: OrderLineNode[] = [];
  const byIndex = new Map<number, OrderLineNode>();

  items.forEach((item, index) => {
    if (item.role === 'component') return;
    const node = { item, index, children: [] as OrderItem[] };
    nodes.push(node);
    byIndex.set(index, node);
  });

  items.forEach((item) => {
    if (item.role !== 'component') return;
    const parent = typeof item.included_in === 'number' ? byIndex.get(item.included_in) : undefined;
    if (parent) {
      parent.children.push(item);
    } else {
      nodes.push({ item, index: -1, children: [] });
    }
  });

  return nodes;
}

function OrderLines({ items }: { items: readonly OrderItem[] }) {
  const tree = buildLineTree(items);

  return (
    <ul className="mt-4 space-y-3">
      {tree.map((node, position) => (
        <li
          key={`${node.item.menu_id}-${position}`}
          className="flex justify-between gap-3 text-body-sm"
        >
          <span className="min-w-0">
            <span className="block font-medium">
              {node.item.quantity} × {node.item.name}
            </span>

            {node.children.length > 0 && (
              <ul className="mt-1 space-y-0.5 border-l-2 border-border pl-2">
                {node.children.map((child, childIndex) => (
                  <li
                    key={`${child.menu_id}-${childIndex}`}
                    className="flex items-start gap-1.5 text-caption text-muted-foreground"
                  >
                    <UtensilsCrossed
                      aria-hidden="true"
                      strokeWidth={1.75}
                      className="mt-0.5 size-3 shrink-0"
                    />
                    {child.quantity > 1 && `${child.quantity} × `}
                    {child.name}
                  </li>
                ))}
              </ul>
            )}

            {(node.item.options ?? []).length > 0 && (
              <span className="block text-muted-foreground">
                {(node.item.options ?? []).join(', ')}
              </span>
            )}
            {node.item.note && (
              <span className="block text-muted-foreground">Not: {node.item.note}</span>
            )}
          </span>

          <Money kurus={node.item.line_total} size="sm" className="shrink-0" />
        </li>
      ))}
    </ul>
  );
}

export function OrderTracker({
  initialOrder,
  eta,
}: {
  initialOrder: OrderDetail;
  /** Vitrinin teslim süresi tahmini; sunucu vermiyorsa `null`. */
  eta: EtaWindow | null;
}) {
  const queryClient = useQueryClient();
  const queryKey = useMemo(() => ['order', initialOrder.id] as const, [initialOrder.id]);

  const { data: order, isError } = useQuery({
    queryKey,
    queryFn: () => fetchOrderFromBff(initialOrder.id),
    initialData: initialOrder,
    // Terminal durumda yoklamayı durdur — gereksiz istek atma.
    refetchInterval: (query) =>
      query.state.data && isTerminalStatus(query.state.data.status) ? false : POLL_INTERVAL_MS,
  });

  const [cancelState, cancelAction, cancelling] = useActionState(
    cancelOrderAction,
    IDLE_CANCEL_STATE,
  );
  const lastHandled = useRef(0);

  useEffect(() => {
    if (cancelState.at === 0 || cancelState.at === lastHandled.current) return;
    lastHandled.current = cancelState.at;
    if (cancelState.status === 'ok') {
      void queryClient.invalidateQueries({ queryKey });
    }
  }, [cancelState, queryClient, queryKey]);

  const canCancel = isCancellable(order.status);
  const lastUpdate = order.status_history.at(-1);
  const serviceDate = (order.service_date ?? null) as BusinessDate | null;
  /*
   * İLERİ TARİHLİ SİPARİŞTE TAHMİN BANDI GİZLİ. `EtaService` "şimdiden N
   * dakika" diyor; cuma için verilmiş bir siparişte bu sayı yanlış bir
   * beklenti yaratıyor — müşteri yemeğin bugün geleceğini sanıyor.
   */
  const isToday = serviceDate === null || serviceDate === businessToday();

  return (
    <div className="space-y-6">
      <section className={CARD}>
        <div className="flex flex-wrap items-baseline justify-between gap-2">
          <h2 className="font-display text-h3 font-semibold text-heading">
            Sipariş durumu:{' '}
            <span className="text-primary-text">{orderStatusLabel(order.status)}</span>
          </h2>
          <span className="text-body-sm text-muted-foreground">
            {deliveryTypeLabel(order.delivery_type)}
          </span>
        </div>

        <p aria-live="polite" className="sr-only">
          Sipariş durumu: {orderStatusLabel(order.status)}
        </p>

        <div className="mt-5">
          <OrderSteps status={order.status} deliveryType={order.delivery_type} />
        </div>

        {/*
         * Tahmin yalnızca "en kısa sürede" verilen ve BUGÜNE ait siparişlerde
         * anlamlı. Müşteri belirli bir saat seçtiyse teslim zamanını ZATEN
         * kendisi belirlemiş; aşağıda "İstenen teslim zamanı" olarak duruyor.
         * Sipariş bittiyse veya iptal olduysa da tahminin işi kalmaz.
         */}
        {eta && isToday && !order.requested_at && !isTerminalStatus(order.status) && (
          <OrderEtaNote
            estimate={eta}
            deliveryType={order.delivery_type}
            createdAt={order.created_at}
          />
        )}

        {lastUpdate && (
          <p className="mt-4 text-body-sm text-muted-foreground">
            Son güncelleme: {formatDateTime(lastUpdate.at)}
          </p>
        )}

        {isError && (
          <p
            role="status"
            className="mt-3 rounded-sm bg-warning-surface px-3 py-2 text-body-sm text-warning-foreground"
          >
            Durum bilgisi şu an yenilenemiyor. Son bilinen durum gösteriliyor.
          </p>
        )}

        {canCancel && (
          <form action={cancelAction} className="mt-5">
            <input type="hidden" name="order_id" value={order.id} />
            {/*
              Yerinde yıkıcı eylem GHOST + danger: dolu kırmızı bir buton
              sayfanın gerçek birincil eylemiyle yarışıyor ve yanlışlıkla
              tıklanıyor (marka kılavuzu).
            */}
            <Button
              type="submit"
              variant="ghost"
              className="text-danger-foreground hover:bg-danger-surface"
              disabled={cancelling}
              disabledReason="İptal ediliyor."
            >
              {cancelling ? 'İptal ediliyor…' : 'Siparişi iptal et'}
            </Button>
          </form>
        )}

        {cancelState.message && (
          <p
            role="alert"
            className={cn(
              'mt-3 rounded-sm px-3 py-2 text-body-sm',
              cancelState.status === 'error'
                ? 'bg-danger-surface text-danger-foreground'
                : 'bg-muted text-foreground',
            )}
          >
            {cancelState.message}
          </p>
        )}
      </section>

      <section className={CARD}>
        <h2 className="font-display text-h3 font-semibold text-heading">Sipariş içeriği</h2>
        {serviceDate && (
          <p className="mt-1 text-body-sm text-muted-foreground">
            {formatLongDate(serviceDate)} için
          </p>
        )}

        <OrderLines items={order.items} />

        <dl className="mt-4 space-y-2 border-t pt-4 text-body-sm">
          <div className="flex justify-between">
            <dt className="text-muted-foreground">Ara toplam</dt>
            <dd>
              <Money kurus={order.subtotal} size="sm" />
            </dd>
          </div>
          <div className="flex justify-between">
            <dt className="text-muted-foreground">Teslimat ücreti</dt>
            <dd>
              <Money kurus={order.delivery_fee} size="sm" />
            </dd>
          </div>
          <div className="flex justify-between border-t pt-2">
            <dt className="text-label">Toplam</dt>
            <dd>
              <Money kurus={order.total} size="lg" />
            </dd>
          </div>
        </dl>
      </section>

      <section className={CARD}>
        <h2 className="font-display text-h3 font-semibold text-heading">Teslimat ve ödeme</h2>
        <dl className="mt-4 space-y-3 text-body-sm">
          {serviceDate && (
            <div>
              <dt className="text-muted-foreground">Servis günü</dt>
              <dd className="font-medium">{formatLongDate(serviceDate)}</dd>
            </div>
          )}

          <div>
            <dt className="text-muted-foreground">Teslimat şekli</dt>
            <dd className="font-medium">{deliveryTypeLabel(order.delivery_type)}</dd>
          </div>

          {order.address && (
            <div>
              <dt className="text-muted-foreground">Adres</dt>
              <dd className="font-medium">
                {order.address.line1}, {order.address.district} / {order.address.city}
                {order.address.note && (
                  <span className="block font-normal text-muted-foreground">
                    {order.address.note}
                  </span>
                )}
              </dd>
            </div>
          )}

          {order.requested_at && (
            <div>
              <dt className="text-muted-foreground">İstenen teslim zamanı</dt>
              <dd className="font-medium">{formatDateTime(order.requested_at)}</dd>
            </div>
          )}

          <div>
            <dt className="text-muted-foreground">Ödeme</dt>
            <dd className="font-medium">
              {paymentMethodLabel(order.payment.method)} —{' '}
              {paymentStatusLabel(order.payment.status)}
            </dd>
          </div>

          {order.customer_note && (
            <div>
              <dt className="text-muted-foreground">Sipariş notu</dt>
              <dd className="font-medium">{order.customer_note}</dd>
            </div>
          )}
        </dl>
      </section>

      {order.status_history.length > 0 && (
        <section className={CARD}>
          <h2 className="font-display text-h3 font-semibold text-heading">Durum geçmişi</h2>
          <ol className="mt-4 space-y-2 text-body-sm">
            {order.status_history.map((entry, index) => (
              <li key={`${entry.status}-${index}`} className="flex justify-between gap-3">
                <span>{orderStatusLabel(entry.status)}</span>
                <span className="text-muted-foreground">{formatDateTime(entry.at)}</span>
              </li>
            ))}
          </ol>
        </section>
      )}
    </div>
  );
}
