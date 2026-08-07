<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;

/** Tek-günlük istisna — "yarın 12 porsiyon" veya "yarın atla". */
class SubscriptionException extends Model
{
    protected $table = 'veykemtu_subscription_exceptions';

    public $timestamps = false;

    protected $guarded = [];

    protected $casts = [
        'subscription_id' => 'integer',
        'service_date' => 'date',
        'skip' => 'boolean',
        'quantity_override' => 'integer',
    ];
}
