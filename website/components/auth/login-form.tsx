'use client';

import { useActionState, useTransition } from 'react';
import Link from 'next/link';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { loginAction } from '@/app/actions/auth';
import { IDLE_AUTH_STATE } from '@/lib/action-state';
import { FormField, inputClass } from '@/components/form-field';
import { loginSchema, type LoginValues } from '@/lib/validation/auth';

export function LoginForm({ next }: { next: string }) {
  const [serverState, formAction] = useActionState(loginAction, IDLE_AUTH_STATE);
  const [pending, startTransition] = useTransition();

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<LoginValues>({
    resolver: zodResolver(loginSchema),
    mode: 'onBlur',
    defaultValues: { email: '', password: '' },
  });

  const onSubmit = handleSubmit((values) => {
    const formData = new FormData();
    formData.set('email', values.email);
    formData.set('password', values.password);
    formData.set('next', next);
    startTransition(() => formAction(formData));
  });

  const emailError = errors.email?.message ?? serverState.fieldErrors.email;
  const passwordError = errors.password?.message ?? serverState.fieldErrors.password;

  return (
    <form onSubmit={onSubmit} noValidate className="space-y-4">
      {serverState.status === 'error' && serverState.message && (
        <p role="alert" className="rounded-md bg-danger/10 px-3 py-2 text-sm text-danger">
          {serverState.message}
        </p>
      )}

      <FormField id="email" label="E-posta" error={emailError}>
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

      <FormField id="password" label="Parola" error={passwordError}>
        {({ id, describedBy, invalid }) => (
          <input
            {...register('password')}
            id={id}
            type="password"
            autoComplete="current-password"
            aria-invalid={invalid}
            aria-describedby={describedBy}
            className={inputClass(invalid)}
          />
        )}
      </FormField>

      <button
        type="submit"
        disabled={pending}
        className="w-full rounded-lg bg-brand-700 px-4 py-3 text-sm font-semibold text-neutral-0 hover:bg-brand-800 disabled:bg-neutral-200 disabled:text-neutral-600"
      >
        {pending ? 'Giriş yapılıyor…' : 'Giriş yap'}
      </button>

      <p className="text-center text-sm text-neutral-600">
        Hesabınız yok mu?{' '}
        <Link
          href={`/kayit?next=${encodeURIComponent(next)}`}
          className="rounded font-semibold text-brand-700 underline-offset-2 hover:underline"
        >
          Kayıt olun
        </Link>
      </p>
    </form>
  );
}
