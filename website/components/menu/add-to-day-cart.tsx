'use client';

import { useActionState, useEffect, useRef, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { Check, TriangleAlert } from 'lucide-react';
import { addToCartAction } from '@/app/actions/cart';
import { Button } from '@/components/ui/button';
import { IDLE_CART_STATE } from '@/lib/action-state';
import { announceCartChanged } from '@/lib/cart-events';
import { formatDayMonth, type BusinessDate } from '@/lib/business-date';
import { cn } from '@/lib/utils';

type Props = {
  /** Ürün ya da menü paketi (`DailyMenu.package.menu_id`). */
  menuId: number;
  /** Satırın bağlanacağı servis günü. Sepetin günü bundan doğar. */
  serviceDate: BusinessDate;
  label?: string;
  disabled: boolean;
  /**
   * ZORUNLU. Kapalı butonun sebebi butonun KENDİ ETİKETİ oluyor ("Tükendi",
   * "Sipariş kapalı"); kullanıcı neden ekleyemediğini okumadan anlayamaz.
   */
  disabledReason: string;
  variant?: 'default' | 'secondary' | 'outline';
  size?: 'default' | 'sm' | 'lg';
  className?: string;
  /** Seçenek alanları (yalnız ürün satırında; paketin seçeneği olmaz). */
  children?: React.ReactNode;
  /** Sonucu formun altında göster. Kapalı bırakılırsa yalnız ekran okuyucuya. */
  showMessage?: boolean;
};

/**
 * GÜNÜN MENÜSÜNDEN sepete ekleme (B-19).
 *
 * ## Neden `AddToCartForm`'un yerine yeni bir bileşen?
 *
 * Eski form yalnızca `menu_id` taşıyordu; sepet artık BİR GÜNE bağlı ve gün
 * her istekte gitmek zorunda. Daha önemlisi bu bileşen ÜÇÜNCÜ BİR SONUCU
 * karşılıyor: gün çakışması. Sepette 20 Ağustos'un menüsü varken 21
 * Ağustos'tan ekleme yapmak ne başarı ne hata — bir SORU. Karışık günlü
 * sepet mutfağın karşılayamayacağı bir sipariştir, sessizce sıfırlamak da
 * müşterinin hazırladığı sepeti haber vermeden silmek olurdu.
 *
 * Onay verildiğinde form AYNI alanlarla ikinci kez gönderiliyor, yanına
 * `confirm_reset` bayrağı ekleniyor — sunucu eylemi tek giriş noktası
 * olarak kalıyor, "sıfırla" diye ayrı bir uç açılmıyor.
 */
export function AddToDayCart({
  menuId,
  serviceDate,
  label = 'Sepete ekle',
  disabled,
  disabledReason,
  variant = 'default',
  size = 'default',
  className,
  children,
  showMessage = false,
}: Props) {
  const router = useRouter();
  const formRef = useRef<HTMLFormElement>(null);
  const [state, formAction, pending] = useActionState(addToCartAction, IDLE_CART_STATE);
  const [confirming, startConfirm] = useTransition();
  const lastHandled = useRef(0);

  useEffect(() => {
    if (state.at === 0 || state.at === lastHandled.current) return;
    lastHandled.current = state.at;
    if (state.status === 'ok') {
      announceCartChanged();
      // Sunucu bileşenleri sepet rozetini ve gün başlığını yeniden çizsin.
      router.refresh();
    }
  }, [state, router]);

  /** Onay: aynı form verisi + `confirm_reset`. */
  const confirmReset = () => {
    const form = formRef.current;
    if (!form) return;
    const data = new FormData(form);
    data.set('confirm_reset', '1');
    startConfirm(() => formAction(data));
  };

  const busy = pending || confirming;
  const conflict = state.status === 'conflict';

  return (
    <div className={cn('space-y-3', className)}>
      <form ref={formRef} action={formAction} className="space-y-3">
        <input type="hidden" name="menu_id" value={menuId} />
        <input type="hidden" name="service_date" value={serviceDate} />
        {children}

        <Button
          type="submit"
          variant={variant}
          size={size}
          className="w-full"
          disabled={disabled || busy}
          disabledReason={busy ? 'Sepete ekleniyor.' : disabledReason}
        >
          {busy ? 'Ekleniyor…' : disabled ? disabledReason : label}
        </Button>
      </form>

      {/*
        Durum HER ZAMAN duyuruluyor, görsel mesaj kapalı olsa bile: menüde
        onlarca kart var ve hangisinin eklendiğini yalnızca renk değişimiyle
        bilmek ekran okuyucu kullanıcısı için mümkün değil.
      */}
      <p aria-live="polite" className="sr-only">
        {state.message ?? ''}
      </p>

      {conflict && (
        <div
          role="alert"
          className="rounded-sm bg-warning-surface p-3 text-body-sm text-warning-foreground"
        >
          <p className="flex items-start gap-2">
            <TriangleAlert
              aria-hidden="true"
              strokeWidth={1.75}
              className="mt-0.5 size-4 shrink-0"
            />
            <span>
              {state.message} {formatDayMonth(serviceDate)} menüsüne geçmek için sepetiniz
              boşaltılacak.
            </span>
          </p>
          <div className="mt-3 flex flex-wrap gap-2">
            <Button
              type="button"
              size="sm"
              onClick={confirmReset}
              disabled={busy}
              disabledReason="Sepet güncelleniyor."
            >
              Sepeti sıfırla ve ekle
            </Button>
            <Button asChild size="sm" variant="outline">
              {/* Vazgeçen kullanıcı sepetine bakmak isteyecek. */}
              <a href="/sepet">Sepetime bak</a>
            </Button>
          </div>
        </div>
      )}

      {showMessage && !conflict && state.message && (
        <p
          role={state.status === 'error' ? 'alert' : 'status'}
          className={cn(
            'flex items-start gap-2 rounded-sm px-3 py-2 text-body-sm',
            state.status === 'error'
              ? 'bg-danger-surface text-danger-foreground'
              : 'bg-success-surface text-success-foreground',
          )}
        >
          {state.status === 'ok' && (
            <Check aria-hidden="true" strokeWidth={1.75} className="mt-0.5 size-4 shrink-0" />
          )}
          {state.message}
        </p>
      )}
    </div>
  );
}
