'use client';

import { useActionState, useEffect, useRef, useState, useTransition } from 'react';
import { Check, Minus, Plus, TriangleAlert } from 'lucide-react';
import { addToCartAction } from '@/app/actions/cart';
import { Button } from '@/components/ui/button';
import { IDLE_CART_STATE } from '@/lib/action-state';
import { announceCartChanged } from '@/lib/cart-events';
import { formatDayMonth, type BusinessDate } from '@/lib/business-date';
import { DEFAULT_LOW_THRESHOLD } from '@/lib/stock-policy';
import { cn } from '@/lib/utils';

/**
 * Bir sepet satırının azami adedi — `lib/cart.ts` içindeki `MAX_QUANTITY` ile
 * aynı sayı. Orada dışa aktarılmıyor ve `cart-line-controls.tsx` de aynı
 * sabiti kendi içinde taşıyor; ikisinden birini değiştiren, ötekini de
 * değiştirmek zorunda.
 */
const LINE_MAX_QUANTITY = 99;

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
   * KAÇ PORSİYON — sepete eklemeden ÖNCE seçiliyor.
   *
   * Sunucu eylemi `quantity` alanını zaten okuyordu (`app/actions/cart.ts`)
   * ve gelmediğinde 1 uyguluyordu; eksik olan yalnızca alanı gönderen bir
   * arayüzdü. On kişilik sipariş veren müşteri "Sepete ekle"ye on kez
   * basıyor, her basış bir sunucu turu ediyordu.
   *
   * SEPETTEKİ SAYAÇTAN AYRI BİR ŞEY: oradaki (`cart-line-controls.tsx`)
   * MUTLAK hedefi yollar ve sunucuya her tıklamada gider. Burası daha
   * eklenmemiş bir satırın adedi, yani yalnız yerel bir sayı — ağa çıkmadan
   * değişir ve tek istekte gönderilir.
   */
  const [quantity, setQuantity] = useState(1);

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
      /*
       * ADET BİRE DÖNÜYOR. Dönmeseydi, üç porsiyon ekleyen müşterinin bir
       * sonraki kartında da "3" yazılı dururdu ve ikinci ekleme sessizce üç
       * porsiyon olurdu — seçim bir kere yapılıp unutulan bir şeydir.
       */
      setQuantity(1);
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
   * Sayacın tavanı: o gün için EKLENEBİLİR KALAN ile sepet satırının azami
   * adedi arasından dar olanı.
   *
   * Kalanla sınırlamak bilinçli: müşteriye beş seçtirip sunucuda ikiye
   * kırpmak, "beş istedim iki geldi" cümlesini kaçınılmaz kılardı. Sunucu
   * kırpmayı yine de yapıyor (`app/actions/cart.ts`) — ekran son sözü değil,
   * ilk kapıyı tutuyor: stok bu sekmede dururken de değişebilir.
   *
   * `blocked` durumunda `remaining` sıfır olabilir; sayaç o hâlde hiç
   * çizilmiyor ama alt sınır yine de 1 kalmalı ki hesap `0`a düşmesin.
   */
  const maxSelectable = Math.max(1, Math.min(remaining, LINE_MAX_QUANTITY));

  /*
   * Tavan daralırsa seçili adet ONUNLA BİRLİKTE iner: yönetici porsiyon
   * sayısını düşürdüğünde ekranda "5" yazılı kalması, basıldığında kırpılan
   * bir düğme bırakırdı.
   */
  useEffect(() => {
    setQuantity((current) => Math.min(current, maxSelectable));
  }, [maxSelectable]);

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
        <input type="hidden" name="quantity" value={quantity} />

        {/*
          SAYAÇ VE DÜĞME AYNI SATIRDA, dar ekranda alt alta. Sayaç sabit
          genişlikte, düğme kalanı alıyor: "Sepete ekle" birincil eylem
          olmaya devam etmeli, adet seçimi onun yanında duran bir ayar.

          Sayaç KAPALI GÜNDE ÇİZİLMİYOR: tükenmiş bir kalemin adedini
          seçtirmek, sonu olmayan bir etkileşim olurdu.
        */}
        <div className="flex flex-wrap items-center gap-2">
          {!blocked && (
            <div
              className="flex items-center rounded-full border border-input"
              role="group"
              aria-label="Porsiyon adedi"
            >
              <button
                type="button"
                onClick={() => setQuantity((current) => Math.max(1, current - 1))}
                disabled={busy || quantity <= 1}
                aria-label="Adedi azalt"
                className="grid size-11 cursor-pointer place-items-center rounded-full text-foreground transition-colors duration-(--duration-fast) hover:bg-muted disabled:cursor-not-allowed disabled:text-muted-foreground"
              >
                <Minus strokeWidth={1.75} aria-hidden="true" className="size-4" />
              </button>

              {/*
                Sayı `aria-live`: ekran okuyucu kullanıcısı düğmeye bastığında
                değerin değiştiğini başka türlü duyamaz.
              */}
              <span
                aria-live="polite"
                data-testid="add-quantity"
                className="min-w-8 px-1 text-center text-label bld-money"
              >
                {quantity}
              </span>

              <button
                type="button"
                onClick={() => setQuantity((current) => Math.min(maxSelectable, current + 1))}
                disabled={busy || quantity >= maxSelectable}
                aria-label="Adedi artır"
                className="grid size-11 cursor-pointer place-items-center rounded-full text-foreground transition-colors duration-(--duration-fast) hover:bg-muted disabled:cursor-not-allowed disabled:text-muted-foreground"
              >
                <Plus strokeWidth={1.75} aria-hidden="true" className="size-4" />
              </button>
            </div>
          )}

          <Button
            type="submit"
            variant={variant}
            size={size}
            className="min-w-40 flex-1"
            disabled={blocked || busy}
            disabledReason={busy ? 'Sepete ekleniyor.' : reason}
          >
            {busy ? 'Ekleniyor…' : blocked ? reason : label}
          </Button>
        </div>
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
