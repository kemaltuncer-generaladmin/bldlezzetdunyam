'use client';

import { useActionState, useTransition } from 'react';
import Link from 'next/link';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { corporateRegisterAction } from '@/app/actions/auth';
import { IDLE_AUTH_STATE } from '@/lib/action-state';
import { FormField, inputClass } from '@/components/form-field';
import { Button } from '@/components/ui/button';
import { corporateRegisterSchema, type CorporateRegisterValues } from '@/lib/validation/auth';

/**
 * Kurumsal kayıt — W-11.
 *
 * `RegisterForm`'un kopyası DEĞİL, yerine geçeni: sipariş kapısı kurumsal
 * hesaplarda açık (`docs/00` B2B kararı) ve bireysel kayıt diye bir şey
 * kalmadı. Alan kümesi farklı olduğu için ayrı bileşen — ortak bir bileşene
 * "kurumsal mı" bayrağı geçirmek, her alanın etrafına koşul yazmak olurdu.
 *
 * KAYIT ANINDA SİPARİŞ AÇILIR. Onay beklemez: iş kararı böyle. Ayrı bir
 * karar olan CARİ HESAP (veresiye) kapalı başlar; formda ondan hiç söz
 * edilmiyor çünkü müşterinin isteyebileceği bir şey değil, yöneticinin
 * vereceği bir yetki.
 */
export function CorporateRegisterForm({ next }: { next: string }) {
  const [serverState, formAction] = useActionState(corporateRegisterAction, IDLE_AUTH_STATE);
  const [pending, startTransition] = useTransition();

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<CorporateRegisterValues>({
    resolver: zodResolver(corporateRegisterSchema),
    mode: 'onBlur',
    defaultValues: {
      company_name: '',
      tax_office: '',
      tax_number: '',
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
    for (const [key, value] of Object.entries(values)) {
      formData.set(key, typeof value === 'boolean' ? String(value) : String(value));
    }
    formData.set('next', next);
    startTransition(() => formAction(formData));
  });

  const fieldError = (name: keyof CorporateRegisterValues): string | undefined => {
    const clientError = errors[name]?.message;
    return typeof clientError === 'string' ? clientError : serverState.fieldErrors[name];
  };

  const kvkkError = fieldError('kvkk_accepted');

  return (
    <form onSubmit={onSubmit} noValidate className="space-y-6">
      {serverState.status === 'error' && serverState.message && (
        <p role="alert" className="rounded-md bg-danger/10 px-3 py-2 text-sm text-danger">
          {serverState.message}
        </p>
      )}

      {/* ── Kurum ────────────────────────────────────────────────────── */}
      <fieldset className="space-y-4">
        <legend className="text-sm font-semibold">Firma bilgileri</legend>

        <FormField id="company_name" label="Ticari unvan" error={fieldError('company_name')}>
          {({ id, describedBy, invalid }) => (
            <input
              {...register('company_name')}
              id={id}
              type="text"
              autoComplete="organization"
              maxLength={160}
              aria-invalid={invalid}
              aria-describedby={describedBy}
              className={inputClass(invalid)}
              placeholder="Örnek Gıda San. ve Tic. Ltd. Şti."
            />
          )}
        </FormField>

        <div className="grid gap-4 sm:grid-cols-2">
          <FormField id="tax_office" label="Vergi dairesi" error={fieldError('tax_office')}>
            {({ id, describedBy, invalid }) => (
              <input
                {...register('tax_office')}
                id={id}
                type="text"
                maxLength={120}
                aria-invalid={invalid}
                aria-describedby={describedBy}
                className={inputClass(invalid)}
              />
            )}
          </FormField>

          <FormField
            id="tax_number"
            label="Vergi no / TCKN"
            hint="Şirkette 10 hane, şahıs şirketinde 11 hane."
            error={fieldError('tax_number')}
          >
            {({ id, describedBy, invalid }) => (
              <input
                {...register('tax_number')}
                id={id}
                type="text"
                inputMode="numeric"
                maxLength={11}
                aria-invalid={invalid}
                aria-describedby={describedBy}
                className={inputClass(invalid)}
              />
            )}
          </FormField>
        </div>
      </fieldset>

      {/* ── Yetkili ──────────────────────────────────────────────────── */}
      <fieldset className="space-y-4">
        <legend className="text-sm font-semibold">Yetkili kişi</legend>

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
          hint="Telefonla giriş bu numaraya kod gönderir. Başında 0 olmadan 10 hane."
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
      </fieldset>

      {/* ── Parola ───────────────────────────────────────────────────── */}
      <fieldset className="space-y-4">
        <legend className="text-sm font-semibold">Parola</legend>

        <div className="grid gap-4 sm:grid-cols-2">
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
        </div>

        <p className="text-xs text-muted-foreground">
          Parolayı unutursanız telefonunuza gelen kodla da girebilirsiniz.
        </p>
      </fieldset>

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
          <label htmlFor="kvkk_accepted" className="text-sm">
            <Link
              href="/kvkk"
              className="rounded-sm font-semibold text-primary underline-offset-2 hover:underline"
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

      <Button
        type="submit"
        size="lg"
        className="w-full"
        disabled={pending}
        disabledReason="Hesap oluşturuluyor, işlem sürüyor."
      >
        {pending ? 'Hesap oluşturuluyor…' : 'Hesabı oluştur ve sipariş vermeye başla'}
      </Button>

      <p className="text-center text-sm text-muted-foreground">
        Zaten hesabınız var mı?{' '}
        <Link
          href={`/giris?next=${encodeURIComponent(next)}`}
          className="font-semibold text-primary underline-offset-2 hover:underline"
        >
          Giriş yapın
        </Link>
      </p>
    </form>
  );
}
