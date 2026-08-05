import { IconCheck, IconClock, IconTruck, IconWallet } from '@/components/icons';
import { formatPrice } from '@/lib/format';
import { paymentMethodLabel } from '@/lib/labels';
import { cn } from '@/lib/cn';
import type { Location } from '@/lib/api/types';

type Fact = {
  key: string;
  icon: React.ReactNode;
  label: string;
  value: string;
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

  return (
    <dl className={cn('flex flex-wrap gap-2', className)}>
      {facts.map((fact) => (
        <div
          key={fact.key}
          className="flex items-center gap-2 rounded-full border border-neutral-200 bg-neutral-0 px-3 py-1.5 text-sm shadow-sm"
        >
          <span className="text-brand-700">{fact.icon}</span>
          <dt className="text-neutral-600">{fact.label}:</dt>
          <dd className="font-semibold">{fact.value}</dd>
        </div>
      ))}
    </dl>
  );
}
