import { z } from 'zod';
import { normalizeTelephone } from '@/lib/validation/auth';

/**
 * Teklif talebi doğrulaması.
 *
 * Şema istemci (React Hook Form) ve sunucu eylemi tarafından **ortak**
 * kullanılır; sunucu son sözü söyler. `lib/validation/auth.ts` içindeki
 * `normalizeTelephone` yeniden kullanılıyor — telefon biçimi sitede tek türlü
 * olmalı.
 */

/** Teklif formundaki hizmet türleri. Değerler `content/services.ts` slug'larıyla aynı. */
export const QUOTE_SERVICE_TYPES = [
  { value: 'kurumsal-toplu-yemek', label: 'Kurumsal toplu yemek' },
  { value: 'tasima-yemek', label: 'Taşıma yemek' },
  { value: 'yerinde-uretim', label: 'Yerinde üretim' },
  { value: 'okul-yemek-hizmeti', label: 'Okul yemek hizmeti' },
  { value: 'saglik-kuruluslari', label: 'Sağlık kuruluşlarına yemek' },
  { value: 'santiye-yemek', label: 'Şantiye yemek hizmeti' },
  { value: 'davet-organizasyon', label: 'Davet ve organizasyon' },
  { value: 'toplanti-ikram', label: 'Toplantı ve etkinlik ikramı' },
] as const;

export type QuoteServiceType = (typeof QUOTE_SERVICE_TYPES)[number]['value'];

/**
 * Tek seferlik hizmetler.
 *
 * Bu ikisinde "hizmet sıklığı" sorulmaz (tek seferlik), buna karşılık
 * **etkinlik tarihi zorunludur** — tarihi bilinmeyen bir davet için teklif
 * hazırlanamaz. Diğer hizmetlerde tarih isteğe bağlı bir başlangıç tercihidir.
 */
export const ONE_OFF_SERVICES: readonly QuoteServiceType[] = [
  'davet-organizasyon',
  'toplanti-ikram',
];

/** Yerinde üretimde mutfak altyapısı sorulur; diğerlerinde alan gösterilmez. */
export const ON_SITE_SERVICES: readonly QuoteServiceType[] = ['yerinde-uretim'];

export const SERVICE_FREQUENCIES = [
  { value: 'gunluk', label: 'Her gün' },
  { value: 'haftaici', label: 'Hafta içi (5 gün)' },
  { value: 'haftalik-birkac', label: 'Haftada birkaç gün' },
  { value: 'donemsel', label: 'Dönemsel / proje bazlı' },
] as const;

export const MENU_PREFERENCES = [
  { value: 'siz-onerin', label: 'Siz önerin' },
  { value: 'dort-kap', label: 'Dört kap' },
  { value: 'uc-kap', label: 'Üç kap' },
  { value: 'kahvalti-ikram', label: 'Kahvaltı / ikram' },
  { value: 'ozel-beslenme', label: 'Özel beslenme ihtiyacı var' },
] as const;

const serviceTypeValues = QUOTE_SERVICE_TYPES.map((option) => option.value) as [
  QuoteServiceType,
  ...QuoteServiceType[],
];

export const quoteSchema = z
  .object({
    full_name: z
      .string()
      .trim()
      .min(2, 'Ad ve soyadınızı girin.')
      .max(120, 'Ad soyad en fazla 120 karakter.'),
    organization: z
      .string()
      .trim()
      .min(2, 'Firma veya kurum adını girin.')
      .max(160, 'En fazla 160 karakter.'),
    telephone: z
      .string()
      .trim()
      .transform(normalizeTelephone)
      .refine(
        (value) => /^[1-9][0-9]{9}$/.test(value),
        'Telefonu başında 0 olmadan 10 hane girin. Örn. 5551234567',
      ),
    email: z
      .string()
      .trim()
      .min(1, 'E-posta adresinizi girin.')
      .email('Geçerli bir e-posta adresi girin.'),
    service_type: z.enum(serviceTypeValues, { message: 'Hizmet türünü seçin.' }),
    headcount: z.coerce
      .number({ message: 'Kişi sayısını rakamla girin.' })
      .int('Kişi sayısı tam sayı olmalı.')
      .min(1, 'Kişi sayısı en az 1 olmalı.')
      .max(100000, 'Kişi sayısı çok yüksek görünüyor; açıklama alanına yazın.'),
    frequency: z
      .enum(SERVICE_FREQUENCIES.map((option) => option.value) as [string, ...string[]])
      .optional(),
    /** ISO tarih (`YYYY-MM-DD`) veya boş. */
    start_date: z.string().trim().optional(),
    location: z
      .string()
      .trim()
      .min(2, 'Hizmetin verileceği il/ilçeyi girin.')
      .max(160, 'En fazla 160 karakter.'),
    menu_preference: z
      .enum(MENU_PREFERENCES.map((option) => option.value) as [string, ...string[]])
      .optional(),
    kitchen_note: z.string().trim().max(500, 'En fazla 500 karakter.').optional(),
    message: z.string().trim().max(2000, 'Açıklama en fazla 2000 karakter.').optional(),
    kvkk_accepted: z.literal(true, {
      message: 'Devam etmek için KVKK aydınlatma metnini onaylayın.',
    }),
    /**
     * Bal küpü. Gerçek kullanıcı görmediği için boş kalır; botlar her alanı
     * doldurma eğiliminde olduğundan dolu gelmesi otomatik gönderim işaretidir.
     */
    website: z.string().max(0).optional(),
  })
  .superRefine((values, ctx) => {
    const isOneOff = ONE_OFF_SERVICES.includes(values.service_type);

    if (isOneOff && !values.start_date) {
      ctx.addIssue({
        code: 'custom',
        path: ['start_date'],
        message: 'Etkinlik tarihini girin.',
      });
    }

    if (!isOneOff && !values.frequency) {
      ctx.addIssue({
        code: 'custom',
        path: ['frequency'],
        message: 'Hizmet sıklığını seçin.',
      });
    }

    if (values.start_date) {
      const parsed = Date.parse(values.start_date);
      if (Number.isNaN(parsed)) {
        ctx.addIssue({ code: 'custom', path: ['start_date'], message: 'Geçerli bir tarih seçin.' });
      }
    }
  });

export type QuoteValues = z.input<typeof quoteSchema>;
export type QuotePayload = z.output<typeof quoteSchema>;
