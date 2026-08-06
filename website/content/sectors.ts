/**
 * Hizmet verilen alanlar.
 *
 * Bu liste **sektörleri** anlatır, referans firma değil. Repoda doğrulanmış
 * müşteri bilgisi yok; sahte logo veya firma adı üretmek yerine hangi alanlarda
 * çalışıldığını ve o alanın neye ihtiyaç duyduğunu anlatıyoruz.
 */

import type { LucideIcon } from 'lucide-react';
import {
  Building,
  Factory,
  GraduationCap,
  HeartPulse,
  Landmark,
  PartyPopper,
  TrafficCone,
} from 'lucide-react';

export interface Sector {
  readonly slug: string;
  readonly title: string;
  readonly icon: LucideIcon;
  /** Bu alanın yemek hizmetinden asıl beklentisi. */
  readonly need: string;
  /** Bizim o beklentiye verdiğimiz karşılık. */
  readonly answer: string;
  /** İlgili hizmet sayfası. */
  readonly serviceSlug: string;
}

export const SECTORS: readonly Sector[] = [
  {
    slug: 'sanayi',
    title: 'Sanayi ve üretim',
    icon: Factory,
    need: 'Vardiya saatlerine dakikası dakikasına uyan, ağır işe yetecek öğünler.',
    answer:
      'Teslimat vardiya değişimine kilitlenir; menü kalori ihtiyacına göre kurulur ve personel sayısındaki dalgalanma günlük olarak güncellenir.',
    serviceSlug: 'kurumsal-toplu-yemek',
  },
  {
    slug: 'egitim',
    title: 'Eğitim kurumları',
    icon: GraduationCap,
    need: 'Yaş grubuna uygun porsiyon, alerjen takibi ve velinin görebileceği menü.',
    answer:
      'Öğün planı yaş grubuna göre ayrılır, alerjisi olan öğrenciler için alternatif hazırlanır, aylık menü paylaşıma hazır biçimde verilir.',
    serviceSlug: 'okul-yemek-hizmeti',
  },
  {
    slug: 'saglik',
    title: 'Sağlık kuruluşları',
    icon: HeartPulse,
    need: 'Hasta diyetleriyle personel öğünlerinin birbirine karışmaması.',
    answer:
      'Diyet öğünleri ayrı akışta üretilir ve hasta bazlı etiketlenir; personel menüsü vardiyaya göre ayrı planlanır.',
    serviceSlug: 'saglik-kuruluslari',
  },
  {
    slug: 'kamu',
    title: 'Kamu kurumları',
    icon: Landmark,
    need: 'Şartnameye uygun, belgelenebilir ve düzenli bir hizmet akışı.',
    answer:
      'Menü planı, teslimat kayıtları ve öğün sayıları raporlanabilir biçimde tutulur; hizmet şartname koşullarına göre kurgulanır.',
    serviceSlug: 'tasima-yemek',
  },
  {
    slug: 'ofis',
    title: 'Kurumsal ofisler',
    icon: Building,
    need: 'Mutfak kurmadan, çalışanı memnun eden düzenli bir öğün çözümü.',
    answer:
      'Yemek merkez mutfakta hazırlanıp servise hazır teslim edilir; ofiste yalnızca servis alanı yeterlidir.',
    serviceSlug: 'tasima-yemek',
  },
  {
    slug: 'insaat',
    title: 'İnşaat ve saha',
    icon: TrafficCone,
    need: 'Ulaşımı zor sahalara, değişken personel sayısıyla teslimat.',
    answer:
      'Saha koşullarına göre teslimat planlanır, günlük öğün adedi sahadan gelen sayıya göre güncellenir.',
    serviceSlug: 'santiye-yemek',
  },
  {
    slug: 'organizasyon',
    title: 'Organizasyon ve etkinlik',
    icon: PartyPopper,
    need: 'Tek seferlik ama hatasız olması gereken bir servis düzeni.',
    answer:
      'Menü, kurulum, servis ekibi ve toplama tek pakette planlanır; davetli sayısındaki değişiklik için pay bırakılır.',
    serviceSlug: 'davet-organizasyon',
  },
];
