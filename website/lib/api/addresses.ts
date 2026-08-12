import 'server-only';

import { apiFetch } from './client';
import type { SavedAddress, SavedAddressInput, SavedAddressList } from './types';

/**
 * Adres defteri uçları — W-15.
 *
 * Uçlar sözleşmede baştan beri vardı ve mobil uygulama kullanıyordu; site
 * hiç çağırmıyordu. Sonuç: siteden sipariş veren müşteri adresini HER
 * SEFERİNDE elden yazıyordu — ve haritadan seçilmiş bir nokta olmadığı
 * için kurye fişindeki QR (K-14) siteden gelen siparişlerde hiç
 * basılmıyordu.
 *
 * Sipariş adresi yine de defterden BAĞLANMIYOR, KOPYALANIYOR
 * (`OrderFactory::storeAddress`): müşteri sonradan kayıtlı adresini
 * değiştirse bile geçmiş siparişin gittiği yer değişmemeli.
 */

export async function fetchAddresses(token: string): Promise<SavedAddressList> {
  return apiFetch<SavedAddressList>('/addresses', { token });
}

export async function createAddress(
  token: string,
  payload: SavedAddressInput,
): Promise<SavedAddress> {
  return apiFetch<SavedAddress>('/addresses', { method: 'POST', token, body: payload });
}

export async function updateAddress(
  token: string,
  id: number,
  payload: Partial<SavedAddressInput>,
): Promise<SavedAddress> {
  return apiFetch<SavedAddress>(`/addresses/${id}`, {
    method: 'PATCH',
    token,
    body: payload,
  });
}

export async function deleteAddress(token: string, id: number): Promise<void> {
  await apiFetch<void>(`/addresses/${id}`, { method: 'DELETE', token });
}
