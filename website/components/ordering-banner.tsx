import { busyNotice } from '@/lib/api/catalog';
import type { Location } from '@/lib/api/types';

/**
 * `ordering_enabled=false` veya `is_open=false` iken gösterilen bant.
 * Menü **gizlenmez** — yalnızca sepete ekleme ve ödeme engellenir
 * (`docs/06` §3).
 */
export function OrderingClosedBanner({ location }: { location: Location | null }) {
  if (!location) return null;
  if (location.is_open && location.ordering_enabled) return null;

  const reason = !location.ordering_enabled
    ? 'Sipariş alımı yönetici tarafından geçici olarak durduruldu.'
    : 'Şu an sipariş saatleri dışındayız.';

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
        {cutoffNote} Menüyü inceleyebilirsiniz; sipariş alımı açıldığında sepetinize
        ekleyebilirsiniz.
      </p>
    </div>
  );
}

/**
 * Mutfak yoğunken gösterilen bant.
 *
 * [OrderingClosedBanner] ile KARIŞTIRILMAMALI: bu bant sipariş almayı
 * engellemez, yalnızca gecikme uyarısıdır. Sipariş düğmeleri açık kalır.
 *
 * Metin sunucudan gelir; buraya sabit metin yazmak, yönetici admin
 * panelden değiştirdiğinde siteyi yeniden yayınlamayı gerektirirdi.
 */
export function KitchenBusyBanner({ location }: { location: Location | null }) {
  const notice = busyNotice(location);
  if (!notice) return null;

  return (
    <div
      role="status"
      className="rounded-card border border-brand-600/40 bg-brand-50 px-4 py-3 text-sm text-neutral-900"
    >
      <p className="font-semibold">Mutfağımız yoğun</p>
      <p className="mt-1 text-neutral-800">{notice}</p>
    </div>
  );
}
