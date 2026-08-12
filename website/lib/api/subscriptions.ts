import 'server-only';

import { apiFetch } from './client';
import type { Subscription, SubscriptionListResponse } from './types';

/**
 * Abonelik uçları — W-13.
 *
 * Uçlar sözleşmede vardı ama sitede hiç çağrılmıyordu (`docs/06` B2B notu
 * abonelik self-servisini mobile bırakmıştı). v2.0'da web de tam
 * self-servis: müşteri aboneliğini görür, gün atlar, duraklatır, iptal eder
 * ve yeni talep açar.
 *
 * FİYAT MÜŞTERİ TARAFINDAN BELİRLENMEZ. `POST /subscriptions` bir TALEP
 * açıyor (`status: pending`, fiyatsız); anlaşmalı porsiyon fiyatını admin
 * giriyor ve aboneliği `active` yapıyor. Bu, sunucu tarafındaki bir kural —
 * arayüz fiyat alanı hiç göstermiyor.
 */

export async function fetchSubscriptions(token: string): Promise<SubscriptionListResponse> {
  return apiFetch<SubscriptionListResponse>('/subscriptions', { token });
}

export async function fetchSubscription(token: string, id: number): Promise<Subscription> {
  return apiFetch<Subscription>(`/subscriptions/${id}`, { token });
}

/**
 * Aboneliği duraklatır — GÖVDESİZ.
 *
 * Sözleşme ve sunucu tarih aralığı istemiyor: duraklatma "şimdiden itibaren
 * belirsiz süreyle dur" demek ve `resume` ile açılıyor. Bitiş tarihi
 * gönderilseydi, o tarih geldiğinde kimin devam ettireceği belirsiz kalırdı
 * — otomatik devam etme kuralı sunucuda yok.
 */
export async function pauseSubscription(token: string, id: number): Promise<Subscription> {
  return apiFetch<Subscription>(`/subscriptions/${id}/pause`, { method: 'POST', token });
}

export async function resumeSubscription(token: string, id: number): Promise<Subscription> {
  return apiFetch<Subscription>(`/subscriptions/${id}/resume`, { method: 'POST', token });
}

export async function cancelSubscription(token: string, id: number): Promise<Subscription> {
  return apiFetch<Subscription>(`/subscriptions/${id}/cancel`, { method: 'POST', token });
}

/**
 * Tek günlük istisna: o günü atla ya da adedi değiştir.
 *
 * `quantity_override` MUTLAK bir sayıdır, ekleme değil — o günün toplam
 * porsiyonunu belirler. Aynı kural panelde de geçerli
 * (`PhoneOrders::onAddSubscriptionPortions` yorumu).
 */
export async function upsertSubscriptionException(
  token: string,
  id: number,
  payload: { service_date: string; skip?: boolean; quantity_override?: number | null },
): Promise<Subscription> {
  return apiFetch<Subscription>(`/subscriptions/${id}/exceptions`, {
    method: 'POST',
    token,
    body: payload,
  });
}
