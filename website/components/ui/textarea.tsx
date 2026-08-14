import * as React from 'react';

import { cn } from '@/lib/utils';

/**
 * Çok satırlı alan. Kenarlık, odak halkası ve yazı boyu gerekçeleri
 * `input.tsx` ile aynı — orada yazılı, burada tekrarlanmıyor.
 *
 * `field-sizing-content`: alan yazıldıkça büyür. Sabit yükseklikte bir
 * `textarea` uzun bir sipariş notunda kendi içinde kayıyor ve kullanıcı
 * yazdığının tamamını göremiyor.
 */
function Textarea({ className, ...props }: React.ComponentProps<'textarea'>) {
  return (
    <textarea
      data-slot="textarea"
      className={cn(
        'flex field-sizing-content min-h-24 w-full rounded-sm border border-input bg-card px-3 py-2.5 text-body-lg text-foreground md:text-body',
        'transition-colors duration-(--duration-fast) outline-none placeholder:text-placeholder',
        'focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background',
        'disabled:cursor-not-allowed disabled:bg-muted disabled:text-muted-foreground',
        'aria-invalid:border-danger aria-invalid:bg-danger-surface',
        className,
      )}
      {...props}
    />
  );
}

export { Textarea };
