'use client';

import { useActionState, useTransition } from 'react';
import Link from 'next/link';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { registerAction } from '@/app/actions/auth';
import { IDLE_AUTH_STATE } from '@/lib/action-state';
import { FormField, inputClass } from '@/components/form-field';
import { registerSchema, type RegisterValues } from '@/lib/validation/auth';

export function RegisterForm({ next }: { next: string }) {
  const [serverState, formAction] = useActionState(registerAction, IDLE_AUTH_STATE);
  const [pending, startTransition] = useTransition();

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<RegisterValues>({
    resolver: zodResolver(registerSchema),
    mode: 'onBlur',
    defaultValues: {
      first_name: '',
      last_name: '',
      email: '',
      telephone: '',
      password: '',
      password_confirm: '',
      kvkk_accepted: false as unknown as true,
    },
  });

  const onSubmit = handleSubmit((values) => {
    const formData = new FormData();
    formData.set('first_name', values.first_name);
    formData.set('last_name', values.last_name);
    formData.set('email', values.email);
    formData.set('telephone', values.telephone);
    formData.set('password', values.password);
    formData.set('password_confirm', values.password_confirm);
    formData.set('kvkk_accepted', values.kvkk_accepted ? 'true' : 'false');
    formData.set('next', next);
    startTransition(() => formAction(formData));
  });

  const fieldError = (name: keyof RegisterValues): string | undefined => {
    const clientError = errors[name]?.message;
    return typeof clientError === 'string' ? clientError : serverState.fieldErrors[name];
  };

  const kvkkError = fieldError('kvkk_accepted');

  return (
    <form onSubmit={onSubmit} noValidate className="space-y-4">
      {serverState.status === 'error' && serverState.message && (
        <p role="alert" className="rounded-md bg-danger/10 px-3 py-2 text-sm text-danger">
          {serverState.message}
        </p>
      )}

      <div className="grid gap-4 sm:grid-cols-2">
        <FormField id="first_name" label="Ad" error={fieldError('first_name')}>
          {({ id, describedBy, invalid }) => (
            <input
              {...register('first_name')}
              id={id}
              type="text"
              autoComplete="given-name"
              maxLength={64}
              aria-invalid={invalid}
              aria-describedby={describedBy}
              className={inputClass(invalid)}
            />
          )}
        </FormField>

        <FormField id="last_name" label="Soyad" error={fieldError('last_name')}>
          {({ id, describedBy, invalid }) => (
            <input
              {...register('last_name')}
              id={id}
              type="text"
              autoComplete="family-name"
              maxLength={64}
              aria-invalid={invalid}
              aria-describedby={describedBy}
              className={inputClass(invalid)}
            />
          )}
        </FormField>
      </div>

      <FormField id="email" label="E-posta" error={fieldError('email')}>
        {({ id, describedBy, invalid }) => (
          <input
            {...register('email')}
            id={id}
            type="email"
            autoComplete="email"
            inputMode="email"
            aria-invalid={invalid}
            aria-describedby={describedBy}
            className={inputClass(invalid)}
            placeholder="ornek@firma.com"
          />
        )}
      </FormField>

      <FormField
        id="telephone"
        label="Cep telefonu"
        hint="Başında 0 olmadan 10 hane. Örn. 5551234567"
        error={fieldError('telephone')}
      >
        {({ id, describedBy, invalid }) => (
          <input
            {...register('telephone')}
            id={id}
            type="tel"
            autoComplete="tel-national"
            inputMode="numeric"
            aria-invalid={invalid}
            aria-describedby={describedBy}
            className={inputClass(invalid)}
            placeholder="5551234567"
          />
        )}
      </FormField>

      <FormField
        id="password"
        label="Parola"
        hint="En az 8 karakter."
        error={fieldError('password')}
      >
        {({ id, describedBy, invalid }) => (
          <input
            {...register('password')}
            id={id}
            type="password"
            autoComplete="new-password"
            aria-invalid={invalid}
            aria-describedby={describedBy}
            className={inputClass(invalid)}
          />
        )}
      </FormField>

      <FormField
        id="password_confirm"
        label="Parola (tekrar)"
        error={fieldError('password_confirm')}
      >
        {({ id, describedBy, invalid }) => (
          <input
            {...register('password_confirm')}
            id={id}
            type="password"
            autoComplete="new-password"
            aria-invalid={invalid}
            aria-describedby={describedBy}
            className={inputClass(invalid)}
          />
        )}
      </FormField>

      <div>
        <div className="flex items-start gap-3">
          <input
            {...register('kvkk_accepted')}
            id="kvkk_accepted"
            type="checkbox"
            aria-invalid={Boolean(kvkkError)}
            aria-describedby={kvkkError ? 'kvkk_accepted-hata' : undefined}
            className="mt-1 h-4 w-4 shrink-0 accent-brand-600"
          />
          <label htmlFor="kvkk_accepted" className="text-sm text-neutral-800">
            <Link
              href="/kvkk"
              className="rounded-sm font-semibold text-brand-700 underline-offset-2 hover:underline"
            >
              KVKK Aydınlatma Metni
            </Link>
            ni okudum, kişisel verilerimin sipariş sürecinde işlenmesini onaylıyorum.
          </label>
        </div>
        {kvkkError && (
          <p id="kvkk_accepted-hata" role="alert" className="mt-1 text-sm text-danger">
            {kvkkError}
          </p>
        )}
      </div>

      <button type="submit" disabled={pending} className="bld-btn-primary w-full">
        {pending ? 'Hesap oluşturuluyor…' : 'Hesap oluştur'}
      </button>

      <p className="text-center text-sm text-neutral-600">
        Zaten hesabınız var mı?{' '}
        <Link
          href={`/giris?next=${encodeURIComponent(next)}`}
          className="rounded-sm font-semibold text-brand-700 underline-offset-2 hover:underline"
        >
          Giriş yapın
        </Link>
      </p>
    </form>
  );
}
