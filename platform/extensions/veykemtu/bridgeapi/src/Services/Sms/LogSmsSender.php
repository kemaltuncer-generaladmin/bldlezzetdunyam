<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services\Sms;

use Illuminate\Support\Facades\Log;
use Override;

/**
 * SMS yerine günlüğe yazan gönderici — geliştirme ve sağlayıcısız kurulum.
 *
 * NEDEN "SESSİZCE BAŞARILI" DEĞİL: mesaj günlüğe TAM METNİYLE yazılıyor,
 * yani geliştirici kodu `storage/logs` içinden okuyup akışı uçtan uca
 * deneyebiliyor. Hiçbir şey yapmayan bir sahte gönderici, giriş akışını
 * yerelde test edilemez hâle getirirdi.
 *
 * ÜRETİMDE UYARI SEVİYESİNDE: `warning`, `info` değil. Netgsm bilgileri
 * yanlışlıkla boş bırakılıp canlıya çıkılırsa, kimse SMS alamaz ve bunun
 * tek izi bu satır olur — günlükte gözden kaçmayacak seviyede durmalı.
 */
final class LogSmsSender implements SmsSender
{
    #[Override]
    public function send(string $phone, string $message): void
    {
        Log::warning('SMS GÖNDERİLMEDİ (sağlayıcı tanımsız) — mesaj yalnızca günlükte.', [
            'phone' => $phone,
            'message' => $message,
        ]);
    }
}
