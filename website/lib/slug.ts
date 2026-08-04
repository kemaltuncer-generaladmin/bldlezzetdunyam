import type { MenuItem } from '@/lib/api/types';

/**
 * VARSAYIM: Sözleşmede `MenuItem.slug` **yoktur** (`docs/openapi.yaml`
 * `MenuItem`), ama `/urun/[slug]` rotası SEO gereği zorunludur
 * (`docs/06` §2). Bu yüzden slug istemcide türetilir:
 *
 *     "Tavuk Sote" (id 101) → "tavuk-sote-101"
 *
 * Sondaki kimlik çözümlemeyi tek anlamlı yapar: ürün adı değişse bile eski
 * bağlantı çalışır. Sözleşmeye `slug` alanı eklenirse bu dosya sadeleşir.
 * BILINMEYENLER'e yazıldı.
 */

const TURKISH_MAP: Record<string, string> = {
  ç: 'c',
  Ç: 'c',
  ğ: 'g',
  Ğ: 'g',
  ı: 'i',
  I: 'i',
  İ: 'i',
  i: 'i',
  ö: 'o',
  Ö: 'o',
  ş: 's',
  Ş: 's',
  ü: 'u',
  Ü: 'u',
};

export function slugify(input: string): string {
  const mapped = Array.from(input)
    .map((char) => TURKISH_MAP[char] ?? char)
    .join('');

  return mapped
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

export function productSlug(item: Pick<MenuItem, 'id' | 'name'>): string {
  const base = slugify(item.name);
  return base.length > 0 ? `${base}-${item.id}` : String(item.id);
}

export function productPath(item: Pick<MenuItem, 'id' | 'name'>): string {
  return `/urun/${productSlug(item)}`;
}

/** Slug'ın sonundaki kimliği çıkarır. Bulunamazsa `null`. */
export function menuIdFromSlug(slug: string): number | null {
  const match = /(?:^|-)(\d+)$/.exec(slug);
  if (!match?.[1]) return null;
  const parsed = Number.parseInt(match[1], 10);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : null;
}
