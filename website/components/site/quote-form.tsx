'use client';

import { useActionState, useEffect, useId, useRef, useState } from 'react';
import Link from 'next/link';
import { AlertTriangle, CheckCircle2, Loader2 } from 'lucide-react';
import { submitQuote } from '@/app/actions/quote';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { IDLE_QUOTE_STATE } from '@/lib/action-state';
import {
  MENU_PREFERENCES,
  ONE_OFF_SERVICES,
  ON_SITE_SERVICES,
  QUOTE_SERVICE_TYPES,
  SERVICE_FREQUENCIES,
  type QuoteServiceType,
} from '@/lib/validation/quote';
import { cn } from '@/lib/utils';

/**
 * Teklif formu.
 *
 * ## Neden `useActionState`, istemci tarafı fetch değil?
 *
 * Doğrulamanın son sözünü sunucu söylüyor; form JavaScript yüklenmeden de
 * gönderilebiliyor (progressive enhancement). Bot koruması da sunucuda —
 * istemcide yapılsaydı atlanabilirdi.
 *
 * ## Koşullu alanlar
 *
 * Alanlar hizmet türüne göre değişiyor ama **gizlenen alan DOM'dan siliniyor**,
 * `display:none` ile saklanmıyor: gizli ama var olan bir alan hem klavyeyle
 * gezilebilir kalır hem de FormData'ya boş değer sokup sunucu doğrulamasını
 * şaşırtır.
 */

type FieldProps = {
  id: string;
  label: string;
  error?: string;
  hint?: string;
  required?: boolean;
  children: (aria: { id: string; describedBy?: string; invalid: boolean }) => React.ReactNode;
};

function Field({ id, label, error, hint, required, children }: FieldProps) {
  const errorId = `${id}-hata`;
  const hintId = `${id}-ipucu`;
  const describedBy = [hint ? hintId : null, error ? errorId : null].filter(Boolean).join(' ');

  return (
    <div className="space-y-1.5">
      <Label htmlFor={id}>
        {label}
        {required && (
          <span aria-hidden="true" className="ml-0.5 text-destructive">
            *
          </span>
        )}
      </Label>
      {hint && (
        <p id={hintId} className="text-xs text-muted-foreground">
          {hint}
        </p>
      )}
      {children({ id, describedBy: describedBy || undefined, invalid: Boolean(error) })}
      {error && (
        <p id={errorId} role="alert" className="text-sm text-destructive">
          {error}
        </p>
      )}
    </div>
  );
}

const SELECT_CLASS =
  'border-input bg-card text-foreground focus-visible:ring-ring h-11 w-full rounded-lg border px-3 text-sm outline-none focus-visible:ring-2';

export function QuoteForm() {
  const [state, formAction, pending] = useActionState(submitQuote, IDLE_QUOTE_STATE);
  const [serviceType, setServiceType] = useState<QuoteServiceType | ''>('');
  const summaryRef = useRef<HTMLDivElement>(null);
  const formId = useId();

  /*
   * Form açılış zamanı. Sunucu bunu "üç saniyeden hızlı doldurulmuş" botları
   * elemek için kullanıyor. `useState` başlatıcısıyla bir kez hesaplanıyor;
   * render başına yeniden üretilseydi her yeniden çizimde sıfırlanırdı.
   */
  const [openedAt] = useState(() => Date.now());

  // Gönderim sonucu geldiğinde odağı özet kutusuna taşı: ekran okuyucu
  // kullanıcısı sonucu duymadan formda kaybolmasın.
  useEffect(() => {
    if (state.at > 0 && state.status !== 'idle') summaryRef.current?.focus();
  }, [state.at, state.status]);

  const isOneOff = serviceType !== '' && ONE_OFF_SERVICES.includes(serviceType);
  const needsKitchenNote = serviceType !== '' && ON_SITE_SERVICES.includes(serviceType);
  const errors = state.fieldErrors;

  if (state.status === 'ok') {
    return (
      <div
        ref={summaryRef}
        tabIndex={-1}
        className="rounded-2xl border bg-card p-8 text-center outline-none sm:p-12"
      >
        <span
          aria-hidden="true"
          className="mx-auto grid size-14 place-items-center rounded-full bg-success/10 text-success"
        >
          <CheckCircle2 className="size-7" />
        </span>
        <h2 className="mt-5 font-display text-2xl font-semibold tracking-tight">
          Talebiniz bize ulaştı
        </h2>
        <p className="mx-auto mt-3 max-w-md text-sm/6 text-muted-foreground">
          İhtiyacınızı inceleyip menü önerisi ve fiyatlandırmayla birlikte size döneceğiz. Acil bir
          durumda doğrudan da ulaşabilirsiniz.
        </p>
        <Button asChild variant="outline" className="mt-7">
          <Link href="/menu">Günün menüsüne bak</Link>
        </Button>
      </div>
    );
  }

  return (
    <form action={formAction} className="space-y-8" noValidate>
      <input type="hidden" name="opened_at" value={openedAt} />

      {/* Bal küpü: ekrandan ve ekran okuyucudan gizli, yalnızca botlar doldurur. */}
      <div aria-hidden="true" className="absolute -left-[9999px] h-px w-px overflow-hidden">
        <label htmlFor={`${formId}-website`}>Web siteniz</label>
        <input
          id={`${formId}-website`}
          name="website"
          type="text"
          tabIndex={-1}
          autoComplete="off"
        />
      </div>

      {(state.status === 'error' || state.status === 'unconfigured') && (
        <div ref={summaryRef} tabIndex={-1} className="outline-none">
          <Alert variant="destructive">
            <AlertTriangle aria-hidden="true" />
            <AlertTitle>
              {state.status === 'unconfigured' ? 'Talep iletilemedi' : 'Gönderilemedi'}
            </AlertTitle>
            <AlertDescription>{state.message}</AlertDescription>
          </Alert>
        </div>
      )}

      <fieldset className="space-y-5">
        <legend className="font-display text-lg font-semibold tracking-tight">
          İletişim bilgileriniz
        </legend>

        <div className="grid gap-5 sm:grid-cols-2">
          <Field id="full_name" label="Ad soyad" required error={errors.full_name}>
            {(aria) => (
              <Input
                id={aria.id}
                name="full_name"
                autoComplete="name"
                aria-describedby={aria.describedBy}
                aria-invalid={aria.invalid}
                className="h-11"
              />
            )}
          </Field>

          <Field id="organization" label="Firma / kurum adı" required error={errors.organization}>
            {(aria) => (
              <Input
                id={aria.id}
                name="organization"
                autoComplete="organization"
                aria-describedby={aria.describedBy}
                aria-invalid={aria.invalid}
                className="h-11"
              />
            )}
          </Field>

          <Field
            id="telephone"
            label="Telefon"
            required
            hint="Başında 0 olmadan 10 hane. Örn. 5551234567"
            error={errors.telephone}
          >
            {(aria) => (
              <Input
                id={aria.id}
                name="telephone"
                type="tel"
                inputMode="numeric"
                autoComplete="tel"
                aria-describedby={aria.describedBy}
                aria-invalid={aria.invalid}
                className="h-11"
              />
            )}
          </Field>

          <Field id="email" label="E-posta" required error={errors.email}>
            {(aria) => (
              <Input
                id={aria.id}
                name="email"
                type="email"
                autoComplete="email"
                aria-describedby={aria.describedBy}
                aria-invalid={aria.invalid}
                className="h-11"
              />
            )}
          </Field>
        </div>
      </fieldset>

      <fieldset className="space-y-5">
        <legend className="font-display text-lg font-semibold tracking-tight">İhtiyacınız</legend>

        <Field id="service_type" label="Hizmet türü" required error={errors.service_type}>
          {(aria) => (
            <select
              id={aria.id}
              name="service_type"
              value={serviceType}
              onChange={(event) => setServiceType(event.target.value as QuoteServiceType)}
              aria-describedby={aria.describedBy}
              aria-invalid={aria.invalid}
              className={cn(SELECT_CLASS, aria.invalid && 'border-destructive')}
            >
              <option value="">Seçin</option>
              {QUOTE_SERVICE_TYPES.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          )}
        </Field>

        <div className="grid gap-5 sm:grid-cols-2">
          <Field
            id="headcount"
            label={isOneOff ? 'Davetli sayısı' : 'Günlük kişi sayısı'}
            required
            error={errors.headcount}
          >
            {(aria) => (
              <Input
                id={aria.id}
                name="headcount"
                type="number"
                inputMode="numeric"
                min={1}
                aria-describedby={aria.describedBy}
                aria-invalid={aria.invalid}
                className="h-11"
              />
            )}
          </Field>

          {/*
           * Tek seferlik hizmetlerde sıklık sorulmaz — bir düğün "haftada üç
           * gün" tekrar etmez. Buna karşılık tarih zorunlu hâle gelir.
           */}
          {!isOneOff && (
            <Field id="frequency" label="Hizmet sıklığı" required error={errors.frequency}>
              {(aria) => (
                <select
                  id={aria.id}
                  name="frequency"
                  aria-describedby={aria.describedBy}
                  aria-invalid={aria.invalid}
                  className={cn(SELECT_CLASS, aria.invalid && 'border-destructive')}
                  defaultValue=""
                >
                  <option value="">Seçin</option>
                  {SERVICE_FREQUENCIES.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              )}
            </Field>
          )}

          <Field
            id="start_date"
            label={isOneOff ? 'Etkinlik tarihi' : 'Başlangıç tarihi'}
            required={isOneOff}
            hint={isOneOff ? undefined : 'Belirsizse boş bırakabilirsiniz.'}
            error={errors.start_date}
          >
            {(aria) => (
              <Input
                id={aria.id}
                name="start_date"
                type="date"
                aria-describedby={aria.describedBy}
                aria-invalid={aria.invalid}
                className="h-11"
              />
            )}
          </Field>

          <Field
            id="location"
            label="Hizmet konumu"
            required
            hint="İl / ilçe yeterli."
            error={errors.location}
          >
            {(aria) => (
              <Input
                id={aria.id}
                name="location"
                aria-describedby={aria.describedBy}
                aria-invalid={aria.invalid}
                className="h-11"
              />
            )}
          </Field>
        </div>

        <Field id="menu_preference" label="Menü tercihi" error={errors.menu_preference}>
          {(aria) => (
            <select
              id={aria.id}
              name="menu_preference"
              aria-describedby={aria.describedBy}
              aria-invalid={aria.invalid}
              className={SELECT_CLASS}
              defaultValue="siz-onerin"
            >
              {MENU_PREFERENCES.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          )}
        </Field>

        {/* Yerinde üretimde mutfak altyapısı belirleyici; diğerlerinde alan hiç yok. */}
        {needsKitchenNote && (
          <Field
            id="kitchen_note"
            label="Mutfak altyapınız"
            hint="Mevcut ekipman, alan büyüklüğü ve depolama imkânı hakkında kısa bilgi."
            error={errors.kitchen_note}
          >
            {(aria) => (
              <Textarea
                id={aria.id}
                name="kitchen_note"
                rows={3}
                aria-describedby={aria.describedBy}
                aria-invalid={aria.invalid}
              />
            )}
          </Field>
        )}

        <Field
          id="message"
          label="Eklemek istedikleriniz"
          hint="Özel beslenme ihtiyaçları, vardiya saatleri veya aklınızdaki sorular."
          error={errors.message}
        >
          {(aria) => (
            <Textarea
              id={aria.id}
              name="message"
              rows={4}
              aria-describedby={aria.describedBy}
              aria-invalid={aria.invalid}
            />
          )}
        </Field>
      </fieldset>

      <div className="space-y-4 border-t pt-6">
        <div className="flex items-start gap-3">
          <Checkbox
            id="kvkk_accepted"
            name="kvkk_accepted"
            aria-invalid={Boolean(errors.kvkk_accepted)}
          />
          <div className="space-y-1">
            <Label htmlFor="kvkk_accepted" className="text-sm leading-relaxed font-normal">
              <span>
                <Link href="/kvkk" className="text-primary underline underline-offset-4">
                  KVKK Aydınlatma Metni
                </Link>
                &apos;ni okudum; iletişim bilgilerimin teklif hazırlanması amacıyla işlenmesini
                kabul ediyorum.
              </span>
            </Label>
            {errors.kvkk_accepted && (
              <p role="alert" className="text-sm text-destructive">
                {errors.kvkk_accepted}
              </p>
            )}
          </div>
        </div>

        <Button type="submit" size="lg" disabled={pending} className="w-full sm:w-auto">
          {pending && <Loader2 aria-hidden="true" className="animate-spin" />}
          {pending ? 'Gönderiliyor…' : 'Teklif talebini gönder'}
        </Button>
      </div>
    </form>
  );
}
