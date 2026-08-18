import 'server-only';

import { apiFetch, REVALIDATE_SECONDS, type RequestOptions } from './client';
import { fetchPrimaryLocation, type CatalogFreshness } from './catalog';
import { freshRead } from './fresh-cache';
import { businessToday, addDays, type BusinessDate } from '@/lib/business-date';
import type {
  DailyMenu,
  DailyMenuResponse,
  Location,
  MenuCalendarDay,
  MenuCalendarResponse,
  MenuItem,
} from './types';

/**
 * GÜNÜN MENÜSÜ uçları (B-19).
 *
 * `lib/api/catalog.ts` ile aynı kalıp: `apiFetch`, `server-only`, açık
 * önbellek yönergesi. Ayrı dosya çünkü katalog "vitrinde ne var" sorusunun,
 * bu dosya "BUGÜN ne satılıyor" sorusunun cevabı — ikincisinin geçerlilik
 * süresi gün içinde bitiyor.
 *
 * ## Tazelik kuralı
 *
 * SİPARİŞ KARARI VEREN HER YOL `'fresh'` OKUR. Menü sayfası, sepet, ödeme ve
 * sipariş oluşturma bu gruba girer: yönetici menüyü yayından kaldırdığında ya
 * da kesim saati geçtiğinde altmış saniye boyunca sipariş alınmaya devam
 * edilemez. `'isr'` yalnızca karar vermeyen yerler içindir (takvim şeridi,
 * ana sayfadaki vitrin bandı) — orada bir dakikalık gecikme yalnızca "yarın
 * menü var mı" sorusunu etkiliyor.
 */
export const DAILY_MENU_TAG = 'daily-menu';

function cacheFor(freshness: CatalogFreshness): NonNullable<RequestOptions['cache']> {
  return freshness === 'fresh'
    ? { kind: 'no-store' }
    : { kind: 'revalidate', seconds: REVALIDATE_SECONDS, tags: [DAILY_MENU_TAG] };
}

/**
 * Bir günün menüsü.
 *
 * Menü olmayan gün de `200` döner (`id: null`, `items: []`,
 * `is_orderable: false`): boş bir gün hata değil, cevaptır.
 */
export async function fetchDailyMenu(
  locationId: number,
  date?: BusinessDate,
  freshness: CatalogFreshness = 'fresh',
): Promise<DailyMenu> {
  const load = async (): Promise<DailyMenu> => {
    const body = await apiFetch<DailyMenuResponse>(`/locations/${locationId}/daily-menu`, {
      query: date ? { date } : undefined,
      cache: cacheFor(freshness),
    });
    return body.data;
  };

  /*
   * Taze okuma iki saniyelik pencereye ve tek-uçuşa bağlanıyor
   * (`lib/api/fresh-cache.ts`). Anahtara GÜN de giriyor: sepet salıya bağlı
   * bir sepetin menüsünü okurken menü sayfası çarşambayı gösteriyor
   * olabilir ve ikisi aynı cevabı paylaşamaz.
   */
  return freshness === 'fresh'
    ? freshRead(`daily-menu:${locationId}:${date ?? 'today'}`, load)
    : load();
}

/**
 * Gün seçicinin takvimi.
 *
 * Sunucu YALNIZCA menüsü olan ya da kapalı olan günleri döner; aradaki günler
 * yanıtta yoktur ve "menü yok" anlamına gelir. Aralık en fazla 92 gün.
 */
export async function fetchMenuCalendar(
  locationId: number,
  from: BusinessDate,
  to: BusinessDate,
  freshness: CatalogFreshness = 'isr',
): Promise<MenuCalendarDay[]> {
  const load = async (): Promise<MenuCalendarDay[]> => {
    const body = await apiFetch<MenuCalendarResponse>(`/locations/${locationId}/menu-calendar`, {
      query: { from, to },
      cache: cacheFor(freshness),
    });
    return body.data;
  };

  return freshness === 'fresh'
    ? freshRead(`menu-calendar:${locationId}:${from}:${to}`, load)
    : load();
}

/** Sunucunun izin verdiği en uzak gün — takvim bundan ötesini çizmez. */
export function lastOrderableDate(
  location: Location | null,
  today: BusinessDate = businessToday(),
): BusinessDate {
  // Yedek değer 7 (günlük menü satış modeli). Alan her yanıtta geliyor ama
  // eksik kalırsa takvim, sunucunun reddedeceği günleri açık göstermemeli.
  // Şemadaki `default: 30` katalog dönemine ait tarihsel bir annotasyon;
  // ona düşmek takvimi üç haftadan fazla ileriye açardı.
  const lookahead = location?.max_lookahead_days ?? 7;
  // Takvim ucunun üst sınırı 92 gün; daha genişi `422` döner.
  return addDays(today, Math.min(Math.max(lookahead, 0), 92));
}

export type DailyMenuSnapshot = {
  location: Location | null;
  menu: DailyMenu | null;
  /** Gün seçicinin çizeceği aralık — bugünden azami ileri görüşe kadar. */
  calendar: MenuCalendarDay[];
  today: BusinessDate;
  /** Ekranda seçili gün. İstenen gün geçersizse bugüne düşer. */
  selectedDate: BusinessDate;
};

/**
 * Menü sayfasının tek okuma noktası: vitrin + seçili günün menüsü + takvim.
 *
 * Menü ve takvim vitrin kimliğine bağlı olduğu için sıralı; ikisi kendi
 * aralarında paralel. Takvim `'isr'` okunuyor (karar vermez, yalnızca hangi
 * günlerin tıklanabilir olduğunu söyler), menü ise her zaman taze.
 */
export async function fetchDailyMenuSnapshot(
  requestedDate?: BusinessDate | null,
  freshness: CatalogFreshness = 'fresh',
): Promise<DailyMenuSnapshot> {
  const today = businessToday();
  const location = await fetchPrimaryLocation(freshness);

  if (!location) {
    return {
      location: null,
      menu: null,
      calendar: [],
      today,
      selectedDate: requestedDate ?? today,
    };
  }

  const selectedDate = requestedDate ?? today;

  const [menu, calendar] = await Promise.all([
    fetchDailyMenu(location.id, selectedDate, freshness),
    fetchMenuCalendar(location.id, today, lastOrderableDate(location, today)).catch(() => {
      // Takvim düşerse sayfa yine açılmalı: o günün menüsü asıl içerik,
      // takvim gezinme yardımıdır. Şerit "menü yok" hâline döner.
      return [] as MenuCalendarDay[];
    }),
  ]);

  return { location, menu, calendar, today, selectedDate };
}

/**
 * Paket avantajı: kalemleri tek tek almakla paketi almak arasındaki fark.
 *
 * İKİ SUNUCU DEĞERİNİN FARKI, kalemlerin İSTEMCİDE TOPLANMASI DEĞİL.
 * `items_total` sunucuda hesaplanıyor (o güne girilmiş fiyat istisnaları
 * dâhil); burada `price` ile arasındaki farkı almak dışında para aritmetiği
 * yapılmıyor. Kalemleri toplasaydık, istisnalı bir günde ekrandaki avantaj
 * sunucunun bildiğinden farklı çıkardı.
 *
 * Paket kalemlerden pahalıysa (avantaj yok) `0` döner — "eksi avantaj"
 * göstermek yerine hiç göstermemek doğru.
 */
export function packageAdvantageKurus(menu: DailyMenu | null): number {
  const itemsTotal = menu?.items_total;
  const packagePrice = menu?.package?.price;

  if (typeof itemsTotal !== 'number' || typeof packagePrice !== 'number') return 0;

  return Math.max(0, Math.trunc(itemsTotal) - Math.trunc(packagePrice));
}

/**
 * Bu gün için sepete ekleme yapılabilir mi?
 *
 * ÜÇ AYRI KAPI birlikte değerlendiriliyor ve üçü de sunucuda tekrar
 * uygulanıyor:
 *   * GÜN kapısı — menü yayında mı, gün kapalı mı, kesim saati geçti mi
 *     (`DailyMenu.is_orderable`).
 *   * ANLIK kapı — vitrin şu anda sipariş alıyor mu (`ordering_enabled` ve
 *     çalışma saati). Cuma menüsüne bugün 03:00'te sipariş verilemiyor:
 *     `LocationGate::assertAcceptsOrder` çalışma saatini SİPARİŞİN VERİLDİĞİ
 *     ana göre denetliyor.
 *   * STOK kapısı — günün toplam tavanı açıkça `0` mı.
 */
export function canOrderDay(location: Location | null, menu: DailyMenu | null): boolean {
  if (!location || !menu) return false;

  /*
   * `remaining_portions === 0` SÖZLEŞMEDE TEK ANLAMLIDIR: tükendi. `null` ya
   * da eksik alan "tavan konmamış" demek ve kapıyı KAPATMAZ — ikisini
   * karıştıran istemci, tavanı hiç girilmemiş bir günü satıştan düşürür.
   *
   * Burada `cutoff_at` yorumlanmıyor: sözleşme, istemcinin o alandan kendi
   * "gün kapandı" kararını çıkarmasını açıkça yasaklıyor ve karar kapısı
   * `is_orderable`. Sıfır porsiyon istisna çünkü yorum gerektirmiyor;
   * sunucu günü bir an için hâlâ açık gösterirken ekranda "sepete ekle"
   * bırakmak, müşteriye sunucunun reddedeceği bir sipariş verdirmek olurdu.
   */
  if (menu.remaining_portions === 0) return false;

  return menu.is_orderable && location.is_open && location.ordering_enabled;
}

/**
 * Günün toplam kalan porsiyonu — `null` SINIRSIZ.
 *
 * İnce ama gerekli bir okuyucu: alan sözleşmede İSTEĞE BAĞLI, yani gelmeyen
 * bir yanıtta `undefined` olur. `undefined`'ı olduğu gibi aritmetiğe sokmak
 * `NaN` üretir; burada "tavan konmamış" anlamına gelen `null`'a indirgeniyor
 * ve `lib/stock-policy.ts` tek bir sınırsızlık işareti görüyor.
 */
export function dayStock(menu: DailyMenu | null | undefined): number | null {
  return menu?.remaining_portions ?? null;
}

/**
 * Bir kalemin O GÜN için efektif kalanı — gün tavanı ile kalem tavanının dar
 * olanı. `null` SINIRSIZ.
 *
 * STOK BANDI bu sayıyla çizilir: gün toplamı 2'ye düşmüşken kalemin kendi
 * tavanı 40 olsa bile müşteri en fazla 2 alabilir, rozet de "son 2 porsiyon"
 * demelidir. Bağlamanın normatif tarifi
 * `docs/contract/sales-rules.cases.json` → `case_input_binding`.
 *
 * `maxAddable` bu birleşimi KULLANMAZ: orada iki tavan ayrı ayrı, kendi
 * sepet adetleriyle düşülür (gün adedi gün tavanından, kalem adedi kalem
 * tavanından) ve `min()` ancak ondan sonra alınır.
 *
 * İkinci parametre yapısal: `DailyMenuPackage` de `remaining_portions`
 * taşıdığı için paket kartı aynı okuyucuyu kullanabiliyor.
 */
export function itemStock(
  menu: DailyMenu | null | undefined,
  item: Pick<MenuItem, 'remaining_portions'> | null | undefined,
): number | null {
  const day = dayStock(menu);
  const perItem = item?.remaining_portions ?? null;

  if (day === null) return perItem;
  if (perItem === null) return day;

  return Math.min(day, perItem);
}
