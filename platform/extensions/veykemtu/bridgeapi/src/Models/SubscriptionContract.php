<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Abonelik sözleşmesi — iş kararı 9.
 *
 * Bir sözleşme, aboneliğin O ANKİ koşullarının DONMUŞ bir fotoğrafıdır:
 * metin (`body_html`), fiyat (`agreed_unit_price_kurus`) ve koşullar
 * (`terms_json`) kayıttan sonra değişmez. Abonelik değişirse yeni bir
 * sözleşme açılır, eskisi olduğu gibi kalır.
 *
 * Durum sözlüğü `docs/openapi.yaml` → `ContractStatus`'tan gelir; Kontrol
 * Merkezi paneli kendi sözlüğünü kullanıyor ve çeviri `controlStatus()`
 * içinde TEK yerde duruyor.
 */
class SubscriptionContract extends Model
{
    /** Metin üretildi, bağlantı henüz gönderilmedi. */
    public const string STATUS_DRAFT = 'draft';

    /** Bağlantı gönderildi, onay bekleniyor. */
    public const string STATUS_SENT = 'sent';

    /** Abone SMS koduyla onayladı — TERMİNAL. */
    public const string STATUS_APPROVED = 'approved';

    /** Bağlantının süresi doldu; yeni bağlantı gerekir. */
    public const string STATUS_EXPIRED = 'expired';

    /** Sözleşme geçersiz kılındı (yeni sürüm ya da iptal). */
    public const string STATUS_CANCELLED = 'cancelled';

    /** @var list<string> */
    public const array STATUSES = [
        self::STATUS_DRAFT,
        self::STATUS_SENT,
        self::STATUS_APPROVED,
        self::STATUS_EXPIRED,
        self::STATUS_CANCELLED,
    ];

    protected $table = 'veykemtu_subscription_contracts';

    public $timestamps = true;

    protected $guarded = [];

    protected $casts = [
        'subscription_id' => 'integer',
        'agreed_unit_price_kurus' => 'integer',
        'term_days' => 'integer',
        'terms_json' => 'array',
        'sent_at' => 'datetime',
        'otp_verified_at' => 'datetime',
        'approved_at' => 'datetime',
        'expires_at' => 'datetime',
        'cancelled_at' => 'datetime',
    ];

    /** @var array<string, array<string, mixed>> */
    public $relation = [
        'belongsTo' => [
            'subscription' => [Subscription::class, 'foreignKey' => 'subscription_id'],
        ],
    ];

    /**
     * Dışarıya söylenen durum.
     *
     * SÜRE DOLMASI SATIRA YAZILMAZ, HESAPLANIR. Yazsaydık, süresi geçen her
     * sözleşmeyi bir zamanlayıcının gezip güncellemesi gerekirdi; o iş bir
     * gün koşmadığında bağlantı ölmüş görünmez ama ölü olurdu. Burada tek
     * kaynak `expires_at` ve imzanın içindeki bitiş anıdır.
     *
     * ONAY VE İPTAL SÜREYİ YENER: onaylanmış bir sözleşme, bağlantısının
     * süresi geçti diye "expired" gösterilemez — imza zaten atılmış.
     */
    public function effectiveStatus(): string
    {
        $status = (string) $this->status;

        if ($status === self::STATUS_APPROVED || $status === self::STATUS_CANCELLED) {
            return $status;
        }

        return $this->isExpired() ? self::STATUS_EXPIRED : $status;
    }

    public function isExpired(): bool
    {
        return $this->expires_at !== null
            && $this->expires_at->lt(BusinessTime::now());
    }

    /**
     * Onay bekliyor mu?
     *
     * `draft` de kabul edilir: yönetici bağlantıyı SMS yerine elden
     * iletmiş olabilir (`send_sms: false`) ve o hâlde kayıt `draft`
     * kalıyor. Bağlantıyı eline geçiren onaylayabilmelidir; yoksa "elden
     * ilet" seçeneği çalışmayan bir bağlantı üretirdi.
     */
    public function isApprovable(): bool
    {
        return in_array($this->effectiveStatus(), [self::STATUS_DRAFT, self::STATUS_SENT], true);
    }

    /**
     * Kontrol Merkezi panelinin sözlüğü — `docs/control/subscriptions.md`.
     *
     * Panel `pending|sent|signed|cancelled|expired` bekliyor, sözleşme
     * (`docs/openapi.yaml`) `draft|sent|approved|expired|cancelled`
     * yayınlıyor. İki sözlük de yayınlanmış birer arayüz; hangisinin
     * "doğru" olduğu sorusunun cevabı yok, tek çeviri noktası olması ise
     * şart. İkinci bir çeviri, iki ekranın aynı sözleşmeyi farklı durumda
     * göstermesi demektir.
     */
    public function controlStatus(): string
    {
        return match ($this->effectiveStatus()) {
            self::STATUS_DRAFT => 'pending',
            self::STATUS_APPROVED => 'signed',
            default => $this->effectiveStatus(),
        };
    }

    /**
     * Donmuş koşullardan tek bir alan.
     *
     * @param  mixed  $default  Alan yoksa dönecek değer.
     */
    public function term(string $key, mixed $default = null): mixed
    {
        $terms = $this->terms_json;

        return is_array($terms) ? ($terms[$key] ?? $default) : $default;
    }
}
