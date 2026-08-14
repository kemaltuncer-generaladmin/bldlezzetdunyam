<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Admin;

use Igniter\Admin\Models\Status;
use Igniter\Cart\Models\Order;
use Igniter\Flame\Database\Builder;
use Igniter\Local\Models\Location;
use Illuminate\Support\Carbon;
use Veykemtu\BridgeApi\Models\ClosedDay;
use Veykemtu\BridgeApi\Models\DailyMenu;
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

    /**
     * Menü boşlukları için bakılan pencere (bugün dahil).
     *
     * Bir hafta: gece üretimi 22:00'de YARIN için koşuyor, yani asıl
     * kritik gün yarın. Ama yöneticinin panele her gün baktığı garanti
     * değil ve bir haftalık boşluğu görmek, tek bir günü görmekten çok
     * daha erken uyarıyor. Daha uzun bir pencere ise sürekli kırmızı
     * yanar (menü genelde bir hafta öncesinden girilir) ve uyarı
     * görmezden gelinmeye başlar.
     */
    public const int MENU_LOOKAHEAD_DAYS = 7;

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
     *     daily_menu_enabled: bool,
     *     missing_menu_days: list<string>,
     * }
     */
    public function collect(): array
    {
        $location = resolve(SettingsRepository::class)->location();

        return [
            'has_location' => $location !== null,
            'daily_menu_enabled' => $location !== null && $this->gate->dailyMenuEnabled($location),
            'missing_menu_days' => $location === null
                ? []
                : $this->missingMenuDays($location),
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
     * Önümüzdeki günlerden menüsü YAYINLANMAMIŞ olanlar (`YYYY-AA-GG`).
     *
     * NEDEN GÖSTERGE PANELİNDE: gece üretimi 22:00'de yarın için koşuyor.
     * Yarının menüsü o saate kadar yayınlanmamışsa `daily_menu` abonelikleri
     * hiç sipariş üretmez ve müşteri de o güne sipariş veremez. Bunu
     * kimsenin izlemediği ikinci bir cron'a bağlamak yerine yöneticinin
     * ZATEN her sabah baktığı yere koymak, uyarının görülme ihtimalini
     * tek başına belirliyor.
     *
     * KAPALI GÜNLER ELENİR: bayramda menü olmaması bir eksiklik değil,
     * kararın kendisi. Elenmeseydi her resmî tatil kalıcı bir kırmızı
     * satır üretir ve uyarı anlamsızlaşırdı.
     *
     * @return list<string>
     */
    private function missingMenuDays(Location $location): array
    {
        // Şalter kapalıyken satış günün menüsünden yürümüyor; boş günler
        // bir eksiklik değil, o rejimin hiç açılmamış olması.
        if (!$this->gate->dailyMenuEnabled($location)) {
            return [];
        }

        $from = BusinessTime::now()->startOfDay();
        $to = $from->copy()->addDays(self::MENU_LOOKAHEAD_DAYS - 1);

        // İki toplu sorgu, gün başına sorgu değil.
        $published = DailyMenu::query()
            ->where('location_id', $location->location_id)
            ->where('status', DailyMenu::STATUS_PUBLISHED)
            ->whereBetween('menu_date', [$from->toDateString(), $to->toDateString()])
            ->pluck('menu_date')
            ->map(static fn($date): string => Carbon::parse($date)->toDateString())
            ->all();

        $closed = ClosedDay::query()
            ->whereBetween('closed_on', [$from->toDateString(), $to->toDateString()])
            ->pluck('closed_on')
            ->map(static fn($date): string => Carbon::parse($date)->toDateString())
            ->all();

        $missing = [];

        for ($cursor = $from->copy(); $cursor->lessThanOrEqualTo($to); $cursor->addDay()) {
            $key = $cursor->toDateString();

            if (in_array($key, $published, true) || in_array($key, $closed, true)) {
                continue;
            }

            $missing[] = $key;
        }

        return $missing;
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
