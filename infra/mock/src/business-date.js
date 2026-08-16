// İşletme takvimi — `website/lib/business-date.ts` ve
// `packages/core/lib/src/business_date.dart` ile aynı kuralları uygular.
//
// Servis günü bir AN değil bir TAKVİM GÜNÜ; bu yüzden her yerde
// `'YYYY-AA-GG'` metni taşınır. Mock'un çalıştığı makinenin saat dilimi
// (CI'da UTC) günü kaydırmasın diye gün hesabı burada tek yerde yapılıyor —
// aksi hâlde İstanbul'da 01:00'de üretilen tohum, UTC'de bir önceki güne
// düşerdi ve "bugünün menüsü" boş dönerdi.

/**
 * Türkiye 2016'dan beri kalıcı UTC+03; yaz saati uygulaması yok.
 *
 * Sabit sayı kullanmak `Intl` üzerinden dilim çözmekten daha güvenli:
 * konteynerde tzdata bulunmayabiliyor ve o durumda `Intl` sessizce UTC'ye
 * düşüp bütün günleri üç saat kaydırırdı.
 */
export const TZ_OFFSET_MINUTES = 180;

/** Verilen anın işletme günü. */
export function businessDateOf(instant) {
  return new Date(instant.getTime() + TZ_OFFSET_MINUTES * 60_000)
    .toISOString()
    .slice(0, 10);
}

/** İşletme saatindeki bugün. */
export function businessToday(now = new Date()) {
  return businessDateOf(now);
}

export function addDays(date, count) {
  const instant = new Date(`${date}T00:00:00Z`);
  instant.setUTCDate(instant.getUTCDate() + count);
  return instant.toISOString().slice(0, 10);
}

/** İki gün arasındaki fark (gün). Negatif olabilir. */
export function daysBetween(from, to) {
  const ms = new Date(`${to}T00:00:00Z`) - new Date(`${from}T00:00:00Z`);
  return Math.round(ms / 86_400_000);
}

/** ISO hafta günü: 1 Pazartesi .. 7 Pazar. Türkiye takvimi pazartesi başlar. */
export function isoWeekday(date) {
  const weekday = new Date(`${date}T00:00:00Z`).getUTCDay();
  return weekday === 0 ? 7 : weekday;
}

export function isBusinessDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;

  // `2026-02-31` desene uyuyor ama gün yok: JS onu 3 Mart'a taşır. Geri
  // yazdırıp karşılaştırmak bu sessiz kaymayı yakalar.
  const instant = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(instant.getTime()) && instant.toISOString().slice(0, 10) === value;
}

/**
 * İşletme saatini (`'08:00'`) o günün MUTLAK anına çevirir.
 *
 * Sözleşmedeki `cutoff_at` bilerek mutlak: istemci "saat 08:00" metnini
 * kendi cihaz dilimiyle yorumlarsa, telefonu Almanya'da olan müşteri kesim
 * saatini bir saat geç sanar ve kapanmış güne sipariş dener.
 */
export function instantAt(date, hhmm) {
  const [hour, minute] = String(hhmm).split(':').map(Number);
  const instant = new Date(`${date}T00:00:00Z`);
  instant.setUTCMinutes(instant.getUTCMinutes() + hour * 60 + minute - TZ_OFFSET_MINUTES);

  return instant.toISOString().replace(/\.\d{3}Z$/, 'Z');
}
