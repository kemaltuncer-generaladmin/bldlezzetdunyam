import type { Metadata } from 'next';
import { redirect } from 'next/navigation';
import { RegisterForm } from '@/components/auth/register-form';
import { safeInternalPath } from '@/lib/safe-redirect';
import { getCurrentCustomerSafe } from '@/lib/session';

export const metadata: Metadata = {
  title: 'Kayıt ol',
  description: 'Hesap oluşturun, catering siparişlerinizi tek yerden yönetin.',
  robots: { index: false, follow: true },
};

type SearchParams = { next?: string | string[] };

function firstValue(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

export default async function RegisterPage({
  searchParams,
}: {
  searchParams: Promise<SearchParams>;
}) {
  const params = await searchParams;
  const next = safeInternalPath(firstValue(params.next), '/');

  if (await getCurrentCustomerSafe()) redirect(next);

  return (
    <div className="bg-linear-to-b from-brand-50 to-neutral-50">
      <div className="mx-auto w-full max-w-lg px-4 py-10 sm:py-16">
        <h1 className="text-2xl font-bold">Hesap oluştur</h1>
        <p className="mt-2 text-sm text-neutral-600">
          Sipariş verebilmek ve siparişinizi anlık takip edebilmek için kısa bir kayıt yeterli.
        </p>

        <div className="mt-6 bld-card p-5 shadow-md sm:p-6">
          <RegisterForm next={next} />
        </div>
      </div>
    </div>
  );
}
