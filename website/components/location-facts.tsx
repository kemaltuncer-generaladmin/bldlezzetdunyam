import { EtaFactValue } from '@/components/delivery-eta';
import { IconCheck, IconClock, IconTruck, IconWallet } from '@/components/icons';
import { formatPrice } from '@/lib/format';
import { readLocationEta } from '@/lib/eta';
import { paymentMethodLabel } from '@/lib/labels';
import { cn } from '@/lib/utils';
import type { Location } from '@/lib/api/types';

type Fact = {
  key: string;
  icon: React.ReactNode;
  /** Metin değil düğüm: teslim tahmini duvar saatini tarayıcıda hesaplıyor. */
  value: React.ReactNode;
  label: string;
};

/**
 * Vitrinin sipariş koşulları: asgari sepet, teslimat ücreti, son sipariş saati,
 * ödeme yöntemleri. Hepsi `Location` sözleşmesinden gelir — hiçbiri sabit
 * yazılmaz, yönetici değeri değiştirdiğinde metin de değişir.
 */
export function LocationFacts({
  location,
  className,
}: {
  location: Location | null;
  className?: string;
}) {
  if (!location) return null;

  const facts: Fact[] = [
    {
      key: 'min',
      icon: <IconCheck className="h-4 w-4" />,
      label: 'Asgari sepet',
      value: location.min_order_total > 0 ? formatPrice(location.min_order_total) : 'Alt sınır yok',
    },
    {
      key: 'delivery',
      icon: <IconTruck className="h-4 w-4" />,
      label: 'Teslimat',
      value: location.delivery_fee > 0 ? formatPrice(location.delivery_fee) : 'Ücretsiz',
    },
  ];

  /*
   * Teslim süresi ücretin hemen ardında: müşteri "ne kadar tutar" ile "ne
   * zaman gelir" sorularını birlikte soruyor. İki teslim türü ayrı çip —
   * gel-al belirgin biçimde daha hızlı ve bu fark seçimi değiştiriyor.
   */
  const eta = readLocationEta(location);
  if (eta) {
    facts.push(
      {
        key: 'eta-delivery',
        icon: <IconClock className="h-4 w-4" />,
        label: 'Tahmini teslim',
        value: <EtaFactValue estimate={eta.delivery} />,
      },
      {
        key: 'eta-pickup',
        icon: <IconClock className="h-4 w-4" />,
        label: 'Gel-al hazır',
        value: <EtaFactValue estimate={eta.pickup} />,
      },
    );
  }

  if (location.order_cutoff) {
    facts.push({
      key: 'cutoff',
      icon: <IconClock className="h-4 w-4" />,
      label: 'Son sipariş',
      value: location.order_cutoff,
    });
  }

  if (location.payment_methods.length > 0) {
    facts.push({
      key: 'payment',
      icon: <IconWallet className="h-4 w-4" />,
      label: 'Ödeme',
      value: location.payment_methods.map(paymentMethodLabel).join(' · '),
    });
  }

  /*
   * Çipler kendi renklerini taşır, kapsayıcıdan miras ALMAZ.
   *
   * Bileşen artık koyu, fotoğraflı bir bandın içinde de kullanılıyor. `dd`
   * kendi rengini vermediğinde banttan `text-cream` miras alıyor ve beyaz
   * çipin üzerinde okunmaz hâle geliyordu — asgari sepet tutarı ekranda
   * görünmüyordu.
   */
  return (
    <dl className={cn('flex flex-wrap gap-2', className)}>
      {facts.map((fact) => (
        <div
          key={fact.key}
          className="flex items-center gap-2 rounded-full border border-neutral-200 bg-neutral-0 px-3 py-1.5 text-sm text-neutral-900 shadow-xs"
        >
          <span className="text-brand-700">{fact.icon}</span>
          <dt className="text-neutral-600">{fact.label}:</dt>
          <dd className="font-semibold text-neutral-900">{fact.value}</dd>
        </div>
      ))}
    </dl>
  );
}
