import 'server-only';

import { apiFetch } from './client';
import type { AccountPaymentStarted, AccountStatement, AccountSummary } from './types';

/**
 * Cari hesap uçları — W-12.
 *
 * Uçlar `docs/openapi.yaml` içinde zaten tanımlıydı ama sitede hiç
 * çağrılmıyordu: cari self-servisi "mobil uygulamaya özgü" diye
 * planlanmıştı (`docs/06` B2B notu). O karar v2.0'da değişti — kurumsal
 * müşterinin çoğu siparişi masaüstünden veriyor ve borcunu görmek için
 * telefon uygulaması indirmek zorunda kalması anlamsızdı.
 *
 * `server-only`: token httpOnly çerezde duruyor ve tarayıcıya hiç
 * geçmiyor. Bu modülün istemciden içe aktarılması derleme hatası verir.
 */

export async function fetchAccountSummary(token: string): Promise<AccountSummary> {
  return apiFetch<AccountSummary>('/account/summary', { token });
}

export async function fetchAccountStatement(
  token: string,
  range?: { from?: string; to?: string },
): Promise<AccountStatement> {
  return apiFetch<AccountStatement>('/account/statement', {
    token,
    query: {
      ...(range?.from ? { from: range.from } : {}),
      ...(range?.to ? { to: range.to } : {}),
    },
  });
}

/**
 * Ödeme başlatır ve sağlayıcının adresini döndürür.
 *
 * `full` ve `amount` BİRLİKTE GÖNDERİLMEZ: sunucu `full` geldiğinde
 * `amount`'u yok sayıyor, ama ikisini birden yollamak "hangisi geçerli"
 * sorusunu çağıran tarafa taşırdı. Çağıran biri ya da diğeri seçiyor.
 */
export async function startAccountPayment(
  token: string,
  payload: { amount: number } | { full: true },
): Promise<AccountPaymentStarted> {
  return apiFetch<AccountPaymentStarted>('/account/payments', {
    method: 'POST',
    token,
    body: payload,
  });
}
