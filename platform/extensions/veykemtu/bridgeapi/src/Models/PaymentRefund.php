<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Cart\Models\Order;
use Igniter\Flame\Database\Model;

/**
 * Ödeme iadesi kaydı — B-15.
 *
 * Tablo K-13 ile doğdu (`2026_08_11_000004`) ama bugüne kadar hiçbir
 * arayüzü yoktu: iadeler yazılıyor, kimse görmüyordu. `manual` durumundaki
 * bir iade tanımı gereği bir insanın para göndermesini bekliyor — görünmeyen
 * bir bekleme listesi, hiç yapılmayan bir iş demek.
 *
 * MODEL SALT OKUMA + TEK ALAN GÜNCELLEME İÇİN. İade kaydını yaratan yer
 * `Veykemtu\Payment\Refunds\RefundManager`; buradan yeni iade açılmaz.
 * Panelin yapabildiği tek yazma işlemi, `manual` bir iadeyi "ödendi" olarak
 * işaretlemek.
 */
class PaymentRefund extends Model
{
    /** Sağlayıcı iadeyi aldı ve tamamladı. */
    public const string STATUS_SUCCEEDED = 'succeeded';

    /** Sağlayıcıya gitti, sonucu bekleniyor. */
    public const string STATUS_PENDING = 'pending';

    /** Elle para gönderilmesi gerekiyor — panelin takip ettiği durum. */
    public const string STATUS_MANUAL = 'manual';

    /** Sağlayıcı reddetti; `error` sütununda sebebi var. */
    public const string STATUS_FAILED = 'failed';

    protected $table = 'veykemtu_payment_refunds';

    /** `created_at` yazan `RefundManager`, `updated_at` sütunu yok. */
    public $timestamps = false;

    protected $guarded = [];

    protected $casts = [
        'order_id' => 'integer',
        'revision_id' => 'integer',
        'amount_kurus' => 'integer',
        'created_at' => 'datetime',
        'settled_at' => 'datetime',
    ];

    /**
     * @var array<string, array<string, mixed>>
     */
    public $relation = [
        'belongsTo' => [
            'order' => [Order::class, 'foreignKey' => 'order_id'],
        ],
    ];

    /**
     * Liste filtresi için durum seçenekleri.
     *
     * @return array<string, string>
     */
    public static function statusOptions(): array
    {
        return [
            self::STATUS_MANUAL => lang('veykemtu.bridgeapi::refund.status_manual'),
            self::STATUS_PENDING => lang('veykemtu.bridgeapi::refund.status_pending'),
            self::STATUS_FAILED => lang('veykemtu.bridgeapi::refund.status_failed'),
            self::STATUS_SUCCEEDED => lang('veykemtu.bridgeapi::refund.status_succeeded'),
        ];
    }

    /** Bu iade hâlâ bir insanın elini bekliyor mu? */
    public function needsAction(): bool
    {
        return in_array($this->status, [self::STATUS_MANUAL, self::STATUS_FAILED], true);
    }
}
