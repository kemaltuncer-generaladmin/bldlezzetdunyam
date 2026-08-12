'use client';

import { useActionState, useState, useTransition } from 'react';
import { MapPin, Pencil, Star, Trash2 } from 'lucide-react';
import {
  deleteAddressAction,
  makeDefaultAddressAction,
  saveAddressAction,
} from '@/app/actions/addresses';
import { IDLE_ADDRESS_STATE } from '@/lib/action-state';
import { MapPickerLazy, type MapPin as Pin } from '@/components/address/map-picker-lazy';
import { FormField, inputClass } from '@/components/form-field';
import { Button } from '@/components/ui/button';
import { SERVICE_AREA_CITY, SERVICE_AREA_DISTRICTS } from '@/lib/service-area';
import { cn } from '@/lib/utils';
import type { SavedAddress } from '@/lib/api/types';

/**
 * Adres defteri — W-15.
 *
 * Uçlar sözleşmede baştan beri vardı ve mobil kullanıyordu; site hiç
 * çağırmıyordu, yani siteden sipariş veren müşteri adresini her seferinde
 * elden yazıyordu.
 *
 * TEK BİR FORM, İKİ İŞ: yeni adres ve düzenleme aynı formu paylaşıyor.
 * `editing` dolu olduğunda `id` gizli alanla gidiyor ve sunucu eylemi
 * `PATCH`'e dönüyor. İki ayrı form, iki ayrı doğrulama ve iki ayrı harita
 * durumu demekti.
 */
export function AddressBook({ addresses }: { addresses: readonly SavedAddress[] }) {
  const [saveState, saveAction] = useActionState(saveAddressAction, IDLE_ADDRESS_STATE);
  const [deleteState, deleteAction] = useActionState(deleteAddressAction, IDLE_ADDRESS_STATE);
  const [defaultState, defaultAction] = useActionState(
    makeDefaultAddressAction,
    IDLE_ADDRESS_STATE,
  );
  const [pending, startTransition] = useTransition();

  const [editing, setEditing] = useState<SavedAddress | null>(null);
  const [formOpen, setFormOpen] = useState(false);
  const [pin, setPin] = useState<Pin | null>(null);

  const latest = [saveState, deleteState, defaultState].reduce((a, b) => (b.at > a.at ? b : a));

  const openNew = () => {
    setEditing(null);
    setPin(null);
    setFormOpen(true);
  };

  const openEdit = (address: SavedAddress) => {
    setEditing(address);
    setPin(
      address.latitude != null && address.longitude != null
        ? { latitude: address.latitude, longitude: address.longitude }
        : null,
    );
    setFormOpen(true);
  };

  const submit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    formData.set('latitude', pin ? String(pin.latitude) : '');
    formData.set('longitude', pin ? String(pin.longitude) : '');
    startTransition(() => saveAction(formData));
    setFormOpen(false);
  };

  const dispatch = (action: (fd: FormData) => void, id: number) => {
    const formData = new FormData();
    formData.set('id', String(id));
    startTransition(() => action(formData));
  };

  return (
    <div className="space-y-6">
      {latest.status === 'error' && latest.message && (
        <p role="alert" className="rounded-md bg-danger/10 px-3 py-2 text-sm text-danger">
          {latest.message}
        </p>
      )}
      {latest.status === 'ok' && (
        <p role="status" className="rounded-md bg-success/10 px-3 py-2 text-sm">
          Adres defteriniz güncellendi.
        </p>
      )}

      {addresses.length === 0 ? (
        <div className="rounded-xl border bg-card p-8 text-center">
          <h2 className="text-lg font-semibold">Kayıtlı adresiniz yok</h2>
          <p className="mx-auto mt-2 max-w-prose text-sm text-muted-foreground">
            Adres kaydederseniz her siparişte yeniden yazmanız gerekmez. Haritadan nokta seçerseniz
            kuryenin fişine harita QR&apos;ı da basılır.
          </p>
        </div>
      ) : (
        <ul className="space-y-3">
          {addresses.map((address) => (
            <li
              key={address.id}
              className="flex flex-wrap items-start justify-between gap-3 rounded-xl border bg-card p-4"
            >
              <div className="min-w-0">
                <p className="flex flex-wrap items-center gap-2 font-medium">
                  {address.label ?? address.line1}
                  {address.is_default && (
                    <span className="rounded-full bg-brand-50 px-2 py-0.5 text-xs font-semibold text-primary">
                      Varsayılan
                    </span>
                  )}
                  {address.latitude != null && address.longitude != null && (
                    <span className="inline-flex items-center gap-1 text-xs text-muted-foreground">
                      <MapPin aria-hidden="true" className="size-3.5" />
                      Haritada işaretli
                    </span>
                  )}
                </p>
                <p className="mt-0.5 text-sm text-muted-foreground">
                  {address.line1} · {address.district} / {address.city}
                </p>
                {address.note && (
                  <p className="mt-0.5 text-sm text-muted-foreground">{address.note}</p>
                )}
              </div>

              <div className="flex shrink-0 gap-1">
                {!address.is_default && (
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    disabled={pending}
                    onClick={() => dispatch(defaultAction, address.id)}
                  >
                    <Star aria-hidden="true" />
                    Varsayılan yap
                  </Button>
                )}
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  disabled={pending}
                  onClick={() => openEdit(address)}
                >
                  <Pencil aria-hidden="true" />
                  Düzenle
                </Button>
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  disabled={pending}
                  className="text-danger hover:text-danger"
                  onClick={() => {
                    // Silme geri alınamaz ve kayıtlı adres, geçmiş
                    // siparişlerin gittiği yerden bağımsız (sipariş adresi
                    // kopyalanıyor) — yine de tek tıkla gitmemeli.
                    if (window.confirm('Bu adres silinecek. Emin misiniz?')) {
                      dispatch(deleteAction, address.id);
                    }
                  }}
                >
                  <Trash2 aria-hidden="true" />
                  Sil
                </Button>
              </div>
            </li>
          ))}
        </ul>
      )}

      {!formOpen && (
        <Button type="button" size="lg" onClick={openNew}>
          Yeni adres ekle
        </Button>
      )}

      {formOpen && (
        <form onSubmit={submit} noValidate className="rounded-xl border bg-card p-5 sm:p-6">
          <h2 className="text-lg font-semibold">{editing ? 'Adresi düzenle' : 'Yeni adres'}</h2>

          {editing && <input type="hidden" name="id" value={editing.id} />}

          <div className="mt-4 space-y-4">
            <FormField
              id="label"
              label="Etiket"
              hint='İsteğe bağlı. "Ofis", "Şantiye" gibi.'
              error={saveState.fieldErrors.label}
            >
              {({ id, describedBy, invalid }) => (
                <input
                  id={id}
                  name="label"
                  type="text"
                  maxLength={48}
                  defaultValue={editing?.label ?? ''}
                  aria-invalid={invalid}
                  aria-describedby={describedBy}
                  className={inputClass(invalid)}
                />
              )}
            </FormField>

            <FormField id="line1" label="Adres" error={saveState.fieldErrors.line1}>
              {({ id, describedBy, invalid }) => (
                <input
                  id={id}
                  name="line1"
                  type="text"
                  maxLength={255}
                  defaultValue={editing?.line1 ?? ''}
                  aria-invalid={invalid}
                  aria-describedby={describedBy}
                  className={inputClass(invalid)}
                />
              )}
            </FormField>

            <div className="grid gap-4 sm:grid-cols-2">
              <FormField id="district" label="İlçe" error={saveState.fieldErrors.district}>
                {({ id, describedBy, invalid }) => (
                  <select
                    id={id}
                    name="district"
                    defaultValue={editing?.district ?? SERVICE_AREA_DISTRICTS[0]}
                    aria-invalid={invalid}
                    aria-describedby={describedBy}
                    className={inputClass(invalid)}
                  >
                    {SERVICE_AREA_DISTRICTS.map((district) => (
                      <option key={district} value={district}>
                        {district}
                      </option>
                    ))}
                  </select>
                )}
              </FormField>

              <FormField id="city" label="İl" error={saveState.fieldErrors.city}>
                {({ id, describedBy, invalid }) => (
                  <input
                    id={id}
                    name="city"
                    type="text"
                    readOnly
                    defaultValue={editing?.city ?? SERVICE_AREA_CITY}
                    aria-invalid={invalid}
                    aria-describedby={describedBy}
                    className={cn(inputClass(invalid), 'bg-muted')}
                  />
                )}
              </FormField>
            </div>

            <FormField
              id="note"
              label="Adres tarifi"
              hint="İsteğe bağlı. Kat, daire, zili çalmayın gibi notlar."
              error={saveState.fieldErrors.note}
            >
              {({ id, describedBy, invalid }) => (
                <input
                  id={id}
                  name="note"
                  type="text"
                  maxLength={255}
                  defaultValue={editing?.note ?? ''}
                  aria-invalid={invalid}
                  aria-describedby={describedBy}
                  className={inputClass(invalid)}
                />
              )}
            </FormField>

            <label className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                name="is_default"
                value="true"
                defaultChecked={editing?.is_default ?? addresses.length === 0}
                className="size-4 accent-brand-600"
              />
              Ödeme adımında bu adres önceden seçili gelsin
            </label>

            <div className="border-t pt-4">
              <p className="text-sm font-medium">Haritada işaretle (isteğe bağlı)</p>
              <p className="mt-0.5 text-xs text-muted-foreground">
                İşaretlerseniz kuryenin fişine harita QR&apos;ı basılır ve kurye adresi elle aramak
                zorunda kalmaz.
              </p>
              <MapPickerLazy value={pin} onChange={setPin} />
              {saveState.fieldErrors.latitude && (
                <p role="alert" className="mt-2 text-sm text-danger">
                  {saveState.fieldErrors.latitude}
                </p>
              )}
            </div>
          </div>

          <div className="mt-5 flex flex-wrap gap-2">
            <Button type="submit" size="lg" disabled={pending}>
              {pending ? 'Kaydediliyor…' : 'Kaydet'}
            </Button>
            <Button type="button" variant="outline" size="lg" onClick={() => setFormOpen(false)}>
              Vazgeç
            </Button>
          </div>
        </form>
      )}
    </div>
  );
}
