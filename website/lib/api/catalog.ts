import 'server-only';
import { cache } from 'react';

import { apiFetch, REVALIDATE_SECONDS, type RequestOptions } from './client';
import { freshRead } from './fresh-cache';
import type { Location, LocationListResponse } from './types';

export const CATALOG_TAG = 'catalog';

/**
 * Önbellek davranışı. Vitrin bilgisini SEO yüzeyleri (`/`) ISR ile okur;
 * sipariş kararının verildiği yerler (`/menu`, `/sepet`, `/odeme`, sipariş
 * oluşturma) **taze** veri ister — yönetici şalteri kapattığında 60 saniye
 * boyunca sipariş alınmaya devam etmemeli.
 *
 * `lib/api/daily-menu.ts` aynı ayrımı kullanıyor; tip oradan da içe
 * aktarılıyor ki iki dosyada iki farklı tazelik kavramı doğmasın.
 */
export type CatalogFreshness = 'isr' | 'fresh';

function cacheFor(freshness: CatalogFreshness): NonNullable<RequestOptions['cache']> {
  return freshness === 'fresh'
    ? { kind: 'no-store' }
    : { kind: 'revalidate', seconds: REVALIDATE_SECONDS, tags: [CATALOG_TAG] };
}

/**
 * VİTRİN OKUMA — genel ürün kataloğu ARTIK BURADA DEĞİL (B-19).
 *
 * `fetchMenu`/`fetchCatalog`/`flattenItems` kaldırıldı: satış günün menüsü
 * üzerinden yürüyor ve müşteri yüzeylerinde güne bağlı olmayan bir ürün
 * listesi kalmadı. `GET /locations/{id}/menu` ucu sözleşmede DURUYOR ve
 * yönetim paneli onu kullanmaya devam ediyor; kaldırılan yalnızca sitenin
 * o uca giden yolu.
 *
 * Vitrinler. Faz 1'de tek vitrin döner ama dizi biçimi korunur
 * (`docs/openapi.yaml` `/locations`).
 *
 * `'isr'` okumaları Next.js'in Data Cache'ine düşüyor; `'fresh'` okumaları
 * ise `lib/api/fresh-cache.ts`'teki iki saniyelik pencereye ve tek-uçuşa.
 * İkisi ayrı anahtar uzayında: aynı istek içinde bir yer taze, bir yer
 * önbellekli okuduğunda birbirlerinin cevabını görmemeliler.
 */
export async function fetchLocations(freshness: CatalogFreshness = 'isr'): Promise<Location[]> {
  const load = async (): Promise<Location[]> => {
    const body = await apiFetch<LocationListResponse>('/locations', {
      cache: cacheFor(freshness),
    });
    return body.data;
  };

  return freshness === 'fresh' ? freshRead('locations', load) : load();
}

/**
 * Sitenin çalıştığı vitrin. Liste boşsa sözleşme ihlalidir; `null` döneriz.
 *
 * `cache()` ile sarılı: aynı render içinde bu fonksiyon dört beş yerden
 * çağrılıyor (sayfa, `resolveCart`, `fetchDailyMenuSnapshot`) ve `'fresh'`
 * okumada Next.js'in kendi istek belleklemesi devre dışı kalıyor. Mikro-
 * önbellek zaten HTTP'yi eliyor; bu katman bir adım öncesini, JSON'un
 * yeniden dolaşılmasını da eliyor.
 */
export const fetchPrimaryLocation = cache(
  async (freshness: CatalogFreshness = 'isr'): Promise<Location | null> => {
    const locations = await fetchLocations(freshness);
    return locations[0] ?? null;
  },
);

/** Sipariş alınabilir mi? İki şalter de açık olmalı (`docs/06` §3). */
export function isOrderingOpen(location: Location | null): boolean {
  return Boolean(location?.is_open && location.ordering_enabled);
}
