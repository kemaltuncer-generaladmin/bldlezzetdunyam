import type { DeliveryType, OrderStatus, PaymentMethod, PaymentStatus } from '@/lib/api/types';

const ORDER_STATUS_LABELS: Record<OrderStatus, string> = {
  yeni: 'Alındı',
  onaylandi: 'Onaylandı',
  hazirlaniyor: 'Hazırlanıyor',
  hazir: 'Hazır',
  yolda: 'Yolda',
  teslim_edildi: 'Teslim edildi',
  iptal: 'İptal edildi',
};

/**
 * Sunucu sözleşmeye değer **ekleyebilir** (`PaymentStatus` notu). Bilinmeyen
 * değerde çökmek yerine "Belirsiz" göster.
 */
export function orderStatusLabel(status: string): string {
  return ORDER_STATUS_LABELS[status as OrderStatus] ?? 'Belirsiz';
}

const PAYMENT_METHOD_LABELS: Record<PaymentMethod, string> = {
  cash: 'Kapıda ödeme',
  account: 'Cari hesap',
  online: 'Online ödeme (kredi kartı)',
};

const PAYMENT_METHOD_HINTS: Record<PaymentMethod, string> = {
  cash: 'Teslimat sırasında nakit veya kart ile ödersiniz.',
  account: 'Tutar cari hesabınıza işlenir, tahsilat ayrıca yapılır.',
  online: 'Güvenli ödeme sayfasına yönlendirilirsiniz.',
};

export function paymentMethodLabel(method: string): string {
  return PAYMENT_METHOD_LABELS[method as PaymentMethod] ?? 'Diğer';
}

export function paymentMethodHint(method: string): string {
  return PAYMENT_METHOD_HINTS[method as PaymentMethod] ?? '';
}

const PAYMENT_STATUS_LABELS: Record<PaymentStatus, string> = {
  pending: 'Ödeme bekleniyor',
  paid: 'Ödendi',
};

export function paymentStatusLabel(status: string): string {
  return PAYMENT_STATUS_LABELS[status as PaymentStatus] ?? 'Belirsiz';
}

const DELIVERY_TYPE_LABELS: Record<DeliveryType, string> = {
  delivery: 'Adrese teslim',
  pickup: 'Gel-al',
};

export function deliveryTypeLabel(type: string): string {
  return DELIVERY_TYPE_LABELS[type as DeliveryType] ?? 'Belirsiz';
}

/** Sipariş iptal edilebilir mi? Yalnızca `yeni` ve `onaylandi` (`docs/06` §4). */
export function isCancellable(status: string): boolean {
  return status === 'yeni' || status === 'onaylandi';
}

/** Terminal durumlar — polling burada durur. */
export function isTerminalStatus(status: string): boolean {
  return status === 'teslim_edildi' || status === 'iptal';
}
