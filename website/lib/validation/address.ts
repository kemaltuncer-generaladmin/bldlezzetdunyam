import { z } from 'zod';

import { SERVICE_AREA_CITY, containsPoint, coversCity, coversDistrict } from '@/lib/service-area';

/**
 * Kayıtlı adres doğrulaması — W-15.
 *
 * `checkoutSchema` ile aynı hizmet alanı kurallarını uyguluyor ama ayrı bir
 * şema: adres defterinde `label` ve `is_default` var, ödeme adımında yok;
 * ödeme adımında ise teslim zamanı ve ödeme yöntemi var, burada yok. Ortak
 * bir şemaya `.partial()` ile yaklaşmak, her iki tarafta da olmayan
 * alanları isteğe bağlı hâle getirip doğrulamayı gevşetirdi.
 */
export const addressSchema = z
  .object({
    label: z.string().trim().max(48, 'Etiket en fazla 48 karakter.'),
    line1: z.string().trim().min(1, 'Adresi girin.').max(255, 'Adres en fazla 255 karakter.'),
    district: z.string().trim(),
    city: z.string().trim(),
    note: z.string().trim().max(255, 'Adres notu en fazla 255 karakter.'),
    /** Metin olarak geliyor: `FormData` yalnızca dize taşıyor. */
    latitude: z.string().trim(),
    longitude: z.string().trim(),
    is_default: z.boolean(),
  })
  .superRefine((values, ctx) => {
    if (!coversDistrict(values.district)) {
      ctx.addIssue({
        code: 'custom',
        path: ['district'],
        message: 'Teslimat yapılan bir ilçe seçin.',
      });
    }
    if (!coversCity(values.city)) {
      ctx.addIssue({
        code: 'custom',
        path: ['city'],
        message: `Şu an yalnızca ${SERVICE_AREA_CITY} içine teslimat yapıyoruz.`,
      });
    }

    /*
     * Koordinat İSTEĞE BAĞLI ama girildiyse hizmet alanının içinde olmalı.
     * Dışarıdaki bir iğne kurye fişine basılır ve kuryeyi yanlış yere
     * götürür — hiç iğne olmamasından kötü.
     */
    const pin = toPin(values.latitude, values.longitude);
    if (pin && !containsPoint(pin.latitude, pin.longitude)) {
      ctx.addIssue({
        code: 'custom',
        path: ['latitude'],
        message: 'Seçilen nokta teslimat alanımızın dışında.',
      });
    }
  })
  .transform((values) => ({
    label: values.label.length > 0 ? values.label : null,
    line1: values.line1,
    district: values.district,
    city: values.city,
    note: values.note.length > 0 ? values.note : null,
    is_default: values.is_default,
    // İKİSİ BİRDEN ya da HİÇBİRİ: yarısı dolu bir koordinat haritada
    // gösterilemez ve sözleşme de öyle diyor.
    ...(toPin(values.latitude, values.longitude) ?? {}),
  }));

export type AddressValues = z.input<typeof addressSchema>;

function toPin(
  latitude: string,
  longitude: string,
): { latitude: number; longitude: number } | null {
  const lat = Number.parseFloat(latitude);
  const lng = Number.parseFloat(longitude);

  return Number.isFinite(lat) && Number.isFinite(lng) ? { latitude: lat, longitude: lng } : null;
}
