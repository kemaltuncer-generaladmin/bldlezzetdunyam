import * as React from 'react';

import { cn } from '@/lib/utils';

/**
 * Kart.
 *
 * ## Yükseltme AÇIK temada gölge, KOYU temada açıklıktır
 *
 * shadcn'in üst kaynağı kartı `ring-1 ring-foreground/10` ile çiziyordu:
 * saydam bir çizgi, her zeminde başka bir renk veriyor ve koyu temada
 * kartın kenarını kaybediyordu. Burada açık temada `shadow-card`
 * (0 1px 2px + 0 6px 16px, sıcak-koyu kahve gölge), koyu temada gölge
 * KAPALI ve ayrım `--card`ın zeminden bir adım açık olmasından geliyor —
 * karanlıkta gölge görünmez, açıklık görünür. `inset` hairline kartın üst
 * kenarını karanlıkta da ayırıyor.
 *
 * Yarıçap `md` (14 px) — marka ölçeğinde kart/liste satırı/görsel adımı.
 */
function Card({
  className,
  size = 'default',
  ...props
}: React.ComponentProps<'div'> & { size?: 'default' | 'sm' }) {
  return (
    <div
      data-slot="card"
      data-size={size}
      className={cn(
        'group/card flex flex-col gap-(--card-spacing) overflow-hidden rounded-md bg-card py-(--card-spacing) text-body text-card-foreground',
        'shadow-card dark:shadow-none dark:inset-ring dark:inset-ring-white/5',
        '[--card-spacing:--spacing(5)] data-[size=sm]:[--card-spacing:--spacing(4)]',
        'has-data-[slot=card-footer]:pb-0 has-[>img:first-child]:pt-0',
        '*:[img:first-child]:rounded-t-md *:[img:last-child]:rounded-b-md',
        className,
      )}
      {...props}
    />
  );
}

function CardHeader({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="card-header"
      className={cn(
        'group/card-header @container/card-header grid auto-rows-min items-start gap-1 px-(--card-spacing) has-data-[slot=card-action]:grid-cols-[1fr_auto] has-data-[slot=card-description]:grid-rows-[auto_auto] [.border-b]:pb-(--card-spacing)',
        className,
      )}
      {...props}
    />
  );
}

/**
 * Kart başlığı — SERİF aile, `title` adımı (17 px).
 *
 * Renk `--heading` (marka kahvesi) DEĞİL, `--card-foreground`: kart başlığı
 * sayfa başlığı değil, bir nesnenin adı. Marka kahvesini her kart başlığına
 * yaymak sayfadaki hiyerarşiyi düzleştiriyordu.
 */
function CardTitle({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="card-title"
      className={cn(
        'font-display text-title font-semibold group-data-[size=sm]/card:text-body-lg',
        className,
      )}
      {...props}
    />
  );
}

function CardDescription({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="card-description"
      className={cn('text-body-sm text-muted-foreground', className)}
      {...props}
    />
  );
}

function CardAction({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="card-action"
      className={cn('col-start-2 row-span-2 row-start-1 self-start justify-self-end', className)}
      {...props}
    />
  );
}

function CardContent({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div data-slot="card-content" className={cn('px-(--card-spacing)', className)} {...props} />
  );
}

function CardFooter({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="card-footer"
      className={cn(
        'flex items-center rounded-b-md border-t bg-muted/60 p-(--card-spacing)',
        className,
      )}
      {...props}
    />
  );
}

export { Card, CardHeader, CardFooter, CardTitle, CardAction, CardDescription, CardContent };
