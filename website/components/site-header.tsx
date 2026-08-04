import Link from 'next/link';
import { getTranslations } from 'next-intl/server';
import { HeaderActions } from '@/components/header-actions';

/**
 * Başlık bilinçli olarak **statik**tir: cookie okumaz. Sepet rozeti ve oturum
 * adı istemcide okunur (`HeaderActions`), böylece `/` ve `/menu` ISR kalır.
 */
export async function SiteHeader() {
  const t = await getTranslations('nav');

  return (
    <header className="sticky top-0 z-40 border-b border-neutral-200 bg-neutral-0/95 backdrop-blur">
      <div className="mx-auto flex h-16 max-w-content items-center gap-3 px-4 sm:gap-6">
        <Link
          href="/"
          className="flex shrink-0 items-center gap-2 rounded-md text-neutral-900"
          aria-label={t('home')}
        >
          <span
            aria-hidden="true"
            className="grid h-9 w-9 place-items-center rounded-lg bg-brand-500 text-base font-bold text-neutral-0"
          >
            BL
          </span>
          <span className="hidden text-base font-semibold leading-tight sm:block">
            Benim Lezzet
            <br />
            Dünyam
          </span>
        </Link>

        <nav aria-label={t('ariaMain')} className="flex items-center gap-1 sm:gap-2">
          <Link
            href="/menu"
            className="rounded-md px-2 py-2 text-sm font-medium text-neutral-800 hover:bg-neutral-100 sm:px-3"
          >
            {t('menu')}
          </Link>
          <Link
            href="/iletisim"
            className="hidden rounded-md px-3 py-2 text-sm font-medium text-neutral-800 hover:bg-neutral-100 sm:block"
          >
            {t('contact')}
          </Link>
        </nav>

        <div className="ml-auto">
          <HeaderActions />
        </div>
      </div>
    </header>
  );
}
