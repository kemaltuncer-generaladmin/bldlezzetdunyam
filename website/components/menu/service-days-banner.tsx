import type { Location } from '@/lib/api/types';

const GUN_ADLARI: Readonly<Record<number, string>> = {
  1: 'Pazartesi',
  2: 'Salı',
  3: 'Çarşamba',
  4: 'Perşembe',
  5: 'Cuma',
  6: 'Cumartesi',
  7: 'Pazar',
};

/**
 * "Hangi günler yemek çıkarıyoruz" bandı.
 *
 * NEDEN AYRI BİR BANT: servis günü olmadığını anlatan metin bugüne kadar
 * yalnız hafta sonu bir güne TIKLAYINCA görünüyordu (`lib/labels.ts` →
 * `no_service_day`). Cumartesi siteye giren biri o tıklamayı yapmadan da
 * "bugün yemek var mı" sorusunun cevabını görmeli; göremeyince siteyi
 * kapalı sanıp çıkıyor.
 *
 * SATIŞ KANALI KAPANMIYOR. Cumartesi pazartesinin menüsü sipariş
 * edilebiliyor (`docs/control/settings.md`, hafta sonu kuralı) ve bant bunu
 * AÇIKÇA söylüyor — "kapalıyız" deyip bırakmak, açık olan bir kanalı
 * kapalı göstermek olurdu. Sipariş alımının gerçekten durduğu hâli
 * `OrderingClosedBanner` anlatıyor; ikisi ayrı sorulardır.
 *
 * Günler `Location.service_weekdays`'ten (ISO 1-7) geliyor; `6` ve `7`
 * buraya GÖMÜLMEZ — hafta sonu servise açılırsa metin kendiliğinden
 * doğrulanır. Aynı gerekçe `day-picker.tsx` içinde de yazılı.
 */
export function ServiceDaysBanner({
  location,
  today,
}: {
  location: Location | null;
  today: number;
}) {
  const servis = location?.service_weekdays;

  // Sunucu alanı göndermiyorsa (eski sürüm) susuyoruz: uydurulmuş bir
  // "hafta içi çalışıyoruz" cümlesi, cumartesi servis veren bir işletmede
  // müşteriyi geri çevirirdi.
  if (!servis || servis.length === 0 || servis.length === 7) return null;

  const gunler = [...servis]
    .sort((a, b) => a - b)
    .map((g) => GUN_ADLARI[g])
    .filter((ad): ad is string => Boolean(ad));

  if (gunler.length === 0) return null;

  const bugunServis = servis.includes(today);

  const liste =
    gunler.length > 1
      ? `${gunler.slice(0, -1).join(', ')} ve ${gunler[gunler.length - 1]}`
      : gunler[0];

  return (
    <div
      role="status"
      className="rounded-card border border-info/40 bg-info-surface px-4 py-3 text-sm text-foreground"
    >
      <p className="font-semibold">
        {bugunServis ? `Yalnızca ${liste} yemek çıkarıyoruz` : 'Bugün yemek çıkarmıyoruz'}
      </p>
      <p className="mt-1 text-foreground">
        {bugunServis
          ? `Servis günlerimiz ${liste}.`
          : `Servis günlerimiz ${liste}; bugün servisimiz yok.`}{' '}
        Sipariş almaya devam ediyoruz — takvimden menü çıkan bir gün seçip şimdi
        sipariş verebilirsiniz.
      </p>
    </div>
  );
}
