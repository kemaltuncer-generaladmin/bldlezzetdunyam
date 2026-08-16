<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Admin;

use Veykemtu\BridgeApi\Models\ClosedDay;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Kurumsal gösterge paneli sayıları — abonelik.
 *
 * Yalnızca hesaplar; çizim `DashboardWidgets\BldCorporateStatus`'te. Mantık
 * serviste tutulur ki test edilebilsin ve widget ince kalsın
 * (`OperationsSnapshot` kalıbı).
 *
 * "Toplam açık cari bakiye" metriği kaldırıldı: dayandığı
 * `veykemtu_account_ledger` tablosu düşürüldü. Bileşenin kendisi kaldı —
 * abonelik sayıları hâlâ panelin en çok bakılan iki rakamı.
 */
final class CorporateSnapshot
{
    /**
     * @return array{active_subscriptions:int, tomorrow_portions:int, tomorrow_closed:bool}
     */
    public function collect(): array
    {
        $tomorrow = BusinessTime::now()->addDay()->startOfDay();
        $tomorrowClosed = ClosedDay::isClosed($tomorrow);

        $activeSubscriptions = Subscription::query()->active()->count();

        $tomorrowPortions = 0;
        if (!$tomorrowClosed) {
            $subscriptions = Subscription::query()
                ->active()
                ->with(['pauses', 'exceptions', 'delivery_points'])
                ->get();

            foreach ($subscriptions as $subscription) {
                if (!$subscription->runsOnDate($tomorrow)) {
                    continue;
                }
                $points = max(1, $subscription->delivery_points->count());
                $tomorrowPortions += $subscription->quantityForDate($tomorrow) * $points;
            }
        }

        return [
            'active_subscriptions' => $activeSubscriptions,
            'tomorrow_portions' => $tomorrowPortions,
            'tomorrow_closed' => $tomorrowClosed,
        ];
    }
}
