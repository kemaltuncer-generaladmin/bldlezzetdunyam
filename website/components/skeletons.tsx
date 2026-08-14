import { Skeleton } from '@/components/ui/skeleton';

/**
 * Yükleme yer tutucuları.
 *
 * ## Kural: iskelet GERÇEK düzeni yansıtır
 *
 * Kutu SAYISI ve YÜKSEKLİKLERİ, yerini tutacağı bileşenden ölçülür. Yaklaşık
 * bir iskelet, içerik geldiğinde sayfayı zıplatıyor ve kullanıcı okumaya
 * başladığı satırı kaybediyor. Bu dosyadaki her ölçü bir bileşene dayanıyor
 * ve karşılığı yorumda yazılı — o bileşen değişirse burası da değişmeli.
 *
 * Spinner yok (400 ms altı buton içi hariç): dönen bir çark "bir şey oluyor"
 * der, iskelet "ŞU gelecek" der.
 */

/**
 * Sepet/sipariş satırı listesi.
 *
 * Satırın solunda 56 px'lik 1:1 görsel var (marka kılavuzu: sepet/sipariş
 * satırı görseli 56 px kare) — iskelette de o kare duruyor, yoksa içerik
 * gelince metin sağa kayıyor.
 */
export function ListSkeleton({ rows = 4 }: { rows?: number }) {
  return (
    <div className="space-y-3" aria-hidden="true">
      {Array.from({ length: rows }, (_, index) => (
        <div
          key={index}
          className="flex items-center gap-4 rounded-md bg-card p-4 shadow-card dark:shadow-none dark:inset-ring dark:inset-ring-white/5"
        >
          <Skeleton className="size-14 shrink-0 rounded-md" />
          <div className="w-full space-y-2">
            <Skeleton className="h-5 w-40" />
            <Skeleton className="h-4 w-56" />
          </div>
          <Skeleton className="h-6 w-20 shrink-0" />
        </div>
      ))}
    </div>
  );
}

/**
 * Yükleniyor duyurusu.
 *
 * İskelet `aria-hidden`: ekran okuyucuya on beş boş kutu okutmanın anlamı
 * yok. Durumu tek bir kibar satır duyuruyor (`role="status"` — kullanıcı
 * cümlesini bitirsin, sonra duyulsun).
 */
export function LoadingAnnouncement({ label = 'Yükleniyor' }: { label?: string }) {
  return (
    <p role="status" aria-live="polite" className="sr-only">
      {label}
    </p>
  );
}
