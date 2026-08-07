<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;
use Illuminate\Support\Carbon;

/** Resmî tatil / kapalı gün — üretim bu günleri atlar (global). */
class ClosedDay extends Model
{
    protected $table = 'veykemtu_closed_days';

    public $timestamps = false;

    protected $guarded = [];

    protected $casts = [
        'closed_on' => 'date',
    ];

    public static function isClosed(Carbon $date): bool
    {
        return self::query()
            ->whereDate('closed_on', $date->toDateString())
            ->exists();
    }
}
