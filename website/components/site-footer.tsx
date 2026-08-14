import Link from 'next/link';
import { Clock, Mail, MapPin, MessageCircle, Phone } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { BrandMark } from '@/components/site/brand-mark';
import { FOOTER_NAV, LEGAL_NAV, PRIMARY_CTA } from '@/content/navigation';
import { fetchSiteContent } from '@/lib/api/site-content';

/**
 * Site altbilgisi.
 *
 * İletişim bloğundaki her satır panelden gelen değere bağlı ve değer `null`
 * ise satır **hiç basılmaz**. Böylece "Telefon: —" gibi boş kalıplar veya
 * uydurma bir numara ortaya çıkmıyor.
 *
 * API kapalıyken `fetchSiteContent` yedeğe düşüyor; altbilgi bağlantıları her
 * hâlükârda basılıyor — sitenin ikinci gezinme katmanı bir ağ hatasıyla
 * kaybolmamalı.
 */
export async function SiteFooter() {
  const year = new Date().getFullYear();
  const { brand, contact } = await fetchSiteContent();

  return (
    <footer className="mt-auto bg-neutral-950 text-neutral-50">
      <div className="mx-auto max-w-content px-4 py-14 sm:px-6 sm:py-16">
        <div className="grid gap-10 lg:grid-cols-[1.4fr_1fr_1fr_1fr]">
          <div>
            {/* Sözcük işareti altta ayrı basılıyor: amblem + iki satırlık
                işaret yan yana, altbilgi sütununda marka adını ikinci kez
                yazıyordu. */}
            <BrandMark showWordmark={false} brandName={brand.name} logoSrc={brand.logoSrc} />
            <p className="mt-4 font-display text-h3 font-semibold">{brand.name}</p>
            <p className="mt-2 max-w-sm text-body text-pretty text-neutral-50/70">
              {brand.tagline}
            </p>

            <address className="mt-6 space-y-3 text-body not-italic">
              {contact.phone && (
                <a
                  href={contact.phone.href}
                  className="flex min-h-11 items-center gap-3 transition-colors duration-(--duration-fast) hover:text-brand-300"
                >
                  <Phone aria-hidden="true" strokeWidth={1.75} className="size-4 shrink-0" />
                  {contact.phone.display}
                </a>
              )}
              {contact.whatsapp && (
                <a
                  href={contact.whatsapp.href}
                  className="flex min-h-11 items-center gap-3 transition-colors duration-(--duration-fast) hover:text-brand-300"
                >
                  <MessageCircle
                    aria-hidden="true"
                    strokeWidth={1.75}
                    className="size-4 shrink-0"
                  />
                  WhatsApp
                </a>
              )}
              {contact.email && (
                <a
                  href={contact.email.href}
                  className="flex min-h-11 items-center gap-3 transition-colors duration-(--duration-fast) hover:text-brand-300"
                >
                  <Mail aria-hidden="true" strokeWidth={1.75} className="size-4 shrink-0" />
                  {contact.email.display}
                </a>
              )}
              {contact.address && (
                <p className="flex items-start gap-3 text-neutral-50/70">
                  <MapPin
                    aria-hidden="true"
                    strokeWidth={1.75}
                    className="mt-0.5 size-4 shrink-0"
                  />
                  <span>
                    {contact.address.streetAddress}
                    <br />
                    {contact.address.district} / {contact.address.city}
                  </span>
                </p>
              )}
              {contact.workingHours.length > 0 && (
                <p className="flex items-start gap-3 text-neutral-50/70">
                  <Clock aria-hidden="true" strokeWidth={1.75} className="mt-0.5 size-4 shrink-0" />
                  <span>
                    {contact.workingHours.map((entry) => (
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
              <p className="text-label">{group.title}</p>
              <ul className="mt-4 space-y-1">
                {group.links.map((link) => (
                  <li key={link.href}>
                    <Link
                      href={link.href}
                      className="flex min-h-9 items-center text-body text-neutral-50/70 transition-colors duration-(--duration-fast) hover:text-brand-300"
                    >
                      {link.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </nav>
          ))}
        </div>

        <div className="mt-12 flex flex-col gap-6 border-t border-neutral-50/15 pt-8 sm:flex-row sm:items-center sm:justify-between">
          <p className="max-w-md text-body-sm text-neutral-50/70">
            {brand.name}, {brand.parentGroup} şirket ailesinin catering markasıdır.
          </p>

          {/* Altbilgi her iki temada da KOYU: dolgu marka kılavuzunun koyu
              tema birincili (brand300 + koyu yazı), açık temanınki değil. */}
          <Button asChild className="bg-brand-300 text-neutral-950 hover:bg-brand-200">
            <Link href={PRIMARY_CTA.href}>{PRIMARY_CTA.label}</Link>
          </Button>
        </div>

        <div className="mt-8 flex flex-col gap-4 border-t border-neutral-50/15 pt-6 sm:flex-row sm:items-center sm:justify-between">
          <p className="text-body-sm text-neutral-50/70">
            © {year} {brand.name}. Tüm hakları saklıdır.
          </p>

          <nav aria-label="Yasal bağlantılar">
            <ul className="flex flex-wrap gap-x-5 gap-y-2">
              {LEGAL_NAV.map((link) => (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    className="text-body-sm text-neutral-50/70 transition-colors duration-(--duration-fast) hover:text-neutral-50"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </nav>

          {contact.social.length > 0 && (
            <ul className="flex gap-4">
              {contact.social.map((item) => (
                <li key={item.href}>
                  <a
                    href={item.href}
                    className="text-body-sm text-neutral-50/70 transition-colors duration-(--duration-fast) hover:text-neutral-50"
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
