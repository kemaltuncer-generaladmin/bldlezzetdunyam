import 'server-only';

import { apiFetch, REVALIDATE_SECONDS, type RequestOptions } from './client';
import type {
  Location,
  LocationListResponse,
  MenuCategory,
  MenuItem,
  MenuResponse,
} from './types';

export const CATALOG_TAG = 'catalog';

/**
 * Önbellek davranışı. Katalog sayfaları (`/`, `/menu`, `/urun/[slug]`) ISR
 * kullanır; sipariş kararının verildiği yerler (`/sepet`, `/odeme`, sipariş
 * oluşturma) **taze** veri ister — yönetici şalteri kapattığında 60 saniye
 * boyunca sipariş alınmaya devam etmemeli.
 */
export type CatalogFreshness = 'isr' | 'fresh';

function cacheFor(freshness: CatalogFreshness): NonNullable<RequestOptions['cache']> {
  return freshness === 'fresh'
    ? { kind: 'no-store' }
    : { kind: 'revalidate', seconds: REVALIDATE_SECONDS, tags: [CATALOG_TAG] };
}

/**
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

/** Vitrinin menüsü. `is_available: false` ürünler listede **kalır**. */
export async function fetchMenu(
  locationId: number,
  freshness: CatalogFreshness = 'isr',
): Promise<MenuCategory[]> {
  const body = await apiFetch<MenuResponse>(`/locations/${locationId}/menu`, {
    cache: cacheFor(freshness),
  });
  return [...body.data].sort((a, b) => a.sort - b.sort);
}

export type CatalogSnapshot = {
  location: Location | null;
  categories: MenuCategory[];
};

/** Vitrin + menü tek çağrıda; sayfaların çoğu ikisine birden ihtiyaç duyar. */
export async function fetchCatalog(
  freshness: CatalogFreshness = 'isr',
): Promise<CatalogSnapshot> {
  const location = await fetchPrimaryLocation(freshness);
  if (!location) return { location: null, categories: [] };
  const categories = await fetchMenu(location.id, freshness);
  return { location, categories };
}

/** Menüdeki tüm ürünler, kategori sırasıyla düzleştirilmiş. */
export function flattenItems(categories: MenuCategory[]): MenuItem[] {
  return categories.flatMap((category) => category.items ?? []);
}

/** Ürünü kimliğiyle bulur — `/urun/[slug]` çözümlemesi bunu kullanır. */
export function findItemById(categories: MenuCategory[], menuId: number): MenuItem | null {
  return flattenItems(categories).find((item) => item.id === menuId) ?? null;
}

/** Bir ürünün ait olduğu kategori adı (ekmek kırıntısı ve JSON-LD için). */
export function findCategoryOf(categories: MenuCategory[], menuId: number): MenuCategory | null {
  return categories.find((c) => (c.items ?? []).some((item) => item.id === menuId)) ?? null;
}

/** Sipariş alınabilir mi? İki şalter de açık olmalı (`docs/06` §3). */
export function isOrderingOpen(location: Location | null): boolean {
  return Boolean(location?.is_open && location.ordering_enabled);
}
