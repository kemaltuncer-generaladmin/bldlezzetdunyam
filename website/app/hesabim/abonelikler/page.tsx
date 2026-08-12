import type { Metadata } from 'next';
import Link from 'next/link';
import { AccountNav } from '@/components/account/account-nav';
import { SubscriptionCard } from '@/components/account/subscription-card';
import { Button } from '@/components/ui/button';
import { fetchSubscriptions } from '@/lib/api/subscriptions';
import { requireSession } from '@/lib/require-session';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Aboneliklerim',
  description: 'Düzenli öğün aboneliklerinizi görüntüleyin ve yönetin.',
  robots: { index: false, follow: false },
};

/**
 * Abonelik self-servisi — W-13.
 *
 * `force-dynamic`: duraklatma ve gün atlama anında görünmeli. Önbelleğe
 * alınsaydı müşteri "yarını atladım" deyip listede eski hâli görür ve
 * ikinci kez atlamaya çalışırdı.
 *
 * YENİ ABONELİK BURADAN AÇILMIYOR. `POST /subscriptions` bir talep açıyor
 * ama talebin içeriği (hangi ürünler, kaç porsiyon, hangi günler, hangi
 * adres) telefonla konuşulan bir anlaşma; formda toplamaya çalışmak,
 * müşteriye yanlış beklenti veren yarım bir sözleşme üretirdi. Talep
 * "Teklif Al" üzerinden geliyor ve aboneliği yönetici kuruyor.
 */
export default async function SubscriptionsPage() {
  const { token } = await requireSession('/hesabim/abonelikler');
  const { data: subscriptions } = await fetchSubscriptions(token);

  const active = subscriptions.filter((item) => item.status !== 'cancelled');
  const cancelled = subscriptions.filter((item) => item.status === 'cancelled');

  return (
    <div className="mx-auto w-full max-w-content px-4 py-8 sm:px-6 sm:py-12">
      <h1 className="font-display text-3xl font-bold">Aboneliklerim</h1>

      <AccountNav active="abonelikler" />

      {subscriptions.length === 0 ? (
        <div className="mt-8 rounded-xl border bg-card p-8 text-center">
          <h2 className="text-lg font-semibold">Henüz aboneliğiniz yok</h2>
          <p className="mx-auto mt-2 max-w-prose text-sm text-muted-foreground">
            Her gün aynı saatte gelen öğün için abonelik kurabiliriz: gün ve porsiyon sayısını
            birlikte belirleriz, siparişler kendiliğinden oluşur ve mutfağa düşer.
          </p>
          <Button asChild size="lg" className="mt-6">
            <Link href="/teklif-al">Abonelik için teklif alın</Link>
          </Button>
        </div>
      ) : (
        <>
          <div className="mt-8 space-y-4">
            {active.map((subscription) => (
              <SubscriptionCard key={subscription.id} subscription={subscription} />
            ))}
          </div>

          {cancelled.length > 0 && (
            <section className="mt-10">
              <h2 className="text-sm font-medium text-muted-foreground">İptal edilenler</h2>
              <div className="mt-3 space-y-4 opacity-70">
                {cancelled.map((subscription) => (
                  <SubscriptionCard key={subscription.id} subscription={subscription} />
                ))}
              </div>
            </section>
          )}

          <p className="mt-8 text-sm text-muted-foreground">
            Abonelik içeriğini (ürünler, günler, saat) değiştirmek için{' '}
            <Link href="/iletisim" className="text-primary underline underline-offset-4">
              bizimle iletişime geçin
            </Link>
            . Çalışan bir aboneliğin kuralını değiştirmek, o güne ait üretilmiş siparişlerle
            ayrışmasına yol açtığı için telefonla yapılıyor.
          </p>
        </>
      )}
    </div>
  );
}
