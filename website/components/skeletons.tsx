/** Yükleniyor durumları skeleton ile gösterilir (`docs/06` §5). */

export function ProductCardSkeleton() {
  return (
    <div className="overflow-hidden bld-card" aria-hidden="true">
      <div className="aspect-4/3 bld-skeleton rounded-none" />
      <div className="space-y-2 p-4">
        <div className="h-5 w-2/3 bld-skeleton" />
        <div className="h-4 w-full bld-skeleton" />
        <div className="h-6 w-24 bld-skeleton" />
        <div className="h-11 w-full bld-skeleton" />
      </div>
    </div>
  );
}

export function ProductGridSkeleton({ count = 6 }: { count?: number }) {
  return (
    <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
      {Array.from({ length: count }, (_, index) => (
        <ProductCardSkeleton key={index} />
      ))}
    </div>
  );
}

/** Arama kutusu, sıralama ve kategori çubuğunun yer tutucusu. */
export function MenuToolbarSkeleton() {
  return (
    <div aria-hidden="true">
      <div className="flex flex-col gap-3 sm:flex-row">
        <div className="h-12 flex-1 bld-skeleton" />
        <div className="h-12 w-full bld-skeleton sm:w-52" />
        <div className="h-12 w-32 bld-skeleton" />
      </div>
      <div className="mt-4 flex gap-2 overflow-hidden">
        {Array.from({ length: 4 }, (_, index) => (
          <div key={index} className="h-11 w-28 shrink-0 bld-skeleton rounded-full" />
        ))}
      </div>
    </div>
  );
}

export function ListSkeleton({ rows = 4 }: { rows?: number }) {
  return (
    <div className="space-y-3" aria-hidden="true">
      {Array.from({ length: rows }, (_, index) => (
        <div key={index} className="flex items-center justify-between gap-4 bld-card p-4">
          <div className="w-full space-y-2">
            <div className="h-5 w-32 bld-skeleton" />
            <div className="h-4 w-48 bld-skeleton" />
          </div>
          <div className="h-6 w-20 shrink-0 bld-skeleton" />
        </div>
      ))}
    </div>
  );
}

export function LoadingAnnouncement({ label = 'Yükleniyor' }: { label?: string }) {
  return (
    <p role="status" aria-live="polite" className="sr-only">
      {label}
    </p>
  );
}
