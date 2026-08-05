import { NextResponse } from 'next/server';

import { isOrderingOpen } from '@/lib/api/catalog';
import { resolveCart } from '@/lib/cart';

/**
 * Sepetin anlık özeti — yapışkan sepet kutusu bunu okur.
 *
 * NEDEN AYRI UÇ: sepet `httpOnly` cookie'de tutuluyor (`lib/cart.ts`), yani
 * tarayıcı satırları okuyamaz; tutarı da yalnızca canlı menü fiyatlarıyla
 * hesaplanabiliyor. Öte yandan `/menu` ve `/` sayfaları 60 sn ISR ile
 * önbellekli — sepeti sunucu bileşeninde okumak bu sayfaları dinamik yapar ve
 * SEO için gereken önbelleği bozardı. Bu yüzden yalnızca özet ayrı çekiliyor.
 *
 * Yoklama yoktur: istemci yalnızca ilk yüklemede, sepet değiştiğinde ve sekme
 * odağa geldiğinde çağırır.
 */
export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const cart = await resolveCart();
    const minOrderTotal = cart.location?.min_order_total ?? 0;

    return NextResponse.json(
      {
        count: cart.itemCount,
        subtotal: cart.subtotal,
        min_order_total: minOrderTotal,
        remaining_to_minimum: Math.max(0, minOrderTotal - cart.subtotal),
        has_unavailable: cart.hasUnavailable,
        ordering_open: isOrderingOpen(cart.location),
      },
      { headers: { 'Cache-Control': 'no-store' } },
    );
  } catch {
    // Hata durumunda sıfır göndermiyoruz: "sepetiniz boş" demek, dolu sepeti
    // olan müşteriyi yanıltır. İstemci başarısız yanıtı yok sayıp son bilinen
    // özeti korur.
    return new NextResponse(null, { status: 503, headers: { 'Cache-Control': 'no-store' } });
  }
}
