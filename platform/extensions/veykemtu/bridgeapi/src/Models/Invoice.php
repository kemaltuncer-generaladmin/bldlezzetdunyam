<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Builder;
use Igniter\Flame\Database\Model;

/**
 * Fatura belgesi — `docs/control/invoices.md` (iş kararı 10).
 *
 * MALİ DEĞERİ YOKTUR. e-Fatura değil, e-Arşiv değil, GİB'e gitmez, KDV
 * hesaplamaz. Yazdırılabilir bir A4 dökümüdür ve üzerindeki zorunlu ibare
 * `InvoiceService::NOTICE` sabitindedir.
 *
 * BELGE DEĞİŞMEZ. `PATCH` yok, `DELETE` yok. Yanlış kesilmiş bir belge
 * `status = void` ile iptal edilir; doğrusu YENİ bir satır olarak kesilir ve
 * `replaces_invoice_id` ile eskisine bağlanır. Düzenlenebilen bir belge,
 * elindeki kâğıtla sistemdeki kayıt farklı olan bir müşteri üretir.
 *
 * İÇERİK `snapshot_json` İÇİNDEDİR, canlı tablolarda değil. Müşteri adı,
 * kurum unvanı ve fiyatlar sonradan değişse bile basılmış belge aynı kalır.
 * HTML render'ı canlı tabloya HİÇ bakmaz.
 */
class Invoice extends Model
{
    /** Tek siparişin belgesi. */
    public const string TYPE_ORDER = 'order';

    /** Abonelik döneminin belgesi. */
    public const string TYPE_SUBSCRIPTION = 'subscription';

    /**
     * İptal belgesi — iptal edilmiş bir belgenin yerine geçen, "bu belge
     * geçersizdir" diyen ayrı bir kâğıt. Bugün üretilmiyor; `type`
     * kümesinde durması, o gün geldiğinde şema değişikliği gerekmemesi
     * içindir.
     */
    public const string TYPE_VOID = 'void';

    /** @var list<string> */
    public const array TYPES = [
        self::TYPE_ORDER,
        self::TYPE_SUBSCRIPTION,
        self::TYPE_VOID,
    ];

    public const string STATUS_ISSUED = 'issued';

    public const string STATUS_VOID = 'void';

    /** Otomatik üretimin (`auto_invoice`) aktör etiketi. */
    public const string ACTOR_SYSTEM = 'sistem';

    protected $table = 'veykemtu_invoices';

    public $timestamps = true;

    protected $guarded = [];

    protected $casts = [
        'year' => 'integer',
        'sequence' => 'integer',
        'replaces_invoice_id' => 'integer',
        'order_id' => 'integer',
        'subscription_id' => 'integer',
        'subscription_payment_id' => 'integer',
        'customer_id' => 'integer',
        'issued_at' => 'datetime',
        'period_start' => 'date',
        'period_end' => 'date',
        'subtotal_kurus' => 'integer',
        'delivery_kurus' => 'integer',
        'total_kurus' => 'integer',
        'snapshot_json' => 'array',
        'void_at' => 'datetime',
    ];

    /** @var array<string, array<string, mixed>> */
    public $relation = [
        'belongsTo' => [
            'customer' => [
                ApiCustomer::class,
                'foreignKey' => 'customer_id',
                'otherKey' => 'customer_id',
            ],
            'replaces' => [self::class, 'foreignKey' => 'replaces_invoice_id'],
        ],
    ];

    /** Yalnız geçerli belgeler — iptal edilmişler toplamlara girmez. */
    public function scopeIssued(Builder $query): Builder
    {
        return $query->where('status', self::STATUS_ISSUED);
    }

    public function isVoid(): bool
    {
        return $this->status === self::STATUS_VOID;
    }

    /** Panelin yeni sekmede açtığı yazdırma adresi. */
    public function htmlUrl(): string
    {
        return '/api/control/invoices/'.((int) $this->id).'/html';
    }

    /**
     * Donmuş içeriğin güvenli okuması.
     *
     * `snapshot_json` cast'i bozuk/eski bir satırda dizi yerine `null`
     * dönebilir; belge çizimi bunun yüzünden 500 vermemeli — eksik bölüm
     * hiç basılmaz.
     *
     * @return array<string, mixed>
     */
    public function snapshot(): array
    {
        $snapshot = $this->snapshot_json;

        return is_array($snapshot) ? $snapshot : [];
    }
}
