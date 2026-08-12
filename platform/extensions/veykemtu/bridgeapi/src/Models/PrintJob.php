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
 * `(order_id, type, revision)` ÜÇLÜSÜ benzersizdir — aynı fişin aynı sürümü
 * iki kez kaydedilmez. Bu, KDS'in ağ hatasında ack'i tekrar göndermesini
 * zararsız kılar (`docs/10-test-kabul.md` S4).
 *
 * REVİZYON K-20 İLE GELDİ. Öncesinde tekillik `(order_id, type)` idi ve
 * düzenlenen siparişin yeniden basılan fişinin ack'i sessizce yutuluyordu;
 * `printedAtFor()` hep ilk basımın saatini döndürdüğü için yeniden basılan
 * kâğıt, yerini aldığı eski kâğıdın saatiyle damgalanıyordu.
 *
 * @property int $id
 * @property int $order_id
 * @property string $type
 * @property int $revision
 * @property Carbon|null $printed_at
 * @property int|null $device_id
 */
class PrintJob extends Model
{
    public const string TYPE_KITCHEN = 'mutfak';

    public const string TYPE_CUSTOMER = 'musteri';

    /**
     * Kurye fişi (K-14) — ad, telefon, adres, tahsil edilecek tutar.
     *
     * Yalnız `delivery` siparişte basılır; gel-al'da kurye yoktur.
     */
    public const string TYPE_COURIER = 'kurye';

    public const array TYPES = [
        self::TYPE_KITCHEN,
        self::TYPE_CUSTOMER,
        self::TYPE_COURIER,
    ];

    protected $table = 'veykemtu_print_jobs';

    protected $guarded = [];

    /**
     * DAMGALAR AÇIK OLMALI — TastyIgniter'ın modeli `false` ile geliyor.
     *
     * `Igniter\Flame\Database\Model` `public $timestamps = false;`
     * tanımlıyor ve alt sınıf bunu devralıyor. Göç `timestamps()` ile
     * sütunları açsa bile hiçbir zaman yazılmıyorlardı: sahada tüm
     * satırların `created_at`'i NULL çıktı ("bu kasa ne zaman eklendi?"
     * sorusunun cevabı yoktu).
     */
    public $timestamps = true;

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
     * İlk kayıt kazanır — ama artık **revizyon başına**: ikinci çağrı aynı
     * revizyonun `printed_at`'ini değiştirmez, çünkü denetim sorusu "bu
     * revizyon ilk ne zaman basıldı"dır, "son ne zaman denendi" değil.
     * Revizyon artınca yeni bir satır açılır; eskisi denetim izi olarak
     * yerinde kalır.
     *
     * `$revision` VARSAYILAN `0`: alanı hiç göndermeyen eski KDS sürümleri
     * sıfır kovasına düşer, yani düzenlenmemiş sipariş için davranış
     * bugünküyle birebir aynı kalır.
     */
    public static function record(
        int $orderId,
        string $type,
        Carbon $printedAt,
        ?int $deviceId,
        int $revision = 0,
    ): self {
        $job = static::firstOrNew([
            'order_id' => $orderId,
            'type' => $type,
            'revision' => $revision,
        ]);

        if (!$job->exists) {
            $job->printed_at = $printedAt;
            $job->device_id = $deviceId;
            $job->save();
        }

        return $job;
    }

    public static function printedAtFor(int $orderId, string $type, int $revision = 0): ?Carbon
    {
        return static::where('order_id', $orderId)
            ->where('type', $type)
            ->where('revision', $revision)
            ->value('printed_at');
    }
}
