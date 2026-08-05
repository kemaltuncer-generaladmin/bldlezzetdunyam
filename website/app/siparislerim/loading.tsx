import { ListSkeleton, LoadingAnnouncement } from '@/components/skeletons';

export default function MyOrdersLoading() {
  return (
    <div className="mx-auto max-w-3xl px-4 py-8 sm:py-12">
      <LoadingAnnouncement label="Siparişleriniz yükleniyor" />
      <div className="bld-skeleton h-9 w-48" aria-hidden="true" />
      <div className="mt-6">
        <ListSkeleton rows={4} />
      </div>
    </div>
  );
}
