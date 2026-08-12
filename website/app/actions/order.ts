'use server';

import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { ApiError, userMessage } from '@/lib/api/client';
import { fetchCatalog, flattenItems, isOrderingOpen } from '@/lib/api/catalog';
import { cancelOrder, createOrder, fetchOrder } from '@/lib/api/orders';
import { addLine, clearCart, readCart, resolveCart, writeCart } from '@/lib/cart';
import { readToken } from '@/lib/session';
import { istanbulLocalToUtcIso } from '@/lib/timezone';
import { checkoutSchema } from '@/lib/validation/checkout';
import type {
  Address,
  OrderCreateRequest,
  OrderCreatedResponse,
  OrderDetail,
} from '@/lib/api/types';
import type { CancelState, CartActionState, CheckoutState } from '@/lib/action-state';

function invalid(message: string, fieldErrors: Record<string, string> = {}): CheckoutState {
  return { status: 'error', message, fieldErrors };
}

/**
 * Metin koordinat çiftini sayıya çevirir — ikisi de geçerliyse.
 *
 * Biri boş ya da sayı değilse `{}` döner ve adres koordinatsız gider.
 * Sunucu da aynı kuralı uyguluyor (`OrderFactory::storeAddress`); buradaki
 * kopya, yarım bir çiftin ağa hiç çıkmamasını sağlıyor.
 */
function pinOf(
  latitude: string,
  longitude: string,
): { latitude: number; longitude: number } | Record<string, never> {
  const lat = Number.parseFloat(latitude);
  const lng = Number.parseFloat(longitude);

  return Number.isFinite(lat) && Number.isFinite(lng) ? { latitude: lat, longitude: lng } : {};
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
    address_latitude: text(formData, 'address_latitude'),
    address_longitude: text(formData, 'address_longitude'),
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
          /*
           * Haritadan seçilen nokta (W-16). Kurye fişindeki QR'ın (K-14)
           * basılabilmesinin tek şartı bu iki alan.
           *
           * İKİSİ BİRDEN ya da HİÇBİRİ: yarısı dolu bir koordinat
           * haritada gösterilemez. `pinOf` bu kuralı tek yerde uyguluyor.
           */
          ...pinOf(values.address_latitude, values.address_longitude),
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

/**
 * Geçmiş bir siparişi sepete geri yükler — W-10.
 *
 * SEÇENEKLER TAŞINAMIYOR VE BU SÖZLEŞMEDEN GELİYOR. `OrderItem` seçenek
 * KİMLİKLERİNİ değil, görünen ADLARINI taşıyor (`options?: string[]`);
 * "Az acılı" metninden hangi `option_value_id` olduğunu geri çıkarmak,
 * seçenek adı değiştiğinde sessizce yanlış ürün eklemek demekti.
 *
 * Bu yüzden ZORUNLU seçeneği olan ürünler atlanıyor ve kullanıcıya kaç
 * satırın atlandığı SAYIYLA söyleniyor. Sessizce eksik bir sepet
 * hazırlamak, müşterinin ödeme adımında fark etmesine yol açardı.
 *
 * Menüden kalkmış ya da bugün tükenmiş ürünler de atlanıyor: katalog
 * `fresh` çekiliyor, yani karar ISR önbelleğine değil o anki duruma
 * dayanıyor.
 */
export async function repeatOrderAction(
  _prev: CartActionState,
  formData: FormData,
): Promise<CartActionState> {
  const token = await readToken();
  if (!token) redirect('/giris?next=%2F');

  const orderId = Number(formData.get('order_id'));
  if (!Number.isFinite(orderId) || orderId <= 0) {
    return { status: 'error', message: 'Sipariş bulunamadı.', at: Date.now() };
  }

  let order: OrderDetail;
  let catalog: Awaited<ReturnType<typeof fetchCatalog>>;
  try {
    [order, catalog] = await Promise.all([fetchOrder(token, orderId), fetchCatalog('fresh')]);
  } catch (error) {
    if (error instanceof ApiError && error.status === 401) {
      redirect('/giris?next=%2F&durum=suresi-doldu');
    }
    return {
      status: 'error',
      message: userMessage(error, 'Sipariş okunamadı, tekrar deneyin.'),
      at: Date.now(),
    };
  }

  if (!isOrderingOpen(catalog.location)) {
    return {
      status: 'error',
      message: 'Şu anda sipariş alamıyoruz. Menüden çalışma saatlerini görebilirsiniz.',
      at: Date.now(),
    };
  }

  const available = new Map(flattenItems(catalog.categories).map((item) => [item.id, item]));

  let lines = await readCart();
  let added = 0;
  let skipped = 0;

  for (const orderItem of order.items) {
    const item = available.get(orderItem.menu_id);

    // Menüden kalkmış, tükenmiş ya da zorunlu seçeneği olan ürün.
    // `is_available` menüden kalkmayı, `sold_out_today` o günkü tükenmeyi
    // ayrı ayrı gösteriyor (K-11). İkisi de eklemeyi engelliyor.
    const unavailable = !item || !item.is_available || item.sold_out_today;

    if (unavailable || (item.options ?? []).some((option) => option.required)) {
      skipped += 1;
      continue;
    }

    lines = addLine(lines, {
      menuId: orderItem.menu_id,
      quantity: orderItem.quantity,
      optionValueIds: [],
      note: orderItem.note ?? null,
    });
    added += 1;
  }

  if (added === 0) {
    return {
      status: 'error',
      message: 'Bu siparişteki ürünlerin hiçbiri şu anda eklenemedi. Menüden seçim yapabilirsiniz.',
      at: Date.now(),
    };
  }

  await writeCart(lines);
  revalidatePath('/sepet');

  return {
    status: 'ok',
    message:
      skipped === 0
        ? 'Siparişiniz sepete eklendi.'
        : `${added} ürün sepete eklendi. ${skipped} ürün seçenek gerektirdiği ya da bugün bulunmadığı için atlandı.`,
    at: Date.now(),
  };
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
