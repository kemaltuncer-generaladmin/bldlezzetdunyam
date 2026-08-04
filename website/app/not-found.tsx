import Link from 'next/link';
import { getTranslations } from 'next-intl/server';

export default async function NotFound() {
  const t = await getTranslations('errors');

  return (
    <div className="mx-auto max-w-content px-4 py-20 text-center">
      <p className="text-sm font-semibold uppercase tracking-wide text-brand-700">404</p>
      <h1 className="mt-2 text-3xl font-bold text-neutral-900">{t('notFoundTitle')}</h1>
      <p className="mx-auto mt-3 max-w-md text-sm text-neutral-600">{t('notFoundBody')}</p>
      <Link
        href="/menu"
        className="mt-6 inline-block rounded-lg bg-brand-600 px-6 py-3 text-sm font-semibold text-neutral-0 hover:bg-brand-700"
      >
        {t('goToMenu')}
      </Link>
    </div>
  );
}
