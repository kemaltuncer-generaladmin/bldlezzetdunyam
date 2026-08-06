import Link from 'next/link';
import { ArrowRight, Clock, Info, Mail, MapPin, MessageCircle, Phone } from 'lucide-react';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Button } from '@/components/ui/button';
import { JsonLd } from '@/components/json-ld';
import { PageHero, type Crumb } from '@/components/site/page-hero';
import { Section, SectionHeading } from '@/components/site/section';
import {
  fetchSiteContent,
  hasAnyContactChannel,
  pendingContactFields,
} from '@/lib/api/site-content';
import { breadcrumbJsonLd, organizationJsonLd, pageMetadata } from '@/lib/seo';

export async function generateMetadata() {
  const { brand } = await fetchSiteContent();

  return pageMetadata({
    title: 'İletişim',
    description: `${brand.name} ile iletişime geçin. Kurumsal catering, toplu yemek ve organizasyon talepleriniz için bize ulaşın.`,
    path: '/iletisim',
    brandName: brand.name,
  });
}

const CRUMBS: readonly Crumb[] = [{ href: '/iletisim', label: 'İletişim' }];

export default async function IletisimPage() {
  const { brand, contact } = await fetchSiteContent();
  const pending = pendingContactFields(contact);

  return (
    <>
      <JsonLd data={breadcrumbJsonLd(CRUMBS)} />
      <JsonLd data={organizationJsonLd(brand, contact)} />

      <PageHero
        crumbs={CRUMBS}
        eyebrow="İletişim"
        title="Bize ulaşın"
        description="Teklif talepleri, mevcut hizmetleriniz ve genel sorularınız için aşağıdaki kanallardan bize ulaşabilirsiniz."
      />

      <Section aria-labelledby="kanallar-baslik">
        <SectionHeading id="kanallar-baslik" title="İletişim kanalları" level={2} />

        {/*
         * İletişim bilgileri henüz girilmemiş.
         *
         * Uydurma telefon veya adres basmak yerine durumu açıkça söylüyoruz:
         * ziyaretçi neden numara göremediğini anlıyor ve teklif formuna
         * yönlendiriliyor — yani sayfa boş kalmıyor, akış kesilmiyor.
         *
         * Panelde ilgili alanlar doldurulduğunda bu uyarı kendiliğinden
         * kaybolur.
         */}
        {pending.length > 0 && (
          <Alert className="mt-8 max-w-3xl">
            <Info aria-hidden="true" />
            <AlertTitle>İletişim bilgileri henüz yayınlanmadı</AlertTitle>
            <AlertDescription>
              <p>
                Şu alanlar sitede henüz tanımlı değil: {pending.join(', ')}. Bu bilgiler girilene
                kadar bize ulaşmanın en hızlı yolu teklif formu — talebinizi bırakın, size dönelim.
              </p>
            </AlertDescription>
          </Alert>
        )}

        <div className="mt-10 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {contact.phone && (
            <a
              href={contact.phone.href}
              className="group rounded-2xl border bg-card p-6 transition-colors hover:border-primary/40"
            >
              <Phone aria-hidden="true" className="size-5 text-primary" />
              <h3 className="mt-4 font-display text-base font-semibold">Telefon</h3>
              <p className="mt-1 text-sm text-muted-foreground">{contact.phone.display}</p>
            </a>
          )}

          {contact.whatsapp && (
            <a
              href={contact.whatsapp.href}
              className="group rounded-2xl border bg-card p-6 transition-colors hover:border-primary/40"
            >
              <MessageCircle aria-hidden="true" className="size-5 text-primary" />
              <h3 className="mt-4 font-display text-base font-semibold">WhatsApp</h3>
              <p className="mt-1 text-sm text-muted-foreground">{contact.whatsapp.display}</p>
            </a>
          )}

          {contact.email && (
            <a
              href={contact.email.href}
              className="group rounded-2xl border bg-card p-6 transition-colors hover:border-primary/40"
            >
              <Mail aria-hidden="true" className="size-5 text-primary" />
              <h3 className="mt-4 font-display text-base font-semibold">E-posta</h3>
              <p className="mt-1 text-sm text-muted-foreground">{contact.email.display}</p>
            </a>
          )}

          {contact.address && (
            <div className="rounded-2xl border bg-card p-6">
              <MapPin aria-hidden="true" className="size-5 text-primary" />
              <h3 className="mt-4 font-display text-base font-semibold">Adres</h3>
              <address className="mt-1 text-sm/6 text-muted-foreground not-italic">
                {contact.address.streetAddress}
                <br />
                {contact.address.district} / {contact.address.city}
                {contact.address.postalCode && <> · {contact.address.postalCode}</>}
              </address>
            </div>
          )}

          {contact.workingHours.length > 0 && (
            <div className="rounded-2xl border bg-card p-6">
              <Clock aria-hidden="true" className="size-5 text-primary" />
              <h3 className="mt-4 font-display text-base font-semibold">Çalışma saatleri</h3>
              <dl className="mt-1 space-y-1 text-sm text-muted-foreground">
                {contact.workingHours.map((entry) => (
                  <div key={entry.label} className="flex justify-between gap-4">
                    <dt>{entry.label}</dt>
                    <dd>{entry.value}</dd>
                  </div>
                ))}
              </dl>
            </div>
          )}

          <div className="rounded-2xl border bg-surface-warm p-6 text-surface-warm-foreground">
            <ArrowRight aria-hidden="true" className="size-5 text-primary" />
            <h3 className="mt-4 font-display text-base font-semibold">Teklif talebi</h3>
            <p className="mt-1 text-sm/6 opacity-80">
              İhtiyacınızı iletin, menü önerisi ve fiyatlandırmayla dönelim.
            </p>
            <Button asChild size="sm" className="mt-4">
              <Link href="/teklif-al">Teklif Al</Link>
            </Button>
          </div>
        </div>
      </Section>

      {/* Harita yalnızca gerçek bir gömme adresi girildiyse. */}
      {contact.address?.mapEmbedUrl && (
        <Section tone="muted" aria-labelledby="harita-baslik">
          <SectionHeading id="harita-baslik" title="Nasıl gelinir?" level={2} />
          <div className="mt-8 aspect-video overflow-hidden rounded-2xl border">
            <iframe
              src={contact.address.mapEmbedUrl}
              title={`${brand.name} konum haritası`}
              loading="lazy"
              referrerPolicy="no-referrer-when-downgrade"
              className="size-full border-0"
            />
          </div>
        </Section>
      )}

      <Section tone="charcoal" aria-labelledby="siparis-baslik">
        <div className="grid gap-8 lg:grid-cols-[1.3fr_1fr] lg:items-center">
          <SectionHeading
            id="siparis-baslik"
            eyebrow="Mevcut müşterilerimiz"
            title="Günlük sipariş ve takip"
            description="Düzenli hizmet alan kurumlar günlük menüyü görüntüleyebilir, sipariş verebilir ve siparişlerinin durumunu takip edebilir."
          />

          <div className="flex flex-wrap gap-3">
            <Button asChild size="lg" className="bg-brand-500 text-charcoal hover:bg-brand-400">
              <Link href="/menu">Günün menüsü</Link>
            </Button>
            <Button
              asChild
              size="lg"
              variant="outline"
              className="border-cream/30 bg-transparent text-cream hover:bg-cream/10 hover:text-cream"
            >
              <Link href="/siparislerim">Siparişlerim</Link>
            </Button>
          </div>
        </div>
      </Section>

      {/* Hiç kanal yoksa sayfanın sonunda tekrar forma yönlendirmek gerekiyor. */}
      {!hasAnyContactChannel(contact) && (
        <Section aria-labelledby="son-cagri">
          <SectionHeading
            id="son-cagri"
            title="Yazın, biz dönelim"
            description="Telefon ve e-posta bilgileri yayınlanana kadar teklif formu en hızlı yol."
            align="center"
          />
          <div className="mt-8 flex justify-center">
            <Button asChild size="lg">
              <Link href="/teklif-al">
                Teklif formunu aç
                <ArrowRight aria-hidden="true" />
              </Link>
            </Button>
          </div>
        </Section>
      )}
    </>
  );
}
