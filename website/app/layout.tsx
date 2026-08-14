import type { Metadata, Viewport } from 'next';
import { Inter, Source_Serif_4 } from 'next/font/google';
import { SiteFooter } from '@/components/site-footer';
import { SiteHeader } from '@/components/site-header';
import { QuickContact } from '@/components/site/quick-contact';
import { ThemeProvider } from '@/components/theme-provider';
import { getTranslations } from 'next-intl/server';
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
 * Başlıklar — Source Serif 4.
 *
 * NEDEN PLAYFAIR DEĞİL: Playfair bir Didone; kalın-ince farkı çok yüksek,
 * tırnakları saç inceliğinde. Logo ise dirsekli tırnaklı, DÜŞÜK kontrastlı
 * bir hümanist serif — ikisi yan yana aynı markadanmış gibi durmuyordu.
 * Source Serif 4 aynı sınıftan, Türkçe kapsaması tam (İ/ı dahil), OFL.
 *
 * Üç kalınlık yükleniyor (400/600/700): 500 hiçbir yerde kullanılmıyordu ve
 * her ek kalınlık ayrı bir dosya indiriyor. `display: swap` ile ilk boyamada
 * Georgia'ya düşer, LCP başlığı beklemez (docs/06 §7).
 */
const sourceSerif = Source_Serif_4({
  subsets: ['latin', 'latin-ext'],
  display: 'swap',
  weight: ['400', '600', '700'],
  variable: '--font-source-serif',
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
    { media: '(prefers-color-scheme: light)', color: '#FAF6F0' },
    { media: '(prefers-color-scheme: dark)', color: '#1B120C' },
  ],
  width: 'device-width',
  initialScale: 1,
};

/**
 * Kök yerleşim.
 *
 * `NextIntlClientProvider` BİLİNÇLİ OLARAK YOK. Sitede istemci tarafında
 * çeviri okuyan hiçbir bileşen kalmadı (tek kullanıcı `HeaderActions`'tı,
 * metinleri artık prop olarak alıyor). Sağlayıcı burada dururken next-intl'in
 * ICU biçimlendirme çalışma zamanı sitedeki her sayfaya iniyordu.
 *
 * Sunucu tarafı çeviri (`getTranslations`) etkilenmez; o istemciye hiçbir şey
 * göndermez.
 */
export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const t = await getTranslations('nav');

  return (
    // `suppressHydrationWarning`: next-themes sunucuda bilinemeyen temayı
    // `<html>` sınıfına istemcide yazar, aradaki fark uyarı üretir.
    <html lang="tr" className={cn(inter.variable, sourceSerif.variable)} suppressHydrationWarning>
      <body className="flex min-h-dvh flex-col">
        <ThemeProvider>
          <a
            href="#icerik"
            className="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 focus:z-50 focus:rounded-md focus:bg-primary focus:px-4 focus:py-2 focus:text-primary-foreground"
          >
            {t('skipToContent')}
          </a>
          <SiteHeader />
          <main id="icerik" className="flex-1">
            {children}
          </main>
          <SiteFooter />
          <QuickContact />
        </ThemeProvider>
      </body>
    </html>
  );
}
