<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;
use Illuminate\Support\Carbon;

/**
 * Abonelik dönem ödemesi — 30 günlük peşin tahsilat niyeti.
 *
 * Bu bir DEFTER SATIRI DEĞİL, bir NİYETTİR: `pending` doğar, sağlayıcı
 * sonucu bildirince `succeeded` ya da `failed` olur. Ayrımın sebebi
 * göçün başındaki nottadır — sağlayıcıya gidip dönmek güvenilmez ve
 * "başladı ama bitmedi" durumu temsil edilebilir olmalı.
 *
 * DIŞARIYA `hash` VERİLİR. Ödeme sayfasının adresi (`/abonelik-odeme-
 * simulasyon/{hash}`) sıralı bir kimlik taşısaydı, bir bağlantıyı eline
 * geçiren komşu numaraları deneyerek başkalarının ödeme sayfasını açardı.
 * API yolunda `{payment}` sayısaldır ama orada abonelik sahipliği ayrıca
 * doğrulanıyor (`SubscriptionPaymentController::owned`).
 */
class SubscriptionPayment extends Model
{
    /** Niyet açıldı, sağlayıcı sonucu bekleniyor. */
    public const string STATUS_PENDING = 'pending';

    /** Tahsilat kesinleşti. Aboneliği `active` yapan tek durum. */
    public const string STATUS_SUCCEEDED = 'succeeded';

    /** Sağlayıcı reddetti ya da doğrulama hakkı tükendi. */
    public const string STATUS_FAILED = 'failed';

    /** Para iade edildi; dönem artık kapsanmıyor. */
    public const string STATUS_REFUNDED = 'refunded';

    /** Dönem uzunluğu — 30 GÜN, takvim ayı değil (`docs/11` §7.5). */
    public const int PERIOD_DAYS = 30;

    /**
     * Yenileme penceresi: ödenmiş dönemin SON 7 GÜNÜ.
     *
     * İKİ ARIZAYI BİRDEN ÖNLÜYOR. Pencere olmasaydı ve yenileme dönem
     * bittiği gün açılsaydı, o sabahın gece üretimi çoktan koşmuş ve
     * abonelik duraklatılmış olurdu — her yenilemede bir günlük yemek
     * düşerdi. Pencere hiç olmasaydı, yani her an ödenebilseydi, abone
     * on iki dönemi peşin açıp iptal ettiğinde elle iade edilecek bir yığın
     * kalırdı.
     */
    public const int RENEWAL_WINDOW_DAYS = 7;

    protected $table = 'veykemtu_subscription_payments';

    /** `created_at` elle yazılıyor, `updated_at` sütunu yok. */
    public $timestamps = false;

    protected $guarded = [];

    protected $casts = [
        'subscription_id' => 'integer',
        'period_start' => 'date',
        'period_end' => 'date',
        'portions_planned' => 'integer',
        'unit_price_kurus' => 'integer',
        'amount_kurus' => 'integer',
        'created_at' => 'datetime',
        'settled_at' => 'datetime',
    ];

    /** @var array<string, array<string, mixed>> */
    public $relation = [
        'belongsTo' => [
            'subscription' => [Subscription::class, 'foreignKey' => 'subscription_id'],
        ],
    ];

    public function isPending(): bool
    {
        return $this->status === self::STATUS_PENDING;
    }

    public function isSucceeded(): bool
    {
        return $this->status === self::STATUS_SUCCEEDED;
    }

    /**
     * Sözleşmedeki `period` alanı — `YYYY-AA`.
     *
     * SAKLAMA BİRİMİ DEĞİL, SUNUM BİÇİMİ. Dönem 30 gündür; istemci ekranında
     * "Eylül dönemi" demek için aya ihtiyaç duyuyor ve o ay dönemin BAŞLADIĞI
     * aydır. Dönemi aya yuvarlayıp saklasaydık ayın 17'sinde başlayan bir
     * abonelikten eksik gün için tam para almış olurduk.
     */
    public function period(): string
    {
        return $this->period_start->format('Y-m');
    }

    /**
     * Bu ödeme verilen servis gününü kapsıyor mu?
     *
     * KARŞILAŞTIRMA TARİH DİZESİYLE, `Carbon` ANIYLA DEĞİL. `date` dönüşümü
     * PHP'nin varsayılan zaman diliminde gece yarısı üretiyor, `BusinessTime`
     * ise Europe/Istanbul'da; ikisi aynı takvim günü için 3 saat farklı ana
     * denk geliyor ve `betweenIncluded` dönemin İLK GÜNÜNÜ kapsam dışı
     * sayıyordu. `YYYY-AA-GG` dizeleri sözlük sırasında zaten takvim
     * sırasındadır ve saat dilimi taşımaz.
     */
    public function covers(Carbon $date): bool
    {
        $gun = $date->toDateString();

        return $gun >= $this->period_start->toDateString()
            && $gun <= $this->period_end->toDateString();
    }

    /**
     * Yenileme ödemesinin açılabileceği ilk gün (`YYYY-AA-GG`).
     *
     * Dönemin son [RENEWAL_WINDOW_DAYS] günü. Gerekçe o sabitin notunda.
     */
    public function renewableFrom(): string
    {
        return $this->period_end->copy()
            ->subDays(self::RENEWAL_WINDOW_DAYS - 1)
            ->toDateString();
    }
}
