import type { Metadata, Viewport } from 'next';
import { Inter } from 'next/font/google';
import { NextIntlClientProvider } from 'next-intl';
import { getMessages, getTranslations } from 'next-intl/server';
import { SiteFooter } from '@/components/site-footer';
import { SiteHeader } from '@/components/site-header';
import { SITE_URL } from '@/lib/api/client';
import './globals.css';

const inter = Inter({
  subsets: ['latin', 'latin-ext'],
  display: 'swap',
  variable: '--font-inter',
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
  themeColor: '#F97316',
  width: 'device-width',
  initialScale: 1,
};

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const [messages, t] = await Promise.all([getMessages(), getTranslations('nav')]);

  return (
    <html lang="tr" className={inter.variable}>
      <body className="flex min-h-dvh flex-col">
        <NextIntlClientProvider messages={messages}>
          <a
            href="#icerik"
            className="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-50 focus:rounded-md focus:bg-brand-700 focus:px-4 focus:py-2 focus:text-neutral-0"
          >
            {t('skipToContent')}
          </a>
          <SiteHeader />
          <main id="icerik" className="flex-1">
            {children}
          </main>
          <SiteFooter />
        </NextIntlClientProvider>
      </body>
    </html>
  );
}
