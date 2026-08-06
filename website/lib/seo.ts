import type { Metadata } from 'next';
import { SITE_URL } from '@/lib/api/client';
import { BRAND, CONTACT } from '@/content/site';
import type { Crumb } from '@/components/site/page-hero';

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
}: {
  title: string;
  description: string;
  path: string;
}): Metadata {
  return {
    title,
    description,
    alternates: { canonical: path },
    openGraph: {
      title: `${title} | ${BRAND.name}`,
      description,
      url: path,
      type: 'website',
      siteName: BRAND.name,
      locale: 'tr_TR',
    },
    twitter: {
      card: 'summary_large_image',
      title: `${title} | ${BRAND.name}`,
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
 * `content/site.ts` içindeki adres ve telefon doldurulduğunda şema
 * kendiliğinden `LocalBusiness`'a yükseliyor ve alanlar ekleniyor.
 */
export function organizationJsonLd(): Record<string, unknown> {
  const hasPhysicalPresence = CONTACT.address !== null && CONTACT.phone !== null;

  const base: Record<string, unknown> = {
    '@context': 'https://schema.org',
    '@type': hasPhysicalPresence ? 'FoodEstablishment' : 'Organization',
    name: BRAND.name,
    alternateName: BRAND.shortName,
    description: BRAND.description,
    url: SITE_URL,
    parentOrganization: { '@type': 'Organization', name: BRAND.parentGroup },
  };

  if (CONTACT.phone) base.telephone = CONTACT.phone.display;
  if (CONTACT.email) base.email = CONTACT.email.display.replace(/^mailto:/, '');

  if (CONTACT.address) {
    base.address = {
      '@type': 'PostalAddress',
      streetAddress: CONTACT.address.streetAddress,
      addressLocality: CONTACT.address.district,
      addressRegion: CONTACT.address.city,
      ...(CONTACT.address.postalCode ? { postalCode: CONTACT.address.postalCode } : {}),
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
}: {
  name: string;
  description: string;
  path: string;
}): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'Service',
    name,
    description,
    serviceType: 'Catering',
    url: `${SITE_URL}${path}`,
    areaServed: { '@type': 'Country', name: 'Türkiye' },
    provider: { '@type': 'Organization', name: BRAND.name, url: SITE_URL },
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
}: {
  title: string;
  description: string;
  path: string;
  publishedAt: string;
}): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'Article',
    headline: title,
    description,
    datePublished: publishedAt,
    mainEntityOfPage: { '@type': 'WebPage', '@id': `${SITE_URL}${path}` },
    author: { '@type': 'Organization', name: BRAND.name },
    publisher: { '@type': 'Organization', name: BRAND.name },
  };
}
