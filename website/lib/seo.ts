import type { Metadata } from 'next';
import { SITE_URL } from '@/lib/api/client';
import { BRAND, CONTACT, type PostalAddress } from '@/content/site';
import type { Crumb } from '@/components/site/page-hero';

/**
 * Sayfa metadata'sı ve şema üreticileri.
 *
 * ## Neden marka/iletişim bilgisi parametre?
 *
 * İçeriğin tek kaynağı artık admin paneli (`lib/api/site-content.ts`) ve o
 * yalnızca sunucuda, `await` ile okunabiliyor. Buradaki fonksiyonlar ise
 * bazı sayfalarda modül düzeyinde (`export const metadata = ...`) çağrılıyor;
 * hepsini zorla `async` yapmak, içeriği API'den beslenmeyen hukuki sayfaları da
 * gereksizce dinamikleştirirdi.
 *
 * Çözüm: değerler **parametre** olarak geçiyor, verilmediğinde `content/site.ts`
 * yedeğine düşüyor. İçeriğe bağlı sayfalar `generateMetadata` içinde panelden
 * geleni veriyor; geri kalanı bugünkü davranışını aynen sürdürüyor.
 */

/** Şema/metadata için gereken en küçük marka yüzeyi. */
export type SeoBrand = {
  readonly name: string;
  readonly shortName: string;
  readonly parentGroup: string;
  readonly description: string;
};

/** Şema için gereken en küçük iletişim yüzeyi. */
export type SeoContact = {
  readonly phone: { readonly display: string } | null;
  readonly email: { readonly display: string } | null;
  readonly address: PostalAddress | null;
};

const FALLBACK_BRAND: SeoBrand = BRAND;
const FALLBACK_CONTACT: SeoContact = CONTACT;

/**
 * Sayfa metadata'sı üretici.
 *
 * Her sayfada aynı `openGraph` bloğunu elle yazmak, er ya da geç birinin
 * canonical'ı unutmasıyla bitiyor. Tek giriş noktası bunu engelliyor.
 */
export function pageMetadata({
  title,
  description,
  path,
  brandName = FALLBACK_BRAND.name,
}: {
  title: string;
  description: string;
  path: string;
  brandName?: string;
}): Metadata {
  return {
    title,
    description,
    alternates: { canonical: path },
    openGraph: {
      title: `${title} | ${brandName}`,
      description,
      url: path,
      type: 'website',
      siteName: brandName,
      locale: 'tr_TR',
    },
    twitter: {
      card: 'summary_large_image',
      title: `${title} | ${brandName}`,
      description,
    },
  };
}

/** Görsel breadcrumb ile aynı diziden üretilen `BreadcrumbList`. */
export function breadcrumbJsonLd(crumbs: readonly Crumb[]): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: [
      { '@type': 'ListItem', position: 1, name: 'Ana Sayfa', item: SITE_URL },
      ...crumbs.map((crumb, index) => ({
        '@type': 'ListItem',
        position: index + 2,
        name: crumb.label,
        item: `${SITE_URL}${crumb.href}`,
      })),
    ],
  };
}

/**
 * Kurum şeması.
 *
 * `LocalBusiness` DEĞİL, `Organization` kullanılıyor: `LocalBusiness` şeması
 * adres ve telefon bekler ve arama motorları bunu harita/yerel sonuçlarda
 * gösterir. Doğrulanmamış adresle bu şemayı yayınlamak, kullanıcıyı var
 * olmayan bir yere yönlendirmek demek.
 *
 * Panelde adres ve telefon doldurulduğunda şema kendiliğinden
 * `FoodEstablishment`'a yükseliyor ve alanlar ekleniyor.
 */
export function organizationJsonLd(
  brand: SeoBrand = FALLBACK_BRAND,
  contact: SeoContact = FALLBACK_CONTACT,
): Record<string, unknown> {
  const hasPhysicalPresence = contact.address !== null && contact.phone !== null;

  const base: Record<string, unknown> = {
    '@context': 'https://schema.org',
    '@type': hasPhysicalPresence ? 'FoodEstablishment' : 'Organization',
    name: brand.name,
    alternateName: brand.shortName,
    description: brand.description,
    url: SITE_URL,
    parentOrganization: { '@type': 'Organization', name: brand.parentGroup },
  };

  if (contact.phone) base.telephone = contact.phone.display;
  if (contact.email) base.email = contact.email.display.replace(/^mailto:/, '');

  if (contact.address) {
    base.address = {
      '@type': 'PostalAddress',
      streetAddress: contact.address.streetAddress,
      addressLocality: contact.address.district,
      addressRegion: contact.address.city,
      ...(contact.address.postalCode ? { postalCode: contact.address.postalCode } : {}),
      addressCountry: 'TR',
    };
  }

  return base;
}

/** Hizmet detay sayfaları için `Service` şeması. */
export function serviceJsonLd({
  name,
  description,
  path,
  brandName = FALLBACK_BRAND.name,
}: {
  name: string;
  description: string;
  path: string;
  brandName?: string;
}): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'Service',
    name,
    description,
    serviceType: 'Catering',
    url: `${SITE_URL}${path}`,
    areaServed: { '@type': 'Country', name: 'Türkiye' },
    provider: { '@type': 'Organization', name: brandName, url: SITE_URL },
  };
}

/** SSS bölümleri için `FAQPage`. */
export function faqJsonLd(
  items: readonly { readonly question: string; readonly answer: string }[],
): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: items.map((item) => ({
      '@type': 'Question',
      name: item.question,
      acceptedAnswer: { '@type': 'Answer', text: item.answer },
    })),
  };
}

/** Bilgi merkezi yazıları için `Article`. */
export function articleJsonLd({
  title,
  description,
  path,
  publishedAt,
  brandName = FALLBACK_BRAND.name,
}: {
  title: string;
  description: string;
  path: string;
  publishedAt: string;
  brandName?: string;
}): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'Article',
    headline: title,
    description,
    datePublished: publishedAt,
    mainEntityOfPage: { '@type': 'WebPage', '@id': `${SITE_URL}${path}` },
    author: { '@type': 'Organization', name: brandName },
    publisher: { '@type': 'Organization', name: brandName },
  };
}
