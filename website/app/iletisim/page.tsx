import type { Metadata } from 'next';
import Link from 'next/link';
import { LegalNotice } from '@/components/legal-notice';

export const metadata: Metadata = {
  title: 'İletişim',
  description:
    'Benim Lezzet Dünyam ile iletişime geçin: sipariş, teklif ve kurumsal catering talepleriniz için.',
  alternates: { canonical: '/iletisim' },
};

export default function IletisimPage() {
  return (
    <div className="mx-auto max-w-3xl px-4 py-10 sm:py-14">
      <h1 className="text-3xl font-bold text-neutral-900">İletişim</h1>
      <p className="mt-3 text-sm leading-relaxed text-neutral-800">
        Kurumsal catering teklifleri, toplu sipariş talepleri ve mevcut siparişleriniz hakkındaki
        sorularınız için bize ulaşabilirsiniz.
      </p>

      <LegalNotice />

      <div className="mt-8 grid gap-4 sm:grid-cols-2">
        <div className="bld-card p-5">
          <h2 className="text-base font-semibold text-neutral-900">Sipariş vermek için</h2>
          <p className="mt-2 text-sm text-neutral-600">
            Menüden seçim yapıp sepetinizi oluşturun; sipariş birkaç adımda tamamlanır.
          </p>
          <Link href="/menu" className="bld-btn-primary mt-4">
            Menüyü aç
          </Link>
        </div>

        <div className="bld-card p-5">
          <h2 className="text-base font-semibold text-neutral-900">Mevcut siparişiniz</h2>
          <p className="mt-2 text-sm text-neutral-600">
            Siparişinizin durumunu hesabınızdan anlık olarak takip edebilirsiniz.
          </p>
          <Link
            href="/siparislerim"
            className="mt-4 inline-block rounded-lg border border-neutral-200 px-5 py-2.5 text-sm font-semibold text-neutral-900 hover:bg-neutral-100"
          >
            Siparişlerim
          </Link>
        </div>
      </div>
    </div>
  );
}
