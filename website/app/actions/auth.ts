'use server';

import { redirect } from 'next/navigation';
import { login, logout, register } from '@/lib/api/auth';
import { ApiError, userMessage } from '@/lib/api/client';
import { clearSession, readToken, startSession } from '@/lib/session';
import { loginSchema, registerSchema } from '@/lib/validation/auth';
import { safeInternalPath } from '@/lib/safe-redirect';
import type { AuthResponse } from '@/lib/api/types';
import type { AuthFormState } from '@/lib/action-state';

function invalid(message: string, fieldErrors: Record<string, string> = {}): AuthFormState {
  return { status: 'error', message, fieldErrors };
}

function zodFieldErrors(issues: { path: PropertyKey[]; message: string }[]): Record<string, string> {
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

export async function registerAction(
  _prev: AuthFormState,
  formData: FormData,
): Promise<AuthFormState> {
  const parsed = registerSchema.safeParse({
    first_name: text(formData, 'first_name'),
    last_name: text(formData, 'last_name'),
    email: text(formData, 'email'),
    telephone: text(formData, 'telephone'),
    password: text(formData, 'password'),
    password_confirm: text(formData, 'password_confirm'),
    kvkk_accepted: formData.get('kvkk_accepted') === 'on' || formData.get('kvkk_accepted') === 'true',
  });

  if (!parsed.success) {
    return invalid('Lütfen alanları kontrol edin.', zodFieldErrors(parsed.error.issues));
  }

  const { password_confirm: _ignored, ...payload } = parsed.data;

  let auth: AuthResponse;
  try {
    auth = await register(payload);
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
