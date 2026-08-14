import * as React from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { Slot } from 'radix-ui';

import { cn } from '@/lib/utils';

/**
 * Rozet — durum etiketi, dokunma hedefi değil.
 *
 * Yarıçap `xs` (6 px): marka ölçeğinde rozet adımı. Üst kaynak `rounded-4xl`
 * ile hap biçimindeydi; hap yarıçapı bu dilde ÇİP'e ait (seçilebilir,
 * dokunulabilir öğe). Rozet ile çip görsel olarak ayrılmazsa kullanıcı
 * rozete tıklamayı deniyor.
 *
 * Renkler tint + aynı ailenin METİN adımı: dolu renkli rozetler (beyaz yazı)
 * listede primary butondan daha çok bağırıyordu. `default` bunun tek
 * istisnası — "yeni", "kampanya" gibi gerçekten öne çıkması gereken tek
 * rozet için.
 */
const badgeVariants = cva(
  [
    'group/badge inline-flex w-fit shrink-0 items-center justify-center gap-1 overflow-hidden',
    'rounded-xs border border-transparent px-2 py-0.5 text-caption font-semibold whitespace-nowrap',
    'focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background',
    '[&>svg]:pointer-events-none [&>svg]:size-4',
  ],
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground',
        secondary: 'bg-secondary text-secondary-foreground',
        outline: 'border-border text-muted-foreground',
        success: 'bg-success-surface text-success-foreground',
        warning: 'bg-warning-surface text-warning-foreground',
        destructive: 'bg-danger-surface text-danger-foreground',
        info: 'bg-info-surface text-info-foreground',
      },
    },
    defaultVariants: {
      variant: 'default',
    },
  },
);

function Badge({
  className,
  variant = 'default',
  asChild = false,
  ...props
}: React.ComponentProps<'span'> & VariantProps<typeof badgeVariants> & { asChild?: boolean }) {
  const Comp = asChild ? Slot.Root : 'span';

  return (
    <Comp
      data-slot="badge"
      data-variant={variant}
      className={cn(badgeVariants({ variant }), className)}
      {...props}
    />
  );
}

export { Badge, badgeVariants };
