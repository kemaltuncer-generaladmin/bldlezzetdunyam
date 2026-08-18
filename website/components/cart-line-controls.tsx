'use client';

import { useActionState, useEffect, useOptimistic, useRef } from 'react';
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
 *
 * ## ADET İYİMSER GÜNCELLENİYOR
 *
 * Sayaç eskiden sunucu turunu bekliyordu: müşteri artıya basıyor, sayı
 * saniyelerce eski değerde kalıyor, düğme de o süre boyunca kapalı oluyordu.
 * Ekranda hiçbir şey olmadığı için "site kasıyor" hissi buradan doğuyordu —
 * oysa istek gitmişti, sadece görünmüyordu.
 *
 * Artık sayı ANINDA değişiyor (`useOptimistic`) ve düğme AÇIK KALIYOR: adet
 * mutlak bir sayı olarak gönderiliyor (`quantity=<hedef>`), yani üst üste
 * basmak sırayla 3, 4, 5 gönderir ve son yanıt kazanır. Sunucu tavanı
 * aşarsa adedi kırpıyor; sepet yeniden çizildiğinde iyimser değer gerçek
 * değere geri düşüyor ve sebep zaten mesaj satırında yazıyor.
 *
 * KALDIRMA düğmesi bunun DIŞINDA: yıkıcı ve geri alınamaz, iyimser
 * gösterilmiyor ve istek uçarken kapalı kalıyor.
 */
export function CartLineControls({ lineKey, quantity, itemName }: Props) {
  const [updateState, updateAction, updating] = useActionState(
    updateQuantityAction,
    IDLE_CART_STATE,
  );
  const [removeState, removeAction, removing] = useActionState(removeLineAction, IDLE_CART_STATE);

  useAnnounce(updateState);
  useAnnounce(removeState);

  const [shownQuantity, showQuantity] = useOptimistic(quantity);

  /**
   * Form eylemi: önce ekrandaki sayıyı hedef değere taşı, sonra sunucuya
   * gönder. İkisi de aynı geçişin içinde olduğu için React iyimser değeri
   * eylem bitene kadar tutuyor.
   */
  const submitQuantity = (formData: FormData) => {
    const target = Number.parseInt(String(formData.get('quantity') ?? ''), 10);
    if (Number.isSafeInteger(target)) showQuantity(Math.max(0, target));
    updateAction(formData);
  };

  const busy = updating || removing;

  return (
    <div className="flex flex-wrap items-center gap-3">
      {/* Adet sayacı `pill`: marka kılavuzunda çip/avatar/adet sayacı tam yarıçap. */}
      {/*
        Düğme değerleri EKRANDAKİ sayıdan türüyor, sunucudan gelen sayıdan
        değil: peş peşe basan müşteri 3 → 4 → 5 gönderebilsin diye. İkisini
        ayırmasaydık ikinci tıklama da ilkiyle aynı hedefi yollardı.
      */}
      <form action={submitQuantity} className="flex items-center rounded-full border border-input">
        <input type="hidden" name="line_key" value={lineKey} />
        <button
          type="submit"
          name="quantity"
          value={shownQuantity - 1}
          disabled={removing}
          aria-label={`${itemName} adedini azalt`}
          className="grid size-11 cursor-pointer place-items-center rounded-full text-foreground transition-colors duration-(--duration-fast) hover:bg-muted disabled:cursor-not-allowed disabled:text-muted-foreground"
        >
          <Minus strokeWidth={1.75} aria-hidden="true" className="size-4" />
        </button>

        <span
          aria-live="polite"
          data-testid="cart-line-quantity"
          className="min-w-8 px-1 text-center text-label bld-money"
        >
          {shownQuantity}
        </span>

        <button
          type="submit"
          name="quantity"
          value={shownQuantity + 1}
          disabled={removing || shownQuantity >= 99}
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
