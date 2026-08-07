import Link from 'next/link';
import { ArrowRight } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { ProductImage } from '@/components/product-image';
import { Section, SectionHeading } from '@/components/site/section';
import { fetchCatalog, flattenItems } from '@/lib/api/catalog';
import { formatPrice } from '@/lib/format';
import { productPath } from '@/lib/slug';
import type { MenuItem } from '@/lib/api/types';

/**
 * Ana sayfadaki "bugün mutfakta" bandı — **canlı katalog**.
 *
 * ## Neden ayrı bileşen?
 *
 * Ana sayfanın geri kalanı kurumsal içerikten besleniyor ve sipariş API'si
 * kapalıyken de açılmak zorunda. Bu bölüm ise gerçek menüyü gösteriyor, yani o
 * API'ye bağımlı. İkisini aynı dosyada tutmak, tek bir 500 yüzünden vitrinin
 * tamamının hata ekranına düşmesi demekti.
 *
 * Burada hata **yutuluyor**: menü alınamazsa bölüm hiç basılmıyor. Ziyaretçi
 * eksik bir şey görmüyor, kırık bir şey de görmüyor.
 *
 * ## Neden fiyat gösteriyoruz?
 *
 * Kurumsal catering fiyatı teklife bağlı ve sitede liste vermiyoruz. Ama
 * `/menu` üzerinden verilen porsiyon siparişinin fiyatı bellidir ve zaten
 * menüde yazıyor; burada saklamak ziyaretçiyi bir tık daha uzaklaştırırdı.
 */

/** Ana sayfada gösterilecek ürün sayısı — üç sütuna tam oturan altı kart. */
const LIMIT = 6;

export async function TodaysMenu() {
  let items: MenuItem[] = [];

  try {
    const { categories } = await fetchCatalog();
    items = flattenItems(categories)
      // Tükenen ürün ana sayfada gösterilmez: burası vitrin, sipariş ekranı
      // değil. `/menu` içinde soluk hâliyle kalmaya devam ediyor.
      .filter((item) => item.is_available)
      .slice(0, LIMIT);
  } catch {
    return null;
  }

  if (items.length === 0) return null;

  return (
    <Section aria-labelledby="bugun-baslik">
      <div className="flex flex-wrap items-end justify-between gap-6">
        <SectionHeading
          id="bugun-baslik"
          eyebrow="Bugün mutfakta"
          title="Tek tabak da satıyoruz"
          description="Kurumsal siparişin yanında porsiyon usulü de veriyoruz. Menü her gün buradan güncelleniyor."
          className="!mb-0"
        />

        <Button asChild variant="outline" size="lg" className="hidden sm:inline-flex">
          <Link href="/menu">
            Menünün tamamı
            <ArrowRight aria-hidden="true" />
          </Link>
        </Button>
      </div>

      <ul className="mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
        {items.map((item) => (
          <li key={item.id} className="bld-reveal">
            <Link
              href={productPath(item)}
              className="group flex h-full flex-col overflow-hidden rounded-2xl border bg-card text-card-foreground transition-all hover:shadow-lg motion-safe:hover:-translate-y-0.5"
            >
              <div className="relative aspect-4/3 overflow-hidden bg-muted">
                <ProductImage
                  src={item.image_url}
                  alt=""
                  sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 380px"
                  className="transition-transform duration-500 motion-safe:group-hover:scale-105"
                />
              </div>

              <div className="flex flex-1 flex-col p-5">
                <h3 className="font-display text-lg font-semibold tracking-tight">{item.name}</h3>
                {item.description && (
                  <p className="mt-1.5 flex-1 text-sm/6 text-muted-foreground">
                    {item.description}
                  </p>
                )}
                <p className="mt-4 text-lg font-bold">{formatPrice(item.price)}</p>
              </div>
            </Link>
          </li>
        ))}
      </ul>

      <div className="mt-10 sm:hidden">
        <Button asChild variant="outline" size="lg" className="w-full">
          <Link href="/menu">
            Menünün tamamı
            <ArrowRight aria-hidden="true" />
          </Link>
        </Button>
      </div>
    </Section>
  );
}
