<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;

/** Abonelik teslimat noktası — adres defterinden, nokta başına bir sipariş. */
class SubscriptionDeliveryPoint extends Model
{
    protected $table = 'veykemtu_subscription_delivery_points';

    public $timestamps = false;

    protected $guarded = [];

    protected $casts = [
        'subscription_id' => 'integer',
        'address_id' => 'integer',
        'quantity' => 'integer',
    ];
}
