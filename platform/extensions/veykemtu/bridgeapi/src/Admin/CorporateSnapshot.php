<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Admin;

use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Models\ClosedDay;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Kurumsal gösterge paneli sayıları — abonelik + cari.
 *
 * Yalnızca hesaplar; çizim `DashboardWidgets\BldCorporateStatus`'te. Mantık
 * serviste tutulur ki test edilebilsin ve widget ince kalsın
 * (`OperationsSnapshot` kalıbı).
 */
final class CorporateSnapshot
{
    /**
     * @return array{active_subscriptions:int, tomorrow_portions:int, tomorrow_closed:bool, open_balance_kurus:int}
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

        // Tüm cari defterin işaretli toplamı = toplam açık bakiye (borç pozitif).
        $openBalance = (int) DB::table('veykemtu_account_ledger')
            ->selectRaw(
                "COALESCE(SUM(CASE WHEN entry_type = 'debit' THEN amount_kurus ELSE -amount_kurus END), 0) AS bakiye",
            )
            ->value('bakiye');

        return [
            'active_subscriptions' => $activeSubscriptions,
            'tomorrow_portions' => $tomorrowPortions,
            'tomorrow_closed' => $tomorrowClosed,
            'open_balance_kurus' => $openBalance,
        ];
    }
}
