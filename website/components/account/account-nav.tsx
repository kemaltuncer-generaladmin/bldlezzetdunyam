import Link from 'next/link';
import { cn } from '@/lib/utils';

/**
 * Hesap bölümleri arası gezinme — W-12 / W-13.
 *
 * `/hesabim` artık tek bir profil sayfası değil, dört bölümlü bir merkez:
 * profil, siparişler, cari hesap, abonelikler. Aralarında gezinmenin tek
 * yolu footer olsaydı, cari sayfasından abonelik sayfasına geçmek için
 * sayfanın en altına inmek gerekirdi.
 *
 * SUNUCU BİLEŞENİ: aktif bölüm `usePathname` ile değil prop ile
 * belirleniyor. Her sayfa hangi bölümde olduğunu zaten biliyor; bunun için
 * istemci tarafına bir bileşen daha indirmek gereksiz.
 */
const SECTIONS = [
  { key: 'profil', href: '/hesabim', label: 'Profil' },
  { key: 'siparisler', href: '/siparislerim', label: 'Siparişlerim' },
  { key: 'cari', href: '/hesabim/cari', label: 'Cari hesabım' },
  { key: 'abonelikler', href: '/hesabim/abonelikler', label: 'Aboneliklerim' },
] as const;

export type AccountSection = (typeof SECTIONS)[number]['key'];

export function AccountNav({ active }: { active: AccountSection }) {
  return (
    <nav aria-label="Hesap bölümleri" className="-mx-4 mt-4 overflow-x-auto px-4">
      <ul className="flex min-w-max gap-1 border-b">
        {SECTIONS.map((section) => {
          const isActive = section.key === active;
          return (
            <li key={section.key}>
              <Link
                href={section.href}
                aria-current={isActive ? 'page' : undefined}
                className={cn(
                  'flex min-h-11 items-center border-b-2 px-3 text-sm font-medium transition-colors',
                  isActive
                    ? 'border-primary text-primary'
                    : 'border-transparent text-muted-foreground hover:text-foreground',
                )}
              >
                {section.label}
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
