import { TIME_ZONE } from '@/i18n/request';

/**
 * İŞLETME GÜNÜ — `'YYYY-AA-GG'` metni.
 *
 * ## Neden `Date` değil de metin?
 *
 * Servis günü bir AN değil, bir TAKVİM GÜNÜ. `new Date('2026-08-20')` UTC
 * gece yarısını üretiyor; İstanbul'da (+03) bu 03:00 demek ve cihazı UTC-5'te
 * olan bir kullanıcıda `toLocaleDateString` bunu **19 Ağustos** diye yazıyor.
 * Sunucu (`orders.bld_service_date`) günü metin olarak tutuyor; istemci de
 * metin taşırsa aradaki dönüşüm hiç olmuyor, kayma da olmuyor.
 *
 * Biçimlendirme için gün UTC gece yarısına açılır ve `Intl`'e `timeZone: 'UTC'`
 * verilir — yani gün numarası hangi cihazda olursak olalım aynı kalır.
 *
 * Flutter tarafındaki karşılığı `packages/core/lib/src/business_date.dart`;
 * iki yüzey aynı kuralları uyguluyor.
 */

/** `'YYYY-AA-GG'` — sözleşmedeki `format: date` alanlarının biçimi. */
export type BusinessDate = string;

const PATTERN = /^(\d{4})-(\d{2})-(\d{2})$/;

/** Takvim gününü UTC gece yarısına açar; biçimlendirme buradan geçer. */
function toUtcInstant(date: BusinessDate): Date | null {
  const match = PATTERN.exec(date);
  if (!match) return null;

  const [, year, month, day] = match;
  const instant = new Date(Date.UTC(Number(year), Number(month) - 1, Number(day)));

  // `2026-02-31` desene uyuyor ama gün yok: JS onu 3 Mart'a taşır. Geri
  // yazdırıp karşılaştırmak bu sessiz kaymayı yakalar.
  return instant.toISOString().slice(0, 10) === date ? instant : null;
}

export function isBusinessDate(value: unknown): value is BusinessDate {
  return typeof value === 'string' && toUtcInstant(value) !== null;
}

/** Geçersiz girdide `null` — çağıran kendi yedeğine düşer. */
export function parseBusinessDate(value: unknown): BusinessDate | null {
  return isBusinessDate(value) ? value : null;
}

const isoFormatter = new Intl.DateTimeFormat('sv-SE', {
  timeZone: TIME_ZONE,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});

/**
 * İşletme saatindeki bugün.
 *
 * Cihazın saat dilimi DEĞİL: gece 23:30'da Berlin'den bakan müşteri için
 * İstanbul'da yarın olmuş olabilir ve mutfağın günü bağlayıcı olandır.
 */
export function businessToday(): BusinessDate {
  // sv-SE zaten `2026-08-20` biçimi veriyor; elle birleştirme gerekmiyor.
  return isoFormatter.format(new Date());
}

export function addDays(date: BusinessDate, days: number): BusinessDate {
  const instant = toUtcInstant(date);
  if (!instant) return date;
  instant.setUTCDate(instant.getUTCDate() + days);
  return instant.toISOString().slice(0, 10);
}

/** `to - from` gün farkı; ikisi de takvim günü olduğu için tam sayı. */
export function daysBetween(from: BusinessDate, to: BusinessDate): number {
  const a = toUtcInstant(from);
  const b = toUtcInstant(to);
  if (!a || !b) return 0;
  return Math.round((b.getTime() - a.getTime()) / 86_400_000);
}

export function compareBusinessDates(a: BusinessDate, b: BusinessDate): number {
  // `YYYY-AA-GG` sözlük sırası takvim sırasıyla aynı; ayrıştırmaya gerek yok.
  return a < b ? -1 : a > b ? 1 : 0;
}

/** Aralıktaki günler, `from` ve `to` dâhil. */
export function eachDay(from: BusinessDate, to: BusinessDate): BusinessDate[] {
  const total = daysBetween(from, to);
  if (total < 0) return [];
  return Array.from({ length: total + 1 }, (_, index) => addDays(from, index));
}

/** Haftanın günü: 1 Pazartesi … 7 Pazar (ISO). */
export function isoWeekday(date: BusinessDate): number {
  const instant = toUtcInstant(date);
  if (!instant) return 1;
  const day = instant.getUTCDay();
  return day === 0 ? 7 : day;
}

/** Ayın ilk günü — takvim ızgarası bunun üstüne kurulur. */
export function startOfMonth(date: BusinessDate): BusinessDate {
  return `${date.slice(0, 7)}-01`;
}

export function monthKey(date: BusinessDate): string {
  return date.slice(0, 7);
}

/*
 * Biçimlendiriciler modül düzeyinde: `Intl.DateTimeFormat` kurulumu pahalı ve
 * gün şeridi bir ekranda otuz kez biçimlendirme yapıyor.
 *
 * HEPSİNDE `timeZone: 'UTC'` — gün UTC gece yarısına açıldığı için başka bir
 * dilim gün numarasını bir kaydırırdı.
 */
const longFormatter = new Intl.DateTimeFormat('tr-TR', {
  timeZone: 'UTC',
  day: 'numeric',
  month: 'long',
  year: 'numeric',
});

const dayMonthFormatter = new Intl.DateTimeFormat('tr-TR', {
  timeZone: 'UTC',
  day: 'numeric',
  month: 'long',
});

const weekdayFormatter = new Intl.DateTimeFormat('tr-TR', {
  timeZone: 'UTC',
  weekday: 'long',
});

const shortWeekdayFormatter = new Intl.DateTimeFormat('tr-TR', {
  timeZone: 'UTC',
  weekday: 'short',
});

const dayNumberFormatter = new Intl.DateTimeFormat('tr-TR', { timeZone: 'UTC', day: 'numeric' });

const monthYearFormatter = new Intl.DateTimeFormat('tr-TR', {
  timeZone: 'UTC',
  month: 'long',
  year: 'numeric',
});

function format(formatter: Intl.DateTimeFormat, date: BusinessDate): string {
  const instant = toUtcInstant(date);
  return instant ? formatter.format(instant) : '—';
}

/** `20 Ağustos 2026` */
export function formatLongDate(date: BusinessDate): string {
  return format(longFormatter, date);
}

/** `20 Ağustos` — yıl aynıysa yılı tekrar etmenin bilgi değeri yok. */
export function formatDayMonth(date: BusinessDate): string {
  return format(dayMonthFormatter, date);
}

/** `Perşembe` */
export function formatWeekday(date: BusinessDate): string {
  return format(weekdayFormatter, date);
}

/** `Per` — gün şeridindeki iki satırlık hücrenin üst satırı. */
export function formatShortWeekday(date: BusinessDate): string {
  return format(shortWeekdayFormatter, date);
}

/** `20` — takvim ızgarası hücresi. */
export function formatDayNumber(date: BusinessDate): string {
  return format(dayNumberFormatter, date);
}

/** `Ağustos 2026` — takvim başlığı. */
export function formatMonthYear(date: BusinessDate): string {
  return format(monthYearFormatter, date);
}

/**
 * `Bugün` / `Yarın` / `Perşembe`.
 *
 * İlk iki gün ADLANDIRILIYOR çünkü "Perşembe" tek başına hangi perşembe
 * olduğunu söylemiyor ve müşterinin en çok baktığı iki gün bunlar.
 */
export function relativeDayLabel(
  date: BusinessDate,
  today: BusinessDate = businessToday(),
): string {
  const diff = daysBetween(today, date);
  if (diff === 0) return 'Bugün';
  if (diff === 1) return 'Yarın';
  return formatWeekday(date);
}

/**
 * `Bugünün menüsü` / `20 Ağustos menüsü` — sipariş listesinde ve sepette
 * günü tek satırda söyleyen ifade.
 */
export function serviceDayTitle(date: BusinessDate, today: BusinessDate = businessToday()): string {
  const diff = daysBetween(today, date);
  if (diff === 0) return 'Bugünün menüsü';
  if (diff === 1) return 'Yarının menüsü';
  return `${formatDayMonth(date)} menüsü`;
}
