import 'server-only';

import { apiFetch } from './client';
import type { components, operations } from './schema';

/**
 * Abonelik sözleşmesi uçları — **kimlik GEREKTİRMEZ** (M2).
 *
 * Bağlantı aboneye SMS ile gidiyor ve onaylayan kişi çoğu zaman sitede
 * oturum açmış kişi değil, satın almayı onaylayan yetkilidir. Oturum istemek
 * onayı imkânsız hâle getirirdi; ikinci etken SMS kodudur
 * (`docs/openapi.yaml` §Sözleşme).
 *
 * Bu yüzden `apiFetch` çağrılarında `token` YOKTUR ve olmamalıdır: müşteri
 * oturumu taşınsaydı, sözleşmeyi imzalayan kişinin siteye giriş yapmış olması
 * gerekirdi.
 *
 * TİPLER BURADA ADLANDIRILIYOR, `types.ts`'te değil: o dosya bu dalgada başka
 * bir kulvarın elinde. Kaynak yine üretilmiş `schema.ts` — elle tip yazılmış
 * değil (`AGENTS.md` §2.3).
 */

export type SubscriptionContract = components['schemas']['SubscriptionContract'];
export type ContractStatus = components['schemas']['ContractStatus'];

/**
 * `202` gövdesi: kodun ömrü ve yeniden gönderme bekleme süresi SUNUCUDAN
 * gelir. Arayüz sabit saniye yazmaz — sunucudaki bekleme değiştiğinde ekranın
 * sayacı kendiliğinden uyar, aksi halde ikisi sessizce ayrışırdı.
 */
export type ContractOtpResponse =
  operations['requestContractOtp']['responses'][202]['content']['application/json'];

/** Belirteç yola gömülü; sözleşmede `minLength: 20, maxLength: 200`. */
function contractPath(token: string, suffix = ''): string {
  return `/contracts/${encodeURIComponent(token)}${suffix}`;
}

/**
 * Sözleşme metnini ve fiyatını okur.
 *
 * SÜRESİ DOLMUŞ BAĞLANTI HATA ATMAZ: `200` + `status: expired` döner ki ekran
 * "bu bağlantının süresi doldu, yenisini isteyin" diyebilsin. Tanınmayan
 * belirteç `404`'tür ve ondan ayrıdır — birinde abonenin yapacağı iş yeni
 * bağlantı istemek, öbüründe elindeki bağlantı hiç var olmamış.
 */
export async function fetchContract(token: string): Promise<SubscriptionContract> {
  const { data } = await apiFetch<{ data: SubscriptionContract }>(contractPath(token));
  return data;
}

/**
 * Sözleşmedeki telefona 6 haneli onay kodu gönderir.
 *
 * **Numara istekte GÖNDERİLMEZ**, sözleşmenin kayıtlı numarasına gider:
 * istemciden alınsaydı bağlantıyı ele geçiren biri kodu kendi telefonuna
 * ısmarlayıp sözleşmeyi onaylayabilirdi. İmzalı bağlantı tek başına kimlik
 * değildir.
 */
export async function requestContractOtp(token: string): Promise<ContractOtpResponse> {
  return apiFetch<ContractOtpResponse>(contractPath(token, '/otp'), { method: 'POST' });
}

/**
 * SMS kodunu doğrular ve sözleşmeyi `approved` yapar.
 *
 * [fullName] ZORUNLU DEĞİL ve doğrulanmaz: onayın kimin elinden geçtiğini
 * belgeye yazmak için alınır. Boş geldiğinde alan gövdeye hiç konmaz —
 * boş dize göndermek, "adını boş bıraktı" ile "ad alanı yoktu"yu aynı şeye
 * indirgerdi.
 */
export async function approveContract(
  token: string,
  code: string,
  fullName?: string,
): Promise<SubscriptionContract> {
  const { data } = await apiFetch<{ data: SubscriptionContract }>(contractPath(token, '/approve'), {
    method: 'POST',
    body: fullName ? { code, full_name: fullName } : { code },
  });
  return data;
}
