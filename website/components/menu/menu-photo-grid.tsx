import { ProductImage } from '@/components/product-image';
import { cn } from '@/lib/utils';

/**
 * MENÜ FOTOĞRAF IZGARASI — günün ilk dört kaleminin 2×2 dizilimi.
 *
 * ## Dizilim İSTEMCİDE kurulur
 *
 * Sözleşme yalnızca sıralı bir görsel listesi veriyor (`DailyMenu.image_urls`,
 * "yöneticinin verdiği sırada, görseli olmayan kalem listeye girmez") ve
 * ızgarayı istemcinin dizmesini şart koşuyor. Sunucu birleştirilmiş tek bir
 * kapak üretseydi her ekran genişliği için ayrı bir dosya gerekirdi ve
 * yönetici bir yemeğin fotoğrafını değiştirdiğinde o dosyanın yeniden
 * üretilmesini beklemek zorunda kalırdı.
 *
 * ## Dört ayrı yerleşim, tek kural: BOŞ HÜCRE YOK
 *
 * | Görsel | Yerleşim |
 * |---|---|
 * | 1 | tam kanama |
 * | 2 | iki sütun |
 * | 3 | uzun sol + iki sağ |
 * | 4 | 2×2 |
 *
 * Eksik görseli yer tutucuyla doldurup her zaman 2×2 çizmek daha kolaydı ama
 * iki fotoğrafı olan bir gün ekranda "yarısı eksik" görünürdü. Sözleşme de
 * aynı sebeple diziye boş yer koymuyor.
 *
 * ## Neden `ProductImage`?
 *
 * Hücreler `next/image` ile elle çizilseydi buğday yayı yer tutucusu ve
 * fotoğrafın `bld-photo` iç halkası burada ikinci kez yazılırdı; beyaz tabaklı
 * bir yemek beyaz kartın içinde halkasız eriyor. Tek bir çizim noktası
 * olması, mobil uygulamayla aynı yer tutucuyu kullanmayı da sürdürüyor.
 *
 * ## DEKORATİF
 *
 * Kapsayıcı `aria-hidden`: ızgaradaki yemeklerin adları paket kartında zaten
 * metin olarak yazıyor (`daily.components`). Her hücreye ürün adını `alt`
 * olarak yazmak, ekran okuyucuya aynı dört ismi arka arkaya iki kez okuturdu.
 */

/** Sözleşme en fazla dört görsel veriyor; fazlası çizilmez. */
const MAX_CELLS = 4;

/**
 * Kapsayıcının satır/sütun düzeni. Hücre sayısına göre ayrı ayrı yazılı
 * çünkü Tailwind sınıf adlarını derleme anında tarıyor — `grid-cols-${n}`
 * gibi kurulmuş bir ad üretime hiç çıkmaz.
 */
const SHELL_BY_COUNT: Record<number, string> = {
  1: 'grid-cols-1 grid-rows-1',
  2: 'grid-cols-2 grid-rows-1',
  3: 'grid-cols-2 grid-rows-2',
  4: 'grid-cols-2 grid-rows-2',
};

type Props = {
  /** `DailyMenu.image_urls` — kapak varsa çağıran onu tek elemanlı verir. */
  imageUrls?: readonly string[];
  /**
   * TEK HÜCRENİN görüntü alanı payı. En geniş hücre tam kanama hâlidir; iki
   * ve dörtlü dizilimde hücre bunun yarısına düşer, yani değer güvenli
   * taraftan (biraz büyük) kalır. Hücre başına ayrı bir tarif almak, çağıranı
   * kaç görsel geleceğini önceden bilmeye zorlardı.
   */
  sizes: string;
  /** İlk hücre sayfanın en büyük görseliyse LCP için öncelikli yüklenir. */
  priority?: boolean;
  className?: string;
};

export function MenuPhotoGrid({ imageUrls, sizes, priority = false, className }: Props) {
  const urls = (imageUrls ?? []).slice(0, MAX_CELLS);

  /*
   * Hiç görsel yoksa TEK hücre çiziliyor, ızgara değil: `ProductImage`
   * kaynaksız çağrıldığında buğday yayını basıyor ve kart boş kalmıyor.
   * Dört boş hücre, aynı yer tutucuyu dört kez tekrarlayıp deseni gürültüye
   * çevirirdi.
   */
  const cells: (string | null)[] = urls.length > 0 ? [...urls] : [null];
  const shell = SHELL_BY_COUNT[cells.length] ?? SHELL_BY_COUNT[MAX_CELLS];

  return (
    <div aria-hidden="true" className={cn('grid h-full w-full gap-px', shell, className)}>
      {cells.map((url, index) => (
        <div
          key={url ?? 'bos'}
          className={cn(
            // `ProductImage` `fill` ile yerleşiyor: hücrenin konumlanmış
            // olması ZORUNLU, yoksa görsel karttan taşar.
            'relative overflow-hidden',
            // Üçlü dizilimde sol hücre iki satır boyunda: kalan iki görsel
            // sağda alt alta durur ve ızgarada boşluk kalmaz.
            cells.length === 3 && index === 0 && 'row-span-2',
          )}
        >
          <ProductImage src={url} alt="" sizes={sizes} priority={priority && index === 0} />
        </div>
      ))}
    </div>
  );
}
