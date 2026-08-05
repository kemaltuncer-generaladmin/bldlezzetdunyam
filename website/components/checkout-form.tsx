'use client';

import { useActionState, useTransition } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { createOrderAction } from '@/app/actions/order';
import { IDLE_CHECKOUT_STATE } from '@/lib/action-state';
import { FormField, inputClass } from '@/components/form-field';
import { paymentMethodHint, paymentMethodLabel } from '@/lib/labels';
import { checkoutSchema, type CheckoutValues } from '@/lib/validation/checkout';
import { cn } from '@/lib/cn';
import type { PaymentMethod } from '@/lib/api/types';

type Props = {
  /** Yalnızca vitrinin açık ödeme yöntemleri (`docs/06` §3). */
  paymentMethods: PaymentMethod[];
  /** `datetime-local` alt sınırı, Europe/Istanbul duvar saati. */
  minRequestedAt: string;
  orderCutoff: string | null;
};

export function CheckoutForm({ paymentMethods, minRequestedAt, orderCutoff }: Props) {
  const [serverState, formAction] = useActionState(createOrderAction, IDLE_CHECKOUT_STATE);
  const [pending, startTransition] = useTransition();

  const {
    register,
    handleSubmit,
    watch,
    formState: { errors },
  } = useForm<CheckoutValues>({
    resolver: zodResolver(checkoutSchema),
    mode: 'onBlur',
    defaultValues: {
      delivery_type: 'delivery',
      payment_method: paymentMethods[0] ?? 'cash',
      timing: 'asap',
      requested_at_local: '',
      address_line1: '',
      address_district: '',
      address_city: '',
      address_note: '',
      customer_note: '',
    },
  });

  const deliveryType = watch('delivery_type');
  const timing = watch('timing');
  const isDelivery = deliveryType === 'delivery';

  const onSubmit = handleSubmit((values) => {
    const formData = new FormData();
    for (const [key, value] of Object.entries(values)) {
      formData.set(key, String(value ?? ''));
    }
    startTransition(() => formAction(formData));
  });

  const fieldError = (name: keyof CheckoutValues): string | undefined => {
    const clientError = errors[name]?.message;
    return typeof clientError === 'string' ? clientError : serverState.fieldErrors[name];
  };

  return (
    <form onSubmit={onSubmit} noValidate className="space-y-6">
      {serverState.status === 'error' && serverState.message && (
        <p role="alert" className="rounded-md bg-danger/10 px-3 py-2 text-sm text-danger">
          {serverState.message}
        </p>
      )}

      <section className="bld-card p-5">
        <fieldset>
          <legend className="text-lg font-semibold text-neutral-900">Teslimat şekli</legend>
          <div className="mt-3 grid gap-3 sm:grid-cols-2">
            <RadioCard
              {...register('delivery_type')}
              value="delivery"
              title="Adrese teslim"
              body="Belirttiğiniz adrese getiriyoruz. Teslimat ücreti sipariş özetinde görünür."
            />
            <RadioCard
              {...register('delivery_type')}
              value="pickup"
              title="Gel-al"
              body="Siparişinizi işletmeden teslim alırsınız. Teslimat ücreti alınmaz."
            />
          </div>
        </fieldset>
      </section>

      {/* Gel-al siparişte adres adımı tamamen atlanır (docs/06 §3). */}
      {isDelivery && (
        <section className="bld-card space-y-4 p-5">
          <h2 className="text-lg font-semibold text-neutral-900">Teslimat adresi</h2>

          <FormField id="address_line1" label="Adres" error={fieldError('address_line1')}>
            {({ id, describedBy, invalid }) => (
              <input
                {...register('address_line1')}
                id={id}
                type="text"
                autoComplete="street-address"
                aria-invalid={invalid}
                aria-describedby={describedBy}
                className={inputClass(invalid)}
                placeholder="Mahalle, cadde, sokak, kapı no"
              />
            )}
          </FormField>

          <div className="grid gap-4 sm:grid-cols-2">
            <FormField id="address_district" label="İlçe" error={fieldError('address_district')}>
              {({ id, describedBy, invalid }) => (
                <input
                  {...register('address_district')}
                  id={id}
                  type="text"
                  autoComplete="address-level2"
                  aria-invalid={invalid}
                  aria-describedby={describedBy}
                  className={inputClass(invalid)}
                />
              )}
            </FormField>

            <FormField id="address_city" label="İl" error={fieldError('address_city')}>
              {({ id, describedBy, invalid }) => (
                <input
                  {...register('address_city')}
                  id={id}
                  type="text"
                  autoComplete="address-level1"
                  aria-invalid={invalid}
                  aria-describedby={describedBy}
                  className={inputClass(invalid)}
                />
              )}
            </FormField>
          </div>

          <FormField
            id="address_note"
            label="Adres tarifi"
            hint="İsteğe bağlı. Kat, daire, zili çalmayın gibi notlar."
            error={fieldError('address_note')}
          >
            {({ id, describedBy, invalid }) => (
              <input
                {...register('address_note')}
                id={id}
                type="text"
                maxLength={255}
                aria-invalid={invalid}
                aria-describedby={describedBy}
                className={inputClass(invalid)}
              />
            )}
          </FormField>
        </section>
      )}

      <section className="bld-card p-5">
        <fieldset>
          <legend className="text-lg font-semibold text-neutral-900">Teslim zamanı</legend>
          {orderCutoff && (
            <p className="mt-1 text-sm text-neutral-600">
              Günlük son sipariş saatimiz {orderCutoff}.
            </p>
          )}

          <div className="mt-3 grid gap-3 sm:grid-cols-2">
            <RadioCard
              {...register('timing')}
              value="asap"
              title="En kısa sürede"
              body="Mutfak siparişi alır almaz hazırlamaya başlar."
            />
            <RadioCard
              {...register('timing')}
              value="scheduled"
              title="Belirli bir saat"
              body="Teslim tarih ve saatini siz belirleyin."
            />
          </div>

          {timing === 'scheduled' && (
            <div className="mt-4">
              <FormField
                id="requested_at_local"
                label="Teslim tarihi ve saati"
                hint="Türkiye saatiyle."
                error={fieldError('requested_at_local')}
              >
                {({ id, describedBy, invalid }) => (
                  <input
                    {...register('requested_at_local')}
                    id={id}
                    type="datetime-local"
                    min={minRequestedAt}
                    aria-invalid={invalid}
                    aria-describedby={describedBy}
                    className={inputClass(invalid)}
                  />
                )}
              </FormField>
            </div>
          )}
        </fieldset>
      </section>

      <section className="bld-card p-5">
        <fieldset>
          <legend className="text-lg font-semibold text-neutral-900">Ödeme yöntemi</legend>
          <p className="mt-1 text-sm text-neutral-600">
            Yalnızca şu anda açık olan yöntemler listelenir.
          </p>

          <div className="mt-3 space-y-3">
            {paymentMethods.map((method) => (
              <RadioCard
                key={method}
                {...register('payment_method')}
                value={method}
                title={paymentMethodLabel(method)}
                body={paymentMethodHint(method)}
              />
            ))}
          </div>

          {fieldError('payment_method') && (
            <p role="alert" className="mt-2 text-sm text-danger">
              {fieldError('payment_method')}
            </p>
          )}
        </fieldset>
      </section>

      <section className="bld-card p-5">
        <FormField
          id="customer_note"
          label="Sipariş notu"
          hint="İsteğe bağlı, en fazla 500 karakter. Mutfağa iletilir."
          error={fieldError('customer_note')}
        >
          {({ id, describedBy, invalid }) => (
            <textarea
              {...register('customer_note')}
              id={id}
              rows={3}
              maxLength={500}
              aria-invalid={invalid}
              aria-describedby={describedBy}
              className={inputClass(invalid)}
            />
          )}
        </FormField>
      </section>

      <button
        type="submit"
        disabled={pending || paymentMethods.length === 0}
        className="bld-btn-primary w-full py-3.5 text-base"
      >
        {pending ? 'Sipariş oluşturuluyor…' : 'Siparişi onayla'}
      </button>

      <p className="text-center text-xs text-neutral-600">
        Siparişi onaylayarak mesafeli satış sözleşmesini kabul etmiş olursunuz. Ödenecek tutar
        sunucuda hesaplanır.
      </p>
    </form>
  );
}

// React 19'da `ref` normal bir prop olduğu için `register(...)` çıktısı
// olduğu gibi yayılabilir.
type RadioCardProps = React.ComponentPropsWithRef<'input'> & {
  title: string;
  body: string;
};

function RadioCard({ title, body, className, ...inputProps }: RadioCardProps) {
  const id = `${String(inputProps.name)}-${String(inputProps.value)}`;
  return (
    <label
      htmlFor={id}
      className={cn(
        'flex cursor-pointer gap-3 rounded-lg border border-neutral-200 bg-neutral-0 p-3 text-sm hover:border-brand-300 has-[:checked]:border-brand-600 has-[:checked]:bg-brand-50',
        className,
      )}
    >
      <input {...inputProps} id={id} type="radio" className="mt-1 h-4 w-4 accent-brand-600" />
      <span>
        <span className="block font-semibold text-neutral-900">{title}</span>
        {body && <span className="mt-0.5 block text-neutral-600">{body}</span>}
      </span>
    </label>
  );
}
