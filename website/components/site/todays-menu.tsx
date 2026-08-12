import Link from 'next/link';
import { ArrowRight } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { ProductImage } from '@/components/product-image';
import { Section, SectionHeading } from '@/components/site/section';
import { AddToCartForm } from '@/components/add-to-cart-form';
import { fetchCatalog, flattenItems, isOrderingOpen } from '@/lib/api/catalog';
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
 *
 * ## v2.0: buradan sipariş verilebiliyor (W-10)
 *
 * Önceki sürümde kartlar yalnızca ürün sayfasına bağlanıyordu; sipariş
 * vermek isteyen ziyaretçi ana sayfa → ürün → sepet diye üç adım atıyordu.
 * Artık seçeneği olmayan ürünler doğrudan sepete ekleniyor.
 *
 * SEÇENEĞİ OLAN ÜRÜN HÂLÂ DETAY SAYFASINA GİDİYOR: zorunlu bir seçenek
 * (porsiyon boyu, acı derecesi) sorulmadan sepete eklenen satır, ödeme
 * adımında reddedilirdi. Aynı ayrım `ProductCard` içinde de var.
 *
 * KART ARTIK BİR BAĞLANTI DEĞİL. Tüm kartı saran `<a>` içine buton koymak
 * geçersiz HTML üretiyor ve tıklama hedefleri iç içe giriyor; başlık
 * bağlantı, gövde düz içerik.
 */

/** Ana sayfada gösterilecek ürün sayısı — üç sütuna tam oturan altı kart. */
const LIMIT = 6;

export async function TodaysMenu() {
  let items: MenuItem[] = [];
  let orderingOpen = false;

  try {
    const { categories, location } = await fetchCatalog();

    // Şalter kapalıyken kart yine çiziliyor ama düğme pasif: menüyü
    // gizlemek SEO'yu ve "bugün ne var" sorusunu birlikte kaybettirirdi
    // (`docs/06` — `ordering_enabled=false` kuralı).
    orderingOpen = isOrderingOpen(location);

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
        {items.map((item) => {
          const hasOptions = (item.options ?? []).some((option) => option.required);

          return (
            <li
              key={item.id}
              className="group flex h-full bld-reveal flex-col overflow-hidden rounded-2xl border bg-card text-card-foreground transition-all hover:shadow-lg motion-safe:hover:-translate-y-0.5"
            >
              <Link
                href={productPath(item)}
                className="relative block aspect-4/3 overflow-hidden bg-muted"
              >
                <ProductImage
                  src={item.image_url}
                  alt=""
                  sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 380px"
                  className="transition-transform duration-500 motion-safe:group-hover:scale-105"
                />
              </Link>

              <div className="flex flex-1 flex-col p-5">
                <h3 className="font-display text-lg font-semibold tracking-tight">
                  <Link href={productPath(item)} className="hover:text-primary">
                    {item.name}
                  </Link>
                </h3>
                {item.description && (
                  <p className="mt-1.5 flex-1 text-sm/6 text-muted-foreground">
                    {item.description}
                  </p>
                )}
                <p className="mt-4 text-lg font-bold tabular-nums">{formatPrice(item.price)}</p>

                <div className="mt-4">
                  {hasOptions ? (
                    <Button asChild variant="outline" className="w-full">
                      <Link href={productPath(item)}>Seçenekleri gör</Link>
                    </Button>
                  ) : (
                    <AddToCartForm
                      menuId={item.id}
                      disabled={!orderingOpen || item.sold_out_today}
                      disabledReason={item.sold_out_today ? 'Tükendi' : 'Sipariş kapalı'}
                      showMessage
                    />
                  )}
                </div>
              </div>
            </li>
          );
        })}
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
