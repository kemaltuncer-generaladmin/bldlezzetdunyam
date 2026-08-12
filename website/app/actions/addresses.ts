'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { createAddress, deleteAddress, updateAddress } from '@/lib/api/addresses';
import { ApiError, userMessage } from '@/lib/api/client';
import { readToken } from '@/lib/session';
import { addressSchema } from '@/lib/validation/address';
import type { AddressActionState } from '@/lib/action-state';

const LOGIN = '/giris?next=%2Fhesabim%2Fadresler';

/**
 * Adres defteri eylemleri — W-15.
 *
 * Üç eylem aynı hata çevirisini ve aynı tazelemeyi paylaşıyor; ortak
 * sarmalayıcı o yüzden var. Tek bir "adres eylemi" fonksiyonuna `action`
 * alanıyla dallanmak, silmeyi bir dize karşılaştırmasına bağlamak olurdu.
 */
async function run(
  work: (token: string) => Promise<unknown>,
  fallback: string,
): Promise<AddressActionState> {
  const token = await readToken();
  if (!token) redirect(LOGIN);

  try {
    await work(token);
  } catch (error) {
    if (error instanceof ApiError && error.status === 401) {
      redirect(`${LOGIN}&durum=suresi-doldu`);
    }
    if (error instanceof ApiError && (error.status === 422 || error.status === 404)) {
      return {
        status: 'error',
        message: error.message || fallback,
        fieldErrors: error.fieldErrors(),
        at: Date.now(),
      };
    }
    return {
      status: 'error',
      message: userMessage(error, fallback),
      fieldErrors: {},
      at: Date.now(),
    };
  }

  // Ödeme adımı da kayıtlı adresleri okuyor; ikisi birden tazeleniyor ki
  // defterden silinen bir adres ödemede seçilebilir kalmasın.
  revalidatePath('/hesabim/adresler');
  revalidatePath('/odeme');

  return { status: 'ok', message: null, fieldErrors: {}, at: Date.now() };
}

function fieldErrorsOf(issues: { path: PropertyKey[]; message: string }[]): Record<string, string> {
  const out: Record<string, string> = {};
  for (const issue of issues) {
    const field = issue.path[0];
    if (typeof field === 'string' && !(field in out)) out[field] = issue.message;
  }
  return out;
}

function parse(formData: FormData) {
  return addressSchema.safeParse({
    label: String(formData.get('label') ?? ''),
    line1: String(formData.get('line1') ?? ''),
    district: String(formData.get('district') ?? ''),
    city: String(formData.get('city') ?? ''),
    note: String(formData.get('note') ?? ''),
    latitude: String(formData.get('latitude') ?? ''),
    longitude: String(formData.get('longitude') ?? ''),
    is_default: formData.get('is_default') === 'true',
  });
}

export async function saveAddressAction(
  _prev: AddressActionState,
  formData: FormData,
): Promise<AddressActionState> {
  const parsed = parse(formData);

  if (!parsed.success) {
    return {
      status: 'error',
      message: 'Lütfen alanları kontrol edin.',
      fieldErrors: fieldErrorsOf(parsed.error.issues),
      at: Date.now(),
    };
  }

  const id = Number(formData.get('id'));
  const payload = parsed.data;

  return Number.isFinite(id) && id > 0
    ? run((token) => updateAddress(token, id, payload), 'Adres güncellenemedi.')
    : run((token) => createAddress(token, payload), 'Adres kaydedilemedi.');
}

export async function deleteAddressAction(
  _prev: AddressActionState,
  formData: FormData,
): Promise<AddressActionState> {
  const id = Number(formData.get('id'));

  if (!Number.isFinite(id) || id <= 0) {
    return { status: 'error', message: 'Adres bulunamadı.', fieldErrors: {}, at: Date.now() };
  }

  return run((token) => deleteAddress(token, id), 'Adres silinemedi.');
}

/**
 * Varsayılan adresi değiştirir.
 *
 * Eskisini elle bırakmıyoruz: sunucu aynı anda en fazla bir adresin
 * varsayılan olmasını kendi garanti ediyor (`docs/openapi.yaml`
 * `SavedAddress.is_default`). İki taraf birden yazsaydı yarış çıkardı.
 */
export async function makeDefaultAddressAction(
  _prev: AddressActionState,
  formData: FormData,
): Promise<AddressActionState> {
  const id = Number(formData.get('id'));

  if (!Number.isFinite(id) || id <= 0) {
    return { status: 'error', message: 'Adres bulunamadı.', fieldErrors: {}, at: Date.now() };
  }

  return run(
    (token) => updateAddress(token, id, { is_default: true }),
    'Varsayılan adres değiştirilemedi.',
  );
}
