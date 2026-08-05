import Link from 'next/link';
import { getTranslations } from 'next-intl/server';

const LINK_CLASS =
  'rounded text-sm text-neutral-600 underline-offset-2 hover:text-brand-700 hover:underline';

export async function SiteFooter() {
  const t = await getTranslations('footer');
  const brand = await getTranslations('brand');
  const year = new Date().getFullYear();

  const legalLinks = [
    { href: '/kvkk', label: t('kvkk') },
    { href: '/mesafeli-satis', label: t('distanceSales') },
    { href: '/iletisim', label: t('contact') },
  ];

  const orderLinks = [
    { href: '/menu', label: t('menu') },
    { href: '/sepet', label: t('cart') },
    { href: '/siparislerim', label: t('orders') },
  ];

  return (
    <footer className="mt-auto border-t border-neutral-200 bg-neutral-0">
      <div className="mx-auto grid max-w-content gap-8 px-4 py-12 sm:grid-cols-2 lg:grid-cols-3">
        <div>
          <p className="flex items-center gap-2 text-base font-semibold text-neutral-900">
            <span
              aria-hidden="true"
              className="grid h-8 w-8 place-items-center rounded-lg bg-brand-500 text-sm font-bold text-neutral-900"
            >
              BL
            </span>
            {brand('name')}
          </p>
          <p className="mt-3 max-w-sm text-sm leading-relaxed text-neutral-600">
            {brand('tagline')}
          </p>
        </div>

        <nav aria-label={t('legalAria')}>
          <p className="text-sm font-semibold text-neutral-900">{t('infoTitle')}</p>
          <ul className="mt-3 space-y-2">
            {legalLinks.map((link) => (
              <li key={link.href}>
                <Link href={link.href} className={LINK_CLASS}>
                  {link.label}
                </Link>
              </li>
            ))}
          </ul>
        </nav>

        <nav aria-label={t('orderAria')}>
          <p className="text-sm font-semibold text-neutral-900">{t('orderTitle')}</p>
          <ul className="mt-3 space-y-2">
            {orderLinks.map((link) => (
              <li key={link.href}>
                <Link href={link.href} className={LINK_CLASS}>
                  {link.label}
                </Link>
              </li>
            ))}
          </ul>
        </nav>
      </div>

      <div className="border-t border-neutral-200">
        <p className="mx-auto max-w-content px-4 py-4 text-xs text-neutral-600">
          {t('rights', { year })}
        </p>
      </div>
    </footer>
  );
}
