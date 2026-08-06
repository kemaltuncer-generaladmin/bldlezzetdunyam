import Link from 'next/link';
import { Clock, Mail, MapPin, MessageCircle, Phone } from 'lucide-react';
import { BrandMark } from '@/components/site/brand-mark';
import { FOOTER_NAV, LEGAL_NAV, PRIMARY_CTA } from '@/content/navigation';
import { BRAND, CONTACT, SOCIAL } from '@/content/site';

/**
 * Site altbilgisi.
 *
 * İletişim bloğundaki her satır `content/site.ts` içindeki değere bağlı ve
 * değer `null` ise satır **hiç basılmaz**. Böylece "Telefon: —" gibi boş
 * kalıplar veya uydurma bir numara ortaya çıkmıyor.
 */
export function SiteFooter() {
  const year = new Date().getFullYear();

  return (
    <footer className="mt-auto bg-charcoal text-cream">
      <div className="mx-auto max-w-content px-4 py-14 sm:px-6 sm:py-16">
        <div className="grid gap-10 lg:grid-cols-[1.4fr_1fr_1fr_1fr]">
          <div>
            {/* Koyu zeminde harf işareti okunur kalsın diye sözcük işareti ayrı basılıyor. */}
            <BrandMark showWordmark={false} />
            <p className="mt-4 font-display text-lg font-semibold">{BRAND.name}</p>
            <p className="mt-2 max-w-sm text-sm/6 text-cream/70">{BRAND.tagline}</p>

            <address className="mt-6 space-y-3 text-sm not-italic">
              {CONTACT.phone && (
                <a
                  href={CONTACT.phone.href}
                  className="flex min-h-11 items-center gap-3 transition-colors hover:text-brand-300"
                >
                  <Phone aria-hidden="true" className="size-4 shrink-0" />
                  {CONTACT.phone.display}
                </a>
              )}
              {CONTACT.whatsapp && (
                <a
                  href={CONTACT.whatsapp.href}
                  className="flex min-h-11 items-center gap-3 transition-colors hover:text-brand-300"
                >
                  <MessageCircle aria-hidden="true" className="size-4 shrink-0" />
                  WhatsApp
                </a>
              )}
              {CONTACT.email && (
                <a
                  href={CONTACT.email.href}
                  className="flex min-h-11 items-center gap-3 transition-colors hover:text-brand-300"
                >
                  <Mail aria-hidden="true" className="size-4 shrink-0" />
                  {CONTACT.email.display}
                </a>
              )}
              {CONTACT.address && (
                <p className="flex items-start gap-3 text-cream/70">
                  <MapPin aria-hidden="true" className="mt-0.5 size-4 shrink-0" />
                  <span>
                    {CONTACT.address.streetAddress}
                    <br />
                    {CONTACT.address.district} / {CONTACT.address.city}
                  </span>
                </p>
              )}
              {CONTACT.workingHours.length > 0 && (
                <p className="flex items-start gap-3 text-cream/70">
                  <Clock aria-hidden="true" className="mt-0.5 size-4 shrink-0" />
                  <span>
                    {CONTACT.workingHours.map((entry) => (
                      <span key={entry.label} className="block">
                        {entry.label}: {entry.value}
                      </span>
                    ))}
                  </span>
                </p>
              )}
            </address>
          </div>

          {FOOTER_NAV.map((group) => (
            <nav key={group.title} aria-label={group.title}>
              <p className="text-sm font-semibold">{group.title}</p>
              <ul className="mt-4 space-y-1">
                {group.links.map((link) => (
                  <li key={link.href}>
                    <Link
                      href={link.href}
                      className="flex min-h-9 items-center text-sm text-cream/70 transition-colors hover:text-brand-300"
                    >
                      {link.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </nav>
          ))}
        </div>

        <div className="mt-12 flex flex-col gap-6 border-t border-cream/15 pt-8 sm:flex-row sm:items-center sm:justify-between">
          <p className="max-w-md text-xs/5 text-cream/60">
            {BRAND.name}, {BRAND.parentGroup} şirket ailesinin catering markasıdır.
          </p>

          <Link
            href={PRIMARY_CTA.href}
            className="inline-flex min-h-11 items-center justify-center rounded-lg bg-brand-500 px-6 text-sm font-semibold text-charcoal transition-colors hover:bg-brand-400"
          >
            {PRIMARY_CTA.label}
          </Link>
        </div>

        <div className="mt-8 flex flex-col gap-4 border-t border-cream/15 pt-6 sm:flex-row sm:items-center sm:justify-between">
          <p className="text-xs text-cream/60">
            © {year} {BRAND.name}. Tüm hakları saklıdır.
          </p>

          <nav aria-label="Yasal bağlantılar">
            <ul className="flex flex-wrap gap-x-5 gap-y-2">
              {LEGAL_NAV.map((link) => (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    className="text-xs text-cream/60 transition-colors hover:text-cream"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </nav>

          {SOCIAL.length > 0 && (
            <ul className="flex gap-4">
              {SOCIAL.map((item) => (
                <li key={item.href}>
                  <a
                    href={item.href}
                    className="text-xs text-cream/60 transition-colors hover:text-cream"
                    rel="noopener noreferrer"
                    target="_blank"
                  >
                    {item.label}
                  </a>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </footer>
  );
}
