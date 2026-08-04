/**
 * Sunucu eylemlerinin form durumları.
 *
 * Bu tipler ve başlangıç değerleri **bilinçli olarak** `'use server'` dosyaları
 * dışında durur: `'use server'` modüllerinden yalnızca async fonksiyon ihraç
 * edilebilir. Sabit bir nesne oradan ihraç edilirse istemciye sunucu referansı
 * olarak geçer ve `undefined` alan hatalarına yol açar.
 */

export type CartActionState = {
  status: 'idle' | 'ok' | 'error';
  message: string | null;
  /** Her işlemde değişir; istemci bunu tetikleyici olarak kullanır. */
  at: number;
};

export const IDLE_CART_STATE: CartActionState = { status: 'idle', message: null, at: 0 };

export type AuthFormState = {
  status: 'idle' | 'error';
  message: string | null;
  /** Alan adı → Türkçe hata metni. `aria-describedby` ile bağlanır. */
  fieldErrors: Record<string, string>;
};

export const IDLE_AUTH_STATE: AuthFormState = { status: 'idle', message: null, fieldErrors: {} };

export type CheckoutState = {
  status: 'idle' | 'error';
  message: string | null;
  fieldErrors: Record<string, string>;
};

export const IDLE_CHECKOUT_STATE: CheckoutState = {
  status: 'idle',
  message: null,
  fieldErrors: {},
};

export type CancelState = {
  status: 'idle' | 'error' | 'ok';
  message: string | null;
  at: number;
};

export const IDLE_CANCEL_STATE: CancelState = { status: 'idle', message: null, at: 0 };
