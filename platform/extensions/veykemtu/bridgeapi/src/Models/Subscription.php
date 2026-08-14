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

    /**
     * Menü kaynağı seçenekleri — admin formundaki `menu_mode` alanı.
     *
     * @return array<string, string>
     */
    public static function menuModeOptions(): array
    {
        return [
            self::MENU_FIXED_LIST => 'lang:veykemtu.bridgeapi::subscription.menu_mode_fixed',
            self::MENU_DAILY => 'lang:veykemtu.bridgeapi::subscription.menu_mode_daily',
        ];
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

    /**
     * Abonelik açılabilecek müşteriler — yalnızca KURUMSAL.
     *
     * Abonelik bir sözleşmedir ve `docs/00` B2B kararına göre sipariş
     * kurumsal hesaplardan alınır. Bireysel bir kayda abonelik açmak,
     * hiçbir zaman sipariş üretemeyecek bir kural yaratırdı
     * (`OrderFactory` o siparişi de aynı kapıdan geçiriyor).
     *
     * @return array<int, string>
     */
    public static function customerOptions(): array
    {
        return ApiCustomer::query()
            ->where('bld_account_type', 'corporate')
            ->orderBy('bld_org_name')
            ->get(['customer_id', 'bld_org_name', 'first_name', 'last_name', 'email'])
            ->mapWithKeys(static fn(ApiCustomer $c): array => [
                (int) $c->customer_id => trim(
                    ($c->bld_org_name ?: trim($c->first_name.' '.$c->last_name))
                    .' — '.$c->email,
                ),
            ])
            ->all();
    }

    /**
     * Önümüzdeki servis günleri — takvim önizlemesi (B-16).
     *
     * NEDEN AYRI BİR HESAP DEĞİL DE MEVCUT KURALLARIN ÜSTÜNDE: `runsOnDate()`
     * ve `quantityForDate()` gece üretim işinin kullandığı metotların ta
     * kendisi. Takvim kendi mantığını yazsaydı, ekranda görünen gün listesi
     * ile gerçekte üretilen siparişler zamanla ayrışırdı — ve bu ayrışmanın
     * fark edileceği yer mutfak olurdu.
     *
     * Kapalı günler (`veykemtu_closed_days`) burada da eleniyor; komut
     * tarafında da eleniyor (`SubscriptionGenerateCommand`). İkisi aynı
     * tabloyu okuyor, yani tek kaynak.
     *
     * @return list<array{date: Carbon, quantity: int, closed: bool, note: string|null}>
     */
    public function upcomingServiceDays(Carbon $from, int $days = 30): array
    {
        $closed = ClosedDay::query()
            ->whereBetween('closed_on', [
                $from->toDateString(),
                $from->copy()->addDays($days)->toDateString(),
            ])
            ->pluck('description', 'closed_on')
            ->all();

        $result = [];
        $cursor = $from->copy()->startOfDay();

        for ($i = 0; $i < $days; $i++, $cursor->addDay()) {
            if (!$this->runsOnDate($cursor)) {
                continue;
            }

            $key = $cursor->toDateString();
            $isClosed = array_key_exists($key, $closed);

            $result[] = [
                'date' => $cursor->copy(),
                'quantity' => $this->quantityForDate($cursor),
                'closed' => $isClosed,
                'note' => $isClosed ? ($closed[$key] ?? null) : null,
            ];
        }

        return $result;
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
