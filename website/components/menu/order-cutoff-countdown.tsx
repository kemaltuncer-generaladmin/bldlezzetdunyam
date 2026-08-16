'use client';

import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { AlarmClock } from 'lucide-react';
import { cn } from '@/lib/utils';

/**
 * KESİM SAATİ GERİ SAYIMI — "bu güne sipariş için ne kadar kaldı".
 *
 * ## Neden mutlak an okunuyor, saat değil
 *
 * Sözleşme kesimi `cutoff_at` alanında MUTLAK AN olarak veriyor ve gerekçesini
 * kendi yazıyor: kesim kuralını üç dilde yeniden hesaplamak (TS `Intl`, Dart'ta
 * sabit UTC+3, PHP'de `Europe/Istanbul`) yaz saatinde ve yanlış saat dilimli
 * cihazlarda üç ayrı sonuç üretiyor. Burada yapılan tek iş çıkarma.
 *
 * ## KARAR KAPISI BURASI DEĞİL
 *
 * Sözleşmenin açık şartı: *"İstemci `cutoff_at` ile `remaining_portions`'ı
 * kendi başına yorumlayıp 'bu gün kapanmıştır' sonucuna varmamalıdır."*
 * Sayaç sıfırlandığında ekran kilitlenmiyor; sayfa yeniden çekiliyor ve karar
 * yine sunucunun `is_orderable` alanından geliyor. Sayacın kendi başına
 * "sepete ekle"yi kapatması, saati iki dakika ileri olan bir cihazda hâlâ açık
 * bir günü kapatmak olurdu.
 *
 * ## İLK GEÇİŞTE `null`
 *
 * Sunucuda çizilen HTML ile istemcinin ilk çizimi aynı olmak zorunda; `now`
 * ilk geçişte okunsaydı iki taraf farklı dakikayı yazar ve React sitenin en
 * önemli sayfasında hidratlama uyuşmazlığı bildirirdi. Bu yüzden sayaç ilk
 * geçişte hiç çizilmiyor, `useEffect` içinde hayata geliyor.
 *
 * ## CİHAZ SAATİ YALAN SÖYLER
 *
 * Saati günlerce şaşmış cihaz nadir değil. Sunucunun çizim anı (`serverNow`,
 * HTTP `Date` başlığıyla aynı saat) ile cihazın anı arasındaki fark on
 * dakikayı geçiyorsa geri sayım HİÇ GÖSTERİLMİYOR: yanlış bir "son 3 dakika"
 * uyarısı, hiç uyarı olmamasından kötü — müşteriyi elindeki sepeti bırakıp
 * aceleyle çıkmaya iter.
 */

const MINUTE_MS = 60_000;
const HOUR_MS = 60 * MINUTE_MS;
const DAY_MS = 24 * HOUR_MS;

/** Bu farkın üstünde cihaz saati güvenilmez sayılır. */
const MAX_CLOCK_SKEW_MS = 10 * MINUTE_MS;

/** Bu kalanın altında sayaç uyarı tonuna geçer. */
const URGENT_MS = HOUR_MS;

/**
 * Kalan süreyi Türkçe okur.
 *
 * İki birimden fazlası yazılmıyor ("2 gün 3 saat 14 dakika" gibi): sayaç bir
 * kronometre değil, bir aciliyet işareti. Son dakikanın içinde sayı yerine
 * "1 dakikadan az" yazılıyor çünkü tik aralığı bir dakika ve "0 dakika"
 * yazan bir sayaç bozuk görünür.
 */
function formatRemaining(ms: number): string {
  if (ms < MINUTE_MS) return '1 dakikadan az';

  const days = Math.floor(ms / DAY_MS);
  const hours = Math.floor((ms % DAY_MS) / HOUR_MS);
  const minutes = Math.floor((ms % HOUR_MS) / MINUTE_MS);

  if (days > 0) return hours > 0 ? `${days} gün ${hours} saat` : `${days} gün`;
  if (hours > 0) return minutes > 0 ? `${hours} saat ${minutes} dakika` : `${hours} saat`;
  return `${minutes} dakika`;
}

type Props = {
  /** `DailyMenu.cutoff_at` — ISO 8601 UTC. */
  cutoffAt: string;
  /** Sunucunun sayfayı çizdiği an (ms). Cihaz sapmasının ölçüldüğü referans. */
  serverNow: number;
  className?: string;
};

export function OrderCutoffCountdown({ cutoffAt, serverNow, className }: Props) {
  const router = useRouter();
  const [now, setNow] = useState<number | null>(null);
  const refreshed = useRef(false);

  useEffect(() => {
    // Sapma yalnızca bir kez, bağlanma anında ölçülüyor: sonraki tiklerde iki
    // saat de aynı hızda ilerlediği için fark değişmez.
    if (Math.abs(Date.now() - serverNow) > MAX_CLOCK_SKEW_MS) return;

    setNow(Date.now());
    const timer = setInterval(() => setNow(Date.now()), MINUTE_MS);
    return () => clearInterval(timer);
  }, [serverNow]);

  const target = Date.parse(cutoffAt);
  const remaining = now === null || Number.isNaN(target) ? null : target - now;

  useEffect(() => {
    if (remaining === null || remaining > 0 || refreshed.current) return;
    // Gün kapandı: kararı sunucuya sordur. Bir kez — yenilenen sayfa yine
    // sıfırlanmış bir sayaçla gelirse sonsuz döngü olurdu.
    refreshed.current = true;
    router.refresh();
  }, [remaining, router]);

  // Sapma büyük, kesim okunamadı ya da gün çoktan kapandı: sessiz kal. Kapalı
  // günün cümlesini `dayUnavailableCopy` zaten kuruyor.
  if (remaining === null || remaining <= 0) return null;

  const urgent = remaining <= URGENT_MS;

  return (
    <p
      className={cn(
        'inline-flex items-center gap-1.5 rounded-xs px-2.5 py-1 text-body-sm font-medium',
        urgent ? 'bg-warning-surface text-warning-foreground' : 'bg-muted text-muted-foreground',
        className,
      )}
    >
      <AlarmClock aria-hidden="true" strokeWidth={1.75} className="size-4 shrink-0" />
      {/*
        Sayı dakikada bir değişiyor ama duyurulmuyor (`aria-live` YOK): ekran
        okuyucu kullanıcısının menüyü okurken dakika başı sözünün kesilmesi
        bilgi değil, engel olurdu. Metin odaklandığında zaten okunuyor.
      */}
      <span>
        Sipariş için son <time dateTime={cutoffAt}>{formatRemaining(remaining)}</time>
      </span>
    </p>
  );
}
