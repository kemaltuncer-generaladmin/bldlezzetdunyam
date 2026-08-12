'use server';

import { redirect } from 'next/navigation';
import { login, logout, register, requestOtp, verifyOtp } from '@/lib/api/auth';
import { ApiError, userMessage } from '@/lib/api/client';
import { clearSession, readToken, startSession } from '@/lib/session';
import {
  corporateRegisterSchema,
  loginSchema,
  otpCodeSchema,
  otpPhoneSchema,
} from '@/lib/validation/auth';
import { safeInternalPath } from '@/lib/safe-redirect';
import type { AuthResponse } from '@/lib/api/types';
import type { AuthFormState, OtpFormState } from '@/lib/action-state';

function invalid(message: string, fieldErrors: Record<string, string> = {}): AuthFormState {
  return { status: 'error', message, fieldErrors };
}

function zodFieldErrors(
  issues: { path: PropertyKey[]; message: string }[],
): Record<string, string> {
  const out: Record<string, string> = {};
  for (const issue of issues) {
    const field = issue.path[0];
    if (typeof field === 'string' && !(field in out)) out[field] = issue.message;
  }
  return out;
}

function text(formData: FormData, key: string): string {
  const value = formData.get(key);
  return typeof value === 'string' ? value : '';
}

export async function loginAction(
  _prev: AuthFormState,
  formData: FormData,
): Promise<AuthFormState> {
  const parsed = loginSchema.safeParse({
    email: text(formData, 'email'),
    password: text(formData, 'password'),
  });

  if (!parsed.success) {
    return invalid('Lütfen alanları kontrol edin.', zodFieldErrors(parsed.error.issues));
  }

  let auth: AuthResponse;
  try {
    auth = await login(parsed.data);
  } catch (error) {
    if (error instanceof ApiError && error.status === 422) {
      return invalid('E-posta veya parola hatalı.', error.fieldErrors());
    }
    if (error instanceof ApiError && error.status === 429) {
      return invalid('Çok fazla deneme yapıldı. Bir dakika sonra tekrar deneyin.');
    }
    return invalid(userMessage(error, 'Giriş yapılamadı, tekrar deneyin.'));
  }

  await startSession(auth.token, auth.customer.first_name);
  redirect(safeInternalPath(text(formData, 'next'), '/'));
}

export async function requestOtpAction(
  _prev: OtpFormState,
  formData: FormData,
): Promise<OtpFormState> {
  const parsed = otpPhoneSchema.safeParse({ phone: text(formData, 'phone') });

  if (!parsed.success) {
    return {
      status: 'error',
      phase: 'phone',
      phone: text(formData, 'phone'),
      message: 'Telefon numarasını kontrol edin.',
      fieldErrors: zodFieldErrors(parsed.error.issues),
      resendAt: 0,
    };
  }

  try {
    const result = await requestOtp(parsed.data.phone);

    return {
      status: 'idle',
      phase: 'code',
      phone: parsed.data.phone,
      message: null,
      fieldErrors: {},
      // Bekleme süresini SUNUCU söylüyor; arayüz sabit yazmıyor.
      resendAt: Date.now() + result.resend_after * 1000,
    };
  } catch (error) {
    if (error instanceof ApiError && error.status === 422) {
      /*
       * 422 burada "biraz bekleyin" demek (`OtpService::assertNotThrottled`).
       * Kullanıcı KOD EKRANINDA kalmalı: kodu zaten almış olabilir ve onu
       * numara ekranına geri atmak, elindeki geçerli kodu girememesine yol
       * açardı.
       */
      const retryAfter = Number(error.details?.retry_after ?? 0);

      return {
        status: 'error',
        phase: 'code',
        phone: parsed.data.phone,
        message: error.message || 'Yeni kod için biraz bekleyin.',
        fieldErrors: {},
        resendAt: Date.now() + (Number.isFinite(retryAfter) ? retryAfter : 60) * 1000,
      };
    }

    if (error instanceof ApiError && error.status === 429) {
      return {
        status: 'error',
        phase: 'phone',
        phone: parsed.data.phone,
        message: 'Çok fazla deneme yapıldı. Bir dakika sonra tekrar deneyin.',
        fieldErrors: {},
        resendAt: 0,
      };
    }

    return {
      status: 'error',
      phase: 'phone',
      phone: parsed.data.phone,
      message: userMessage(error, 'Kod gönderilemedi, tekrar deneyin.'),
      fieldErrors: {},
      resendAt: 0,
    };
  }
}

/** Kodu doğrular ve oturum açar — W-11, ikinci adım. */
export async function verifyOtpAction(
  prev: OtpFormState,
  formData: FormData,
): Promise<OtpFormState> {
  const phone = text(formData, 'phone') || prev.phone;
  const parsed = otpCodeSchema.safeParse({ phone, code: text(formData, 'code') });

  const stay = (message: string, fieldErrors: Record<string, string> = {}): OtpFormState => ({
    status: 'error',
    phase: 'code',
    phone,
    message,
    fieldErrors,
    resendAt: prev.resendAt,
  });

  if (!parsed.success) {
    return stay('Kodu kontrol edin.', zodFieldErrors(parsed.error.issues));
  }

  let auth: AuthResponse;
  try {
    auth = await verifyOtp(parsed.data.phone, parsed.data.code);
  } catch (error) {
    if (error instanceof ApiError && error.status === 422) {
      return stay(error.message || 'Kod doğrulanamadı.', error.fieldErrors());
    }
    if (error instanceof ApiError && error.status === 403) {
      return stay(error.message || 'Hesabınız devre dışı. Bizimle iletişime geçin.');
    }
    if (error instanceof ApiError && error.status === 429) {
      return stay('Çok fazla deneme yapıldı. Bir dakika sonra tekrar deneyin.');
    }
    return stay(userMessage(error, 'Kod doğrulanamadı, tekrar deneyin.'));
  }

  await startSession(auth.token, auth.customer.first_name);
  redirect(safeInternalPath(text(formData, 'next'), '/'));
}

/**
 * Kurumsal kayıt — W-11.
 *
 * `registerAction`'dan ayrı bir eylem: alan kümesi farklı ve kurum alanları
 * BURADA ZORUNLU (gerekçe `corporateRegisterSchema` üzerinde). Tek eyleme
 * sıkıştırılsaydı, hangi formdan geldiğine bakan bir dallanma gerekirdi ve
 * o dallanma ilk değişiklikte yanlış tarafa düşerdi.
 *
 * Kayıt başarılıysa hesap ANINDA sipariş verebilir: sunucu her yeni kaydı
 * kurumsal işaretliyor ve sipariş kapısı ona bakıyor. Cari hesap (veresiye)
 * ayrı bir karar; limiti yönetici tanımlayana kadar kapalı kalıyor.
 */
export async function corporateRegisterAction(
  _prev: AuthFormState,
  formData: FormData,
): Promise<AuthFormState> {
  const parsed = corporateRegisterSchema.safeParse({
    first_name: text(formData, 'first_name'),
    last_name: text(formData, 'last_name'),
    email: text(formData, 'email'),
    telephone: text(formData, 'telephone'),
    password: text(formData, 'password'),
    password_confirm: text(formData, 'password_confirm'),
    kvkk_accepted:
      formData.get('kvkk_accepted') === 'on' || formData.get('kvkk_accepted') === 'true',
    company_name: text(formData, 'company_name'),
    tax_office: text(formData, 'tax_office'),
    tax_number: text(formData, 'tax_number'),
  });

  if (!parsed.success) {
    return invalid('Lütfen alanları kontrol edin.', zodFieldErrors(parsed.error.issues));
  }

  const { password_confirm: _ignored, ...payload } = parsed.data;

  let auth: AuthResponse;
  try {
    auth = await register({
      ...payload,
      // Yetkili kişi ayrı sorulmuyor: kaydı açan kişi zaten yetkili.
      // Fazladan bir alan, aynı bilgiyi ikinci kez yazdırmak olurdu.
      contact_person: `${payload.first_name} ${payload.last_name}`.trim(),
      company_phone: payload.telephone,
    });
  } catch (error) {
    if (error instanceof ApiError && error.status === 422) {
      return invalid(
        error.message || 'Kayıt tamamlanamadı, alanları kontrol edin.',
        error.fieldErrors(),
      );
    }
    if (error instanceof ApiError && error.status === 429) {
      return invalid('Çok fazla deneme yapıldı. Bir dakika sonra tekrar deneyin.');
    }
    return invalid(userMessage(error, 'Kayıt tamamlanamadı, tekrar deneyin.'));
  }

  await startSession(auth.token, auth.customer.first_name);
  redirect(safeInternalPath(text(formData, 'next'), '/'));
}

export async function logoutAction(): Promise<void> {
  const token = await readToken();
  if (token) {
    try {
      await logout(token);
    } catch {
      // Sunucu token'ı iptal edemese bile yerel oturum kapatılır.
    }
  }
  await clearSession();
  redirect('/');
}
