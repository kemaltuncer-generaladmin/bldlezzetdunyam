<?php

declare(strict_types=1);

namespace Veykemtu\Payment\Payments;

/**
 * Bir ödeme denemesinin KESİNLEŞMİŞ sonucu.
 *
 * `PaymentGateway::handleCallback()` bunu döner; `createIntent()` de ek adım
 * gerekmeyen (`next_action = none`) dalda bunu taşır.
 *
 * NEDEN SONUÇ NESNESİ, NEDEN `bool` DEĞİL: başarısızlığın müşteriye
 * gösterilebilir bir SEBEBİ olmalı ("Kart limiti yetersiz."), başarının ise
 * sağlayıcı işlem numarası. İkisini `bool` + dışarıda tutulan bir değişkenle
 * taşımak, çağıran her yerin aynı iki alanı ayrı ayrı toplaması demekti.
 *
 * `reference` niyet açılırken geçide verilen dizedir (bizim `hash`'imiz).
 * Geri-arama gövdesinden geri okunur: sağlayıcı hangi ödemeyi bildirdiğini
 * ancak bu alanla söyleyebilir.
 */
final class PaymentResult
{
    private function __construct(
        public readonly bool $success,
        public readonly string $gateway,
        public readonly string $reference,
        public readonly ?string $providerRef,
        public readonly ?string $failureReason,
    ) {}

    public static function succeeded(string $gateway, string $reference, string $providerRef): self
    {
        return new self(true, $gateway, $reference, $providerRef, null);
    }

    /**
     * Başarısız sonuç.
     *
     * `$failureReason` MÜŞTERİYE GÖSTERİLEBİLİR TÜRKÇE bir cümledir.
     * Sağlayıcının ham hata kodu buraya konmaz (`docs/openapi.yaml`
     * `SubscriptionPayment.failure_reason`): müşteriye bir şey anlatmıyor
     * ve teşhis zaten günlükte.
     */
    public static function failed(string $gateway, string $reference, string $failureReason): self
    {
        return new self(false, $gateway, $reference, null, $failureReason);
    }
}
