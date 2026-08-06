import Image from 'next/image';
import { BRAND, LOGO } from '@/content/site';
import { cn } from '@/lib/utils';

/**
 * Marka işareti.
 *
 * Repoda BLD'nin kurumsal logo dosyası yok (bkz. `content/site.ts` → `LOGO`).
 * Logoyu tarif üzerinden yeniden çizmek marka kimliğini uydurmak olurdu; bu
 * yüzden şimdilik harf işareti kullanıyoruz.
 *
 * `LOGO.src` doldurulduğu anda bu bileşen görsele geçer — çağıran hiçbir
 * sayfayı değiştirmek gerekmez. Logonun etrafındaki `p-*` boşluğu, harf
 * işaretinde de görselde de korunan güvenli alandır.
 */
export function BrandMark({
  className,
  showWordmark = true,
}: {
  className?: string;
  showWordmark?: boolean;
}) {
  return (
    <span className={cn('flex items-center gap-2.5', className)}>
      {LOGO.src ? (
        <Image
          src={LOGO.src}
          alt={BRAND.name}
          width={LOGO.width}
          height={LOGO.height}
          className="h-10 w-auto"
          priority
        />
      ) : (
        <span
          aria-hidden="true"
          className="grid size-10 shrink-0 place-items-center rounded-xl bg-linear-to-br from-brand-500 to-brand-700 text-[0.7rem] font-bold tracking-tight text-white shadow-xs"
        >
          BLD
        </span>
      )}

      {showWordmark && (
        <span className="font-display text-[0.9rem] leading-[1.15] font-semibold text-foreground">
          Benim Lezzet
          <br />
          Dünyam
        </span>
      )}
    </span>
  );
}
