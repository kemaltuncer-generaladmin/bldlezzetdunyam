import { LoadingAnnouncement, ProductGridSkeleton } from '@/components/skeletons';

export default function MenuLoading() {
  return (
    <div className="mx-auto max-w-content px-4 py-8 sm:py-12">
      <LoadingAnnouncement label="Menü yükleniyor" />
      <div className="bld-skeleton h-9 w-64" aria-hidden="true" />
      <div className="bld-skeleton mt-3 h-4 w-full max-w-xl" aria-hidden="true" />
      <div className="mt-8">
        <ProductGridSkeleton count={6} />
      </div>
    </div>
  );
}
