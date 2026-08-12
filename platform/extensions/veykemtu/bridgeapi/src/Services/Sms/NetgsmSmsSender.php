<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services\Sms;

use Illuminate\Support\Facades\Http;
use Override;
use Throwable;

/**
 * Netgsm SMS gönderimi — B-18.
 *
 * Netgsm'in `get/bulkhttppost.asmx` ucu, HTTP 200 gövdesinde metin bir kod
 * döndürür; hata durumunda da 200 döner. Yani `$response->successful()`
 * kontrolü YETMEZ — gövdenin kendisi okunmak zorunda. Bu, sağlayıcının en
 * kolay atlanan ayrıntısı ve atlandığında belirtisi "SMS gitti görünüyor
 * ama kimse almıyor" oluyor.
 *
 * Yanıt biçimi: `"00 <mesaj_id>"` ya da `"01 <mesaj_id>"` başarı; iki
 * haneli diğer kodlar hata. Kodların anlamları `ERRORS` içinde.
 */
final class NetgsmSmsSender implements SmsSender
{
    private const string ENDPOINT = 'https://api.netgsm.com.tr/sms/send/get';

    /** Başarı sayılan yanıt önekleri (00 = kuyruğa alındı, 01 = kısmen). */
    private const array SUCCESS_CODES = ['00', '01', '02'];

    /**
     * Netgsm hata kodları. Türkçeye çevriliyor çünkü bu metin günlüğe
     * düşüyor ve orada "30" görmek hiçbir şey anlatmıyor.
     *
     * @var array<string, string>
     */
    private const array ERRORS = [
        '20' => 'Mesaj metni çok uzun ya da karakter sorunu var.',
        '30' => 'Kullanıcı adı, şifre hatalı ya da API erişim izni yok.',
        '40' => 'Mesaj başlığı (gönderici adı) sistemde tanımlı değil.',
        '50' => 'Abone hesabı IYS kontrollü gönderime uygun değil.',
        '51' => 'IYS marka bilgisi eksik.',
        '70' => 'Hatalı sorgulama — parametrelerden biri eksik ya da yanlış.',
        '80' => 'Gönderim sınırı aşıldı.',
        '85' => 'Aynı numaraya çok sayıda tekrarlı gönderim.',
    ];

    public function __construct(
        private readonly string $username,
        private readonly string $password,
        private readonly string $header,
    ) {}

    #[Override]
    public function send(string $phone, string $message): void
    {
        try {
            $response = Http::timeout(10)
                ->retry(2, 500, throw: false)
                ->get(self::ENDPOINT, [
                    'usercode' => $this->username,
                    'password' => $this->password,
                    'gsmno' => '0'.$phone,
                    'message' => $message,
                    'msgheader' => $this->header,
                    // Türkçe karakterler: `dil=TR` olmadan "ş/ğ/ı" soru
                    // işaretine dönüşüyor ve mesaj okunmaz hâle geliyor.
                    'dil' => 'TR',
                ]);
        } catch (Throwable $e) {
            throw new SmsException('SMS sağlayıcısına ulaşılamadı: '.$e->getMessage(), 0, $e);
        }

        if (!$response->successful()) {
            throw new SmsException('SMS sağlayıcısı HTTP '.$response->status().' döndü.');
        }

        $body = trim($response->body());
        $code = substr($body, 0, 2);

        if (in_array($code, self::SUCCESS_CODES, true)) {
            return;
        }

        throw new SmsException(
            self::ERRORS[$code] ?? ('SMS sağlayıcısı beklenmeyen yanıt döndü: '.$body),
        );
    }
}
