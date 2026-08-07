<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;

/** Abonelik duraklatması — iptal değil; aralıkta üretim durur. */
class SubscriptionPause extends Model
{
    protected $table = 'veykemtu_subscription_pauses';

    public $timestamps = false;

    protected $guarded = [];

    protected $casts = [
        'subscription_id' => 'integer',
        'start_date' => 'date',
        'end_date' => 'date',
    ];
}
