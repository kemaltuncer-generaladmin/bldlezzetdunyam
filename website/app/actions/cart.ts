'use server';

import { revalidatePath } from 'next/cache';
import { canOrderDay, dayStock, fetchDailyMenu } from '@/lib/api/daily-menu';
import { fetchPrimaryLocation } from '@/lib/api/catalog';
import {
  addLine,
  conflictsWithServiceDate,
  readCart,
  removeLine,
  setQuantity,
  writeCart,
  EMPTY_CART,
  type Cart,
} from '@/lib/cart';
import { userMessage } from '@/lib/api/client';
import { formatDayMonth, parseBusinessDate, type BusinessDate } from '@/lib/business-date';
import { dayUnavailableCopy } from '@/lib/labels';
import { maxAddable } from '@/lib/stock-policy';
import type { DailyMenu, MenuItem } from '@/lib/api/types';
import type { CartActionState } from '@/lib/action-state';
import type { CartLimitState, DayCartState } from './cart-state';

function ok(message: string): CartActionState {
  return { status: 'ok', message, at: Date.now() };
}

function fail(message: string): CartActionState {
  return { status: 'error', message, at: Date.now() };
}

function limit(message: string, addedQuantity: number): CartLimitState {
  return { status: 'limit', message, at: Date.now(), addedQuantity };
}

/**
 * Sepette O GÜN için duran toplam adet.
 *
 * Sepet başka bir güne bağlıysa `0`: gün tavanı SERVİS GÜNÜNE ait, sepetin
 * kendisine değil. Başka günün adetlerini saymak, salı için dolu bir sepetin
 * çarşamba kontenjanını da tüketmesi demekti.
 */
function quantityForDay(cart: Cart, serviceDate: BusinessDate): number {
  if (cart.serviceDate !== serviceDate) return 0;
  return cart.lines.reduce((total, line) => total + line.quantity, 0);
}

/**
 * Sepette BU KALEM için duran adet.
 *
 * Aynı ürünün farklı seçenekli satırları TOPLANIYOR: mutfak "az acılı" ile
 * "acılı" için ayrı tencere kurmuyor, stok ürünün kendisine ait. Satır satır
 * saymak, iki seçenekle sipariş veren müşteriye tavanı iki kez tanırdı.
 */
function quantityForItem(cart: Cart, serviceDate: BusinessDate, menuId: number): number {
  if (cart.serviceDate !== serviceDate) return 0;
  return cart.lines.reduce(
    (total, line) => (line.menuId === menuId ? total + line.quantity : total),
    0,
  );
}

/** Bir `menu_id`'nin o günkü kalan porsiyonu; `null` SINIRSIZ. */
function remainingForMenuId(menu: DailyMenu, menuId: number): number | null {
  const daily = menu.package;
  if (daily && daily.menu_id === menuId) return daily.remaining_portions ?? null;
  return menu.items.find((item) => item.id === menuId)?.remaining_portions ?? null;
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
 *
 * ## STOK TAVANI BURADA DA UYGULANIYOR
 *
 * Menü ekranı düğmeyi zaten kapatıyor ama o karar sayfanın çizildiği andaki
 * stoka dayanıyor; müşteri sekmeyi açık bırakıp on dakika sonra tıkladığında
 * kalan porsiyon değişmiş olabilir. Tavan aşılırsa istek reddedilmiyor,
 * KIRPILIYOR: üç isteyip iki alan müşteriye iki tanesini vermek, hiçbirini
 * vermemekten iyi (`lib/stock-policy.ts` → `maxAddable`).
 */
export async function addToCartAction(
  _prev: DayCartState,
  formData: FormData,
): Promise<DayCartState> {
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
    /** Bu kalemin kendi tavanı; `null` SINIRSIZ (gün tavanı ayrı okunur). */
    let itemRemaining: number | null = null;

    if (daily !== null && isPackage) {
      if (!daily.is_available) {
        return fail(daily.sold_out_reason ?? `${daily.name} bugün için tükendi.`);
      }
      // Paketin seçeneği olmaz; sözleşme `option_value_ids` alanını paket
      // satırında yok sayıyor. Formdan geleni taşımıyoruz ki sunucu ile
      // istemci aynı satırı üretsin.
      name = daily.name;
      itemRemaining = daily.remaining_portions ?? null;
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
      itemRemaining = item.remaining_portions ?? null;
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

    // Onaylı sıfırlamada sepet boşalıyor: tavan hesabı da boş sepete göre
    // yapılmalı, yoksa birazdan silinecek satırlar kontenjanı yiyor.
    const base = confirmReset ? EMPTY_CART : cart;
    const dayRemaining = dayStock(menu);

    const addable = maxAddable({
      dayRemaining,
      itemRemaining,
      alreadyInCartForDay: quantityForDay(base, serviceDate),
      alreadyInCartForItem: quantityForItem(base, serviceDate, menuId),
    });

    if (addable === 0) {
      /*
       * Sıfırın İKİ sebebi var ve müşteriye söylenecek şey ayrı: gün ya da
       * kalem tavanı dolduysa "kontenjan bitti" (başka gün seçmeli), tavan
       * hiç konmamışken sıfır çıktıysa satır başı azami adede dayanmıştır
       * (adet azaltmalı). Tek cümle yazmak, doksan dokuz porsiyon sepete
       * atmış müşteriye "kontenjan doldu" dedirtirdi.
       */
      const capped = dayRemaining !== null || itemRemaining !== null;
      return limit(
        capped
          ? `${name} için ${formatDayMonth(serviceDate)} kontenjanı doldu. Sepetinizdeki adet o günün kalanı kadar.`
          : `${name} için satırdaki azami adede ulaştınız.`,
        0,
      );
    }

    const accepted = Math.min(quantity, addable);

    const next = addLine(base, {
      serviceDate,
      menuId,
      quantity: accepted,
      optionValueIds,
      note,
    });

    await writeCart(next);
    revalidatePath('/sepet');

    if (accepted < quantity) {
      return limit(
        `${name} sepete ${accepted} adet eklendi; ${formatDayMonth(serviceDate)} için kalan bu kadardı.`,
        accepted,
      );
    }

    return ok(`${name} sepete eklendi.`);
  } catch (error) {
    return fail(userMessage(error, 'Ürün sepete eklenemedi, tekrar deneyin.'));
  }
}

/**
 * Adet güncelleme.
 *
 * ARTIRMA bir sipariş kararıdır ve tavan denetimi ister; AZALTMA ile silme
 * ise kalan porsiyonu artırır, yani menüyü çekmeye gerek yok. Ayrımı
 * yapmasaydık sepetten bir ürün çıkarmak bile iki ağ isteğine ve yeni bir
 * hata yoluna bağlanırdı — sepetin en sık kullanılan düğmesi için ağır bir
 * bedel.
 */
export async function updateQuantityAction(
  _prev: DayCartState,
  formData: FormData,
): Promise<DayCartState> {
  const key = formData.get('line_key');
  const quantity = readInt(formData, 'quantity');
  if (typeof key !== 'string' || quantity === null) {
    return fail('Sepet güncellenemedi, tekrar deneyin.');
  }

  const cart = await readCart();
  const line = cart.lines.find((candidate) => candidate.key === key) ?? null;
  const serviceDate = cart.serviceDate;

  if (line === null || serviceDate === null || quantity <= line.quantity) {
    await writeCart(setQuantity(cart, key, quantity));
    revalidatePath('/sepet');
    return ok(quantity <= 0 ? 'Ürün sepetten çıkarıldı.' : 'Adet güncellendi.');
  }

  let ceiling: number;
  try {
    const location = await fetchPrimaryLocation('fresh');
    if (!location) return fail('Vitrin bilgisi alınamadı, tekrar deneyin.');

    const menu = await fetchDailyMenu(location.id, serviceDate, 'fresh');

    // `maxAddable` "kaç tane DAHA" der; satırın ulaşabileceği tavan, o
    // satırın mevcut adedi üstüne eklenerek bulunur.
    ceiling =
      line.quantity +
      maxAddable({
        dayRemaining: dayStock(menu),
        itemRemaining: remainingForMenuId(menu, line.menuId),
        alreadyInCartForDay: quantityForDay(cart, serviceDate),
        alreadyInCartForItem: quantityForItem(cart, serviceDate, line.menuId),
      });
  } catch (error) {
    return fail(userMessage(error, 'Adet güncellenemedi, tekrar deneyin.'));
  }

  const accepted = Math.min(quantity, ceiling);
  await writeCart(setQuantity(cart, key, accepted));
  revalidatePath('/sepet');

  if (accepted < quantity) {
    return limit(
      `${formatDayMonth(serviceDate)} için kalan porsiyon en fazla ${accepted} adede yetiyor.`,
      accepted,
    );
  }

  return ok('Adet güncellendi.');
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
