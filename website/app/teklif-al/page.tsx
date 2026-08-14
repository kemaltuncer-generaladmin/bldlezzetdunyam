import { Clock, FileText, MessageSquare, Phone } from 'lucide-react';
import { JsonLd } from '@/components/json-ld';
import { PageHero, type Crumb } from '@/components/site/page-hero';
import { QuoteForm } from '@/components/site/quote-form';
import { fetchSiteContent } from '@/lib/api/site-content';
import { breadcrumbJsonLd, pageMetadata } from '@/lib/seo';
import { PHOTO } from '@/lib/site-images';

export async function generateMetadata() {
  const { brand } = await fetchSiteContent();

  return pageMetadata({
    title: 'Teklif Al',
    description:
      'Kurumsal yemek, catering ve organizasyon için teklif isteyin. Kaç kişi, ne zaman, nerede — söyleyin, menü önerisiyle birlikte dönelim.',
    path: '/teklif-al',
    brandName: brand.name,
  });
}

const CRUMBS: readonly Crumb[] = [{ href: '/teklif-al', label: 'Teklif Al' }];

const WHAT_HAPPENS_NEXT = [
  {
    icon: FileText,
    title: 'Okuyoruz',
    body: 'Kişi sayısı, hizmet türü ve konuma bakıp ne gerektiğini çıkarıyoruz.',
  },
  {
    icon: MessageSquare,
    title: 'Gerekirse arıyoruz',
    body: 'Eksik bir şey varsa telefonla soruyoruz. Uzun sürmüyor.',
  },
  {
    icon: Clock,
    title: 'Menü ve fiyatla dönüyoruz',
    body: 'İkisi aynı cevapta geliyor; menüyü görmeden karar vermiyorsunuz.',
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
        title="Kaç kişisiniz?"
        description="Fiyat kişi sayısına, öğün düzenine ve mesafeye göre değişiyor. Formu doldurun; menü önerisi ve fiyatla birlikte dönelim."
        image={PHOTO.izgaraTabak.src}
      />

      <div className="mx-auto grid max-w-content gap-12 px-4 py-14 sm:px-6 sm:py-20 lg:grid-cols-[1.6fr_1fr]">
        <div>
          <QuoteForm />
        </div>

        <aside className="space-y-8">
          <div className="bld-card p-6">
            <h2 className="font-display text-h3 font-semibold tracking-tight text-heading">
              Sonrasında ne oluyor?
            </h2>
            <ol className="mt-5 space-y-5">
              {WHAT_HAPPENS_NEXT.map((step, index) => (
                <li key={step.title} className="flex gap-4">
                  <span
                    aria-hidden="true"
                    className="grid size-9 shrink-0 place-items-center rounded-sm bg-accent text-label text-accent-foreground"
                  >
                    {index + 1}
                  </span>
                  <span>
                    <span className="flex items-center gap-2 text-label">
                      <step.icon aria-hidden="true" className="size-4 text-primary-text" />
                      {step.title}
                    </span>
                    <span className="mt-1 block text-body text-muted-foreground">{step.body}</span>
                  </span>
                </li>
              ))}
            </ol>
          </div>

          {/* Doğrudan iletişim bloğu yalnızca gerçek bir kanal girilmişse basılır. */}
          {(contact.phone || contact.whatsapp) && (
            <div className="rounded-md border bg-surface-warm p-6 text-surface-warm-foreground">
              <h2 className="font-display text-h3 font-semibold tracking-tight">
                Form yerine konuşalım
              </h2>
              <p className="mt-2 text-body opacity-80">
                İşiniz acilse doğrudan arayın, form beklemesin.
              </p>
              <div className="mt-4 space-y-2">
                {contact.phone && (
                  <a
                    href={contact.phone.href}
                    className="flex min-h-11 items-center gap-2 text-label text-primary-text"
                  >
                    <Phone strokeWidth={1.75} aria-hidden="true" className="size-4" />
                    {contact.phone.display}
                  </a>
                )}
                {contact.whatsapp && (
                  <a
                    href={contact.whatsapp.href}
                    className="flex min-h-11 items-center gap-2 text-label text-primary-text"
                  >
                    <MessageSquare strokeWidth={1.75} aria-hidden="true" className="size-4" />
                    WhatsApp ile yazın
                  </a>
                )}
              </div>
            </div>
          )}

          <div className="text-caption text-muted-foreground">
            <p>Formda yazdıklarınız yalnızca teklif hazırlamak ve size dönmek için kullanılıyor.</p>
          </div>
        </aside>
      </div>
    </>
  );
}
