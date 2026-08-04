'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useTranslations } from 'next-intl';
import { readBrowserCookie } from '@/lib/browser-cookie';
import { CART_CHANGED_EVENT } from '@/lib/cart-events';

const CART_COUNT_COOKIE = 'bld_cart_n';
const SESSION_NAME_COOKIE = 'bld_name';

/**
 * Sepet rozeti ve oturum bağlantısı. Sunucuda cookie okumak `/` ve `/menu`
 * sayfalarını dinamik yapardı; bu yüzden hidrasyondan sonra istemcide okunur.
 * İlk boyama her iki tarafta da aynı (rozetsiz) — hidrasyon uyuşmazlığı yok.
 */
export function HeaderActions() {
  const t = useTranslations('nav');
  const pathname = usePathname();
  const [cartCount, setCartCount] = useState(0);
  const [firstName, setFirstName] = useState<string | null>(null);

  useEffect(() => {
    const sync = () => {
      const rawCount = readBrowserCookie(CART_COUNT_COOKIE);
      const parsed = rawCount === null ? 0 : Number.parseInt(rawCount, 10);
      setCartCount(Number.isFinite(parsed) && parsed > 0 ? parsed : 0);
      setFirstName(readBrowserCookie(SESSION_NAME_COOKIE));
    };

    sync();
    window.addEventListener(CART_CHANGED_EVENT, sync);
    window.addEventListener('focus', sync);
    return () => {
      window.removeEventListener(CART_CHANGED_EVENT, sync);
      window.removeEventListener('focus', sync);
    };
  }, [pathname]);

  return (
    <div className="flex items-center gap-1 sm:gap-2">
      <Link
        href="/sepet"
        className="relative flex items-center gap-2 rounded-md px-2 py-2 text-sm font-medium text-neutral-800 hover:bg-neutral-100 sm:px-3"
      >
        <svg
          aria-hidden="true"
          viewBox="0 0 24 24"
          className="h-5 w-5"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.8"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <path d="M3 4h2l2.4 11.2a2 2 0 0 0 2 1.6h7.5a2 2 0 0 0 2-1.55L20.5 8H6" />
          <circle cx="10" cy="20" r="1.2" />
          <circle cx="17" cy="20" r="1.2" />
        </svg>
        <span className="hidden sm:inline">{t('cart')}</span>
        {cartCount > 0 && (
          <span className="absolute -right-0.5 -top-0.5 grid h-5 min-w-5 place-items-center rounded-full bg-brand-600 px-1 text-xs font-bold text-neutral-0 sm:static sm:h-5">
            {cartCount}
          </span>
        )}
        <span className="sr-only">
          {cartCount > 0 ? t('cartCount', { count: cartCount }) : t('cartEmpty')}
        </span>
      </Link>

      {firstName ? (
        <Link
          href="/siparislerim"
          className="max-w-28 truncate rounded-md bg-neutral-100 px-3 py-2 text-sm font-medium text-neutral-900 hover:bg-neutral-200"
        >
          {firstName}
        </Link>
      ) : (
        <Link
          href="/giris"
          className="rounded-md bg-brand-600 px-3 py-2 text-sm font-semibold text-neutral-0 hover:bg-brand-700"
        >
          {t('login')}
        </Link>
      )}
    </div>
  );
}
