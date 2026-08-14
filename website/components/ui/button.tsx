import * as React from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { Slot } from 'radix-ui';

import { cn } from '@/lib/utils';

/**
 * Buton hiyerarşisi TAM BEŞ basamaktır ve bu liste kapalıdır:
 *
 * | variant       | rol     | görünüm                                   |
 * |---------------|---------|-------------------------------------------|
 * | `default`     | Primary | brand700 dolgu + beyaz yazı               |
 * | `secondary`   | Tonal   | brand50 dolgu + brand800 yazı             |
 * | `outline`     | Outline | şeffaf + İŞLEVSEL kenarlık (neutral400)   |
 * | `ghost`       | Ghost   | şeffaf + brand700 yazı                    |
 * | `link`        | Link    | altı çizili metin                         |
 *
 * `destructive` altıncı bir basamak DEĞİL, Primary'nin yıkıcı eşleniğidir:
 * yalnızca onay diyaloğunda kullanılır. Yerinde yıkıcı eylem (satır silme
 * gibi) `ghost` + `text-danger` ile yazılır — dolu kırmızı bir buton listede
 * göze primary'den daha çok batıyor ve yanlışlıkla tıklanıyor.
 *
 * **Görünüm başına TEK primary.** İkinci eylem `secondary`ye düşer.
 *
 * ## Odak halkası
 *
 * Her iki temada 2px halka + 2px offset, offset rengi zemin. shadcn'in
 * varsayılanı `ring-3 ring-ring/50` idi: yarı saydam ve offsetsiz olduğu için
 * halka butonun kendi dolgusuna karışıyordu ve koyu temada neredeyse
 * görünmüyordu. Hover ile odak birlikte çizilmez — `focus-visible` sırasında
 * renk değişimi yok, yalnızca halka.
 *
 * ## Dokunma hedefi
 *
 * `default` 44 px (docs/06 §5 alt sınırı). `sm` ve `xs` bunun ALTINDA kalır ve
 * yalnızca dokunma hedefi olmayan yerlerde (kart içi metin bağlantısı, rozet
 * yanı) kullanılır.
 */
const buttonVariants = cva(
  [
    'group/button inline-flex shrink-0 cursor-pointer items-center justify-center gap-2',
    'rounded-sm border border-transparent bg-clip-padding font-semibold whitespace-nowrap select-none',
    'transition-colors duration-(--duration-fast) ease-(--ease-out-soft) outline-none',
    'focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background',
    // Devre dışı buton tıklanamaz ama imleç ve ton bunu SÖYLER. `opacity-50`
    // yerine gerçek sessiz yüzey: yarı saydam bir buton, altındaki zemine
    // göre her ekranda başka bir renk oluyordu.
    'disabled:pointer-events-none disabled:border-transparent disabled:bg-muted disabled:text-muted-foreground disabled:shadow-none',
    'aria-invalid:ring-2 aria-invalid:ring-danger',
    "[&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-5",
  ],
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground hover:bg-primary-hover',
        secondary: 'bg-secondary text-secondary-foreground hover:bg-brand-100 dark:hover:bg-accent',
        outline:
          'border-input bg-transparent text-foreground hover:bg-accent hover:text-accent-foreground',
        ghost: 'bg-transparent text-primary-text hover:bg-accent hover:text-accent-foreground',
        link: 'text-link underline underline-offset-4 hover:no-underline',
        // Koyu temada `--destructive` açık bir dolgu (danger300); hover ADIMI
        // bu yüzden ters yönde çalışır — açık temada koyulaşır, koyu temada
        // açılır. Palette danger200 olmadığı için koyu tema adımı karışımla
        // üretiliyor.
        destructive: [
          'bg-destructive text-destructive-foreground hover:bg-danger-700',
          'dark:hover:bg-[color-mix(in_oklch,var(--destructive),white_14%)]',
        ].join(' '),
      },
      size: {
        default: 'h-11 px-4 text-label',
        // 44 px ALTINDA — yalnız dokunmayla kullanılmayan yerlerde.
        xs: "h-7 gap-1 rounded-xs px-2 text-caption [&_svg:not([class*='size-'])]:size-4",
        sm: "h-9 gap-1.5 px-3 text-body-sm [&_svg:not([class*='size-'])]:size-4",
        lg: 'h-12 px-6 text-body',
        icon: 'size-11',
        'icon-xs': "size-7 rounded-xs [&_svg:not([class*='size-'])]:size-4",
        'icon-sm': "size-9 [&_svg:not([class*='size-'])]:size-4",
        'icon-lg': "size-12 [&_svg:not([class*='size-'])]:size-6",
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  },
);

/**
 * ## `disabledReason` TİP DÜZEYİNDE ZORUNLU
 *
 * Marka kılavuzunun kuralı: *"Devre dışı buton HER ZAMAN bir sebep metniyle
 * birlikte."* Kapalı bir buton, sebebi söylenmediğinde kullanıcı için bozuk
 * bir butondur — deniyor, tepki alamıyor, neden olmadığını bilmiyor. Bu, bir
 * inceleme sırasında yakalanacak bir şey değil: gözden kaçması çok kolay ve
 * kaçtığında kimse fark etmiyor.
 *
 * Bu yüzden kural yoruma değil TİPE yazıldı. Ayrık birleşim şöyle okunur:
 *
 * * `disabled` hiç geçilmemişse ya da statik `false` ise → sebep YASAK
 *   (`never`); kapalı olmayan bir butonun sebebi olmaz.
 * * `disabled` çalışma anında hesaplanan bir `boolean` ise (`disabled={pending}`
 *   gibi) → sebep ZORUNLU. Derleyici kapalı olabilecek her butonda metni
 *   ister.
 *
 * Metnin KENDİSİ hâlâ görünür olmalı: kapalı bir öğe odak almadığı için
 * `aria-describedby` işe yaramaz — ekran okuyucu açıklamayı okuyacağı ana hiç
 * varmıyor. Buradaki `title` yalnızca işaretçiyle gelen ikinci yol.
 */
type ButtonDisabledProps =
  | { disabled?: false | undefined; disabledReason?: never }
  | { disabled: boolean; disabledReason: string };

type ButtonProps = Omit<React.ComponentProps<'button'>, 'disabled'> &
  VariantProps<typeof buttonVariants> &
  ButtonDisabledProps & {
    asChild?: boolean;
  };

function Button({
  className,
  variant = 'default',
  size = 'default',
  asChild = false,
  disabled,
  disabledReason,
  title,
  ...props
}: ButtonProps) {
  const Comp = asChild ? Slot.Root : 'button';

  return (
    <Comp
      data-slot="button"
      data-variant={variant}
      data-size={size}
      disabled={disabled}
      title={disabled && disabledReason ? disabledReason : title}
      className={cn(buttonVariants({ variant, size }), className)}
      {...props}
    />
  );
}

export { Button, buttonVariants };
