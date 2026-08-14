import * as React from 'react';
import { cva, type VariantProps } from 'class-variance-authority';

import { cn } from '@/lib/utils';

/**
 * Satır içi bildirim.
 *
 * ## `role` prop olarak geliyor, sabit değil
 *
 * Üst kaynak her `Alert`'e `role="alert"` basıyordu. `role="alert"` ekran
 * okuyucuyu KESER: kullanıcı ne okuyorsa okusun, metin araya girer. Bu
 * yalnızca hata için doğru. Bilgi kutusu bunu yaptığında sayfayı okumak
 * imkânsız hâle geliyor, çevrimdışı uyarısı ise `role="status"` olmalı
 * (kibar sıra: kullanıcı cümlesini bitirsin, sonra duyulsun).
 *
 * Varsayılan `undefined` — yani hiçbir rol. Bilinçli: rol bir karardır,
 * varsayılan olamaz.
 *
 * ## Tonlar tint + METİN adımı
 *
 * Dolu renkli uyarı kutusu sayfadaki tek primary butondan daha güçlü
 * okunuyordu. Zemin `*-surface`, yazı aynı ailenin metin adımı; ikisinin
 * kontrastı `tokens.css`'te ölçüldü.
 */
const alertVariants = cva(
  [
    'group/alert relative grid w-full gap-1 rounded-md border px-4 py-3 text-left text-body',
    'has-data-[slot=alert-action]:pr-16',
    'has-[>svg]:grid-cols-[auto_1fr] has-[>svg]:gap-x-3',
    '*:[svg]:row-span-2 *:[svg]:translate-y-0.5 *:[svg]:text-current',
    "*:[svg:not([class*='size-'])]:size-5",
  ],
  {
    variants: {
      variant: {
        default: 'border-border bg-card text-card-foreground',
        info: 'border-transparent bg-info-surface text-info-foreground',
        success: 'border-transparent bg-success-surface text-success-foreground',
        warning: 'border-transparent bg-warning-surface text-warning-foreground',
        destructive: 'border-transparent bg-danger-surface text-danger-foreground',
      },
    },
    defaultVariants: {
      variant: 'default',
    },
  },
);

function Alert({
  className,
  variant,
  ...props
}: React.ComponentProps<'div'> & VariantProps<typeof alertVariants>) {
  return <div data-slot="alert" className={cn(alertVariants({ variant }), className)} {...props} />;
}

function AlertTitle({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="alert-title"
      className={cn(
        'text-label group-has-[>svg]/alert:col-start-2 [&_a]:underline [&_a]:underline-offset-4',
        className,
      )}
      {...props}
    />
  );
}

/**
 * Açıklama rengi bilinçli olarak `--muted-foreground` DEĞİL.
 *
 * Tint zeminlerin üzerinde nötr gri, ölçülen kontrastın dışına çıkıyordu.
 * `currentColor`ın %90'ı hem tonu koruyor hem başlıktan bir adım geriye
 * düşüyor.
 */
function AlertDescription({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="alert-description"
      className={cn(
        'text-body text-pretty text-current/90 [&_a]:underline [&_a]:underline-offset-4 [&_p:not(:last-child)]:mb-3',
        className,
      )}
      {...props}
    />
  );
}

function AlertAction({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div data-slot="alert-action" className={cn('absolute top-2 right-2', className)} {...props} />
  );
}

export { Alert, AlertTitle, AlertDescription, AlertAction };
