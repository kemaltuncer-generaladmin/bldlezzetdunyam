<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services\Sms;

use RuntimeException;
use Throwable;

/**
 * SMS gönderilemedi — sağlayıcı hatası, ağ hatası ya da eksik yapılandırma.
 *
 * `$providerCode` SAĞLAYICININ HAM KODUNU TAŞIR (`'40'`, `'30'` …) ve
 * mesajın kendisinden AYRI durur. Ayrı durmasının sebebi şu: Kontrol
 * Merkezi ekranı "başlık Netgsm'de tanımlı değil" durumunu diğer
 * hatalardan ayırıp yöneticiye NE YAPACAĞINI söylemek zorunda
 * (`40` → "başlığı Netgsm panelinde onaylatın"), ve bunu Türkçe hata
 * cümlesinin içinde metin arayarak yapması kırılgan olurdu — cümle
 * düzeltildiği gün kapı sessizce kapanırdı.
 */
class SmsException extends RuntimeException
{
    public function __construct(
        string $message,
        int $code = 0,
        ?Throwable $previous = null,
        /**
         * Netgsm'in iki haneli yanıt kodu; ağ hatasında `null`.
         *
         * `code` (int) yerine ayrı bir dize alan: sağlayıcı kodları başında
         * sıfır taşıyor (`'02'`) ve tam sayıya çevirmek onu kaybederdi.
         */
        public readonly ?string $providerCode = null,
    ) {
        parent::__construct($message, $code, $previous);
    }
}
