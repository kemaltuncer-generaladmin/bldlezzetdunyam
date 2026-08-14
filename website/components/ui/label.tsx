'use client';

import * as React from 'react';
import { Label as LabelPrimitive } from 'radix-ui';

import { cn } from '@/lib/utils';

/**
 * Alan etiketi — HER ZAMAN alanın ÜSTÜNDE.
 *
 * Floating label (alanın içinde başlayıp odakta yukarı kayan etiket)
 * BİLİNÇLİ OLARAK YOK: Türkçe etiketler uzun ("Fatura adresi il/ilçe") ve
 * daralınca kırpılıyor; ayrıca tarayıcı otomatik doldurması alanı etiket
 * animasyonunu tetiklemeden doldurup iki metni üst üste bindiriyor.
 *
 * Zorunlu alan yıldızı `aria-hidden`: zorunluluk ekran okuyucuya alandaki
 * `aria-required` ile söylenir, yıldızın ikinci kez okunması gürültü olur.
 * Zorunluluk YALNIZ renkle anlatılmaz (1.4.1).
 */
function Label({
  className,
  required = false,
  children,
  ...props
}: React.ComponentProps<typeof LabelPrimitive.Root> & { required?: boolean }) {
  return (
    <LabelPrimitive.Root
      data-slot="label"
      className={cn(
        'flex items-center gap-1 text-label text-foreground select-none',
        'group-data-[disabled=true]:pointer-events-none group-data-[disabled=true]:opacity-60 peer-disabled:cursor-not-allowed peer-disabled:opacity-60',
        className,
      )}
      {...props}
    >
      {children}
      {required && (
        <span aria-hidden="true" className="text-danger">
          *
        </span>
      )}
    </LabelPrimitive.Root>
  );
}

export { Label };
