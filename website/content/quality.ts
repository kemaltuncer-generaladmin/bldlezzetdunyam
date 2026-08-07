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
    title: 'Mal girişi',
    body: 'Malzemeyi hep aynı yerlerden alıyoruz. Kapıda kasa kasa bakılır; beğenilmeyen geri gider.',
    icon: Sprout,
  },
  {
    title: 'Depo',
    body: 'Kuru gıda, soğuk ve dondurulmuş ayrı yerlerde durur. Rafta önce giren önce çıkar.',
    icon: Refrigerator,
  },
  {
    title: 'Tezgâh',
    body: 'Tezgâh ve ekipman iş öncesi ve sonrası temizlenir. Çiğ etin bıçağı salatanın bıçağı olmaz.',
    icon: UtensilsCrossed,
  },
  {
    title: 'Ekip',
    body: 'Mutfakta bone, maske ve iş kıyafeti var. El yıkamak işin adımlarından biri.',
    icon: ShieldCheck,
  },
  {
    title: 'Ocak',
    body: 'Pişirme saati servis saatinden geri sayılarak belirlenir. Sabahtan pişip öğlene kadar bekleyen yemek yok.',
    icon: ClipboardCheck,
  },
  {
    title: 'Sıcaklık',
    body: 'Sıcak sıcakta, soğuk soğukta durur. Termometre hem çıkışta hem teslimde giriyor.',
    icon: ThermometerSnowflake,
  },
  {
    title: 'Yol',
    body: 'Yemek ısı tutan kapalı kaplarla gider. Kaç kap, kaçta teslim edildi — hepsi yazılır.',
    icon: Truck,
  },
  {
    title: 'Kayıt',
    body: 'Hangi gün ne pişti, nereye gitti — hepsi duruyor. Geriye dönüp bakmak gerekirse kayıt orada.',
    icon: PackageCheck,
  },
];

/** Alerjen yönetimi — ayrı bölüm, çünkü sorumluluk paylaşımı gerektiriyor. */
export const ALLERGEN_APPROACH: readonly string[] = [
  'Menüdeki yemeklerin bilinen alerjenlerini önden yazılı veriyoruz.',
  'Alerjisi olana ayrı yemek pişiyor, kabın üzerine adı yazılıyor.',
  'O kaplar ayrı taşınıyor — yolda diğerlerine değmiyor.',
  'Listeyi siz veriyorsunuz. Yeni bir isim eklendiğinde menü planı da değişiyor.',
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
