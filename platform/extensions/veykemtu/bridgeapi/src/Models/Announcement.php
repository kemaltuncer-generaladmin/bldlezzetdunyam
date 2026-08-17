<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Carbon;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Uygulama-içi duyuru — `docs/openapi.yaml` §Duyuru.
 *
 * PUSH (FCM) YOK: duyuru yalnız istemci açıkken çekilir. Bu, "okundu mu"
 * sorusunun cevabını da değiştirir — işaret bildirimin tesliminden değil,
 * duyurunun EKRANDA ÇİZİLMESİNDEN doğar (`AnnouncementRead::$seen_at`).
 *
 * ## Süzgeç neden burada, istemcide değil
 *
 * Üç istemci var ve üçü de aynı üç kuralı uygulamak zorunda: yayında mı,
 * pencere içinde mi, bu müşteriye mi. Kural istemciye bırakılsaydı biri
 * unuturdu; dahası, saati kaymış bir telefon süresi dolmuş duyuruyu
 * göstermeye devam ederdi. `visibleTo()` bu kuralın TEK kopyasıdır.
 *
 * @property int $id
 * @property string|null $title
 * @property string $body
 * @property string|null $image_path
 * @property string $placement
 * @property string $severity
 * @property string $style
 * @property string|null $action_label
 * @property string|null $action_type
 * @property string|null $action_value
 * @property string $audience
 * @property Carbon|null $starts_at
 * @property Carbon|null $ends_at
 * @property int $priority
 * @property string $status
 * @property bool $dismissible
 * @property int|null $created_by
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
class Announcement extends Model
{
    /** Yazılıyor, henüz kimse görmüyor. */
    public const string STATUS_DRAFT = 'draft';

    public const string STATUS_PUBLISHED = 'published';

    /** Yayından kaldırıldı ama SİLİNMEDİ — geçmiş duyurular kayıt değeridir. */
    public const string STATUS_ARCHIVED = 'archived';

    /** @var list<string> */
    public const array STATUSES = [
        self::STATUS_DRAFT,
        self::STATUS_PUBLISHED,
        self::STATUS_ARCHIVED,
    ];

    public const string AUDIENCE_ALL = 'all';

    public const string AUDIENCE_SUBSCRIBERS = 'subscribers';

    public const string AUDIENCE_NON_SUBSCRIBERS = 'non_subscribers';

    /** @var list<string> */
    public const array AUDIENCES = [
        self::AUDIENCE_ALL,
        self::AUDIENCE_SUBSCRIBERS,
        self::AUDIENCE_NON_SUBSCRIBERS,
    ];

    /** Ekranın üstünde ince bant. */
    public const string STYLE_BANNER = 'banner';

    /** Akışın içinde kart. */
    public const string STYLE_CARD = 'card';

    /** @var list<string> */
    public const array STYLES = [self::STYLE_BANNER, self::STYLE_CARD];

    public const string SEVERITY_INFO = 'info';

    public const string SEVERITY_WARNING = 'warning';

    public const string SEVERITY_CRITICAL = 'critical';

    /** @var list<string> */
    public const array SEVERITIES = [
        self::SEVERITY_INFO,
        self::SEVERITY_WARNING,
        self::SEVERITY_CRITICAL,
    ];

    protected $table = 'veykemtu_announcements';

    /** Gerekçe `PrintJob::$timestamps` üzerinde — çekirdek `false` ile geliyor. */
    public $timestamps = true;

    protected $guarded = [];

    protected $casts = [
        'starts_at' => 'datetime',
        'ends_at' => 'datetime',
        'priority' => 'integer',
        'dismissible' => 'boolean',
        'created_by' => 'integer',
    ];

    /** @var array<string, array<string, mixed>> */
    public $relation = [
        'hasMany' => [
            'reads' => [AnnouncementRead::class, 'foreignKey' => 'announcement_id'],
        ],
    ];

    /**
     * Şu anda, bu kitleye görünen duyurular.
     *
     * ZAMAN KARŞILAŞTIRMASI `BusinessTime::forStorage` İLE YAPILIYOR, çıplak
     * `Carbon::now()` ile DEĞİL. Eloquent bir `datetime` alanını okurken
     * PHP'nin varsayılan zaman dilimini (Europe/Istanbul), `Carbon::now()`
     * ise uygulama dilimini (UTC) veriyor; karşılaştırma üç saat kayardı ve
     * "17:00'de başlasın" denen duyuru 14:00'te belirirdi.
     *
     * KAPATILMIŞ DUYURULAR BURADA ELENMEZ — o süzgeç müşteriye bağlı ve
     * `AnnouncementController` içinde, tek bir okumayla yapılıyor. Buraya
     * bir alt sorgu olarak konsaydı her satır için ayrı bir sorgu doğardı.
     *
     * @param Builder<self> $query
     * @return Builder<self>
     */
    public function scopeVisibleTo(Builder $query, bool $isSubscriber): Builder
    {
        $now = BusinessTime::forStorage(Carbon::now());

        return $query
            ->where('status', self::STATUS_PUBLISHED)
            ->where(static fn(Builder $q): Builder => $q
                ->whereNull('starts_at')
                ->orWhere('starts_at', '<=', $now))
            ->where(static fn(Builder $q): Builder => $q
                ->whereNull('ends_at')
                ->orWhere('ends_at', '>=', $now))
            ->whereIn('audience', self::audiencesFor($isSubscriber));
    }

    /**
     * Bu müşterinin görebileceği kitle etiketleri.
     *
     * `all` HER ZAMAN LİSTEDE: kitlesi belirtilmemiş bir duyuruyu kimsenin
     * görmemesi, yazan kişinin en çok şaşıracağı davranış olurdu.
     *
     * @return list<string>
     */
    public static function audiencesFor(bool $isSubscriber): array
    {
        return [
            self::AUDIENCE_ALL,
            $isSubscriber ? self::AUDIENCE_SUBSCRIBERS : self::AUDIENCE_NON_SUBSCRIBERS,
        ];
    }
}
