import Link from 'next/link';
import { getTranslations } from 'next-intl/server';
import { Phone } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { HeaderActions } from '@/components/header-actions';
import { BrandMark } from '@/components/site/brand-mark';
import { MainNav } from '@/components/site/main-nav';
import { MobileNav } from '@/components/site/mobile-nav';
import { PRIMARY_CTA } from '@/content/navigation';
import { BRAND, CONTACT } from '@/content/site';

/**
 * Site başlığı.
 *
 * Bilinçli olarak **statik**: cookie okumaz, oturum sorgulamaz. Böylece `/`,
 * `/hizmetler` ve diğer pazarlama sayfaları statik/ISR kalabiliyor. Sipariş
 * akışına ait sepet rozeti ve oturum adı artık başlıkta değil — kurumsal
 * ziyaretçinin ilk gördüğü şey sepet olmamalı; sipariş akışına footer ve
 * `/menu` üzerinden giriliyor.
 */
export async function SiteHeader() {
  const t = await getTranslations('nav');

  return (
    <header className="sticky top-0 z-40 border-b bg-background/90 backdrop-blur supports-[backdrop-filter]:bg-background/70">
      <div className="mx-auto flex h-18 max-w-content items-center gap-3 px-4 sm:px-6">
        <Link
          href="/"
          aria-label={`${BRAND.name} — ana sayfa`}
          className="shrink-0 rounded-md focus-visible:ring-2"
        >
          <BrandMark />
        </Link>

        <div className="ml-auto flex items-center gap-2">
          <MainNav />

          {/*
           * Sipariş rotalarında sepet/oturum; kurumsal sayfalarda kendini
           * gizler. Metinler burada (sunucuda) çözülüp prop olarak geçiyor —
           * gerekçesi bileşenin kendi başlığında.
           */}
          <HeaderActions
            labels={{
              cart: t('cart'),
              cartEmpty: t('cartEmpty'),
              cartCount: t.raw('cartCount'),
              login: t('login'),
            }}
          />

          {CONTACT.phone && (
            <Button asChild variant="ghost" size="sm" className="hidden xl:inline-flex">
              <a href={CONTACT.phone.href}>
                <Phone aria-hidden="true" />
                {CONTACT.phone.display}
              </a>
            </Button>
          )}

          {/*
           * En dar ekranlarda (≤ 400 px) gizli. Sipariş sayfalarında başlıkta
           * ayrıca sepet ve giriş de bulunuyor; hepsi birden 390 px'e sığmayıp
           * sayfayı yatay kaydırıyordu. Mobil kullanıcı bu eylemi kaybetmiyor:
           * hamburger menünün ilk düğmesi ve her sayfanın sonundaki çağrı
           * bandı aynı yere gidiyor.
           */}
          <Button
            asChild
            size="sm"
            className="hidden min-[400px]:inline-flex sm:h-11 sm:px-4 sm:text-sm"
          >
            <Link href={PRIMARY_CTA.href}>{PRIMARY_CTA.label}</Link>
          </Button>

          <MobileNav />
        </div>
      </div>
    </header>
  );
}
