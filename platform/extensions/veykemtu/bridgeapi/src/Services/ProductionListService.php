<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Üretim listesi — `docs/02-veri-modeli.md` §4.
 *
 * Tablo değildir, sorgudur: aktif siparişlerin (`onaylandi` + `hazirlaniyor`)
 * ürün bazında toplamı. Mutfak "kaç tavuk sote" sorusuna bakar, hangi
 * siparişten geldiğine değil.
 *
 * Dokümandaki özgün sorgu `orders.status_code` kolonunu varsayıyordu; öyle
 * bir kolon yok (B-02 bulgusu). `statuses` üzerinden JOIN ile çözülür.
 */
class ProductionListService
{
    /** @return list<array{menu_id:int, name:string, total:int}> */
    public function today(): array
    {
        $today = BusinessTime::now()->toDateString();

        return DB::table('order_menus as om')
            ->join('orders as o', 'o.order_id', '=', 'om.order_id')
            ->join('statuses as s', 's.status_id', '=', 'o.status_id')
            ->whereIn('s.status_code', [
                OrderStatusTransition::CONFIRMED,
                OrderStatusTransition::PREPARING,
            ])
            ->whereDate('o.order_date', $today)
            ->groupBy('om.menu_id', 'om.name')
            ->orderByDesc(DB::raw('SUM(om.quantity)'))
            ->get([
                'om.menu_id',
                'om.name',
                DB::raw('SUM(om.quantity) as total'),
            ])
            ->map(static fn(object $row): array => [
                'menu_id' => (int) $row->menu_id,
                'name' => (string) $row->name,
                'total' => (int) $row->total,
            ])
            ->all();
    }
}
