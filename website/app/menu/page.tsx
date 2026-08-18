import type { Metadata } from 'next';
import Image from 'next/image';
import Link from 'next/link';
import { ArrowRight, UtensilsCrossed } from 'lucide-react';
import { CartSummaryBar, CartSummaryPanel } from '@/components/cart-summary';
import { ErrorState } from '@/components/error-state';
import { JsonLd } from '@/components/json-ld';
import { LocationFacts } from '@/components/location-facts';
import { StatePanel } from '@/components/state-panel';
import { Button } from '@/components/ui/button';
import { KitchenBusyBanner } from '@/components/kitchen-busy-banner';
import { OrderingClosedBanner } from '@/components/ordering-banner';
import { DayPicker, findCalendarDay, nextOrderableDay } from '@/components/menu/day-picker';
import { ServiceDaysBanner } from '@/components/menu/service-days-banner';
import { DailyMenuItemCard, DailyMenuPackageCard } from '@/components/menu/daily-menu-cards';
import { ApiError, SITE_URL } from '@/lib/api/client';
import {
  canOrderDay,
  dayStock,
  fetchDailyMenuSnapshot,
  itemStock,
  lastOrderableDate,
  packageAdvantageKurus,
  type DailyMenuSnapshot,
} from '@/lib/api/daily-menu';
import { isOrderingOpen } from '@/lib/api/catalog';
import {
  formatLongDate,
  isoWeekday,
  parseBusinessDate,
  relativeDayLabel,
} from '@/lib/business-date';
import { readCart } from '@/lib/cart';
import { schemaOrgPrice } from '@/lib/format';
import { dayUnavailableCopy } from '@/lib/labels';
import { PHOTO } from '@/lib/site-images';
import { maxAddable, stockLevel } from '@/lib/stock-policy';

/**
 * GÜNÜN MENÜSÜ — sitenin tek satış ekranı (B-19).
 *
 * ## Neden ISR yok?
 *
 * Bu sayfa artık iki sebeple istek başına çiziliyor:
 *   1. Seçili gün adreste (`?gun=`), yani içerik zaten isteğe bağlı.
 *   2. SİPARİŞ KARARI BURADA VERİLİYOR. Yönetici menüyü yayından
 *      kaldırdığında ya da kesim saati geçtiğinde altmış saniye boyunca
 *      "sepete ekle" düğmesi çalışmaya devam edemez.
 *
 * SEO kaybı yok: sayfa yine sunucuda tam içerikle üretiliyor, `metadata` ve
 * JSON-LD duruyor. Kaybedilen yalnızca önbellek isabeti.
 *
 * ## Katalog gitti
 *
 * Kategori gezgini (`MenuBrowser`), arama ve ürün detay bağlantıları
 * kaldırıldı: satılan şey artık bir katalog değil, O GÜNÜN menüsü. Ürün
 * kayıtları duruyor — menünün kalemleri onlar.
 */
export const dynamic = 'force-dynamic';

type SearchParams = { gun?: string | string[] };

function readDay(params: SearchParams): string | null {
  const raw = Array.isArray(params.gun) ? params.gun[0] : params.gun;
  return parseBusinessDate(raw);
}

export async function generateMetadata({
  searchParams,
}: {
  searchParams: Promise<SearchParams>;
}): Promise<Metadata> {
  const day = readDay(await searchParams);
  const title = day ? `${formatLongDate(day)} Menüsü` : 'Günün Menüsü';

  return {
    title,
    description:
      'Her gün yeni bir menü: paketin tamamını ya da içindeki yemekleri tek tek sipariş edin. Bugüne ve ileri günlere sipariş verebilirsiniz.',
    /*
     * Canonical HER GÜNDE `/menu`. Gün parametreli adresler aynı sayfanın
     * takvim durumlarıdır; her birini ayrı bir sayfa olarak dizine vermek
     * otuz kopya içerik üretirdi.
     */
    alternates: { canonical: '/menu' },
    openGraph: {
      title: `${title} | Benim Lezzet Dünyam`,
      description: 'Bugün mutfaktan ne çıktı? Menü ve fiyatlar.',
      url: '/menu',
      type: 'website',
    },
  };
}

/** O günün menüsü `Menu` + tek bir `MenuSection` olarak işaretleniyor. */
function menuJsonLd(snapshot: DailyMenuSnapshot): Record<string, unknown> {
  const { menu, selectedDate } = snapshot;

  return {
    '@context': 'https://schema.org',
    '@type': 'Menu',
    name: `${formatLongDate(selectedDate)} menüsü`,
    url: `${SITE_URL}/menu`,
    inLanguage: 'tr-TR',
    hasMenuSection: [
      {
        '@type': 'MenuSection',
        name: menu?.title ?? 'Günün menüsü',
        ...(menu?.description ? { description: menu.description } : {}),
        hasMenuItem: (menu?.items ?? []).map((item) => ({
          '@type': 'MenuItem',
          name: item.name,
          ...(item.description ? { description: item.description } : {}),
          offers: {
            '@type': 'Offer',
            price: schemaOrgPrice(item.price),
            priceCurrency: item.currency,
            /*
             * STOK DA İZLENİYOR, yalnız `is_available` değil. `is_available`
             * ürünün menüde durup durmadığını söylüyor; porsiyonu bitmiş bir
             * kalem yanıtta hâlâ "mevcut" görünebiliyor ve gün tavanı da ayrı
             * bir kapı. Arama sonucunda "stokta" yazan bir yemeği tıklayıp
             * tükenmiş bulmak, arama motorunun da müşterinin de güvenini
             * kıran türden bir yanlış.
             */
            availability:
              item.is_available && stockLevel({ remaining: itemStock(menu, item) }) !== 'soldOut'
                ? 'https://schema.org/InStock'
                : 'https://schema.org/OutOfStock',
            // Menü o güne ait: teklifin geçerlilik günü de o gün.
            availabilityStarts: selectedDate,
            availabilityEnds: selectedDate,
          },
        })),
      },
    ],
  };
}

export default async function MenuPage({ searchParams }: { searchParams: Promise<SearchParams> }) {
  const requestedDay = readDay(await searchParams);

  let snapshot: DailyMenuSnapshot;
  try {
    snapshot = await fetchDailyMenuSnapshot(requestedDay);
  } catch (error) {
    /*
     * SEBEP AYRILIYOR. Eskiden her hata aynı cümleye düşüyordu ("Günün menüsü
     * yüklenemedi") ve müşteri de destek de ne olduğunu bilmiyordu — sunucu mu
     * kapalı, menü mi girilmemiş, ağ mı koptu. Üstelik en sık sebep geçici bir
     * ağ hıçkırığıydı ve o durumda söylenecek doğru şey "tekrar deneyin".
     *
     * Geçici hatalar artık `apiFetch` içinde iki kez yeniden deneniyor; buraya
     * düşen bir istek gerçekten cevap alamamış demektir.
     */
    const offline = error instanceof ApiError && error.code === 'NETWORK';

    return (
      <div className="mx-auto max-w-content px-4 py-16">
        <ErrorState
          title={offline ? 'Sunucuya ulaşılamadı' : 'Menü yüklenemedi'}
          message={
            offline
              ? 'Menü sunucusuna şu anda ulaşamıyoruz. Bağlantınızı kontrol edip tekrar deneyin; sorun bizdeyse kısa sürede düzelir.'
              : 'Günün menüsü yüklenemedi, tekrar deneyin.'
          }
          retryHref={requestedDay ? `/menu?gun=${requestedDay}` : '/menu'}
        />
      </div>
    );
  }

  const { location, menu, calendar, today, selectedDate } = snapshot;

  if (!location || !menu) {
    return (
      <div className="mx-auto max-w-content px-4 py-16">
        <ErrorState
          title="Menü yüklenemedi"
          message="Vitrin bilgisine ulaşılamadı. Kısa süre sonra tekrar deneyin."
          retryHref="/menu"
        />
      </div>
    );
  }

  const orderingOpen = isOrderingOpen(location);
  const canOrder = canOrderDay(location, menu);
  const calendarDay = findCalendarDay(calendar, selectedDate);
  const advantage = packageAdvantageKurus(menu);
  const nextDay = nextOrderableDay(calendar, selectedDate);

  /*
   * GERİ SAYIMIN SAAT REFERANSI. Cihaz saatleri yalan söyler; sayaç kendi
   * saatiyle sunucununki arasındaki farkı ölçüp sapma büyükse hiç
   * görünmüyor (`components/menu/order-cutoff-countdown.tsx`). Sayfa zaten
   * istek başına çiziliyor, yani bu değer her yanıtta tazedir.
   */
  const serverNow = Date.now();

  /*
   * SEPETTEKİ ADET, TAVANIN İKİNCİ YARISI.
   *
   * "Kaç tane daha eklenebilir" sorusu yalnız kalan porsiyonla cevaplanamaz:
   * müşterinin o gün için sepetine koyduğu adet de tavandan düşer. Sepet
   * BAŞKA bir güne bağlıysa hiçbir şey düşmüyor — salı için dolu bir sepet
   * çarşambanın kontenjanını yemez.
   */
  const cart = await readCart();
  const cartLines = cart.serviceDate === selectedDate ? cart.lines : [];
  const inCartForDay = cartLines.reduce((total, line) => total + line.quantity, 0);

  /** Aynı ürünün farklı seçenekli satırları tek stok yiyor; toplanıyorlar. */
  const inCartForMenuId = (menuId: number) =>
    cartLines.reduce((total, line) => (line.menuId === menuId ? total + line.quantity : total), 0);

  const dayRemaining = dayStock(menu);

  const addableFor = (menuId: number, itemRemaining: number | null) =>
    maxAddable({
      dayRemaining,
      itemRemaining,
      alreadyInCartForDay: inCartForDay,
      alreadyInCartForItem: inCartForMenuId(menuId),
    });

  /*
   * DÜĞMENİN KAPALI OLMA SEBEBİ. Marka kılavuzu: "Devre dışı buton HER ZAMAN
   * bir sebep metniyle birlikte." İki ayrı kapı var ve müşteriye söylenecek
   * şey farklı: gün kapalıysa başka gün seçmeli, şalter kapalıysa beklemeli.
   */
  const disabledReason = !orderingOpen
    ? 'Sipariş alımı kapalı'
    : !menu.is_orderable
      ? 'Bu güne sipariş alınmıyor'
      : 'Şu anda eklenemiyor';

  const unavailable = dayUnavailableCopy(
    menu.unavailable_reason,
    selectedDate,
    calendarDay?.note ?? null,
  );

  return (
    <>
      <JsonLd data={menuJsonLd(snapshot)} />

      {/*
        Sipariş başlığı kurumsal sayfalarla aynı dili konuşuyor: fotoğraflı
        koyu bant. Vitrin bilgileri (asgari sepet, teslimat ücreti, tahmini
        süre) bandın içinde — sipariş kararını etkileyen sayılar menüye
        inmeden görünmeli.
      */}
      <div className="relative isolate border-b bg-neutral-950 text-neutral-50">
        <Image
          alt={PHOTO.menuVitrin.alt}
          src={PHOTO.menuVitrin.src}
          fill
          priority
          sizes="100vw"
          className="-z-10 object-cover"
        />
        <div
          aria-hidden="true"
          className="absolute inset-0 -z-10 bg-linear-to-r from-neutral-950/90 via-neutral-950/80 to-neutral-950/50"
        />

        <div className="mx-auto max-w-content px-4 py-10 sm:px-6 sm:py-14">
          <p className="text-overline text-brand-300 uppercase">
            {relativeDayLabel(selectedDate, today)}
          </p>
          <h1 className="mt-2 font-display text-h1 font-semibold tracking-tight sm:text-display">
            Günün menüsü
          </h1>
          <p className="mt-4 max-w-2xl text-body-lg text-neutral-50/80">
            Her gün tek bir menü çıkarıyoruz. Menünün tamamını paket fiyatıyla ya da içindeki
            yemekleri tek tek alabilirsiniz. Bugüne ve ileri günlere sipariş verebilirsiniz.
          </p>

          <LocationFacts location={location} className="mt-6" />
        </div>
      </div>

      {/* Alt sepet çubuğu içeriği kapatmasın diye mobilde alttan boşluk. */}
      <div className="mx-auto max-w-content px-4 pt-6 pb-28 sm:pt-8 lg:pb-16">
        <div className="space-y-3 empty:hidden">
          {!orderingOpen && <OrderingClosedBanner location={location} />}
          <ServiceDaysBanner location={location} today={isoWeekday(today)} />
          <KitchenBusyBanner />
        </div>

        <div className="mt-4 grid gap-8 lg:grid-cols-[minmax(0,1fr)_18rem]">
          <div className="min-w-0 space-y-8">
            <DayPicker
              calendar={calendar}
              today={today}
              selectedDate={selectedDate}
              lastDate={lastOrderableDate(location, today)}
              /*
               * Hafta sonu Cmt/Paz olarak KODA GÖMÜLMÜYOR. Servis günleri
               * sunucudan geliyor; işletme cumartesi de yemek çıkarmaya
               * başladığında değişecek tek şey bu yanıt.
               */
              serviceWeekdays={location.service_weekdays}
            />

            {!menu.is_orderable && (
              <StatePanel
                tone={menu.closed ? 'error' : 'offline'}
                role={menu.closed ? 'alert' : 'status'}
                icon={<UtensilsCrossed aria-hidden="true" strokeWidth={1.75} />}
                title={unavailable.title}
                message={unavailable.message}
                action={
                  nextDay ? (
                    <Button asChild variant="outline">
                      <Link href={`/menu?gun=${nextDay.date}`}>
                        {formatLongDate(nextDay.date)} menüsüne bak
                        <ArrowRight strokeWidth={1.75} aria-hidden="true" />
                      </Link>
                    </Button>
                  ) : undefined
                }
              />
            )}

            {menu.package && (
              <DailyMenuPackageCard
                menu={menu}
                daily={menu.package}
                serviceDate={selectedDate}
                advantageKurus={advantage}
                remainingPortions={itemStock(menu, menu.package)}
                maxAddable={addableFor(
                  menu.package.menu_id,
                  menu.package.remaining_portions ?? null,
                )}
                serverNow={serverNow}
                canOrder={canOrder}
                disabledReason={disabledReason}
              />
            )}

            {menu.items.length > 0 && (
              <section aria-labelledby="kalemler">
                <h2 id="kalemler" className="font-display text-h3 font-semibold text-heading">
                  {menu.package ? 'Ayrı ayrı da alabilirsiniz' : 'Bu günün yemekleri'}
                </h2>
                <p className="mt-1 text-body-sm text-muted-foreground">
                  {menu.package
                    ? 'Menünün tamamını istemiyorsanız içindeki yemekleri tek tek sipariş edebilirsiniz.'
                    : 'Bu gün paket satışı yok; yemekleri tek tek sipariş edebilirsiniz.'}
                </p>

                <ul className="mt-4 space-y-3">
                  {menu.items.map((item) => (
                    <DailyMenuItemCard
                      key={item.id}
                      item={item}
                      serviceDate={selectedDate}
                      remainingPortions={itemStock(menu, item)}
                      maxAddable={addableFor(item.id, item.remaining_portions ?? null)}
                      canOrder={canOrder}
                      disabledReason={disabledReason}
                    />
                  ))}
                </ul>
              </section>
            )}
          </div>

          <CartSummaryPanel />
        </div>
      </div>

      <CartSummaryBar />
    </>
  );
}
