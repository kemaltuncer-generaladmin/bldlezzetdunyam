<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Cart\Models\Order;
use Igniter\Flame\Database\Model;

/**
 * Mutfakta yapılan sipariş düzenlemesinin kaydı — B-17.
 *
 * K-12 ile doğdu ve yalnızca KDS'den görülebiliyordu. Panelde hiç izi
 * yoktu: "müşteri tutarın değiştiğini söylüyor, ne olmuş?" sorusunun
 * cevabı yalnızca mutfak ekranındaydı ve o ekran sipariş kapandıktan
 * sonra geçmişi göstermiyor.
 *
 * SALT OKUNUR. Revizyon `Services\OrderEditor` tarafından yazılır ve
 * `before_json`/`after_json` o anın tam anlık görüntüsüdür — düzenlenirse
 * denetim değerini tamamen kaybeder.
 */
class OrderRevision extends Model
{
    protected $table = 'veykemtu_order_revisions';

    /** `created_at` `OrderEditor` tarafından yazılır; `updated_at` yok. */
    public $timestamps = false;

    protected $guarded = [];

    protected $casts = [
        'order_id' => 'integer',
        'revision_no' => 'integer',
        'before_json' => 'array',
        'after_json' => 'array',
        'subtotal_before_kurus' => 'integer',
        'subtotal_after_kurus' => 'integer',
        'total_before_kurus' => 'integer',
        'total_after_kurus' => 'integer',
        'refund_kurus' => 'integer',
        'extra_charge_kurus' => 'integer',
        'created_at' => 'datetime',
    ];

    /**
     * @var array<string, array<string, mixed>>
     */
    public $relation = [
        'belongsTo' => [
            'order' => [Order::class, 'foreignKey' => 'order_id'],
        ],
    ];

    /** Toplamdaki değişim (kuruş). Pozitif = tutar arttı. */
    public function totalDelta(): int
    {
        return (int) $this->total_after_kurus - (int) $this->total_before_kurus;
    }
}
