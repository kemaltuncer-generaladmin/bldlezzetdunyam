<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Cart\Models\Menu;
use Igniter\Flame\Database\Model;
use Veykemtu\BridgeApi\Admin\LiraField;
use Veykemtu\BridgeApi\Support\Money;

/**
 * Günün menüsündeki bir kalem — `docs/02-veri-modeli.md` §8.2.
 *
 * Çekirdek `menus` kaydına işaret eder; ürünün kendisi orada yaşar. Bu satır
 * yalnızca "o gün, o üründen, şu kadar, şu sırada, belki şu fiyata" der.
 */
class DailyMenuItem extends Model
{
    protected $table = 'veykemtu_daily_menu_items';

    public $timestamps = false;

    protected $guarded = [];

    protected $casts = [
        'daily_menu_id' => 'integer',
        'menu_id' => 'integer',
        'quantity' => 'integer',
        'sort_order' => 'integer',
        'price_override_kurus' => 'integer',
        'is_required' => 'boolean',
        'sellable_alone' => 'boolean',
    ];

    /** @var array<string, array<string, mixed>> */
    public $relation = [
        'belongsTo' => [
            'menu' => [Menu::class, 'foreignKey' => 'menu_id'],
        ],
    ];

    /**
     * O gün için geçerli birim fiyat (kuruş).
     *
     * İstisna girilmişse o, yoksa ürünün kendi fiyatı. Sözleşmedeki
     * `DailyMenu.items[].price` bu değerdir: müşteri gördüğü fiyatla
     * ödenecek fiyatı ayrı hesaplamaz.
     *
     * YALNIZ TEK TEK SATIŞ İÇİN. Paket fiyatı bütünün fiyatıdır ve
     * kalemlerin toplamından türetilmez.
     */
    public function effectiveUnitPriceKurus(): int
    {
        if ($this->price_override_kurus !== null) {
            return (int) $this->price_override_kurus;
        }

        return Money::toKurus($this->menu?->menu_price ?? 0);
    }

    /** Ekranda görünecek ad: gün için verilen etiket, yoksa ürünün adı. */
    public function displayName(): string
    {
        $label = trim((string) ($this->label ?? ''));

        return $label !== '' ? $label : (string) ($this->menu?->menu_name ?? '');
    }

    public function getPriceOverrideLiraAttribute(): string
    {
        $kurus = $this->attributes['price_override_kurus'] ?? null;

        return $kurus !== null ? LiraField::toInput((int) $kurus) : '';
    }

    public function setPriceOverrideLiraAttribute(mixed $value): void
    {
        $this->attributes['price_override_kurus'] = trim((string) $value) === ''
            ? null
            : max(0, LiraField::toKurus($value));
    }
}
