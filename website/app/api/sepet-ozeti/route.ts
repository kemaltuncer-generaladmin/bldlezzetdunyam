import { NextResponse } from 'next/server';

import { isOrderingOpen } from '@/lib/api/catalog';
import { clearCart, resolveCart } from '@/lib/cart';

/**
 * Sepetin anlık özeti — yapışkan sepet kutusu bunu okur.
 *
 * NEDEN AYRI UÇ: sepet `httpOnly` cookie'de tutuluyor (`lib/cart.ts`), yani
 * tarayıcı satırları okuyamaz; tutarı da yalnızca o günün canlı menüsüyle
 * hesaplanabiliyor. Öte yandan `/` sayfası ISR ile önbellekli — sepeti
 * sunucu bileşeninde okumak bu sayfayı dinamik yapar ve SEO için gereken
 * önbelleği bozardı. Bu yüzden yalnızca özet ayrı çekiliyor.
 *
 * Yoklama yoktur: istemci yalnızca ilk yüklemede, sepet değiştiğinde ve
 * sekme odağa geldiğinde çağırır.
 */
export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const cart = await resolveCart();
    const minOrderTotal = cart.location?.min_order_total ?? 0;

    /*
     * ESKİ ŞEMA ÇEREZİ BURADA TEMİZLENİYOR (v1 → v2, B-19).
     *
     * `resolveCart` onu okumuyor ama çerez yerinde duruyor ve yanındaki
     * SAYAÇ çerezi (`bld_cart_n`, `httpOnly` değil) başlıkta hâlâ eski
     * adedi gösteriyordu — sepet boş, rozet "3" diyor. Sunucu bileşenleri
     * çerez yazamaz; rota işleyicisi yazabilir ve bu uç zaten her sayfa
     * yüklemesinde çağrılıyor. Temizlik için doğru yer burası.
     */
    if (cart.legacyDiscarded) await clearCart();

    return NextResponse.json(
      {
        count: cart.itemCount,
        subtotal: cart.subtotal,
        min_order_total: minOrderTotal,
        remaining_to_minimum: Math.max(0, minOrderTotal - cart.subtotal),
        has_unavailable: cart.hasUnavailable,
        ordering_open: isOrderingOpen(cart.location),
        // Sepet TEK bir güne bağlı; kutu hangi gün olduğunu yazıyor.
        service_date: cart.serviceDate,
        day_orderable: cart.dayOrderable,
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
