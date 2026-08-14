'use client';

import { useActionState, useEffect, useRef } from 'react';
import { Minus, Plus, Trash2 } from 'lucide-react';
import { removeLineAction, updateQuantityAction } from '@/app/actions/cart';
import { IDLE_CART_STATE, type CartActionState } from '@/lib/action-state';
import { announceCartChanged } from '@/lib/cart-events';

/** Sunucu eylemi bitince başlıktaki rozete haber ver. */
function useAnnounce(state: CartActionState) {
  const lastHandled = useRef(0);
  useEffect(() => {
    if (state.at === 0 || state.at === lastHandled.current) return;
    lastHandled.current = state.at;
    if (state.status === 'ok') announceCartChanged();
  }, [state]);
}

type Props = {
  lineKey: string;
  quantity: number;
  itemName: string;
};

/**
 * Adet artır/azalt ve satır silme.
 *
 * Gönderim düğmelerinin `name`/`value` çiftleri form verisine katıldığı için
 * JavaScript kapalıyken de çalışır — sepetin en temel iki eylemi bir paketin
 * yüklenmesini beklemiyor.
 *
 * Silme YERİNDE bir yıkıcı eylem: dolu kırmızı buton değil, `danger` metinli
 * sessiz bir düğme. Listede dolu kırmızı bir buton primary'den daha çok göze
 * batıyor ve yanlışlıkla tıklanıyor (marka kılavuzu).
 */
export function CartLineControls({ lineKey, quantity, itemName }: Props) {
  const [updateState, updateAction, updating] = useActionState(
    updateQuantityAction,
    IDLE_CART_STATE,
  );
  const [removeState, removeAction, removing] = useActionState(removeLineAction, IDLE_CART_STATE);

  useAnnounce(updateState);
  useAnnounce(removeState);

  const busy = updating || removing;

  return (
    <div className="flex flex-wrap items-center gap-3">
      {/* Adet sayacı `pill`: marka kılavuzunda çip/avatar/adet sayacı tam yarıçap. */}
      <form action={updateAction} className="flex items-center rounded-full border border-input">
        <input type="hidden" name="line_key" value={lineKey} />
        <button
          type="submit"
          name="quantity"
          value={quantity - 1}
          disabled={busy}
          aria-label={`${itemName} adedini azalt`}
          className="grid size-11 cursor-pointer place-items-center rounded-full text-foreground transition-colors duration-(--duration-fast) hover:bg-muted disabled:cursor-not-allowed disabled:text-muted-foreground"
        >
          <Minus strokeWidth={1.75} aria-hidden="true" className="size-4" />
        </button>

        <span aria-live="polite" className="min-w-8 px-1 text-center text-label bld-money">
          {quantity}
        </span>

        <button
          type="submit"
          name="quantity"
          value={quantity + 1}
          disabled={busy || quantity >= 99}
          aria-label={`${itemName} adedini artır`}
          className="grid size-11 cursor-pointer place-items-center rounded-full text-foreground transition-colors duration-(--duration-fast) hover:bg-muted disabled:cursor-not-allowed disabled:text-muted-foreground"
        >
          <Plus strokeWidth={1.75} aria-hidden="true" className="size-4" />
        </button>
      </form>

      <form action={removeAction}>
        <input type="hidden" name="line_key" value={lineKey} />
        <button
          type="submit"
          disabled={busy}
          className="inline-flex min-h-11 cursor-pointer items-center gap-1.5 rounded-sm px-2 text-label text-danger-foreground transition-colors duration-(--duration-fast) hover:bg-danger-surface disabled:cursor-not-allowed disabled:text-muted-foreground"
        >
          <Trash2 strokeWidth={1.75} aria-hidden="true" className="size-4" />
          Kaldır
          <span className="sr-only"> — {itemName}</span>
        </button>
      </form>
    </div>
  );
}
