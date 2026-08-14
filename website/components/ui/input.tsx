import * as React from 'react';

import { cn } from '@/lib/utils';

/**
 * Metin alanı.
 *
 * ## Kenarlık `--input`, `--border` DEĞİL
 *
 * İkisi eskiden aynı gri idi ve form alanının kenarı kart beyazı üstünde
 * 1,38:1 ediyordu — WCAG 1.4.11 kontrol bileşenleri için 3:1 istiyor.
 * `--border` artık DEKORATİF (ayraç), `--input` İŞLEVSEL (kontrol kenarı,
 * neutral400 → 3,26:1).
 *
 * ## Yazı boyu 17 px, 15 değil
 *
 * iOS Safari 16 px'in altındaki bir alana odaklanınca sayfayı ZOOMLUYOR ve
 * kullanıcı formu bitirdiğinde kaydırılmış bir sayfada kalıyor. Gövde
 * ölçeğimiz 15 px olduğu için mobilde bir adım yukarı çıkılıyor
 * (`text-body-lg`), masaüstünde ölçeğe dönülüyor.
 *
 * Yükseklik 44 px: dokunma hedefi alt sınırı (docs/06 §5).
 */
function Input({ className, type, ...props }: React.ComponentProps<'input'>) {
  return (
    <input
      type={type}
      data-slot="input"
      className={cn(
        'h-11 w-full min-w-0 rounded-sm border border-input bg-card px-3 py-2 text-body-lg text-foreground md:text-body',
        'transition-colors duration-(--duration-fast) outline-none placeholder:text-placeholder',
        'file:inline-flex file:h-8 file:border-0 file:bg-transparent file:text-body-sm file:font-semibold file:text-foreground',
        'focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background',
        'disabled:cursor-not-allowed disabled:bg-muted disabled:text-muted-foreground',
        'aria-invalid:border-danger aria-invalid:bg-danger-surface',
        className,
      )}
      {...props}
    />
  );
}

export { Input };
