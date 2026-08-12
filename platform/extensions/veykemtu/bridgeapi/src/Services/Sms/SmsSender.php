<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services\Sms;

/**
 * SMS gönderiminin tek arayüzü — B-18.
 *
 * NEDEN ARAYÜZ: sağlayıcı iş kararıdır ve değişir. Netgsm'in HTTP çağrısı
 * `OtpService`'in içine yazılsaydı, sağlayıcı değiştiğinde giriş akışının
 * mantığına dokunmak gerekirdi; üstelik testte gerçek SMS göndermemek için
 * o mantığın içine `if (test)` koymak zorunda kalırdık.
 *
 * Uygulamalar: `NetgsmSmsSender` (üretim) ve `LogSmsSender` (sır tanımsızsa).
 * Bağlama `Extension::registerSmsSender()` içinde yapılıyor.
 */
interface SmsSender
{
    /**
     * Mesajı gönderir.
     *
     * DÖNÜŞ YOK, İSTİSNA VAR: çağıran taraf "gitti mi" diye bir boolean'a
     * bakmaz. Gönderim başarısızsa istisna fırlar ve kullanıcı açık bir
     * hata görür; sessizce `false` dönmek, kodu bekleyen ama hiç gelmeyecek
     * bir kullanıcı üretirdi.
     *
     * @param  string  $phone  Normalleştirilmiş 10 hane (5xxxxxxxxx).
     *
     * @throws SmsException
     */
    public function send(string $phone, string $message): void;
}
