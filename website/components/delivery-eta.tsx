'use client';

import { useEffect, useState } from 'react';
import { IconClock } from '@/components/icons';
import { cn } from '@/lib/cn';
import {
  etaCaveat,
  etaClockText,
  etaEndsAtMs,
  etaMinutesText,
  etaSentence,
  etaTrackingDetail,
} from '@/lib/eta';
import type { DeliveryType, EtaWindow, LocationEta } from '@/lib/api/types';

/**
 * Teslim süresi tahmininin ekrandaki hâlleri.
 *
 * NEDEN İSTEMCİ BİLEŞENİ: dakika aralığı eskimez ama **duvar saati eskir.**
 * `/menu` 60 saniyelik ISR ile önbelleğe alınıyor ve trafik seyrekken Next
 * önbellekteki kopyayı servis edip yenilemeyi arkada yapıyor; sunucuda
 * hesaplanan "yaklaşık 13:15" saat 13:40'ta hâlâ ekranda olabilirdi. Saat
 * tarayıcıda, sayfanın gerçekten görüldüğü anda hesaplanıyor.
 */

/** Duvar saati hesabının dayanağı. Sunucu render'ında `null` — saat çizilmez. */
function useNowMs(): number | null {
  const [now, setNow] = useState<number | null>(null);

  useEffect(() => {
    setNow(Date.now());
    // Sekme uzun süre açık kalırsa saat kaymasın; dakikada bir yeter,
    // aralık zaten beş dakikaya yuvarlı.
    const timer = setInterval(() => setNow(Date.now()), 60_000);
    return () => clearInterval(timer);
  }, []);

  return now;
}

/**
 * Vitrin bilgi şeridindeki değer: `60-85 dk · 13:15-13:40`.
 *
 * Şeritte cümleye yer yok; sağlamlık ayrımı (`measured`/`configured`) burada
 * değil, kararın verildiği ekranlarda (sepet, ödeme) anlatılıyor. Şeridin işi
 * büyüklük sırasını vermek.
 */
export function EtaFactValue({ estimate }: { estimate: EtaWindow }) {
  const now = useNowMs();
  return (
    <>
      {etaMinutesText(estimate)}
      {now !== null && (
        <span className="font-normal text-neutral-600"> · {etaClockText(estimate, now)}</span>
      )}
    </>
  );
}

/**
 * Sepet/sipariş özetindeki kutu. İki teslim türü de gösteriliyor: sepette
 * kullanıcı henüz seçim yapmadı ve gel-al belirgin biçimde daha hızlı —
 * yalnızca adrese teslimi göstermek gel-al'ı gizlemek olurdu.
 */
export function EtaSummary({ eta, className }: { eta: LocationEta; className?: string }) {
  const now = useNowMs();

  // İki tahminin kaynağı ayrışabilir (adrese teslim ölçülmüş, gel-al henüz
  // değil). Böyle bir durumda TEMKİNLİ olanın dili geçerli: ölçülmemiş bir
  // tahmini ölçülmüş gibi sunmaktansa ikisine de tahmin demek doğru.
  const cautious = eta.delivery.source === 'configured' ? eta.delivery : eta.pickup;

  return (
    <section
      className={cn('rounded-card border border-neutral-200 bg-neutral-50 p-3', className)}
      aria-labelledby="teslim-tahmini"
    >
      <h3
        id="teslim-tahmini"
        className="flex items-center gap-1.5 text-sm font-semibold text-neutral-900"
      >
        <IconClock className="h-4 w-4 text-brand-700" />
        Tahmini teslim süresi
      </h3>

      <dl className="mt-2 space-y-2 text-sm">
        <EtaSummaryRow label="Adrese teslim" estimate={eta.delivery} nowMs={now} />
        <EtaSummaryRow label="Gel-al" estimate={eta.pickup} nowMs={now} />
      </dl>

      {etaCaveat(cautious) && (
        <p className="mt-2 text-xs text-neutral-600">{etaCaveat(cautious)}</p>
      )}
    </section>
  );
}

function EtaSummaryRow({
  label,
  estimate,
  nowMs,
}: {
  label: string;
  estimate: EtaWindow;
  nowMs: number | null;
}) {
  return (
    <div className="flex items-start justify-between gap-3">
      <dt className="text-neutral-600">{label}</dt>
      <dd className="text-right">
        <span className="font-semibold text-neutral-900">{etaMinutesText(estimate)}</span>
        {nowMs !== null && (
          <span className="block text-xs text-neutral-600">
            yaklaşık {etaClockText(estimate, nowMs)} arası
          </span>
        )}
      </dd>
    </div>
  );
}

/**
 * Ödeme ekranındaki "En kısa sürede" seçeneğinin açıklaması. Teslim türü
 * değiştiğinde çağıran bileşen farklı `estimate` geçirir — gel-alda yol süresi
 * yok, aynı sayıyı göstermek yanlış olurdu.
 */
export function EtaOptionNote({
  estimate,
  deliveryType,
}: {
  estimate: EtaWindow;
  deliveryType: DeliveryType;
}) {
  const now = useNowMs();
  const caveat = etaCaveat(estimate);

  return (
    <>
      <span className="mt-1 block text-neutral-800">
        {etaSentence(estimate, deliveryType)}
        {now !== null && ` Şu an verirseniz yaklaşık ${etaClockText(estimate, now)} arası.`}
      </span>
      {caveat && <span className="mt-0.5 block text-xs text-neutral-600">{caveat}</span>}
    </>
  );
}

/**
 * Sipariş takip ekranındaki tahmin. Dayanak noktası **siparişin oluşturulma
 * anı**, "şimdi" değil: müşteri sayfayı yarım saat sonra açtığında tahmin
 * yarım saat ileri kaymamalı.
 */
export function OrderEtaNote({
  estimate,
  deliveryType,
  createdAt,
}: {
  estimate: EtaWindow;
  deliveryType: DeliveryType;
  createdAt: string;
}) {
  const now = useNowMs();
  const createdMs = new Date(createdAt).getTime();

  if (now === null || Number.isNaN(createdMs)) return null;

  // Aralığın üst ucu geçmişse tahmin bilgi vermiyor, yanıltıyor. Sipariş
  // gecikmiş olabilir; bunu durum adımları ve son güncelleme zamanı zaten
  // gösteriyor.
  if (etaEndsAtMs(estimate, createdMs) < now) return null;

  const caveat = etaCaveat(estimate);

  return (
    <p className="mt-4 flex items-start gap-2 rounded-card bg-brand-50 px-3 py-2 text-sm">
      <IconClock className="mt-0.5 h-4 w-4 shrink-0 text-brand-700" />
      <span>
        <span className="font-semibold text-neutral-900">
          {deliveryType === 'pickup' ? 'Tahmini hazır olma' : 'Tahmini teslim'}: yaklaşık{' '}
          {etaClockText(estimate, createdMs)} arası
        </span>
        <span className="block text-neutral-800">{etaTrackingDetail(estimate, deliveryType)}</span>
        {caveat && <span className="block text-xs text-neutral-600">{caveat}</span>}
      </span>
    </p>
  );
}
