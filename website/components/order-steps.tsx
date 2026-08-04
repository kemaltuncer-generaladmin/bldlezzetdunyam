import { cn } from '@/lib/cn';
import type { DeliveryType, OrderStatus } from '@/lib/api/types';

/**
 * Adım çubuğu (`docs/06` §4). `pickup` siparişte `Yolda` adımı **gösterilmez**:
 * `Hazır` → `Teslim edildi`.
 */
const BASE_FLOW: { status: OrderStatus; label: string }[] = [
  { status: 'yeni', label: 'Alındı' },
  { status: 'onaylandi', label: 'Onaylandı' },
  { status: 'hazirlaniyor', label: 'Hazırlanıyor' },
  { status: 'hazir', label: 'Hazır' },
  { status: 'yolda', label: 'Yolda' },
  { status: 'teslim_edildi', label: 'Teslim edildi' },
];

export function orderFlow(deliveryType: DeliveryType): { status: OrderStatus; label: string }[] {
  return deliveryType === 'pickup'
    ? BASE_FLOW.filter((step) => step.status !== 'yolda')
    : BASE_FLOW;
}

type Props = {
  status: string;
  deliveryType: DeliveryType;
};

export function OrderSteps({ status, deliveryType }: Props) {
  if (status === 'iptal') {
    return (
      <p role="status" className="rounded-card bg-danger/10 px-4 py-3 text-sm font-medium text-danger">
        Bu sipariş iptal edildi.
      </p>
    );
  }

  const flow = orderFlow(deliveryType);
  const currentIndex = flow.findIndex((step) => step.status === status);

  return (
    <ol
      className="flex flex-wrap gap-x-2 gap-y-3 sm:flex-nowrap sm:items-start"
      aria-label="Sipariş durumu"
    >
      {flow.map((step, index) => {
        const done = currentIndex > index;
        const active = currentIndex === index;
        const state = done ? 'Tamamlandı' : active ? 'Şu anki adım' : 'Bekliyor';

        return (
          <li
            key={step.status}
            aria-current={active ? 'step' : undefined}
            className="flex min-w-[4.5rem] flex-1 flex-col items-center gap-1.5 text-center"
          >
            <div className="flex w-full items-center">
              <span
                aria-hidden="true"
                className={cn(
                  'h-0.5 flex-1',
                  index === 0 ? 'bg-transparent' : done || active ? 'bg-brand-500' : 'bg-neutral-200',
                )}
              />
              <span
                aria-hidden="true"
                className={cn(
                  'grid h-7 w-7 shrink-0 place-items-center rounded-full border-2 text-xs font-bold',
                  done && 'border-brand-500 bg-brand-500 text-neutral-0',
                  active && 'border-brand-500 bg-neutral-0 text-brand-700',
                  !done && !active && 'border-neutral-200 bg-neutral-0 text-neutral-400',
                )}
              >
                {done ? '✓' : active ? '●' : index + 1}
              </span>
              <span
                aria-hidden="true"
                className={cn(
                  'h-0.5 flex-1',
                  index === flow.length - 1 ? 'bg-transparent' : done ? 'bg-brand-500' : 'bg-neutral-200',
                )}
              />
            </div>
            <span
              className={cn(
                'text-xs leading-tight',
                active ? 'font-semibold text-neutral-900' : 'text-neutral-600',
              )}
            >
              {step.label}
            </span>
            <span className="sr-only">{state}</span>
          </li>
        );
      })}
    </ol>
  );
}
