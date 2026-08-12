'use client';

import { useActionState, useEffect, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { addToCartAction } from '@/app/actions/cart';
import { IDLE_CART_STATE } from '@/lib/action-state';
import { announceCartChanged } from '@/lib/cart-events';
import { cn } from '@/lib/utils';

type Props = {
  menuId: number;
  /** Sipariş alımı kapalıysa veya ürün tükendiyse buton pasiftir. */
  disabled: boolean;
  disabledReason?: string;
  label?: string;
  className?: string;
  /** Ürün detayındaki seçenek alanları ve adet girişi. */
  children?: React.ReactNode;
  /** Durum mesajını formun altında göster (detay sayfası). */
  showMessage?: boolean;
};

export function AddToCartForm({
  menuId,
  disabled,
  disabledReason,
  label = 'Sepete ekle',
  className,
  children,
  showMessage = false,
}: Props) {
  const router = useRouter();
  const [state, formAction, pending] = useActionState(addToCartAction, IDLE_CART_STATE);
  const lastHandled = useRef(0);

  useEffect(() => {
    if (state.at === 0 || state.at === lastHandled.current) return;
    lastHandled.current = state.at;
    if (state.status === 'ok') {
      announceCartChanged();
      router.refresh();
    }
  }, [state, router]);

  return (
    <form action={formAction} className={cn('space-y-3', className)}>
      <input type="hidden" name="menu_id" value={menuId} />
      {children}

      <button
        type="submit"
        disabled={disabled || pending}
        aria-disabled={disabled || pending}
        className="bld-btn-primary w-full"
      >
        {pending ? 'Ekleniyor…' : disabled ? (disabledReason ?? 'Eklenemez') : label}
      </button>

      <p aria-live="polite" className="sr-only">
        {state.message ?? ''}
      </p>

      {showMessage && state.message && (
        <p
          className={cn(
            'rounded-md px-3 py-2 text-sm',
            state.status === 'error' ? 'bg-danger/10 text-danger' : 'bg-success/10 text-[#14532D]',
          )}
        >
          {state.message}
        </p>
      )}
    </form>
  );
}
