import { ListSkeleton, LoadingAnnouncement } from '@/components/skeletons';

export default function CartLoading() {
  return (
    <div className="mx-auto max-w-content px-4 py-8 sm:py-12">
      <LoadingAnnouncement label="Sepetiniz yükleniyor" />
      <div className="bld-skeleton h-9 w-40" aria-hidden="true" />
      <div className="mt-8 grid gap-8 lg:grid-cols-[1fr_20rem]">
        <ListSkeleton rows={3} />
        <div className="bld-skeleton h-64 w-full" aria-hidden="true" />
      </div>
    </div>
  );
}
