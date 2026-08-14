import { EtaFactValue } from '@/components/delivery-eta';
import { IconCheck, IconClock, IconTruck, IconWallet } from '@/components/icons';
import { formatPrice } from '@/lib/format';
import { readLocationEta } from '@/lib/eta';
import { paymentMethodLabel } from '@/lib/labels';
import { cn } from '@/lib/utils';
import { isOfferedPaymentMethod } from '@/lib/validation/checkout';
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

  /*
   * `account` SÜZÜLÜYOR (B-19) — ödeme adımıyla AYNI süzgeç.
   *
   * Vitrinde cari açık olabilir ama site onu sunmuyor; çipte "Cari hesap"
   * yazıp ödeme adımında listelememek, müşteriye menü sayfasında söz verip
   * onay adımında geri almak olurdu.
   */
  const offeredMethods = location.payment_methods.filter(isOfferedPaymentMethod);
  if (offeredMethods.length > 0) {
    facts.push({
      key: 'payment',
      icon: <IconWallet className="h-4 w-4" />,
      label: 'Ödeme',
      value: offeredMethods.map(paymentMethodLabel).join(' · '),
    });
  }

  /*
   * Çipler kendi renklerini taşır, kapsayıcıdan miras ALMAZ.
   *
   * Bileşen artık koyu, fotoğraflı bir bandın içinde de kullanılıyor. `dd`
   * kendi rengini vermediğinde banttan `text-neutral-50` miras alıyor ve
   * beyaz çipin üzerinde okunmaz hâle geliyordu — asgari sepet tutarı
   * ekranda görünmüyordu.
   */
  return (
    <dl className={cn('flex flex-wrap gap-2', className)}>
      {facts.map((fact) => (
        <div
          key={fact.key}
          className="flex items-center gap-2 rounded-full border border-border bg-card px-3 py-1.5 text-body-sm text-foreground shadow-card"
        >
          <span className="text-primary-text">{fact.icon}</span>
          <dt className="text-muted-foreground">{fact.label}:</dt>
          {/*
            `tabular-nums` var, `bld-money` YOK: çiplerin bir kısmı para
            (asgari sepet, teslimat ücreti) ama bir kısmı ödeme yöntemi
            listesi. Kısayolun getirdiği `white-space: nowrap` o listeyi dar
            ekranda taşırırdı; rakam hizası ise her değerde doğru.
          */}
          <dd className="font-semibold text-foreground tabular-nums">{fact.value}</dd>
        </div>
      ))}
    </dl>
  );
}
