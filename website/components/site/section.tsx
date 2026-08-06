import type { ReactNode } from 'react';
import { cn } from '@/lib/utils';

/**
 * Bölüm kabuğu.
 *
 * Sayfalar aynı `max-w-content px-4 py-16` dizisini otuz kez tekrar etmesin
 * diye var. `tone` ile bölüm zemini değişir — ard arda gelen bölümlerin hepsi
 * beyaz kutu olmasın, sayfada ritim oluşsun diye.
 */
export type SectionTone = 'default' | 'muted' | 'warm' | 'olive' | 'charcoal';

const TONE_CLASS: Record<SectionTone, string> = {
  default: 'bg-background text-foreground',
  muted: 'bg-card text-card-foreground',
  warm: 'bg-surface-warm text-surface-warm-foreground',
  // Zeytin ve kömür bantlar koyu; içlerindeki metin rengi zorunlu olarak ters.
  olive: 'bg-olive-700 text-olive-50 dark:bg-olive-900',
  charcoal: 'bg-charcoal text-cream',
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
      {eyebrow && (
        <p className="text-xs font-semibold tracking-[0.14em] text-primary uppercase">{eyebrow}</p>
      )}
      <Heading
        id={id}
        className={cn(
          'font-display tracking-tight',
          eyebrow && 'mt-3',
          level === 2 ? 'text-3xl font-semibold sm:text-4xl' : 'text-2xl font-semibold sm:text-3xl',
        )}
      >
        {title}
      </Heading>
      {description && <p className="mt-4 text-base/7 opacity-80">{description}</p>}
    </div>
  );
}
