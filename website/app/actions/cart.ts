'use server';

import { revalidatePath } from 'next/cache';
import { canOrderDay, fetchDailyMenu } from '@/lib/api/daily-menu';
import { fetchPrimaryLocation } from '@/lib/api/catalog';
import {
  addLine,
  conflictsWithServiceDate,
  readCart,
  removeLine,
  setQuantity,
  writeCart,
  EMPTY_CART,
} from '@/lib/cart';
import { userMessage } from '@/lib/api/client';
import { formatDayMonth, parseBusinessDate } from '@/lib/business-date';
import { dayUnavailableCopy } from '@/lib/labels';
import type { DailyMenu, MenuItem } from '@/lib/api/types';
import type { CartActionState } from '@/lib/action-state';

function ok(message: string): CartActionState {
  return { status: 'ok', message, at: Date.now() };
}

function fail(message: string): CartActionState {
  return { status: 'error', message, at: Date.now() };
}

function readInt(formData: FormData, key: string): number | null {
  const raw = formData.get(key);
  if (typeof raw !== 'string') return null;
  const parsed = Number.parseInt(raw, 10);
  return Number.isSafeInteger(parsed) ? parsed : null;
}

function readText(formData: FormData, key: string): string {
  const value = formData.get(key);
  return typeof value === 'string' ? value : '';
}

/**
 * Seçenek değerleri iki adla gelebilir: çok seçimli gruplar tek bir
 * `option_value_ids` altında, tek seçimli (radio/select) gruplar ise kendi
 * grup adları altında (`option_<id>`) — radio davranışı grup başına ayrı ad
 * ister.
 */
function readOptionValueIds(formData: FormData): number[] {
  const ids: number[] = [];
  for (const [key, value] of formData.entries()) {
    if (key !== 'option_value_ids' && !/^option_\d+$/.test(key)) continue;
    if (typeof value !== 'string') continue;
    const parsed = Number.parseInt(value, 10);
    if (Number.isSafeInteger(parsed) && parsed > 0) ids.push(parsed);
  }
  return ids;
}

/** Zorunlu seçenek gruplarının hepsi seçilmiş mi? */
function missingRequiredOption(item: MenuItem, chosen: number[]): string | null {
  const chosenSet = new Set(chosen);
  for (const option of item.options ?? []) {
    if (!option.required) continue;
    const satisfied = option.values.some((value) => chosenSet.has(value.id));
    if (!satisfied) return option.name;
  }
  return null;
}

/**
 * Sepete ekleme — **her zaman bir servis gününe**.
 *
 * Ürünler artık genel katalogdan değil O GÜNÜN MENÜSÜNDEN geliyor: aynı
 * ürünün fiyatı güne göre değişebiliyor ve bir ürün yalnızca menüsünde yer
 * aldığı gün satılabiliyor. Bu yüzden doğrulama katalogda değil,
 * `GET /locations/{id}/daily-menu?date=` yanıtında yapılıyor.
 *
 * Menü paketi de aynı yoldan ekleniyor: sözleşme paketi bir `menu_id` ile
 * sipariş ettiriyor (`DailyMenu.package.menu_id`), yani istek biçimi
 * "paket mi ürün mü" ayrımını taşımıyor.
 */
export async function addToCartAction(
  _prev: CartActionState,
  formData: FormData,
): Promise<CartActionState> {
  const menuId = readInt(formData, 'menu_id');
  const serviceDate = parseBusinessDate(readText(formData, 'service_date'));
  const quantityInput = readInt(formData, 'quantity');
  const quantity = quantityInput && quantityInput > 0 ? quantityInput : 1;
  const noteRaw = formData.get('note');
  const note = typeof noteRaw === 'string' && noteRaw.trim().length > 0 ? noteRaw.trim() : null;
  // Gün çakışması onayı: kullanıcı "sepeti sıfırla ve ekle" dediğinde form
  // aynı alanlarla ikinci kez gönderiliyor, yanına bu bayrak ekleniyor.
  const confirmReset = readText(formData, 'confirm_reset') === '1';

  if (menuId === null) return fail('Ürün seçilemedi, sayfayı yenileyip tekrar deneyin.');
  if (serviceDate === null) {
    return fail('Hangi gün için sipariş verdiğiniz okunamadı, sayfayı yenileyip tekrar deneyin.');
  }

  try {
    // Sepete ekleme bir sipariş kararıdır — vitrin ve menü taze okunur.
    const location = await fetchPrimaryLocation('fresh');
    if (!location) return fail('Vitrin bilgisi alınamadı, tekrar deneyin.');

    const menu: DailyMenu = await fetchDailyMenu(location.id, serviceDate, 'fresh');

    if (!canOrderDay(location, menu)) {
      // Gün kapısı kapalıysa sebebi menü söylüyor; şalter kapalıysa sebep
      // yok ve `dayUnavailableCopy` genel cümleye düşüyor.
      return fail(dayUnavailableCopy(menu.unavailable_reason, serviceDate).message);
    }

    // Paket, sözleşme açısından bir ürün gibi sipariş ediliyor: kimliği
    // `DailyMenu.package.menu_id`. O gün paket satılmıyorsa alan `null` ve
    // karşılaştırma hiçbir zaman tutmaz.
    const daily = menu.package ?? null;
    const isPackage = daily !== null && daily.menu_id === menuId;

    let name: string;
    let optionValueIds: number[] = [];

    if (daily !== null && isPackage) {
      if (!daily.is_available) {
        return fail(daily.sold_out_reason ?? `${daily.name} bugün için tükendi.`);
      }
      // Paketin seçeneği olmaz; sözleşme `option_value_ids` alanını paket
      // satırında yok sayıyor. Formdan geleni taşımıyoruz ki sunucu ile
      // istemci aynı satırı üretsin.
      name = daily.name;
    } else {
      const item = menu.items.find((candidate) => candidate.id === menuId);
      if (!item) {
        return fail(`Bu ürün ${formatDayMonth(serviceDate)} menüsünde yok.`);
      }
      if (!item.is_available) {
        return fail(item.sold_out_reason ?? `${item.name} tükendi.`);
      }

      optionValueIds = readOptionValueIds(formData);
      const missing = missingRequiredOption(item, optionValueIds);
      if (missing) return fail(`Devam etmek için "${missing}" seçimini yapın.`);

      name = item.name;
    }

    const cart = await readCart();

    /*
     * KARIŞIK GÜNLÜ SEPET YOK. Sepette başka bir günün ürünü varsa
     * kullanıcıya soruluyor; onaylarsa sepet o güne göre sıfırlanıyor
     * (`addLine` farklı günde satırları düşürüyor). Mobildeki "vitrin
     * değişince sepeti sıfırla" kalıbının aynısı.
     */
    if (!confirmReset && conflictsWithServiceDate(cart, serviceDate)) {
      return {
        status: 'conflict',
        at: Date.now(),
        conflictServiceDate: cart.serviceDate,
        message: `Sepetinizde ${formatDayMonth(cart.serviceDate ?? serviceDate)} günü için ürünler var. Bir sipariş tek bir güne verilebilir.`,
      };
    }

    const next = addLine(confirmReset ? EMPTY_CART : cart, {
      serviceDate,
      menuId,
      quantity,
      optionValueIds,
      note,
    });

    await writeCart(next);
    revalidatePath('/sepet');

    return ok(`${name} sepete eklendi.`);
  } catch (error) {
    return fail(userMessage(error, 'Ürün sepete eklenemedi, tekrar deneyin.'));
  }
}

export async function updateQuantityAction(
  _prev: CartActionState,
  formData: FormData,
): Promise<CartActionState> {
  const key = formData.get('line_key');
  const quantity = readInt(formData, 'quantity');
  if (typeof key !== 'string' || quantity === null) {
    return fail('Sepet güncellenemedi, tekrar deneyin.');
  }

  await writeCart(setQuantity(await readCart(), key, quantity));
  revalidatePath('/sepet');
  return ok(quantity <= 0 ? 'Ürün sepetten çıkarıldı.' : 'Adet güncellendi.');
}

export async function removeLineAction(
  _prev: CartActionState,
  formData: FormData,
): Promise<CartActionState> {
  const key = formData.get('line_key');
  if (typeof key !== 'string') return fail('Ürün sepetten çıkarılamadı.');

  await writeCart(removeLine(await readCart(), key));
  revalidatePath('/sepet');
  return ok('Ürün sepetten çıkarıldı.');
}

/**
 * Sepeti boşaltır.
 *
 * Sepet TEK bir güne bağlı olduğu için bu aynı zamanda "başka bir gün seç"
 * çıkışıdır: satırları yeni güne TAŞIMAK yanlış olurdu — bir ürünün başka
 * günün menüsünde yer alacağının garantisi yok ve fiyatı da o günün fiyatı
 * olurdu; müşteri onaylamadığı bir sepeti ödeme adımında bulurdu.
 */
export async function clearCartAction(): Promise<void> {
  await writeCart(EMPTY_CART);
  revalidatePath('/sepet');
}
