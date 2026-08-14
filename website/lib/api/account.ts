import 'server-only';

import { apiFetch } from './client';
import type { AccountPaymentStarted, AccountStatement, AccountSummary } from './types';

/**
 * Cari hesap uçları — W-12.
 *
 * ## BU DOSYA ŞU AN HİÇBİR YERDEN ÇAĞRILMIYOR VE BU KASITLI (B-19)
 *
 * İşletme sahibinin kararıyla cari hesap **müşteri arayüzlerinden** kalktı:
 * `/hesabim/cari` sayfası, bakiye kartı, ödeme formu ve `account` ödeme
 * yöntemi web'den; karşılıkları mobilden kaldırıldı. Sipariş artık günün
 * menüsü üzerinden yürüyor ve tahsilat müşteri kendi kendine yapmıyor.
 *
 * ARKA UÇ, API VE ADMIN PANEL AYNEN DURUYOR: `/account/summary`,
 * `/account/statement` ve `/account/payments` sözleşmede (`docs/openapi.yaml`)
 * yayınlanmış uçlar; panelden cari işleyen personel onları kullanmaya devam
 * ediyor. Bu istemci sarmalayıcısını silmek sözleşmeyi kırmaz ama arayüz geri
 * istendiğinde üç ucun tip güvenli çağrısını sıfırdan yazdırırdı — dosyanın
 * bedeli, kullanılmadığı sürece derlemeye giren birkaç satır.
 *
 * KULLANMADAN ÖNCE: cari yüzeyini geri açmak bir ÜRÜN kararıdır, bir içe
 * aktarma satırı değil. Yeni bir çağrı eklemeden önce kararın geri alındığını
 * doğrula.
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
