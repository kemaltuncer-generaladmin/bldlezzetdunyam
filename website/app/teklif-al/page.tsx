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
      'Kurumsal yemek, catering ve organizasyon için teklif isteyin. Dört soru; gerisini telefonda konuşalım, menü önerisi ve fiyatla dönelim.',
    path: '/teklif-al',
    brandName: brand.name,
  });
}

const CRUMBS: readonly Crumb[] = [{ href: '/teklif-al', label: 'Teklif Al' }];

/*
 * FORM DÖRT ALANA İNDİ (M4) VE BU LİSTE ONA GÖRE DEĞİŞTİ.
 *
 * Eski metin "hizmet türü ve konuma bakıp" diyordu; o alanlar artık formda
 * yok. Adımlar bu yüzden yeniden yazıldı: sorular telefonda soruluyor.
 * Kutunun işi beklentiyi doğru kurmak — sayfada söz verilen sıra ile gerçek
 * sıra ayrışırsa arayan kişi hazırlıksız yakalanıyor.
 */
const WHAT_HAPPENS_NEXT = [
  {
    icon: FileText,
    title: 'Talebi görüyoruz',
    body: 'Kişi sayısına bakıp hangi ekibin ilgileneceğini belirliyoruz.',
  },
  {
    icon: MessageSquare,
    title: 'Sizi arıyoruz',
    body: 'Öğün düzeni, konum ve özel beslenme ihtiyaçları telefonda konuşuluyor. Uzun sürmüyor.',
  },
  {
    icon: Clock,
    title: 'Menü ve fiyatla dönüyoruz',
    body: 'İkisi aynı cevapta geliyor; menüyü görmeden karar vermiyorsunuz.',
  },
] as const;

/**
 * `?kisi=` — sepetteki toplu alım kutusundan gelen kişi sayısı önerisi.
 *
 * ## Sayfa bu yüzden İSTEK BAŞINA çiziliyor
 *
 * `searchParams` okumak sayfayı dinamik yapıyor; alternatifi değeri istemcide
 * `useSearchParams` ile okumaktı ve o yol Suspense sınırı gerektiriyor —
 * yani form SSR çıktısında hiç bulunmazdı. Bu form JavaScript kapalıyken de
 * çalışacak şekilde yazıldı (`components/site/quote-form.tsx`); onu sunucu
 * HTML'inden çıkarmak, çalışan bir özelliği önbellek uğruna feda etmek
 * olurdu.
 *
 * Bedel küçük: sayfanın tek veri kaynağı `fetchSiteContent` ve o zaten ISR
 * önbellekli, yani dinamik çizim platforma ek bir istek doğurmuyor. `metadata`
 * ve JSON-LD sunucuda üretilmeye devam ediyor.
 *
 * ADRESTEN GELEN SAYI DOĞRULANIYOR. Değer kullanıcının değiştirebileceği bir
 * yerden geliyor; olduğu gibi forma yazmak, alana "abc" ya da eksi bir sayı
 * düşürmenin yolu olurdu. Şemanın kabul ettiği aralığın dışındaki her şey
 * yok sayılıyor ve alan boş açılıyor (`lib/validation/quote.ts`).
 */
function readHeadcount(raw: string | string[] | undefined): number | undefined {
  const value = Array.isArray(raw) ? raw[0] : raw;
  if (typeof value !== 'string') return undefined;

  const parsed = Number.parseInt(value, 10);
  if (!Number.isSafeInteger(parsed) || parsed < 1 || parsed > 100000) return undefined;

  return parsed;
}

export default async function TeklifAlPage({
  searchParams,
}: {
  searchParams: Promise<{ kisi?: string | string[] }>;
}) {
  const [{ contact }, params] = await Promise.all([fetchSiteContent(), searchParams]);
  const defaultHeadcount = readHeadcount(params.kisi);

  return (
    <>
      <JsonLd data={breadcrumbJsonLd(CRUMBS)} />

      <PageHero
        crumbs={CRUMBS}
        eyebrow="Teklif"
        title="Kaç kişisiniz?"
        description="Dört soru soruyoruz: adınız, telefonunuz, kurumunuz ve kişi sayısı. Öğün düzeni, konum ve menü ayrıntılarını sizi ararken konuşalım."
        image={PHOTO.izgaraTabak.src}
      />

      <div className="mx-auto grid max-w-content gap-12 px-4 py-14 sm:px-6 sm:py-20 lg:grid-cols-[1.6fr_1fr]">
        <div>
          <QuoteForm defaultHeadcount={defaultHeadcount} />
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
