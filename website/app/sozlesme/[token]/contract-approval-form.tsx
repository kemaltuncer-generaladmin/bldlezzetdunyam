'use client';

import { useActionState, useEffect, useRef, useState, useTransition } from 'react';
import { CheckCircle2 } from 'lucide-react';
import { approveContractAction, requestContractOtpAction } from '@/app/actions/contract';
import { FormField, inputClass } from '@/components/form-field';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { IDLE_CONTRACT_STATE } from './contract-state';

/**
 * Sözleşme onayı — iki aşama, tek bileşen (M2).
 *
 * 1. "Onay kodu gönder" → sözleşmedeki **kayıtlı** numaraya SMS gider.
 * 2. Altı hane + (isteğe bağlı) ad soyad → sözleşme onaylanır.
 *
 * NUMARA SORULMUYOR ve sorulmamalı: kod, sözleşmenin kayıtlı numarasına
 * gidiyor. İstemciden alınsaydı, bağlantıyı eline geçiren biri kodu kendi
 * telefonuna ısmarlayıp sözleşmeyi onaylayabilirdi — imzalı bağlantı tek
 * başına kimlik değildir, ikinci etken tam olarak budur.
 *
 * İKİ AYRI `useActionState`, `phone-login-form.tsx`'teki kararla aynı
 * gerekçeyle: iki eylemin dönüş şekli aynı ama hangisinin en son koştuğunu
 * bilmemiz gerekiyor. Tek durumda birleştirilseydi "kod gönderildi" ile "kod
 * yanlış" aynı nesneye yazılır ve hangisinin güncel olduğu kaybolurdu.
 */
export function ContractApprovalForm({
  token,
  maskedPhone,
}: {
  token: string;
  maskedPhone: string | null;
}) {
  const [requestState, requestFormAction] = useActionState(
    requestContractOtpAction,
    IDLE_CONTRACT_STATE,
  );
  const [approveState, approveFormAction] = useActionState(
    approveContractAction,
    IDLE_CONTRACT_STATE,
  );
  const [lastAction, setLastAction] = useState<'request' | 'approve'>('request');
  const [pending, startTransition] = useTransition();

  const state = lastAction === 'approve' ? approveState : requestState;
  const codeInput = useRef<HTMLInputElement>(null);

  /*
   * Kod bir kez istendiyse kutu AÇIK KALIR. Yalnız son eylemin durumuna
   * bakılsaydı, kod yanlış girildiğinde ekran birinci aşamaya döner ve
   * kullanıcı elindeki SMS'i girecek yeri kaybederdi.
   */
  const codeRequested = requestState.status === 'sent' || approveState.at > 0;
  const approved = approveState.status === 'approved';

  useEffect(() => {
    if (codeRequested && !approved) codeInput.current?.focus();
  }, [codeRequested, approved]);

  const submitRequest = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    setLastAction('request');
    startTransition(() => requestFormAction(formData));
  };

  const submitApprove = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    setLastAction('approve');
    startTransition(() => approveFormAction(formData));
  };

  const resend = () => {
    const formData = new FormData();
    formData.set('token', token);
    setLastAction('request');
    startTransition(() => requestFormAction(formData));
  };

  if (approved) {
    return (
      <div
        role="status"
        className="rounded-xl border border-success/30 bg-success/10 p-5 sm:p-6"
        data-testid="sozlesme-onaylandi"
      >
        <div className="flex items-start gap-3">
          <CheckCircle2 className="mt-0.5 size-6 text-success" aria-hidden />
          <div>
            <h2 className="text-lg font-semibold">Sözleşme onaylandı</h2>
            <p className="mt-1 text-sm text-muted-foreground">
              Onayınızı aldık. Aboneliğiniz için ödeme adımına geçiliyor; ödeme bağlantısı SMS ile
              size ulaşacak. Bu sayfayı kapatabilirsiniz.
            </p>
          </div>
        </div>
      </div>
    );
  }

  const alert = state.status === 'error' && state.message && (
    <p role="alert" className="rounded-md bg-danger/10 px-3 py-2 text-sm text-danger">
      {state.message}
    </p>
  );

  if (!codeRequested) {
    return (
      <form onSubmit={submitRequest} noValidate className="space-y-4">
        {alert}

        <input type="hidden" name="token" value={token} />

        <p className="text-sm text-muted-foreground">
          {maskedPhone
            ? `Onay kodunu ${maskedPhone} numarasına göndereceğiz.`
            : 'Onay kodunu sözleşmede kayıtlı cep telefonunuza göndereceğiz.'}{' '}
          Kod, sözleşmede kayıtlı numaraya gider; başka bir numara giremezsiniz.
        </p>

        <Button
          type="submit"
          size="lg"
          className="w-full sm:w-auto"
          disabled={pending}
          disabledReason="Kod gönderiliyor, işlem sürüyor."
        >
          {pending ? 'Gönderiliyor…' : 'Onay kodu gönder'}
        </Button>
      </form>
    );
  }

  return (
    <form onSubmit={submitApprove} noValidate className="space-y-4">
      {alert}

      <input type="hidden" name="token" value={token} />

      <p className="text-sm text-muted-foreground">
        {maskedPhone ? (
          <>
            <span className="font-medium text-foreground">{maskedPhone}</span> numarasına gönderilen
            6 haneli kodu girin.
          </>
        ) : (
          'Telefonunuza gönderilen 6 haneli kodu girin.'
        )}
      </p>

      <FormField id="sozlesme-kod" label="Onay kodu" error={state.fieldErrors.code}>
        {({ id, describedBy, invalid }) => (
          <input
            ref={codeInput}
            id={id}
            name="code"
            type="text"
            inputMode="numeric"
            /*
             * `one-time-code`: iOS ve Android klavyesi SMS'teki kodu üstte
             * öneri olarak gösteriyor, kullanıcı tek dokunuşla dolduruyor.
             */
            autoComplete="one-time-code"
            maxLength={6}
            aria-invalid={invalid}
            aria-describedby={describedBy}
            className={cn(
              inputClass(invalid),
              'text-center text-2xl tracking-[0.4em] tabular-nums',
            )}
            placeholder="––––––"
          />
        )}
      </FormField>

      <FormField
        id="sozlesme-ad"
        label="Onaylayan (isteğe bağlı)"
        hint="Sözleşmeye onayı kimin verdiğini yazmak için. Zorunlu değil."
        error={state.fieldErrors.full_name}
      >
        {({ id, describedBy, invalid }) => (
          <input
            id={id}
            name="full_name"
            type="text"
            autoComplete="name"
            maxLength={120}
            aria-invalid={invalid}
            aria-describedby={describedBy}
            className={inputClass(invalid)}
            placeholder="Ad Soyad"
          />
        )}
      </FormField>

      {/*
       * Onayın geri alınamaz olduğu DÜĞMEDEN ÖNCE yazılıyor. Onay sonrası
       * söylenseydi kullanıcı bunu ancak iş bittikten sonra öğrenirdi.
       */}
      <p className="text-sm text-muted-foreground">
        Onaylamak, sözleşmeyi kabul ettiğiniz anlamına gelir ve <strong>geri alınamaz</strong>.
        Vazgeçmek isterseniz aboneliğinizi iptal edebilirsiniz.
      </p>

      <Button
        type="submit"
        size="lg"
        className="w-full sm:w-auto"
        disabled={pending}
        disabledReason="Onay işleniyor, işlem sürüyor."
      >
        {pending ? 'Onaylanıyor…' : 'Sözleşmeyi onayla'}
      </Button>

      <ResendButton resendAt={state.resendAt} disabled={pending} onResend={resend} />
    </form>
  );
}

/**
 * "Kodu yeniden gönder" düğmesi ve geri sayımı.
 *
 * Sayaç MUTLAK ZAMAN DAMGASINDAN hesaplanıyor, saniye saniye azalan bir
 * sayaçtan değil: kullanıcı SMS'i okumak için sekmeyi arka plana aldığında
 * tarayıcı zamanlayıcıyı kısıyor ve azalan sayaç donuyor.
 */
function ResendButton({
  resendAt,
  disabled,
  onResend,
}: {
  resendAt: number;
  disabled: boolean;
  onResend: () => void;
}) {
  const [remaining, setRemaining] = useState(() => secondsUntil(resendAt));

  useEffect(() => {
    setRemaining(secondsUntil(resendAt));
    if (resendAt <= Date.now()) return;

    const id = window.setInterval(() => {
      const left = secondsUntil(resendAt);
      setRemaining(left);
      if (left <= 0) window.clearInterval(id);
    }, 1000);

    return () => window.clearInterval(id);
  }, [resendAt]);

  if (remaining > 0) {
    return (
      <p className="text-sm text-muted-foreground tabular-nums">
        Kod gelmediyse {remaining} saniye sonra yeniden isteyebilirsiniz.
      </p>
    );
  }

  return (
    <button
      type="button"
      onClick={onResend}
      disabled={disabled}
      className="text-sm font-medium text-primary underline underline-offset-4 disabled:opacity-50"
    >
      Kodu yeniden gönder
    </button>
  );
}

function secondsUntil(timestamp: number): number {
  return Math.max(0, Math.ceil((timestamp - Date.now()) / 1000));
}
