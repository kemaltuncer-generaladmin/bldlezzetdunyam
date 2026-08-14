import 'server-only';

import { apiFetch, REVALIDATE_SECONDS, type RequestOptions } from './client';
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
 */
export async function fetchLocations(freshness: CatalogFreshness = 'isr'): Promise<Location[]> {
  const body = await apiFetch<LocationListResponse>('/locations', {
    cache: cacheFor(freshness),
  });
  return body.data;
}

/** Sitenin çalıştığı vitrin. Liste boşsa sözleşme ihlalidir; `null` döneriz. */
export async function fetchPrimaryLocation(
  freshness: CatalogFreshness = 'isr',
): Promise<Location | null> {
  const locations = await fetchLocations(freshness);
  return locations[0] ?? null;
}

/** Sipariş alınabilir mi? İki şalter de açık olmalı (`docs/06` §3). */
export function isOrderingOpen(location: Location | null): boolean {
  return Boolean(location?.is_open && location.ordering_enabled);
}
