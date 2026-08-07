<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Carbon;

/**
 * Kurumsal sitedeki "Teklif Al" formundan gelen talep.
 *
 * ## KİŞİSEL VERİ TAŞIR
 *
 * `full_name`, `telephone` ve `email` KVKK kapsamındadır. Bu model
 * **yalnızca** iki yerde okunur: panel ekranı (`Http\Controllers\Admin\
 * QuoteRequests`) ve bu dosyadaki testler. Herkese açık API'den geri
 * DÖNMEZ — `POST /api/quote-requests` yalnızca kaydın alındığını bildirir,
 * kaydın kendisini değil. Yeni bir okuma noktası eklenecekse önce
 * `docs/00-genel-bakis.md` §KVKK okunmalı.
 *
 * Onay zaman damgasız saklanmaz: `kvkk_accepted_at` boş bir kayıt hiç
 * oluşmaz, uç onaysız gönderimi 422 ile reddeder.
 *
 * ## TEKİLLEŞTİRME YOK
 *
 * Aynı kişi formu iki kez gönderirse iki kayıt oluşur ve bu DOĞRUDUR: aynı
 * firma iki farklı etkinlik için iki teklif isteyebilir. İkinciyi "kopya"
 * sayıp yutmak, gerçek bir işi sessizce kaybetmenin en kolay yoludur.
 *
 * @property int $id
 * @property string $full_name
 * @property string|null $organization
 * @property string|null $telephone
 * @property string|null $email
 * @property string|null $service_type
 * @property int|null $headcount
 * @property string|null $frequency
 * @property Carbon|null $start_date
 * @property string|null $location
 * @property string|null $menu_preference
 * @property string|null $kitchen_note
 * @property string|null $message
 * @property Carbon $kvkk_accepted_at
 * @property Carbon|null $submitted_at
 * @property string $status
 * @property string|null $admin_note
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
class QuoteRequest extends Model
{
    /** Yeni gelen talebin durumu. */
    public const string STATUS_NEW = 'yeni';

    /**
     * Takip durumları — panelde değiştirilir, sitede görünmez.
     *
     * Dört kademe var çünkü üçü yetmiyordu: "cevaplandı" ile "kapandı"
     * ayrılmasaydı, teklif gönderilip cevap beklenen talep ile işi
     * kaybettiğimiz talep aynı kutuda kalır ve liste zamanla takip
     * edilemeyecek kadar şişerdi.
     *
     * @var list<string>
     */
    public const array STATUSES = [
        self::STATUS_NEW,
        'okundu',
        'cevaplandi',
        'kapandi',
    ];

    protected $table = 'veykemtu_quote_requests';

    /** Gerekçe `SitePost::$timestamps` üzerinde — aynı çekirdek varsayılanı. */
    public $timestamps = true;

    protected $guarded = [];

    /** @var array<string, string> */
    protected $casts = [
        'headcount' => 'integer',
        'start_date' => 'date',
        'kvkk_accepted_at' => 'datetime',
        'submitted_at' => 'datetime',
    ];

    /**
     * Panelin varsayılan sırası: en yeni talep en üstte.
     *
     * `created_at` eşit olan iki kayıt (aynı saniyede gelen iki gönderim)
     * için `id` ikinci ölçüttür; yoksa liste sayfaları arasında sıra
     * kayabilir ve aynı kayıt iki sayfada birden görünür.
     *
     * @param  Builder<self>  $query
     */
    public function scopeNewestFirst(Builder $query): void
    {
        $query->orderByDesc('created_at')->orderByDesc('id');
    }

    /** İşlem bekleyen talepler — panel rozetleri ve raporlar için. */
    public function scopeUnread(Builder $query): void
    {
        $query->where('status', self::STATUS_NEW);
    }

    /**
     * Durum etiketlerinin çeviri anahtarları.
     *
     * Etiket metni koda yazılmıyor (`AGENTS.md` §4): hem form açılır listesi
     * hem liste rozeti buradan besleniyor, iki yerde ayrı yazılsaydı biri
     * güncellenip diğeri unutulurdu.
     *
     * @return array<string, string>
     */
    public static function statusOptions(): array
    {
        $options = [];

        foreach (self::STATUSES as $status) {
            $options[$status] = 'lang:veykemtu.bridgeapi::quoterequest.status_'.$status;
        }

        return $options;
    }

    /**
     * Rozet rengi.
     *
     * Renk modelde duruyor çünkü durum makinesinin anlamı burada: "yeni"
     * bir eylem çağrısıdır (dikkat çeken renk), "kapandı" arşivdir (sönük).
     * Blade şablonunda bir `match` bırakmak, ikinci bir ekran eklendiğinde
     * renklerin ayrışmasına yol açardı.
     */
    public function statusCssClass(): string
    {
        return match ($this->status) {
            self::STATUS_NEW => 'warning',
            'okundu' => 'info',
            'cevaplandi' => 'success',
            default => 'secondary',
        };
    }
}
