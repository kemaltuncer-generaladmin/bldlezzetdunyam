/**
 * Hizmet verilen alanlar.
 *
 * **YEDEK / BAŞLANGIÇ DEĞERİ.** Tek kaynak admin panelidir; sayfa listeyi
 * `lib/api/site-content.ts` üzerinden okur. Panelde `icon` alanı lucide ikon
 * ADI olarak (metin) girilir ve `lib/lucide-icon.ts` bunu bileşene çevirir.
 *
 * Bu liste **sektörleri** anlatır, referans firma değil. Repoda doğrulanmış
 * müşteri bilgisi yok; sahte logo veya firma adı üretmek yerine hangi alanlarda
 * çalışıldığını ve o alanın neye ihtiyaç duyduğunu anlatıyoruz.
 *
 * Görseller `public/gorseller/sektor-<slug>.webp` yolundadır; eşleşme
 * `lib/site-images.ts` içinde slug üzerinden kurulur.
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
    need: 'Vardiya zilinde hazır olan, ağır işe yeten yemek.',
    answer:
      'Teslim saatini vardiya değişimine bağlıyoruz. Menü doyuruyor, sayı gün gün güncelleniyor.',
    serviceSlug: 'kurumsal-toplu-yemek',
  },
  {
    slug: 'egitim',
    title: 'Okullar ve kreşler',
    icon: GraduationCap,
    need: 'Yaşa uygun porsiyon, alerji takibi ve veliye gösterilebilir bir menü.',
    answer:
      'Öğün planı yaşa göre ayrılıyor, alerjisi olana ayrı tabak çıkıyor, aylık liste paylaşıma hazır geliyor.',
    serviceSlug: 'okul-yemek-hizmeti',
  },
  {
    slug: 'saglik',
    title: 'Sağlık kuruluşları',
    icon: HeartPulse,
    need: 'Hasta diyetiyle personel yemeğinin birbirine karışmaması.',
    answer:
      'Diyet öğünleri ayrı pişiyor, hasta adına etiketleniyor. Personel menüsü vardiyaya göre ayrı planlanıyor.',
    serviceSlug: 'saglik-kuruluslari',
  },
  {
    slug: 'kamu',
    title: 'Kamu kurumları',
    icon: Landmark,
    need: 'Şartnameye uyan ve belgelenebilen bir düzen.',
    answer:
      'Menü planı, teslim kayıtları ve öğün sayıları raporlanabilir tutuluyor; hizmet şartnameye göre kuruluyor.',
    serviceSlug: 'tasima-yemek',
  },
  {
    slug: 'ofis',
    title: 'Ofisler',
    icon: Building,
    need: 'Mutfak kurmadan, çalışanın memnun olacağı bir öğle yemeği.',
    answer: 'Yemek bizde pişiyor, servise hazır geliyor. Ofiste bir masa yeterli.',
    serviceSlug: 'tasima-yemek',
  },
  {
    slug: 'insaat',
    title: 'İnşaat ve saha',
    icon: TrafficCone,
    need: 'Yolu zor sahaya, her gün değişen sayıyla teslimat.',
    answer: 'Teslimi saha koşullarına göre planlıyoruz. Sabah kaç kişiyseniz, öğlen o kadar tabak.',
    serviceSlug: 'santiye-yemek',
  },
  {
    slug: 'organizasyon',
    title: 'Davet ve etkinlik',
    icon: PartyPopper,
    need: 'Bir kez olacak ve hatasız olması gereken bir gün.',
    answer:
      'Menü, kurulum, servis ve toplama tek pakette. Davetli sayısı artarsa diye pay bırakıyoruz.',
    serviceSlug: 'davet-organizasyon',
  },
];
