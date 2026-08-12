'use client';

import { useActionState, useState, useTransition } from 'react';
import { startAccountPaymentAction } from '@/app/actions/account';
import { IDLE_ACCOUNT_PAYMENT_STATE } from '@/lib/action-state';
import { Button } from '@/components/ui/button';
import { formatPrice } from '@/lib/format';
import { cn } from '@/lib/utils';

/**
 * Cari borç ödeme formu — W-12.
 *
 * İKİ MOD, TEK FORM: "borcun tamamı" ve "istenen tutar". İstek de birebir
 * buydu — cari hesapta istenen ya da toplam tutara göre ödeme.
 *
 * TAMAMI VARSAYILAN: müşterilerin çoğu hesabı kapatmak için geliyor ve
 * tutarı elle yazmak hem fazladan iş hem de yanlış yazma riski. Kısmi
 * ödeme bilinçli bir seçim olduğu için bir tık uzakta.
 *
 * `full` modunda tutar SUNUCUDA yeniden hesaplanıyor; buradaki rakam
 * yalnızca gösterim. Aradan bir sipariş geçmişse ekrandaki eski bakiye
 * değil, gerçek borç tahsil edilir.
 */
export function AccountPaymentForm({ balance }: { balance: number }) {
  const [state, formAction] = useActionState(startAccountPaymentAction, IDLE_ACCOUNT_PAYMENT_STATE);
  const [pending, startTransition] = useTransition();
  const [mode, setMode] = useState<'full' | 'partial'>('full');

  if (balance <= 0) {
    return <p className="text-sm text-muted-foreground">Ödenecek borcunuz bulunmuyor.</p>;
  }

  const submit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    formData.set('mode', mode);
    startTransition(() => formAction(formData));
  };

  return (
    <form onSubmit={submit} className="space-y-4">
      {state.status === 'error' && state.message && (
        <p role="alert" className="rounded-md bg-danger/10 px-3 py-2 text-sm text-danger">
          {state.message}
        </p>
      )}

      <div className="grid gap-2 sm:grid-cols-2">
        <ModeCard
          active={mode === 'full'}
          onClick={() => setMode('full')}
          title="Borcun tamamı"
          detail={formatPrice(balance)}
        />
        <ModeCard
          active={mode === 'partial'}
          onClick={() => setMode('partial')}
          title="İstediğim tutar"
          detail="Kısmi ödeme"
        />
      </div>

      {mode === 'partial' && (
        <div>
          <label htmlFor="odeme-tutar" className="mb-1 block text-sm font-medium">
            Ödenecek tutar (TL)
          </label>
          <input
            id="odeme-tutar"
            name="amount"
            type="text"
            inputMode="decimal"
            autoComplete="off"
            placeholder="0,00"
            className="h-11 w-full rounded-md border bg-background px-3 tabular-nums"
          />
          <p className="mt-1 text-xs text-muted-foreground">
            Borcunuzdan ({formatPrice(balance)}) büyük bir tutar girilemez.
          </p>
        </div>
      )}

      <Button type="submit" size="lg" className="w-full sm:w-auto" disabled={pending}>
        {pending ? 'Ödeme sayfası açılıyor…' : 'Ödemeye geç'}
      </Button>
    </form>
  );
}

function ModeCard({
  active,
  onClick,
  title,
  detail,
}: {
  active: boolean;
  onClick: () => void;
  title: string;
  detail: string;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={active}
      className={cn(
        'rounded-lg border p-4 text-left transition-colors',
        active ? 'border-primary bg-brand-50 ring-1 ring-primary' : 'hover:bg-muted',
      )}
    >
      <span className="block text-sm font-medium">{title}</span>
      <span className="mt-0.5 block text-sm text-muted-foreground tabular-nums">{detail}</span>
    </button>
  );
}
