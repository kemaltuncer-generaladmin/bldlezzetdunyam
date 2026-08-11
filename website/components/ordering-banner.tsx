import type { Location } from '@/lib/api/types';

/**
 * `ordering_enabled=false` veya `is_open=false` iken gösterilen bant.
 * Menü **gizlenmez** — yalnızca sepete ekleme ve ödeme engellenir
 * (`docs/06` §3).
 */
export function OrderingClosedBanner({ location }: { location: Location | null }) {
  if (!location) return null;
  if (location.is_open && location.ordering_enabled) return null;

  // SEBEP SUNUCUDAN GELİYORSA ONU KULLAN (K-11). "Sipariş alımı geçici
  // olarak durduruldu" tek başına müşteriyi tekrar tekrar denemeye itiyor;
  // "fırın arızalandı, 19:30'da açılıyoruz" beklemeyi bilinçli kılıyor.
  const reason = !location.ordering_enabled
    ? (location.ordering_pause_reason ??
       'Sipariş alımı geçici olarak durduruldu.')
    : 'Şu an sipariş saatleri dışındayız.';

  const resumesAt = location.ordering_resumes_at
    ? new Date(location.ordering_resumes_at)
    : null;

  // Süresiz durdurmada saat YAZILMAZ: uydurulmuş bir saat, gelmeyen bir
  // açılışı beklettirir.
  const resumeNote =
    resumesAt && !Number.isNaN(resumesAt.getTime())
      ? ` Tahmini yeniden açılış: ${resumesAt.toLocaleTimeString('tr-TR', {
          hour: '2-digit',
          minute: '2-digit',
        })}.`
      : '';

  const cutoffNote = location.order_cutoff
    ? ` Günlük son sipariş saatimiz ${location.order_cutoff}.`
    : '';

  return (
    <div
      role="status"
      className="rounded-card border border-warning/40 bg-warning/10 px-4 py-3 text-sm text-neutral-900"
    >
      <p className="font-semibold">Şu anda sipariş alamıyoruz</p>
      <p className="mt-1 text-neutral-800">
        {reason}
        {resumeNote}
        {cutoffNote} Menüyü inceleyebilirsiniz; sipariş alımı açıldığında sepetinize
        ekleyebilirsiniz.
      </p>
    </div>
  );
}
