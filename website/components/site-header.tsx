import Link from 'next/link';
import { getTranslations } from 'next-intl/server';
import { HeaderActions } from '@/components/header-actions';

const NAV_LINK_CLASS =
  'rounded-md px-2 py-2 text-sm font-medium text-neutral-800 transition-colors hover:bg-neutral-100 hover:text-brand-700 sm:px-3';

/**
 * Başlık bilinçli olarak **statik**tir: cookie okumaz. Sepet rozeti ve oturum
 * adı istemcide okunur (`HeaderActions`), böylece `/` ve `/menu` ISR kalır.
 */
export async function SiteHeader() {
  const t = await getTranslations('nav');

  return (
    <header className="sticky top-0 z-40 border-b border-neutral-200 bg-neutral-0/95 backdrop-blur-sm">
      <div className="mx-auto flex h-16 max-w-content items-center gap-2 px-4 sm:gap-5">
        <Link
          href="/"
          className="flex shrink-0 items-center gap-2 rounded-md text-neutral-900"
          aria-label={t('home')}
        >
          {/* Koyu metin açık turuncu üzerine: #1C1917 / #F97316 = 6,0:1 (AA). */}
          <span
            aria-hidden="true"
            className="grid h-9 w-9 place-items-center rounded-lg bg-brand-500 text-base font-bold text-neutral-900 shadow-xs"
          >
            BL
          </span>
          <span className="hidden text-base font-semibold leading-tight sm:block">
            Benim Lezzet
            <br />
            Dünyam
          </span>
        </Link>

        <nav aria-label={t('ariaMain')} className="flex items-center gap-0.5 sm:gap-1">
          <Link href="/menu" className={NAV_LINK_CLASS}>
            {t('menu')}
          </Link>
          <Link href="/siparislerim" className={`${NAV_LINK_CLASS} hidden sm:block`}>
            {t('orders')}
          </Link>
          <Link href="/iletisim" className={`${NAV_LINK_CLASS} hidden md:block`}>
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
