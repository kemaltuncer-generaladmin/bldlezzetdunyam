<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;

/**
 * Üretim defteri — idempotency kaydı.
 *
 * `UNIQUE(subscription_id, delivery_point_id, service_date)`; yazma servis/
 * komuttan `insertOrIgnore` ile yapılır, bu model çoğunlukla okuma içindir.
 */
class SubscriptionRun extends Model
{
    protected $table = 'veykemtu_subscription_runs';

    public $timestamps = false;

    protected $guarded = [];

    protected $casts = [
        'subscription_id' => 'integer',
        'delivery_point_id' => 'integer',
        'service_date' => 'date',
        'order_id' => 'integer',
    ];
}
