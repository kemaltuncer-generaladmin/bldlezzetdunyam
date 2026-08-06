'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Mail, Menu, MessageCircle, Phone } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from '@/components/ui/sheet';
import { BrandMark } from '@/components/site/brand-mark';
import { LEGAL_NAV, MAIN_NAV, PRIMARY_CTA } from '@/content/navigation';
import { CONTACT } from '@/content/site';
import { cn } from '@/lib/utils';

/**
 * Sipariş akışı rotaları — `MainNav` ile aynı liste.
 *
 * Oralarda masaüstü gezinmesi gizlendiği için hamburger düğmesi her genişlikte
 * görünür kalmalı; yoksa geniş ekranda sipariş sayfasındaki kullanıcının
 * hiçbir gezinme yolu kalmıyor.
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

/**
 * Mobil gezinme.
 *
 * Sheet, odak tuzağını ve Escape ile kapanmayı Radix üzerinden hazır getiriyor.
 * Bizim eklediğimiz tek davranış: **rota değişince kapanma.** Onsuz kullanıcı
 * bir bağlantıya bastığında sayfa arkada değişiyor ama panel açık kalıyor ve
 * hiçbir şey olmamış gibi görünüyor.
 *
 * Alt menüler burada açılır-kapanır değil, düz liste hâlinde: mobilde iki
 * seviyeli açılım fazladan bir dokunuş ve fazladan bir hata payı demek.
 */
export function MobileNav() {
  const [open, setOpen] = useState(false);
  const pathname = usePathname();

  const onOrderingRoute = ORDERING_ROUTES.some(
    (route) => pathname === route || pathname.startsWith(`${route}/`),
  );

  useEffect(() => {
    setOpen(false);
  }, [pathname]);

  const channels = [
    CONTACT.phone && { icon: Phone, label: CONTACT.phone.display, href: CONTACT.phone.href },
    CONTACT.whatsapp && {
      icon: MessageCircle,
      label: 'WhatsApp',
      href: CONTACT.whatsapp.href,
    },
    CONTACT.email && { icon: Mail, label: CONTACT.email.display, href: CONTACT.email.href },
  ].filter((channel): channel is { icon: typeof Phone; label: string; href: string } =>
    Boolean(channel),
  );

  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger asChild>
        <Button
          variant="outline"
          size="icon"
          className={cn(!onOrderingRoute && 'xl:hidden')}
          aria-label="Menüyü aç"
        >
          <Menu aria-hidden="true" />
        </Button>
      </SheetTrigger>

      <SheetContent side="right" className="flex w-[min(22rem,88vw)] flex-col gap-0 p-0">
        <SheetHeader className="border-b p-4 text-left">
          <SheetTitle asChild>
            <span>
              <BrandMark />
            </span>
          </SheetTitle>
          <SheetDescription className="sr-only">
            Site bölümleri ve iletişim kanalları
          </SheetDescription>
        </SheetHeader>

        <nav aria-label="Mobil gezinme" className="flex-1 overflow-y-auto p-4">
          <ul className="space-y-1">
            {MAIN_NAV.map((item) => {
              const isActive = pathname === item.href || pathname.startsWith(`${item.href}/`);
              return (
                <li key={item.href}>
                  <Link
                    href={item.href}
                    aria-current={isActive ? 'page' : undefined}
                    className={cn(
                      'flex min-h-11 items-center rounded-lg px-3 text-[0.95rem] font-medium transition-colors',
                      isActive ? 'bg-accent text-accent-foreground' : 'hover:bg-muted',
                    )}
                  >
                    {item.label}
                  </Link>

                  {item.children && (
                    <ul className="mt-1 mb-2 ml-3 space-y-0.5 border-l border-border pl-3">
                      {item.children.map((child) => (
                        <li key={child.href}>
                          <Link
                            href={child.href}
                            className={cn(
                              'flex min-h-11 items-center rounded-lg px-3 text-sm transition-colors',
                              pathname === child.href
                                ? 'font-medium text-primary'
                                : 'text-muted-foreground hover:bg-muted hover:text-foreground',
                            )}
                          >
                            {child.label}
                          </Link>
                        </li>
                      ))}
                    </ul>
                  )}
                </li>
              );
            })}
          </ul>

          <ul className="mt-6 space-y-0.5 border-t pt-4 text-xs text-muted-foreground">
            {LEGAL_NAV.map((link) => (
              <li key={link.href}>
                <Link href={link.href} className="flex min-h-11 items-center px-3">
                  {link.label}
                </Link>
              </li>
            ))}
          </ul>
        </nav>

        <div className="space-y-2 border-t p-4">
          <Button asChild size="lg" className="w-full">
            <Link href={PRIMARY_CTA.href}>{PRIMARY_CTA.label}</Link>
          </Button>

          {/* Girilmemiş kanal hiç render edilmez — sahte numara göstermek yerine. */}
          {channels.map((channel) => (
            <Button key={channel.href} asChild variant="outline" size="lg" className="w-full">
              <a href={channel.href}>
                <channel.icon aria-hidden="true" />
                {channel.label}
              </a>
            </Button>
          ))}
        </div>
      </SheetContent>
    </Sheet>
  );
}
