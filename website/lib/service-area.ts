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
