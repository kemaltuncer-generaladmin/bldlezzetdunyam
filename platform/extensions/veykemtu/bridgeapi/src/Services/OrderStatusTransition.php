<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Igniter\Admin\Models\Status;
use Igniter\Cart\Models\Order;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\AccountLedgerEntry;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\BridgeApi\Support\Money;
use Veykemtu\Payment\Refunds\RefundManager;

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
        private readonly RefundManager $refunds,
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
     * GERİ ALMA PENCERESİ (K-10, 11.08.2026).
     *
     * `docs/05` §3 "geri alma yoktur" diyordu ve dokunmatik monitör
     * gelene kadar doğruydu: klavyeyle yanlış kartı ilerletmek zordu.
     * Dokunmatikte kartlar parmağın altında ve yanlışlıkla kaydırma
     * gerçek — geri alınamayan bir dokunuş, siparişi yanlış sütuna
     * gönderip mutfağı gereksiz fiş basmaya zorluyor.
     *
     * KURALLAR (dar tutuldu, çünkü geri alma bir kaçış kapısıdır):
     *   * yalnız TEK ADIM geri (`hazir` -> `hazirlaniyor`),
     *   * yalnız bu pencere içinde (`status_updated_at`'ten itibaren),
     *   * terminal durumlardan (`teslim_edildi`, `iptal`) ASLA — iptal
     *     cari hesaba ters kayıt yazıyor, geri alması muhasebe düzeltmesi
     *     olurdu ve bu ekranın işi değil,
     *   * `yeni`ye geri dönülemez: mutfak fişi `onaylandi`da basıldı,
     *     `yeni`ye dönmek basılı fişi geçersiz kılardı.
     */
    public const int UNDO_WINDOW_SECONDS = 120;

    /**
     * Geri alma haritası: her durumun tek bir önceki adımı.
     *
     * @var array<string, string>
     */
    private const array UNDO = [
        self::PREPARING => self::CONFIRMED,
        self::READY => self::PREPARING,
        self::ON_THE_WAY => self::READY,
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
            $this->openRefundOnCancel($order);
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

    /**
     * İptal edilen siparişin parası için iade kaydı açar (K-13).
     *
     * `account` HARİÇ: orada zaten ters defter kaydı yazıldı ve para
     * hareketi yok. Diğerlerinde iade kaydı `pending`/`manual` olarak
     * açılır ve admin panelde biri tamamlayana kadar açık durur —
     * kaydetmemek, müşterinin parasını görünmez biçimde beklemesi
     * demekti.
     *
     * ÖDENMEMİŞ SİPARİŞ İADE ÜRETMEZ: kapıda ödeme henüz tahsil
     * edilmediyse iade edilecek bir şey yok.
     */
    private function openRefundOnCancel(Order $order): void
    {
        if ((string) $order->payment === 'account') {
            return;
        }

        if (!(bool) $order->processed) {
            return;
        }

        $this->refunds->refund(
            $order,
            Money::toKurus($order->order_total),
            'Sipariş iptal edildi',
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
            // Geri alma, matriste olmayan tek istisnadır. Matrise
            // eklenmedi: eklenseydi `allowedFrom()` geri adımı normal bir
            // seçenek gibi sunar ve arayüzde kalıcı bir "GERİ" düğmesi
            // olurdu. Geri alma kalıcı bir yol değil, dar bir penceredir.
            if ($this->canUndoTo($order, $from, $to)) {
                return;
            }

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

    /**
     * Bu geçiş bir geri alma mı ve süresi geçmemiş mi?
     *
     * Süre `status_updated_at` üzerinden ölçülüyor: çekirdek bu alanı
     * `updateOrderStatus()` içinde yazıyor, yani "son durum değişikliğinin
     * üstünden ne kadar geçti" sorusunun doğru cevabı orada.
     */
    public function canUndoTo(Order $order, string $from, string $to): bool
    {
        if ((self::UNDO[$from] ?? null) !== $to) {
            return false;
        }

        $changedAt = $order->status_updated_at;

        // Zaman damgası yoksa geri almaya İZİN VERİLMEZ. "Bilinmiyorsa
        // serbest" demek, eski bir siparişin günler sonra geri alınabilmesi
        // olurdu.
        if ($changedAt === null) {
            return false;
        }

        return $changedAt->diffInSeconds(BusinessTime::now()) <= self::UNDO_WINDOW_SECONDS;
    }

    /**
     * Şu an geri alınabilecek durum — yoksa `null`.
     *
     * Arayüz "Geri al" şeridini yalnız bu doluyken gösterir.
     */
    public function undoTargetFor(Order $order): ?string
    {
        $from = $this->codeOf($order);
        $to = self::UNDO[$from] ?? null;

        return $to !== null && $this->canUndoTo($order, $from, $to) ? $to : null;
    }

    /** Müşteri iptal edebilir mi? — `docs/03` §4. */
    public function customerCanCancel(Order $order): bool
    {
        return in_array($this->codeOf($order), [self::NEW, self::CONFIRMED], true);
    }
}
