import type { Metadata } from 'next';
import { redirect } from 'next/navigation';
import { CheckCircle2 } from 'lucide-react';
import { CorporateRegisterForm } from '@/components/auth/corporate-register-form';
import { safeInternalPath } from '@/lib/safe-redirect';
import { getCurrentCustomerSafe } from '@/lib/session';

export const metadata: Metadata = {
  title: 'Kurumsal kayıt',
  description:
    'Firmanız için hesap oluşturun; kaydınız tamamlanır tamamlanmaz sipariş verebilirsiniz.',
};

type SearchParams = { next?: string | string[] };

function firstValue(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

/**
 * Kurumsal kayıt sayfası — W-11.
 *
 * `/kayit` (bireysel) YERİNE GEÇMİYOR, ONUN DEVAMI: sipariş kapısı kurumsal
 * hesaplarda açık, yani bireysel kayıt zaten sipariş veremeyen bir hesap
 * üretiyordu. Eski adres duruyor ama header ve footer buraya işaret ediyor.
 *
 * Sağdaki liste ONAY BEKLEMEDİĞİNİ söylüyor. Kurumsal kayıt formu gören
 * çoğu kişi "başvuru yapıp bekleyeceğim" varsayıyor ve formu yarıda
 * bırakıyor; beklenti baştan düzeltiliyor.
 */
export default async function CorporateRegisterPage({
  searchParams,
}: {
  searchParams: Promise<SearchParams>;
}) {
  const params = await searchParams;
  const next = safeInternalPath(firstValue(params.next), '/menu');

  if (await getCurrentCustomerSafe()) redirect(next);

  return (
    <div className="bg-linear-to-b from-brand-50 to-neutral-50">
      <div className="mx-auto grid w-full max-w-content gap-10 px-4 py-10 sm:px-6 sm:py-16 lg:grid-cols-[1.3fr_1fr] lg:gap-16">
        <div>
          <h1 className="font-display text-3xl font-bold sm:text-4xl">Kurumsal kayıt</h1>
          <p className="mt-3 max-w-prose text-muted-foreground">
            Firmanız için bir hesap açın. Kaydınız tamamlanır tamamlanmaz menüden sipariş
            verebilirsiniz — onay beklemenize gerek yok.
          </p>

          <div className="mt-8 rounded-xl border bg-card p-5 shadow-sm sm:p-6">
            <CorporateRegisterForm next={next} />
          </div>
        </div>

        <aside className="lg:pt-24">
          <div className="rounded-xl border bg-card p-6 shadow-sm">
            <h2 className="text-base font-semibold">Kayıttan sonra</h2>
            <ul className="mt-4 space-y-4 text-sm">
              {[
                {
                  title: 'Hemen sipariş verebilirsiniz',
                  body: 'Onay süreci yok. Menüye gidip sepetinizi doldurmanız yeterli.',
                },
                {
                  title: 'Telefonla giriş açılır',
                  body: 'Parola hatırlamanız gerekmez; numaranıza gelen kodla girersiniz.',
                },
                {
                  title: 'Kapıda ödeme veya kart',
                  body: 'Cari hesap (veresiye) ayrı bir anlaşmadır; talep ederseniz tanımlarız.',
                },
                {
                  title: 'Düzenli sipariş verecekseniz abonelik',
                  body: 'Her gün aynı saatte gelen öğün için abonelik talebi açabilirsiniz.',
                },
              ].map((item) => (
                <li key={item.title} className="flex gap-3">
                  <CheckCircle2
                    aria-hidden="true"
                    className="mt-0.5 size-5 shrink-0 text-success"
                  />
                  <span>
                    <span className="block font-medium">{item.title}</span>
                    <span className="text-muted-foreground">{item.body}</span>
                  </span>
                </li>
              ))}
            </ul>
          </div>
        </aside>
      </div>
    </div>
  );
}
