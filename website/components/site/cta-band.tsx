import Link from 'next/link';
import { ArrowRight, MessageCircle, Phone } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { PRIMARY_CTA } from '@/content/navigation';
import { fetchSiteContent } from '@/lib/api/site-content';

/**
 * Sayfa sonu dönüşüm bandı.
 *
 * Her bölüme CTA serpiştirmek yerine sayfa başına **bir** güçlü çağrı
 * kullanıyoruz. Birincil eylem her zaman "Teklif Al"; telefon ve WhatsApp
 * ikincil kalıyor ve yalnızca panelde değer girilmişse görünüyor.
 *
 * Başlık/açıklama prop olarak kalıyor: bunlar bulunduğu sayfaya göre değişen
 * arayüz metinleri, panelden yönetilen içerik değil. Teklif Al her zaman
 * çalışır — iletişim kanalı hiç yoksa bile band boşalmaz.
 */
export async function CtaBand({
  title = 'Kaç kişisiniz? Gerisini konuşalım.',
  description = 'Kişi sayınızı ve ne tür bir hizmet istediğinizi yazın; menü önerisi ve fiyatla birlikte dönelim.',
}: {
  title?: string;
  description?: string;
}) {
  const { contact } = await fetchSiteContent();

  return (
    <section aria-labelledby="teklif-cagrisi" className="bg-background">
      <div className="mx-auto max-w-content px-4 pb-16 sm:px-6 sm:pb-24">
        <div className="relative overflow-hidden rounded-lg bg-neutral-950 px-6 py-14 text-neutral-50 sm:px-12">
          {/* Dekoratif sıcaklık lekesi — metnin okunurluğunu etkilemeyecek opaklıkta. */}
          <div
            aria-hidden="true"
            className="pointer-events-none absolute -top-24 -right-20 size-72 rounded-full bg-brand-600/25 blur-3xl"
          />

          <div className="relative max-w-2xl">
            <h2
              id="teklif-cagrisi"
              className="font-display text-h2 font-semibold tracking-tight text-balance sm:text-h1"
            >
              {title}
            </h2>
            <p className="mt-4 text-body-lg text-pretty text-neutral-50/75">{description}</p>

            <div className="mt-8 flex flex-wrap gap-3">
              <Button
                asChild
                size="lg"
                className="bg-brand-300 text-neutral-950 hover:bg-brand-200"
              >
                <Link href={PRIMARY_CTA.href}>
                  {PRIMARY_CTA.label}
                  <ArrowRight aria-hidden="true" strokeWidth={1.75} />
                </Link>
              </Button>

              {contact.phone && (
                <Button
                  asChild
                  size="lg"
                  variant="outline"
                  className="border-neutral-50/40 bg-transparent text-neutral-50 hover:bg-neutral-50/10 hover:text-neutral-50"
                >
                  <a href={contact.phone.href}>
                    <Phone aria-hidden="true" strokeWidth={1.75} />
                    {contact.phone.display}
                  </a>
                </Button>
              )}

              {contact.whatsapp && (
                <Button
                  asChild
                  size="lg"
                  variant="outline"
                  className="border-neutral-50/40 bg-transparent text-neutral-50 hover:bg-neutral-50/10 hover:text-neutral-50"
                >
                  <a href={contact.whatsapp.href}>
                    <MessageCircle aria-hidden="true" strokeWidth={1.75} />
                    WhatsApp
                  </a>
                </Button>
              )}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
