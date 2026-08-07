<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Igniter\Admin\Models\Status;
use Igniter\Cart\Models\Order;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\AccountLedgerEntry;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\BridgeApi\Support\Money;

/**
 * Sipariş durum makinesi — `docs/02-veri-modeli.md` §3.
 *
 * **Kararı sunucu verir.** İstemci yalnızca hedef durumu ister; burası izin
 * verir veya `422 INVALID_TRANSITION` ile reddeder. İstemcideki aynı matris
 * (`packages/core`) sadece geçersiz butonu göstermemek içindir, güvenlik
 * sınırı burasıdır.
 */
class OrderStatusTransition
{
    public function __construct(
        private readonly AccountLedger $ledger,
    ) {}

    public const string NEW = 'yeni';

    public const string CONFIRMED = 'onaylandi';

    public const string PREPARING = 'hazirlaniyor';

    public const string READY = 'hazir';

    public const string ON_THE_WAY = 'yolda';

    public const string DELIVERED = 'teslim_edildi';

    public const string CANCELLED = 'iptal';

    /** Sözleşmedeki yedi kod, admin panelindeki sırayla. */
    public const array CODES = [
        self::NEW,
        self::CONFIRMED,
        self::PREPARING,
        self::READY,
        self::ON_THE_WAY,
        self::DELIVERED,
        self::CANCELLED,
    ];

    /** @var array<string, list<string>> */
    private const array MATRIX = [
        self::NEW => [self::CONFIRMED, self::CANCELLED],
        self::CONFIRMED => [self::PREPARING, self::CANCELLED],
        self::PREPARING => [self::READY, self::CANCELLED],
        self::READY => [self::ON_THE_WAY, self::DELIVERED, self::CANCELLED],
        self::ON_THE_WAY => [self::DELIVERED, self::CANCELLED],
        self::DELIVERED => [],
        self::CANCELLED => [],
    ];

    /**
     * Sipariş durumunu ilerletir.
     *
     * @throws ApiException geçersiz geçişte
     */
    public function apply(Order $order, string $to, ?int $userId = null): Order
    {
        $from = $this->codeOf($order);
        $this->assertAllowed($order, $from, $to);

        $status = $this->statusByCode($to);

        // Çekirdeğin kendi metodu kullanılır: status_history kaydını,
        // bildirim tetiklerini ve status_updated_at'i o yönetir.
        // Kendi UPDATE'imizi yazmak bu üçünü sessizce atlardı.
        $order->updateOrderStatus($status->status_id, [
            'notify' => (bool) $status->notify_customer,
            'user_id' => $userId,
        ]);

        if ($to === self::CANCELLED) {
            $this->reverseAccountDebitOnCancel($order);
        }

        return $order->refresh();
    }

    /**
     * İptal edilen `account` siparişinin cari borcunu ters alacakla nötrler.
     *
     * Append-only defter: borç silinmez, eşit bir alacak yazılır. Yalnızca
     * gerçekten borç düşmüş siparişte çalışır (idempotent; ikinci iptal zaten
     * durum makinesince engellenir).
     */
    private function reverseAccountDebitOnCancel(Order $order): void
    {
        if ($order->payment !== 'account') {
            return;
        }

        $orderId = (int) $order->order_id;

        if (!$this->ledger->hasEntry(
            AccountLedgerEntry::SOURCE_ORDER,
            'order',
            $orderId,
            AccountLedgerEntry::TYPE_DEBIT,
        )) {
            return;
        }

        $this->ledger->record(
            customerId: (int) $order->customer_id,
            type: AccountLedgerEntry::TYPE_CREDIT,
            amountKurus: Money::toKurus($order->order_total),
            source: AccountLedgerEntry::SOURCE_ORDER,
            referenceType: 'order',
            referenceId: $orderId,
            description: 'Sipariş #'.$orderId.' iptal (ters kayıt)',
            effectiveDate: BusinessTime::now(),
        );
    }

    /** @throws ApiException */
    public function assertAllowed(Order $order, string $from, string $to): void
    {
        if (!in_array($to, self::CODES, true)) {
            throw ApiException::validationFailed('Geçersiz durum kodu.', [
                'status' => 'Şunlardan biri olmalı: '.implode(', ', self::CODES),
            ]);
        }

        if ($from === $to) {
            throw ApiException::invalidTransition(
                $from,
                $to,
                'Sipariş zaten bu durumda.',
            );
        }

        if (!in_array($to, self::MATRIX[$from] ?? [], true)) {
            throw ApiException::invalidTransition(
                $from,
                $to,
                'Sipariş bu duruma geçirilemez.',
            );
        }

        // `hazir` sonrası dal teslimat tipine bağlıdır (docs/02 §3):
        // adrese gönderimde kurye adımı atlanamaz, gel-al'da kurye adımı yoktur.
        if ($from === self::READY) {
            $isDelivery = $order->order_type === Order::DELIVERY;

            if ($to === self::ON_THE_WAY && !$isDelivery) {
                throw ApiException::invalidTransition(
                    $from,
                    $to,
                    'Gel-al siparişi yola çıkarılamaz.',
                );
            }

            if ($to === self::DELIVERED && $isDelivery) {
                throw ApiException::invalidTransition(
                    $from,
                    $to,
                    'Adrese gönderim siparişi önce yola çıkarılmalı.',
                );
            }
        }
    }

    /**
     * Siparişin mevcut durum kodu.
     *
     * Kodsuz bir durum (TastyIgniter varsayılanı) `yeni` sayılır: eski bir
     * sipariş veya elle değiştirilmiş bir kayıt yüzünden API çökmemeli.
     */
    public function codeOf(Order $order): string
    {
        $code = Status::where('status_id', $order->status_id)->value('status_code');

        return is_string($code) && $code !== '' ? $code : self::NEW;
    }

    /** @throws ApiException */
    public function statusByCode(string $code): Status
    {
        $status = Status::where('status_code', $code)->first();

        if ($status === null) {
            // Kurulum eksik demektir — istemcinin suçu değil.
            throw ApiException::serverError(
                "Durum tanımlı değil: {$code}. `php artisan veykemtu:setup` çalıştırılmalı.",
            );
        }

        return $status;
    }

    /** @return list<string> */
    public function allowedFrom(Order $order): array
    {
        $from = $this->codeOf($order);
        $allowed = self::MATRIX[$from] ?? [];

        if ($from !== self::READY) {
            return $allowed;
        }

        $isDelivery = $order->order_type === Order::DELIVERY;

        return array_values(array_filter(
            $allowed,
            static fn(string $to): bool => match ($to) {
                self::ON_THE_WAY => $isDelivery,
                self::DELIVERED => !$isDelivery,
                default => true,
            },
        ));
    }

    /** Müşteri iptal edebilir mi? — `docs/03` §4. */
    public function customerCanCancel(Order $order): bool
    {
        return in_array($this->codeOf($order), [self::NEW, self::CONFIRMED], true);
    }
}
