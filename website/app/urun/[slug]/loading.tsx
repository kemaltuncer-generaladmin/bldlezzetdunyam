import { LoadingAnnouncement } from '@/components/skeletons';

export default function ProductLoading() {
  return (
    <div className="mx-auto max-w-content px-4 py-6 sm:py-10">
      <LoadingAnnouncement label="Ürün yükleniyor" />

      <div className="bld-skeleton h-4 w-64" aria-hidden="true" />

      <div className="mt-5 grid gap-8 lg:grid-cols-2" aria-hidden="true">
        <div className="bld-skeleton aspect-4/3 rounded-card" />
        <div className="space-y-3">
          <div className="bld-skeleton h-4 w-28" />
          <div className="bld-skeleton h-9 w-3/4" />
          <div className="bld-skeleton h-4 w-full" />
          <div className="bld-skeleton h-9 w-40" />
          <div className="bld-skeleton h-56 w-full rounded-card" />
        </div>
      </div>
    </div>
  );
}
