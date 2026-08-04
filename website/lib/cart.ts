import 'server-only';

import { cookies } from 'next/headers';
import { fetchCatalog } from '@/lib/api/catalog';
import { multiplyPrice } from '@/lib/format';
import type { Location, MenuItem, MenuOptionValue } from '@/lib/api/types';

/**
 * Sepet `localStorage`'da değil **cookie**'de tutulur; SSR ilk boyamada
 * sepeti bilebilsin diye (`docs/06` §3).
 *
 * Cookie yalnızca **kimlik ve adet** taşır — ad ve fiyat taşımaz. Tutar her
 * seferinde canlı menüden yeniden hesaplanır, sipariş anında da sunucu
 * yeniden hesaplar. Böylece cookie'yi kurcalamak fiyatı değiştiremez.
 */
export const CART_COOKIE = 'bld_cart';

/**
 * Sepetteki adet, `httpOnly` **olmayan** ayrı bir cookie'de de tutulur.
 * Sebep: başlıktaki rozeti sunucuda okumak `/` ve `/menu` sayfalarını dinamik
 * yapardı ve ISR'yi bozardı (SEO zorunluluğu, `docs/06` §2). Rozet istemcide
 * bu cookie'den okunur; kaynak doğruluk hâlâ `bld_cart`'tadır.
 */
export const CART_COUNT_COOKIE = 'bld_cart_n';

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

type StoredCart = { v: 1; i: StoredLine[] };

export type CartLine = {
  /** Satır kimliği: aynı ürün farklı seçenek/notla ayrı satırdır. */
  key: string;
  menuId: number;
  quantity: number;
  optionValueIds: number[];
  note: string | null;
};

export type ResolvedCartLine = CartLine & {
  item: MenuItem;
  optionValues: MenuOptionValue[];
  /** Seçenek farkları dahil birim fiyat (kuruş). */
  unitPrice: number;
  lineTotal: number;
  /** Ürün menüden kaldırıldı ya da tükendi. */
  unavailable: boolean;
};

export type ResolvedCart = {
  lines: ResolvedCartLine[];
  /** Menüde artık bulunmayan satırların ürün kimlikleri. */
  missingMenuIds: number[];
  subtotal: number;
  itemCount: number;
  location: Location | null;
  hasUnavailable: boolean;
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

function parseCart(raw: string | undefined): CartLine[] {
  if (!raw) return [];
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return [];
  }
  if (typeof parsed !== 'object' || parsed === null) return [];
  const candidate = parsed as { v?: unknown; i?: unknown };
  if (candidate.v !== 1 || !Array.isArray(candidate.i)) return [];

  const lines: CartLine[] = [];
  for (const entry of candidate.i) {
    if (typeof entry !== 'object' || entry === null) continue;
    const line = toCartLine(entry as StoredLine);
    if (line) lines.push(line);
    if (lines.length >= MAX_LINES) break;
  }
  return lines;
}

function serialize(lines: CartLine[]): string {
  const stored: StoredCart = {
    v: 1,
    i: lines.map((line) => ({
      m: line.menuId,
      q: line.quantity,
      ...(line.optionValueIds.length > 0 ? { o: line.optionValueIds } : {}),
      ...(line.note ? { n: line.note.slice(0, MAX_NOTE_LENGTH) } : {}),
    })),
  };
  return JSON.stringify(stored);
}

/** Ham sepet satırları — ürün bilgisi olmadan, yalnızca cookie içeriği. */
export async function readCart(): Promise<CartLine[]> {
  const store = await cookies();
  return parseCart(store.get(CART_COOKIE)?.value);
}

export async function writeCart(lines: CartLine[]): Promise<void> {
  const store = await cookies();
  if (lines.length === 0) {
    store.delete(CART_COOKIE);
    store.delete(CART_COUNT_COOKIE);
    return;
  }
  store.set(CART_COOKIE, serialize(lines), {
    httpOnly: true,
    sameSite: 'lax',
    secure: isProduction,
    path: '/',
    maxAge: CART_MAX_AGE_SECONDS,
  });
  const count = lines.reduce((total, line) => total + line.quantity, 0);
  store.set(CART_COUNT_COOKIE, String(count), {
    httpOnly: false,
    sameSite: 'lax',
    secure: isProduction,
    path: '/',
    maxAge: CART_MAX_AGE_SECONDS,
  });
}

export async function clearCart(): Promise<void> {
  await writeCart([]);
}

/** Sepetteki toplam ürün adedi — başlıktaki rozet bunu gösterir. */
export async function cartItemCount(): Promise<number> {
  const lines = await readCart();
  return lines.reduce((total, line) => total + line.quantity, 0);
}

export function addLine(
  lines: CartLine[],
  input: { menuId: number; quantity: number; optionValueIds: number[]; note: string | null },
): CartLine[] {
  const key = lineKey(input.menuId, input.optionValueIds, input.note);
  const existing = lines.find((line) => line.key === key);

  if (existing) {
    return lines.map((line) =>
      line.key === key
        ? { ...line, quantity: Math.min(line.quantity + input.quantity, MAX_QUANTITY) }
        : line,
    );
  }

  if (lines.length >= MAX_LINES) return lines;

  return [
    ...lines,
    {
      key,
      menuId: input.menuId,
      quantity: Math.min(input.quantity, MAX_QUANTITY),
      optionValueIds: [...input.optionValueIds].sort((a, b) => a - b),
      note: input.note,
    },
  ];
}

export function setQuantity(lines: CartLine[], key: string, quantity: number): CartLine[] {
  if (quantity <= 0) return lines.filter((line) => line.key !== key);
  return lines.map((line) =>
    line.key === key ? { ...line, quantity: Math.min(quantity, MAX_QUANTITY) } : line,
  );
}

export function removeLine(lines: CartLine[], key: string): CartLine[] {
  return lines.filter((line) => line.key !== key);
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

/**
 * Cookie satırlarını canlı menüyle birleştirir. Fiyat burada hesaplanır ama
 * bağlayıcı değildir — sipariş tutarını **sunucu** hesaplar.
 */
export async function resolveCart(): Promise<ResolvedCart> {
  // Sepet ve ödeme ekranı sipariş kararını verir; şalter durumu taze okunur.
  const [lines, catalog] = await Promise.all([readCart(), fetchCatalog('fresh')]);

  const itemsById = new Map<number, MenuItem>();
  for (const category of catalog.categories) {
    for (const item of category.items ?? []) itemsById.set(item.id, item);
  }

  const resolved: ResolvedCartLine[] = [];
  const missingMenuIds: number[] = [];
  let subtotal = 0;
  let itemCount = 0;

  for (const line of lines) {
    const item = itemsById.get(line.menuId);
    if (!item) {
      missingMenuIds.push(line.menuId);
      continue;
    }
    const optionValues = collectOptionValues(item, line.optionValueIds);
    const unitPrice = optionValues.reduce(
      (total, value) => total + Math.trunc(value.price_delta),
      Math.trunc(item.price),
    );
    const lineTotal = multiplyPrice(unitPrice, line.quantity);

    subtotal += lineTotal;
    itemCount += line.quantity;

    resolved.push({
      ...line,
      item,
      optionValues,
      unitPrice,
      lineTotal,
      unavailable: !item.is_available,
    });
  }

  return {
    lines: resolved,
    missingMenuIds,
    subtotal,
    itemCount,
    location: catalog.location,
    hasUnavailable: resolved.some((line) => line.unavailable),
  };
}
