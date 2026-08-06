import { istanbulClock } from '@/lib/timezone';
import type { DeliveryType, EtaWindow, Location, LocationEta } from '@/lib/api/types';

/**
 * Teslim süresi tahmininin metne dönüşü.
 *
 * Müşteri teslim saatini seçebiliyordu ama **ne kadar sürdüğünü bilmeden**
 * seçiyordu. Sunucu artık bir aralık veriyor; buradaki iş o aralığı
 * abartmadan ve eksiltmeden cümleye çevirmek.
 */

/**
 * `eta` sözleşmede zorunlu ama **çalışma zamanında yok sayılabilir olmalı.**
 *
 * Site ile platform ayrı ayrı yayınlanıyor: alanı henüz göndermeyen bir
 * sunucuya (ya da mock'a) bağlanan yeni bir site, tipin "zorunlu" demesine
 * güvenip `location.eta.delivery` yazsaydı sayfa komple çökerdi. Alanın
 * varlığı tipten değil, gelen gövdeden doğrulanıyor.
 */
function isEtaWindow(value: unknown): value is EtaWindow {
  if (typeof value !== 'object' || value === null) return false;
  const candidate = value as Record<string, unknown>;
  return (
    typeof candidate.min_minutes === 'number' &&
    typeof candidate.max_minutes === 'number' &&
    candidate.min_minutes > 0 &&
    candidate.max_minutes >= candidate.min_minutes &&
    (candidate.source === 'measured' || candidate.source === 'configured') &&
    typeof candidate.busy === 'boolean'
  );
}

/** Vitrinin iki tahmini de geçerliyse döner, aksi hâlde `null`. */
export function readLocationEta(location: Location | null | undefined): LocationEta | null {
  const raw: unknown = location?.eta;
  if (typeof raw !== 'object' || raw === null) return null;
  const candidate = raw as Record<string, unknown>;
  if (!isEtaWindow(candidate.delivery) || !isEtaWindow(candidate.pickup)) return null;
  return { delivery: candidate.delivery, pickup: candidate.pickup };
}

/** Tek bir teslim türünün tahmini. */
export function readEtaWindow(
  location: Location | null | undefined,
  deliveryType: DeliveryType,
): EtaWindow | null {
  return readLocationEta(location)?.[deliveryType] ?? null;
}

/** `60-85 dk` */
export function etaMinutesText(estimate: EtaWindow): string {
  return `${estimate.min_minutes}-${estimate.max_minutes} dk`;
}

/**
 * `13:15-13:40` — aralığın duvar saati karşılığı.
 *
 * "60-85 dakika" soyut; müşteri onu kafasında saate çevirmek zorunda kalıyor.
 * Somut saat, sipariş verip vermeme kararını hızlandırıyor.
 */
export function etaClockText(estimate: EtaWindow, fromMs: number): string {
  const start = istanbulClock(new Date(fromMs + estimate.min_minutes * 60_000));
  const end = istanbulClock(new Date(fromMs + estimate.max_minutes * 60_000));
  return `${start}-${end}`;
}

/** Aralığın bittiği an — geçmişte kalmış tahmini göstermemek için. */
export function etaEndsAtMs(estimate: EtaWindow, fromMs: number): number {
  return fromMs + estimate.max_minutes * 60_000;
}

/**
 * Aralığın cümlesi. Dil, tahminin **ne kadar sağlam olduğuna** göre değişir:
 *
 * - `measured`: geçmiş siparişlerin gerçekleşen süresi ölçülmüş. Olanı
 *   bildirdiğimiz için geçmiş zamanla ve daha kesin konuşuyoruz.
 * - `configured`: hiç ölçüm yok, panelde elle girilen süreden türetilmiş.
 *   Bunu "genelde şu kadar sürüyor" diye sunmak uydurma olurdu — ortada
 *   "genelde" diyecek veri yok. Bu yüzden açıkça "tahmin" deniyor.
 * - `busy`: aralık zaten uzatılmış geliyor. Yoğunlukta `measured` bile artık
 *   "olağan" değil; ölçüme dayandığını söylemek yanıltıcı olur. İkisi de
 *   nötr "şu an için" diline düşüyor. Yoğunluğun KENDİSİ burada anılmıyor —
 *   onu [KitchenBusyBanner] söylüyor, iki kez söylenmemeli.
 */
export function etaSentence(estimate: EtaWindow, deliveryType: DeliveryType): string {
  const range = etaMinutesText(estimate);
  const isPickup = deliveryType === 'pickup';

  if (estimate.busy) {
    return isPickup
      ? `Şu an için ${range} içinde hazır olacağını öngörüyoruz.`
      : `Şu an için ${range} içinde teslim edeceğimizi öngörüyoruz.`;
  }

  if (estimate.source === 'measured') {
    return isPickup
      ? `Son siparişlerimizin çoğu ${range} içinde hazır oldu.`
      : `Son siparişlerimizin çoğu ${range} içinde teslim edildi.`;
  }

  return isPickup ? `Tahmini hazırlanma süresi ${range}.` : `Tahmini teslim süresi ${range}.`;
}

/**
 * Sipariş takip ekranının ikinci satırı.
 *
 * Orada başlık zaten "Tahmini teslim: yaklaşık 13:15-13:40" diyor;
 * `configured` cümlesini olduğu gibi kullanınca "Tahmini teslim" iki satır
 * üst üste okunuyordu. Ölçüme dayanan ve yoğunluk hâlleri farklı bir şey
 * söylediği için onlar aynen kalıyor.
 */
export function etaTrackingDetail(estimate: EtaWindow, deliveryType: DeliveryType): string {
  if (estimate.busy || estimate.source === 'measured') {
    return etaSentence(estimate, deliveryType);
  }
  return `Siparişten sonraki ${etaMinutesText(estimate)} içinde.`;
}

/**
 * Cümlenin altına düşen küçük açıklama. Yoğunkenki `null`, bandın söylediğini
 * tekrar etmemek içindir.
 */
export function etaCaveat(estimate: EtaWindow): string | null {
  if (estimate.busy) return null;
  return estimate.source === 'measured'
    ? 'Son iki haftada gerçekleşen sürelerden hesaplandı.'
    : 'Ölçüme değil ortalama hazırlık sürelerimize dayanan bir tahmindir.';
}
