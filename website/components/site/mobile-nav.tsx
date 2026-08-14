'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Mail, Menu, MessageCircle, Phone } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  Sheet,
  SheetClose,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from '@/components/ui/sheet';
import { BrandMark } from '@/components/site/brand-mark';
import { LEGAL_NAV, MAIN_NAV, PRIMARY_CTA, isOrderingRoute } from '@/content/navigation';
import { cn } from '@/lib/utils';

/**
 * İletişim kanalı — sunucudan prop olarak inen düz veri.
 *
 * `icon` alanı YOK: bileşen referansı sunucudan istemciye geçirilemez. Kanal
 * türü metin olarak geliyor, ikon burada seçiliyor.
 */
export type MobileNavChannel = {
  readonly kind: 'phone' | 'whatsapp' | 'email';
  readonly display: string;
  readonly href: string;
};

const CHANNEL_ICONS = { phone: Phone, whatsapp: MessageCircle, email: Mail } as const;

/**
 * Mobil gezinme.
 *
 * Sheet, odak tuzağını ve Escape ile kapanmayı Radix üzerinden hazır getiriyor.
 *
 * KAPANMA İKİ KEMERLE SAĞLANIYOR (W-07) — ve ikisi de gerekli:
 *
 * 1. Her bağlantı `SheetClose asChild` ile sarılı. Tıklama anında kapatır;
 *    hedefin ne olduğuna bakmaz.
 * 2. `pathname` değişince `setOpen(false)`. Tarayıcı geri/ileri tuşuyla
 *    yapılan gezinmeyi yakalar — orada tıklama olmadığı için 1. kemer
 *    devreye girmez.
 *
 * ÖNCEDEN YALNIZ 2. KEMER VARDI VE ÜÇ DURUMDA DELİNİYORDU:
 *   * bulunduğun sayfanın kendi bağlantısına dokunmak — `usePathname()` aynı
 *     dizeyi döndürüyor, efekt hiç yeniden koşmuyor, panel açık kalıyor;
 *   * alttaki `tel:` / `wa.me` / `mailto:` düğmeleri — rota hiç değişmiyor,
 *     kullanıcı telefon uygulamasından dönünce paneli açık buluyor;
 *   * yavaş bir RSC geçişi (`/odeme`, `/siparislerim` dinamik) — panel geçiş
 *     boyunca açık duruyor ve "kapanmıyor" olarak okunuyor.
 *
 * Alt menüler burada açılır-kapanır değil, düz liste hâlinde: mobilde iki
 * seviyeli açılım fazladan bir dokunuş ve fazladan bir hata payı demek.
 */
export function MobileNav({
  brandName,
  logoSrc,
  channels,
}: {
  brandName?: string;
  logoSrc?: string | null;
  channels: readonly MobileNavChannel[];
}) {
  const [open, setOpen] = useState(false);
  const pathname = usePathname();

  const onOrderingRoute = isOrderingRoute(pathname);

  useEffect(() => {
    setOpen(false);
  }, [pathname]);

  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger asChild>
        <Button
          variant="outline"
          size="icon"
          className={cn(!onOrderingRoute && 'xl:hidden')}
          aria-label="Menüyü aç"
        >
          <Menu aria-hidden="true" strokeWidth={1.75} />
        </Button>
      </SheetTrigger>

      <SheetContent side="right" className="flex w-[min(22rem,88vw)] flex-col gap-0 p-0">
        <SheetHeader className="border-b p-4 text-left">
          <SheetTitle asChild>
            <span>
              <BrandMark brandName={brandName} logoSrc={logoSrc} />
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
                  <SheetClose asChild>
                    <Link
                      href={item.href}
                      aria-current={isActive ? 'page' : undefined}
                      className={cn(
                        'flex min-h-11 items-center rounded-sm px-3 text-body-lg font-medium transition-colors duration-(--duration-fast)',
                        isActive ? 'bg-accent text-accent-foreground' : 'hover:bg-muted',
                      )}
                    >
                      {item.label}
                    </Link>
                  </SheetClose>

                  {item.children && (
                    <ul className="mt-1 mb-2 ml-3 space-y-0.5 border-l border-border pl-3">
                      {item.children.map((child) => (
                        <li key={child.href}>
                          <SheetClose asChild>
                            <Link
                              href={child.href}
                              className={cn(
                                'flex min-h-11 items-center rounded-sm px-3 text-body transition-colors duration-(--duration-fast)',
                                pathname === child.href
                                  ? 'font-medium text-primary-text'
                                  : 'text-muted-foreground hover:bg-muted hover:text-foreground',
                              )}
                            >
                              {child.label}
                            </Link>
                          </SheetClose>
                        </li>
                      ))}
                    </ul>
                  )}
                </li>
              );
            })}
          </ul>

          <ul className="mt-6 space-y-0.5 border-t border-border pt-4 text-body-sm text-muted-foreground">
            {LEGAL_NAV.map((link) => (
              <li key={link.href}>
                <SheetClose asChild>
                  <Link href={link.href} className="flex min-h-11 items-center px-3">
                    {link.label}
                  </Link>
                </SheetClose>
              </li>
            ))}
          </ul>
        </nav>

        <div className="space-y-2 border-t p-4">
          <SheetClose asChild>
            <Button asChild size="lg" className="w-full">
              <Link href={PRIMARY_CTA.href}>{PRIMARY_CTA.label}</Link>
            </Button>
          </SheetClose>

          {/* Girilmemiş kanal hiç render edilmez — sahte numara göstermek yerine.
              `SheetClose` burada özellikle önemli: `tel:`/`wa.me`/`mailto:`
              bağlantıları rotayı hiç değiştirmiyor, yani paneli kapatacak
              başka bir mekanizma yok. Kullanıcı arama ekranından dönünce
              paneli açık bulmamalı. */}
          {channels.map((channel) => {
            const Icon = CHANNEL_ICONS[channel.kind];
            // WhatsApp'ta numara değil eylem yazılır; `href` zaten wa.me adresi.
            const label = channel.kind === 'whatsapp' ? 'WhatsApp' : channel.display;
            return (
              <SheetClose key={channel.href} asChild>
                <Button asChild variant="outline" size="lg" className="w-full">
                  <a href={channel.href}>
                    <Icon aria-hidden="true" strokeWidth={1.75} />
                    {label}
                  </a>
                </Button>
              </SheetClose>
            );
          })}
        </div>
      </SheetContent>
    </Sheet>
  );
}
