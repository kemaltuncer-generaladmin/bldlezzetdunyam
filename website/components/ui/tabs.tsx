'use client';

import * as React from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { Tabs as TabsPrimitive } from 'radix-ui';

import { cn } from '@/lib/utils';

function Tabs({
  className,
  orientation = 'horizontal',
  ...props
}: React.ComponentProps<typeof TabsPrimitive.Root>) {
  return (
    <TabsPrimitive.Root
      data-slot="tabs"
      data-orientation={orientation}
      className={cn('group/tabs flex gap-4 data-horizontal:flex-col', className)}
      {...props}
    />
  );
}

/**
 * İki görünüm var ve ikisi farklı işler için:
 *
 * * `default` — sessiz yüzeye oturmuş segment kontrolü. Az sayıda, eşit
 *   ağırlıklı seçenek (2-4) için.
 * * `line` — altı çizgili sekme. Sayfa bölümleri gibi çok sayıda seçenek
 *   için; segment kontrolü altı sekmede kutu gibi görünüyor.
 */
const tabsListVariants = cva(
  'group/tabs-list inline-flex w-fit items-center justify-center text-muted-foreground group-data-vertical/tabs:h-fit group-data-vertical/tabs:flex-col',
  {
    variants: {
      variant: {
        default: 'rounded-sm bg-muted p-1',
        line: 'gap-1 rounded-none border-b border-border bg-transparent',
      },
    },
    defaultVariants: {
      variant: 'default',
    },
  },
);

function TabsList({
  className,
  variant = 'default',
  ...props
}: React.ComponentProps<typeof TabsPrimitive.List> & VariantProps<typeof tabsListVariants>) {
  return (
    <TabsPrimitive.List
      data-slot="tabs-list"
      data-variant={variant}
      className={cn(tabsListVariants({ variant }), className)}
      {...props}
    />
  );
}

/**
 * Yükseklik 44 px — sekme bir dokunma hedefi. Etkin sekmenin altındaki
 * çizgi (`line`) `after:` ile çiziliyor: kenarlıkla yapılsaydı etkin
 * olmayan sekmeler 2 px yukarı kayardı.
 */
function TabsTrigger({ className, ...props }: React.ComponentProps<typeof TabsPrimitive.Trigger>) {
  return (
    <TabsPrimitive.Trigger
      data-slot="tabs-trigger"
      className={cn(
        'relative inline-flex min-h-11 flex-1 items-center justify-center gap-2 rounded-xs px-3 text-label whitespace-nowrap text-muted-foreground',
        'transition-colors duration-(--duration-fast) group-data-vertical/tabs:w-full group-data-vertical/tabs:justify-start',
        'hover:text-foreground',
        'focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background focus-visible:outline-hidden',
        'disabled:pointer-events-none disabled:text-muted-foreground/60',
        'group-data-[variant=default]/tabs-list:data-active:bg-card group-data-[variant=default]/tabs-list:data-active:text-foreground group-data-[variant=default]/tabs-list:data-active:shadow-card',
        'group-data-[variant=line]/tabs-list:data-active:text-primary-text',
        'after:absolute after:bg-primary after:opacity-0 after:transition-opacity',
        'group-data-horizontal/tabs:after:inset-x-0 group-data-horizontal/tabs:after:-bottom-px group-data-horizontal/tabs:after:h-0.5',
        'group-data-vertical/tabs:after:inset-y-0 group-data-vertical/tabs:after:-right-px group-data-vertical/tabs:after:w-0.5',
        'group-data-[variant=line]/tabs-list:data-active:after:opacity-100',
        "[&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-5",
        className,
      )}
      {...props}
    />
  );
}

function TabsContent({ className, ...props }: React.ComponentProps<typeof TabsPrimitive.Content>) {
  return (
    <TabsPrimitive.Content
      data-slot="tabs-content"
      className={cn('flex-1 text-body outline-none', className)}
      {...props}
    />
  );
}

export { Tabs, TabsList, TabsTrigger, TabsContent, tabsListVariants };
