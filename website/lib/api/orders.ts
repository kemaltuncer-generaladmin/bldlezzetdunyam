import 'server-only';

import { apiFetch } from './client';
import type {
  OrderCreateRequest,
  OrderCreatedResponse,
  OrderDetail,
  OrderListResponse,
  PublicOrderTracking,
} from './types';

export async function createOrder(
  token: string,
  payload: OrderCreateRequest,
): Promise<OrderCreatedResponse> {
  return apiFetch<OrderCreatedResponse>('/orders', { method: 'POST', body: payload, token });
}

export async function fetchOrders(
  token: string,
  page = 1,
  perPage = 25,
): Promise<OrderListResponse> {
  return apiFetch<OrderListResponse>('/orders', { token, query: { page, per_page: perPage } });
}

/** Başkasının siparişi `404` döner — varlık sızdırılmaz (`docs/openapi.yaml`). */
export async function fetchOrder(token: string, id: number): Promise<OrderDetail> {
  return apiFetch<OrderDetail>(`/orders/${id}`, { token });
}

/**
 * Fişteki QR'ın açtığı takip verisi — **token yok** (K-20).
 *
 * Yetki `e`/`s` sorgu parametrelerindeki imzada. Yanıt siparişin daraltılmış
 * yüzüdür; adres, ad, telefon ve kalem listesi dönmez.
 *
 * `403` bozuk imza VEYA süresi dolmuş bağlantı demektir — sunucu ikisini
 * ayırmıyor, ayırmak elinde geçersiz bağlantı olan kişiye bilgi verirdi.
 */
export async function fetchPublicTracking(
  id: number,
  expires: string,
  signature: string,
): Promise<PublicOrderTracking> {
  return apiFetch<PublicOrderTracking>(`/public/orders/${id}/tracking`, {
    query: { e: expires, s: signature },
  });
}

export async function cancelOrder(token: string, id: number): Promise<OrderDetail> {
  return apiFetch<OrderDetail>(`/orders/${id}/cancel`, { method: 'POST', token });
}
