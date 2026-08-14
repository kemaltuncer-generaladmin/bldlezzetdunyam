'use client';

import { useActionState, useEffect, useRef, useState, useTransition } from 'react';
import { requestOtpAction, verifyOtpAction } from '@/app/actions/auth';
import { IDLE_OTP_STATE } from '@/lib/action-state';
import { FormField, inputClass } from '@/components/form-field';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

/**
 * Telefonla giriş — W-11.
 *
 * İKİ AŞAMA, TEK BİLEŞEN, TEK DURUM. Ayrı bir `/giris/kod` sayfası
 * kullanılsaydı, "numarayı yanlış yazdım" diyen kullanıcı geri tuşuyla
 * dönüp formu boş bulurdu.
 *
 * İKİ AYRI `useActionState` var ve bu bilinçli: iki eylemin dönüş şekli aynı
 * (`OtpFormState`) ama hangisinin en son koştuğunu bilmemiz gerekiyor. Tek
 * durumda birleştirilseydi, "kod gönderildi" ile "kod yanlış" aynı nesneye
 * yazılır ve hangisinin güncel olduğu kaybolurdu. `activeState`, en son
 * hangi eylemin çalıştığını takip eden `lastAction` ile seçiliyor.
 */
export function PhoneLoginForm({ next }: { next: string }) {
  const [requestState, requestFormAction] = useActionState(requestOtpAction, IDLE_OTP_STATE);
  const [verifyState, verifyFormAction] = useActionState(verifyOtpAction, IDLE_OTP_STATE);
  const [lastAction, setLastAction] = useState<'request' | 'verify'>('request');
  const [pending, startTransition] = useTransition();

  const state = lastAction === 'verify' ? verifyState : requestState;
  const codeInput = useRef<HTMLInputElement>(null);

  /*
   * Kod ekranına geçince odak koda gider. Bunu yapmazsak kullanıcı SMS'ten
   * dönüp ekrana bakıyor ve yazacağı yeri arıyor; mobilde klavye de
   * açılmıyor.
   */
  useEffect(() => {
    if (state.phase === 'code') codeInput.current?.focus();
  }, [state.phase]);

  const submitPhone = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    setLastAction('request');
    startTransition(() => requestFormAction(formData));
  };

  const submitCode = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    formData.set('phone', state.phone);
    formData.set('next', next);
    setLastAction('verify');
    startTransition(() => verifyFormAction(formData));
  };

  const resend = () => {
    const formData = new FormData();
    formData.set('phone', state.phone);
    setLastAction('request');
    startTransition(() => requestFormAction(formData));
  };

  const alert = state.status === 'error' && state.message && (
    <p role="alert" className="rounded-md bg-danger/10 px-3 py-2 text-sm text-danger">
      {state.message}
    </p>
  );

  if (state.phase === 'phone') {
    return (
      <form onSubmit={submitPhone} noValidate className="space-y-4">
        {alert}

        <FormField id="otp-phone" label="Cep telefonu" error={state.fieldErrors.phone}>
          {({ id, describedBy, invalid }) => (
            <input
              id={id}
              name="phone"
              type="tel"
              inputMode="tel"
              autoComplete="tel"
              defaultValue={state.phone}
              aria-invalid={invalid}
              aria-describedby={describedBy}
              className={inputClass(invalid)}
              placeholder="0555 111 22 33"
            />
          )}
        </FormField>

        <Button
          type="submit"
          size="lg"
          className="w-full"
          disabled={pending}
          disabledReason="Kod gönderiliyor, işlem sürüyor."
        >
          {pending ? 'Gönderiliyor…' : 'Giriş kodu gönder'}
        </Button>

        <p className="text-xs text-muted-foreground">
          Numaranıza 6 haneli bir kod göndereceğiz. Şifre gerekmez.
        </p>
      </form>
    );
  }

  return (
    <form onSubmit={submitCode} noValidate className="space-y-4">
      {alert}

      <p className="text-sm text-muted-foreground">
        <span className="font-medium text-foreground">{formatPhone(state.phone)}</span> numarasına
        gönderilen kodu girin.
      </p>

      <FormField id="otp-code" label="Giriş kodu" error={state.fieldErrors.code}>
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
             * Bu öznitelik olmadan kodu elle kopyalamak gerekir.
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

      <Button
        type="submit"
        size="lg"
        className="w-full"
        disabled={pending}
        disabledReason="Kod doğrulanıyor, işlem sürüyor."
      >
        {pending ? 'Doğrulanıyor…' : 'Giriş yap'}
      </Button>

      <div className="flex items-center justify-between text-sm">
        <ResendButton resendAt={state.resendAt} disabled={pending} onResend={resend} />

        <button
          type="button"
          className="text-muted-foreground underline underline-offset-4 hover:text-foreground"
          onClick={() => {
            // Numarayı düzeltmek için birinci aşamaya dön. Sunucuya istek
            // atmıyoruz; yalnızca hangi eylemin durumunu gösterdiğimizi
            // sıfırlıyoruz ve `requestState` hâlâ `phase: 'phone'`.
            setLastAction('request');
          }}
        >
          Numarayı değiştir
        </button>
      </div>
    </form>
  );
}

/**
 * "Yeniden gönder" düğmesi ve geri sayımı.
 *
 * Sayaç MUTLAK ZAMAN DAMGASINDAN hesaplanıyor, saniye saniye azalan bir
 * sayaçtan değil: kullanıcı sekmeyi arka plana aldığında tarayıcı zamanlayıcıyı
 * kısıyor ve azalan sayaç donuyor. Damgadan hesaplayınca geri dönüşte doğru
 * değer görünüyor.
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
      <span className="text-muted-foreground tabular-nums">Yeniden gönder ({remaining} sn)</span>
    );
  }

  return (
    <button
      type="button"
      onClick={onResend}
      disabled={disabled}
      className="font-medium text-primary underline underline-offset-4 disabled:opacity-50"
    >
      Kodu yeniden gönder
    </button>
  );
}

function secondsUntil(timestamp: number): number {
  return Math.max(0, Math.ceil((timestamp - Date.now()) / 1000));
}

/** `5551112233` → `0555 111 22 33`. Yalnız gösterim içindir. */
function formatPhone(phone: string): string {
  if (phone.length !== 10) return phone;
  return `0${phone.slice(0, 3)} ${phone.slice(3, 6)} ${phone.slice(6, 8)} ${phone.slice(8)}`;
}
