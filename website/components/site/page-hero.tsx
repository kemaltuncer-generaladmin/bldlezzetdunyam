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
 * üstüne taşınır. Katman `from-neutral-950/85` ile başlıyor: daha açık bir değerde
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
        dark ? 'bg-neutral-950 text-neutral-50' : 'bg-surface-warm text-surface-warm-foreground',
      )}
    >
      {image && (
        <>
          <Image alt="" src={image} fill priority sizes="100vw" className="-z-10 object-cover" />
          <div
            aria-hidden="true"
            className="absolute inset-0 -z-10 bg-linear-to-r from-neutral-950/85 via-neutral-950/70 to-neutral-950/35"
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
              'flex flex-wrap items-center gap-1 text-body-sm',
              dark ? 'text-neutral-50/60' : 'text-muted-foreground',
            )}
          >
            <li>
              <Link
                href="/"
                className={cn(
                  'rounded-xs transition-colors duration-(--duration-fast)',
                  dark ? 'hover:text-neutral-50' : 'hover:text-foreground',
                )}
              >
                Ana Sayfa
              </Link>
            </li>
            {crumbs.map((crumb, index) => {
              const isLast = index === crumbs.length - 1;
              return (
                <li key={crumb.href} className="flex items-center gap-1">
                  <ChevronRight
                    aria-hidden="true"
                    strokeWidth={1.75}
                    className="size-4 opacity-60"
                  />
                  {isLast ? (
                    <span
                      aria-current="page"
                      className={cn('font-medium', dark ? 'text-neutral-50' : 'text-foreground')}
                    >
                      {crumb.label}
                    </span>
                  ) : (
                    <Link
                      href={crumb.href}
                      className={cn(
                        'rounded-xs transition-colors duration-(--duration-fast)',
                        dark ? 'hover:text-neutral-50' : 'hover:text-foreground',
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
                'text-overline uppercase',
                dark ? 'text-brand-300' : 'text-primary-text',
              )}
            >
              {eyebrow}
            </p>
          )}
          <h1
            className={cn(
              'mt-2 font-display text-h1 font-semibold tracking-tight text-balance sm:text-display',
              // Koyu kahraman fotoğrafın üstünde başlık krem kalır; açık
              // bantta marka kahvesi.
              dark ? null : 'text-heading',
            )}
          >
            {title}
          </h1>
          {description && (
            <p
              className={cn(
                'mt-5 text-body-lg text-pretty',
                dark ? 'text-neutral-50/80' : 'opacity-80',
              )}
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
