import Link from 'next/link';
import type { ReactNode } from 'react';
import { Button } from '@/components/ui/button';
import { StatePanel } from '@/components/state-panel';

type Props = {
  title: string;
  message: string;
  /** Dekoratif ikon; sağlanmazsa yalnızca metin gösterilir. */
  icon?: ReactNode;
  actionHref?: string;
  actionLabel?: string;
  className?: string;
};

/**
 * "Sonuç yok" durumu.
 *
 * `ErrorState`'ten ayrıdır ve bu ayrım GÖRSEL DEĞİL, ANLAMSAL: hata
 * `role="alert"` ile ekran okuyucuyu keser, boş liste ise hata değildir —
 * sayfanın normal akışında okunmalı. Bu yüzden burada hiçbir `role` yok.
 *
 * Ton marka yüzeyi (`accent`): boş liste bir uyarı değil, bir davet. Eylem
 * PRIMARY, çünkü kutuda başka eylem yok ve kullanıcının çıkışı o.
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
    <StatePanel
      tone="empty"
      icon={icon}
      title={title}
      message={message}
      className={className}
      action={
        actionHref ? (
          <Button asChild>
            <Link href={actionHref}>{actionLabel}</Link>
          </Button>
        ) : undefined
      }
    />
  );
}
