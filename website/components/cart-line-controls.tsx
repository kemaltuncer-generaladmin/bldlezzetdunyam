'use client';

import { useActionState, useEffect, useRef } from 'react';
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
 * Adet artır/azalt ve satır silme. Gönderim düğmelerinin `name`/`value`
 * çiftleri form verisine katıldığı için JavaScript kapalıyken de çalışır.
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
    <div className="flex items-center gap-3">
      <form action={updateAction} className="flex items-center rounded-lg border border-neutral-200">
        <input type="hidden" name="line_key" value={lineKey} />
        <button
          type="submit"
          name="quantity"
          value={quantity - 1}
          disabled={busy}
          aria-label={`${itemName} adedini azalt`}
          className="grid h-10 w-10 place-items-center rounded-l-lg text-lg font-semibold text-neutral-800 hover:bg-neutral-100 disabled:opacity-50"
        >
          −
        </button>
        <span
          aria-live="polite"
          className="min-w-10 px-2 text-center text-sm font-semibold text-neutral-900"
        >
          {quantity}
        </span>
        <button
          type="submit"
          name="quantity"
          value={quantity + 1}
          disabled={busy || quantity >= 99}
          aria-label={`${itemName} adedini artır`}
          className="grid h-10 w-10 place-items-center rounded-r-lg text-lg font-semibold text-neutral-800 hover:bg-neutral-100 disabled:opacity-50"
        >
          +
        </button>
      </form>

      <form action={removeAction}>
        <input type="hidden" name="line_key" value={lineKey} />
        <button
          type="submit"
          disabled={busy}
          className="rounded-md px-2 py-2 text-sm font-medium text-danger underline-offset-2 hover:underline disabled:opacity-50"
        >
          Kaldır
          <span className="sr-only"> — {itemName}</span>
        </button>
      </form>
    </div>
  );
}
