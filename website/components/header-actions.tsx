'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { ShoppingCart } from 'lucide-react';
import { readBrowserCookie } from '@/lib/browser-cookie';
import { CART_CHANGED_EVENT } from '@/lib/cart-events';

const CART_COUNT_COOKIE = 'bld_cart_n';
const SESSION_NAME_COOKIE = 'bld_name';

/**
 * Sipariş akışı için sepet rozeti ve oturum bağlantısı.
 *
 * ## Neden yalnızca sipariş rotalarında?
 *
 * Site artık iki işi birden yapıyor: kurumsal tanıtım ve sipariş. Kurumsal
 * ziyaretçinin (teklif arayan bir satın alma sorumlusu) ilk gördüğü şeyin
 * "Sepet" olması, firmayı yemek sipariş sitesi gibi gösteriyordu.
 *
 * Rozeti silmek de doğru değildi: sipariş akışı çalışıyor ve `/menu` →
 * `/sepet` yolunda kullanıcının sepetini görmesi gerekiyor. Çözüm, bileşeni
 * rotaya bağlamak — sipariş sayfalarında görünür, kurumsal sayfalarda yok.
 *
 * Cookie'ler sunucuda değil istemcide okunuyor: sunucuda okumak kurumsal
 * sayfaları da dinamik yapar ve ISR'ı bozardı. İlk boyama iki tarafta da
 * aynı (rozetsiz), dolayısıyla hidrasyon uyuşmazlığı yok.
 *
 * ## Metinler neden prop, `useTranslations` değil?
 *
 * `useTranslations` istemci tarafında `NextIntlClientProvider` gerektiriyor ve
 * o sağlayıcı kök layout'ta durduğu için next-intl'in ICU biçimlendirme
 * çalışma zamanı SİTEDEKİ HER SAYFAYA iniyordu — beş kelime uğruna. Site tek
 * dilli (docs/06 §5); metinleri sunucuda çözüp prop olarak geçmek aynı sonucu
 * veriyor, sağlayıcıya gerek kalmıyor.
 */
const ORDERING_ROUTES = [
  '/menu',
  '/urun',
  '/sepet',
  '/odeme',
  '/siparis',
  '/siparislerim',
  '/hesabim',
];

export interface HeaderActionLabels {
  readonly cart: string;
  readonly cartEmpty: string;
  /** `{count}` yer tutucusu içerir. */
  readonly cartCount: string;
  readonly login: string;
}

export function HeaderActions({ labels }: { labels: HeaderActionLabels }) {
  const pathname = usePathname();
  const [cartCount, setCartCount] = useState(0);
  const [firstName, setFirstName] = useState<string | null>(null);

  const onOrderingRoute = ORDERING_ROUTES.some(
    (route) => pathname === route || pathname.startsWith(`${route}/`),
  );

  useEffect(() => {
    if (!onOrderingRoute) return;

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
  }, [pathname, onOrderingRoute]);

  if (!onOrderingRoute) return null;

  return (
    <div className="flex items-center gap-1 sm:gap-2">
      <Link
        href="/sepet"
        className="relative flex min-h-11 items-center gap-2 rounded-md px-2 text-sm font-medium text-foreground/80 transition-colors hover:bg-muted sm:px-3"
      >
        <ShoppingCart aria-hidden="true" className="size-5" />
        <span className="hidden sm:inline">{labels.cart}</span>
        {cartCount > 0 && (
          <span className="absolute -top-0.5 -right-0.5 grid h-5 min-w-5 place-items-center rounded-full bg-primary px-1 text-xs font-bold text-primary-foreground sm:static sm:h-5">
            {cartCount}
          </span>
        )}
        <span className="sr-only">
          {cartCount > 0
            ? labels.cartCount.replace('{count}', String(cartCount))
            : labels.cartEmpty}
        </span>
      </Link>

      {firstName ? (
        <Link
          href="/siparislerim"
          className="flex min-h-11 max-w-28 items-center truncate rounded-md bg-muted px-3 text-sm font-medium text-foreground transition-colors hover:bg-accent"
        >
          {firstName}
        </Link>
      ) : (
        <Link
          href="/giris"
          className="flex min-h-11 items-center rounded-md bg-primary px-3 text-sm font-semibold text-primary-foreground transition-opacity hover:opacity-90"
        >
          {labels.login}
        </Link>
      )}
    </div>
  );
}
