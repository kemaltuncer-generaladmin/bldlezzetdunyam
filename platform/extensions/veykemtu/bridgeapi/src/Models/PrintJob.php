<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Cart\Models\Order;
use Igniter\Flame\Database\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Basılan fişlerin denetim kaydı — `docs/02-veri-modeli.md` §2.2.
 *
 * KDS kendi kalıcı kuyruğunu diskte tutar; bu tablo **yalnızca denetim**
 * içindir: hangi fiş, hangi cihazda, ne zaman basıldı.
 *
 * `(order_id, type)` çifti benzersizdir — aynı fiş iki kez kaydedilmez.
 * Bu, KDS'in ağ hatasında ack'i tekrar göndermesini zararsız kılar
 * (`docs/10-test-kabul.md` S4).
 *
 * @property int $id
 * @property int $order_id
 * @property string $type
 * @property Carbon|null $printed_at
 * @property int|null $device_id
 */
class PrintJob extends Model
{
    public const string TYPE_KITCHEN = 'mutfak';

    public const string TYPE_CUSTOMER = 'musteri';

    public const array TYPES = [self::TYPE_KITCHEN, self::TYPE_CUSTOMER];

    protected $table = 'veykemtu_print_jobs';

    protected $guarded = [];

    protected $casts = [
        'printed_at' => 'datetime',
    ];

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class, 'order_id');
    }

    public function device(): BelongsTo
    {
        return $this->belongsTo(KitchenDevice::class, 'device_id');
    }

    /**
     * Fiş basımını kaydeder. İdempotenttir.
     *
     * İlk kayıt kazanır: ikinci çağrı `printed_at`'i **değiştirmez**, çünkü
     * denetim sorusu "ilk ne zaman basıldı"dır, "son ne zaman denendi" değil.
     */
    public static function record(
        int $orderId,
        string $type,
        Carbon $printedAt,
        ?int $deviceId,
    ): self {
        $job = static::firstOrNew([
            'order_id' => $orderId,
            'type' => $type,
        ]);

        if (!$job->exists) {
            $job->printed_at = $printedAt;
            $job->device_id = $deviceId;
            $job->save();
        }

        return $job;
    }

    public static function printedAtFor(int $orderId, string $type): ?Carbon
    {
        return static::where('order_id', $orderId)
            ->where('type', $type)
            ->value('printed_at');
    }
}
