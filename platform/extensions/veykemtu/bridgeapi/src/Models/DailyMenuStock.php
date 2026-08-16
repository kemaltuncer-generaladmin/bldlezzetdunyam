<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Cart\Models\Menu;
use Igniter\Flame\Database\Model;

/**
 * Bir günün, bir kalemin (ya da günün tamamının) porsiyon tavanı — S2.
 *
 * SALT OKUNUR SAYILIR. Tavanı yönetici/Kontrol Merkezi yazar; SATIŞIN
 * düşümü ise ASLA bu model üzerinden yapılmaz. Sebep `DailyStock` içinde
 * uzun uzun anlatılıyor: Eloquent'le "oku → değiştir → kaydet" arasında bir
 * kayıp-güncelleme penceresi var ve son porsiyonu iki müşteriye birden
 * satmak tam olarak oradan çıkıyor. Düşümün tek doğru ilkeli tek bir koşullu
 * `UPDATE`'tir ve `DailyStock` içinde yaşar.
 *
 * `menu_id = 0` GÜN TOPLAMI satırıdır — göç yorumundaki gerekçe: MySQL
 * benzersiz indekste NULL'ları ayrı sayar ve NULL nöbetçi tavanı sessizce
 * ikiye katlardı.
 */
class DailyMenuStock extends Model
{
    /** Gün toplamı satırının `menu_id` nöbetçisi. */
    public const int DAY_TOTAL = 0;

    protected $table = 'veykemtu_daily_menu_stock';

    public $timestamps = true;

    protected $guarded = [];

    protected $casts = [
        'location_id' => 'integer',
        'service_date' => 'date',
        'menu_id' => 'integer',
        'capacity' => 'integer',
        'reserved' => 'integer',
        'sold' => 'integer',
    ];

    /**
     * Gün toplamı satırının ürün bağıntısı YOKTUR (`menu_id = 0`); okuyan
     * taraf `isDayTotal()` ile ayırır.
     *
     * @var array<string, array<string, mixed>>
     */
    public $relation = [
        'belongsTo' => [
            'menu' => [Menu::class, 'foreignKey' => 'menu_id'],
        ],
    ];

    public function isDayTotal(): bool
    {
        return (int) $this->menu_id === self::DAY_TOTAL;
    }

    /**
     * Kalan porsiyon.
     *
     * ASLA EKSİYE DÜŞMEZ: personel telefonda tavanı bilerek aşabiliyor
     * (`DailyStock::take(allowOvershoot: true)`) ve o hâlde `sold`
     * `capacity`'yi geçer. Eksi bir "kalan" sözleşmedeki `minimum: 0`
     * kısıtını çiğner ve istemcilerde "-2 porsiyon kaldı" yazardı.
     */
    public function remaining(): int
    {
        return max(0, (int) $this->capacity - (int) $this->reserved - (int) $this->sold);
    }
}
