import { TIME_ZONE } from '@/i18n/request';

/**
 * Para biçimlendirme. Girdi **kuruş** cinsinden tam sayıdır; float aritmetiği
 * yapılmaz — tamsayı bölme ve kalan kullanılır (`docs/openapi.yaml` §Değişmezler).
 *
 * `41000` → `"410,00 ₺"`, `-2500` → `"-25,00 ₺"`
 */
export function formatPrice(kurus: number): string {
  const safe = Number.isFinite(kurus) ? Math.trunc(kurus) : 0;
  const negative = safe < 0;
  const absolute = negative ? -safe : safe;

  const lira = Math.floor(absolute / 100);
  const remainder = absolute % 100;

  const liraText = new Intl.NumberFormat('tr-TR', { useGrouping: true }).format(lira);
  const kurusText = remainder < 10 ? `0${remainder}` : String(remainder);

  return `${negative ? '-' : ''}${liraText},${kurusText} ₺`;
}

/** Seçenek farkı gibi işaretli tutarlar: `+40,00 ₺` / `-5,00 ₺` / boş (0). */
export function formatPriceDelta(kurus: number): string {
  if (kurus === 0) return '';
  return kurus > 0 ? `+${formatPrice(kurus)}` : formatPrice(kurus);
}

/**
 * schema.org `Offer.price` biçimi: nokta ayraçlı, gruplamasız (`185.00`).
 * Kuruş tam sayısından **metin** olarak üretilir, float aritmetiği yapılmaz.
 */
export function schemaOrgPrice(kurus: number): string {
  const safe = Math.max(0, Math.trunc(kurus));
  return `${Math.floor(safe / 100)}.${String(safe % 100).padStart(2, '0')}`;
}

/** Kuruş toplamı — tamsayı çarpımı, asla float. */
export function multiplyPrice(unitKurus: number, quantity: number): number {
  return Math.trunc(unitKurus) * Math.trunc(quantity);
}

const dateTimeFormatter = new Intl.DateTimeFormat('tr-TR', {
  timeZone: TIME_ZONE,
  day: '2-digit',
  month: 'long',
  year: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
});

const timeFormatter = new Intl.DateTimeFormat('tr-TR', {
  timeZone: TIME_ZONE,
  hour: '2-digit',
  minute: '2-digit',
});

const dateFormatter = new Intl.DateTimeFormat('tr-TR', {
  timeZone: TIME_ZONE,
  day: '2-digit',
  month: 'long',
  year: 'numeric',
});

/** ISO 8601 UTC → Europe/Istanbul yerel metni. */
export function formatDateTime(iso: string): string {
  const date = new Date(iso);
  return Number.isNaN(date.getTime()) ? '—' : dateTimeFormatter.format(date);
}

export function formatTime(iso: string): string {
  const date = new Date(iso);
  return Number.isNaN(date.getTime()) ? '—' : timeFormatter.format(date);
}

export function formatDate(iso: string): string {
  const date = new Date(iso);
  return Number.isNaN(date.getTime()) ? '—' : dateFormatter.format(date);
}
