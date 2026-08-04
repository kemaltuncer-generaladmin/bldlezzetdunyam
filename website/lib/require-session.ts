import 'server-only';

import { redirect } from 'next/navigation';
import { ApiError } from '@/lib/api/client';
import { fetchMe } from '@/lib/api/auth';
import { readToken } from '@/lib/session';
import type { Customer } from '@/lib/api/types';

export type ActiveSession = { token: string; customer: Customer };

function toLogin(nextPath: string, expired: boolean): never {
  const query = new URLSearchParams({ next: nextPath });
  if (expired) query.set('durum', 'suresi-doldu');
  redirect(`/giris?${query.toString()}`);
}

/**
 * Korumalı sayfaların girişi. Middleware yalnızca cookie varlığına bakar;
 * token'ın gerçekten geçerli olduğunu burada sunucuya sorarız.
 */
export async function requireSession(nextPath: string): Promise<ActiveSession> {
  const token = await readToken();
  if (!token) toLogin(nextPath, false);

  try {
    const customer = await fetchMe(token);
    return { token, customer };
  } catch (error) {
    if (error instanceof ApiError && error.status === 401) toLogin(nextPath, true);
    throw error;
  }
}
