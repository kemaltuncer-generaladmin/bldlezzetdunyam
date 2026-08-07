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
        <div className="relative overflow-hidden rounded-3xl bg-charcoal px-6 py-14 text-cream sm:px-12">
          {/* Dekoratif sıcaklık lekesi — metnin okunurluğunu etkilemeyecek opaklıkta. */}
          <div
            aria-hidden="true"
            className="pointer-events-none absolute -top-24 -right-20 size-72 rounded-full bg-brand-600/25 blur-3xl"
          />

          <div className="relative max-w-2xl">
            <h2
              id="teklif-cagrisi"
              className="font-display text-3xl font-semibold tracking-tight sm:text-4xl"
            >
              {title}
            </h2>
            <p className="mt-4 text-base/7 text-cream/75">{description}</p>

            <div className="mt-8 flex flex-wrap gap-3">
              <Button asChild size="lg" className="bg-brand-500 text-charcoal hover:bg-brand-400">
                <Link href={PRIMARY_CTA.href}>
                  {PRIMARY_CTA.label}
                  <ArrowRight aria-hidden="true" />
                </Link>
              </Button>

              {contact.phone && (
                <Button
                  asChild
                  size="lg"
                  variant="outline"
                  className="border-cream/30 bg-transparent text-cream hover:bg-cream/10 hover:text-cream"
                >
                  <a href={contact.phone.href}>
                    <Phone aria-hidden="true" />
                    {contact.phone.display}
                  </a>
                </Button>
              )}

              {contact.whatsapp && (
                <Button
                  asChild
                  size="lg"
                  variant="outline"
                  className="border-cream/30 bg-transparent text-cream hover:bg-cream/10 hover:text-cream"
                >
                  <a href={contact.whatsapp.href}>
                    <MessageCircle aria-hidden="true" />
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
