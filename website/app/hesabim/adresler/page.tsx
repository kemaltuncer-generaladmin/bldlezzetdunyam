import type { Metadata } from 'next';
import { AccountNav } from '@/components/account/account-nav';
import { AddressBook } from '@/components/address/address-book';
import { fetchAddresses } from '@/lib/api/addresses';
import { requireSession } from '@/lib/require-session';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Adreslerim',
  description: 'Kayıtlı teslimat adreslerinizi yönetin.',
  robots: { index: false, follow: false },
};

/**
 * Adres defteri — W-15.
 *
 * `/hesabim` sayfası "Kayıtlı adres defteri Faz 1 kapsamında değildir"
 * diyordu; oysa uçlar sözleşmede baştan beri vardı ve mobil uygulama
 * kullanıyordu. Sitedeki müşteri adresini her siparişte elden yazıyordu.
 *
 * `force-dynamic`: adres eklendikten sonra listenin eski hâlini göstermek,
 * müşteriyi ikinci kez eklemeye iterdi.
 */
export default async function AddressBookPage() {
  const { token } = await requireSession('/hesabim/adresler');
  const { data: addresses } = await fetchAddresses(token);

  return (
    <div className="mx-auto w-full max-w-content px-4 py-8 sm:px-6 sm:py-12">
      <h1 className="font-display text-3xl font-bold">Adreslerim</h1>

      <AccountNav active="adresler" />

      <div className="mt-8">
        <AddressBook addresses={addresses} />
      </div>
    </div>
  );
}
