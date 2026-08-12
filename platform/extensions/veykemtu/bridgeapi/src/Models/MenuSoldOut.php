<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Cart\Models\Menu;
use Igniter\Flame\Database\Model;

/**
 * Günlük "tükendi" işareti — B-17.
 *
 * K-11 ile doğdu: mutfak bir ürünü o güne özel satıştan kaldırabiliyor.
 * İşaret ertesi gün kendiliğinden düşüyor (tarih bazlı), bu yüzden hiçbir
 * yerde geçmişi görünmüyordu. Oysa "bu ay kaç kez humus bitti" sorusu
 * doğrudan satın almaya bakan bir soru.
 *
 * SALT OKUNUR: işareti KDS koyar ve kaldırır (`Services\MenuAvailability`).
 * Panelden bugünün satışına müdahale etmek, mutfakla panelin aynı anda
 * zıt kararlar vermesi demek olurdu.
 */
class MenuSoldOut extends Model
{
    protected $table = 'veykemtu_menu_soldout';

    public $timestamps = false;

    protected $guarded = [];

    protected $casts = [
        'menu_id' => 'integer',
        'sold_out_on' => 'date',
        'device_id' => 'integer',
        'created_by' => 'integer',
        'created_at' => 'datetime',
    ];

    /**
     * @var array<string, array<string, mixed>>
     */
    public $relation = [
        'belongsTo' => [
            'menu' => [Menu::class, 'foreignKey' => 'menu_id'],
        ],
    ];
}
