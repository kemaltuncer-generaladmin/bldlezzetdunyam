'use server';

import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { ApiError, userMessage } from '@/lib/api/client';
import { fetchPrimaryLocation, isOrderingOpen } from '@/lib/api/catalog';
import { canOrderDay, fetchDailyMenu } from '@/lib/api/daily-menu';
import { cancelOrder, createOrder, fetchOrder } from '@/lib/api/orders';
import { addLine, clearCart, resolveCart, writeCart, EMPTY_CART, type Cart } from '@/lib/cart';
import { businessToday, formatDayMonth } from '@/lib/business-date';
import { dayUnavailableCopy } from '@/lib/labels';
import { readToken } from '@/lib/session';
import { istanbulLocalToUtcIso } from '@/lib/timezone';
import { checkoutSchema } from '@/lib/validation/checkout';
import type {
  Address,
  DailyMenuUnavailableReason,
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

/** Sözleşmedeki beş sebepten biri mi? Bilinmeyen değer `null`'a düşer. */
function readReason(details: Record<string, unknown> | null): DailyMenuUnavailableReason | null {
  const raw = details?.reason;
  return raw === 'closed_day' ||
    raw === 'not_published' ||
    raw === 'cutoff_passed' ||
    raw === 'past' ||
    raw === 'too_far'
    ? raw
    : null;
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

  if (cart.lines.length === 0 || cart.serviceDate === null) redirect('/sepet');
  if (!cart.location) return invalid('Vitrin bilgisi alınamadı, tekrar deneyin.');
  if (!isOrderingOpen(cart.location)) {
    return invalid('Şu anda sipariş alamıyoruz. Menüyü inceleyebilirsiniz.');
  }
  /*
   * GÜN KAPISI. Sepet hazırlanırken açık olan gün, ödeme sayfasında
   * beklerken kapanmış olabilir: kesim saati geçer, yönetici menüyü yayından
   * kaldırır. Sunucu bunu `POST /orders` içinde yine denetliyor; buradaki
   * denetim müşteriyi formu doldurup gönderdikten sonra reddedilmekten
   * kurtarıyor.
   */
  if (!cart.dayOrderable) {
    return invalid(dayUnavailableCopy(cart.dayUnavailableReason, cart.serviceDate).message);
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
    /*
     * SAAT, SERVİS GÜNÜNÜN İÇİNDE OLMAK ZORUNDA. Sözleşme `requested_at` ile
     * `service_date`in aynı güne düşmesini şart koşuyor; farklıysa sunucu
     * `422` döner. Burada yakalamak, müşterinin formu doldurup gönderdikten
     * sonra anlamsız bir doğrulama hatasıyla karşılaşmasını önlüyor.
     */
    if (values.requested_at_local.slice(0, 10) !== cart.serviceDate) {
      return invalid(`Seçtiğiniz saat ${formatDayMonth(cart.serviceDate)} gününe ait olmalı.`, {
        requested_at_local: 'Sipariş gününüzün içinde bir saat seçin.',
      });
    }

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
    /*
     * SİPARİŞ HANGİ GÜN İÇİN? Sepetin bağlı olduğu gün (B-19).
     *
     * `requested_at` ile birlikte gönderildiğinde İKİSİNİN GÜNÜ AYNI OLMAK
     * ZORUNDA (sözleşme): "cuma menüsünü perşembe 12:00'ye" mutfağın
     * karşılayamayacağı bir sipariş. `components/checkout-form.tsx`
     * saat seçicisini bu güne kilitliyor.
     */
    service_date: cart.serviceDate,
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
      /*
       * GÜN KAPISININ İKİ HATASI (B-19). Sunucu sebebi iki ayrı yoldan
       * söylüyor ve ikisi de burada Türkçeye çevriliyor — sunucunun
       * cümlesi ekrana basılmıyor (`lib/labels.ts` başındaki gerekçe).
       *
       *   * `LOCATION_CLOSED` — kapalı gün ya da kesim saati. Makine okunur
       *     bir sebep taşımıyor, o yüzden gün metnine düşülüyor.
       *   * `VALIDATION_FAILED` + `details.reason` — geçmiş gün, çok ileri
       *     tarih, yayınlanmamış menü.
       */
      if (error.code === 'LOCATION_CLOSED') {
        return invalid(
          `${formatDayMonth(cart.serviceDate)} için sipariş alımı kapandı. Takvimden başka bir gün seçebilirsiniz.`,
        );
      }
      if (error.code === 'VALIDATION_FAILED') {
        const reason = readReason(error.details);
        if (reason) return invalid(dayUnavailableCopy(reason, cart.serviceDate).message);
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
 * Geçmiş bir siparişi sepete geri yükler — W-10, B-19 ile yeniden yazıldı.
 *
 * ## Kaynak artık katalog değil, BUGÜNÜN MENÜSÜ
 *
 * Tekrarlanan sipariş her zaman **bugüne** kuruluyor ve yalnızca bugünün
 * menüsünde olan satırlar ekleniyor. Eski sürüm genel katalogda arıyordu;
 * günün menüsü akışında o katalogdaki bir ürün bugün satılmıyor olabilir ve
 * sepet ödeme adımında `ITEM_UNAVAILABLE` ile reddedilirdi.
 *
 * ## `component` satırları ATLANIYOR
 *
 * Paketin içindeki yemekler siparişte ayrı satır olarak duruyor
 * (`role: component`, fiyatı sıfır) ama sepete PAKET satırı ekleniyor;
 * sunucu içindekileri yeniden açıyor. İkisini birden eklemek, aynı yemeği
 * iki kez sipariş etmek demekti.
 *
 * ## SEÇENEKLER TAŞINAMIYOR VE BU SÖZLEŞMEDEN GELİYOR
 *
 * `OrderItem` seçenek KİMLİKLERİNİ değil, görünen ADLARINI taşıyor
 * (`options?: string[]`); "Az acılı" metninden hangi `option_value_id`
 * olduğunu geri çıkarmak, seçenek adı değiştiğinde sessizce yanlış ürün
 * eklemek demekti. Bu yüzden zorunlu seçeneği olan ürünler atlanıyor ve
 * kullanıcıya kaç satırın atlandığı SAYIYLA söyleniyor.
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

  const today = businessToday();

  let order: OrderDetail;
  let location: Awaited<ReturnType<typeof fetchPrimaryLocation>>;
  try {
    [order, location] = await Promise.all([
      fetchOrder(token, orderId),
      fetchPrimaryLocation('fresh'),
    ]);
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

  if (!location) {
    return { status: 'error', message: 'Vitrin bilgisi alınamadı.', at: Date.now() };
  }
  if (!isOrderingOpen(location)) {
    return {
      status: 'error',
      message: 'Şu anda sipariş alamıyoruz. Menüden çalışma saatlerini görebilirsiniz.',
      at: Date.now(),
    };
  }

  let menu;
  try {
    menu = await fetchDailyMenu(location.id, today, 'fresh');
  } catch (error) {
    return {
      status: 'error',
      message: userMessage(error, 'Bugünün menüsü alınamadı, tekrar deneyin.'),
      at: Date.now(),
    };
  }

  if (!canOrderDay(location, menu)) {
    return {
      status: 'error',
      message: dayUnavailableCopy(menu.unavailable_reason, today).message,
      at: Date.now(),
    };
  }

  const available = new Map(menu.items.map((item) => [item.id, item]));
  const packageMenuId = menu.package?.menu_id ?? null;

  // Tekrar HER ZAMAN yeni bir sepet kurar: eski sepet başka bir güne bağlı
  // olabilir ve iki günü birleştirmek karşılanamaz bir sipariş üretirdi.
  let cart: Cart = EMPTY_CART;
  let added = 0;
  let skipped = 0;

  for (const orderItem of order.items) {
    // Paketin içindekiler paketle birlikte geliyor; ayrıca eklenmez.
    if (orderItem.role === 'component') continue;

    const isPackage = packageMenuId !== null && orderItem.menu_id === packageMenuId;
    const item = available.get(orderItem.menu_id);

    if (isPackage) {
      if (!menu.package?.is_available) {
        skipped += 1;
        continue;
      }
    } else {
      // Menüde yok, tükenmiş ya da zorunlu seçeneği var.
      // `is_available` menüden kalkmayı, `sold_out_today` o günkü tükenmeyi
      // ayrı ayrı gösteriyor (K-11); ikisi de eklemeyi engelliyor.
      if (!item || !item.is_available || item.sold_out_today) {
        skipped += 1;
        continue;
      }
      if ((item.options ?? []).some((option) => option.required)) {
        skipped += 1;
        continue;
      }
    }

    cart = addLine(cart, {
      serviceDate: today,
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
      message:
        'Bu siparişteki ürünlerin hiçbiri bugünün menüsünde yok. Menüden seçim yapabilirsiniz.',
      at: Date.now(),
    };
  }

  await writeCart(cart);
  revalidatePath('/sepet');

  return {
    status: 'ok',
    message:
      skipped === 0
        ? 'Siparişiniz bugünün menüsünden sepete eklendi.'
        : `${added} ürün sepete eklendi. ${skipped} ürün bugünün menüsünde bulunmadığı ya da seçim gerektirdiği için atlandı.`,
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
