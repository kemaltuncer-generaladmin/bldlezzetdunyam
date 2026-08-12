import type { Metadata } from 'next';
import { AccountPaymentForm } from '@/components/account/account-payment-form';
import { AccountNav } from '@/components/account/account-nav';
import { fetchAccountStatement, fetchAccountSummary } from '@/lib/api/account';
import { formatPrice } from '@/lib/format';
import { requireSession } from '@/lib/require-session';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Cari hesabım',
  description: 'Güncel bakiyeniz, hesap ekstreniz ve ödeme.',
  robots: { index: false, follow: false },
};

type SearchParams = { durum?: string | string[] };

function firstValue(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

/**
 * Cari hesap self-servisi — W-12.
 *
 * Bu sayfa `docs/06`'daki "cari self-servisi mobil uygulamaya özgüdür"
 * kararını değiştiriyor. Gerekçe: kurumsal müşterinin çoğu siparişi
 * masaüstünden veriyor ve borcunu görmek için telefon uygulaması indirmek
 * zorunda kalması anlamsızdı.
 *
 * `force-dynamic`: bakiye her istekte taze okunuyor. ISR'a bırakılsaydı
 * müşteri ödeme yaptıktan sonra eski bakiyeyi görür ve ikinci kez ödemeye
 * kalkardı.
 *
 * BAKİYENİN İŞARETİ ANLAM TAŞIYOR (`docs/02` §7.2): pozitif = müşterinin
 * borcu. Sayıyı yalnız bırakmak "1.250,00 ₺ ne?" sorusunu doğuruyordu;
 * her yerde bir cümleyle birlikte gösteriliyor.
 */
export default async function AccountLedgerPage({
  searchParams,
}: {
  searchParams: Promise<SearchParams>;
}) {
  const { token } = await requireSession('/hesabim/cari');
  const params = await searchParams;
  const outcome = firstValue(params.durum);

  const [summary, statement] = await Promise.all([
    fetchAccountSummary(token),
    fetchAccountStatement(token),
  ]);

  const balance = summary.balance;

  return (
    <div className="mx-auto w-full max-w-content px-4 py-8 sm:px-6 sm:py-12">
      <h1 className="font-display text-3xl font-bold">Cari hesabım</h1>

      <AccountNav active="cari" />

      {/*
        Ödeme dönüşü. Sağlayıcı `?durum=odendi` ile geri gönderiyor
        (`AccountSimulationController::process`). Bu bildirim olmadan
        müşteri ödemenin geçip geçmediğini yalnızca bakiyeye bakarak
        tahmin etmek zorunda kalırdı.
      */}
      {outcome === 'odendi' && (
        <p role="status" className="mt-6 rounded-md bg-success/10 px-4 py-3 text-sm">
          Ödemeniz alındı ve hesabınıza işlendi. Güncel bakiyeniz aşağıda.
        </p>
      )}
      {outcome === 'zaten_odendi' && (
        <p role="status" className="mt-6 rounded-md bg-warning/10 px-4 py-3 text-sm">
          Bu ödeme daha önce tamamlanmış. İkinci kez tahsilat yapılmadı.
        </p>
      )}

      <section className="mt-6 rounded-xl border bg-card p-5 shadow-sm sm:p-6">
        <h2 className="text-sm font-medium text-muted-foreground">Güncel bakiye</h2>
        <p
          className={`mt-1 text-4xl font-bold tabular-nums ${
            balance > 0 ? 'text-danger' : balance < 0 ? 'text-success' : ''
          }`}
        >
          {formatPrice(Math.abs(balance))}
        </p>
        <p className="mt-1 text-sm text-muted-foreground">
          {balance > 0
            ? 'Ödenmemiş borcunuz.'
            : balance < 0
              ? 'Fazla ödemeniz var; sonraki siparişlerinizden düşülür.'
              : 'Hesabınız kapalı, borcunuz yok.'}
        </p>

        <div className="mt-6 border-t pt-6">
          <AccountPaymentForm balance={balance} />
        </div>
      </section>

      <section className="mt-8">
        <div className="flex flex-wrap items-baseline justify-between gap-2">
          <h2 className="text-lg font-semibold">Hesap ekstresi</h2>
          <p className="text-sm text-muted-foreground tabular-nums">
            {formatDate(statement.from)} – {formatDate(statement.to)}
          </p>
        </div>

        <div className="mt-3 overflow-x-auto rounded-xl border bg-card">
          <table className="w-full text-sm">
            <thead className="bg-muted/60">
              <tr>
                <th scope="col" className="px-4 py-3 text-left font-medium">
                  Tarih
                </th>
                <th scope="col" className="px-4 py-3 text-left font-medium">
                  Açıklama
                </th>
                <th scope="col" className="px-4 py-3 text-right font-medium">
                  Borç
                </th>
                <th scope="col" className="px-4 py-3 text-right font-medium">
                  Alacak
                </th>
                <th scope="col" className="px-4 py-3 text-right font-medium">
                  Bakiye
                </th>
              </tr>
            </thead>
            <tbody className="divide-y">
              <tr className="text-muted-foreground">
                <td className="px-4 py-2" colSpan={4}>
                  Devir
                </td>
                <td className="px-4 py-2 text-right tabular-nums">
                  {formatSigned(statement.opening_balance)}
                </td>
              </tr>

              {statement.entries.length === 0 ? (
                <tr>
                  <td colSpan={5} className="px-4 py-8 text-center text-muted-foreground">
                    Bu dönemde hareket yok.
                  </td>
                </tr>
              ) : (
                statement.entries.map((entry, index) => {
                  const isDebit = entry.entry_type === 'debit';
                  return (
                    <tr key={`${entry.date}-${index}`}>
                      <td className="px-4 py-2 whitespace-nowrap tabular-nums">
                        {formatDate(entry.date)}
                      </td>
                      <td className="px-4 py-2">{entry.description || '—'}</td>
                      <td className="px-4 py-2 text-right tabular-nums">
                        {isDebit ? formatPrice(entry.amount) : ''}
                      </td>
                      <td className="px-4 py-2 text-right tabular-nums">
                        {isDebit ? '' : formatPrice(entry.amount)}
                      </td>
                      <td className="px-4 py-2 text-right font-medium tabular-nums">
                        {formatSigned(entry.running_balance)}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
            <tfoot className="border-t bg-muted/40">
              <tr>
                <th scope="row" colSpan={4} className="px-4 py-3 text-right font-medium">
                  Kapanış bakiyesi
                </th>
                <td className="px-4 py-3 text-right font-bold tabular-nums">
                  {formatSigned(statement.closing_balance)}
                </td>
              </tr>
            </tfoot>
          </table>
        </div>

        <p className="mt-3 text-xs text-muted-foreground">
          Pozitif bakiye borcunuzu, negatif bakiye fazla ödemenizi gösterir. Daha eski dönemler için
          bizimle iletişime geçin.
        </p>
      </section>
    </div>
  );
}

/** `2026-08-12` → `12.08.2026`. Sunucuda çalışıyor; yerel ayara bağlı değil. */
function formatDate(iso: string): string {
  const [year, month, day] = iso.split('-');
  return day && month && year ? `${day}.${month}.${year}` : iso;
}

/** İşareti koruyan tutar. Bakiye sütununda yön anlam taşıyor. */
function formatSigned(kurus: number): string {
  return kurus < 0 ? `-${formatPrice(Math.abs(kurus))}` : formatPrice(kurus);
}
