<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;

/**
 * Abonelik duraklatması — iptal değil; aralıkta üretim durur.
 *
 * `cancelled_at` DOLU OLAN SATIR HİÇ YAŞANMAMIŞ SAYILIR: başlamadan geri
 * alınan bir duraklatmadır (`SubscriptionController::resume()`). Satır
 * silinmiyor çünkü "girildi ve vazgeçildi" de bir karar; ama hiçbir günü
 * kapsamıyor (`Subscription::pauseCovering()`).
 */
class SubscriptionPause extends Model
{
    protected $table = 'veykemtu_subscription_pauses';

    public $timestamps = false;

    protected $guarded = [];

    protected $casts = [
        'subscription_id' => 'integer',
        'start_date' => 'date',
        'end_date' => 'date',
        'cancelled_at' => 'datetime',
    ];

    /** Bu duraklatma yürürlükte mi (iptal edilmemiş ve aralığı tutarlı mı). */
    public function isLive(): bool
    {
        return $this->cancelled_at === null
            && !$this->end_date->copy()->startOfDay()->lt($this->start_date->copy()->startOfDay());
    }
}
