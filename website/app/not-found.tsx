import Link from 'next/link';
import { getTranslations } from 'next-intl/server';
import { ArrowRight } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { MAIN_NAV } from '@/content/navigation';

export default async function NotFound() {
  const t = await getTranslations('errors');

  return (
    <div className="mx-auto max-w-content px-4 py-24 text-center sm:px-6">
      <p className="text-xs font-semibold tracking-[0.14em] text-primary uppercase">404</p>
      <h1 className="mt-3 font-display text-3xl font-semibold tracking-tight sm:text-4xl">
        {t('notFoundTitle')}
      </h1>
      <p className="mx-auto mt-4 max-w-md text-base/7 text-muted-foreground">{t('notFoundBody')}</p>

      <div className="mt-8 flex flex-wrap justify-center gap-3">
        <Button asChild size="lg">
          <Link href="/">
            {t('goToMenu')}
            <ArrowRight aria-hidden="true" />
          </Link>
        </Button>
        <Button asChild size="lg" variant="outline">
          <Link href="/teklif-al">Teklif Al</Link>
        </Button>
      </div>

      {/* Kırık bağlantıya düşen ziyaretçi elle URL denemesin diye bölüm listesi. */}
      <nav aria-label="Site bölümleri" className="mt-12">
        <ul className="flex flex-wrap justify-center gap-x-6 gap-y-2">
          {MAIN_NAV.map((item) => (
            <li key={item.href}>
              <Link
                href={item.href}
                className="text-sm text-muted-foreground underline-offset-4 hover:text-foreground hover:underline"
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
