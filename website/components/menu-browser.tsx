'use client';

import { useId, useMemo, useState } from 'react';
import { IconClose, IconSearch, IconSliders } from '@/components/icons';
import { ProductCard } from '@/components/product-card';
import { formatPrice } from '@/lib/format';
import { slugify } from '@/lib/slug';
import type { MenuCategory, MenuItem } from '@/lib/api/types';

type SortKey = 'category' | 'price-asc' | 'price-desc' | 'name-asc';

const SORT_OPTIONS: ReadonlyArray<{ value: SortKey; label: string }> = [
  { value: 'category', label: 'Menü sırası' },
  { value: 'price-asc', label: 'Fiyat: önce ucuz' },
  { value: 'price-desc', label: 'Fiyat: önce pahalı' },
  { value: 'name-asc', label: 'İsme göre (A–Z)' },
];

type Props = {
  categories: MenuCategory[];
  /** Vitrin sipariş alıyor mu — kartlardaki düğmeye geçirilir. */
  orderingOpen: boolean;
};

/**
 * Menü gezinme yüzeyi: arama, kategori çubuğu, fiyat/stok süzgeci ve sıralama.
 *
 * NEDEN İSTEMCİ BİLEŞENİ AMA VERİ SUNUCUDAN: sözleşmede arama ucu yok
 * (`docs/openapi.yaml`), bu yüzden süzme tarayıcıda yapılır. Buna karşılık
 * bileşen sunucuda da render edilir; ilk HTML **bütün** ürünleri süzgeçsiz
 * içerir, böylece SEO ve JavaScript kapalı kullanım bozulmaz.
 *
 * `is_available: false` ürünler varsayılan görünümde **kalır** (`docs/03` §3);
 * gizlemek kullanıcının açık tercihidir.
 */
export function MenuBrowser({ categories, orderingOpen }: Props) {
  const fieldId = useId();
  const [query, setQuery] = useState('');
  const [categoryId, setCategoryId] = useState<number | null>(null);
  const [sort, setSort] = useState<SortKey>('category');
  const [availableOnly, setAvailableOnly] = useState(false);
  const [filtersOpen, setFiltersOpen] = useState(false);

  const bounds = usePriceBounds(categories);
  const [maxPrice, setMaxPrice] = useState<number | null>(null);
  const priceCeiling = maxPrice ?? bounds.max;

  const normalizedQuery = slugify(query);
  const filtered = useMemo(
    () =>
      categories
        .map((category) => ({
          category,
          items: sortItems(
            (category.items ?? []).filter(
              (item) =>
                (categoryId === null || category.id === categoryId) &&
                (!availableOnly || item.is_available) &&
                item.price <= priceCeiling &&
                matchesQuery(item, category, normalizedQuery),
            ),
            sort,
          ),
        }))
        .filter((group) => group.items.length > 0),
    [categories, categoryId, availableOnly, priceCeiling, normalizedQuery, sort],
  );

  const matchCount = filtered.reduce((total, group) => total + group.items.length, 0);
  const totalCount = categories.reduce((total, c) => total + (c.items ?? []).length, 0);
  const filtersActive =
    query.trim().length > 0 || categoryId !== null || availableOnly || maxPrice !== null;

  function resetFilters(): void {
    setQuery('');
    setCategoryId(null);
    setAvailableOnly(false);
    setMaxPrice(null);
    setSort('category');
  }

  return (
    <div>
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
        <div className="relative flex-1">
          <label htmlFor={`${fieldId}-search`} className="sr-only">
            Menüde ara
          </label>
          <IconSearch className="pointer-events-none absolute top-1/2 left-3 h-5 w-5 -translate-y-1/2 text-neutral-400" />
          <input
            id={`${fieldId}-search`}
            type="search"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Yemek veya kategori arayın"
            autoComplete="off"
            className="h-12 bld-field pr-10 pl-10 text-base"
          />
          {query.length > 0 && (
            <button
              type="button"
              onClick={() => setQuery('')}
              className="absolute top-1/2 right-2 grid h-8 w-8 -translate-y-1/2 place-items-center rounded-full text-neutral-600 hover:bg-neutral-100"
            >
              <IconClose className="h-4 w-4" />
              <span className="sr-only">Aramayı temizle</span>
            </button>
          )}
        </div>

        <div className="flex gap-2">
          <div className="flex-1 sm:flex-none">
            <label htmlFor={`${fieldId}-sort`} className="sr-only">
              Sıralama
            </label>
            <select
              id={`${fieldId}-sort`}
              value={sort}
              onChange={(event) => setSort(event.target.value as SortKey)}
              className="h-12 bld-field py-0 pr-8 text-sm font-medium sm:w-52"
            >
              {SORT_OPTIONS.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          </div>

          <button
            type="button"
            onClick={() => setFiltersOpen((open) => !open)}
            aria-expanded={filtersOpen}
            aria-controls={`${fieldId}-filters`}
            className="bld-btn-secondary h-12 shrink-0"
          >
            <IconSliders className="h-5 w-5" />
            Filtreler
          </button>
        </div>
      </div>

      <div
        id={`${fieldId}-filters`}
        hidden={!filtersOpen}
        className="mt-3 grid gap-5 bld-card p-4 sm:grid-cols-2"
      >
        <div>
          <label htmlFor={`${fieldId}-price`} className="block text-sm font-semibold">
            Fiyat üst sınırı
          </label>
          <input
            id={`${fieldId}-price`}
            type="range"
            min={bounds.min}
            max={bounds.max}
            step={bounds.step}
            value={priceCeiling}
            disabled={bounds.min === bounds.max}
            onChange={(event) => setMaxPrice(Number(event.target.value))}
            className="mt-3 w-full accent-brand-600"
            aria-describedby={`${fieldId}-price-value`}
          />
          <p id={`${fieldId}-price-value`} className="mt-1 text-sm text-neutral-600">
            {formatPrice(bounds.min)} — {formatPrice(priceCeiling)} arası ürünler
          </p>
        </div>

        <div className="flex flex-col justify-between gap-3">
          <label className="flex items-start gap-3 text-sm">
            <input
              type="checkbox"
              checked={availableOnly}
              onChange={(event) => setAvailableOnly(event.target.checked)}
              className="mt-0.5 h-5 w-5 shrink-0 rounded-sm border-neutral-400 accent-brand-600"
            />
            <span>
              <span className="font-semibold">Yalnızca satışta olanlar</span>
              <span className="mt-0.5 block text-neutral-600">
                Tükenen ürünler varsayılan olarak menüde soluk görünür.
              </span>
            </span>
          </label>

          <button
            type="button"
            onClick={resetFilters}
            disabled={!filtersActive}
            className="bld-btn-secondary self-start disabled:cursor-not-allowed disabled:text-neutral-400"
          >
            Filtreleri temizle
          </button>
        </div>
      </div>

      {/*
        Kategori çubuğu yapışkan: uzun menüde kullanıcı kategori değiştirmek
        için başa dönmek zorunda kalmasın. `top` değeri site başlığının 4rem
        yüksekliğiyle hizalıdır.
      */}
      <div className="sticky top-16 z-30 -mx-4 mt-4 border-b border-neutral-200 bg-neutral-50/95 px-4 py-2 backdrop-blur-sm lg:mx-0 lg:px-0">
        <div role="group" aria-label="Kategori süzgeci" className="bld-rail">
          <CategoryChip
            active={categoryId === null}
            count={totalCount}
            label="Tümü"
            onSelect={() => setCategoryId(null)}
          />
          {categories.map((category) => (
            <CategoryChip
              key={category.id}
              active={categoryId === category.id}
              count={(category.items ?? []).length}
              label={category.name}
              onSelect={() => setCategoryId(category.id)}
            />
          ))}
        </div>
      </div>

      <p role="status" aria-live="polite" className="mt-4 text-sm text-neutral-600">
        {filtersActive
          ? `${totalCount} üründen ${matchCount} tanesi eşleşti.`
          : `Menüde ${totalCount} ürün var.`}
      </p>

      {matchCount === 0 ? (
        <div className="mx-auto mt-8 max-w-lg bld-card px-5 py-10 text-center">
          <p className="text-lg font-semibold">Aramanıza uyan ürün yok</p>
          <p className="mt-2 text-sm text-neutral-600">
            Farklı bir kelime deneyin ya da süzgeçleri kaldırıp menünün tamamına bakın.
          </p>
          <button type="button" onClick={resetFilters} className="mt-5 bld-btn-primary">
            Filtreleri temizle
          </button>
        </div>
      ) : (
        <div className="mt-6 space-y-10">
          {filtered.map((group, groupIndex) => (
            <section
              key={group.category.id}
              id={`kategori-${group.category.id}`}
              aria-labelledby={`kategori-${group.category.id}-baslik`}
              className="bld-anchor"
            >
              <div className="flex items-baseline gap-3">
                <h2
                  id={`kategori-${group.category.id}-baslik`}
                  className="text-xl font-bold sm:text-2xl"
                >
                  {group.category.name}
                </h2>
                <span className="text-sm text-neutral-600">{group.items.length} ürün</span>
              </div>

              <div className="mt-4 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
                {group.items.map((item, index) => (
                  <ProductCard
                    key={item.id}
                    item={item}
                    orderingOpen={orderingOpen}
                    priority={groupIndex === 0 && index < 3}
                  />
                ))}
              </div>
            </section>
          ))}
        </div>
      )}
    </div>
  );
}

function CategoryChip({
  active,
  count,
  label,
  onSelect,
}: {
  active: boolean;
  count: number;
  label: string;
  onSelect: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onSelect}
      aria-pressed={active}
      className={active ? 'bld-chip-active' : 'bld-chip-idle'}
    >
      {label}
      <span className={active ? 'text-brand-100' : 'text-neutral-600'}>({count})</span>
    </button>
  );
}

/** Fiyat süzgecinin sınırları — menüdeki en ucuz ve en pahalı ürün. */
function usePriceBounds(categories: MenuCategory[]): { min: number; max: number; step: number } {
  return useMemo(() => {
    const prices = categories.flatMap((category) => (category.items ?? []).map((i) => i.price));
    if (prices.length === 0) return { min: 0, max: 0, step: 100 };
    const min = Math.min(...prices);
    const max = Math.max(...prices);
    // Kuruş tamsayısı: 5 TL'lik adım, dar aralıkta 1 TL'ye iner.
    const step = max - min > 5000 ? 500 : 100;
    return { min, max, step };
  }, [categories]);
}

/**
 * Türkçe duyarsız arama. `slugify` zaten ç/ğ/ı/ö/ş/ü eşlemesini yapıyor
 * (`lib/slug.ts`), iki tarafı da aynı biçime indirip alt dize arıyoruz.
 */
function matchesQuery(item: MenuItem, category: MenuCategory, normalizedQuery: string): boolean {
  if (normalizedQuery.length === 0) return true;
  const haystack = slugify(`${item.name} ${item.description ?? ''} ${category.name}`);
  return haystack.includes(normalizedQuery);
}

function sortItems(items: MenuItem[], sort: SortKey): MenuItem[] {
  if (sort === 'category') return items;
  const copy = [...items];
  if (sort === 'price-asc') return copy.sort((a, b) => a.price - b.price);
  if (sort === 'price-desc') return copy.sort((a, b) => b.price - a.price);
  return copy.sort((a, b) => a.name.localeCompare(b.name, 'tr'));
}
