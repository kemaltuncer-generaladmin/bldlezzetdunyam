import Image from 'next/image';
import Link from 'next/link';
import { AddToCartForm } from '@/components/add-to-cart-form';
import { formatPrice } from '@/lib/format';
import { productPath } from '@/lib/slug';
import type { MenuItem } from '@/lib/api/types';
import { cn } from '@/lib/cn';

type Props = {
  item: MenuItem;
  /** Vitrin sipariş alıyor mu (`is_open && ordering_enabled`). */
  orderingOpen: boolean;
  /** Görsel yükleme önceliği yalnızca ilk satır için. */
  priority?: boolean;
};

export function ProductCard({ item, orderingOpen, priority = false }: Props) {
  const href = productPath(item);
  const hasOptions = (item.options ?? []).length > 0;
  const soldOut = !item.is_available;

  return (
    <article
      className={cn(
        'bld-card flex flex-col overflow-hidden transition-shadow hover:shadow-md',
        soldOut && 'opacity-60',
      )}
    >
      <Link href={href} className="relative block aspect-[3/2] bg-neutral-100" tabIndex={-1}>
        {item.image_url ? (
          <Image
            src={item.image_url}
            alt=""
            fill
            sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 320px"
            className="object-cover"
            priority={priority}
          />
        ) : (
          <span
            aria-hidden="true"
            className="grid h-full w-full place-items-center text-3xl text-neutral-400"
          >
            🍽️
          </span>
        )}
        {soldOut && (
          <span className="absolute left-3 top-3 rounded-full bg-neutral-900/85 px-3 py-1 text-xs font-semibold text-neutral-0">
            Tükendi
          </span>
        )}
      </Link>

      <div className="flex flex-1 flex-col gap-2 p-4">
        <h3 className="text-base font-semibold leading-snug text-neutral-900">
          <Link href={href} className="rounded hover:text-brand-700">
            {item.name}
          </Link>
        </h3>

        {item.description && (
          <p className="line-clamp-2 text-sm text-neutral-600">{item.description}</p>
        )}

        {(item.allergens ?? []).length > 0 && (
          <p className="text-xs text-neutral-600">
            <span className="font-medium">Alerjen:</span> {(item.allergens ?? []).join(', ')}
          </p>
        )}

        <p className="mt-auto pt-2 text-lg font-bold text-neutral-900">
          {formatPrice(item.price)}
          {hasOptions && (
            <span className="ml-1 text-xs font-normal text-neutral-600">başlangıç</span>
          )}
        </p>

        {hasOptions ? (
          <Link
            href={href}
            className="block rounded-lg border border-brand-600 px-4 py-3 text-center text-sm font-semibold text-brand-700 hover:bg-brand-50"
          >
            Seçenekleri gör
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
    </article>
  );
}
