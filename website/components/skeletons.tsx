/** Yükleniyor durumları skeleton ile gösterilir (`docs/06` §5). */

export function ProductCardSkeleton() {
  return (
    <div className="bld-card overflow-hidden" aria-hidden="true">
      <div className="bld-skeleton aspect-[3/2] rounded-none" />
      <div className="space-y-2 p-4">
        <div className="bld-skeleton h-5 w-2/3" />
        <div className="bld-skeleton h-4 w-full" />
        <div className="bld-skeleton h-6 w-24" />
        <div className="bld-skeleton h-11 w-full" />
      </div>
    </div>
  );
}

export function ProductGridSkeleton({ count = 6 }: { count?: number }) {
  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      {Array.from({ length: count }, (_, index) => (
        <ProductCardSkeleton key={index} />
      ))}
    </div>
  );
}

export function ListSkeleton({ rows = 4 }: { rows?: number }) {
  return (
    <div className="space-y-3" aria-hidden="true">
      {Array.from({ length: rows }, (_, index) => (
        <div key={index} className="bld-card flex items-center justify-between gap-4 p-4">
          <div className="w-full space-y-2">
            <div className="bld-skeleton h-5 w-32" />
            <div className="bld-skeleton h-4 w-48" />
          </div>
          <div className="bld-skeleton h-6 w-20 shrink-0" />
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
