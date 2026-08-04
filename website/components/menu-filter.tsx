'use client';

import { useState } from 'react';
import { cn } from '@/lib/cn';

export type MenuSection = {
  id: number;
  name: string;
  count: number;
  /** Sunucuda render edilmiş kategori bloğu. */
  content: React.ReactNode;
};

/**
 * Kategori filtresi. Bölümler DOM'da **kalır**, yalnızca `hidden` ile gizlenir
 * — böylece ilk SSR çıktısı tüm ürünleri içerir (SEO) ve JavaScript kapalıyken
 * de bütün menü görünür.
 */
export function MenuFilter({ sections }: { sections: MenuSection[] }) {
  const [selected, setSelected] = useState<number | null>(null);

  return (
    <>
      <div
        role="group"
        aria-label="Kategori filtresi"
        className="-mx-4 flex gap-2 overflow-x-auto px-4 pb-2"
      >
        <FilterChip active={selected === null} onSelect={() => setSelected(null)}>
          Tümü
        </FilterChip>
        {sections.map((section) => (
          <FilterChip
            key={section.id}
            active={selected === section.id}
            onSelect={() => setSelected(section.id)}
          >
            {section.name}
            <span className="ml-1 text-xs opacity-75">({section.count})</span>
          </FilterChip>
        ))}
      </div>

      <div className="mt-8 space-y-12">
        {sections.map((section) => (
          <div key={section.id} hidden={selected !== null && selected !== section.id}>
            {section.content}
          </div>
        ))}
      </div>
    </>
  );
}

function FilterChip({
  active,
  onSelect,
  children,
}: {
  active: boolean;
  onSelect: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onSelect}
      aria-pressed={active}
      className={cn(
        'shrink-0 rounded-full border px-4 py-2 text-sm font-medium transition-colors',
        active
          ? 'border-brand-600 bg-brand-600 text-neutral-0'
          : 'border-neutral-200 bg-neutral-0 text-neutral-800 hover:bg-neutral-100',
      )}
    >
      {children}
    </button>
  );
}
