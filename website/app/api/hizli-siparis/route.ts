import { NextResponse } from 'next/server';

import { fetchMe } from '@/lib/api/auth';
import { fetchOrders } from '@/lib/api/orders';
import { readToken } from '@/lib/session';

/**
 * Ana sayfadaki hızlı sipariş kutusunun verisi — W-10.
 *
 * NEDEN AYRI UÇ: ana sayfa ISR ile önbellekli ve öyle kalmalı (SEO). Oturumu
 * sunucu bileşeninde okumak sayfayı dinamik yapar ve her ziyaretçi için
 * yeniden çizdirirdi. `sepet-ozeti` ve `vitrin-durumu` uçları aynı sebeple
 * var; bu üçüncüsü.
 *
 * YANIT HİÇBİR KOŞULDA 401 DÖNMEZ. Giriş yapmamış ziyaretçi bu ucun normal
 * bir tüketicisi — ona hata dönmek, tarayıcı konsolunu her ana sayfa
 * ziyaretinde kırmızıya boyardı. Oturum yoksa `logged_in: false` döner.
 */
export const dynamic = 'force-dynamic';

export async function GET() {
  const token = await readToken();

  if (!token) {
    return NextResponse.json(
      { logged_in: false, can_order: false, first_name: null, last_order: null },
      { headers: { 'Cache-Control': 'no-store' } },
    );
  }

  try {
    /*
     * İki istek paralel. Sıralı olsaydı kart, en yavaş ikisinin TOPLAMI
     * kadar sonra görünürdü; ana sayfanın üstünde duran bir kutu için bu
     * fark hissediliyor.
     */
    const [customer, orders] = await Promise.all([fetchMe(token), fetchOrders(token, 1, 1)]);

    const last = orders.data[0] ?? null;

    return NextResponse.json(
      {
        logged_in: true,
        can_order: customer.can_order ?? false,
        first_name: customer.first_name,
        last_order: last
          ? {
              id: last.id,
              order_number: last.order_number,
              total: last.total,
              created_at: last.created_at,
              /*
                Ürün adları BURADA YOK ve bilerek: liste ucu `OrderSummary`
                döndürüyor, satırları taşımıyor. Adları göstermek için her
                ana sayfa ziyaretinde ikinci bir detay isteği atmak
                gerekirdi — kart için "3 ürün · 240,00 ₺" yeterli bilgi.
              */
              item_count: last.item_count,
            }
          : null,
      },
      { headers: { 'Cache-Control': 'no-store' } },
    );
  } catch {
    /*
     * Token süresi dolmuş ya da API erişilemez. `logged_in: false` dönmek
     * yanlış olurdu: kullanıcı giriş yapmış durumda ve kartın "giriş yapın"
     * demesi kafa karıştırırdı. Kutu hiç çizilmiyor.
     */
    return new NextResponse(null, { status: 503, headers: { 'Cache-Control': 'no-store' } });
  }
}
