import Link from 'next/link';
import { getTranslations } from 'next-intl/server';
import { Phone } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { HeaderActions } from '@/components/header-actions';
import { BrandMark } from '@/components/site/brand-mark';
import { HeaderShell } from '@/components/site/header-shell';
import { MainNav } from '@/components/site/main-nav';
import { MobileNav } from '@/components/site/mobile-nav';
import { PRIMARY_CTA } from '@/content/navigation';
import { fetchSiteContent } from '@/lib/api/site-content';

/**
 * Site başlığı.
 *
 * Bilinçli olarak **oturumsuz**: cookie okumaz, oturum sorgulamaz. Böylece `/`,
 * `/hizmetler` ve diğer pazarlama sayfaları statik/ISR kalabiliyor. Sipariş
 * akışına ait sepet rozeti ve oturum adı artık başlıkta değil — kurumsal
 * ziyaretçinin ilk gördüğü şey sepet olmamalı; sipariş akışına footer ve
 * `/menu` üzerinden giriliyor.
 *
 * Marka ve iletişim bilgisi panelden geliyor. `fetchSiteContent` hata
 * fırlatmıyor: API kapalıysa yedek içerikle aynı başlık basılır, başlık
 * hiçbir koşulda kaybolmaz.
 */
export async function SiteHeader() {
  const t = await getTranslations('nav');
  const { brand, contact } = await fetchSiteContent();

  return (
    <HeaderShell>
      <div className="mx-auto flex h-18 max-w-content items-center gap-3 px-4 sm:px-6">
        <Link
          href="/"
          aria-label={`${brand.name} — ana sayfa`}
          className="shrink-0 rounded-md focus-visible:ring-2"
        >
          <BrandMark
            brandName={brand.name}
            brandShortName={brand.shortName}
            logoSrc={brand.logoSrc}
          />
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

          {contact.phone && (
            <Button asChild variant="ghost" size="sm" className="hidden xl:inline-flex">
              <a href={contact.phone.href}>
                <Phone aria-hidden="true" />
                {contact.phone.display}
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

          {/*
           * İstemci bileşeni: panelden gelen değerler prop olarak iniyor.
           * İkonlar burada seçilemez (bileşen referansı istemciye
           * gönderilemez), bu yüzden kanal türü metin olarak geçiyor.
           */}
          <MobileNav
            brandName={brand.name}
            brandShortName={brand.shortName}
            logoSrc={brand.logoSrc}
            channels={[
              contact.phone && { kind: 'phone' as const, ...contact.phone },
              contact.whatsapp && { kind: 'whatsapp' as const, ...contact.whatsapp },
              contact.email && { kind: 'email' as const, ...contact.email },
            ].filter((channel) => channel !== null)}
          />
        </div>
      </div>
    </HeaderShell>
  );
}
