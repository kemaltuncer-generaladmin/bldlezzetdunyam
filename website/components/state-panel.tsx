import type { ReactNode } from 'react';
import { cn } from '@/lib/utils';

/**
 * Boş / hata / çevrimdışı panellerinin ORTAK GÖVDESİ.
 *
 * ## Neden tek bileşen?
 *
 * Üç durumun düzeni AYNI: 72 px daire + 28 px ikon + serif h3 başlık + gövde
 * mesajı + tek eylem. Ayrı ayrı yazıldıklarında üçü de kendi dolgusuna, kendi
 * başlık boyutuna ve kendi daire çapına karar veriyordu; aynı ekranda iki
 * tanesi arka arkaya çıktığında (boş liste + çevrimdışı uyarısı) sayfa iki
 * farklı ürüne benziyordu. Değişen yalnızca TON ve DUYURU ROLÜ.
 *
 * ## Mesaj genişliği 42ch
 *
 * Ölçü karakter cinsinden, piksel değil: kutu ne kadar genişlerse genişlesin
 * satır uzunluğu okunur aralıkta kalır. Piksel verilseydi büyük ekranda tek
 * satırlık 90 karakterlik bir metin çıkardı.
 *
 * ## `role` çağıran tarafından geliyor, burada sabit değil
 *
 * `role="alert"` ekran okuyucuyu KESER — bu yalnızca hata için doğru. Boş
 * liste bir hata değil (rol yok), çevrimdışı bilgisi ise kibar sırada
 * duyurulur (`role="status"`).
 */

/** Ton yalnızca DAİRENİN rengini değiştirir; başlık ve gövde her tonda aynı. */
export type StateTone = 'empty' | 'error' | 'offline';

/*
 * Zemin + ikon çiftleri `app/tokens.css`'te ÖLÇÜLEREK eşleştirildi ve KOYU
 * TEMA karşılıkları da orada tanımlı.
 *
 * Marka kılavuzu bu üçlüyü açık tema değerleriyle veriyor (brand50/brand600,
 * danger50/danger600, warning50/warning700). Buraya o hex'ler yazılsaydı
 * karanlıkta krem bir daire kalırdı; belirteç çifti aynı ilişkinin iki
 * temadaki karşılığını taşıyor.
 */
const TONE_CLASS: Record<StateTone, string> = {
  empty: 'bg-accent text-accent-foreground',
  error: 'bg-danger-surface text-danger-foreground',
  offline: 'bg-warning-surface text-warning-foreground',
};

export function StatePanel({
  tone,
  role,
  icon,
  title,
  message,
  action,
  className,
}: {
  tone: StateTone;
  /** `undefined` (boş), `'alert'` (hata) ya da `'status'` (çevrimdışı). */
  role?: 'alert' | 'status';
  /** Dekoratif ikon. Boyutu burada zorlanır — çağıran karar vermez. */
  icon?: ReactNode;
  title: string;
  message: string;
  /** Tek eylem. Ton başına görünümü çağıran seçer (hata → outline). */
  action?: ReactNode;
  className?: string;
}) {
  return (
    <div
      role={role}
      className={cn(
        'mx-auto flex max-w-lg flex-col items-center rounded-md bg-card px-6 py-12 text-center',
        'text-card-foreground shadow-card dark:shadow-none dark:inset-ring dark:inset-ring-white/5',
        className,
      )}
    >
      {icon && (
        <span
          aria-hidden="true"
          className={cn(
            // 72 px daire, 28 px ikon. İkonun boyutu çağıranın geçirdiği
            // sınıftan bağımsız olarak burada sabitleniyor: üç panelin
            // dairesi aynı, içindeki ikon farklı boyda olamaz.
            'grid size-18 place-items-center rounded-full [&>svg]:size-7',
            TONE_CLASS[tone],
          )}
        >
          {icon}
        </span>
      )}

      <h3 className={cn('font-display text-h3 font-semibold text-heading', icon && 'mt-5')}>
        {title}
      </h3>

      {/* 42ch: satır uzunluğu kutu genişliğinden bağımsız olarak okunur kalır. */}
      <p className="mt-2 max-w-[42ch] text-body text-pretty text-muted-foreground">{message}</p>

      {action && <div className="mt-6">{action}</div>}
    </div>
  );
}
