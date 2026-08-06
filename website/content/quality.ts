/**
 * Kalite ve hijyen yaklaşımı.
 *
 * **YEDEK / BAŞLANGIÇ DEĞERİ.** Tek kaynak admin panelidir; sayfa içeriği
 * `lib/api/site-content.ts` üzerinden gelir. Burası yalnızca API kapalıyken
 * veya bölüm panelde boşken devreye girer.
 *
 * ## Sertifika iddiası neden yok?
 *
 * Repoda BLD adına düzenlenmiş ISO, HACCP, TSE veya gıda üretim izni belgesi
 * bulunmuyor. Sahip olunmayan bir belgeyi varmış gibi göstermek yalnızca yanlış
 * değil, gıda sektöründe yaptırımı olan bir beyandır.
 *
 * Bu yüzden sayfa **uygulanan yöntemi** anlatır. Firma belge bilgilerini
 * panele girdiğinde sertifika listesi dolar ve sayfadaki bölüm kendiliğinden
 * görünür hâle gelir. Sertifikalar tek istisnadır: panelden gelen **boş
 * liste** yedeğe düşmez, olduğu gibi kabul edilir — belge iddiası asla
 * "yedekten" doğmamalı.
 */

import type { LucideIcon } from 'lucide-react';
import {
  ClipboardCheck,
  PackageCheck,
  Refrigerator,
  ShieldCheck,
  Sprout,
  ThermometerSnowflake,
  Truck,
  UtensilsCrossed,
} from 'lucide-react';

export interface QualityPrinciple {
  readonly title: string;
  readonly body: string;
  readonly icon: LucideIcon;
}

/** Hammadde girişinden teslimata kadar zincir — sıralı okunacak biçimde. */
export const QUALITY_CHAIN: readonly QualityPrinciple[] = [
  {
    title: 'Hammadde seçimi',
    body: 'Malzeme, düzenli çalışılan tedarikçilerden alınır. Girişte görsel kontrol yapılır; uygun bulunmayan ürün kabul edilmez.',
    icon: Sprout,
  },
  {
    title: 'Depolama koşulları',
    body: 'Kuru gıda, soğuk ve dondurulmuş ürünler ayrı alanlarda saklanır. Ürünler giriş tarihine göre sıraya konur; önce giren önce kullanılır.',
    icon: Refrigerator,
  },
  {
    title: 'Mutfak hijyeni',
    body: 'Hazırlık yüzeyleri ve ekipman, kullanım öncesi ve sonrası temizlenir. Çiğ ve pişmiş ürün için ayrı hazırlık alanı ve ekipman kullanılır.',
    icon: UtensilsCrossed,
  },
  {
    title: 'Personel hijyeni',
    body: 'Mutfak ekibi bone, maske ve iş kıyafetiyle çalışır. El hijyeni kuralları üretim akışının bir parçası olarak uygulanır.',
    icon: ShieldCheck,
  },
  {
    title: 'Üretim ve pişirme',
    body: 'Öğünler servis saatine göre planlanan zamanda pişirilir. Uzun süre bekleyecek biçimde erken üretim yapılmaz.',
    icon: ClipboardCheck,
  },
  {
    title: 'Sıcaklık kontrolü',
    body: 'Sıcak yemek sıcak, soğuk ürün soğuk zincirde tutulur. Sıcaklık, sevkiyat öncesi ve teslimde kontrol edilir.',
    icon: ThermometerSnowflake,
  },
  {
    title: 'Taşıma ve teslimat',
    body: 'Yemek, ısı yalıtımlı kapalı kaplarla taşınır. Teslim edilen öğün, sayı ve saat bilgisiyle kayda geçer.',
    icon: Truck,
  },
  {
    title: 'İzlenebilirlik',
    body: 'Hangi gün hangi menünün üretildiği ve nereye teslim edildiği kayıt altındadır. Geriye dönük inceleme gerektiğinde bu kayıtlar kullanılır.',
    icon: PackageCheck,
  },
];

/** Alerjen yönetimi — ayrı bölüm, çünkü sorumluluk paylaşımı gerektiriyor. */
export const ALLERGEN_APPROACH: readonly string[] = [
  'Menüdeki öğünlerin içerdiği bilinen alerjenler kurumla paylaşılır.',
  'Alerjisi olan kişiler için alternatif öğün ayrı hazırlanır ve etiketlenir.',
  'Özel öğünler, çapraz bulaşma riskini azaltmak için ayrı kaplarda taşınır.',
  'Alerjen listesi kurumdan gelen bilgiye dayanır; liste güncellendiğinde menü planı da güncellenir.',
];

/**
 * Sahip olunan belgeler.
 *
 * BOŞ BIRAKILDI — repoda doğrulanabilir belge yok. Firma belge bilgisini
 * verdiğinde buraya eklenir ve Kalite sayfasındaki sertifika bölümü görünür.
 */
export const CERTIFICATIONS: readonly {
  readonly name: string;
  readonly issuer: string;
  readonly validUntil: string | null;
}[] = [];
