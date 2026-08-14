'use client';

import * as React from 'react';
import { Accordion as AccordionPrimitive } from 'radix-ui';

import { cn } from '@/lib/utils';
import { ChevronDownIcon } from 'lucide-react';

function Accordion({ className, ...props }: React.ComponentProps<typeof AccordionPrimitive.Root>) {
  return (
    <AccordionPrimitive.Root
      data-slot="accordion"
      className={cn('flex w-full flex-col', className)}
      {...props}
    />
  );
}

function AccordionItem({
  className,
  ...props
}: React.ComponentProps<typeof AccordionPrimitive.Item>) {
  return (
    <AccordionPrimitive.Item
      data-slot="accordion-item"
      className={cn('not-last:border-b', className)}
      {...props}
    />
  );
}

/**
 * Başlık satırı 44 px dokunma hedefi.
 *
 * Ok TEK ikon ve dönüyor; üst kaynak iki ayrı ikonu (aşağı/yukarı)
 * gizleyip gösteriyordu — geçiş anında ikon zıplıyordu, dönüş ise sürekli.
 *
 * `hover:underline` KALDIRILDI: soru metninin altını çizmek onu bağlantı
 * gibi gösteriyor ve tıklanınca sayfa değişmediği için kullanıcı şaşırıyor.
 * Hover geri bildirimi zemin tonuyla veriliyor.
 */
function AccordionTrigger({
  className,
  children,
  ...props
}: React.ComponentProps<typeof AccordionPrimitive.Trigger>) {
  return (
    <AccordionPrimitive.Header className="flex">
      <AccordionPrimitive.Trigger
        data-slot="accordion-trigger"
        className={cn(
          'group/accordion-trigger relative flex min-h-11 flex-1 items-center justify-between gap-4 rounded-xs py-3 text-left text-body-lg font-semibold text-foreground',
          'transition-colors duration-(--duration-fast) outline-none hover:text-primary-text',
          'focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background',
          'disabled:pointer-events-none disabled:text-muted-foreground',
          className,
        )}
        {...props}
      >
        {children}
        <ChevronDownIcon
          aria-hidden="true"
          strokeWidth={1.75}
          className="size-5 shrink-0 text-muted-foreground transition-transform duration-(--duration-base) ease-(--ease-out-soft) group-aria-expanded/accordion-trigger:rotate-180"
        />
      </AccordionPrimitive.Trigger>
    </AccordionPrimitive.Header>
  );
}

function AccordionContent({
  className,
  children,
  ...props
}: React.ComponentProps<typeof AccordionPrimitive.Content>) {
  return (
    <AccordionPrimitive.Content
      data-slot="accordion-content"
      className="overflow-hidden text-body data-open:animate-accordion-down data-closed:animate-accordion-up"
      {...props}
    >
      <div
        className={cn(
          'h-(--radix-accordion-content-height) pt-0 pb-4 text-muted-foreground [&_a]:underline [&_a]:underline-offset-4 [&_p:not(:last-child)]:mb-3',
          className,
        )}
      >
        {children}
      </div>
    </AccordionPrimitive.Content>
  );
}

export { Accordion, AccordionItem, AccordionTrigger, AccordionContent };
