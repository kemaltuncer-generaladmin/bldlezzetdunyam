'use client';

import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { OrderSteps } from '@/components/order-steps';
import { formatDateTime } from '@/lib/format';
import { Money } from '@/components/money';
import {
  deliveryTypeLabel,
  isTerminalStatus,
  orderStatusLabel,
  paymentMethodLabel,
  paymentStatusLabel,
} from '@/lib/labels';
import type { PublicOrderTracking } from '@/lib/api/types';

/** 5 saniyede bir yoklama — girişli takip ekranıyla aynı ritim (`docs/06` §4). */
const POLL_INTERVAL_MS = 5000;

/**
 * Fişteki QR'la açılan, giriş istemeyen takip görünümü (K-20).
 *
 * NEDEN `OrderTracker` YENİDEN KULLANILMIYOR: o bileşen oturuma bağlı BFF'ye
 * (`/api/siparis/{id}`) ve **iptal eylemine** bağlı. İkisi de burada
 * çalışamaz; bağlantıyı okutan kişinin oturumu yok ve elindeki imza ona
 * siparişi iptal etme yetkisi VERMEMELİ. Ortak parçalar (`OrderSteps`,
 * biçimleyiciler, etiketler) paylaşılıyor; yetkiye dokunan hiçbir şey değil.
 */
function isTracking(value: unknown): value is PublicOrderTracking {
  if (typeof value !== 'object' || value === null) return false;
  const candidate = value as Record<string, unknown>;
  return (
    typeof candidate.id === 'number' &&
    typeof candidate.order_number === 'string' &&
    typeof candidate.status === 'string'
  );
}

async function fetchFromBff(
  orderId: number,
  expires: string,
  signature: string,
): Promise<PublicOrderTracking> {
  const query = new URLSearchParams({ e: expires, s: signature });
  const response = await fetch(`/api/takip/${orderId}?${query.toString()}`, {
    cache: 'no-store',
    headers: { Accept: 'application/json' },
  });

  if (!response.ok) throw new Error(response.status === 403 ? 'imza' : 'durum');

  const body: unknown = await response.json();
  if (!isTracking(body)) throw new Error('bicim');
  return body;
}

type Props = {
  initial: PublicOrderTracking;
  expires: string;
  signature: string;
};

export function PublicOrderTracker({ initial, expires, signature }: Props) {
  const queryKey = useMemo(() => ['takip', initial.id] as const, [initial.id]);

  const { data: order } = useQuery({
    queryKey,
    queryFn: () => fetchFromBff(initial.id, expires, signature),
    initialData: initial,
    // Sipariş kapandıysa yoklama durur: terminal durumdan sonra değişecek
    // bir şey yok ve açık kalan bir sekme sunucuyu boşuna dövmemeli.
    refetchInterval: (query) =>
      isTerminalStatus(query.state.data?.status ?? '') ? false : POLL_INTERVAL_MS,
  });

  return (
    <div className="space-y-6">
      <div className="rounded-md border bg-card p-5 text-card-foreground shadow-card sm:p-6 dark:shadow-none dark:inset-ring dark:inset-ring-white/5">
        <p className="text-label text-muted-foreground">Durum</p>
        <p className="mt-1 font-display text-h2 font-semibold text-heading">
          {orderStatusLabel(order.status)}
        </p>

        <div className="mt-5">
          <OrderSteps status={order.status} deliveryType={order.delivery_type} />
        </div>
      </div>

      <dl className="rounded-md border bg-card p-5 text-body-sm text-card-foreground shadow-card sm:p-6 dark:shadow-none dark:inset-ring dark:inset-ring-white/5">
        <div className="flex justify-between gap-4 py-1.5">
          <dt className="text-muted-foreground">Teslimat</dt>
          <dd className="font-medium text-foreground">{deliveryTypeLabel(order.delivery_type)}</dd>
        </div>
        <div className="flex justify-between gap-4 py-1.5">
          <dt className="text-muted-foreground">Ödeme</dt>
          <dd className="font-medium text-foreground">
            {paymentMethodLabel(order.payment.method)} — {paymentStatusLabel(order.payment.status)}
          </dd>
        </div>
        <div className="mt-2 flex justify-between gap-4 border-t border-border pt-3">
          <dt className="text-label">Toplam</dt>
          <dd>
            <Money kurus={order.total} size="lg" />
          </dd>
        </div>
      </dl>

      {/*
        KALEM LİSTESİ VE ADRES YOK — bu sayfayı açan şey bir oturum değil,
        kâğıda basılmış bir kare. İkisi de zaten o kâğıdın üstünde yazıyor;
        kâğıttan uzun yaşayan bir URL üzerinden ikinci kez göstermek hiçbir
        şey kazandırmıyor. Ayrıntı için giriş yapılır.
      */}
      <p className="text-center text-body-sm text-muted-foreground">
        Sipariş ayrıntıları için{' '}
        <a
          href={`/siparis/${order.id}`}
          className="font-medium text-link underline underline-offset-4"
        >
          hesabınıza giriş yapın
        </a>
        .
      </p>

      <p className="text-center text-xs text-neutral-500">
        {formatDateTime(order.created_at)} tarihinde oluşturuldu.
      </p>
    </div>
  );
}
