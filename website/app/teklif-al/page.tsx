import { Clock, FileText, MessageSquare, Phone } from 'lucide-react';
import { JsonLd } from '@/components/json-ld';
import { PageHero, type Crumb } from '@/components/site/page-hero';
import { QuoteForm } from '@/components/site/quote-form';
import { fetchSiteContent } from '@/lib/api/site-content';
import { breadcrumbJsonLd, pageMetadata } from '@/lib/seo';

export async function generateMetadata() {
  const { brand } = await fetchSiteContent();

  return pageMetadata({
    title: 'Teklif Al',
    description:
      'Kurumsal catering, toplu yemek ve organizasyon hizmetleri için teklif talebi oluşturun. Kişi sayınızı ve hizmet türünüzü iletin, menü önerisiyle birlikte dönelim.',
    path: '/teklif-al',
    brandName: brand.name,
  });
}

const CRUMBS: readonly Crumb[] = [{ href: '/teklif-al', label: 'Teklif Al' }];

const WHAT_HAPPENS_NEXT = [
  {
    icon: FileText,
    title: 'Talebinizi inceliyoruz',
    body: 'Kişi sayısı, hizmet türü ve konum bilgisine göre ihtiyacınızı değerlendiriyoruz.',
  },
  {
    icon: MessageSquare,
    title: 'Gerekirse görüşüyoruz',
    body: 'Eksik kalan bir nokta varsa telefonla arayıp netleştiriyoruz.',
  },
  {
    icon: Clock,
    title: 'Menü ve fiyatla dönüyoruz',
    body: 'Size uygun menü kurgusu ve fiyatlandırmayı birlikte iletiyoruz.',
  },
] as const;

export default async function TeklifAlPage() {
  const { contact } = await fetchSiteContent();

  return (
    <>
      <JsonLd data={breadcrumbJsonLd(CRUMBS)} />

      <PageHero
        crumbs={CRUMBS}
        eyebrow="Teklif"
        title="İhtiyacınıza özel teklif alın"
        description="Catering fiyatı kişi sayısı, öğün düzeni ve konuma göre değişiyor. Aşağıdaki formu doldurun; size uygun menü kurgusu ve fiyatlandırmayla dönelim."
      />

      <div className="mx-auto grid max-w-content gap-12 px-4 py-14 sm:px-6 sm:py-20 lg:grid-cols-[1.6fr_1fr]">
        <div>
          <QuoteForm />
        </div>

        <aside className="space-y-8">
          <div className="rounded-2xl border bg-card p-6">
            <h2 className="font-display text-lg font-semibold tracking-tight">
              Sonrasında ne oluyor?
            </h2>
            <ol className="mt-5 space-y-5">
              {WHAT_HAPPENS_NEXT.map((step, index) => (
                <li key={step.title} className="flex gap-4">
                  <span
                    aria-hidden="true"
                    className="grid size-9 shrink-0 place-items-center rounded-lg bg-accent text-sm font-semibold text-accent-foreground"
                  >
                    {index + 1}
                  </span>
                  <span>
                    <span className="flex items-center gap-2 text-sm font-semibold">
                      <step.icon aria-hidden="true" className="size-4 text-primary" />
                      {step.title}
                    </span>
                    <span className="mt-1 block text-sm/6 text-muted-foreground">{step.body}</span>
                  </span>
                </li>
              ))}
            </ol>
          </div>

          {/* Doğrudan iletişim bloğu yalnızca gerçek bir kanal girilmişse basılır. */}
          {(contact.phone || contact.whatsapp) && (
            <div className="rounded-2xl border bg-surface-warm p-6 text-surface-warm-foreground">
              <h2 className="font-display text-lg font-semibold tracking-tight">
                Form yerine konuşalım
              </h2>
              <p className="mt-2 text-sm/6 opacity-80">
                Acil bir talebiniz varsa doğrudan arayabilirsiniz.
              </p>
              <div className="mt-4 space-y-2">
                {contact.phone && (
                  <a
                    href={contact.phone.href}
                    className="flex min-h-11 items-center gap-2 text-sm font-semibold text-primary"
                  >
                    <Phone aria-hidden="true" className="size-4" />
                    {contact.phone.display}
                  </a>
                )}
                {contact.whatsapp && (
                  <a
                    href={contact.whatsapp.href}
                    className="flex min-h-11 items-center gap-2 text-sm font-semibold text-primary"
                  >
                    <MessageSquare aria-hidden="true" className="size-4" />
                    WhatsApp ile yazın
                  </a>
                )}
              </div>
            </div>
          )}

          <div className="text-xs/6 text-muted-foreground">
            <p>
              Formda paylaştığınız bilgiler yalnızca teklif hazırlamak ve size dönüş yapmak için
              kullanılır.
            </p>
          </div>
        </aside>
      </div>
    </>
  );
}
