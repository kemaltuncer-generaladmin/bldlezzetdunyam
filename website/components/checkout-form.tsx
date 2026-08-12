'use client';

import { useActionState, useState, useTransition } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { createOrderAction } from '@/app/actions/order';
import { IDLE_CHECKOUT_STATE } from '@/lib/action-state';
import { EtaOptionNote } from '@/components/delivery-eta';
import { FormField, inputClass } from '@/components/form-field';
import { MapPickerLazy, type MapPin } from '@/components/address/map-picker-lazy';
import { paymentMethodHint, paymentMethodLabel } from '@/lib/labels';
import { SERVICE_AREA_CITY, SERVICE_AREA_DISTRICTS } from '@/lib/service-area';
import { checkoutSchema, type CheckoutValues } from '@/lib/validation/checkout';
import { cn } from '@/lib/utils';
import type { LocationEta, PaymentMethod, SavedAddress } from '@/lib/api/types';

type Props = {
  /** Yalnızca vitrinin açık ödeme yöntemleri (`docs/06` §3). */
  paymentMethods: PaymentMethod[];
  /** `datetime-local` alt sınırı, Europe/Istanbul duvar saati. */
  minRequestedAt: string;
  orderCutoff: string | null;
  /** Teslim süresi tahmini; sunucu vermiyorsa `null` ve hiç gösterilmez. */
  eta: LocationEta | null;
  /**
   * Kayıtlı adresler (W-15). Boş dizi gelebilir: defteri hiç kullanmamış
   * müşteri ya da uç okunamamış olabilir — ikisinde de form elle yazmaya
   * izin vermeye devam ediyor.
   */
  savedAddresses: readonly SavedAddress[];
};

export function CheckoutForm({
  paymentMethods,
  minRequestedAt,
  orderCutoff,
  eta,
  savedAddresses,
}: Props) {
  const [serverState, formAction] = useActionState(createOrderAction, IDLE_CHECKOUT_STATE);
  const [pending, startTransition] = useTransition();

  /*
   * Varsayılan adres önceden dolu geliyor (W-15). Müşterilerin çoğu hep
   * aynı yere sipariş veriyor; her seferinde listeden seçtirmek gereksiz
   * bir adım olurdu. Defter boşsa alanlar eskisi gibi boş açılıyor.
   */
  const defaultAddress = savedAddresses.find((item) => item.is_default) ?? null;

  const {
    register,
    handleSubmit,
    watch,
    setValue,
    formState: { errors },
  } = useForm<CheckoutValues>({
    resolver: zodResolver(checkoutSchema),
    mode: 'onBlur',
    defaultValues: {
      delivery_type: 'delivery',
      payment_method: paymentMethods[0] ?? 'cash',
      timing: 'asap',
      requested_at_local: '',
      address_line1: defaultAddress?.line1 ?? '',
      address_district: defaultAddress?.district ?? '',
      // Tek il olduğu için varsayılan doğrudan dolu gelir; kullanıcı
      // değiştiremez.
      address_city: SERVICE_AREA_CITY,
      address_note: defaultAddress?.note ?? '',
      address_latitude: '',
      address_longitude: '',
      customer_note: '',
    },
  });

  const deliveryType = watch('delivery_type');
  const timing = watch('timing');
  const isDelivery = deliveryType === 'delivery';

  /**
   * Haritadan seçilen nokta. Form alanı DEĞİL: React Hook Form metin
   * girdileri için var, harita ise kendi etkileşimini yönetiyor. Gönderimde
   * `FormData`'ya elle ekleniyor.
   */
  const [pin, setPin] = useState<MapPin | null>(
    defaultAddress?.latitude != null && defaultAddress.longitude != null
      ? { latitude: defaultAddress.latitude, longitude: defaultAddress.longitude }
      : null,
  );

  const onSubmit = handleSubmit((values) => {
    const formData = new FormData();
    // Koordinat formun bir alanı değil, harita bileşeninin durumu; elle
    // ekleniyor. Boşken boş dize gidiyor ve sunucu tarafı onu yok sayıyor.
    formData.set('address_latitude', pin ? String(pin.latitude) : '');
    formData.set('address_longitude', pin ? String(pin.longitude) : '');
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
        <section className="space-y-4 bld-card p-5">
          <h2 className="text-lg font-semibold text-neutral-900">Teslimat adresi</h2>

          {/*
            KAYITLI ADRES SEÇİMİ — W-15.

            Defter boşsa hiç çizilmiyor: tek seçeneği olmayan bir açılır
            liste, ekranda yer kaplayan bir soru işareti olurdu.

            Seçim formu DOLDURUYOR, kilitlemiyor: müşteri kayıtlı adresi
            seçip üstünde küçük bir düzeltme yapabilmeli (kat değişmiş,
            zil bozulmuş). Sipariş adresi zaten kopyalanıyor, deftere
            bağlanmıyor.
          */}
          {savedAddresses.length > 0 && (
            <div className="mb-4">
              <label htmlFor="kayitli-adres" className="mb-1 block text-sm font-medium">
                Kayıtlı adreslerim
              </label>
              <select
                id="kayitli-adres"
                className={inputClass(false)}
                defaultValue=""
                onChange={(event) => {
                  const chosen = savedAddresses.find(
                    (item) => String(item.id) === event.target.value,
                  );
                  if (!chosen) return;

                  setValue('address_line1', chosen.line1, { shouldValidate: true });
                  setValue('address_district', chosen.district, { shouldValidate: true });
                  setValue('address_city', chosen.city, { shouldValidate: true });
                  setValue('address_note', chosen.note ?? '');
                  setPin(
                    chosen.latitude != null && chosen.longitude != null
                      ? { latitude: chosen.latitude, longitude: chosen.longitude }
                      : null,
                  );
                }}
              >
                <option value="">— Yeni adres yaz —</option>
                {savedAddresses.map((item) => (
                  <option key={item.id} value={item.id}>
                    {item.label ?? item.line1} — {item.district}
                  </option>
                ))}
              </select>
            </div>
          )}

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

          {/*
           * İl ve ilçe serbest metin DEĞİL: şu an yalnızca Konya'nın Selçuklu
           * ve Karatay ilçelerine teslimat yapıyoruz. Serbest yazıldığında
           * hizmet vermediğimiz yere sipariş giriliyor, mutfağa düşüyor ve
           * kurye yola çıkarken iptal ediliyordu.
           */}
          <div className="grid gap-4 sm:grid-cols-2">
            <FormField
              id="address_district"
              label="İlçe"
              hint="Şu an yalnızca Selçuklu ve Karatay'a teslimat yapıyoruz."
              error={fieldError('address_district')}
            >
              {({ id, describedBy, invalid }) => (
                <select
                  {...register('address_district')}
                  id={id}
                  autoComplete="address-level2"
                  aria-invalid={invalid}
                  aria-describedby={describedBy}
                  className={inputClass(invalid)}
                >
                  <option value="">Seçin</option>
                  {SERVICE_AREA_DISTRICTS.map((district) => (
                    <option key={district} value={district}>
                      {district}
                    </option>
                  ))}
                </select>
              )}
            </FormField>

            {/*
             * İl değiştirilemez ama `readOnly` bir GİRDİ olarak duruyor,
             * salt metin olarak değil: `disabled` yapılsaydı değer forma
             * dahil olmaz, sunucuya boş il giderdi.
             */}
            <FormField id="address_city" label="İl" error={fieldError('address_city')}>
              {({ id, describedBy, invalid }) => (
                <input
                  {...register('address_city')}
                  id={id}
                  type="text"
                  readOnly
                  autoComplete="address-level1"
                  aria-invalid={invalid}
                  aria-describedby={describedBy}
                  className={cn(inputClass(invalid), 'bg-neutral-50 text-neutral-700')}
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

          {/*
            HARİTADAN NOKTA — W-16.

            Kurye fişindeki QR (K-14) yalnızca koordinat varken basılıyor.
            Site bunu hiç toplamadığı için siteden gelen her siparişin
            kurye fişi QR'sızdı; kurye adresi okuyup elle aramak zorunda
            kalıyordu.

            İSTEĞE BAĞLI: konum izni vermeyen müşteri de sipariş
            verebilmeli. Boş bırakılırsa yalnız QR basılmıyor, sipariş
            normal akıyor.
          */}
          <div className="mt-5 border-t pt-5">
            <p className="text-sm font-medium">Teslimat noktası (isteğe bağlı)</p>
            <MapPickerLazy value={pin} onChange={setPin} />
          </div>
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
              body={
                <>
                  Mutfak siparişi alır almaz hazırlamaya başlar.
                  {/*
                   * Tahmin teslim türüne bağlı: gel-alda yol süresi yok.
                   * Kullanıcı yukarıda adrese teslim ↔ gel-al arasında
                   * geçtiğinde buradaki süre de değişir.
                   */}
                  {eta && (
                    <EtaOptionNote estimate={eta[deliveryType]} deliveryType={deliveryType} />
                  )}
                </>
              }
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
  /** Düz metin ya da düğüm — "en kısa sürede" seçeneği canlı tahmin gösteriyor. */
  body: React.ReactNode;
};

function RadioCard({ title, body, className, ...inputProps }: RadioCardProps) {
  const id = `${String(inputProps.name)}-${String(inputProps.value)}`;
  return (
    <label
      htmlFor={id}
      className={cn(
        'flex cursor-pointer gap-3 rounded-lg border border-neutral-200 bg-neutral-0 p-3 text-sm hover:border-brand-300 has-checked:border-brand-600 has-checked:bg-brand-50',
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
