import { LoadingAnnouncement } from '@/components/skeletons';

export default function ProductLoading() {
  return (
    <div className="mx-auto max-w-content px-4 py-6 sm:py-10">
      <LoadingAnnouncement label="Ürün yükleniyor" />

      <div className="h-4 w-64 bld-skeleton" aria-hidden="true" />

      <div className="mt-5 grid gap-8 lg:grid-cols-2" aria-hidden="true">
        <div className="aspect-4/3 bld-skeleton rounded-card" />
        <div className="space-y-3">
          <div className="h-4 w-28 bld-skeleton" />
          <div className="h-9 w-3/4 bld-skeleton" />
          <div className="h-4 w-full bld-skeleton" />
          <div className="h-9 w-40 bld-skeleton" />
          <div className="h-56 w-full bld-skeleton rounded-card" />
        </div>
      </div>
    </div>
  );
}
