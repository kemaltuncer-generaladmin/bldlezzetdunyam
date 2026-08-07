import Image from 'next/image';
import Link from 'next/link';
import { ChevronRight } from 'lucide-react';
import type { ReactNode } from 'react';
import { cn } from '@/lib/utils';

export interface Crumb {
  readonly href: string;
  readonly label: string;
}

/**
 * İç sayfa başlığı + breadcrumb.
 *
 * Breadcrumb burada, ayrı bir bileşen olarak değil: her iç sayfada ikisi
 * birlikte kullanılıyor ve ayrı tutmak her sayfada aynı iki satırı yan yana
 * yazmak anlamına geliyordu.
 *
 * Görsel breadcrumb ile JSON-LD `BreadcrumbList` aynı diziden üretiliyor
 * (bkz. `lib/seo.ts`), böylece ikisi birbirinden kopamaz.
 *
 * ## Fotoğraflı hâli
 *
 * `image` verildiğinde başlık, üzerine koyu bir katman serilmiş fotoğrafın
 * üstüne taşınır. Katman `from-charcoal/85` ile başlıyor: daha açık bir değerde
 * beyaz başlık bazı fotoğrafların aydınlık bölgelerinde AA eşiğinin altına
 * düşüyordu. Fotoğraf yoksa bileşen eski sıcak zeminli hâline döner — panelden
 * eklenen bir sayfanın fotoğrafı olmayabilir.
 */
export function PageHero({
  crumbs,
  eyebrow,
  title,
  description,
  image,
  children,
}: {
  crumbs: readonly Crumb[];
  eyebrow?: string;
  title: string;
  description?: string;
  image?: string | null;
  children?: ReactNode;
}) {
  const dark = Boolean(image);

  return (
    <section
      className={cn(
        'relative isolate border-b',
        dark ? 'bg-charcoal text-cream' : 'bg-surface-warm text-surface-warm-foreground',
      )}
    >
      {image && (
        <>
          <Image alt="" src={image} fill priority sizes="100vw" className="-z-10 object-cover" />
          <div
            aria-hidden="true"
            className="absolute inset-0 -z-10 bg-linear-to-r from-charcoal/85 via-charcoal/70 to-charcoal/35"
          />
        </>
      )}

      <div
        className={cn(
          'mx-auto max-w-content px-4 sm:px-6',
          dark ? 'py-14 sm:py-24' : 'py-10 sm:py-14',
        )}
      >
        <nav aria-label="Sayfa yolu">
          <ol
            className={cn(
              'flex flex-wrap items-center gap-1 text-xs',
              dark ? 'text-cream/60' : 'text-muted-foreground',
            )}
          >
            <li>
              <Link
                href="/"
                className={cn(
                  'rounded-sm transition-colors',
                  dark ? 'hover:text-cream' : 'hover:text-foreground',
                )}
              >
                Ana Sayfa
              </Link>
            </li>
            {crumbs.map((crumb, index) => {
              const isLast = index === crumbs.length - 1;
              return (
                <li key={crumb.href} className="flex items-center gap-1">
                  <ChevronRight aria-hidden="true" className="size-3.5 opacity-50" />
                  {isLast ? (
                    <span
                      aria-current="page"
                      className={cn('font-medium', dark ? 'text-cream' : 'text-foreground')}
                    >
                      {crumb.label}
                    </span>
                  ) : (
                    <Link
                      href={crumb.href}
                      className={cn(
                        'rounded-sm transition-colors',
                        dark ? 'hover:text-cream' : 'hover:text-foreground',
                      )}
                    >
                      {crumb.label}
                    </Link>
                  )}
                </li>
              );
            })}
          </ol>
        </nav>

        <div className="mt-6 max-w-3xl">
          {eyebrow && (
            <p
              className={cn(
                'text-xs font-semibold tracking-[0.14em] uppercase',
                dark ? 'text-brand-300' : 'text-primary',
              )}
            >
              {eyebrow}
            </p>
          )}
          <h1 className="mt-2 font-display text-3xl font-semibold tracking-tight sm:text-5xl">
            {title}
          </h1>
          {description && (
            <p
              className={cn('mt-5 text-base/7 sm:text-lg/8', dark ? 'text-cream/80' : 'opacity-80')}
            >
              {description}
            </p>
          )}
          {children && <div className="mt-8">{children}</div>}
        </div>
      </div>
    </section>
  );
}
