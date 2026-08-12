/**
 * Hizmet alanı — nereye teslimat yapıyoruz?
 *
 * Faz 1'de yalnızca **Konya / Selçuklu** ve **Konya / Karatay**. Müşteri il ve
 * ilçeyi serbest yazamaz; formda il sabit, ilçe listeden gelir.
 *
 * Bu dosya Dart tarafındaki `packages/core/lib/src/service_area.dart` ve sunucu
 * tarafındaki `ServiceArea.php` ile **aynı değerleri** taşır. Üçü birlikte
 * değişir; biri unutulursa istemcinin kabul ettiği adresi sunucu reddeder.
 */

export const SERVICE_AREA_CITY = 'Konya';

/** Teslimat yapılan ilçeler; sıra formdaki sıradır. */
export const SERVICE_AREA_DISTRICTS = ['Selçuklu', 'Karatay'] as const;

export type ServiceAreaDistrict = (typeof SERVICE_AREA_DISTRICTS)[number];

/**
 * Türkçe'ye duyarlı küçük harf.
 *
 * `toLowerCase()` dilden bağımsızdır ve `I` harfini `i`'ye düşürür; Türkçe'de
 * doğrusu `ı`'dır. Bugünkü iki ilçe adında fark yaratmıyor ama karşılaştırmayı
 * baştan doğru yazmak, ileride eklenecek bir ilçede sessiz bir eşleşmemeden
 * ucuz.
 */
function trLower(value: string): string {
  return value.replace(/I/g, 'ı').replace(/İ/g, 'i').toLowerCase();
}

export function coversDistrict(value: string | null | undefined): boolean {
  if (!value) return false;
  const needle = trLower(value.trim());
  return SERVICE_AREA_DISTRICTS.some((district) => trLower(district) === needle);
}

export function coversCity(value: string | null | undefined): boolean {
  if (!value) return false;
  return trLower(value.trim()) === trLower(SERVICE_AREA_CITY);
}

/**
 * Haritanın hapsedildiği kutu — `packages/core/lib/src/service_area.dart`
 * ile AYNI değerler (W-16).
 *
 * Üç yerde birden duruyor (Dart, PHP, buradaki TypeScript) ve birlikte
 * değişmek zorundalar; biri unutulursa istemcinin kabul ettiği iğneyi
 * sunucu reddeder.
 *
 * Kenarlar DAHİL: tam sınırdaki bir iğneyi reddetmek, kutuyu bir santimetre
 * içeriden çizmekle aynı şey olurdu.
 */
export const SERVICE_AREA_BOUNDS = {
  south: 37.8,
  north: 38.1,
  west: 32.35,
  east: 32.75,
} as const;

/** Harita ilk açıldığında ortalanacak nokta (Konya merkez). */
export const SERVICE_AREA_CENTER = { latitude: 37.8746, longitude: 32.4932 } as const;

/**
 * Kutunun tamamını gösteren en uzak seviye. Daha uzağa izin verilirse
 * "haritayı kutuya hapset" kısıtı sağlanamaz ve harita donmuş gibi davranır.
 */
export const SERVICE_AREA_MIN_ZOOM = 12.5;

/** Karo sağlayıcısının (OSM) verdiği en yakın seviye. */
export const SERVICE_AREA_MAX_ZOOM = 19;

/** Nokta hizmet alanı kutusunun içinde mi? */
export function containsPoint(latitude: number, longitude: number): boolean {
  return (
    latitude >= SERVICE_AREA_BOUNDS.south &&
    latitude <= SERVICE_AREA_BOUNDS.north &&
    longitude >= SERVICE_AREA_BOUNDS.west &&
    longitude <= SERVICE_AREA_BOUNDS.east
  );
}
