<?php

declare(strict_types=1);

namespace Veykemtu\Payment\Payments;

/**
 * `PaymentGateway::createIntent()` sonucu — SIRADAKİ ADIM.
 *
 * Sözleşmedeki `PaymentNextAction` (`docs/openapi.yaml`) ile birebir aynı
 * dağarcık. Kararı SUNUCU verir; istemci tutara ya da bankaya bakarak bunu
 * kendi çıkarmaz, çünkü o kural sağlayıcı tarafında ve bizim dışımızda
 * değişir.
 *
 * `none` DALI NEDEN HAZIR BİR SONUÇ TAŞIYOR: "ek adım yok" demek, sağlayıcının
 * aynı çağrıda onay verdiği anlamına gelir (sürtünmesiz/3DS'siz dal). Sonucu
 * ayrı bir geri-arama beklemeye bırakmak, hiç gelmeyecek bir çağrıyı sonsuza
 * kadar yoklayan bir istemci demekti.
 */
final class PaymentIntentResult
{
    public const string ACTION_NONE = 'none';

    public const string ACTION_OTP = 'otp';

    public const string ACTION_THREE_DS = 'three_ds';

    private function __construct(
        public readonly string $gateway,
        public readonly string $nextAction,
        /** Yalnız `ACTION_NONE` iken dolu: sağlayıcı aynı çağrıda karar verdi. */
        public readonly ?PaymentResult $result,
        /** Yalnız `ACTION_THREE_DS` iken dolu. */
        public readonly ?string $redirectUrl,
    ) {}

    public static function settled(PaymentResult $result): self
    {
        return new self($result->gateway, self::ACTION_NONE, $result, null);
    }

    /** Kod bekleniyor: abone SMS'le gelen kodu `.../confirm` ucuna gönderecek. */
    public static function otp(string $gateway): self
    {
        return new self($gateway, self::ACTION_OTP, null, null);
    }

    /**
     * Sağlayıcının sayfasına yönlendirme gerekiyor.
     *
     * Simülasyon bunu ÜRETMEZ (mobil akış bugün tamamen yerli, WebView yok);
     * gerçek POS'un 3D Secure dalı için duruyor. Adres olmadan bu adım
     * anlamsız olduğu için kurucu onu zorunlu alıyor.
     */
    public static function threeDs(string $gateway, string $redirectUrl): self
    {
        return new self($gateway, self::ACTION_THREE_DS, null, $redirectUrl);
    }
}
