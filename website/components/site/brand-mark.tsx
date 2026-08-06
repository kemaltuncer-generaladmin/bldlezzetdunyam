import Image from 'next/image';
import { BRAND, LOGO } from '@/content/site';
import { cn } from '@/lib/utils';

/**
 * Marka işareti.
 *
 * Marka adı ve logo panelden gelir (`brand.name`, `brand.logo_url`); değerler
 * **prop olarak** geçirilir. Bileşen içeriği kendi çekmiyor, çünkü mobil menü
 * bir istemci bileşeni ve sunucu tarafı içerik okumasını (`server-only`)
 * istemci ağacına sokamaz. Prop verilmediğinde `content/site.ts` yedeğine
 * düşer — böylece hukuki sayfalar gibi içerikten beslenmeyen yerler
 * değişmeden çalışmaya devam eder.
 *
 * Logo yoksa harf işareti basılır: repoda BLD'nin kurumsal logo dosyası yok
 * (bkz. `content/site.ts` → `LOGO`) ve logoyu tarif üzerinden yeniden çizmek
 * marka kimliğini uydurmak olurdu. Logonun etrafındaki boşluk, harf işaretinde
 * de görselde de korunan güvenli alandır.
 */
export function BrandMark({
  className,
  showWordmark = true,
  brandName = BRAND.name,
  brandShortName = BRAND.shortName,
  logoSrc = LOGO.src,
}: {
  className?: string;
  showWordmark?: boolean;
  brandName?: string;
  brandShortName?: string;
  logoSrc?: string | null;
}) {
  /*
   * Panelden gelen logo mutlak bir URL ve boyutları bilinmiyor. `next/image`
   * için iki sonucu var:
   *  - `width`/`height` yalnızca oran ipucu; gerçek ölçüyü `h-10 w-auto` verir.
   *  - `unoptimized`: iyileştiriciden geçirmek `next.config.ts` içindeki
   *    `remotePatterns` listesine panelin kullanacağı her alan adını önceden
   *    yazmayı gerektirirdi. Logo küçük bir dosya; iyileştirmeden kaçınmak,
   *    yayınlanamayan bir logodan iyi.
   */
  const isRemoteLogo = typeof logoSrc === 'string' && /^https?:\/\//i.test(logoSrc);

  /*
   * Sözcük işareti iki satır: son sözcük alta iner ("Benim Lezzet / Dünyam").
   * Satır sonu koda gömülü değil, addan türetiliyor — marka adı panelden
   * değiştirilirse başlık kendini yeniden kırar, tek sözcüklük bir adda da
   * boş ikinci satır kalmaz.
   */
  const words = brandName.trim().split(/\s+/);
  const wordmarkTail = words.length > 1 ? words[words.length - 1] : null;
  const wordmarkHead = wordmarkTail ? words.slice(0, -1).join(' ') : brandName;

  return (
    <span className={cn('flex items-center gap-2.5', className)}>
      {logoSrc ? (
        <Image
          src={logoSrc}
          alt={brandName}
          width={LOGO.width || 160}
          height={LOGO.height || 40}
          className="h-10 w-auto"
          unoptimized={isRemoteLogo}
          priority
        />
      ) : (
        <span
          aria-hidden="true"
          className="grid size-10 shrink-0 place-items-center rounded-xl bg-linear-to-br from-brand-500 to-brand-700 text-[0.7rem] font-bold tracking-tight text-white shadow-xs"
        >
          {brandShortName}
        </span>
      )}

      {showWordmark && (
        <span className="font-display text-[0.9rem] leading-[1.15] font-semibold text-foreground">
          {wordmarkHead}
          {wordmarkTail && (
            <>
              <br />
              {wordmarkTail}
            </>
          )}
        </span>
      )}
    </span>
  );
}
