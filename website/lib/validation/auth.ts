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

/**
 * Ortak kayıt alanları.
 *
 * DOĞRUDAN KULLANILMIYOR: bireysel kayıt sayfası v2.0'da kaldırıldı
 * (`/kayit` → `/kurumsal-kayit`, `next.config.ts`). Şema
 * `corporateRegisterSchema`'nın tabanı olarak duruyor — kurum alanları
 * onun üzerine ekleniyor. Ayrı tutulmasının sebebi, ad/e-posta/parola
 * kurallarının kurumsal alanlardan bağımsız değişebilmesi.
 */
export const registerSchema = z
  .object({
    first_name: z.string().trim().min(1, 'Adınızı girin.').max(64, 'Ad en fazla 64 karakter.'),
    last_name: z.string().trim().min(1, 'Soyadınızı girin.').max(64, 'Soyad en fazla 64 karakter.'),
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

/**
 * Telefonla giriş — W-11.
 *
 * Numara `normalizeTelephone` ile 10 haneye iniyor, yani `0555…`,
 * `+90 555…` ve `555…` aynı değere düşüyor. Sunucu da aynı işi yapıyor
 * (`OtpService::normalize`); ikisi birden gerekli çünkü buradaki hâli
 * kullanıcıya anında hata gösterebilmek için, oradaki hâli istemciye
 * güvenmediğimiz için var.
 */
export const otpPhoneSchema = z.object({
  phone: z
    .string()
    .trim()
    .transform(normalizeTelephone)
    .refine(
      (value) => /^[1-9][0-9]{9}$/.test(value),
      'Telefonu başında 0 olmadan 10 hane girin. Örn. 5551234567',
    ),
});

export type OtpPhoneValues = z.input<typeof otpPhoneSchema>;

export const otpCodeSchema = z.object({
  phone: z.string().trim().transform(normalizeTelephone),
  code: z
    .string()
    .trim()
    .regex(/^\d{6}$/, 'Kod 6 haneli olmalı.'),
});

export type OtpCodeValues = z.input<typeof otpCodeSchema>;

/**
 * Kurumsal kayıt — W-11.
 *
 * `registerSchema`'nın üzerine kurum alanları ekliyor. Sunucu bu alanları
 * hâlâ opsiyonel kabul ediyor (`docs/openapi.yaml` `RegisterRequest`), ama
 * SİTE ZORUNLU KILIYOR: sipariş kapısı kurumsal hesaplarda açık ve unvanı
 * olmayan bir "kurumsal" kayıt, faturalandırılamayan bir müşteri demek.
 *
 * Vergi numarası 10 (kurum) ya da 11 (şahıs şirketi, TCKN) hane olabilir;
 * ikisini de kabul etmek zorundayız çünkü küçük işletmelerin çoğu şahıs.
 */
export const corporateRegisterSchema = registerSchema.safeExtend({
  company_name: z
    .string()
    .trim()
    .min(2, 'Ticari unvanı girin.')
    .max(160, 'Unvan en fazla 160 karakter.'),
  tax_office: z.string().trim().min(2, 'Vergi dairesini girin.').max(120, 'En fazla 120 karakter.'),
  tax_number: z
    .string()
    .trim()
    .regex(/^\d{10,11}$/, 'Vergi numarası 10 hane, şahıs şirketinde TCKN 11 hane olmalı.'),
});

export type CorporateRegisterValues = z.input<typeof corporateRegisterSchema>;
