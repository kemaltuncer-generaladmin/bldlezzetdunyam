'use client';

import { useActionState, useEffect, useRef, useTransition } from 'react';
import { Check, TriangleAlert } from 'lucide-react';
import { addToCartAction } from '@/app/actions/cart';
import { Button } from '@/components/ui/button';
import { IDLE_CART_STATE } from '@/lib/action-state';
import { announceCartChanged } from '@/lib/cart-events';
import { formatDayMonth, type BusinessDate } from '@/lib/business-date';
import { DEFAULT_LOW_THRESHOLD } from '@/lib/stock-policy';
import { cn } from '@/lib/utils';

type Props = {
  /** Ürün ya da menü paketi (`DailyMenu.package.menu_id`). */
  menuId: number;
  /** Satırın bağlanacağı servis günü. Sepetin günü bundan doğar. */
  serviceDate: BusinessDate;
  label?: string;
  /**
   * Sepete daha kaç tane eklenebilir (`lib/stock-policy.ts` → `maxAddable`).
   * `0` ise bu kalem o gün için tükenmiştir.
   *
   * Sayı SUNUCUDA hesaplanıp geçiliyor: müşterinin sepetinde o gün için duran
   * adet ile günün ve kalemin tavanı birlikte gerekiyor ve ikisi de burada
   * yok. Bileşenin kendi hesabını yapması, aynı aritmetiğin dördüncü bir
   * kopyasını doğururdu.
   */
  maxAddable: number;
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
  maxAddable,
  disabled,
  disabledReason,
  variant = 'default',
  size = 'default',
  className,
  children,
  showMessage = false,
}: Props) {
  const formRef = useRef<HTMLFormElement>(null);
  const [state, formAction, pending] = useActionState(addToCartAction, IDLE_CART_STATE);
  const [confirming, startConfirm] = useTransition();
  const lastHandled = useRef(0);

  /*
   * `router.refresh()` KALDIRILDI — sayfayı ikinci kez çizdiriyordu.
   *
   * Sunucu eylemi `revalidatePath` çağırıyor; Next.js bunu gördüğünde eylemin
   * YANITINA mevcut rotanın yeniden çizilmiş RSC yükünü koyuyor ve istemci
   * router önbelleğini düşürüyor. Yani ekrandaki kalan porsiyon sayısı ve gün
   * başlığı zaten tazeleniyordu. Üstüne `router.refresh()` çağırmak, aynı
   * sayfanın SUNUCUDA ikinci kez üretilmesi demekti: `/menu` için vitrin,
   * günün menüsü ve takvim uçlarına üç istek daha. Tek bir tıklamada iki tam
   * render, iki kat veritabanı işi.
   *
   * Duyuru (`announceCartChanged`) duruyor: o ağ isteği değil, sepet
   * göstergelerine "çerezi tekrar oku" sinyali.
   */
  useEffect(() => {
    if (state.at === 0 || state.at === lastHandled.current) return;
    lastHandled.current = state.at;

    // Rozet yalnız sepet gerçekten değiştiyse duyuruluyor: tavana takılıp
    // hiçbir şey eklenemeyen istekte "güncellendi" demek yalan olur.
    if (state.status === 'limit' ? state.addedQuantity > 0 : state.status === 'ok') {
      announceCartChanged();
    }
  }, [state]);

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
  const limited = state.status === 'limit';

  /*
   * Negatif bir tavan "eksi iki eklenebilir" demek değil, "artık eklenemez"
   * demektir: yönetici porsiyon sayısını sepet doldurulduktan sonra indirmiş
   * olabilir (`lib/stock-policy.ts` aynı yuvarlamayı yapıyor).
   */
  const remaining = Math.max(0, maxAddable);
  const soldOutForCart = remaining === 0;
  const blocked = disabled || soldOutForCart;

  /*
   * Kapalı butonun sebebi ZORUNLU ve sıra bağlayıcı: gün kapalıysa stok
   * mesajı yanıltıcı olur ("tükendi" diyorsak müşteri yarın bekler, oysa
   * sorun kesim saati). Çağıranın sebebi her zaman kazanır.
   */
  const reason = disabled ? disabledReason : 'Bugünlük tükendi';

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
          disabled={blocked || busy}
          disabledReason={busy ? 'Sepete ekleniyor.' : reason}
        >
          {busy ? 'Ekleniyor…' : blocked ? reason : label}
        </Button>
      </form>

      {/*
        Kalan adet SAYIYLA söyleniyor ama yalnız azaldığında: her kartın
        altında "en fazla 40 adet" yazmak bilgi değil gürültü olurdu. Eşik
        stok bandıyla aynı (`DEFAULT_LOW_THRESHOLD`) — rozet "son 3 porsiyon"
        derken düğmenin altında başka bir sınır yazması müşteriyi ikilemde
        bırakırdı.

        Cümle SEBEP SÖYLEMİYOR ("kontenjan" demiyor): sayı üç tavanın en
        darından geliyor ve satır başı azami adede dayanmış bir müşteriye
        "kontenjan doldu" demek yanlış olurdu.
      */}
      {!blocked && remaining <= DEFAULT_LOW_THRESHOLD && (
        <p className="text-body-sm text-muted-foreground">
          En fazla {remaining} adet daha ekleyebilirsiniz.
        </p>
      )}

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

      {/*
        Tavan mesajı `showMessage` bayrağına BAKMIYOR, çakışma uyarısı gibi
        her zaman görünüyor. Kalem kartlarında görsel mesaj kapalı çünkü
        "eklendi" bilgisini başlıktaki rozet zaten veriyor; "üç istediniz,
        iki eklendi" ise rozette görünmez ve söylenmezse müşteri farkı ancak
        sepette görür.
      */}
      {limited && (
        <p
          role="status"
          className="flex items-start gap-2 rounded-sm bg-warning-surface px-3 py-2 text-body-sm text-warning-foreground"
        >
          <TriangleAlert aria-hidden="true" strokeWidth={1.75} className="mt-0.5 size-4 shrink-0" />
          {state.message}
        </p>
      )}

      {showMessage && !conflict && !limited && state.message && (
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
