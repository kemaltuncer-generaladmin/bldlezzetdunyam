<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;

/**
 * Cari hesap ödeme niyeti — B-14 / W-12.
 *
 * "Müşteri borcunun şu kadarını ödemeye başladı" olayını temsil eder.
 * Defterden farkı: defter GEÇMİŞTİR (değişmez), bu tablo SÜREÇTİR
 * (`pending` → `succeeded`/`failed`). Ödeme kesinleşince deftere bir alacak
 * satırı doğar ve asıl kayıt orada tutulur; bu satır yalnızca izdir.
 *
 * Tablo gerekçesinin tamamı migration'da:
 * `2026_08_13_000002_create_veykemtu_account_payments_table`.
 */
class AccountPaymentIntent extends Model
{
    public const string STATUS_PENDING = 'pending';

    public const string STATUS_SUCCEEDED = 'succeeded';

    public const string STATUS_FAILED = 'failed';

    /**
     * Defterdeki `reference_type`. Sabit olarak burada duruyor ki ödeme
     * yazan (`SimulationController`) ile okuyanlar aynı dizeyi elle
     * yazmak zorunda kalmasın.
     */
    public const string LEDGER_REFERENCE = 'account_payment';

    protected $table = 'veykemtu_account_payments';

    /** `created_at` elle yazılır, `updated_at` yok — süreç tablosu. */
    public $timestamps = false;

    protected $guarded = [];

    protected $casts = [
        'customer_id' => 'integer',
        'amount_kurus' => 'integer',
        'balance_at_start' => 'integer',
        'created_at' => 'datetime',
        'settled_at' => 'datetime',
    ];

    /**
     * @var array<string, array<string, mixed>>
     */
    public $relation = [
        'belongsTo' => [
            'customer' => [ApiCustomer::class, 'foreignKey' => 'customer_id'],
        ],
    ];

    public function isPending(): bool
    {
        return $this->status === self::STATUS_PENDING;
    }
}
