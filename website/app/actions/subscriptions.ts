'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import {
  cancelSubscription,
  pauseSubscription,
  resumeSubscription,
  upsertSubscriptionException,
} from '@/lib/api/subscriptions';
import { ApiError, userMessage } from '@/lib/api/client';
import { readToken } from '@/lib/session';
import type { SubscriptionActionState } from '@/lib/action-state';

const LOGIN = '/giris?next=%2Fhesabim%2Fabonelikler';

/**
 * Abonelik self-servis eylemleri — W-13.
 *
 * DÖRT EYLEM TEK DOSYADA ama tek fonksiyonda değil: hepsi aynı hata
 * çevirisini ve aynı yeniden doğrulamayı paylaşıyor, o yüzden ortak bir
 * sarmalayıcı var. Tek bir "abonelik eylemi" fonksiyonuna `action` alanıyla
 * dallanmak, formdan gelen bir dizeye göre yıkıcı işlem seçmek olurdu —
 * iptal ile duraklatmanın arası bir yazım hatası kadar olurdu.
 */
async function run(
  work: (token: string) => Promise<unknown>,
  fallback: string,
): Promise<SubscriptionActionState> {
  const token = await readToken();
  if (!token) redirect(LOGIN);

  try {
    await work(token);
  } catch (error) {
    if (error instanceof ApiError && error.status === 401) {
      redirect(`${LOGIN}&durum=suresi-doldu`);
    }
    if (error instanceof ApiError && (error.status === 422 || error.status === 404)) {
      return { status: 'error', message: error.message || fallback, at: Date.now() };
    }
    return { status: 'error', message: userMessage(error, fallback), at: Date.now() };
  }

  // Liste ve detay birlikte tazeleniyor: müşteri detaydan duraklatıp
  // listeye döndüğünde eski durumu görmemeli.
  revalidatePath('/hesabim/abonelikler');

  return { status: 'ok', message: null, at: Date.now() };
}

function subscriptionId(formData: FormData): number {
  return Number(formData.get('subscription_id'));
}

export async function pauseSubscriptionAction(
  _prev: SubscriptionActionState,
  formData: FormData,
): Promise<SubscriptionActionState> {
  const id = subscriptionId(formData);
  return run((token) => pauseSubscription(token, id), 'Abonelik duraklatılamadı.');
}

export async function resumeSubscriptionAction(
  _prev: SubscriptionActionState,
  formData: FormData,
): Promise<SubscriptionActionState> {
  const id = subscriptionId(formData);
  return run((token) => resumeSubscription(token, id), 'Abonelik devam ettirilemedi.');
}

export async function cancelSubscriptionAction(
  _prev: SubscriptionActionState,
  formData: FormData,
): Promise<SubscriptionActionState> {
  const id = subscriptionId(formData);
  return run((token) => cancelSubscription(token, id), 'Abonelik iptal edilemedi.');
}

/**
 * Bir günü atlar ya da o günün adedini değiştirir.
 *
 * `quantity_override` MUTLAK: o günün toplam porsiyonu. "Şu kadar ekle"
 * değil. Sunucu ve panel de aynı anlamı kullanıyor.
 */
export async function subscriptionExceptionAction(
  _prev: SubscriptionActionState,
  formData: FormData,
): Promise<SubscriptionActionState> {
  const id = subscriptionId(formData);
  const serviceDate = String(formData.get('service_date') ?? '');
  const skip = formData.get('skip') === 'true';
  const rawQuantity = String(formData.get('quantity_override') ?? '').trim();

  if (!/^\d{4}-\d{2}-\d{2}$/.test(serviceDate)) {
    return { status: 'error', message: 'Gün seçin.', at: Date.now() };
  }

  const quantity = rawQuantity === '' ? null : Number.parseInt(rawQuantity, 10);

  if (!skip && (quantity === null || !Number.isFinite(quantity) || quantity < 1)) {
    return { status: 'error', message: 'Porsiyon sayısı en az 1 olmalı.', at: Date.now() };
  }

  return run(
    (token) =>
      upsertSubscriptionException(token, id, {
        service_date: serviceDate,
        skip,
        // Atlanan günde adet anlamsız; sunucuya null gidiyor ki daha önce
        // girilmiş bir adet istisnası orada asılı kalmasın.
        quantity_override: skip ? null : quantity,
      }),
    'Gün güncellenemedi.',
  );
}
