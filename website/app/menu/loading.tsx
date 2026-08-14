import { LoadingAnnouncement } from '@/components/skeletons';
import { Skeleton } from '@/components/ui/skeleton';

/**
 * `app/menu/page.tsx` iskeleti — kutu sayısı ve yükseklikleri gerçek
 * düzenden ölçüldü: gün seçici (şerit + ay takvimi başlığı), paket kartı
 * (16:9 görsel + metin sütunu), üç kalem satırı (96 px kare görsel).
 * Yaklaşık bir iskelet, içerik gelince sayfayı zıplatıyor.
 */
export default function MenuLoading() {
  return (
    <>
      <LoadingAnnouncement label="Günün menüsü yükleniyor" />

      <div className="border-b bg-neutral-950">
        <div className="mx-auto max-w-content px-4 py-10 sm:px-6 sm:py-14" aria-hidden="true">
          <Skeleton className="h-4 w-24 bg-white/10" />
          <Skeleton className="mt-3 h-10 w-72 bg-white/10" />
          <Skeleton className="mt-4 h-6 w-full max-w-2xl bg-white/10" />
          <Skeleton className="mt-6 h-6 w-80 bg-white/10" />
        </div>
      </div>

      <div className="mx-auto max-w-content px-4 pt-6 pb-16 sm:pt-8">
        <div className="grid gap-8 lg:grid-cols-[minmax(0,1fr)_18rem]">
          <div className="min-w-0 space-y-8" aria-hidden="true">
            {/* Gün seçici: başlık + on dört gün hücresi. */}
            <div className="rounded-md bg-card p-4 shadow-card dark:shadow-none dark:inset-ring dark:inset-ring-white/5">
              <Skeleton className="h-7 w-48" />
              <div className="mt-3 flex gap-2 overflow-hidden">
                {Array.from({ length: 8 }, (_, index) => (
                  <Skeleton key={index} className="h-20 w-16 shrink-0 rounded-sm" />
                ))}
              </div>
              <Skeleton className="mt-3 h-6 w-32" />
            </div>

            {/* Paket kartı. */}
            <div className="overflow-hidden rounded-md bg-card shadow-card dark:shadow-none dark:inset-ring dark:inset-ring-white/5">
              <div className="grid lg:grid-cols-2">
                <Skeleton className="aspect-16/9 rounded-none lg:h-full" />
                <div className="space-y-3 p-5 sm:p-7">
                  <Skeleton className="h-4 w-28" />
                  <Skeleton className="h-8 w-3/4" />
                  <Skeleton className="h-4 w-40" />
                  <Skeleton className="h-5 w-full" />
                  <Skeleton className="h-5 w-5/6" />
                  <Skeleton className="mt-4 h-9 w-40" />
                  <Skeleton className="mt-2 h-11 w-full rounded-sm" />
                </div>
              </div>
            </div>

            {/* Kalemler. */}
            <div className="space-y-3">
              <Skeleton className="h-7 w-64" />
              {Array.from({ length: 3 }, (_, index) => (
                <div
                  key={index}
                  className="flex gap-4 rounded-md bg-card p-4 shadow-card dark:shadow-none dark:inset-ring dark:inset-ring-white/5"
                >
                  <Skeleton className="size-20 shrink-0 rounded-sm sm:size-24" />
                  <div className="w-full space-y-2">
                    <Skeleton className="h-6 w-2/5" />
                    <Skeleton className="h-4 w-4/5" />
                    <Skeleton className="h-9 w-40 rounded-sm" />
                  </div>
                </div>
              ))}
            </div>
          </div>

          <Skeleton className="hidden h-64 rounded-md lg:block" aria-hidden="true" />
        </div>
      </div>
    </>
  );
}
