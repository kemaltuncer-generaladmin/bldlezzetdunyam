'use server';

import { revalidatePath } from 'next/cache';
import { fetchCatalog, findItemById, isOrderingOpen } from '@/lib/api/catalog';
import { addLine, readCart, removeLine, setQuantity, writeCart } from '@/lib/cart';
import { userMessage } from '@/lib/api/client';
import type { MenuItem } from '@/lib/api/types';
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

export async function addToCartAction(
  _prev: CartActionState,
  formData: FormData,
): Promise<CartActionState> {
  const menuId = readInt(formData, 'menu_id');
  const quantityInput = readInt(formData, 'quantity');
  const quantity = quantityInput && quantityInput > 0 ? quantityInput : 1;
  const noteRaw = formData.get('note');
  const note = typeof noteRaw === 'string' && noteRaw.trim().length > 0 ? noteRaw.trim() : null;

  if (menuId === null) return fail('Ürün seçilemedi, sayfayı yenileyip tekrar deneyin.');

  try {
    // Sepete ekleme bir sipariş kararıdır — şalter ve stok taze okunur.
    const catalog = await fetchCatalog('fresh');

    if (!isOrderingOpen(catalog.location)) {
      return fail('Şu anda sipariş alamıyoruz. Menüyü inceleyebilirsiniz.');
    }

    const item = findItemById(catalog.categories, menuId);
    if (!item) return fail('Bu ürün menüde bulunamadı.');
    if (!item.is_available) return fail(`${item.name} şu anda tükendi.`);

    const optionValueIds = readOptionValueIds(formData);
    const missing = missingRequiredOption(item, optionValueIds);
    if (missing) return fail(`Devam etmek için "${missing}" seçimini yapın.`);

    const next = addLine(await readCart(), { menuId, quantity, optionValueIds, note });
    await writeCart(next);
    revalidatePath('/sepet');

    return ok(`${item.name} sepete eklendi.`);
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

export async function clearCartAction(): Promise<void> {
  await writeCart([]);
  revalidatePath('/sepet');
}
