<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Admin panelden kasaya gönderilen tek seferlik komut.
 *
 * AYAR DEĞİL, KOMUT. Bir ayar "şu andan itibaren böyle olsun" der ve
 * kalıcıdır; komut "şunu bir kez yap" der ve tüketilir. "Test fişi bas"
 * bir ayar olsaydı, sonsuza kadar açık kalıp her yoklamada fiş bastırırdı.
 *
 * TESLİMAT SAĞLIK YANITIYLA olur; ayrı bir yoklama döngüsü kurmuyoruz.
 * Komutun ne kadar sürede varacağı `health_seconds` ayarına bağlıdır ve
 * yönetici bunu panelden kısaltabilir.
 *
 * @property int $id
 * @property int $device_id
 * @property string $command
 * @property array<string, mixed>|null $payload
 * @property Carbon|null $delivered_at
 * @property Carbon|null $executed_at
 * @property bool|null $succeeded
 * @property string|null $result
 */
class KitchenCommand extends Model
{
    /** Test fişi bas — yazıcının ve kod sayfasının doğrulaması. */
    public const string TEST_RECEIPT = 'test_receipt';

    /** Bir siparişin fişini yeniden bas. `payload.order_id` ve `payload.type`. */
    public const string REPRINT = 'reprint';

    /** Basılamamış işleri kuyruktan düşür. */
    public const string CLEAR_FAILED = 'clear_failed';

    /** Çalan yeni sipariş alarmını sustur. */
    public const string SILENCE_ALARM = 'silence_alarm';

    /** Uygulamayı yeniden başlat; systemd geri getirir. */
    public const string RESTART = 'restart';

    /** @var list<string> */
    public const array ALL = [
        self::TEST_RECEIPT,
        self::REPRINT,
        self::CLEAR_FAILED,
        self::SILENCE_ALARM,
        self::RESTART,
    ];

    /**
     * Teslim edilmiş ama sonucu gelmemiş komut bu süre sonra unutulur.
     *
     * Kasa komutu alıp çöktüyse sonucu hiç gelmez; komut sonsuza kadar
     * "yolda" görünürdü ve yönetici tekrar göndermeye çekinirdi.
     */
    public const int STALE_AFTER_MINUTES = 10;

    protected $table = 'veykemtu_kitchen_commands';

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
        'payload' => 'array',
        'delivered_at' => 'datetime',
        'executed_at' => 'datetime',
        'succeeded' => 'boolean',
    ];

    public function device(): BelongsTo
    {
        return $this->belongsTo(KitchenDevice::class, 'device_id');
    }

    /**
     * Kasaya gönderilmeyi bekleyen komutlar.
     *
     * Teslim edilmiş ama sonucu gelmemiş ESKİ komutlar yeniden gönderilir:
     * kasa komutu alıp çökmüş olabilir. Tekrar göndermek "test fişi"nde
     * fazladan bir kâğıt, "yeniden başlat"ta zararsız; komutun hiç
     * çalışmaması ise sessiz bir başarısızlık.
     *
     * @return \Illuminate\Database\Eloquent\Builder<KitchenCommand>
     */
    public static function pendingFor(int $deviceId)
    {
        $stale = Carbon::now()->subMinutes(self::STALE_AFTER_MINUTES);

        return static::query()
            ->where('device_id', $deviceId)
            ->whereNull('executed_at')
            ->where(fn($q) => $q
                ->whereNull('delivered_at')
                ->orWhere('delivered_at', '<', $stale))
            ->orderBy('id');
    }
}
