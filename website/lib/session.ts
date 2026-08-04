import 'server-only';

import { cookies } from 'next/headers';
import { fetchMe } from '@/lib/api/auth';
import { ApiError } from '@/lib/api/client';
import type { Customer } from '@/lib/api/types';

/** Oturum token'ı. `httpOnly` — JavaScript'e hiç açılmaz. */
export const SESSION_COOKIE = 'bld_token';
/** Sunucu isteği olmadan başlık "Giriş yap" mı diyecek? Yalnızca ad tutar. */
export const SESSION_NAME_COOKIE = 'bld_name';

const THIRTY_DAYS_SECONDS = 60 * 60 * 24 * 30;

const isProduction = process.env.NODE_ENV === 'production';

export async function readToken(): Promise<string | null> {
  const store = await cookies();
  const value = store.get(SESSION_COOKIE)?.value;
  return value && value.length > 0 ? value : null;
}

export async function readCustomerName(): Promise<string | null> {
  const store = await cookies();
  return store.get(SESSION_NAME_COOKIE)?.value ?? null;
}

export async function startSession(token: string, firstName: string): Promise<void> {
  const store = await cookies();
  store.set(SESSION_COOKIE, token, {
    httpOnly: true,
    sameSite: 'lax',
    secure: isProduction,
    path: '/',
    maxAge: THIRTY_DAYS_SECONDS,
  });
  store.set(SESSION_NAME_COOKIE, firstName, {
    httpOnly: false,
    sameSite: 'lax',
    secure: isProduction,
    path: '/',
    maxAge: THIRTY_DAYS_SECONDS,
  });
}

export async function clearSession(): Promise<void> {
  const store = await cookies();
  store.delete(SESSION_COOKIE);
  store.delete(SESSION_NAME_COOKIE);
}

/**
 * Oturumdaki müşteri. Token yoksa veya sunucu `401` derse `null` döner —
 * çağıran taraf yönlendirmeye kendisi karar verir.
 */
export async function getCurrentCustomer(): Promise<Customer | null> {
  const token = await readToken();
  if (!token) return null;
  try {
    return await fetchMe(token);
  } catch (error) {
    if (error instanceof ApiError && error.status === 401) return null;
    throw error;
  }
}

/**
 * Hiçbir koşulda fırlatmayan sürüm. `/giris` bunu kullanır: token varsa ama
 * geçersizse kullanıcı giriş ekranında kalmalı, aksi hâlde korumalı sayfa ile
 * giriş sayfası arasında sonsuz yönlendirme oluşur.
 */
export async function getCurrentCustomerSafe(): Promise<Customer | null> {
  try {
    return await getCurrentCustomer();
  } catch {
    return null;
  }
}
