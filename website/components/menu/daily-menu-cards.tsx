import { Leaf, UtensilsCrossed } from 'lucide-react';
import { AddToDayCart } from '@/components/menu/add-to-day-cart';
import { MenuPhotoGrid } from '@/components/menu/menu-photo-grid';
import { OrderCutoffCountdown } from '@/components/menu/order-cutoff-countdown';
import { Money } from '@/components/money';
import { ProductImage } from '@/components/product-image';
import { ProductOptions } from '@/components/product-options';
import { formatLongDate, type BusinessDate } from '@/lib/business-date';
import { stockLevel } from '@/lib/stock-policy';
import { cn } from '@/lib/utils';
import type { DailyMenu, DailyMenuPackage, MenuItem } from '@/lib/api/types';

/**
 * GÜNÜN MENÜSÜ kartları (B-19).
 *
 * İki satış biçimi var ve ikisi de aynı günden besleniyor:
 *   * PAKET — menünün bütün hâli, kendi fiyatıyla.
 *   * KALEM — paketin içindeki yemekler, tek tek.
 *
 * Paket kartı görsel olarak baskın; kalemler onun altında ikincil bir liste.
 * Sıra bilinçli: işletme paketi satmak istiyor ve paket fiyatı kalemlerin
 * toplamından ucuz. Kalemleri önce göstermek, müşteriyi pahalı olan yola
 * sokardı.
 *
 * ## STOK SAYILARI DIŞARIDAN GELİYOR
 *
 * Kartlar `remaining_portions` alanlarını kendileri okumuyor; kalan porsiyon
 * ile "kaç tane daha eklenebilir" sayısı sayfada hesaplanıp geçiliyor
 * (`app/menu/page.tsx`). İkincisi müşterinin sepetine bağlı ve sepet burada
 * yok; ilkini burada, ikincisini orada hesaplamak aynı aritmetiği iki
 * dosyaya bölerdi.
 */

/**
 * STOK ROZETİ — kalan porsiyonun ekrandaki hâli.
 *
 * Yalnız DARALDIĞINDA çiziliyor: kırk porsiyonu kalan bir güne "40 porsiyon
 * var" yazmak aciliyet değil gürültü üretir, üstelik her kartta tekrarlanır.
 * Bandın kendisi `lib/stock-policy.ts` içinde ve mobil uygulamayla ortak;
 * burada yapılan tek iş ona bir renk ve bir cümle vermek.
 *
 * Sayı SEPETTEN ARINDIRILMAZ: "son 3 porsiyon" bir satış bilgisidir, kişisel
 * bir durum değil — sepetine iki tane atmış müşteriye başka bir sayı
 * göstermek, iki müşterinin aynı ekranda farklı rakam okuması demekti.
 */
function StockBadge({ remaining }: { remaining: number | null }) {
  const level = stockLevel({ remaining });

  // `unlimited` (tavan konmamış) ile `plenty` (bol) sessiz kalır.
  if (remaining === null || level === 'plenty') return null;

  if (level === 'soldOut') {
    return <span className="bld-badge bg-danger-surface text-danger-foreground">Tükendi</span>;
  }

  return (
    <span className="bld-badge bg-warning-surface text-warning-foreground">
      Son {remaining} porsiyon
    </span>
  );
}

/** Alerjen rozeti — metin API'den geliyor, BÜYÜTÜLMÜYOR (İ/ı kırılır). */
function AllergenList({ allergens }: { allergens?: string[] }) {
  if (!allergens || allergens.length === 0) return null;

  return (
    <ul className="mt-2 flex flex-wrap gap-1.5">
      {allergens.map((allergen) => (
        <li
          key={allergen}
          className="bld-badge bg-warning-surface text-warning-foreground"
          title="Alerjen"
        >
          <Leaf aria-hidden="true" strokeWidth={1.75} className="size-3" />
          {allergen}
        </li>
      ))}
    </ul>
  );
}

export function DailyMenuPackageCard({
  menu,
  daily,
  serviceDate,
  advantageKurus,
  remainingPortions,
  maxAddable,
  serverNow,
  canOrder,
  disabledReason,
}: {
  menu: DailyMenu;
  daily: DailyMenuPackage;
  serviceDate: BusinessDate;
  /** `items_total − package.price`; avantaj yoksa `0` (`lib/api/daily-menu.ts`). */
  advantageKurus: number;
  /** Paketin o günkü efektif kalanı (gün ile paket tavanının darı); `null` sınırsız. */
  remainingPortions: number | null;
  /** Sepete daha kaç paket eklenebilir. */
  maxAddable: number;
  /** Sunucunun sayfayı çizdiği an — geri sayımın saat referansı. */
  serverNow: number;
  canOrder: boolean;
  disabledReason: string;
}) {
  const soldOut = !daily.is_available;
  const itemsTotal = typeof menu.items_total === 'number' ? menu.items_total : null;

  return (
    <article className="overflow-hidden rounded-md bg-card text-card-foreground shadow-raised dark:shadow-none dark:inset-ring dark:inset-ring-white/5">
      <div className="grid lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
        {/*
          KAPAK VARSA IZGARAYA TERCİH EDİLİR — sözleşmenin kuralı: `image_url`
          yöneticinin o güne elle yüklediği kapaktır, `image_urls` ise
          kapaksız günlerin boş kart görünmesini engellemek için var. Tek
          görselle çağrılan ızgara zaten tam kanama çiziyor, yani eski
          davranış aynen sürüyor.
        */}
        <div className="aspect-16/9 lg:aspect-auto lg:min-h-72">
          <MenuPhotoGrid
            imageUrls={menu.image_url ? [menu.image_url] : menu.image_urls}
            priority
            sizes="(max-width: 1024px) 100vw, 560px"
          />
        </div>

        <div className="p-5 sm:p-7">
          <p className="text-overline text-primary-text uppercase">Günün menüsü</p>
          <h2 className="mt-2 font-display text-h2 font-semibold text-heading">
            {menu.title ?? daily.name}
          </h2>
          <p className="mt-1 text-body-sm text-muted-foreground">{formatLongDate(serviceDate)}</p>

          {menu.description && <p className="mt-3 text-body-lg text-pretty">{menu.description}</p>}

          <h3 className="mt-5 text-label text-muted-foreground">Menüde neler var?</h3>
          <ul className="mt-2 space-y-1.5">
            {daily.components.map((component) => (
              <li key={component.menu_id} className="flex items-start gap-2 text-body">
                <UtensilsCrossed
                  aria-hidden="true"
                  strokeWidth={1.75}
                  className="mt-0.5 size-4 shrink-0 text-neutral-400"
                />
                <span>
                  {component.name}
                  {component.quantity > 1 && (
                    <span className="text-muted-foreground"> × {component.quantity}</span>
                  )}
                </span>
              </li>
            ))}
          </ul>

          <div className="mt-6 flex flex-wrap items-end gap-x-3 gap-y-2">
            {/*
              Üstü çizili kalem toplamı ÖNCE, paket fiyatı SONRA: göz önce
              eski değeri görüp sonra yenisine iniyor. `Money` bu sırayı
              kendi uyguluyor (`was` desteği).
            */}
            <Money
              kurus={daily.price}
              was={advantageKurus > 0 && itemsTotal !== null ? itemsTotal : undefined}
              size="xl"
            />

            {advantageKurus > 0 && (
              <p className="bld-badge bg-success-surface text-success-foreground">
                Paketle <Money kurus={advantageKurus} size="sm" className="mx-1" /> avantaj
              </p>
            )}
          </div>

          {/*
            KALAN PORSİYON ve KESİM SAATİ yan yana: ikisi de "acele etmeli
            miyim" sorusunu cevaplıyor ve müşteri kararını fiyatı gördükten
            hemen sonra veriyor. Boşken satır hiç çizilmiyor (`empty:hidden`),
            yoksa çoğu günde altı boş bir aralık kalırdı.
          */}
          <div className="mt-4 flex flex-wrap items-center gap-2 empty:hidden">
            <StockBadge remaining={remainingPortions} />
            {menu.cutoff_at && (
              <OrderCutoffCountdown cutoffAt={menu.cutoff_at} serverNow={serverNow} />
            )}
          </div>

          {soldOut && daily.sold_out_reason && (
            <p role="status" className="mt-3 text-body-sm text-danger-foreground">
              {daily.sold_out_reason}
            </p>
          )}

          <div className="mt-5">
            <AddToDayCart
              menuId={daily.menu_id}
              serviceDate={serviceDate}
              label="Menüyü sepete ekle"
              maxAddable={maxAddable}
              disabled={!canOrder || soldOut}
              disabledReason={soldOut ? 'Bugünlük tükendi' : disabledReason}
              showMessage
            />
          </div>
        </div>
      </div>
    </article>
  );
}

/**
 * Menünün tek bir kalemi.
 *
 * Ürün detay sayfasına BAĞLANMIYOR: satış artık günün menüsü üzerinden
 * yürüyor ve genel ürün kataloğu (liste + detay) müşteri yüzeylerinden
 * kaldırıldı. Kalemin bilmesi gereken her şey (ad, açıklama, alerjen,
 * fiyat) bu kartın içinde.
 */
export function DailyMenuItemCard({
  item,
  serviceDate,
  remainingPortions,
  maxAddable,
  canOrder,
  disabledReason,
}: {
  item: MenuItem;
  serviceDate: BusinessDate;
  /** Kalemin o günkü efektif kalanı (gün ile kalem tavanının darı). */
  remainingPortions: number | null;
  /** Sepete bu kalemden daha kaç tane eklenebilir. */
  maxAddable: number;
  canOrder: boolean;
  disabledReason: string;
}) {
  const soldOut = !item.is_available;
  const hasOptions = (item.options ?? []).length > 0;

  return (
    <li className="flex gap-4 rounded-md bg-card p-4 text-card-foreground shadow-card dark:shadow-none dark:inset-ring dark:inset-ring-white/5">
      <div className="relative size-20 shrink-0 overflow-hidden rounded-sm sm:size-24">
        <ProductImage
          src={item.image_url}
          alt=""
          sizes="96px"
          className={soldOut ? 'grayscale' : undefined}
        />
      </div>

      <div className="flex min-w-0 flex-1 flex-col">
        <div className="flex flex-wrap items-start justify-between gap-x-3 gap-y-1">
          <h3 className="text-title font-semibold">{item.name}</h3>
          <Money kurus={item.price} size="md" />
        </div>

        {item.description && (
          <p className="mt-1 text-body-sm text-muted-foreground">{item.description}</p>
        )}

        {/*
          Rozet alerjenlerin ÜSTÜNDE: kalan porsiyon satın alma kararını
          değiştiriyor, alerjen listesi ise zaten kararını vermiş müşteriyi
          ilgilendiriyor.
        */}
        <div className="mt-2 empty:hidden">
          <StockBadge remaining={remainingPortions} />
        </div>

        <AllergenList allergens={item.allergens} />

        {soldOut && (
          <p role="status" className="mt-2 text-body-sm text-danger-foreground">
            {item.sold_out_reason ?? 'Tükendi'}
          </p>
        )}

        <div className={cn('mt-3', hasOptions ? 'max-w-md' : 'max-w-56')}>
          <AddToDayCart
            menuId={item.id}
            serviceDate={serviceDate}
            label="Sepete ekle"
            maxAddable={maxAddable}
            size="sm"
            variant="outline"
            disabled={!canOrder || soldOut}
            disabledReason={soldOut ? 'Tükendi' : disabledReason}
          >
            {/*
              Seçenekler KARTIN İÇİNDE. Ürün detay sayfası kaldırıldığı için
              "seçenekleri gör" diye gidilecek bir yer kalmadı; zorunlu
              seçeneği olan bir kalem, seçimi burada sorulmazsa hiç
              satılamaz.
            */}
            {hasOptions && <ProductOptions item={item} />}
          </AddToDayCart>
        </div>
      </div>
    </li>
  );
}
