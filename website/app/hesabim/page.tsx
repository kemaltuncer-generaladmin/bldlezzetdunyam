import type { Metadata } from 'next';
import Link from 'next/link';
import { LogoutButton } from '@/components/auth/logout-button';
import { requireSession } from '@/lib/require-session';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Hesabım',
  description: 'Hesap bilgileriniz.',
  robots: { index: false, follow: false },
};

export default async function AccountPage() {
  const { customer } = await requireSession('/hesabim');

  const rows: Array<{ label: string; value: string }> = [
    { label: 'Ad Soyad', value: `${customer.first_name} ${customer.last_name}` },
    { label: 'E-posta', value: customer.email },
    { label: 'Telefon', value: `0${customer.telephone}` },
  ];

  return (
    <div className="mx-auto max-w-2xl px-4 py-8 sm:py-12">
      <h1 className="text-3xl font-bold text-neutral-900">Hesabım</h1>

      <div className="mt-6 bld-card p-5">
        <h2 className="text-lg font-semibold text-neutral-900">Profil bilgileri</h2>
        <dl className="mt-4 divide-y divide-neutral-200">
          {rows.map((row) => (
            <div key={row.label} className="flex flex-wrap justify-between gap-2 py-3 text-sm">
              <dt className="text-neutral-600">{row.label}</dt>
              <dd className="font-medium text-neutral-900">{row.value}</dd>
            </div>
          ))}
        </dl>
        <p className="mt-3 text-xs text-neutral-600">
          Profil bilgilerinizi güncellemek için bizimle iletişime geçin. Sözleşmede profil
          güncelleme ucu tanımlı olmadığından bu ekran şimdilik yalnızca görüntüleme yapar.
        </p>
      </div>

      <div className="mt-4 bld-card p-5">
        <h2 className="text-lg font-semibold text-neutral-900">Adreslerim</h2>
        <p className="mt-2 text-sm text-neutral-600">
          Kayıtlı adres defteri Faz 1 kapsamında değildir. Teslimat adresini her siparişte ödeme
          adımında girersiniz.
        </p>
      </div>

      <div className="mt-6 flex flex-wrap gap-3">
        <Link
          href="/siparislerim"
          className="rounded-lg bg-brand-700 px-4 py-2.5 text-sm font-semibold text-neutral-0 hover:bg-brand-800"
        >
          Siparişlerim
        </Link>
        <LogoutButton />
      </div>
    </div>
  );
}
