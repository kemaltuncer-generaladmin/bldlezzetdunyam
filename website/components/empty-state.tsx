import Link from 'next/link';
import { cn } from '@/lib/cn';

type Props = {
  title: string;
  message: string;
  /** Dekoratif ikon; sağlanmazsa yalnızca metin gösterilir. */
  icon?: React.ReactNode;
  actionHref?: string;
  actionLabel?: string;
  className?: string;
};

/**
 * "Sonuç yok" durumları. `ErrorState`'ten ayrıdır: o `role="alert"` ile bir
 * **hata** duyurur, boş liste ise hata değildir — ekran okuyucuyu uyarıyla
 * kesmemeli, sayfanın normal akışında okunmalı.
 */
export function EmptyState({
  title,
  message,
  icon,
  actionHref,
  actionLabel = 'Menüye git',
  className,
}: Props) {
  return (
    <div className={cn('mx-auto max-w-lg bld-card px-6 py-12 text-center', className)}>
      {icon && (
        <span
          aria-hidden="true"
          className="mx-auto grid h-16 w-16 place-items-center rounded-full bg-brand-50 text-brand-600"
        >
          {icon}
        </span>
      )}
      <p className={cn('text-lg font-semibold', icon ? 'mt-4' : null)}>{title}</p>
      <p className="mt-2 text-sm leading-relaxed text-neutral-600">{message}</p>
      {actionHref && (
        <Link href={actionHref} className="mt-6 bld-btn-primary">
          {actionLabel}
        </Link>
      )}
    </div>
  );
}
