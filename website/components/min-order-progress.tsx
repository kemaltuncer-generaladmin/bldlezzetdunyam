import { formatPrice } from '@/lib/format';
import { cn } from '@/lib/utils';

type Props = {
  subtotal: number;
  /** `Location.min_order_total` — 0 ise alt sınır yok, bileşen çizilmez. */
  minOrderTotal: number;
  className?: string;
};

/**
 * "Asgari sepet tutarına ne kadar kaldı" şeridi. Sepet kutusu ve sepet
 * sayfası aynı hesabı iki yerde yapmasın diye tek bileşen.
 *
 * Tutarlar kuruş tamsayısıdır; yüzde hesabı yalnızca çubuğun genişliği için
 * kullanılır, gösterilen paralar `formatPrice` ile biçimlenir.
 */
export function MinOrderProgress({ subtotal, minOrderTotal, className }: Props) {
  if (minOrderTotal <= 0) return null;

  const remaining = Math.max(0, minOrderTotal - subtotal);
  const reached = remaining === 0;
  const percent = reached ? 100 : Math.min(100, Math.round((subtotal / minOrderTotal) * 100));

  return (
    <div className={cn(className)}>
      <div
        role="progressbar"
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={percent}
        aria-label="Asgari sepet tutarına ilerleme"
        className="h-1.5 w-full overflow-hidden rounded-full bg-muted"
      >
        <div
          className={cn('h-full transition-[width]', reached ? 'bg-success' : 'bg-primary')}
          style={{ width: `${percent}%` }}
        />
      </div>
      <p className={cn('mt-1.5 text-xs', reached ? 'text-muted-foreground' : 'text-foreground')}>
        {reached
          ? `Asgari sepet tutarı (${formatPrice(minOrderTotal)}) karşılandı.`
          : `Asgari sepet tutarına ${formatPrice(remaining)} kaldı.`}
      </p>
    </div>
  );
}
