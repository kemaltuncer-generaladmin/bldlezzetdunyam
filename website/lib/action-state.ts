/**
 * Sunucu eylemlerinin form durumları.
 *
 * Bu tipler ve başlangıç değerleri **bilinçli olarak** `'use server'` dosyaları
 * dışında durur: `'use server'` modüllerinden yalnızca async fonksiyon ihraç
 * edilebilir. Sabit bir nesne oradan ihraç edilirse istemciye sunucu referansı
 * olarak geçer ve `undefined` alan hatalarına yol açar.
 */

/**
 * `conflict` DÖRDÜNCÜ BİR DURUM ve hatadan ayrı (B-19).
 *
 * Sepet TEK bir servis gününe bağlı; başka bir günün ürünü eklenmek
 * istendiğinde yapılacak şey belli ama KARARI KULLANICI VERİYOR — sepeti
 * sıfırlayıp yeni güne geçmek ya da vazgeçmek. Bunu `error` olarak taşımak,
 * ekranın kırmızı bir uyarı gösterip hiçbir çıkış sunmaması demekti;
 * sessizce sıfırlamak ise müşterinin hazırladığı sepeti haber vermeden
 * silmek olurdu.
 */
export type CartActionState = {
  status: 'idle' | 'ok' | 'error' | 'conflict';
  message: string | null;
  /** Her işlemde değişir; istemci bunu tetikleyici olarak kullanır. */
  at: number;
  /** `conflict` durumunda sepetin ŞU ANDA bağlı olduğu gün. */
  conflictServiceDate?: string | null;
};

export const IDLE_CART_STATE: CartActionState = { status: 'idle', message: null, at: 0 };

export type AuthFormState = {
  status: 'idle' | 'error';
  message: string | null;
  /** Alan adı → Türkçe hata metni. `aria-describedby` ile bağlanır. */
  fieldErrors: Record<string, string>;
};

export const IDLE_AUTH_STATE: AuthFormState = { status: 'idle', message: null, fieldErrors: {} };

/**
 * Telefonla giriş durumu — W-11.
 *
 * İKİ AŞAMALI FORMUN TEK DURUMU. `phase` alanı hangi ekranın çizileceğini
 * söylüyor: `phone` numarayı ister, `code` altı haneyi. Ayrı iki bileşene
 * bölünseydi "kod ekranındayken numarayı düzelt" akışı iki bileşen arasında
 * durum taşımayı gerektirirdi.
 *
 * `phone` alanı geri taşınıyor çünkü doğrulama isteği numarayı da gönderiyor
 * ve kullanıcı onu ikinci kez yazmamalı.
 *
 * `resendAt`, "yeniden gönder" düğmesinin ne zaman açılacağını söyleyen
 * mutlak zaman damgası (ms). Kalan saniye olarak taşınsaydı, kullanıcı
 * sekmeyi arka plana alıp döndüğünde sayaç donmuş görünürdü.
 */
export type OtpFormState = {
  status: 'idle' | 'error';
  phase: 'phone' | 'code';
  phone: string;
  message: string | null;
  fieldErrors: Record<string, string>;
  resendAt: number;
};

export const IDLE_OTP_STATE: OtpFormState = {
  status: 'idle',
  phase: 'phone',
  phone: '',
  message: null,
  fieldErrors: {},
  resendAt: 0,
};

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

/**
 * Teklif formu durumu.
 *
 * `unconfigured`, `error`'dan ayrı bir durum: ikisi de "gönderilemedi" demek
 * ama sebepleri farklı ve kullanıcıya söylenecek şey farklı. `error`'da
 * "tekrar deneyin" doğru bir öneri; `unconfigured`'da tekrar denemek hiçbir
 * şeyi değiştirmez, sorun sunucu yapılandırmasında.
 */
export type QuoteState = {
  status: 'idle' | 'ok' | 'error' | 'unconfigured';
  message: string | null;
  fieldErrors: Record<string, string>;
  /** Her gönderimde değişir; istemci başarı ekranını buna göre tetikler. */
  at: number;
};

export const IDLE_QUOTE_STATE: QuoteState = {
  status: 'idle',
  message: null,
  fieldErrors: {},
  at: 0,
};

export type CancelState = {
  status: 'idle' | 'error' | 'ok';
  message: string | null;
  at: number;
};

export const IDLE_CANCEL_STATE: CancelState = { status: 'idle', message: null, at: 0 };

/*
 * `AccountPaymentState` KALDIRILDI (B-19).
 *
 * Cari ödeme formu ve onu besleyen sunucu eylemi müşteri arayüzünden
 * çıktı; geriye taşıyacak durumu olmayan bir tip kalmıştı. Uçların kendisi
 * duruyor (`lib/api/account.ts`) ama onlar durum tipi kullanmıyor.
 */

/**
 * Abonelik self-servis eylemlerinin ortak durumu — W-13.
 *
 * `at` her çalıştırmada değişiyor: aynı hata iki kez oluştuğunda React
 * nesneyi eşit görüp yeniden çizmezdi ve kullanıcı "tıkladım, bir şey
 * olmadı" derdi.
 */
export type SubscriptionActionState = {
  status: 'idle' | 'ok' | 'error';
  message: string | null;
  at: number;
};

export const IDLE_SUBSCRIPTION_STATE: SubscriptionActionState = {
  status: 'idle',
  message: null,
  at: 0,
};

/** Adres defteri eylemlerinin ortak durumu — W-15. */
export type AddressActionState = {
  status: 'idle' | 'ok' | 'error';
  message: string | null;
  fieldErrors: Record<string, string>;
  at: number;
};

export const IDLE_ADDRESS_STATE: AddressActionState = {
  status: 'idle',
  message: null,
  fieldErrors: {},
  at: 0,
};
