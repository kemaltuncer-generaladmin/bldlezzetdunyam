<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Admin;

use Igniter\Admin\Models\Status;
use Igniter\Cart\Models\Order;
use Igniter\Flame\Database\Builder;
use Veykemtu\BridgeApi\Models\KitchenDevice;
use Veykemtu\BridgeApi\Models\PrintJob;
use Veykemtu\BridgeApi\Services\LocationGate;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\BridgeApi\Support\Money;

/**
 * Gösterge panelindeki BLD parçacığının verisini üretir.
 *
 * AYRI SINIF OLMASININ SEBEBİ: parçacık sınıfı bir `AdminController` olmadan
 * kurulamaz, bu yüzden testte canlandırılması pahalıdır. Sayılan şeyler ise
 * iş kuralıdır (hangi sipariş "bekliyor" sayılır, "bugün" hangi zaman
 * diliminde başlar) ve testi zorunludur. Mantık burada durur, parçacık
 * yalnızca çizer.
 *
 * TastyIgniter'ın kendi istatistik kartları (`igniter.cart`) ciro ve sipariş
 * sayısını zaten veriyor; burada tekrarlanmalarının sebebi, yöneticinin
 * sabah panele bakınca "sipariş alıyor muyum, mutfak yetişiyor mu, fişler
 * basılıyor mu" sorularının cevabını TEK kutuda görmesi. O kartlar tarih
 * aralığı seçimine bağlıdır ve şalterlerin durumunu hiç göstermez.
 */
final class OperationsSnapshot
{
    /** Bu süredir haber vermeyen kasa çevrimdışı sayılır. */
    public const int DEVICE_ONLINE_MINUTES = 5;

    /** Mutfağın hâlâ dokunması gereken durumlar. */
    private const array PENDING_CODES = [
        OrderStatusTransition::NEW,
        OrderStatusTransition::CONFIRMED,
        OrderStatusTransition::PREPARING,
    ];

    public function __construct(private readonly LocationGate $gate) {}

    /**
     * @return array{
     *     has_location: bool,
     *     ordering_enabled: bool,
     *     busy: bool,
     *     order_cutoff: string|null,
     *     orders_today: int,
     *     revenue_today_kurus: int,
     *     pending_orders: int,
     *     unprinted_orders: int,
     *     devices_online: int,
     *     devices_total: int,
     * }
     */
    public function collect(): array
    {
        $location = resolve(SettingsRepository::class)->location();

        return [
            'has_location' => $location !== null,
            'ordering_enabled' => $location !== null && $this->gate->orderingEnabled($location),
            'busy' => $location !== null && $this->gate->isBusy($location),
            'order_cutoff' => $location === null ? null : $this->gate->orderCutoff($location),
            'orders_today' => $this->ordersToday()->count(),
            'revenue_today_kurus' => Money::toKurus(
                $this->ordersToday()->whereNotIn('status_id', $this->statusIds([OrderStatusTransition::CANCELLED]))->sum('order_total'),
            ),
            'pending_orders' => Order::query()
                ->whereIn('status_id', $this->statusIds(self::PENDING_CODES))
                ->count(),
            'unprinted_orders' => $this->ordersToday()
                ->whereNotIn('order_id', PrintJob::query()
                    ->where('type', PrintJob::TYPE_KITCHEN)
                    ->whereNotNull('printed_at')
                    ->select('order_id'))
                ->count(),
            'devices_online' => KitchenDevice::query()
                ->whereNull('revoked_at')
                ->where('last_seen_at', '>=', BusinessTime::forStorage(
                    BusinessTime::now()->subMinutes(self::DEVICE_ONLINE_MINUTES),
                ))
                ->count(),
            'devices_total' => KitchenDevice::query()->whereNull('revoked_at')->count(),
        ];
    }

    /**
     * Bugün oluşturulan siparişler.
     *
     * "Bugün" işletme günüdür (Europe/Istanbul), UTC günü değil — gece
     * yarısından sonraki üç saatte iki kavram farklı günlere düşer
     * (`Support\BusinessTime`). `status_id > 0` süzgeci TastyIgniter'ın
     * tamamlanmamış sepet kayıtlarını dışarıda bırakır.
     */
    private function ordersToday(): Builder
    {
        return Order::query()
            ->where('status_id', '>', 0)
            ->where('created_at', '>=', BusinessTime::forStorage(
                BusinessTime::now()->startOfDay(),
            ));
    }

    /**
     * @param  list<string>  $codes
     * @return list<int>
     */
    private function statusIds(array $codes): array
    {
        return Status::query()
            ->whereIn('status_code', $codes)
            ->pluck('status_id')
            ->map(intval(...))
            ->values()
            ->all();
    }
}
