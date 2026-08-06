import {
  LoadingAnnouncement,
  MenuToolbarSkeleton,
  ProductGridSkeleton,
} from '@/components/skeletons';

export default function MenuLoading() {
  return (
    <>
      <LoadingAnnouncement label="Menü yükleniyor" />

      <div className="border-b border-neutral-200 bg-linear-to-b from-brand-50 to-neutral-50">
        <div className="mx-auto max-w-content px-4 py-8 sm:py-10" aria-hidden="true">
          <div className="h-4 w-32 bld-skeleton" />
          <div className="mt-3 h-9 w-64 bld-skeleton" />
          <div className="mt-3 h-4 w-full max-w-xl bld-skeleton" />
          <div className="mt-5 flex flex-wrap gap-2">
            {Array.from({ length: 4 }, (_, index) => (
              <div key={index} className="h-8 w-36 bld-skeleton rounded-full" />
            ))}
          </div>
        </div>
      </div>

      <div className="mx-auto max-w-content px-4 pt-6 pb-16 sm:pt-8">
        <div className="grid gap-8 lg:grid-cols-[minmax(0,1fr)_18rem]">
          <div>
            <MenuToolbarSkeleton />
            <div className="mt-8 space-y-4">
              <div className="h-7 w-40 bld-skeleton" aria-hidden="true" />
              <ProductGridSkeleton count={6} />
            </div>
          </div>
          <div className="hidden h-64 bld-skeleton lg:block" aria-hidden="true" />
        </div>
      </div>
    </>
  );
}
