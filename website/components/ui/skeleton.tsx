import { cn } from '@/lib/utils';

/**
 * Yükleme yer tutucusu.
 *
 * `animate-pulse` DEĞİL: nabız tüm kutuyu birlikte söndürüp yakıyor ve
 * sayfada dört beş kutu varken göz kırpması gibi okunuyor. Marka dilinde
 * yükleme, soldan sağa geçen tek bir parıltı (1200 ms) — `bld-skeleton`
 * yardımcı sınıfı, `prefers-reduced-motion` altında parıltıyı kapatıyor.
 *
 * İskelet GERÇEK düzenin kutu sayısını ve yüksekliklerini yansıtmalıdır;
 * hazır düzenler `components/skeletons.tsx` içinde.
 */
function Skeleton({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="skeleton"
      aria-hidden="true"
      className={cn('bld-skeleton', className)}
      {...props}
    />
  );
}

export { Skeleton };
