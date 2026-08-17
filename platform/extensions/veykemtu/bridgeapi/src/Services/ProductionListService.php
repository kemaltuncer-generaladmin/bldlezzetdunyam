<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Üretim listesi — `docs/02-veri-modeli.md` §4.
 *
 * Tablo değildir, sorgudur: aktif siparişlerin (`onaylandi` + `hazirlaniyor`)
 * ürün bazında toplamı. Mutfak "kaç tavuk sote" sorusuna bakar, hangi
 * siparişten geldiğine değil.
 *
 * Dokümandaki özgün sorgu `orders.status_code` kolonunu varsayıyordu; öyle
 * bir kolon yok (B-02 bulgusu). `statuses` üzerinden JOIN ile çözülür.
 *
 * SERBEST BIRAKMA KAPISINA UYAR (A1) — abonelik planı ekranlarından ayrıldığı
 * yer burası. Bu liste ŞU AN pişirilecek işi sayıyor ve mutfak panosuyla
 * (`KitchenController::orders`) aynı gerçeği göstermek zorunda: pano 07:00'e
 * kadar boşken şerit "40 tavuk sote" derse mutfak, ekranda karşılığı olmayan
 * bir yemeği pişirmeye başlar.
 */
class ProductionListService
{
    /** @return list<array{menu_id:int, name:string, total:int}> */
    public function today(): array
    {
        $today = BusinessTime::now()->toDateString();
        $now = BusinessTime::forStorage(BusinessTime::now());

        return DB::table('order_menus as om')
            ->join('orders as o', 'o.order_id', '=', 'om.order_id')
            ->join('statuses as s', 's.status_id', '=', 'o.status_id')
            ->whereIn('s.status_code', [
                OrderStatusTransition::CONFIRMED,
                OrderStatusTransition::PREPARING,
            ])
            ->whereDate('o.order_date', $today)
            /*
             * MENÜ PAKETİ SATIRI ŞERİDE GİRMEZ (B-19).
             *
             * Paket bir üst satır + altında bileşen satırları olarak
             * yazılıyor. Üst satır da sayılsaydı mutfak "40 Günün Menüsü"
             * satırını görürdü — hiçbir işe yaramayan ve gerçek toplamların
             * arasına karışan bir satır. Bileşenler gerçek `menu_id`'leriyle
             * burada zaten toplanıyor: "40 tavuk sote" oradan geliyor.
             */
            ->where(function ($query): void {
                $query->whereNull('om.bld_line_role')
                    ->orWhere('om.bld_line_role', '!=', 'package');
            })
            // Henüz mutfağa açılmamış sipariş şeride girmez (A1).
            // `NULL = serbest`: vitrin siparişleri damgasızdır.
            ->where(function ($query) use ($now): void {
                $query->whereNull('o.bld_released_at')
                    ->orWhere('o.bld_released_at', '<=', $now);
            })
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
