import Link from 'next/link';
import { CalendarDays } from 'lucide-react';
import {
  eachDay,
  formatDayNumber,
  formatLongDate,
  formatMonthYear,
  formatShortWeekday,
  isoWeekday,
  monthKey,
  relativeDayLabel,
  startOfMonth,
  type BusinessDate,
} from '@/lib/business-date';
import { cn } from '@/lib/utils';
import type { MenuCalendarDay } from '@/lib/api/types';

/**
 * GÜN SEÇİCİ — yatay tarih şeridi + ay takvimi (B-19).
 *
 * ## Neden JavaScript yok?
 *
 * Bileşenin tamamı sunucuda çizilir ve her gün bir bağlantıdır
 * (`/menu?gun=YYYY-AA-GG`). Ay takvimi `<details>` içinde: açılıp kapanması
 * tarayıcının işi. Böylece seçici JavaScript yüklenmeden ÖNCE çalışıyor ve
 * arama motoru her günün menüsünü ayrı bir adreste görebiliyor. Durum
 * taşıyan bir istemci bileşeni yazsaydık, sepetin en kritik girişi bir
 * paketin yüklenmesini bekliyor olurdu.
 *
 * ## Takvim yanıtı SEYREKTİR
 *
 * Sunucu yalnızca menüsü olan ya da kapalı olan günleri döner
 * (`DailyMenuService::calendar`); aradaki günler yanıtta YOKTUR ve "menü
 * yok" demektir. Bu yüzden günler burada üretilip yanıtla eşleştiriliyor —
 * yanıtı olduğu gibi listelemek, takvimde günleri atlayan boşluklar
 * bırakırdı.
 */

type DayState = {
  date: BusinessDate;
  entry: MenuCalendarDay | null;
  selectable: boolean;
  isSelected: boolean;
  isToday: boolean;
};

function buildDays(
  from: BusinessDate,
  to: BusinessDate,
  calendar: readonly MenuCalendarDay[],
  selected: BusinessDate,
  today: BusinessDate,
): DayState[] {
  const byDate = new Map(calendar.map((day) => [day.date, day]));

  return eachDay(from, to).map((date) => {
    const entry = byDate.get(date) ?? null;
    return {
      date,
      entry,
      selectable: entry?.is_orderable === true,
      isSelected: date === selected,
      isToday: date === today,
    };
  });
}

/** Günün kısa hâli: neden seçilemediği ekran okuyucuya da söylenir. */
function dayHint(day: DayState): string {
  if (day.entry?.closed) return day.entry.note ? `Kapalı — ${day.entry.note}` : 'Kapalı';
  if (!day.entry?.has_menu) return 'Menü açıklanmadı';
  if (!day.entry.is_orderable) return 'Sipariş alınmıyor';
  return day.entry.title ?? 'Menü var';
}

/**
 * Durum noktası. Renk TEK BAŞINA anlam taşımıyor: her hücrede metin karşılığı
 * `title` ve `sr-only` olarak da var (kılavuz: "zorunlu alan * ile, yalnız
 * renk asla").
 */
function DayDot({ day }: { day: DayState }) {
  const tone = day.entry?.closed
    ? 'bg-danger'
    : day.entry?.is_orderable
      ? 'bg-success'
      : 'bg-neutral-400';

  return <span aria-hidden="true" className={cn('size-1.5 rounded-full', tone)} />;
}

function DayCell({ day, basePath }: { day: DayState; basePath: string }) {
  const label = `${formatLongDate(day.date)} — ${dayHint(day)}`;

  const shell = cn(
    'flex min-h-11 w-16 shrink-0 flex-col items-center gap-0.5 rounded-sm border px-2 py-2 text-center',
    'transition-colors duration-(--duration-fast) ease-(--ease-out-soft)',
    day.isSelected
      ? 'border-primary bg-primary text-primary-foreground'
      : day.selectable
        ? 'bg-card text-foreground hover:border-brand-300 hover:bg-accent hover:text-accent-foreground'
        : // Seçilemeyen gün: sessiz yüzey. Soluklaştırma (`opacity`) yerine
          // gerçek renk, çünkü yarı saydam bir hücre altındaki zemine göre
          // her ekranda başka bir tona düşüyordu.
          'cursor-not-allowed border-transparent bg-muted text-muted-foreground',
  );

  const body = (
    <>
      <span className="text-overline uppercase">{formatShortWeekday(day.date)}</span>
      <span className="text-title font-semibold">{formatDayNumber(day.date)}</span>
      <DayDot day={day} />
      <span className="sr-only">{label}</span>
    </>
  );

  if (!day.selectable) {
    return (
      <li>
        <span aria-disabled="true" title={label} className={shell}>
          {body}
        </span>
      </li>
    );
  }

  return (
    <li>
      <Link
        href={`${basePath}?gun=${day.date}`}
        aria-current={day.isSelected ? 'date' : undefined}
        title={label}
        className={shell}
      >
        {body}
      </Link>
    </li>
  );
}

function MonthGrid({ days, basePath }: { days: DayState[]; basePath: string }) {
  const first = days[0];
  if (!first) return null;

  // Ayın 1'i ile ilk günün arasındaki boşluk + haftanın başına hizalama.
  // ISO hafta günü (1 Pazartesi) kullanılıyor: Türkiye'de takvim pazartesi
  // başlar, `Date.getUTCDay()`in pazar başlangıcı değil.
  const monthStart = startOfMonth(first.date);
  const leading = isoWeekday(monthStart) - 1;
  const offset = Number(first.date.slice(8)) - 1;

  return (
    <section aria-label={formatMonthYear(first.date)} className="mt-4">
      <h3 className="text-label text-muted-foreground">{formatMonthYear(first.date)}</h3>

      <div aria-hidden="true" className="mt-2 grid grid-cols-7 gap-1 text-center">
        {['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'].map((name) => (
          <span key={name} className="text-caption text-muted-foreground">
            {name}
          </span>
        ))}
      </div>

      <ul className="mt-1 grid grid-cols-7 gap-1">
        {Array.from({ length: leading + offset }, (_, index) => (
          <li key={`bos-${index}`} aria-hidden="true" />
        ))}

        {days.map((day) => {
          const label = `${formatLongDate(day.date)} — ${dayHint(day)}`;
          const shell = cn(
            'grid aspect-square w-full place-items-center rounded-xs border text-body-sm',
            'transition-colors duration-(--duration-fast) ease-(--ease-out-soft)',
            day.isSelected
              ? 'border-primary bg-primary font-semibold text-primary-foreground'
              : day.selectable
                ? 'bg-card font-medium text-foreground hover:border-brand-300 hover:bg-accent'
                : 'cursor-not-allowed border-transparent bg-muted text-muted-foreground',
          );

          return (
            <li key={day.date}>
              {day.selectable ? (
                <Link
                  href={`${basePath}?gun=${day.date}`}
                  aria-current={day.isSelected ? 'date' : undefined}
                  title={label}
                  className={shell}
                >
                  {formatDayNumber(day.date)}
                  <span className="sr-only">{label}</span>
                </Link>
              ) : (
                <span aria-disabled="true" title={label} className={shell}>
                  {formatDayNumber(day.date)}
                  <span className="sr-only">{label}</span>
                </span>
              )}
            </li>
          );
        })}
      </ul>
    </section>
  );
}

export function DayPicker({
  calendar,
  today,
  selectedDate,
  lastDate,
  basePath = '/menu',
}: {
  calendar: readonly MenuCalendarDay[];
  today: BusinessDate;
  selectedDate: BusinessDate;
  /** Sipariş alınabilen en uzak gün (`max_lookahead_days`). */
  lastDate: BusinessDate;
  basePath?: string;
}) {
  const days = buildDays(today, lastDate, calendar, selectedDate, today);

  // Şerit iki hafta gösteriyor; gerisi ay takviminde. Otuz hücrelik bir
  // şeritte kullanıcı sonunu hiç görmüyor ve kaydırma çubuğu da yok.
  const stripDays = days.slice(0, 14);

  const months = new Map<string, DayState[]>();
  for (const day of days) {
    const key = monthKey(day.date);
    months.set(key, [...(months.get(key) ?? []), day]);
  }

  const selected = days.find((day) => day.date === selectedDate) ?? null;
  const closedNote = selected?.entry?.closed ? (selected.entry.note ?? null) : null;

  return (
    <div className="rounded-md border bg-card p-4 text-card-foreground shadow-card dark:shadow-none dark:inset-ring dark:inset-ring-white/5">
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <h2 className="font-display text-h3 font-semibold text-heading">Hangi gün için?</h2>
        <p className="text-body-sm text-muted-foreground">
          {relativeDayLabel(selectedDate, today)} · {formatLongDate(selectedDate)}
        </p>
      </div>

      <nav aria-label="Gün seçimi" className="mt-3">
        <ul className="bld-rail pb-1">
          {stripDays.map((day) => (
            <DayCell key={day.date} day={day} basePath={basePath} />
          ))}
        </ul>
      </nav>

      {closedNote && (
        <p
          role="status"
          className="mt-3 rounded-sm bg-danger-surface px-3 py-2 text-body-sm text-danger-foreground"
        >
          {formatLongDate(selectedDate)}: {closedNote}
        </p>
      )}

      <details className="group mt-3">
        <summary className="flex min-h-11 cursor-pointer items-center gap-2 text-label text-primary-text">
          <CalendarDays aria-hidden="true" strokeWidth={1.75} className="size-4" />
          Ay takvimi
        </summary>

        <p className="mt-2 text-body-sm text-muted-foreground">
          Menüsü açıklanmış günler seçilebilir. Kapalı günler ve menüsü henüz girilmemiş günler
          pasiftir.
        </p>

        {[...months.entries()].map(([key, monthDays]) => (
          <MonthGrid key={key} days={monthDays} basePath={basePath} />
        ))}

        {/*
          Takvimin sonu: sipariş penceresinin son günü. Yönetici pencereyi
          değiştirdiğinde metin de değişiyor — sabit "30 gün" yazsaydık
          ikisi sessizce ayrışırdı.
        */}
        <p className="mt-4 text-caption text-muted-foreground">
          En son {formatLongDate(lastDate)} gününe kadar sipariş alıyoruz.
        </p>
      </details>
    </div>
  );
}

/** Bir günün takvim kaydı — sayfa başlığı kapalı gün notunu buradan alır. */
export function findCalendarDay(
  calendar: readonly MenuCalendarDay[],
  date: BusinessDate,
): MenuCalendarDay | null {
  return calendar.find((day) => day.date === date) ?? null;
}

/** Sipariş verilebilecek EN YAKIN gün — boş gün ekranındaki çıkış yolu. */
export function nextOrderableDay(
  calendar: readonly MenuCalendarDay[],
  after: BusinessDate,
): MenuCalendarDay | null {
  return (
    [...calendar]
      .filter((day) => day.is_orderable && day.date > after)
      .sort((a, b) => (a.date < b.date ? -1 : 1))[0] ?? null
  );
}
