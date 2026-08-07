<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;

/** Abonelik satırı — diyet/alerjen varyantı (bkz. Subscription). */
class SubscriptionLine extends Model
{
    protected $table = 'veykemtu_subscription_lines';

    public $timestamps = false;

    protected $guarded = [];

    protected $casts = [
        'subscription_id' => 'integer',
        'menu_id' => 'integer',
        'quantity' => 'integer',
        'agreed_unit_price_kurus' => 'integer',
    ];
}
