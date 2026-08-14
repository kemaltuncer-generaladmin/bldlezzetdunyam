import 'server-only';

import { cookies } from 'next/headers';
import { fetchPrimaryLocation } from '@/lib/api/catalog';
import { canOrderDay, fetchDailyMenu } from '@/lib/api/daily-menu';
import { isBusinessDate, type BusinessDate } from '@/lib/business-date';
import { multiplyPrice } from '@/lib/format';
import type {
  DailyMenu,
  DailyMenuComponent,
  DailyMenuUnavailableReason,
  Location,
  MenuItem,
  MenuOptionValue,
} from '@/lib/api/types';

/**
 * Sepet `localStorage`'da değil **cookie**'de tutulur; SSR ilk boyamada
 * sepeti bilebilsin diye (`docs/06` §3).
 *
 * Cookie yalnızca **kimlik, adet ve SERVİS GÜNÜ** taşır — ad ve fiyat
 * taşımaz. Tutar her seferinde o günün canlı menüsünden yeniden hesaplanır,
 * sipariş anında da sunucu yeniden hesaplar. Böylece cookie'yi kurcalamak
 * fiyatı değiştiremez.
 */
export const CART_COOKIE = 'bld_cart';

/**
 * Sepetteki adet, `httpOnly` **olmayan** ayrı bir cookie'de de tutulur.
 * Sebep: başlıktaki rozeti sunucuda okumak `/` ve `/menu` sayfalarını dinamik
 * yapardı ve ISR'yi bozardı (SEO zorunluluğu, `docs/06` §2). Rozet istemcide
 * bu cookie'den okunur; kaynak doğruluk hâlâ `bld_cart`'tadır.
 */
export const CART_COUNT_COOKIE = 'bld_cart_n';

/**
 * ÇEREZ ŞEMASI SÜRÜMÜ.
 *
 * v1: `{ v: 1, i: [...] }` — servis günü YOK, sipariş her zaman "bugün"dü.
 * v2: `{ v: 2, d: 'YYYY-AA-GG', i: [...] }` — sepet TEK BİR servis gününe
 *     bağlı (B-19).
 *
 * v1 çerezi GÖÇ ETTİRİLMİYOR, DÜŞÜRÜLÜYOR. Göç etmek "günü bugün varsay"
 * demekti ve bu iki yönden de yanlış: kesim saati geçmişse o sepet artık
 * bugüne verilemez, geçmemişse bile ürünler bugünün menüsünde olmayabilir —
 * eski katalogdaki her ürün bugün satılmıyor. Sessizce yanlış güne bağlanmış
 * bir sepet, müşterinin ancak ödeme adımında fark edeceği bir hata olurdu.
 * Bunun yerine sepet boşalıyor ve kullanıcıya SÖYLENİYOR
 * (`ResolvedCart.legacyDiscarded`).
 */
const CART_SCHEMA_VERSION = 2;

const CART_MAX_AGE_SECONDS = 60 * 60 * 24 * 7;
const MAX_LINES = 50;
const MAX_QUANTITY = 99;
const MAX_NOTE_LENGTH = 255;

const isProduction = process.env.NODE_ENV === 'production';

/** Cookie'de saklanan biçim — kısa anahtarlar, 4 KB sınırı için. */
type StoredLine = {
  m: number;
  q: number;
  o?: number[];
  n?: string;
};

type StoredCart = { v: typeof CART_SCHEMA_VERSION; d: BusinessDate; i: StoredLine[] };

export type CartLine = {
  /** Satır kimliği: aynı ürün farklı seçenek/notla ayrı satırdır. */
  key: string;
  menuId: number;
  quantity: number;
  optionValueIds: number[];
  note: string | null;
};

/**
 * Çerezin çözülmüş hâli.
 *
 * `serviceDate` ile `lines` BİRLİKTE anlamlı: satırı olmayan bir sepetin günü
 * de yoktur (yoksa müşteri sepeti boşalttıktan sonra bile eski güne
 * bağlanırdı ve başka bir günden ekleme yaptığında sebepsiz yere onay
 * istenirdi).
 */
export type Cart = {
  serviceDate: BusinessDate | null;
  lines: CartLine[];
  /** v1 çerezi bulundu ve düşürüldü — kullanıcıya söylenmesi gerekiyor. */
  legacy: boolean;
};

export const EMPTY_CART: Cart = { serviceDate: null, lines: [], legacy: false };

export type ResolvedCartLine = CartLine & {
  /** Satırın o günkü adı — paket satırında paketin adı. */
  name: string;
  imageUrl: string | null;
  /** Menü paketi satırı mı? Para PAKET satırında; içindekiler ücretsiz. */
  isPackage: boolean;
  /** Paketin içindekiler; ürün satırında boş dizi. */
  components: DailyMenuComponent[];
  /** Paket satırında `null` — paket bir `MenuItem` değil. */
  item: MenuItem | null;
  optionValues: MenuOptionValue[];
  /** Seçenek farkları dahil birim fiyat (kuruş). */
  unitPrice: number;
  lineTotal: number;
  /** Ürün o günün menüsünden kalktı ya da tükendi. */
  unavailable: boolean;
  /** Mutfağın yazdığı tükenme sebebi; yoksa `null`. */
  unavailableReason: string | null;
};

export type ResolvedCart = {
  serviceDate: BusinessDate | null;
  lines: ResolvedCartLine[];
  /** O günün menüsünde artık bulunmayan satırların ürün kimlikleri. */
  missingMenuIds: number[];
  subtotal: number;
  itemCount: number;
  location: Location | null;
  /** Sepetin bağlı olduğu günün menüsü; sepet boşken `null`. */
  menu: DailyMenu | null;
  hasUnavailable: boolean;
  /** O güne **şu anda** sipariş verilebilir mi? (gün kapısı + anlık kapı) */
  dayOrderable: boolean;
  dayUnavailableReason: DailyMenuUnavailableReason | null;
  legacyDiscarded: boolean;
};

function lineKey(menuId: number, optionValueIds: number[], note: string | null): string {
  const options = [...optionValueIds].sort((a, b) => a - b).join('.');
  return `${menuId}|${options}|${note ?? ''}`;
}

function toCartLine(stored: StoredLine): CartLine | null {
  if (!Number.isSafeInteger(stored.m) || stored.m <= 0) return null;
  if (!Number.isSafeInteger(stored.q) || stored.q <= 0) return null;

  const optionValueIds = Array.isArray(stored.o)
    ? stored.o.filter((id): id is number => Number.isSafeInteger(id) && id > 0)
    : [];
  const note = typeof stored.n === 'string' && stored.n.length > 0 ? stored.n : null;
  const quantity = Math.min(stored.q, MAX_QUANTITY);

  return {
    key: lineKey(stored.m, optionValueIds, note),
    menuId: stored.m,
    quantity,
    optionValueIds,
    note,
  };
}

function parseCart(raw: string | undefined): Cart {
  if (!raw) return EMPTY_CART;

  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return EMPTY_CART;
  }
  if (typeof parsed !== 'object' || parsed === null) return EMPTY_CART;

  const candidate = parsed as { v?: unknown; d?: unknown; i?: unknown };
  if (!Array.isArray(candidate.i) || candidate.i.length === 0) return EMPTY_CART;

  // Eski şema: içeriği okunmuyor bile. Yalnızca "bir şey vardı" bilgisi
  // taşınıyor ki ekran bunu söyleyebilsin.
  if (candidate.v === 1) return { serviceDate: null, lines: [], legacy: true };

  if (candidate.v !== CART_SCHEMA_VERSION) return EMPTY_CART;

  // Gün okunamıyorsa satırlar da anlamsız: hangi güne ait olduğu bilinmeyen
  // bir sepet karşılanamaz bir siparişe dönüşür.
  const serviceDate = isBusinessDate(candidate.d) ? candidate.d : null;
  if (serviceDate === null) return EMPTY_CART;

  const lines: CartLine[] = [];
  for (const entry of candidate.i) {
    if (typeof entry !== 'object' || entry === null) continue;
    const line = toCartLine(entry as StoredLine);
    if (line) lines.push(line);
    if (lines.length >= MAX_LINES) break;
  }

  return lines.length > 0 ? { serviceDate, lines, legacy: false } : EMPTY_CART;
}

function serialize(cart: Cart & { serviceDate: BusinessDate }): string {
  const stored: StoredCart = {
    v: CART_SCHEMA_VERSION,
    d: cart.serviceDate,
    i: cart.lines.map((line) => ({
      m: line.menuId,
      q: line.quantity,
      ...(line.optionValueIds.length > 0 ? { o: line.optionValueIds } : {}),
      ...(line.note ? { n: line.note.slice(0, MAX_NOTE_LENGTH) } : {}),
    })),
  };
  return JSON.stringify(stored);
}

/** Ham sepet — ürün bilgisi olmadan, yalnızca cookie içeriği. */
export async function readCart(): Promise<Cart> {
  const store = await cookies();
  return parseCart(store.get(CART_COOKIE)?.value);
}

/**
 * Sepeti yazar. Satır kalmadıysa GÜN DE SİLİNİR: boş bir sepetin servis günü
 * olmaz.
 *
 * Yalnızca sunucu eylemlerinden ve rota işleyicilerinden çağrılabilir —
 * sunucu bileşenleri cookie yazamaz.
 */
export async function writeCart(cart: Cart): Promise<void> {
  const store = await cookies();

  if (cart.lines.length === 0 || cart.serviceDate === null) {
    store.delete(CART_COOKIE);
    store.delete(CART_COUNT_COOKIE);
    return;
  }

  store.set(CART_COOKIE, serialize({ ...cart, serviceDate: cart.serviceDate }), {
    httpOnly: true,
    sameSite: 'lax',
    secure: isProduction,
    path: '/',
    maxAge: CART_MAX_AGE_SECONDS,
  });

  const count = cart.lines.reduce((total, line) => total + line.quantity, 0);
  store.set(CART_COUNT_COOKIE, String(count), {
    httpOnly: false,
    sameSite: 'lax',
    secure: isProduction,
    path: '/',
    maxAge: CART_MAX_AGE_SECONDS,
  });
}

export async function clearCart(): Promise<void> {
  await writeCart(EMPTY_CART);
}

/** Sepetteki toplam ürün adedi — başlıktaki rozet bunu gösterir. */
export async function cartItemCount(): Promise<number> {
  const cart = await readCart();
  return cart.lines.reduce((total, line) => total + line.quantity, 0);
}

/**
 * Sepet BAŞKA bir güne bağlı mı?
 *
 * KARIŞIK GÜNLÜ SEPET KARŞILANAMAZ BİR SİPARİŞTİR: mutfak salı menüsünü
 * çarşamba tabağıyla birlikte gönderemez, sözleşme de siparişe TEK bir
 * `service_date` alanı veriyor. Bu yüzden başka günden ekleme sessizce
 * yapılmaz — kullanıcıya sorulur (`app/actions/cart.ts`).
 */
export function conflictsWithServiceDate(cart: Cart, serviceDate: BusinessDate): boolean {
  return cart.lines.length > 0 && cart.serviceDate !== null && cart.serviceDate !== serviceDate;
}

/**
 * Satır ekler. Sepet boşsa günü de bu ekleme belirler.
 *
 * ÇAĞIRAN ÖNCE `conflictsWithServiceDate` İLE SORAR: burada gün çakışması
 * denetlenmiyor, çünkü onay akışı (sıfırla ve ekle) bilerek çakışan bir günle
 * çağırıyor.
 */
export function addLine(
  cart: Cart,
  input: {
    serviceDate: BusinessDate;
    menuId: number;
    quantity: number;
    optionValueIds: number[];
    note: string | null;
  },
): Cart {
  const sameDay = cart.serviceDate === input.serviceDate;
  const lines = sameDay ? cart.lines : [];

  const key = lineKey(input.menuId, input.optionValueIds, input.note);
  const existing = lines.find((line) => line.key === key);

  if (existing) {
    return {
      serviceDate: input.serviceDate,
      legacy: false,
      lines: lines.map((line) =>
        line.key === key
          ? { ...line, quantity: Math.min(line.quantity + input.quantity, MAX_QUANTITY) }
          : line,
      ),
    };
  }

  if (lines.length >= MAX_LINES) return { ...cart, serviceDate: input.serviceDate, lines };

  return {
    serviceDate: input.serviceDate,
    legacy: false,
    lines: [
      ...lines,
      {
        key,
        menuId: input.menuId,
        quantity: Math.min(input.quantity, MAX_QUANTITY),
        optionValueIds: [...input.optionValueIds].sort((a, b) => a - b),
        note: input.note,
      },
    ],
  };
}

export function setQuantity(cart: Cart, key: string, quantity: number): Cart {
  const lines =
    quantity <= 0
      ? cart.lines.filter((line) => line.key !== key)
      : cart.lines.map((line) =>
          line.key === key ? { ...line, quantity: Math.min(quantity, MAX_QUANTITY) } : line,
        );

  return { ...cart, lines, serviceDate: lines.length > 0 ? cart.serviceDate : null };
}

export function removeLine(cart: Cart, key: string): Cart {
  const lines = cart.lines.filter((line) => line.key !== key);
  return { ...cart, lines, serviceDate: lines.length > 0 ? cart.serviceDate : null };
}

function collectOptionValues(item: MenuItem, optionValueIds: number[]): MenuOptionValue[] {
  const wanted = new Set(optionValueIds);
  const found: MenuOptionValue[] = [];
  for (const option of item.options ?? []) {
    for (const value of option.values) {
      if (wanted.has(value.id)) found.push(value);
    }
  }
  return found;
}

const EMPTY_RESOLVED: Omit<ResolvedCart, 'location' | 'legacyDiscarded'> = {
  serviceDate: null,
  lines: [],
  missingMenuIds: [],
  subtotal: 0,
  itemCount: 0,
  menu: null,
  hasUnavailable: false,
  dayOrderable: false,
  dayUnavailableReason: null,
};

/**
 * Cookie satırlarını **sepetin bağlı olduğu günün menüsüyle** birleştirir.
 *
 * Fiyat burada hesaplanır ama bağlayıcı değildir — sipariş tutarını sunucu
 * hesaplar. Kaynak artık genel katalog değil, o günün menüsü: aynı ürünün
 * fiyatı güne göre değişebiliyor (`DailyMenuItem::effectiveUnitPriceKurus`)
 * ve bir ürün yalnızca menüsünde yer aldığı gün satılabiliyor.
 *
 * Sepet ve ödeme ekranı sipariş kararı verir; hem vitrin hem menü **taze**
 * okunur.
 */
export async function resolveCart(): Promise<ResolvedCart> {
  const [cart, location] = await Promise.all([readCart(), fetchPrimaryLocation('fresh')]);

  // Sepet boşken menü çağrısı YAPILMIYOR: gösterilecek satır yok ve günün
  // menüsü boş sepet ekranında hiçbir soruyu cevaplamıyor. Vitrin ise
  // her hâlde gerekiyor (şalter bandı, asgari tutar).
  const menu =
    cart.serviceDate !== null && location !== null
      ? await fetchDailyMenu(location.id, cart.serviceDate, 'fresh')
      : null;

  if (menu === null || cart.serviceDate === null) {
    return {
      ...EMPTY_RESOLVED,
      serviceDate: cart.serviceDate,
      /*
       * Dolu bir sepeti "boş" göstermemek için satırlar DÜŞEN olarak
       * bildiriliyor. Buraya yalnızca vitrin listesi boş döndüğünde
       * (sözleşme ihlali) gelinir; menü isteği patlarsa `resolveCart`
       * zaten fırlatır ve ekran hata paneline düşer. Sessiz boş sepet
       * ikisinden de kötü: müşteri hazırladığı sepetin nereye gittiğini
       * sorar.
       */
      missingMenuIds: cart.lines.map((line) => line.menuId),
      location,
      legacyDiscarded: cart.legacy,
    };
  }

  const itemsById = new Map<number, MenuItem>(menu.items.map((item) => [item.id, item]));
  const packageMenuId = menu.package?.menu_id ?? null;

  const resolved: ResolvedCartLine[] = [];
  const missingMenuIds: number[] = [];
  let subtotal = 0;
  let itemCount = 0;

  for (const line of cart.lines) {
    const isPackage = packageMenuId !== null && line.menuId === packageMenuId;
    const item = isPackage ? null : (itemsById.get(line.menuId) ?? null);

    // Paket o gün satılmıyorsa ya da ürün menüden çıktıysa satır düşer.
    if (!isPackage && item === null) {
      missingMenuIds.push(line.menuId);
      continue;
    }

    const optionValues = item ? collectOptionValues(item, line.optionValueIds) : [];
    const basePrice = isPackage ? (menu.package?.price ?? 0) : (item?.price ?? 0);
    const unitPrice = optionValues.reduce(
      (total, value) => total + Math.trunc(value.price_delta),
      Math.trunc(basePrice),
    );
    const lineTotal = multiplyPrice(unitPrice, line.quantity);

    subtotal += lineTotal;
    itemCount += line.quantity;

    resolved.push({
      ...line,
      name: isPackage ? (menu.package?.name ?? 'Günün menüsü') : (item?.name ?? ''),
      imageUrl: (isPackage ? menu.image_url : item?.image_url) ?? null,
      isPackage,
      components: isPackage ? (menu.package?.components ?? []) : [],
      item,
      optionValues,
      unitPrice,
      lineTotal,
      unavailable: isPackage
        ? !(menu.package?.is_available ?? false)
        : !(item?.is_available ?? false),
      unavailableReason:
        (isPackage ? menu.package?.sold_out_reason : item?.sold_out_reason) ?? null,
    });
  }

  return {
    serviceDate: cart.serviceDate,
    lines: resolved,
    missingMenuIds,
    subtotal,
    itemCount,
    location,
    menu,
    hasUnavailable: resolved.some((line) => line.unavailable),
    dayOrderable: canOrderDay(location, menu),
    dayUnavailableReason: menu.unavailable_reason ?? null,
    legacyDiscarded: cart.legacy,
  };
}
