import type { ReactNode } from 'react';
import { cn } from '@/lib/utils';

/**
 * Bölüm kabuğu.
 *
 * Sayfalar aynı `max-w-content px-4 py-16` dizisini otuz kez tekrar etmesin
 * diye var. `tone` ile bölüm zemini değişir — ard arda gelen bölümlerin hepsi
 * beyaz kutu olmasın, sayfada ritim oluşsun diye.
 */
export type SectionTone = 'default' | 'muted' | 'warm' | 'brand' | 'dark';

/*
 * TON ADLARI ARTIK RENK DEĞİL ROL SÖYLÜYOR — B-19.
 *
 * Eskiden `olive` ve `charcoal` vardı; ikisi de paletin dışında kendi hex'i
 * olan renklerdi ve ara bir turda `success-700` ile `neutral-950`e
 * bağlanmışlardı. Ad ile değer ayrışmıştı: `olive` diye çağrılan bant artık
 * yeşil bile değil.
 *
 * `olive` → `brand`. Değeri de değişti: `success-700` bir SEMANTİK renk ve
 * "başarılı" demek. Misyon/vizyon bandını yeşile boyamak, sayfaya anlamı
 * olmayan bir durum bildirimi koymaktı; marka kahvesi hem doğru anlamı hem
 * de logoyla aynı aileyi taşıyor.
 *
 * Koyu bantlar (`brand`, `dark`) kendi metin rengini VERİR ve başlık rengini
 * de kendileri taşır — bu yüzden `SectionHeading` başlığa `--heading`
 * uygulamıyor (bkz. aşağıdaki gerekçe).
 */
const TONE_CLASS: Record<SectionTone, string> = {
  default: 'bg-background text-foreground',
  muted: 'bg-card text-card-foreground',
  warm: 'bg-surface-warm text-surface-warm-foreground',
  /*
   * Marka kahvesi bandı. Metin `brand-50`: beyaz DEĞİL, çünkü sıcak bir
   * kahvenin üstünde saf beyaz mavimsi duruyor. Kontrast 7,8:1 (ölçüldü:
   * brand800 beyaz üstünde 8,66 · brand50 neredeyse beyaz).
   *
   * Karanlık temada `brand-950`e düşüyor: koyu zeminde brand800 bir bant
   * değil, sayfadan taşan parlak bir blok gibi duruyordu.
   */
  brand: 'bg-brand-800 text-brand-50 dark:bg-brand-950',
  /* En koyu bant — sıcak kahve siyahı, saf siyah değil. */
  dark: 'bg-neutral-950 text-neutral-50',
};

export function Section({
  children,
  className,
  tone = 'default',
  id,
  as: Tag = 'section',
  'aria-labelledby': labelledBy,
}: {
  children: ReactNode;
  className?: string;
  tone?: SectionTone;
  id?: string;
  as?: 'section' | 'div';
  'aria-labelledby'?: string;
}) {
  return (
    <Tag id={id} aria-labelledby={labelledBy} className={cn(TONE_CLASS[tone], className)}>
      <div className="mx-auto max-w-content px-4 py-14 sm:px-6 sm:py-20">{children}</div>
    </Tag>
  );
}

/**
 * Bölüm başlığı.
 *
 * `eyebrow` başlığın üstündeki küçük etiket. Görsel bir öğe olduğu için
 * başlık hiyerarşisine girmez — `<p>` olarak çıkar, yoksa ekran okuyucuda
 * her bölümde sahte bir başlık seviyesi belirirdi.
 */
export function SectionHeading({
  eyebrow,
  title,
  description,
  id,
  align = 'start',
  level = 2,
  className,
}: {
  eyebrow?: string;
  title: string;
  description?: string;
  id?: string;
  align?: 'start' | 'center';
  level?: 2 | 3;
  className?: string;
}) {
  const Heading = level === 2 ? 'h2' : 'h3';

  return (
    <div
      className={cn(
        'max-w-2xl',
        align === 'center' && 'mx-auto text-center',
        'bld-reveal',
        className,
      )}
    >
      {/*
        Üst etiket `overline` adımı: 11/700/0.14em. Ölçek belirteci hem boyu
        hem ağırlığı hem harf aralığını birlikte taşıyor — üçünü ayrı sınıfla
        yazmak, bir gün biri değiştiğinde ötekilerin geride kalması demek.

        `uppercase` SABİT METİNDE güvenli: bu etiketler kodda yazılı ve
        Türkçe İ/ı içermiyor. API'den gelen metin ASLA CSS ile büyütülmez.
      */}
      {eyebrow && <p className="text-overline text-primary-text uppercase">{eyebrow}</p>}
      <Heading
        id={id}
        className={cn(
          // Başlık rengi BURADA verilmiyor: bölüm tonu koyuysa (`brand`,
          // `dark`) banttan miras alınan açık renk doğru olan; marka
          // kahvesini zorlamak başlığı görünmez yapardı. Açık bantlarda
          // sayfa `text-heading` ile geliyor.
          'font-display font-semibold tracking-tight text-balance',
          eyebrow && 'mt-3',
          level === 2 ? 'text-h2 sm:text-h1' : 'text-h3 sm:text-h2',
        )}
      >
        {title}
      </Heading>
      {description && <p className="mt-4 text-body-lg text-pretty opacity-80">{description}</p>}
    </div>
  );
}
