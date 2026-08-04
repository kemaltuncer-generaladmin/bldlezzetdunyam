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
    <div
      role="alert"
      className="bld-card mx-auto max-w-lg px-5 py-8 text-center"
    >
      <p className="text-lg font-semibold text-neutral-900">{title}</p>
      <p className="mt-2 text-sm text-neutral-600">{message}</p>
      {retryHref && (
        <Link
          href={retryHref}
          className="mt-5 inline-block rounded-lg bg-brand-600 px-5 py-2.5 text-sm font-semibold text-neutral-0 hover:bg-brand-700"
        >
          {retryLabel}
        </Link>
      )}
    </div>
  );
}
