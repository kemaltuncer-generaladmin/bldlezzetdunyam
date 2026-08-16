import Link from 'next/link';
import { ArrowRight, UtensilsCrossed } from 'lucide-react';
import { AddToDayCart } from '@/components/menu/add-to-day-cart';
import { Money } from '@/components/money';
import { ProductImage } from '@/components/product-image';
import { Section, SectionHeading } from '@/components/site/section';
import { Button } from '@/components/ui/button';
import { canOrderDay, dayStock, fetchDailyMenu, packageAdvantageKurus } from '@/lib/api/daily-menu';
import { fetchPrimaryLocation } from '@/lib/api/catalog';
import { businessToday, formatLongDate } from '@/lib/business-date';
import { maxAddable } from '@/lib/stock-policy';
import type { DailyMenu, Location } from '@/lib/api/types';

/**
 * Ana sayfadaki "bugün mutfakta" bandı — **bugünün menüsü** (B-19).
 *
 * ## Neden ayrı bileşen?
 *
 * Ana sayfanın geri kalanı kurumsal içerikten besleniyor ve sipariş API'si
 * kapalıyken de açılmak zorunda. Bu bölüm ise gerçek menüyü gösteriyor, yani
 * o API'ye bağımlı. İkisini aynı dosyada tutmak, tek bir 500 yüzünden
 * vitrinin tamamının hata ekranına düşmesi demekti. Hata burada YUTULUYOR:
 * menü alınamazsa bölüm hiç basılmıyor.
 *
 * ## Neden `'isr'` okuyor, `'fresh'` değil?
 *
 * Ana sayfa SEO yüzeyi ve önbellekli kalmalı; burada `'fresh'` okumak
 * sayfanın tamamını her ziyaretçi için yeniden çizdirirdi. Bir dakikalık
 * pencere yalnızca GÖSTERİMİ etkiliyor: "sepete ekle"ye basıldığında sunucu
 * eylemi menüyü taze okuyup kararı yeniden veriyor
 * (`app/actions/cart.ts`). Yani ekranda eskimiş bir menü olabilir, ama
 * eskimiş bir menüden sipariş alınamaz.
 *
 * ## Katalog gitti
 *
 * Eskiden altı ürün kartı çiziliyor ve her biri ürün detay sayfasına
 * bağlanıyordu. Ürün listeleme ve detay sayfaları kaldırıldı; bugünün menüsü
 * TEK bir teklif ve bandın işi onu göstermek.
 */
export async function TodaysMenu() {
  const today = businessToday();

  let location: Location | null;
  let menu: DailyMenu;
  try {
    location = await fetchPrimaryLocation('isr');
    if (!location) return null;
    menu = await fetchDailyMenu(location.id, today, 'isr');
  } catch {
    return null;
  }

  // Menüsü olmayan gün: bant hiç çizilmiyor. "Bugün menü yok" demek ana
  // sayfanın ortasında negatif bir mesaj olurdu; ziyaretçi takvime
  // gidebilir.
  if (menu.items.length === 0) return null;

  const daily = menu.package ?? null;
  const advantage = packageAdvantageKurus(menu);
  const canOrder = canOrderDay(location, menu);

  return (
    <Section aria-labelledby="bugun-baslik">
      <div className="flex flex-wrap items-end justify-between gap-6">
        <SectionHeading
          id="bugun-baslik"
          eyebrow="Bugün mutfakta"
          title={menu.title ?? 'Bugünün menüsü'}
          description={menu.description ?? `${formatLongDate(today)} için hazırladıklarımız.`}
          className="!mb-0"
        />

        <Button asChild variant="outline" size="lg" className="hidden sm:inline-flex">
          <Link href="/menu">
            Takvim ve diğer günler
            <ArrowRight strokeWidth={1.75} aria-hidden="true" />
          </Link>
        </Button>
      </div>

      <div className="mt-10 grid gap-6 lg:grid-cols-[minmax(0,7fr)_minmax(0,5fr)]">
        <div className="overflow-hidden rounded-md bg-card text-card-foreground shadow-card dark:shadow-none dark:inset-ring dark:inset-ring-white/5">
          <div className="relative aspect-3/2">
            <ProductImage src={menu.image_url} alt="" sizes="(max-width: 1024px) 100vw, 640px" />
          </div>

          <ul className="grid gap-2 p-5 sm:grid-cols-2">
            {menu.items.map((item) => (
              <li key={item.id} className="flex items-start justify-between gap-3 text-body">
                <span className="flex items-start gap-2">
                  <UtensilsCrossed
                    aria-hidden="true"
                    strokeWidth={1.75}
                    className="mt-0.5 size-4 shrink-0 text-neutral-400"
                  />
                  {item.name}
                </span>
                <Money kurus={item.price} size="sm" tone="muted" />
              </li>
            ))}
          </ul>
        </div>

        <div className="flex h-fit flex-col rounded-md bg-surface-warm p-5 text-surface-warm-foreground sm:p-6">
          {daily ? (
            <>
              <h3 className="font-display text-h3 font-semibold text-heading">{daily.name}</h3>
              <p className="mt-1 text-body-sm text-muted-foreground">
                Menünün tamamı tek fiyatla. İçindekileri tek tek de alabilirsiniz.
              </p>

              <div className="mt-4 flex flex-wrap items-end gap-3">
                <Money
                  kurus={daily.price}
                  was={
                    advantage > 0 && typeof menu.items_total === 'number'
                      ? menu.items_total
                      : undefined
                  }
                  size="lg"
                />
                {advantage > 0 && (
                  <p className="bld-badge bg-success-surface text-success-foreground">
                    Paketle <Money kurus={advantage} size="sm" className="mx-1" /> avantaj
                  </p>
                )}
              </div>

              <div className="mt-5">
                <AddToDayCart
                  menuId={daily.menu_id}
                  serviceDate={today}
                  label="Menüyü sepete ekle"
                  /*
                   * TAVAN SEPETSİZ hesaplanıyor: sepeti okumak çerez okumak
                   * demek ve ana sayfa ISR'de kalmak zorunda (SEO). Sonuç
                   * "günde kaç porsiyon kaldı" sorusunun cevabı; müşterinin
                   * sepetindeki adet burada düşülmüyor. Fark güvenli yönde
                   * değil ama zararsız: sunucu eylemi menüyü ve sepeti taze
                   * okuyup adedi yine kırpıyor (`app/actions/cart.ts`).
                   */
                  maxAddable={maxAddable({
                    dayRemaining: dayStock(menu),
                    itemRemaining: daily.remaining_portions ?? null,
                    alreadyInCartForDay: 0,
                    alreadyInCartForItem: 0,
                  })}
                  disabled={!canOrder || !daily.is_available}
                  disabledReason={
                    !daily.is_available
                      ? 'Bugünlük tükendi'
                      : menu.is_orderable
                        ? 'Sipariş alımı kapalı'
                        : 'Bugüne sipariş alınmıyor'
                  }
                  showMessage
                />
              </div>
            </>
          ) : (
            <>
              <h3 className="font-display text-h3 font-semibold text-heading">
                Bugün tek tek satıyoruz
              </h3>
              <p className="mt-1 text-body-sm text-muted-foreground">
                Bu gün için paket fiyatı girilmedi; yemekleri menü sayfasından tek tek sepete
                ekleyebilirsiniz.
              </p>
            </>
          )}

          <Button asChild variant="secondary" className="mt-4 w-full">
            <Link href="/menu">Günün menüsünü aç</Link>
          </Button>
        </div>
      </div>

      <div className="mt-10 sm:hidden">
        <Button asChild variant="outline" size="lg" className="w-full">
          <Link href="/menu">
            Takvim ve diğer günler
            <ArrowRight strokeWidth={1.75} aria-hidden="true" />
          </Link>
        </Button>
      </div>
    </Section>
  );
}
