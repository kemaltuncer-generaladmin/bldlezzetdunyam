<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Builder;
use Igniter\Flame\Database\Model;
use Veykemtu\BridgeApi\Admin\LiraField;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Cari hesap defteri satırı — append-only (`docs/02 §5` felsefesi).
 *
 * Satır güncellenmez; her olay bir satırdır, güncel bakiye toplamdır. Yazma
 * `AccountLedger` servisinden yapılır (idempotent `insertOrIgnore`); bu model
 * çoğunlukla OKUMA (ekstre) içindir.
 */
class AccountLedgerEntry extends Model
{
    /** Borç: müşterinin bize borcu artar (sipariş/abonelik). */
    public const string TYPE_DEBIT = 'debit';

    /** Alacak: borç azalır (tahsilat / iptal ters kaydı). */
    public const string TYPE_CREDIT = 'credit';

    public const string SOURCE_ORDER = 'order';

    public const string SOURCE_SUBSCRIPTION = 'subscription';

    public const string SOURCE_PAYMENT = 'payment';

    public const string SOURCE_MANUAL = 'manual';

    public const string SOURCE_ADJUSTMENT = 'adjustment';

    protected $table = 'veykemtu_account_ledger';

    // Append-only: created_at elle (servis) set edilir, updated_at yok.
    public $timestamps = false;

    protected $guarded = [];

    protected $casts = [
        'customer_id' => 'integer',
        'amount_kurus' => 'integer',
        'reference_id' => 'integer',
        'created_by' => 'integer',
        'effective_date' => 'date',
        'created_at' => 'datetime',
    ];

    /**
     * Cari sahibi müşteri — admin formundaki `relation` alanı bunu kullanır.
     *
     * @var array<string, array<string, mixed>>
     */
    public $relation = [
        'belongsTo' => [
            'customer' => [
                ApiCustomer::class,
                'foreignKey' => 'customer_id',
                'otherKey' => 'customer_id',
            ],
        ],
    ];

    public function scopeForCustomer(Builder $query, int $customerId): Builder
    {
        return $query->where('customer_id', $customerId);
    }

    public function scopeNewestFirst(Builder $query): Builder
    {
        return $query->orderByDesc('effective_date')->orderByDesc('id');
    }

    /**
     * Admin formundaki TL alanı ↔ `amount_kurus` (kuruş) köprüsü.
     *
     * `amount_lira` gerçek bir kolon DEĞİL: yazınca `LiraField` ile kuruşa
     * çevrilip `amount_kurus`'a yazılır; okurken kuruştan TL metnine döner.
     * Böylece form `text` girdisi kullanır (`number` kuruşu kırpardı).
     */
    public function getAmountLiraAttribute(): string
    {
        return LiraField::toInput((int) ($this->attributes['amount_kurus'] ?? 0));
    }

    public function setAmountLiraAttribute(mixed $value): void
    {
        $this->attributes['amount_kurus'] = LiraField::toKurus($value);
    }

    /** @return array<string, string> */
    public static function entryTypeOptions(): array
    {
        return [
            self::TYPE_DEBIT => 'lang:veykemtu.bridgeapi::accountledger.type_debit',
            self::TYPE_CREDIT => 'lang:veykemtu.bridgeapi::accountledger.type_credit',
        ];
    }

    /**
     * Manuel hareket formundaki müşteri seçimi — yalnızca kurumsal müşteriler.
     *
     * @return array<int, string>
     */
    public static function customerOptions(): array
    {
        return ApiCustomer::query()
            // 'corporate' literal: model bir servise (CustomerGate) bağlanmasın.
            ->where('bld_account_type', 'corporate')
            ->orderBy('bld_org_name')
            ->orderBy('first_name')
            ->get()
            ->mapWithKeys(static function (ApiCustomer $customer): array {
                $name = $customer->bld_org_name
                    ?: trim($customer->first_name.' '.$customer->last_name);

                return [(int) $customer->customer_id => $name.' — '.$customer->email];
            })
            ->all();
    }

    /**
     * Append-only defterde `created_at` elle set edilir (`$timestamps=false`).
     * Admin formundan gelen kayıtta da dolsun diye burada garanti ediyoruz;
     * servis yolu (DB::table insert) zaten kendi created_at'ini yazar.
     */
    protected static function booted(): void
    {
        static::creating(static function (self $entry): void {
            if ($entry->created_at === null) {
                $entry->created_at = BusinessTime::forStorage(BusinessTime::now());
            }
        });
    }
}
