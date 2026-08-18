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

    /**
     * Sözleşme hazırlandı, imza bekleniyor.
     *
     * `pending` ile aynı şey DEĞİL: `pending` "henüz fiyatlanmadı" der, bu
     * ise "fiyat kesinleşti, müşterinin imzası bekleniyor". Ayrım
     * tahsilat ekibinin listesini ikiye böler.
     */
    public const string STATUS_AWAITING_CONTRACT = 'awaiting_contract';

    /**
     * Sözleşme imzalandı, ilk dönem ödemesi bekleniyor.
     *
     * ═════════════════════════════════════════════════════════════════
     * BU DURUM ZATEN YAZILIYORDU — SÖZLÜKTE OLMADAN.
     *
     * `ContractService::handOver()` sözleşme onaylandığında durumu
     * `awaiting_payment` yapıyor ve kolon da (32 karakter) bunu kabul
     * ediyor. Ama değer `STATUSES` içinde olmadığı için:
     *   · `POST /activate` "bu durumdayken bu eylem yapılamaz" diye 409,
     *   · `GET /?status=awaiting_payment` "bilinmeyen durum" diye 422,
     *   · liste ekranı hiçbir sekmede göstermiyordu.
     * Yani imzayı almış, parasını bekleyen abonelik SİSTEMDEN KAYBOLUYORDU.
     * Sözlüğe eklemek bir özellik değil, var olan yazmanın karşılığını
     * tanımaktır.
     * ═════════════════════════════════════════════════════════════════
     */
    public const string STATUS_AWAITING_PAYMENT = 'awaiting_payment';

    public const string STATUS_ACTIVE = 'active';

    public const string STATUS_PAUSED = 'paused';

    public const string STATUS_CANCELLED = 'cancelled';

    /**
     * SIRA İŞ AKIŞININ SIRASIDIR, alfabetik değil: talep → sözleşme → ödeme
     * → üretim. Panelin sekme sırası da bunu okuyor ve alfabetik bir liste
     * "iptal edildi"yi en başa koyardı.
     *
     * @var list<string>
     */
    public const array STATUSES = [
        self::STATUS_PENDING,
        self::STATUS_AWAITING_CONTRACT,
        self::STATUS_AWAITING_PAYMENT,
        self::STATUS_ACTIVE,
        self::STATUS_PAUSED,
        self::STATUS_CANCELLED,
    ];

    /**
     * Henüz üretime girmemiş, girmesi beklenen durumlar.
     *
     * Tek yerde duruyor çünkü üç ayrı yer aynı soruyu soruyor
     * (`activate()` kabul listesi, sözleşme devri, panel sekmesi) ve üçü
     * ayrı ayrı sayılsaydı yeni bir ara durum eklendiğinde biri unutulur,
     * o durumdaki abonelikler yine görünmez olurdu.
     *
     * @var list<string>
     */
    public const array STATUSES_BEFORE_ACTIVE = [
        self::STATUS_PENDING,
        self::STATUS_AWAITING_CONTRACT,
        self::STATUS_AWAITING_PAYMENT,
    ];

    public const string MENU_FIXED_LIST = 'fixed_list';

    public const string MENU_DAILY = 'daily_menu';

    /**
     * Tek ödeme modu. `PAYMENT_ACCOUNT` (cari hesap) kaldırıldı — iş modeli
     * cari hesaptan çıktı.
     *
     * Sabit tek değerli kalsa da SİLİNMEDİ: `payment_mode` kolonu duruyor ve
     * kodun ona yazdığı değer tek bir yerden gelmeli. Kolonu da düşürmek
     * abonelik kulvarının işi.
     */
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
            self::STATUS_AWAITING_CONTRACT => 'lang:veykemtu.bridgeapi::subscription.status_awaiting_contract',
            self::STATUS_AWAITING_PAYMENT => 'lang:veykemtu.bridgeapi::subscription.status_awaiting_payment',
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
            self::STATUS_AWAITING_CONTRACT, self::STATUS_AWAITING_PAYMENT => 'info',
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
     * Abonelik açılabilecek müşteriler — HEPSİ.
     *
     * `bld_account_type = 'corporate'` filtresi KALDIRILDI: kurumsal sipariş
     * kapısı (`CustomerGate`) kalktı ve herkes sipariş verebiliyor. Filtre
     * kalsaydı, sipariş verebilen bir müşteriye abonelik açılamazdı — kural
     * artık bir yerde açık, öbür yerde kapalı olurdu.
     *
     * Kolon serbest metin etiket olarak duruyor; listeleme sırası hâlâ
     * ticari unvana göre, çünkü abone çoğunlukla bir kurum.
     *
     * @return array<int, string>
     */
    public static function customerOptions(): array
    {
        return ApiCustomer::query()
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

        if ($this->pauseCovering($day) !== null) {
            return false;
        }

        $exception = $this->exceptionFor($date);

        return !($exception !== null && (bool) $exception->skip);
    }

    /**
     * Verilen günü kapsayan YÜRÜRLÜKTEKİ duraklatma (yoksa `null`).
     *
     * ─────────────────────────────────────────────────────────────────
     * İKİ SORU AYRILDI: "duraklatma satırı var mı" ve "o gün duraklatma
     * yürürlükte mi".
     *
     * Eskiden `runsOnDate()` yalnız `status !== active` diye bakıyordu ve
     * `pause()` durumu HEMEN `paused` yapıyordu. Sonuç: yönetici yarın
     * için duraklatma girdiğinde BUGÜNÜN üretimi de sessizce kesiliyordu —
     * panelin varsayılanı da yarındı, yani en sık yapılan hareket en
     * pahalı hatayı üretiyordu. Mutfak siparişi hiç görmüyor, kimse hata
     * almıyor ve eksik yemek ancak teslimatta anlaşılıyordu.
     *
     * `cancelled_at` DOLU OLAN SATIR SAYILMAZ: başlamadan geri alınmış bir
     * duraklatma hiç yaşanmamıştır (`resume()` sınıf yorumu).
     * ─────────────────────────────────────────────────────────────────
     */
    public function pauseCovering(Carbon $date): ?SubscriptionPause
    {
        $day = $date->copy()->startOfDay();

        foreach ($this->pauses as $pause) {
            if ($pause->cancelled_at !== null) {
                continue;
            }

            $start = $pause->start_date->copy()->startOfDay();
            $end = $pause->end_date->copy()->startOfDay();

            // TERS ARALIK GÜVENLİĞİ: `end < start` olan eski satırlar
            // (`cancelled_at` göçünden önce `resume()` ile bozulmuş olanlar)
            // hiçbir günü kapsamamalı; `betweenIncluded` orada tanımsız.
            if ($end->lt($start)) {
                continue;
            }

            if ($day->betweenIncluded($start, $end)) {
                return $pause;
            }
        }

        return null;
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
