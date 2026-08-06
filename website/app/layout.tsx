import type { Metadata, Viewport } from 'next';
import { Inter, Playfair_Display } from 'next/font/google';
import { NextIntlClientProvider } from 'next-intl';
import { SiteFooter } from '@/components/site-footer';
import { SiteHeader } from '@/components/site-header';
import { ThemeProvider } from '@/components/theme-provider';
import { getMessages, getTranslations } from 'next-intl/server';
import { SITE_URL } from '@/lib/api/client';
import { cn } from '@/lib/utils';
import './globals.css';

/* Gövde, form ve fiyat. `latin-ext` Türkçe için zorunlu (ı, ş, ğ, ç, ö, ü). */
const inter = Inter({
  subsets: ['latin', 'latin-ext'],
  display: 'swap',
  variable: '--font-inter',
});

/*
 * Başlıklar. Yalnızca 400–700 aralığı yükleniyor: Playfair'in tamamı ~4×
 * daha ağır ve başlıkta ara kalınlıkları kullanmıyoruz. `display: swap` ile
 * ilk boyamada Georgia'ya düşer, LCP başlığı beklemez (docs/06 §7).
 */
const playfair = Playfair_Display({
  subsets: ['latin', 'latin-ext'],
  display: 'swap',
  weight: ['400', '500', '600', '700'],
  variable: '--font-playfair',
});

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: 'Benim Lezzet Dünyam — Kurumsal Catering ve Günlük Yemek',
    template: '%s | Benim Lezzet Dünyam',
  },
  description:
    'Kurumlara ve topluluklara günlük taze catering. Menüyü inceleyin, adrese teslim veya gel-al olarak sipariş verin.',
  applicationName: 'Benim Lezzet Dünyam',
  openGraph: {
    type: 'website',
    locale: 'tr_TR',
    siteName: 'Benim Lezzet Dünyam',
    url: SITE_URL,
  },
  robots: { index: true, follow: true },
};

export const viewport: Viewport = {
  /*
   * Adres çubuğu rengi sayfa zeminiyle aynı (`--background`). Tek bir marka
   * rengi verseydik karanlık temada çubuk turuncu, sayfa koyu kalır ve arayüz
   * bozuk görünürdü.
   */
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '#FAFAF9' },
    { media: '(prefers-color-scheme: dark)', color: '#1C1917' },
  ],
  width: 'device-width',
  initialScale: 1,
};

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const [messages, t] = await Promise.all([getMessages(), getTranslations('nav')]);

  return (
    // `suppressHydrationWarning`: next-themes sunucuda bilinemeyen temayı
    // `<html>` sınıfına istemcide yazar, aradaki fark uyarı üretir.
    <html lang="tr" className={cn(inter.variable, playfair.variable)} suppressHydrationWarning>
      <body className="flex min-h-dvh flex-col">
        <ThemeProvider>
          <NextIntlClientProvider messages={messages}>
            <a
              href="#icerik"
              className="focus:bg-primary focus:text-primary-foreground sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 focus:z-50 focus:rounded-md focus:px-4 focus:py-2"
            >
              {t('skipToContent')}
            </a>
            <SiteHeader />
            <main id="icerik" className="flex-1">
              {children}
            </main>
            <SiteFooter />
          </NextIntlClientProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
