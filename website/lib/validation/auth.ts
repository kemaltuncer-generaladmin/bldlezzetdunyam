import { z } from 'zod';

/**
 * Doğrulama şemaları istemci (React Hook Form) ve sunucu eylemi tarafından
 * **ortak** kullanılır. Sunucu son sözü söyler; istemci yalnızca erken uyarı
 * verir. Kurallar `docs/openapi.yaml` `RegisterRequest` ile birebir aynıdır.
 */

const emailField = z
  .string()
  .trim()
  .min(1, 'E-posta adresinizi girin.')
  .email('Geçerli bir e-posta adresi girin.');

const passwordField = z.string().min(8, 'Parola en az 8 karakter olmalıdır.');

/** `+90`, `0` ve boşluklar temizlenir; sözleşme 10 hane ister. */
export function normalizeTelephone(input: string): string {
  const digitsOnly = input.replace(/[^\d]/g, '');
  if (digitsOnly.startsWith('90') && digitsOnly.length === 12) return digitsOnly.slice(2);
  if (digitsOnly.startsWith('0') && digitsOnly.length === 11) return digitsOnly.slice(1);
  return digitsOnly;
}

export const loginSchema = z.object({
  email: emailField,
  password: passwordField,
});

export type LoginValues = z.infer<typeof loginSchema>;

export const registerSchema = z
  .object({
    first_name: z.string().trim().min(1, 'Adınızı girin.').max(64, 'Ad en fazla 64 karakter.'),
    last_name: z
      .string()
      .trim()
      .min(1, 'Soyadınızı girin.')
      .max(64, 'Soyad en fazla 64 karakter.'),
    email: emailField,
    telephone: z
      .string()
      .trim()
      .transform(normalizeTelephone)
      .refine(
        (value) => /^[1-9][0-9]{9}$/.test(value),
        'Telefonu başında 0 olmadan 10 hane girin. Örn. 5551234567',
      ),
    password: passwordField,
    password_confirm: z.string().min(1, 'Parolayı tekrar girin.'),
    kvkk_accepted: z.literal(true, {
      message: 'Devam etmek için KVKK aydınlatma metnini onaylayın.',
    }),
  })
  .refine((values) => values.password === values.password_confirm, {
    path: ['password_confirm'],
    message: 'Parolalar eşleşmiyor.',
  });

export type RegisterValues = z.input<typeof registerSchema>;
