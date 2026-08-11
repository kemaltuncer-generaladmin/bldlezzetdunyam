<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;
use Illuminate\Support\Carbon;

/**
 * BBD Store'dan gelen sipariş — **yalnız ses ve fiş** (K-16).
 *
 * BLD'nin `orders` tablosuna girmez ve hiçbir istatistiğe karışmaz;
 * gerekçe göç dosyasında.
 *
 * @property int $id
 * @property string $external_id
 * @property string|null $order_number
 * @property array $payload_json
 * @property Carbon|null $received_at
 * @property Carbon|null $printed_at
 */
class BbdReceipt extends Model
{
    protected $table = 'veykemtu_bbd_receipts';

    protected $guarded = [];

    /**
     * Damgalar KAPALI: tablonun `created_at`/`updated_at` sütunu yok.
     * `received_at` zaten kaydın doğduğu anı taşıyor ve ikinci bir zaman
     * damgası yalnız karışıklık üretirdi.
     */
    public $timestamps = false;

    protected $casts = [
        'payload_json' => 'array',
        'received_at' => 'datetime',
        'printed_at' => 'datetime',
    ];

    public function isPrinted(): bool
    {
        return $this->printed_at !== null;
    }
}
