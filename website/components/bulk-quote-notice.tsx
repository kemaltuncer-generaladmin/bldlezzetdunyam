import Link from 'next/link';
import { ArrowRight, Users } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

/**
 * TOPLU ALIM EŞİĞİ — bu adedin ÜZERİNE çıkıldığında teklif kutusu görünür.
 *
 * On, sepetten geçen normal bir siparişin üst sınırı: bir aile ya da küçük bir
 * ofis katı bu sayının altında kalıyor. Üzerine çıkan müşteri artık perakende
 * değil toplu alım yapıyor ve ona sepetten devam ettirmek iki tarafa da
 * zarar: fiyat pazarlığı, fatura düzeni, teslimat saati ve mutfak kapasitesi
 * konuşulmadan giren büyük bir sipariş ya karşılanamıyor ya da telefonla
 * yeniden kuruluyor.
 */
export const BULK_QUOTE_THRESHOLD = 10;

/**
 * "Bu kadar çok kişi için özel teklif alın" kutusu.
 *
 * ## Eşik SATIR BAŞINA bakılıyor, sepet toplamına değil
 *
 * Dört farklı yemekten üçer tane alan bir müşteri on iki porsiyona ulaşıyor
 * ama toplu alım yapmıyor — dört kişilik bir masa kuruyor. Tek bir yemekten
 * on beş tane alan ise kalabalığa yemek çıkarıyor. Ayrımı yapan sayı satırın
 * kendi adedi; sepet toplamıyla ölçseydik normal siparişlerin çoğuna
 * gereksiz yere teklif teklif ederdik.
 *
 * ## Sipariş DURDURULMUYOR
 *
 * Kutu bir kapı değil, bir öneri: müşteri isterse sepetten devam edebilir.
 * "Bu adette sipariş veremezsiniz" demek, hazır olan bir işi geri çevirmek
 * olurdu. Kontenjan gerçekten yetmiyorsa zaten stok tavanı devrede
 * (`lib/stock-policy.ts`).
 *
 * ## Kişi sayısı NİYE ÖNCEDEN DOLDURULUYOR
 *
 * Teklif formu dört şey soruyor ve biri "kaç kişi" (`lib/validation/quote.ts`).
 * Müşteri o sayıyı sepette zaten söyledi; formu açınca ikinci kez sormak,
 * doldurulmuş bir formu boş göstermek olurdu. Değer TAHMİN olduğu için
 * kilitli değil — form onu düzenlenebilir bir alan olarak veriyor.
 */
export function BulkQuoteNotice({
  quantity,
  headcount,
  className,
}: {
  /** Eşikle karşılaştırılan adet — sepetteki en kalabalık satırın adedi. */
  quantity: number;
  /** Teklif formuna taşınacak kişi sayısı önerisi. */
  headcount: number;
  className?: string;
}) {
  if (quantity <= BULK_QUOTE_THRESHOLD) return null;

  return (
    <div
      className={cn(
        'rounded-md border bg-surface-warm p-4 text-surface-warm-foreground',
        className,
      )}
    >
      <p className="flex items-center gap-2 text-label">
        <Users aria-hidden="true" strokeWidth={1.75} className="size-4 shrink-0" />
        Kalabalık bir grup için mi?
      </p>
      <p className="mt-1.5 text-body-sm opacity-80">
        {BULK_QUOTE_THRESHOLD} porsiyonun üzerindeki siparişler için menüyü ve fiyatı size özel
        hazırlıyoruz. Sepetten devam edebilirsiniz; teklif isterseniz sizi arayalım.
      </p>

      <Button asChild variant="outline" size="sm" className="mt-3">
        <Link href={`/teklif-al?kisi=${headcount}`}>
          Özel teklif istiyorum
          <ArrowRight strokeWidth={1.75} aria-hidden="true" />
        </Link>
      </Button>
    </div>
  );
}
