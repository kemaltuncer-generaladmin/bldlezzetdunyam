<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Cart\Models\Menu;
use Igniter\Flame\Database\Builder;
use Igniter\Flame\Database\Model;
use Illuminate\Support\Carbon;
use Veykemtu\BridgeApi\Admin\LiraField;

/**
 * Abonelik kuralı — `docs/11-yol-haritasi.md` §7.5 (F2-09).
 *
 * Bu bir SİPARİŞ DEĞİL, sipariş üreten kuraldır. Gece işi `runsOnDate()` true
 * olan her (abonelik × teslimat noktası) için o günün siparişini üretir.
 * Kural değişse bile üretilmiş sipariş değişmez.
 */
class Subscription extends Model
{
    /** Talep: müşteri açtı, admin fiyatlandırıp `active` yapacak. */
    public const string STATUS_PENDING = 'pending';

    public const string STATUS_ACTIVE = 'active';

    public const string STATUS_PAUSED = 'paused';

    public const string STATUS_CANCELLED = 'cancelled';

    /** @var list<string> */
    public const array STATUSES = [
        self::STATUS_PENDING,
        self::STATUS_ACTIVE,
        self::STATUS_PAUSED,
        self::STATUS_CANCELLED,
    ];

    public const string MENU_FIXED_LIST = 'fixed_list';

    public const string MENU_DAILY = 'daily_menu';

    public const string PAYMENT_ACCOUNT = 'account';

    public const string PAYMENT_PREPAID = 'prepaid_monthly';

    protected $table = 'veykemtu_subscriptions';

    public $timestamps = true;

    protected $guarded = [];

    protected $casts = [
        'customer_id' => 'integer',
        'location_id' => 'integer',
        'start_date' => 'date',
        'end_date' => 'date',
        'service_days' => 'array',
        'default_quantity' => 'integer',
        'agreed_unit_price_kurus' => 'integer',
        'created_by' => 'integer',
    ];

    /** @var array<string, array<string, mixed>> */
    public $relation = [
        'hasMany' => [
            'lines' => [SubscriptionLine::class, 'foreignKey' => 'subscription_id'],
            'delivery_points' => [SubscriptionDeliveryPoint::class, 'foreignKey' => 'subscription_id'],
            'pauses' => [SubscriptionPause::class, 'foreignKey' => 'subscription_id'],
            'exceptions' => [SubscriptionException::class, 'foreignKey' => 'subscription_id'],
        ],
        'belongsTo' => [
            'customer' => [
                ApiCustomer::class,
                'foreignKey' => 'customer_id',
                'otherKey' => 'customer_id',
            ],
        ],
    ];

    public function scopeActive(Builder $query): Builder
    {
        return $query->where('status', self::STATUS_ACTIVE);
    }

    /** @return array<string, string> */
    public static function statusOptions(): array
    {
        return [
            self::STATUS_PENDING => 'lang:veykemtu.bridgeapi::subscription.status_pending',
            self::STATUS_ACTIVE => 'lang:veykemtu.bridgeapi::subscription.status_active',
            self::STATUS_PAUSED => 'lang:veykemtu.bridgeapi::subscription.status_paused',
            self::STATUS_CANCELLED => 'lang:veykemtu.bridgeapi::subscription.status_cancelled',
        ];
    }

    public function statusCssClass(): string
    {
        return match ($this->status) {
            self::STATUS_ACTIVE => 'success',
            self::STATUS_PENDING => 'info',
            self::STATUS_PAUSED => 'warning',
            default => 'secondary',
        };
    }

    /** @return array<int, string> */
    public static function dayOptions(): array
    {
        return [
            1 => 'lang:veykemtu.bridgeapi::subscription.day_1',
            2 => 'lang:veykemtu.bridgeapi::subscription.day_2',
            3 => 'lang:veykemtu.bridgeapi::subscription.day_3',
            4 => 'lang:veykemtu.bridgeapi::subscription.day_4',
            5 => 'lang:veykemtu.bridgeapi::subscription.day_5',
            6 => 'lang:veykemtu.bridgeapi::subscription.day_6',
            7 => 'lang:veykemtu.bridgeapi::subscription.day_7',
        ];
    }

    /** @return array<int, string> */
    public static function menuOptions(): array
    {
        return Menu::query()
            ->where('menu_status', true)
            ->orderBy('menu_name')
            ->pluck('menu_name', 'menu_id')
            ->map(static fn($name): string => (string) $name)
            ->all();
    }

    /**
     * Admin formundaki TL alanı ↔ `agreed_unit_price_kurus`. Boş = null
     * (pending talep fiyatsız kalır).
     */
    public function getAgreedPriceLiraAttribute(): string
    {
        $kurus = $this->attributes['agreed_unit_price_kurus'] ?? null;

        return $kurus !== null ? LiraField::toInput((int) $kurus) : '';
    }

    public function setAgreedPriceLiraAttribute(mixed $value): void
    {
        $this->attributes['agreed_unit_price_kurus'] = trim((string) $value) === ''
            ? null
            : LiraField::toKurus($value);
    }

    /**
     * Bu abonelik verilen günde sipariş üretmeli mi?
     *
     * Aktif + dönem içi + service_days'te + duraklatma dışında + istisna-skip
     * değilse. Bileşke: kapalı gün (tatil) komut tarafında ayrıca elenir.
     */
    public function runsOnDate(Carbon $date): bool
    {
        if ($this->status !== self::STATUS_ACTIVE) {
            return false;
        }

        $day = $date->copy()->startOfDay();

        if ($day->lt($this->start_date->copy()->startOfDay())) {
            return false;
        }
        if ($this->end_date !== null && $day->gt($this->end_date->copy()->startOfDay())) {
            return false;
        }

        $days = array_map('intval', $this->service_days ?? []);
        if (!in_array($date->dayOfWeekIso, $days, true)) {
            return false;
        }

        foreach ($this->pauses as $pause) {
            if ($day->betweenIncluded(
                $pause->start_date->copy()->startOfDay(),
                $pause->end_date->copy()->startOfDay(),
            )) {
                return false;
            }
        }

        $exception = $this->exceptionFor($date);

        return !($exception !== null && (bool) $exception->skip);
    }

    /** Verilen gün için üretilecek adet (istisna varsa onu, yoksa varsayılanı). */
    public function quantityForDate(Carbon $date): int
    {
        return $this->quantityOverrideFor($date) ?? (int) $this->default_quantity;
    }

    /** Verilen gün için tek-günlük adet istisnası (yoksa null). */
    public function quantityOverrideFor(Carbon $date): ?int
    {
        $exception = $this->exceptionFor($date);

        return $exception !== null && $exception->quantity_override !== null
            ? (int) $exception->quantity_override
            : null;
    }

    private function exceptionFor(Carbon $date): ?SubscriptionException
    {
        /** @var SubscriptionException|null */
        return $this->exceptions->first(
            static fn(SubscriptionException $e): bool => $e->service_date->isSameDay($date),
        );
    }
}
