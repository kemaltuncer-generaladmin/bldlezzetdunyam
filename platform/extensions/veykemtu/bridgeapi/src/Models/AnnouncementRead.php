<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;
use Illuminate\Support\Carbon;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Bir müşterinin bir duyuruyla ilişkisi: gördü mü, kapattı mı?
 *
 * MÜŞTERİ BAŞINA TEK SATIR (`UNIQUE(announcement_id, customer_id)`). İki
 * damga ayrı ayrı doluyor ve ikisi de ilk yazıldıklarında donuyor:
 *
 *   `seen_at`      duyuru ekranda çizildi. Listeden DÜŞÜRMEZ.
 *   `dismissed_at` müşteri kapattı. Listeden DÜŞÜRÜR.
 *
 * "İlk anı koru" kuralı ikisi için de geçerli ve idempotentliğin ta
 * kendisi: istemci aynı ucu ağ hatasında tekrar çağırır, çağırmalıdır da.
 * Damgayı her çağrıda tazeleseydik "bu duyuru müşteriye ne zaman ulaştı"
 * sorusunun cevabı, en son ne zaman baktığına dönüşürdü.
 *
 * @property int $id
 * @property int $announcement_id
 * @property int $customer_id
 * @property Carbon|null $seen_at
 * @property Carbon|null $dismissed_at
 */
class AnnouncementRead extends Model
{
    protected $table = 'veykemtu_announcement_reads';

    /**
     * Damga kolonları BİZDE; çekirdeğin `created_at`/`updated_at` çifti bu
     * tabloda yok. Açık bırakılsaydı her yazma var olmayan kolonlara
     * değer koymaya çalışırdı.
     */
    public $timestamps = false;

    protected $guarded = [];

    protected $casts = [
        'announcement_id' => 'integer',
        'customer_id' => 'integer',
        'seen_at' => 'datetime',
        'dismissed_at' => 'datetime',
    ];

    /** @var array<string, array<string, mixed>> */
    public $relation = [
        'belongsTo' => [
            'announcement' => [Announcement::class, 'foreignKey' => 'announcement_id'],
            'customer' => [ApiCustomer::class, 'foreignKey' => 'customer_id'],
        ],
    ];

    /**
     * Damgayı YALNIZCA boşsa yazar; satır yoksa açar.
     *
     * `firstOrCreate` + koşullu güncelleme yerine tek bir `updateOrCreate`
     * yazılabilirdi ama o, ikinci çağrıda ilk anı EZERDİ. Buradaki iki
     * adım, sözleşmenin "idempotenttir ve ilk görülme anını değiştirmez"
     * cümlesinin birebir karşılığıdır.
     *
     * Yarış durumunda benzersiz kısıt devreye girer: iki eşzamanlı istekten
     * biri kısıt hatası alır, `firstOrCreate` yeniden okur ve aynı satırı
     * bulur. Kısıt olmasaydı iki satır oluşur, kapatma işareti bunlardan
     * birine yazılır ve duyuru bazen kapanmış bazen kapanmamış görünürdü.
     */
    public static function stamp(int $announcementId, int $customerId, string $column): self
    {
        $row = self::firstOrCreate([
            'announcement_id' => $announcementId,
            'customer_id' => $customerId,
        ]);

        if ($row->{$column} === null) {
            $row->{$column} = BusinessTime::forStorage(Carbon::now());
            $row->save();
        }

        return $row;
    }
}
