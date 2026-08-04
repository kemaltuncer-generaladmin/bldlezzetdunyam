'use client';

import { useActionState, useEffect, useMemo, useRef } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { cancelOrderAction } from '@/app/actions/order';
import { IDLE_CANCEL_STATE } from '@/lib/action-state';
import { OrderSteps } from '@/components/order-steps';
import { formatDateTime, formatPrice } from '@/lib/format';
import {
  deliveryTypeLabel,
  isCancellable,
  isTerminalStatus,
  orderStatusLabel,
  paymentMethodLabel,
  paymentStatusLabel,
} from '@/lib/labels';
import type { OrderDetail } from '@/lib/api/types';

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

export function OrderTracker({ initialOrder }: { initialOrder: OrderDetail }) {
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

  return (
    <div className="space-y-6">
      <section className="bld-card p-5">
        <div className="flex flex-wrap items-baseline justify-between gap-2">
          <h2 className="text-lg font-semibold text-neutral-900">
            Sipariş durumu: <span className="text-brand-700">{orderStatusLabel(order.status)}</span>
          </h2>
          <span className="text-sm text-neutral-600">{deliveryTypeLabel(order.delivery_type)}</span>
        </div>

        <p aria-live="polite" className="sr-only">
          Sipariş durumu: {orderStatusLabel(order.status)}
        </p>

        <div className="mt-5">
          <OrderSteps status={order.status} deliveryType={order.delivery_type} />
        </div>

        {lastUpdate && (
          <p className="mt-4 text-sm text-neutral-600">
            Son güncelleme: {formatDateTime(lastUpdate.at)}
          </p>
        )}

        {isError && (
          <p
            role="status"
            className="mt-3 rounded-md bg-warning/10 px-3 py-2 text-sm text-neutral-900"
          >
            Durum bilgisi şu an yenilenemiyor. Son bilinen durum gösteriliyor.
          </p>
        )}

        {canCancel && (
          <form action={cancelAction} className="mt-5">
            <input type="hidden" name="order_id" value={order.id} />
            <button
              type="submit"
              disabled={cancelling}
              className="rounded-lg border border-danger px-4 py-2.5 text-sm font-semibold text-danger hover:bg-danger/10 disabled:opacity-60"
            >
              {cancelling ? 'İptal ediliyor…' : 'Siparişi iptal et'}
            </button>
          </form>
        )}

        {cancelState.message && (
          <p
            role="alert"
            className={
              cancelState.status === 'error'
                ? 'mt-3 rounded-md bg-danger/10 px-3 py-2 text-sm text-danger'
                : 'mt-3 rounded-md bg-neutral-100 px-3 py-2 text-sm text-neutral-900'
            }
          >
            {cancelState.message}
          </p>
        )}
      </section>

      <section className="bld-card p-5">
        <h2 className="text-lg font-semibold text-neutral-900">Sipariş içeriği</h2>
        <ul className="mt-4 space-y-3">
          {order.items.map((item, index) => (
            <li key={`${item.menu_id}-${index}`} className="flex justify-between gap-3 text-sm">
              <span className="min-w-0">
                <span className="block font-medium text-neutral-900">
                  {item.quantity} × {item.name}
                </span>
                {(item.options ?? []).length > 0 && (
                  <span className="block text-neutral-600">{(item.options ?? []).join(', ')}</span>
                )}
                {item.note && <span className="block text-neutral-600">Not: {item.note}</span>}
              </span>
              <span className="shrink-0 font-medium text-neutral-900">
                {formatPrice(item.line_total)}
              </span>
            </li>
          ))}
        </ul>

        <dl className="mt-4 space-y-2 border-t border-neutral-200 pt-4 text-sm">
          <div className="flex justify-between">
            <dt className="text-neutral-600">Ara toplam</dt>
            <dd className="text-neutral-900">{formatPrice(order.subtotal)}</dd>
          </div>
          <div className="flex justify-between">
            <dt className="text-neutral-600">Teslimat ücreti</dt>
            <dd className="text-neutral-900">{formatPrice(order.delivery_fee)}</dd>
          </div>
          <div className="flex justify-between border-t border-neutral-200 pt-2">
            <dt className="font-semibold text-neutral-900">Toplam</dt>
            <dd className="text-lg font-bold text-neutral-900">{formatPrice(order.total)}</dd>
          </div>
        </dl>
      </section>

      <section className="bld-card p-5">
        <h2 className="text-lg font-semibold text-neutral-900">Teslimat ve ödeme</h2>
        <dl className="mt-4 space-y-3 text-sm">
          <div>
            <dt className="text-neutral-600">Teslimat şekli</dt>
            <dd className="font-medium text-neutral-900">
              {deliveryTypeLabel(order.delivery_type)}
            </dd>
          </div>

          {order.address && (
            <div>
              <dt className="text-neutral-600">Adres</dt>
              <dd className="font-medium text-neutral-900">
                {order.address.line1}, {order.address.district} / {order.address.city}
                {order.address.note && (
                  <span className="block font-normal text-neutral-600">{order.address.note}</span>
                )}
              </dd>
            </div>
          )}

          {order.requested_at && (
            <div>
              <dt className="text-neutral-600">İstenen teslim zamanı</dt>
              <dd className="font-medium text-neutral-900">{formatDateTime(order.requested_at)}</dd>
            </div>
          )}

          <div>
            <dt className="text-neutral-600">Ödeme</dt>
            <dd className="font-medium text-neutral-900">
              {paymentMethodLabel(order.payment.method)} —{' '}
              {paymentStatusLabel(order.payment.status)}
            </dd>
          </div>

          {order.customer_note && (
            <div>
              <dt className="text-neutral-600">Sipariş notu</dt>
              <dd className="font-medium text-neutral-900">{order.customer_note}</dd>
            </div>
          )}
        </dl>
      </section>

      {order.status_history.length > 0 && (
        <section className="bld-card p-5">
          <h2 className="text-lg font-semibold text-neutral-900">Durum geçmişi</h2>
          <ol className="mt-4 space-y-2 text-sm">
            {order.status_history.map((entry, index) => (
              <li key={`${entry.status}-${index}`} className="flex justify-between gap-3">
                <span className="text-neutral-900">{orderStatusLabel(entry.status)}</span>
                <span className="text-neutral-600">{formatDateTime(entry.at)}</span>
              </li>
            ))}
          </ol>
        </section>
      )}
    </div>
  );
}
