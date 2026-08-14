<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Console;

use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Throwable;
use Veykemtu\BridgeApi\Models\ClosedDay;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Services\OrderFactory;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Abonelik gece üretim işi — `docs/11-yol-haritasi.md` §7.5.
 *
 * Her gece ertesi günün siparişlerini üretir; KDS'e normal sipariş olarak
 * düşer. FAZ 4'te `registerSchedule` ile kesim saatinden ÖNCE (22:00)
 * çalışacak, böylece müşteriye sabaha kadar adet değiştirme payı kalır.
 *
 * İDEMPOTENT: `veykemtu_subscription_runs` üzerindeki
 * `UNIQUE(subscription_id, delivery_point_id, service_date)` + varlık kontrolü
 * — komut iki kez koşsa da aynı gün için ikinci sipariş doğmaz.
 *
 * `menu_mode = daily_menu` abonelikleri için ÖN KONTROL var
 * ([reportMissingDailyMenus]): o günün menüsü yayınlanmamışsa vitrin başına
 * tek bir hata satırı basılır ve o abonelikler üretime hiç sokulmaz. Koşum
 * satırı yazılmadığı için menü yayınlandıktan sonra komut yeniden
 * koşturulunca sipariş doğar — başarısızlık bir sonraki denemeyi engellemez.
 */
class SubscriptionGenerateCommand extends Command
{
    protected $signature = 'veykemtu:abonelik-uret
        {--date= : Servis günü YYYY-AA-GG (varsayılan: yarın, Istanbul)}
        {--dry-run : Sipariş üretmeden neyin üretileceğini göster}';

    protected $description = 'Aboneliklerden o günün siparişlerini üretir (idempotent).';

    public function handle(OrderFactory $factory): int
    {
        $serviceDate = ($this->option('date') !== null
            ? Carbon::parse((string) $this->option('date'))
            : BusinessTime::now()->addDay())->startOfDay();
        $dryRun = (bool) $this->option('dry-run');

        if (ClosedDay::isClosed($serviceDate)) {
            $this->components->warn(
                $serviceDate->toDateString().' kapalı gün (tatil) — üretim atlandı.',
            );

            return self::SUCCESS;
        }

        $subscriptions = Subscription::query()
            ->active()
            ->with(['lines', 'delivery_points', 'pauses', 'exceptions', 'customer'])
            ->get()
            ->filter(static fn(Subscription $s): bool => $s->runsOnDate($serviceDate));

        $this->components->info(sprintf(
            '%s — %d abonelik bugün üretecek%s',
            $serviceDate->toDateString(),
            $subscriptions->count(),
            $dryRun ? ' (kuru koşum)' : '',
        ));

        $locationsWithoutMenu = $this->reportMissingDailyMenus($subscriptions, $serviceDate);

        $created = 0;
        $skipped = 0;
        $failed = 0;

        foreach ($subscriptions as $subscription) {
            $points = $subscription->delivery_points->all();
            // Teslimat noktası yoksa noktasız tek üretim (delivery_point_id = 0).
            $targets = $points === []
                ? [[null, 0]]
                : array_map(static fn($p): array => [$p, (int) $p->id], $points);

            foreach ($targets as [$point, $pointId]) {
                $exists = DB::table('veykemtu_subscription_runs')
                    ->where('subscription_id', $subscription->id)
                    ->where('delivery_point_id', $pointId)
                    ->where('service_date', $serviceDate->toDateString())
                    ->exists();

                if ($exists) {
                    $skipped++;

                    continue;
                }

                /*
                 * SEBEBİ ZATEN BİR KEZ SÖYLENDİ.
                 *
                 * Menüsü olmayan bir vitrinin `daily_menu` abonelikleri
                 * burada üretime hiç sokulmuyor: `OrderFactory` her biri
                 * için ayrı ayrı patlar ve 40 abonelikte 40 satırlık,
                 * hepsi aynı şeyi söyleyen bir hata yığını çıkardı.
                 * Hata SAYILIYOR (komut FAILURE dönsün, zamanlayıcı
                 * sessizce başarılı görünmesin) ama tekrar yazılmıyor.
                 */
                if ($subscription->menu_mode === Subscription::MENU_DAILY
                    && in_array((int) $subscription->location_id, $locationsWithoutMenu, true)
                ) {
                    $failed++;

                    continue;
                }

                if ($dryRun) {
                    $this->components->twoColumnDetail(
                        'Abonelik #'.$subscription->id.($pointId > 0 ? ' / nokta '.$pointId : ''),
                        $subscription->quantityForDate($serviceDate).' porsiyon üretilecek',
                    );
                    $created++;

                    continue;
                }

                try {
                    DB::transaction(function () use ($factory, $subscription, $point, $pointId, $serviceDate): void {
                        $order = $factory->createForSubscription($subscription, $point, $serviceDate);

                        DB::table('veykemtu_subscription_runs')->insert([
                            'subscription_id' => $subscription->id,
                            'delivery_point_id' => $pointId,
                            'service_date' => $serviceDate->toDateString(),
                            'order_id' => $order->order_id,
                            'created_at' => BusinessTime::forStorage(BusinessTime::now()),
                        ]);
                    });
                    $created++;
                } catch (Throwable $e) {
                    $this->components->error('Abonelik #'.$subscription->id.': '.$e->getMessage());
                    $failed++;
                }
            }
        }

        $this->components->info(sprintf(
            '%d üretildi, %d zaten vardı, %d hata.',
            $created,
            $skipped,
            $failed,
        ));

        return $failed > 0 ? self::FAILURE : self::SUCCESS;
    }

    /**
     * `daily_menu` abonelikleri için menüsü YAYINLANMAMIŞ vitrinleri bulur
     * ve her biri için TEK bir yüksek sesli hata satırı basar.
     *
     * NEDEN ÖN KONTROL: gece işi 22:00'de yarın için koşuyor. Yarının
     * menüsü o saate kadar yayınlanmamışsa yüzlerce porsiyon düşer ve bunu
     * gören tek yer bu komutun çıktısı. Kontrol döngünün içinde kalsaydı
     * mesaj abonelik sayısı kadar tekrarlanır, gerçek sebep yığın izlerinin
     * arasında kaybolurdu.
     *
     * @param  Collection<int, Subscription>  $subscriptions
     * @return list<int>  Menüsü olmayan vitrinlerin kimlikleri
     */
    private function reportMissingDailyMenus(Collection $subscriptions, Carbon $serviceDate): array
    {
        $missing = [];

        $daily = $subscriptions->filter(
            static fn(Subscription $s): bool => $s->menu_mode === Subscription::MENU_DAILY,
        );

        foreach ($daily->groupBy('location_id') as $locationId => $group) {
            $locationId = (int) $locationId;

            if (DailyMenu::findPublished($locationId, $serviceDate) !== null) {
                continue;
            }

            $missing[] = $locationId;

            $portions = $group->sum(
                static fn(Subscription $s): int => max(1, $s->quantityForDate($serviceDate)),
            );

            $this->components->error(sprintf(
                '%s için GÜNÜN MENÜSÜ YAYINLANMAMIŞ (vitrin #%d): %d abonelik, '
                    .'%d porsiyon üretilemiyor. Menüyü yayınlayıp '
                    .'`php artisan veykemtu:abonelik-uret --date=%s` komutunu tekrar koşun.',
                $serviceDate->toDateString(),
                $locationId,
                $group->count(),
                $portions,
                $serviceDate->toDateString(),
            ));
        }

        return $missing;
    }
}
