import { z } from 'zod';

import { coversCity, coversDistrict } from '@/lib/service-area';

/**
 * Ödeme formu doğrulaması. `pickup` seçildiğinde adres alanları **istenmez**
 * (`docs/06` §3, `docs/openapi.yaml` `OrderCreateRequest.address`).
 *
 * Alanlar boş metin olarak da gelebilir; koşullu zorunluluklar `superRefine`
 * içindedir. Böylece şemanın girdi ve çıktı tipleri aynı kalır ve React Hook
 * Form ile sunucu eylemi aynı tipi paylaşır.
 */
export const checkoutSchema = z
  .object({
    delivery_type: z.enum(['delivery', 'pickup']),
    payment_method: z.enum(['online', 'cash', 'account']),
    timing: z.enum(['asap', 'scheduled']),
    requested_at_local: z.string().trim(),
    address_line1: z.string().trim().max(255, 'Adres en fazla 255 karakter.'),
    address_district: z.string().trim().max(64, 'İlçe en fazla 64 karakter.'),
    address_city: z.string().trim().max(64, 'İl en fazla 64 karakter.'),
    address_note: z.string().trim().max(255, 'Adres notu en fazla 255 karakter.'),
    customer_note: z.string().trim().max(500, 'Sipariş notu en fazla 500 karakter.'),
  })
  .superRefine((values, ctx) => {
    if (values.delivery_type === 'delivery') {
      if (values.address_line1.length === 0) {
        ctx.addIssue({
          code: 'custom',
          path: ['address_line1'],
          message: 'Teslimat adresini girin.',
        });
      }
      // Boşluk değil, HİZMET ALANI denetimi: form ilçeyi listeden verdiği
      // için buraya ancak elle kurcalanmış bir gönderim başka değerle gelir.
      // Sunucu da aynı denetimi yapar; buradaki kopya yalnızca kullanıcıya
      // anlaşılır bir hata göstermek için.
      if (!coversDistrict(values.address_district)) {
        ctx.addIssue({
          code: 'custom',
          path: ['address_district'],
          message: 'Teslimat yapılan bir ilçe seçin.',
        });
      }
      if (!coversCity(values.address_city)) {
        ctx.addIssue({
          code: 'custom',
          path: ['address_city'],
          message: 'Şu an yalnızca Konya’ya teslimat yapıyoruz.',
        });
      }
    }

    if (values.timing === 'scheduled' && values.requested_at_local.length === 0) {
      ctx.addIssue({
        code: 'custom',
        path: ['requested_at_local'],
        message: 'Teslim saatini seçin.',
      });
    }
  });

export type CheckoutValues = z.infer<typeof checkoutSchema>;
