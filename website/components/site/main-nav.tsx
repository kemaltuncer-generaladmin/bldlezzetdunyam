'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { ChevronDown } from 'lucide-react';
import { MAIN_NAV } from '@/content/navigation';
import { cn } from '@/lib/utils';

/**
 * Masaüstü ana gezinme.
 *
 * Alt menü `<details>` ile açılıyor, JavaScript durum yönetimiyle değil:
 * tarayıcı açma/kapama, klavye (Enter/Space), Escape ve odak sırasını
 * kendisi yönetiyor. Kendi yazdığımız bir dropdown'da bunların hepsini
 * yeniden kurmak ve test etmek gerekirdi.
 *
 * `onMouseLeave` ile kapanma yok: yalnızca hover'a bağlı bir menü klavye ve
 * dokunmatik kullanıcıyı dışarıda bırakır.
 */
/**
 * Sipariş akışı rotaları.
 *
 * Buralarda pazarlama gezinmesi gizleniyor. Sebep görsel değil, ölçülmüş:
 * `/menu` başlığında hem yedi bölümlük menü hem sepet/oturum hem de "Teklif
 * Al" yan yana gelince satır 1280 px'te 1362 px'e taşıyor ve sayfada yatay
 * kaydırma çıkıyordu. Kullanıcı zaten bir iş akışının içinde; bölümlerin
 * tamamına hamburger menüden erişmeye devam ediyor.
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

export function MainNav() {
  const pathname = usePathname();

  const onOrderingRoute = ORDERING_ROUTES.some(
    (route) => pathname === route || pathname.startsWith(`${route}/`),
  );
  if (onOrderingRoute) return null;

  return (
    <nav aria-label="Ana gezinme" className="hidden items-center gap-0.5 xl:flex">
      {MAIN_NAV.map((item) => {
        const isActive = pathname === item.href || pathname.startsWith(`${item.href}/`);

        if (!item.children) {
          return (
            <Link
              key={item.href}
              href={item.href}
              aria-current={isActive ? 'page' : undefined}
              className={cn(
                'rounded-md px-3 py-2 text-sm font-medium whitespace-nowrap transition-colors',
                'hover:bg-muted hover:text-foreground',
                isActive ? 'text-primary' : 'text-foreground/75',
              )}
            >
              {item.label}
            </Link>
          );
        }

        return (
          <details key={item.href} className="group/menu relative">
            <summary
              className={cn(
                'flex cursor-pointer list-none items-center gap-1 rounded-md px-3 py-2 text-sm font-medium whitespace-nowrap transition-colors',
                'hover:bg-muted hover:text-foreground [&::-webkit-details-marker]:hidden',
                isActive ? 'text-primary' : 'text-foreground/75',
              )}
            >
              {item.label}
              <ChevronDown
                aria-hidden="true"
                className="size-4 transition-transform duration-200 group-open/menu:rotate-180"
              />
            </summary>

            <div className="absolute top-full left-0 z-50 mt-1 w-80 rounded-xl border bg-popover p-2 text-popover-foreground shadow-lg">
              <Link
                href={item.href}
                className="block rounded-lg px-3 py-2 text-sm font-semibold hover:bg-muted"
              >
                Tüm hizmetler
              </Link>
              <ul className="mt-1 space-y-0.5">
                {item.children.map((child) => (
                  <li key={child.href}>
                    <Link
                      href={child.href}
                      className="block rounded-lg px-3 py-2 transition-colors hover:bg-muted"
                    >
                      <span className="block text-sm font-medium">{child.label}</span>
                      {child.summary && (
                        <span className="mt-0.5 block text-xs leading-snug text-muted-foreground">
                          {child.summary}
                        </span>
                      )}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          </details>
        );
      })}
    </nav>
  );
}
