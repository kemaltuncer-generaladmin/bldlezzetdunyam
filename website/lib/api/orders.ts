import 'server-only';

import { apiFetch } from './client';
import type {
  OrderCreateRequest,
  OrderCreatedResponse,
  OrderDetail,
  OrderListResponse,
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

export async function cancelOrder(token: string, id: number): Promise<OrderDetail> {
  return apiFetch<OrderDetail>(`/orders/${id}/cancel`, { method: 'POST', token });
}
