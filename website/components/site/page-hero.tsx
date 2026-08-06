import Link from 'next/link';
import { ChevronRight } from 'lucide-react';
import type { ReactNode } from 'react';

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
 */
export function PageHero({
  crumbs,
  eyebrow,
  title,
  description,
  children,
}: {
  crumbs: readonly Crumb[];
  eyebrow?: string;
  title: string;
  description?: string;
  children?: ReactNode;
}) {
  return (
    <section className="border-b bg-surface-warm text-surface-warm-foreground">
      <div className="mx-auto max-w-content px-4 py-10 sm:px-6 sm:py-14">
        <nav aria-label="Sayfa yolu">
          <ol className="flex flex-wrap items-center gap-1 text-xs text-muted-foreground">
            <li>
              <Link href="/" className="rounded-sm transition-colors hover:text-foreground">
                Ana Sayfa
              </Link>
            </li>
            {crumbs.map((crumb, index) => {
              const isLast = index === crumbs.length - 1;
              return (
                <li key={crumb.href} className="flex items-center gap-1">
                  <ChevronRight aria-hidden="true" className="size-3.5 opacity-50" />
                  {isLast ? (
                    <span aria-current="page" className="font-medium text-foreground">
                      {crumb.label}
                    </span>
                  ) : (
                    <Link
                      href={crumb.href}
                      className="rounded-sm transition-colors hover:text-foreground"
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
            <p className="text-xs font-semibold tracking-[0.14em] text-primary uppercase">
              {eyebrow}
            </p>
          )}
          <h1 className="mt-2 font-display text-3xl font-semibold tracking-tight sm:text-5xl">
            {title}
          </h1>
          {description && <p className="mt-5 text-base/7 opacity-80 sm:text-lg/8">{description}</p>}
          {children && <div className="mt-8">{children}</div>}
        </div>
      </div>
    </section>
  );
}
