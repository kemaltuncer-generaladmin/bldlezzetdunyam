'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  NavigationMenu,
  NavigationMenuContent,
  NavigationMenuItem,
  NavigationMenuLink,
  NavigationMenuList,
  NavigationMenuTrigger,
  navigationMenuTriggerStyle,
} from '@/components/ui/navigation-menu';
import { MAIN_NAV, isOrderingRoute } from '@/content/navigation';
import { cn } from '@/lib/utils';

/**
 * Masaüstü ana gezinme.
 *
 * RADIX `NavigationMenu`, ÖNCEKİ `<details>/<summary>` YERİNE (W-07).
 *
 * `<details>` seçilmişti çünkü açma/kapama, klavye ve odak yönetimini
 * tarayıcı bedavaya veriyordu. Vermediği tek şey ise asıl gerekli olandı:
 * **seçim yapılınca kapanmak.** Alt menüdeki bir bağlantıya tıklandığında
 * Next.js istemci tarafında geziniyor, DOM korunuyor ve `<details open>`
 * olduğu gibi kalıyordu — kullanıcı yeni sayfanın üstünde hâlâ açık duran
 * bir panel görüyordu. Dışarı tıklamak da, Escape de kapatmıyordu
 * (`<details>` Escape dinlemez; eski yorumdaki aksi yöndeki iddia yanlıştı).
 *
 * Radix bunların hepsini kutudan çıkarıyor: seçimde kapanma, dış tıklama,
 * Escape, odak tuzağı ve `aria-expanded`. `NavigationMenuLink` içindeki
 * `onSelect` varsayılanı menüyü kapattığı için ek bir state'e gerek yok —
 * ve rota değişimini dinlemediğimiz için "aynı sayfaya tıklanınca kapanmama"
 * hatası da yapısal olarak ortadan kalkıyor.
 */
export function MainNav() {
  const pathname = usePathname();

  if (isOrderingRoute(pathname)) return null;

  return (
    <NavigationMenu className="hidden xl:flex" aria-label="Ana gezinme">
      <NavigationMenuList className="gap-0.5">
        {MAIN_NAV.map((item) => {
          const isActive = pathname === item.href || pathname.startsWith(`${item.href}/`);

          if (!item.children) {
            return (
              <NavigationMenuItem key={item.href}>
                <NavigationMenuLink asChild className={navigationMenuTriggerStyle()}>
                  <Link
                    href={item.href}
                    aria-current={isActive ? 'page' : undefined}
                    className={cn(
                      'text-sm font-medium whitespace-nowrap',
                      isActive ? 'text-primary' : 'text-foreground/75',
                    )}
                  >
                    {item.label}
                  </Link>
                </NavigationMenuLink>
              </NavigationMenuItem>
            );
          }

          return (
            <NavigationMenuItem key={item.href}>
              <NavigationMenuTrigger
                className={cn(
                  'text-sm font-medium whitespace-nowrap',
                  isActive ? 'text-primary' : 'text-foreground/75',
                )}
              >
                {item.label}
              </NavigationMenuTrigger>

              <NavigationMenuContent>
                <ul className="w-80 p-2">
                  <li>
                    <NavigationMenuLink asChild>
                      <Link
                        href={item.href}
                        className="block rounded-lg px-3 py-2 text-sm font-semibold hover:bg-muted"
                      >
                        Tüm {item.label.toLocaleLowerCase('tr-TR')}
                      </Link>
                    </NavigationMenuLink>
                  </li>

                  {item.children.map((child) => (
                    <li key={child.href}>
                      <NavigationMenuLink asChild>
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
                      </NavigationMenuLink>
                    </li>
                  ))}
                </ul>
              </NavigationMenuContent>
            </NavigationMenuItem>
          );
        })}
      </NavigationMenuList>
    </NavigationMenu>
  );
}
