import { z } from 'zod';
import { normalizeTelephone } from '@/lib/validation/auth';

/**
 * Teklif talebi doğrulaması.
 *
 * Şema istemci (React Hook Form) ve sunucu eylemi tarafından **ortak**
 * kullanılır; sunucu son sözü söyler. `lib/validation/auth.ts` içindeki
 * `normalizeTelephone` yeniden kullanılıyor — telefon biçimi sitede tek türlü
 * olmalı.
 *
 * ## DÖRT ALANA İNDİ — M4
 *
 * Form on bir alan soruyordu: hizmet türü, sıklık, başlangıç/etkinlik tarihi,
 * konum, menü tercihi, mutfak altyapısı, e-posta, serbest açıklama. Hepsi
 * teklif hazırlarken lazım olan şeyler — ama hiçbiri **formda** lazım değil.
 * Teklifi hazırlayan zaten telefonla arıyor (`app/teklif-al/page.tsx`
 * "Sonrasında ne oluyor?" adımları) ve o konuşmada sorulan sorular formdakinin
 * tekrarı oluyordu.
 *
 * Geriye kalan dördü, ARAMADAN ÖNCE bilinmesi gereken asgari: kimi arayacağız
 * (`full_name`), nereden arayacağız (`telephone`), kimin adına (`organization`)
 * ve iş ne büyüklükte (`headcount`). Sonuncusu talebi sıraya koymaya yetiyor.
 *
 * Silinen sabitler (`QUOTE_SERVICE_TYPES`, `ONE_OFF_SERVICES`,
 * `ON_SITE_SERVICES`, `SERVICE_FREQUENCIES`, `MENU_PREFERENCES`) ve
 * `superRefine` bloğu yalnızca `components/site/quote-form.tsx` tarafından
 * kullanılıyordu; başka tüketicisi yoktu.
 *
 * ## Bal küpü ve süre KALIYOR
 *
 * Alanları azaltmak formu bot için kolaylaştırır: doldurulacak dört kutu
 * kaldı. Bu yüzden iki sessiz eleme (`website` bal küpü ve üç saniyelik asgari
 * doldurma süresi, bkz. `app/actions/quote.ts`) olduğu gibi duruyor — formun
 * hakkını veren kısım zaten onlar, koşullu alanlar değildi.
 */

export const quoteSchema = z.object({
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
  headcount: z.coerce
    .number({ message: 'Kişi sayısını rakamla girin.' })
    .int('Kişi sayısı tam sayı olmalı.')
    .min(1, 'Kişi sayısı en az 1 olmalı.')
    .max(100000, 'Kişi sayısı çok yüksek görünüyor; sizi arayınca konuşalım.'),
  kvkk_accepted: z.literal(true, {
    message: 'Devam etmek için KVKK aydınlatma metnini onaylayın.',
  }),
  /**
   * Bal küpü. Gerçek kullanıcı görmediği için boş kalır; botlar her alanı
   * doldurma eğiliminde olduğundan dolu gelmesi otomatik gönderim işaretidir.
   */
  website: z.string().max(0).optional(),
});

export type QuoteValues = z.input<typeof quoteSchema>;
export type QuotePayload = z.output<typeof quoteSchema>;
