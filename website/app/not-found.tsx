import Link from 'next/link';
import { getTranslations } from 'next-intl/server';
import { ArrowRight, Compass } from 'lucide-react';
import { StatePanel } from '@/components/state-panel';
import { Button } from '@/components/ui/button';
import { MAIN_NAV } from '@/content/navigation';

/**
 * 404.
 *
 * ## Ton `empty`, `error` DEĞİL
 *
 * Bulunamayan bir adres sitenin arızası değil; kırık bir bağlantı ya da eski
 * bir yer imi. `error` tonu (kırmızı daire + `role="alert"`) ekran okuyucuyu
 * keser ve ziyaretçiye bir şeyin bozulduğunu söyler — ikisi de yanlış.
 *
 * ## Bölüm listesi neden duruyor?
 *
 * Kırık bağlantıdan gelen ziyaretçinin bir sonraki hamlesi adresi elle
 * denemek oluyor. Üç bölümlük liste bu denemeyi gereksiz kılıyor ve sayfayı
 * çıkışsız bırakmıyor.
 */
export default async function NotFound() {
  const t = await getTranslations('errors');

  return (
    <div className="mx-auto max-w-content px-4 py-20 sm:px-6 sm:py-24">
      <StatePanel
        tone="empty"
        icon={<Compass strokeWidth={1.75} aria-hidden="true" />}
        title={t('notFoundTitle')}
        message={t('notFoundBody')}
        action={
          <div className="flex flex-wrap justify-center gap-3">
            <Button asChild size="lg">
              <Link href="/menu">
                {t('goToMenu')}
                <ArrowRight strokeWidth={1.75} aria-hidden="true" />
              </Link>
            </Button>
            <Button asChild size="lg" variant="outline">
              <Link href="/teklif-al">{t('goToQuote')}</Link>
            </Button>
          </div>
        }
      />

      <nav aria-label="Site bölümleri" className="mt-10">
        <ul className="flex flex-wrap justify-center gap-x-6 gap-y-2">
          {MAIN_NAV.map((item) => (
            <li key={item.href}>
              <Link
                href={item.href}
                className="text-body-sm text-muted-foreground underline-offset-4 transition-colors duration-(--duration-fast) hover:text-foreground hover:underline"
              >
                {item.label}
              </Link>
            </li>
          ))}
        </ul>
      </nav>
    </div>
  );
}
