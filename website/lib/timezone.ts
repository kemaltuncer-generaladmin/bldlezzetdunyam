import { TIME_ZONE } from '@/i18n/request';

/**
 * `datetime-local` alanı duvar saati verir ("2026-08-05T13:30"); sözleşme ise
 * ISO 8601 **UTC** ister. Dönüşüm sunucuda ve her zaman Europe/Istanbul'a göre
 * yapılır — kullanıcının cihaz saat dilimi farklı olabilir.
 *
 * Harici tarih kütüphanesi eklemeden `Intl` ile ofset hesaplanır; yaz saati
 * uygulaması geri gelirse de doğru çalışır.
 */
function zoneOffsetMs(instant: Date, timeZone: string): number {
  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone,
    hour12: false,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });

  const parts: Record<string, number> = {};
  for (const part of formatter.formatToParts(instant)) {
    if (part.type !== 'literal') parts[part.type] = Number.parseInt(part.value, 10);
  }

  const asUtc = Date.UTC(
    parts.year ?? 1970,
    (parts.month ?? 1) - 1,
    parts.day ?? 1,
    (parts.hour ?? 0) % 24,
    parts.minute ?? 0,
    parts.second ?? 0,
  );

  return asUtc - instant.getTime();
}

const clockFormatter = new Intl.DateTimeFormat('tr-TR', {
  timeZone: TIME_ZONE,
  hour12: false,
  hour: '2-digit',
  minute: '2-digit',
});

/**
 * Bir anı Europe/Istanbul **duvar saatine** çevirir: `13:15`.
 *
 * Teslim tahmini "60-85 dakika" yerine "13:15-13:40" olarak da gösteriliyor;
 * bu çeviri kullanıcının cihaz saat dilimine göre YAPILMAMALI. Yurt dışından
 * ya da saati yanlış kurulmuş bir cihazdan bakan müşteriye mutfağın saatini
 * göstermek gerekir, tarayıcının saatini değil.
 */
export function istanbulClock(instant: Date): string {
  return Number.isNaN(instant.getTime()) ? '—' : clockFormatter.format(instant);
}

const LOCAL_PATTERN = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$/;

/** "2026-08-05T13:30" (Europe/Istanbul) → "2026-08-05T10:30:00.000Z" */
export function istanbulLocalToUtcIso(localValue: string): string | null {
  const match = LOCAL_PATTERN.exec(localValue.trim());
  if (!match) return null;

  const [, year, month, day, hour, minute] = match;
  const wallClockAsUtc = Date.UTC(
    Number(year),
    Number(month) - 1,
    Number(day),
    Number(hour),
    Number(minute),
  );
  if (!Number.isFinite(wallClockAsUtc)) return null;

  // İki geçiş: ilk tahminle ofseti bul, sonra düzeltilmiş anla tekrar doğrula.
  let utcMs = wallClockAsUtc - zoneOffsetMs(new Date(wallClockAsUtc), TIME_ZONE);
  utcMs = wallClockAsUtc - zoneOffsetMs(new Date(utcMs), TIME_ZONE);

  return new Date(utcMs).toISOString();
}

/** `datetime-local` alanının `min` değeri: şu andan itibaren. */
export function istanbulNowLocalValue(offsetMinutes = 0): string {
  const target = new Date(Date.now() + offsetMinutes * 60_000);
  const formatter = new Intl.DateTimeFormat('sv-SE', {
    timeZone: TIME_ZONE,
    hour12: false,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });
  // sv-SE "2026-08-05 13:30" verir; HTML alanı "T" ayırıcı ister.
  return formatter.format(target).replace(' ', 'T');
}
