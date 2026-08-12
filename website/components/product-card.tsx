import Link from 'next/link';
import { AddToCartForm } from '@/components/add-to-cart-form';
import { IconChevronRight } from '@/components/icons';
import { ProductImage } from '@/components/product-image';
import { formatPrice } from '@/lib/format';
import { productPath } from '@/lib/slug';
import type { MenuItem } from '@/lib/api/types';
import { cn } from '@/lib/utils';

type Props = {
  item: MenuItem;
  /** Vitrin sipariş alıyor mu (`is_open && ordering_enabled`). */
  orderingOpen: boolean;
  /** Görsel yükleme önceliği yalnızca ilk satır için. */
  priority?: boolean;
};

export function ProductCard({ item, orderingOpen, priority = false }: Props) {
  const href = productPath(item);
  const options = item.options ?? [];
  const hasOptions = options.length > 0;
  const allergens = item.allergens ?? [];
  const soldOut = !item.is_available;

  return (
    <article
      className={cn(
        'group relative flex flex-col overflow-hidden rounded-card border border-neutral-200 bg-neutral-0 shadow-xs transition-shadow duration-200',
        soldOut ? 'border-dashed' : 'hover:shadow-lg',
      )}
    >
      {/*
        Görsel bağlantısı ekran okuyucudan gizlenir: hemen altındaki başlık
        aynı hedefe gidiyor, iki kez okunması gezinmeyi yavaşlatır.
      */}
      <Link
        href={href}
        aria-hidden="true"
        tabIndex={-1}
        className="relative block aspect-4/3 overflow-hidden bg-neutral-100"
      >
        <ProductImage
          src={item.image_url}
          alt=""
          sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 340px"
          priority={priority}
          className={cn(
            'transition-transform duration-300 motion-safe:group-hover:scale-105',
            soldOut && 'grayscale',
          )}
        />
        {soldOut && (
          <span className="absolute inset-0 grid place-items-center bg-neutral-900/45">
            <span className="bld-badge bg-neutral-0 px-3 py-1.5 text-sm text-neutral-900">
              Tükendi
            </span>
          </span>
        )}
        {!soldOut && hasOptions && (
          <span className="absolute top-3 left-3 bld-badge bg-neutral-0/95 text-neutral-800 shadow-xs">
            Seçenekli
          </span>
        )}
      </Link>

      <div className="flex flex-1 flex-col gap-2 p-4">
        <h3 className="text-base leading-snug font-semibold text-neutral-900">
          <Link href={href} className="rounded-sm transition-colors hover:text-brand-700">
            {/* Kartın tamamını tıklanabilir yapan görünmez katman. */}
            <span className="absolute inset-0 z-0" aria-hidden="true" />
            <span className="relative">{item.name}</span>
          </Link>
        </h3>

        {item.description && (
          <p className="line-clamp-2 text-sm leading-relaxed text-neutral-600">
            {item.description}
          </p>
        )}

        {allergens.length > 0 && (
          <ul className="flex flex-wrap gap-1.5" aria-label="Alerjen uyarıları">
            {allergens.map((allergen) => (
              <li key={allergen} className="bld-badge bg-warning/15 text-neutral-800">
                <span className="sr-only">Alerjen: </span>
                {allergen}
              </li>
            ))}
          </ul>
        )}

        <p className="mt-auto flex items-baseline gap-1.5 pt-2">
          <span className="text-xl font-bold text-neutral-900">{formatPrice(item.price)}</span>
          {hasOptions && <span className="text-xs font-medium text-neutral-600">başlangıç</span>}
        </p>

        {/*
          Sepete ekleme düğmesi kart bağlantısının üstünde kalmalı; yoksa
          görünmez katman tıklamayı yutar.
        */}
        <div className="relative z-10">
          {hasOptions ? (
            <Link href={href} className="bld-btn-ghost w-full">
              Seçenekleri gör
              <IconChevronRight className="h-4 w-4" />
            </Link>
          ) : (
            <AddToCartForm
              menuId={item.id}
              disabled={soldOut || !orderingOpen}
              disabledReason={soldOut ? 'Tükendi' : 'Sipariş kapalı'}
              label="Sepete ekle"
              showMessage
            />
          )}
        </div>
      </div>
    </article>
  );
}
