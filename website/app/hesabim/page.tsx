import type { Metadata } from 'next';
import Link from 'next/link';
import { ArrowRight, MapPin, ReceiptText, Repeat, Wallet } from 'lucide-react';
import { AccountNav } from '@/components/account/account-nav';
import { LogoutButton } from '@/components/auth/logout-button';
import { fetchAccountSummary } from '@/lib/api/account';
import { formatPrice } from '@/lib/format';
import { requireSession } from '@/lib/require-session';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Hesabım',
  description: 'Hesap bilgileriniz, cari bakiyeniz ve abonelikleriniz.',
  robots: { index: false, follow: false },
};

/**
 * Hesap merkezi — W-12 / W-13.
 *
 * Eskiden yalnızca üç satır profil bilgisi vardı. Artık dört bölümün giriş
 * kapısı: profil, siparişler, cari hesap, abonelikler.
 *
 * BAKİYE BURADA DA GÖSTERİLİYOR ve bu kasıtlı bir tekrar: borcu olan
 * müşterinin onu görmek için ayrı bir sayfaya gitmesi gerekmemeli. Kart,
 * borç varsa uyarı rengiyle çiziliyor.
 *
 * Bakiye okunamazsa sayfa ÇÖKMÜYOR: cari uç kurumsal olmayan bir hesapta
 * ya da geçici bir arızada hata verebilir ve o durumda profil bilgilerinin
 * de görünmemesi orantısız olurdu.
 */
export default async function AccountPage() {
  const { customer, token } = await requireSession('/hesabim');

  const balance = await fetchAccountSummary(token)
    .then((summary) => summary.balance)
    .catch(() => null);

  const rows: Array<{ label: string; value: string }> = [
    { label: 'Ad Soyad', value: `${customer.first_name} ${customer.last_name}` },
    { label: 'E-posta', value: customer.email },
    { label: 'Telefon', value: `0${customer.telephone}` },
  ];

  return (
    <div className="mx-auto w-full max-w-content px-4 py-8 sm:px-6 sm:py-12">
      <h1 className="font-display text-3xl font-bold">Hesabım</h1>

      <AccountNav active="profil" />

      <div className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <ShortcutCard
          href="/siparislerim"
          icon={<ReceiptText aria-hidden="true" className="size-5" />}
          title="Siparişlerim"
          detail="Geçmiş ve devam eden siparişler"
        />

        <ShortcutCard
          href="/hesabim/cari"
          icon={<Wallet aria-hidden="true" className="size-5" />}
          title="Cari hesabım"
          detail={
            balance === null
              ? 'Bakiye ve ekstre'
              : balance > 0
                ? `${formatPrice(balance)} borç`
                : balance < 0
                  ? `${formatPrice(Math.abs(balance))} alacak`
                  : 'Borcunuz yok'
          }
          highlight={balance !== null && balance > 0}
        />

        <ShortcutCard
          href="/hesabim/adresler"
          icon={<MapPin aria-hidden="true" className="size-5" />}
          title="Adreslerim"
          detail="Kayıtlı teslimat adresleri"
        />

        <ShortcutCard
          href="/hesabim/abonelikler"
          icon={<Repeat aria-hidden="true" className="size-5" />}
          title="Aboneliklerim"
          detail="Düzenli öğün planınız"
        />
      </div>

      <section className="mt-8 rounded-xl border bg-card p-5 shadow-sm sm:p-6">
        <h2 className="text-lg font-semibold">Profil bilgileri</h2>
        <dl className="mt-4 divide-y">
          {rows.map((row) => (
            <div key={row.label} className="flex flex-wrap justify-between gap-2 py-3 text-sm">
              <dt className="text-muted-foreground">{row.label}</dt>
              <dd className="font-medium">{row.value}</dd>
            </div>
          ))}
        </dl>
        <p className="mt-3 text-xs text-muted-foreground">
          Firma unvanı, vergi bilgisi veya iletişim bilgilerinizi güncellemek için bizimle iletişime
          geçin.
        </p>
      </section>

      <div className="mt-6">
        <LogoutButton />
      </div>
    </div>
  );
}

function ShortcutCard({
  href,
  icon,
  title,
  detail,
  highlight = false,
}: {
  href: string;
  icon: React.ReactNode;
  title: string;
  detail: string;
  highlight?: boolean;
}) {
  return (
    <Link
      href={href}
      className={`group flex items-start gap-3 rounded-xl border p-4 transition-colors hover:bg-muted ${
        highlight ? 'border-danger/40 bg-danger/5' : 'bg-card'
      }`}
    >
      <span className="mt-0.5 text-primary">{icon}</span>
      <span className="flex-1">
        <span className="block font-medium">{title}</span>
        <span className="mt-0.5 block text-sm text-muted-foreground tabular-nums">{detail}</span>
      </span>
      <ArrowRight
        aria-hidden="true"
        className="mt-1 size-4 shrink-0 text-muted-foreground transition-transform group-hover:translate-x-0.5"
      />
    </Link>
  );
}
