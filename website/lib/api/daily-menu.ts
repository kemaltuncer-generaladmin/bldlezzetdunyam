import 'server-only';

import { apiFetch, REVALIDATE_SECONDS, type RequestOptions } from './client';
import { fetchPrimaryLocation, type CatalogFreshness } from './catalog';
import { businessToday, addDays, type BusinessDate } from '@/lib/business-date';
import type {
  DailyMenu,
  DailyMenuResponse,
  Location,
  MenuCalendarDay,
  MenuCalendarResponse,
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
  const body = await apiFetch<DailyMenuResponse>(`/locations/${locationId}/daily-menu`, {
    query: date ? { date } : undefined,
    cache: cacheFor(freshness),
  });
  return body.data;
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
  const body = await apiFetch<MenuCalendarResponse>(`/locations/${locationId}/menu-calendar`, {
    query: { from, to },
    cache: cacheFor(freshness),
  });
  return body.data;
}

/** Sunucunun izin verdiği en uzak gün — takvim bundan ötesini çizmez. */
export function lastOrderableDate(
  location: Location | null,
  today: BusinessDate = businessToday(),
): BusinessDate {
  // Sözleşmedeki varsayılan 30; alan her yanıtta geliyor ama eski bir sunucu
  // sürümünde eksik kalırsa takvimin tek güne düşmemesi gerekiyor.
  const lookahead = location?.max_lookahead_days ?? 30;
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
 * İKİ AYRI KAPI birlikte değerlendiriliyor ve ikisi de sunucuda tekrar
 * uygulanıyor:
 *   * GÜN kapısı — menü yayında mı, gün kapalı mı, kesim saati geçti mi
 *     (`DailyMenu.is_orderable`).
 *   * ANLIK kapı — vitrin şu anda sipariş alıyor mu (`ordering_enabled` ve
 *     çalışma saati). Cuma menüsüne bugün 03:00'te sipariş verilemiyor:
 *     `LocationGate::assertAcceptsOrder` çalışma saatini SİPARİŞİN VERİLDİĞİ
 *     ana göre denetliyor.
 */
export function canOrderDay(location: Location | null, menu: DailyMenu | null): boolean {
  if (!location || !menu) return false;
  return menu.is_orderable && location.is_open && location.ordering_enabled;
}
