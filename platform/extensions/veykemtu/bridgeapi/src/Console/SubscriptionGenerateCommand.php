<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Console;

use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Throwable;
use Veykemtu\BridgeApi\Models\ClosedDay;
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
}
