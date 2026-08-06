import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ErrorState } from '@/components/error-state';
import { OrderTracker } from '@/components/order-tracker';
import { QueryProvider } from '@/components/query-provider';
import { ApiError } from '@/lib/api/client';
import { fetchPrimaryLocation } from '@/lib/api/catalog';
import { fetchOrder } from '@/lib/api/orders';
import { readEtaWindow } from '@/lib/eta';
import { formatDateTime } from '@/lib/format';
import { requireSession } from '@/lib/require-session';
import type { EtaWindow, OrderDetail } from '@/lib/api/types';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Sipariş takibi',
  description: 'Siparişinizin güncel durumu.',
  robots: { index: false, follow: false },
};

export default async function OrderTrackingPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const orderId = Number.parseInt(id, 10);
  if (!Number.isSafeInteger(orderId) || orderId <= 0) notFound();

  const { token } = await requireSession(`/siparis/${orderId}`);

  let order: OrderDetail;
  try {
    order = await fetchOrder(token, orderId);
  } catch (error) {
    // Başkasının siparişi de `404` döner — varlık sızdırılmaz.
    if (error instanceof ApiError && error.status === 404) notFound();
    return (
      <div className="mx-auto max-w-3xl px-4 py-16">
        <ErrorState
          title="Sipariş yüklenemedi"
          message="Sipariş bilgisi alınamadı, tekrar deneyin."
          retryHref={`/siparis/${orderId}`}
        />
      </div>
    );
  }

  /*
   * Tahmin vitrinden gelir, siparişten değil. Katalog önbelleği (60 sn)
   * yeterli: tahmin beş dakikaya yuvarlı, saniyesi önemli değil. Vitrin
   * okunamazsa sipariş takibi tahminsiz çalışmaya devam etmeli — bu ekranın
   * asıl işi durum göstermek.
   */
  let eta: EtaWindow | null = null;
  try {
    const location = await fetchPrimaryLocation();
    eta = readEtaWindow(location, order.delivery_type);
  } catch {
    eta = null;
  }

  return (
    <div className="mx-auto max-w-3xl px-4 py-8 sm:py-12">
      <nav aria-label="Ekmek kırıntısı" className="mb-4 text-sm text-neutral-600">
        <Link href="/siparislerim" className="rounded-sm hover:text-brand-700 hover:underline">
          Siparişlerim
        </Link>
      </nav>

      <h1 className="text-3xl font-bold text-neutral-900">Sipariş {order.order_number}</h1>
      <p className="mt-1 text-sm text-neutral-600">
        {formatDateTime(order.created_at)} tarihinde oluşturuldu.
      </p>

      <div className="mt-6">
        <QueryProvider>
          <OrderTracker initialOrder={order} eta={eta} />
        </QueryProvider>
      </div>
    </div>
  );
}
