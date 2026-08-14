import Image from 'next/image';
import { BRAND, LOGO } from '@/content/site';
import { BrandEmblemPlate } from '@/components/site/brand-emblem';
import { cn } from '@/lib/utils';

/**
 * Marka işareti: amblem + sözcük işareti.
 *
 * Marka adı ve logo panelden gelir (`brand.name`, `brand.logo_url`); değerler
 * **prop olarak** geçirilir. Bileşen içeriği kendi çekmiyor, çünkü mobil menü
 * bir istemci bileşeni ve sunucu tarafı içerik okumasını (`server-only`)
 * istemci ağacına sokamaz. Prop verilmediğinde `content/site.ts` yedeğine
 * düşer.
 *
 * ## HARF İŞARETİ YEDEĞİ KALDIRILDI
 *
 * Panelde logo yokken burada "BLD" üç harf olarak diziliyordu. Marka kılavuzu
 * monogramı fontla dizmeyi YASAKLIYOR — logodaki harfler el çizimi ve hiçbir
 * font onları üretmiyor; dizilmiş hâli markanın yanlış bir kopyasıydı. Artık
 * gerçek amblem var (`brand-emblem.tsx`, `app/icon.svg` ile aynı geometri) ve
 * yedek gerekmiyor: panelde logo yoksa AMBLEM basılır, harf değil.
 *
 * Panelden yüklenen bir logo hâlâ kazanır — işletme kendi dosyasını
 * yüklediğinde onu göstermek doğru.
 */
export function BrandMark({
  className,
  showWordmark = true,
  brandName = BRAND.name,
  logoSrc = LOGO.src,
  /**
   * Koyu zeminde (altbilgi, mobil menü perdesi) sözcük işareti `foreground`
   * ile okunmaz. Bant kendi metin rengini veriyorsa `inherit` geçilir.
   */
  wordmarkClassName,
}: {
  className?: string;
  showWordmark?: boolean;
  brandName?: string;
  logoSrc?: string | null;
  wordmarkClassName?: string;
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
        // Sözcük işareti basılıyorsa amblem dekoratif; basılmıyorsa (altbilgi)
        // adı taşıyan tek öğe o, o yüzden `title` geçiyor.
        <BrandEmblemPlate title={showWordmark ? undefined : brandName} />
      )}

      {showWordmark && (
        <span
          className={cn(
            'font-display text-body font-semibold text-foreground',
            // Satır aralığı 1.15: iki satırlık sözcük işareti 40 px'lik
            // amblemin yüksekliğini aşmasın diye. Gövde ölçeği kullanılsaydı
            // (22 px satır) başlık çubuğu iki piksel uzuyordu.
            'leading-[1.15]',
            wordmarkClassName,
          )}
        >
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
