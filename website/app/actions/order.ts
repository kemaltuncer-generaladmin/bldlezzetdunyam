'use server';

import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { ApiError, userMessage } from '@/lib/api/client';
import { isOrderingOpen } from '@/lib/api/catalog';
import { cancelOrder, createOrder } from '@/lib/api/orders';
import { clearCart, resolveCart } from '@/lib/cart';
import { readToken } from '@/lib/session';
import { istanbulLocalToUtcIso } from '@/lib/timezone';
import { checkoutSchema } from '@/lib/validation/checkout';
import type { Address, OrderCreateRequest, OrderCreatedResponse } from '@/lib/api/types';
import type { CancelState, CheckoutState } from '@/lib/action-state';

function invalid(message: string, fieldErrors: Record<string, string> = {}): CheckoutState {
  return { status: 'error', message, fieldErrors };
}

function text(formData: FormData, key: string): string {
  const value = formData.get(key);
  return typeof value === 'string' ? value : '';
}

/**
 * Sipariş oluşturma. **Ürünler istemciden alınmaz** — sepet cookie'sinden ve
 * canlı menüden yeniden kurulur; tutarı da sunucu hesaplar. Formdan yalnızca
 * teslimat/ödeme tercihleri okunur.
 */
export async function createOrderAction(
  _prev: CheckoutState,
  formData: FormData,
): Promise<CheckoutState> {
  const token = await readToken();
  if (!token) redirect('/giris?next=%2Fodeme');

  const parsed = checkoutSchema.safeParse({
    delivery_type: text(formData, 'delivery_type'),
    payment_method: text(formData, 'payment_method'),
    timing: text(formData, 'timing') || 'asap',
    requested_at_local: text(formData, 'requested_at_local'),
    address_line1: text(formData, 'address_line1'),
    address_district: text(formData, 'address_district'),
    address_city: text(formData, 'address_city'),
    address_note: text(formData, 'address_note'),
    customer_note: text(formData, 'customer_note'),
  });

  if (!parsed.success) {
    const fieldErrors: Record<string, string> = {};
    for (const issue of parsed.error.issues) {
      const field = issue.path[0];
      if (typeof field === 'string' && !(field in fieldErrors)) fieldErrors[field] = issue.message;
    }
    return invalid('Lütfen eksik alanları tamamlayın.', fieldErrors);
  }

  const values = parsed.data;
  const cart = await resolveCart();

  if (cart.lines.length === 0) redirect('/sepet');
  if (!cart.location) return invalid('Vitrin bilgisi alınamadı, tekrar deneyin.');
  if (!isOrderingOpen(cart.location)) {
    return invalid('Şu anda sipariş alamıyoruz. Menüyü inceleyebilirsiniz.');
  }
  if (cart.hasUnavailable) {
    return invalid('Sepetinizde tükenen ürün var. Sepetten çıkarıp tekrar deneyin.');
  }
  if (cart.subtotal < cart.location.min_order_total) {
    return invalid('Sepet tutarı minimum sipariş tutarının altında.');
  }
  if (!cart.location.payment_methods.includes(values.payment_method)) {
    return invalid('Seçtiğiniz ödeme yöntemi şu anda kullanılamıyor.', {
      payment_method: 'Bu ödeme yöntemi kapalı.',
    });
  }

  let requestedAt: string | null = null;
  if (values.timing === 'scheduled') {
    requestedAt = istanbulLocalToUtcIso(values.requested_at_local);
    if (!requestedAt) {
      return invalid('Teslim saati okunamadı.', {
        requested_at_local: 'Geçerli bir tarih ve saat seçin.',
      });
    }
  }

  const address: Address | null =
    values.delivery_type === 'delivery'
      ? {
          line1: values.address_line1,
          district: values.address_district,
          city: values.address_city,
          note: values.address_note.length > 0 ? values.address_note : null,
        }
      : null;

  const payload: OrderCreateRequest = {
    location_id: cart.location.id,
    items: cart.lines.map((line) => ({
      menu_id: line.menuId,
      quantity: line.quantity,
      ...(line.optionValueIds.length > 0 ? { option_value_ids: line.optionValueIds } : {}),
      ...(line.note ? { note: line.note } : {}),
    })),
    delivery_type: values.delivery_type,
    // Gel-al siparişte adres gönderilmez, teslimat ücreti de eklenmez.
    address,
    requested_at: requestedAt,
    payment_method: values.payment_method,
    customer_note: values.customer_note.length > 0 ? values.customer_note : null,
  };

  let created: OrderCreatedResponse;
  try {
    created = await createOrder(token, payload);
  } catch (error) {
    if (error instanceof ApiError) {
      if (error.status === 401) redirect('/giris?next=%2Fodeme&durum=suresi-doldu');
      if (error.code === 'LOCATION_CLOSED') {
        return invalid('Sipariş alımı kapandı. Seçtiğiniz saat kesim saatinden sonra olabilir.', {
          requested_at_local: 'Farklı bir saat seçin.',
        });
      }
      if (error.code === 'ITEM_UNAVAILABLE') {
        return invalid('Sepetinizdeki bir ürün tükendi. Sepeti güncelleyip tekrar deneyin.');
      }
      if (error.status === 429) {
        return invalid('Çok fazla sipariş denemesi yapıldı. Bir süre sonra tekrar deneyin.');
      }
      return invalid(error.message, error.fieldErrors());
    }
    return invalid(userMessage(error, 'Sipariş oluşturulamadı, tekrar deneyin.'));
  }

  await clearCart();
  revalidatePath('/sepet');
  revalidatePath('/siparislerim');

  // Online ödemede sağlayıcıya yönlendirilir; dönüşte takip ekranı açılır.
  const redirectUrl = created.payment.redirect_url;
  redirect(
    typeof redirectUrl === 'string' && redirectUrl.length > 0
      ? redirectUrl
      : `/siparis/${created.id}`,
  );
}

export async function cancelOrderAction(
  _prev: CancelState,
  formData: FormData,
): Promise<CancelState> {
  const token = await readToken();
  if (!token) redirect('/giris?next=%2Fsiparislerim');

  const raw = formData.get('order_id');
  const orderId = typeof raw === 'string' ? Number.parseInt(raw, 10) : Number.NaN;
  if (!Number.isSafeInteger(orderId)) {
    return { status: 'error', message: 'Sipariş bulunamadı.', at: Date.now() };
  }

  try {
    await cancelOrder(token, orderId);
  } catch (error) {
    if (error instanceof ApiError && error.code === 'INVALID_TRANSITION') {
      return {
        status: 'error',
        message: 'Sipariş hazırlanmaya başlandığı için artık iptal edilemiyor.',
        at: Date.now(),
      };
    }
    return {
      status: 'error',
      message: userMessage(error, 'Sipariş iptal edilemedi, tekrar deneyin.'),
      at: Date.now(),
    };
  }

  revalidatePath(`/siparis/${orderId}`);
  revalidatePath('/siparislerim');
  return { status: 'ok', message: 'Siparişiniz iptal edildi.', at: Date.now() };
}
