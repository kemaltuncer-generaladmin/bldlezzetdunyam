import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { ErrorState } from '@/components/error-state';
import { PublicOrderTracker } from '@/components/public-order-tracker';
import { QueryProvider } from '@/components/query-provider';
import { ApiError } from '@/lib/api/client';
import { fetchPublicTracking } from '@/lib/api/orders';
import type { PublicOrderTracking } from '@/lib/api/types';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Sipariş takibi',
  description: 'Siparişinizin güncel durumu.',
  robots: { index: false, follow: false },
};

/**
 * Fişteki QR'ın açtığı takip sayfası — **giriş istemez** (K-20).
 *
 * NEDEN VAR: takip QR'ı eskiden `/siparis/{id}` adresine gidiyordu ve o
 * sayfa `requireSession` ile korunuyor (`middleware.ts` de aynı yolu
 * kapsıyor). Fişteki kareyi okutan müşteri sipariş durumunu değil giriş
 * ekranını görüyordu — kâğıda basılmış bir QR giriş isteyemez.
 *
 * BU ROTA `middleware.ts` MATCHER'INDA YOKTUR ve olmamalıdır; yetki
 * URL'deki HMAC imzasında.
 *
 * Girişli `/siparis/{id}` sayfası olduğu gibi duruyor: hesabı olan müşteri
 * için hiçbir şey değişmedi ve ayrıntılara (adres, kalemler, iptal) yalnız
 * oradan ulaşılıyor.
 */
export default async function PublicTrackingPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ e?: string; s?: string }>;
}) {
  const { id } = await params;
  const orderId = Number.parseInt(id, 10);
  if (!Number.isSafeInteger(orderId) || orderId <= 0) notFound();

  const { e: expires = '', s: signature = '' } = await searchParams;

  let order: PublicOrderTracking;
  try {
    order = await fetchPublicTracking(orderId, expires, signature);
  } catch (error) {
    /*
     * `403` = bozuk imza VEYA süresi dolmuş bağlantı; sunucu ikisini
     * ayırmıyor. Mesaj da ayırmıyor: elinde geçersiz bağlantı olan kişiye
     * "imza doğruydu ama süresi geçti" demek, bilgi vermek olurdu.
     *
     * `404` de aynı ekrana düşüyor — var olmayan sipariş ile başkasının
     * siparişi ayırt edilememeli (`/siparis/{id}` sayfasındaki kararla
     * aynı).
     */
    if (error instanceof ApiError && (error.status === 403 || error.status === 404)) {
      return (
        <div className="mx-auto max-w-3xl px-4 py-16">
          <ErrorState
            title="Bağlantı geçersiz"
            message="Takip bağlantısı geçersiz ya da süresi dolmuş. Siparişinizi hesabınızdan takip edebilirsiniz."
            retryHref="/siparislerim"
          />
        </div>
      );
    }

    return (
      <div className="mx-auto max-w-3xl px-4 py-16">
        <ErrorState
          title="Sipariş yüklenemedi"
          message="Sipariş bilgisi alınamadı, tekrar deneyin."
          retryHref={`/takip/${orderId}?e=${encodeURIComponent(expires)}&s=${encodeURIComponent(signature)}`}
        />
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-3xl px-4 py-8 sm:py-12">
      <h1 className="text-3xl font-bold text-neutral-900">
        Sipariş {order.order_number}
      </h1>
      <p className="mt-1 text-sm text-neutral-600">
        Benim Lezzet Dünyam — sipariş takibi
      </p>

      <div className="mt-6">
        <QueryProvider>
          <PublicOrderTracker
            initial={order}
            expires={expires}
            signature={signature}
          />
        </QueryProvider>
      </div>
    </div>
  );
}
