import Link from 'next/link';

type Props = {
  title?: string;
  message: string;
  /** "Tekrar deneyin" bağlantısının hedefi. */
  retryHref?: string;
  retryLabel?: string;
};

export function ErrorState({
  title = 'Bir sorun oluştu',
  message,
  retryHref,
  retryLabel = 'Tekrar deneyin',
}: Props) {
  return (
    <div role="alert" className="bld-card mx-auto max-w-lg px-5 py-8 text-center">
      <p className="text-lg font-semibold text-neutral-900">{title}</p>
      <p className="mt-2 text-sm text-neutral-600">{message}</p>
      {retryHref && (
        <Link href={retryHref} className="bld-btn-primary mt-5">
          {retryLabel}
        </Link>
      )}
    </div>
  );
}
