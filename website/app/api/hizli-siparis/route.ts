import { NextResponse } from 'next/server';

import { fetchMe } from '@/lib/api/auth';
import { fetchOrders } from '@/lib/api/orders';
import { fetchPrimaryLocation } from '@/lib/api/catalog';
import { canOrderDay, fetchDailyMenu } from '@/lib/api/daily-menu';
import { businessToday } from '@/lib/business-date';
import { readToken } from '@/lib/session';

/**
 * Ana sayfadaki hızlı sipariş kutusunun verisi — W-10, B-19 ile genişletildi.
 *
 * NEDEN AYRI UÇ: ana sayfa ISR ile önbellekli ve öyle kalmalı (SEO). Oturumu
 * sunucu bileşeninde okumak sayfayı dinamik yapar ve her ziyaretçi için
 * yeniden çizdirirdi. `sepet-ozeti` ve `vitrin-durumu` uçları aynı sebeple
 * var; bu üçüncüsü.
 *
 * YANIT HİÇBİR KOŞULDA 401 DÖNMEZ. Giriş yapmamış ziyaretçi bu ucun normal
 * bir tüketicisi — ona hata dönmek, tarayıcı konsolunu her ana sayfa
 * ziyaretinde kırmızıya boyardı. Oturum yoksa `logged_in: false` döner.
 *
 * BUGÜNÜN MENÜSÜ DE BURADAN GELİYOR: kutunun "aynı siparişi tekrarla"
 * düğmesi ancak bugün menü varsa ve sipariş alınıyorsa iş görüyor. Menü
 * bilgisi ISR'lı sayfadan değil bu taze uçtan geldiği için kutu, kesim saati
 * geçer geçmez doğru şeyi söylüyor.
 */
export const dynamic = 'force-dynamic';

type TodaySummary = {
  date: string;
  title: string | null;
  has_menu: boolean;
  is_orderable: boolean;
  package_price: number | null;
};

/** Menü okunamazsa kutu menüsüz çalışmaya devam eder — `null` döner. */
async function readToday(): Promise<TodaySummary | null> {
  const date = businessToday();
  try {
    const location = await fetchPrimaryLocation('fresh');
    if (!location) return null;

    const menu = await fetchDailyMenu(location.id, date, 'fresh');

    return {
      date,
      title: menu.title ?? null,
      has_menu: menu.items.length > 0,
      // Gün kapısı VE anlık şalter birlikte: kutu "sipariş verilebilir mi"
      // sorusuna tek bir cevap istiyor.
      is_orderable: canOrderDay(location, menu),
      package_price: menu.package?.price ?? null,
    };
  } catch {
    return null;
  }
}

export async function GET() {
  const token = await readToken();

  if (!token) {
    return NextResponse.json(
      {
        logged_in: false,
        can_order: false,
        first_name: null,
        last_order: null,
        today: await readToday(),
      },
      { headers: { 'Cache-Control': 'no-store' } },
    );
  }

  try {
    /*
     * Üç istek paralel. Sıralı olsaydı kart, en yavaşların TOPLAMI kadar
     * sonra görünürdü; ana sayfanın üstünde duran bir kutu için bu fark
     * hissediliyor.
     */
    const [customer, orders, today] = await Promise.all([
      fetchMe(token),
      fetchOrders(token, 1, 1),
      readToday(),
    ]);

    const last = orders.data[0] ?? null;

    return NextResponse.json(
      {
        logged_in: true,
        can_order: customer.can_order ?? false,
        first_name: customer.first_name,
        today,
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
