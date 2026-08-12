'use client';

import { useActionState, useState, useTransition } from 'react';
import { CalendarOff, Pause, Play, X } from 'lucide-react';
import {
  cancelSubscriptionAction,
  pauseSubscriptionAction,
  resumeSubscriptionAction,
  subscriptionExceptionAction,
} from '@/app/actions/subscriptions';
import { IDLE_SUBSCRIPTION_STATE } from '@/lib/action-state';
import { Button } from '@/components/ui/button';
import { formatPrice } from '@/lib/format';
import { cn } from '@/lib/utils';
import type { Subscription } from '@/lib/api/types';

const DAY_NAMES = ['', 'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'] as const;

const STATUS_LABELS: Record<Subscription['status'], { text: string; className: string }> = {
  pending: { text: 'Fiyat bekleniyor', className: 'bg-info/10 text-info' },
  active: { text: 'Aktif', className: 'bg-success/10 text-success' },
  paused: { text: 'Duraklatıldı', className: 'bg-warning/10 text-warning' },
  cancelled: { text: 'İptal edildi', className: 'bg-muted text-muted-foreground' },
};

/**
 * Abonelik kartı ve self-servis eylemleri — W-13.
 *
 * DÖRT AYRI `useActionState` var, tek bir "eylem" formu yok. Tek forma
 * `action` alanıyla dallanmak, yıkıcı bir işlemi (iptal) bir dize
 * karşılaştırmasına bağlamak olurdu; yanlış değer iptalle duraklatmayı
 * yer değiştirebilirdi.
 *
 * İPTAL GERİ ALINAMAZ ve `confirm` ile soruluyor. Duraklatma sorulmuyor:
 * geri alınabilir ve sık kullanılıyor (tatil, bayram) — her seferinde onay
 * istemek kullanışsız hâle getirirdi.
 */
export function SubscriptionCard({ subscription }: { subscription: Subscription }) {
  const [pauseState, pauseAction] = useActionState(
    pauseSubscriptionAction,
    IDLE_SUBSCRIPTION_STATE,
  );
  const [resumeState, resumeAction] = useActionState(
    resumeSubscriptionAction,
    IDLE_SUBSCRIPTION_STATE,
  );
  const [cancelState, cancelAction] = useActionState(
    cancelSubscriptionAction,
    IDLE_SUBSCRIPTION_STATE,
  );
  const [exceptionState, exceptionAction] = useActionState(
    subscriptionExceptionAction,
    IDLE_SUBSCRIPTION_STATE,
  );
  const [pending, startTransition] = useTransition();
  const [showDayForm, setShowDayForm] = useState(false);

  // En son çalışan eylemin mesajı gösteriliyor; dördü de `at` damgası
  // taşıdığı için en büyüğü en yeni.
  const latest = [pauseState, resumeState, cancelState, exceptionState].reduce((a, b) =>
    b.at > a.at ? b : a,
  );

  const status = STATUS_LABELS[subscription.status];
  const isCancelled = subscription.status === 'cancelled';

  const dispatch = (action: (fd: FormData) => void) => {
    const formData = new FormData();
    formData.set('subscription_id', String(subscription.id));
    startTransition(() => action(formData));
  };

  const submitException = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    formData.set('subscription_id', String(subscription.id));
    startTransition(() => exceptionAction(formData));
  };

  return (
    <article className="rounded-xl border bg-card p-5 shadow-sm sm:p-6">
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2 className="text-lg font-semibold">
            {subscription.default_quantity} porsiyon ·{' '}
            {subscription.delivery_type === 'delivery' ? 'Adrese gönderim' : 'Gel-al'}
          </h2>
          <p className="mt-1 text-sm text-muted-foreground">
            {formatDate(subscription.start_date)} –{' '}
            {subscription.end_date ? formatDate(subscription.end_date) : 'süresiz'}
            {subscription.delivery_time_from && ` · ${subscription.delivery_time_from}`}
          </p>
        </div>

        <span className={cn('rounded-full px-3 py-1 text-xs font-semibold', status.className)}>
          {status.text}
        </span>
      </header>

      <dl className="mt-4 grid gap-3 text-sm sm:grid-cols-3">
        <div>
          <dt className="text-muted-foreground">Servis günleri</dt>
          <dd className="mt-0.5 font-medium">
            {subscription.service_days.map((day) => DAY_NAMES[day]).join(', ') || '—'}
          </dd>
        </div>
        <div>
          <dt className="text-muted-foreground">Porsiyon fiyatı</dt>
          <dd className="mt-0.5 font-medium tabular-nums">
            {subscription.agreed_unit_price != null ? (
              formatPrice(subscription.agreed_unit_price)
            ) : (
              <span className="font-normal text-muted-foreground">Henüz belirlenmedi</span>
            )}
          </dd>
        </div>
        <div>
          <dt className="text-muted-foreground">Ödeme</dt>
          <dd className="mt-0.5 font-medium">
            {subscription.payment_mode === 'account' ? 'Cari hesap' : 'Aylık peşin'}
          </dd>
        </div>
      </dl>

      {subscription.lines.length > 0 && (
        <div className="mt-4">
          <p className="text-sm text-muted-foreground">Porsiyon içeriği</p>
          <ul className="mt-1 flex flex-wrap gap-2">
            {subscription.lines.map((line, index) => (
              <li
                key={`${line.menu_id ?? 'x'}-${index}`}
                className="rounded-md bg-muted px-2 py-1 text-sm"
              >
                {line.quantity} × {line.label ?? `#${line.menu_id}`}
              </li>
            ))}
          </ul>
        </div>
      )}

      {subscription.status === 'pending' && (
        <p className="mt-4 rounded-md bg-info/10 px-3 py-2 text-sm">
          Talebiniz alındı. Porsiyon fiyatını belirleyip aboneliği başlattığımızda size haber
          vereceğiz.
        </p>
      )}

      {latest.status === 'error' && latest.message && (
        <p role="alert" className="mt-4 rounded-md bg-danger/10 px-3 py-2 text-sm text-danger">
          {latest.message}
        </p>
      )}

      {/*
        BAŞARI DA SÖYLENİYOR. İlk yazışta yalnızca hata gösteriliyordu:
        "yarını atla" diyen kullanıcı kartın hiç değişmediğini görüp
        işlemin geçip geçmediğini anlayamıyordu — duraklatmada rozet
        değiştiği için fark edilmiyor, gün atlamada hiçbir iz kalmıyordu.
        E2E testi de tam bunu yakaladı.
      */}
      {latest.status === 'ok' && (
        <p role="status" className="mt-4 rounded-md bg-success/10 px-3 py-2 text-sm">
          Değişiklik kaydedildi.
        </p>
      )}

      {!isCancelled && (
        <div className="mt-5 flex flex-wrap gap-2 border-t pt-5">
          {subscription.status === 'active' && (
            <>
              <Button
                type="button"
                variant="outline"
                size="sm"
                disabled={pending}
                onClick={() => setShowDayForm((open) => !open)}
              >
                <CalendarOff aria-hidden="true" />
                Gün atla / adet değiştir
              </Button>

              <Button
                type="button"
                variant="outline"
                size="sm"
                disabled={pending}
                onClick={() => dispatch(pauseAction)}
              >
                <Pause aria-hidden="true" />
                Duraklat
              </Button>
            </>
          )}

          {subscription.status === 'paused' && (
            <Button
              type="button"
              size="sm"
              disabled={pending}
              onClick={() => dispatch(resumeAction)}
            >
              <Play aria-hidden="true" />
              Devam ettir
            </Button>
          )}

          <Button
            type="button"
            variant="ghost"
            size="sm"
            disabled={pending}
            className="text-danger hover:text-danger"
            onClick={() => {
              // İptal geri alınamaz: yeni abonelik açmak yeni bir talep ve
              // yeni bir fiyatlandırma demek.
              if (
                window.confirm('Abonelik iptal edilecek. Bu işlem geri alınamaz. Emin misiniz?')
              ) {
                dispatch(cancelAction);
              }
            }}
          >
            <X aria-hidden="true" />
            İptal et
          </Button>
        </div>
      )}

      {showDayForm && subscription.status === 'active' && (
        <form onSubmit={submitException} className="mt-4 rounded-lg border bg-muted/40 p-4">
          <p className="text-sm font-medium">Tek günlük değişiklik</p>
          <p className="mt-1 text-xs text-muted-foreground">
            Bu değişiklik yalnızca seçtiğiniz günü etkiler; aboneliğin kuralı değişmez. Girdiğiniz
            porsiyon sayısı o günün <strong>toplamıdır</strong>, ek değildir.
          </p>

          <div className="mt-3 grid gap-3 sm:grid-cols-[1fr_auto_auto]">
            <div>
              <label htmlFor={`gun-${subscription.id}`} className="mb-1 block text-sm">
                Gün
              </label>
              <input
                id={`gun-${subscription.id}`}
                name="service_date"
                type="date"
                required
                className="h-11 w-full rounded-md border bg-background px-3"
              />
            </div>

            <div>
              <label htmlFor={`adet-${subscription.id}`} className="mb-1 block text-sm">
                Porsiyon
              </label>
              <input
                id={`adet-${subscription.id}`}
                name="quantity_override"
                type="number"
                min={1}
                max={9999}
                defaultValue={subscription.default_quantity}
                className="h-11 w-28 rounded-md border bg-background px-3 tabular-nums"
              />
            </div>

            <div className="flex items-end gap-2">
              <Button type="submit" size="lg" disabled={pending}>
                Kaydet
              </Button>
              <Button
                type="submit"
                name="skip"
                value="true"
                variant="outline"
                size="lg"
                disabled={pending}
              >
                O gün istemiyorum
              </Button>
            </div>
          </div>
        </form>
      )}
    </article>
  );
}

function formatDate(iso: string): string {
  const [year, month, day] = iso.split('-');
  return day && month && year ? `${day}.${month}.${year}` : iso;
}
