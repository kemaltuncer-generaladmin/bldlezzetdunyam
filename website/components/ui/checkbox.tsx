'use client';

import * as React from 'react';
import { Checkbox as CheckboxPrimitive } from 'radix-ui';

import { cn } from '@/lib/utils';
import { CheckIcon } from 'lucide-react';

/**
 * Onay kutusu.
 *
 * Kutunun kendisi 20 px çiziliyor ama `after:` ile görünmez bir 44 px'lik
 * dokunma alanı taşıyor: 20 px'lik bir hedefi parmakla vurmak neredeyse
 * imkânsız, kutuyu 44 px büyütmek ise satır yüksekliğini bozuyor.
 *
 * Kenarlık `--input` (İŞLEVSEL, 3,26:1) — dekoratif `--border` bu eşiği
 * geçmiyor ve onay kutusu bir kontrol.
 */
function Checkbox({ className, ...props }: React.ComponentProps<typeof CheckboxPrimitive.Root>) {
  return (
    <CheckboxPrimitive.Root
      data-slot="checkbox"
      className={cn(
        'peer relative flex size-5 shrink-0 items-center justify-center rounded-xs border border-input bg-card',
        'transition-colors duration-(--duration-fast) outline-none',
        'after:absolute after:size-11 after:content-[""]',
        'focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background',
        'group-has-disabled/field:opacity-60 disabled:cursor-not-allowed disabled:bg-muted disabled:opacity-60',
        'aria-invalid:border-danger',
        'data-checked:border-primary data-checked:bg-primary data-checked:text-primary-foreground',
        className,
      )}
      {...props}
    >
      <CheckboxPrimitive.Indicator
        data-slot="checkbox-indicator"
        className="grid place-content-center text-current [&>svg]:size-4"
      >
        <CheckIcon strokeWidth={2.5} />
      </CheckboxPrimitive.Indicator>
    </CheckboxPrimitive.Root>
  );
}

export { Checkbox };
