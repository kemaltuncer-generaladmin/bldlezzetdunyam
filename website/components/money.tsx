import { formatPrice, formatPriceDelta } from '@/lib/format';
import { cn } from '@/lib/utils';

/**
 * Para gösterimi.
 *
 * ## Neden bileşen?
 *
 * `formatPrice(...)` yirmi küsur yerde satır içi çağrılıyordu ve her çağrı
 * BOYUTA, AĞIRLIĞA ve `tabular-nums`'a yeniden karar veriyordu: sepet toplamı
 * bir ekranda `text-2xl font-bold`, ötekinde `text-lg font-bold`, üçüncüsünde
 * hizalama sınıfı olmadan çıkıyordu. Sonuç, sabit genişlikte olmayan rakamlar
 * yüzünden satır satır kayan bir fiyat sütunuydu.
 *
 * Ölçeğe karar vermek tipografi sisteminin işi, çağıranın değil. Burada TEK
 * karar noktası var: `size`.
 *
 * `lib/format.ts`'e DOKUNULMADI — kuruş matematiği (tamsayı bölme, float yok)
 * orada doğru çalışıyor. Bu bileşen onu yalnızca sarmalıyor.
 *
 * ## Değişmezler
 *
 * * `tabular-nums` HER YERDE (bkz. `bld-money`).
 * * Para ASLA sarmalanmaz/kırpılmaz — `white-space: nowrap`.
 * * `₺` rakamlarla aynı boy ve renkte: tek metin düğümü, ayrı `<span>` yok.
 * * Tabloda sağa yaslama hizalamayı KULLANAN yerin kararı, burada değil.
 */

/**
 * Ölçek `app/globals.css` içindeki `--text-money-*` adımları.
 *
 * * `sm` (15/600) — satır içi ikincil tutar: birim fiyat, seçenek farkı.
 * * `md` (17/700) — sepet/sipariş satırının tutarı, kart fiyatı.
 * * `lg` (22/700) — özet kutusunun toplamı.
 * * `xl` (28/700) — ürün detayındaki tek büyük fiyat.
 */
export type MoneySize = 'sm' | 'md' | 'lg' | 'xl';

const SIZE_CLASS: Record<MoneySize, string> = {
  sm: 'text-money-sm',
  md: 'text-money-md',
  lg: 'text-money-lg',
  xl: 'text-money-xl',
};

/**
 * İŞARETLİ TUTAR RENKLERİ — anlam, matematik değil.
 *
 * Bir tutarın eksi olması onu otomatik olarak "iyi" ya da "kötü" yapmaz:
 * cari hesapta eksi bakiye ALACAKtır (iyi), sipariş farkında eksi tutar
 * İNDİRİMdir (yine iyi), borç ise artı bir sayıdır. Bu yüzden renk `kurus`un
 * işaretinden türetilmiyor, çağıran söylüyor.
 *
 * * `default` — miras alınan renk (kart başlığı, satır metni ne ise).
 * * `muted`   — pozitif fark (neutral600): "+40,00 ₺" seçenek farkı gibi.
 * * `credit`  — indirim/alacak (success700).
 * * `debit`   — borç (danger700).
 */
export type MoneyTone = 'default' | 'muted' | 'credit' | 'debit';

const TONE_CLASS: Record<MoneyTone, string> = {
  default: '',
  muted: 'text-muted-foreground',
  credit: 'text-success',
  debit: 'text-danger',
};

export function Money({
  kurus,
  size = 'md',
  tone,
  signed = false,
  was,
  className,
  ...props
}: {
  /** Tutar KURUŞ cinsinden tam sayı (`docs/openapi.yaml` §Değişmezler). */
  kurus: number;
  size?: MoneySize;
  tone?: MoneyTone;
  /**
   * `+40,00 ₺` / `-5,00 ₺` biçimi; sıfırda hiçbir şey basılmaz. Seçenek farkı
   * ve tutar değişikliği içindir. Varsayılan ton `muted`e kayar — pozitif fark
   * marka kılavuzunda neutral600.
   */
  signed?: boolean;
  /**
   * Bir önceki fiyat (kuruş). Verildiğinde ÜSTÜ ÇİZİLİ olarak ÖNCE basılır,
   * güncel fiyat ondan SONRA gelir — sıra bilinçli: göz önce eski değeri
   * görüp sonra yenisine iner, tersi "zam" gibi okunuyor.
   */
  was?: number;
} & Omit<React.ComponentProps<'span'>, 'children'>) {
  const text = signed ? formatPriceDelta(kurus) : formatPrice(kurus);

  // Sıfır fark hiçbir şey söylemez; boş bir `<span>` bırakmak yerine düzenden
  // tamamen çıkıyor (yoksa `gap` yüzünden görünmez bir boşluk kalıyordu).
  if (signed && text === '') return null;

  const resolvedTone = tone ?? (signed ? 'muted' : 'default');

  return (
    <span
      data-slot="money"
      className={cn('bld-money', SIZE_CLASS[size], TONE_CLASS[resolvedTone], className)}
      {...props}
    >
      {was !== undefined && was !== kurus && (
        <>
          {/*
            Üstü çizili fiyat neutral400. Marka kılavuzu "neutral400 metin
            değildir" diyor ve bu TEK istisna: geçersiz kılınmış bir fiyat
            okunması gereken bir değer değil, güncel fiyatın yanındaki
            bağlamdır — ve hemen ardından tam kontrastlı hâli geliyor.
          */}
          <s className="mr-1.5 font-normal text-neutral-400">{formatPrice(was)}</s>{' '}
        </>
      )}
      {text}
    </span>
  );
}
