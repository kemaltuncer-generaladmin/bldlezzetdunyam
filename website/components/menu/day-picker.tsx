import Link from 'next/link';
import { CalendarDays } from 'lucide-react';
import {
  daysBetween,
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
 *
 * ## HAFTA SONU BURADA ÖZEL DEĞİL
 *
 * Cumartesi ve pazar kodda hiçbir yerde geçmiyor. Satış kanalı hafta sonu da
 * AÇIK — cumartesi günü pazartesiye sipariş verilebiliyor — kapalı olan tek
 * şey o günün SERVİSİ. Hangi günlerde yemek çıktığını sunucu söylüyor
 * (`Location.service_weekdays`, ISO numaraları); `6` ile `7`yi buraya gömmek,
 * işletme cumartesi de yemek çıkarmaya başladığında siteyi yeniden
 * yayınlamayı gerektirirdi. Alan eksik gelirse hiçbir gün servis dışı
 * sayılmaz: eksik bilgiyle günleri sessizce kapatmak satış kaybıdır.
 */

type DayState = {
  date: BusinessDate;
  entry: MenuCalendarDay | null;
  selectable: boolean;
  isSelected: boolean;
  isToday: boolean;
  /** İşletme bu hafta gününde yemek çıkarıyor mu? */
  serviceDay: boolean;
};

function buildDays(
  from: BusinessDate,
  to: BusinessDate,
  calendar: readonly MenuCalendarDay[],
  selected: BusinessDate,
  today: BusinessDate,
  serviceWeekdays: readonly number[] | undefined,
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
      /*
       * Takvim yanıtı seyrek: servis dışı bir günün kaydı hiç gelmeyebilir ve
       * o zaman `entry.weekend` de okunamaz. Hafta gününü listeyle karşılamak,
       * kaydı olmayan günün de doğru cümleyi almasını sağlıyor.
       */
      serviceDay: serviceWeekdays === undefined || serviceWeekdays.includes(isoWeekday(date)),
    };
  });
}

/** Günün kısa hâli: neden seçilemediği ekran okuyucuya da söylenir. */
function dayHint(day: DayState): string {
  // Kapalı gün kazanır: menü girilmiş olsa bile o gün sipariş alınmıyor.
  if (day.entry?.closed) return day.entry.note ? `Kapalı — ${day.entry.note}` : 'Kapalı';
  /*
   * "Servis günü değil" ile "menü açıklanmadı" AYRI cümleler. İkisini aynı
   * metne düşürmek, her cumartesi müşteriye "menü henüz girilmedi" dedirtip
   * akşama doğru tekrar bakmasını beklettirirdi — oysa o gün hiç menü
   * çıkmayacak.
   */
  if (day.entry?.weekend === true || !day.serviceDay) return 'Servis günü değil';
  if (!day.entry?.has_menu) return 'Menü açıklanmadı';
  // Menüsü var ama porsiyonu kalmadı: gün takvimde durmaya devam ediyor.
  if (day.entry.sold_out) return 'Kontenjan doldu';
  if (!day.entry.is_orderable) return 'Sipariş alınmıyor';
  return day.entry.title ?? 'Menü var';
}

/**
 * Durum noktası. Renk TEK BAŞINA anlam taşımıyor: her hücrede metin karşılığı
 * `title` ve `sr-only` olarak da var (kılavuz: "zorunlu alan * ile, yalnız
 * renk asla").
 *
 * Tükenmiş gün KENDİ TONUNU alıyor (uyarı sarısı): kırmızı "kapalıyız"
 * demektir ve tatille karışır, gri ise "menü yok" ile karışır. Kapış kapış
 * giden bir günü hiç hazırlanmamış gibi göstermek, mutfağın işini görünmez
 * kılardı.
 */
function DayDot({ day }: { day: DayState }) {
  const tone = day.entry?.closed
    ? 'bg-danger'
    : day.entry?.sold_out
      ? 'bg-warning'
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

/** Bu kadar günlük bir pencere tek şeride sığar; ay takvimi çizilmez. */
const STRIP_ONLY_SPAN_DAYS = 14;

export function DayPicker({
  calendar,
  today,
  selectedDate,
  lastDate,
  serviceWeekdays,
  basePath = '/menu',
}: {
  calendar: readonly MenuCalendarDay[];
  today: BusinessDate;
  selectedDate: BusinessDate;
  /** Sipariş alınabilen en uzak gün (`max_lookahead_days`). */
  lastDate: BusinessDate;
  /** `Location.service_weekdays` — yemek çıkan hafta günleri (ISO). */
  serviceWeekdays?: readonly number[];
  basePath?: string;
}) {
  const days = buildDays(today, lastDate, calendar, selectedDate, today, serviceWeekdays);

  /*
   * TEK ARAYÜZ Mİ, İKİ ARAYÜZ Mİ? Pencerenin genişliği karar veriyor.
   *
   * Sipariş penceresi bir aylıkken şerit iki haftayı gösteriyor, gerisi ay
   * takviminde duruyordu: otuz hücrelik bir şeritte kullanıcı sonunu hiç
   * görmüyor. Pencere yedi güne indiğinde (`max_lookahead_days: 7`) aynı
   * takvim bir buçuk haftalık bir ayı çizmeye başladı — otuz hücrenin
   * yirmi ikisi boş, açılıp kapanan bir kutunun içinde. Şeridin zaten
   * gösterdiği günleri ikinci kez, daha kötü bir düzende sunmak
   * kullanıcıya "başka günler de var" diye yanlış bir söz veriyordu.
   */
  const stripOnly = daysBetween(today, lastDate) <= STRIP_ONLY_SPAN_DAYS;
  const stripDays = stripOnly ? days : days.slice(0, STRIP_ONLY_SPAN_DAYS);

  const months = new Map<string, DayState[]>();
  if (!stripOnly) {
    for (const day of days) {
      const key = monthKey(day.date);
      months.set(key, [...(months.get(key) ?? []), day]);
    }
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

      <p className="mt-3 text-body-sm text-muted-foreground">
        Menüsü açıklanmış günler seçilebilir. Kapalı günler, servis günü olmayanlar ve menüsü henüz
        girilmemiş günler pasiftir.
      </p>

      {!stripOnly && (
        <details className="group mt-3">
          <summary className="flex min-h-11 cursor-pointer items-center gap-2 text-label text-primary-text">
            <CalendarDays aria-hidden="true" strokeWidth={1.75} className="size-4" />
            Ay takvimi
          </summary>

          {[...months.entries()].map(([key, monthDays]) => (
            <MonthGrid key={key} days={monthDays} basePath={basePath} />
          ))}
        </details>
      )}

      {/*
        Takvimin sonu: sipariş penceresinin son günü. Yönetici pencereyi
        değiştirdiğinde metin de değişiyor — sabit "30 gün" yazsaydık ikisi
        sessizce ayrışırdı. Ay takviminin İÇİNDEN çıkarıldı: takvim
        katlandığında pencerenin nerede bittiğini söyleyen tek cümle de
        onunla birlikte kaybolurdu.
      */}
      <p className="mt-3 text-caption text-muted-foreground">
        En son {formatLongDate(lastDate)} gününe kadar sipariş alıyoruz.
      </p>
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
