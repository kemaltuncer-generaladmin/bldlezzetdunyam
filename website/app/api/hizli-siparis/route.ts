import { NextResponse } from 'next/server';

import { fetchMe } from '@/lib/api/auth';
import { fetchOrders } from '@/lib/api/orders';
import { fetchPrimaryLocation } from '@/lib/api/catalog';
import { canOrderDay, fetchDailyMenu } from '@/lib/api/daily-menu';
import { dayStock } from '@/lib/api/daily-menu';
import { maxAddable } from '@/lib/stock-policy';
import { readCart } from '@/lib/cart';
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
  /**
   * Paketin sipariş kimliği — `DailyMenu.package.menu_id`.
   *
   * FİYAT TEK BAŞINA İŞE YARAMIYORDU: kutu "menü şu kadar" diyebiliyor ama
   * satamıyordu, çünkü sepete ekleme `menu_id` istiyor. Menü fiyatı girilmiş
   * olmasına rağmen müşterinin o fiyattan alabilmesi için `/menu` sayfasına
   * gidip paketi orada bulması gerekiyordu.
   */
  package_menu_id: number | null;
  /** Paketin adı — düğmede "Menüyü sepete ekle" yerine gerçek ad yazılabilsin. */
  package_name: string | null;
  /**
   * Bugün için sepete daha kaç paket eklenebilir (`lib/stock-policy.ts`).
   *
   * Sunucuda hesaplanıyor: müşterinin o güne bağlı sepetindeki adet ile
   * günün ve paketin tavanı birlikte gerekiyor ve ikisi de istemcide yok.
   * `0` ise paket bugünlük tükenmiştir.
   */
  package_max_addable: number;
};

/** Menü okunamazsa kutu menüsüz çalışmaya devam eder — `null` döner. */
async function readToday(): Promise<TodaySummary | null> {
  const date = businessToday();
  try {
    const location = await fetchPrimaryLocation('fresh');
    if (!location) return null;

    const menu = await fetchDailyMenu(location.id, date, 'fresh');
    const daily = menu.package ?? null;

    /*
     * TAVAN `/menu` SAYFASIYLA AYNI ARİTMETİKTEN ÇIKIYOR (`lib/stock-policy.ts`).
     * Sepet BAŞKA bir güne bağlıysa hiçbir şey düşmüyor: salı için dolu bir
     * sepet çarşambanın kontenjanını yemez.
     */
    const cart = await readCart();
    const lines = cart.serviceDate === date ? cart.lines : [];
    const inCartForDay = lines.reduce((total, line) => total + line.quantity, 0);
    const inCartForPackage = daily
      ? lines.reduce(
          (total, line) => (line.menuId === daily.menu_id ? total + line.quantity : total),
          0,
        )
      : 0;

    return {
      date,
      title: menu.title ?? null,
      has_menu: menu.items.length > 0,
      // Gün kapısı VE anlık şalter birlikte: kutu "sipariş verilebilir mi"
      // sorusuna tek bir cevap istiyor.
      is_orderable: canOrderDay(location, menu),
      package_price: daily?.price ?? null,
      package_menu_id: daily?.menu_id ?? null,
      package_name: daily?.name ?? null,
      package_max_addable:
        daily && daily.is_available
          ? maxAddable({
              dayRemaining: dayStock(menu),
              itemRemaining: daily.remaining_portions ?? null,
              alreadyInCartForDay: inCartForDay,
              alreadyInCartForItem: inCartForPackage,
            })
          : 0,
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
