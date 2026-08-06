import type { Metadata } from 'next';
import { redirect } from 'next/navigation';
import { LoginForm } from '@/components/auth/login-form';
import { safeInternalPath } from '@/lib/safe-redirect';
import { getCurrentCustomerSafe } from '@/lib/session';

export const metadata: Metadata = {
  title: 'Giriş yap',
  description: 'Hesabınıza giriş yapın, siparişlerinizi takip edin.',
  robots: { index: false, follow: true },
};

type SearchParams = { next?: string | string[]; durum?: string | string[] };

function firstValue(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

export default async function LoginPage({ searchParams }: { searchParams: Promise<SearchParams> }) {
  const params = await searchParams;
  const next = safeInternalPath(firstValue(params.next), '/');
  const expired = firstValue(params.durum) === 'suresi-doldu';

  // Geçerli oturum varsa giriş ekranı gösterilmez. Token geçersizse burada
  // kalınır — aksi hâlde korumalı sayfa ile döngüye girilir.
  if (await getCurrentCustomerSafe()) redirect(next);

  return (
    <div className="bg-linear-to-b from-brand-50 to-neutral-50">
      <div className="mx-auto w-full max-w-md px-4 py-10 sm:py-16">
        <h1 className="text-2xl font-bold">Giriş yap</h1>
        <p className="mt-2 text-sm text-neutral-600">
          Siparişlerinizi takip etmek ve hızlı sipariş vermek için hesabınıza girin.
        </p>

        {expired && (
          <p role="status" className="mt-4 rounded-md bg-warning/10 px-3 py-2 text-sm">
            Oturumunuzun süresi doldu. Devam etmek için tekrar giriş yapın.
          </p>
        )}

        <div className="bld-card mt-6 p-5 shadow-md sm:p-6">
          <LoginForm next={next} />
        </div>
      </div>
    </div>
  );
}
