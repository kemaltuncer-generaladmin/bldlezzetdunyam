'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { ShoppingCart } from 'lucide-react';
import { readBrowserCookie } from '@/lib/browser-cookie';
import { CART_COUNT_COOKIE, subscribeCartChanged } from '@/lib/cart-events';
import { isOrderingRoute } from '@/content/navigation';

const SESSION_NAME_COOKIE = 'bld_name';

/**
 * Sipariş akışı için sepet rozeti ve oturum bağlantısı.
 *
 * ## Ne zaman görünür?
 *
 * Site iki işi birden yapıyor: kurumsal tanıtım ve sipariş. Kurumsal
 * ziyaretçinin (teklif arayan bir satın alma sorumlusu) ilk gördüğü şeyin
 * "Sepet" olması, firmayı yemek sipariş sitesi gibi gösteriyordu. Rozeti
 * tamamen silmek de doğru değildi: sipariş akışı çalışıyor.
 *
 * İKİ KOŞULDAN BİRİ YETER:
 *   * sipariş rotalarındayız (`/menu`, `/sepet`, `/odeme` …), ya da
 *   * sepette ürün var.
 *
 * İkinci koşul v2.0'da eklendi (W-10): ana sayfadaki menüden sepete ürün
 * eklenebiliyor ve o üründen sonra ziyaretçi hangi sayfaya giderse gitsin
 * sepetini görebilmeli. Boş sepette kurumsal sayfalar eskisi gibi rozetsiz.
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

  const onOrderingRoute = isOrderingRoute(pathname);

  /*
   * ÇEREZ HER ROTADA OKUNUYOR, YALNIZ SİPARİŞ ROTALARINDA DEĞİL (W-10).
   *
   * v2.0'da ana sayfadaki "bugün mutfakta" bölümünden sepete ürün
   * eklenebiliyor. Okuma eskisi gibi rotaya bağlı kalsaydı, ürün ekleyen
   * ziyaretçi rozeti hiç görmez ve sepetinin var olduğunu ancak `/menu`ye
   * gidince fark ederdi.
   *
   * Bu bir ISR sorunu YARATMAZ: çerez sunucuda değil tarayıcıda okunuyor,
   * yani `/` ve `/kurumsal` statik kalmaya devam ediyor.
   *
   * ## ÇEREZ İZLENİYOR, HABER BEKLENMİYOR
   *
   * Sayaç eskiden yalnızca `bld:cart-changed` olayıyla ve `focus` ile
   * tazeleniyordu. İkisi de sepete ekleme eyleminin İSTEMCİ TARAFINDAKİ başarı
   * dalına bağlıydı: o dal geç çalıştığında rozet, doğru değeri taşıyan çerez
   * tarayıcıda dururken bile saniyelerce "Sepetiniz boş" diyordu — ölçülmüş,
   * müşteriye görünen bir hata. `subscribeCartChanged` artık çerezin kendisini
   * de izliyor; rozetin doğruluğu React'in eylemi ne zaman commit ettiğinden
   * bağımsız (gerekçe ve ölçüm `lib/cart-events.ts`).
   */
  useEffect(() => {
    const sync = () => {
      const rawCount = readBrowserCookie(CART_COUNT_COOKIE);
      const parsed = rawCount === null ? 0 : Number.parseInt(rawCount, 10);
      setCartCount(Number.isFinite(parsed) && parsed > 0 ? parsed : 0);
      setFirstName(readBrowserCookie(SESSION_NAME_COOKIE));
    };

    sync();
    return subscribeCartChanged(sync);
  }, [pathname]);

  /*
   * Kurumsal sayfalarda rozet YALNIZCA sepette ürün varken çıkıyor.
   *
   * Teklif arayan bir satın alma sorumlusunun ilk gördüğü şey "Sepet"
   * olmamalı (bileşenin başındaki gerekçe) — ama sepetinde üç ürün olan
   * birinden o sepeti saklamak da yanlış: hangi sayfaya giderse gitsin
   * bıraktığı yerden devam edebilmeli.
   */
  if (!onOrderingRoute && cartCount === 0) return null;

  return (
    <div className="flex items-center gap-1 sm:gap-2">
      <Link
        href="/sepet"
        className="relative flex min-h-11 items-center gap-2 rounded-md px-2 text-sm font-medium text-foreground/80 transition-colors hover:bg-muted sm:px-3"
      >
        <ShoppingCart strokeWidth={1.75} aria-hidden="true" className="size-5" />
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
