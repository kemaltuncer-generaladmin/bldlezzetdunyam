'use client';

import { useActionState, useEffect, useRef } from 'react';
import { Minus, Plus, Trash2 } from 'lucide-react';
import { removeLineAction, updateQuantityAction } from '@/app/actions/cart';
import type { DayCartState } from '@/app/actions/cart-state';
import { IDLE_CART_STATE } from '@/lib/action-state';
import { announceCartChanged } from '@/lib/cart-events';

/** Sunucu eylemi bitince başlıktaki rozete haber ver. */
function useAnnounce(state: DayCartState) {
  const lastHandled = useRef(0);
  useEffect(() => {
    if (state.at === 0 || state.at === lastHandled.current) return;
    lastHandled.current = state.at;
    // Tavana takılan güncelleme de sepeti değiştiriyor (adet kırpılıyor);
    // rozet o hâlde de yenilenmeli.
    if (state.status === 'ok' || state.status === 'limit') announceCartChanged();
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

      {/*
        TAVANA TAKILAN ARTIRMA SÖYLENMEK ZORUNDA. Adet sunucuda kırpılıyor ve
        sayaç eski değerine dönüyor; sebebi yazılmazsa müşteri "artı düğmesi
        çalışmıyor" der ve tekrar tekrar basar. Hata da aynı yerden okunuyor:
        sessizce başarısız olan bir sepet düğmesi en kötü hâl.
      */}
      {(updateState.status === 'limit' || updateState.status === 'error') && (
        <p
          role="status"
          className="basis-full text-body-sm text-warning-foreground"
          aria-live="polite"
        >
          {updateState.message}
        </p>
      )}
    </div>
  );
}
