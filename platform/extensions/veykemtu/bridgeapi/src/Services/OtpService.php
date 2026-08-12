<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Services\Sms\SmsSender;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Telefonla giriş kodu üretimi ve doğrulaması — B-18.
 *
 * ÜÇ SALDIRIYA KARŞI TASARLANDI:
 *
 *  1. **Numara sayımı (enumeration).** Kayıtlı olmayan bir numara için de
 *     istek BAŞARILI döner ve hiçbir SMS gitmez. "Bu numara kayıtlı değil"
 *     demek, saldırgana müşteri listesini numara numara taratma imkânı
 *     verirdi.
 *  2. **Kaba kuvvet.** Kod 6 haneli, yani 10^6 olasılık — beş dakikada
 *     denenebilir. `MAX_ATTEMPTS` sayacı KODA bağlı: IP değiştirmek işe
 *     yaramaz. Eşiğe ulaşan kod ölür.
 *  3. **Yeniden kullanım.** Kod tüketilince `consumed_at` damgalanır ve bir
 *     daha kabul edilmez. Satır silinseydi bu ayrım kaybolurdu.
 *
 * KOD VERİTABANINDA AÇIK DURMAZ (`Hash::make`). Kısa ömürlü olması yetmez:
 * bir yedek sızıntısı, o anda geçerli her kodu aktif anahtar hâline getirir.
 */
final class OtpService
{
    /** Kod ömrü. Kısa tutuluyor; SMS'in gelmesi saniyeler sürüyor. */
    public const int TTL_SECONDS = 300;

    /**
     * Yeni kod istemeden önce beklenecek süre.
     *
     * Arayüzdeki 60 saniyelik geri sayımın sunucu tarafındaki karşılığı.
     * Yalnız istemcide dursaydı, isteği doğrudan atan biri sınırsız SMS
     * gönderterek hem bütçeyi hem de müşterinin telefonunu yakardı.
     */
    public const int RESEND_COOLDOWN_SECONDS = 60;

    /** Bir koda yapılabilecek yanlış deneme sayısı. */
    public const int MAX_ATTEMPTS = 5;

    private const string TABLE = 'veykemtu_otp_codes';

    public function __construct(private readonly SmsSender $sms) {}

    /**
     * Kod üretir ve gönderir.
     *
     * Kayıtlı olmayan numarada SESSİZCE hiçbir şey yapmaz — çağıran taraf
     * bu iki durumu ayırt edemez ve etmemeli.
     */
    public function request(string $phone): void
    {
        $phone = self::normalize($phone);

        $this->assertNotThrottled($phone);

        if (ApiCustomer::where('telephone', $phone)->doesntExist()) {
            // Numara sayımına kapı bırakmamak için sessiz çıkış. Bekleme
            // süresi YUKARIDA kontrol edildi, yani kayıtsız numaraya istek
            // atarak da sınırsız deneme yapılamıyor.
            return;
        }

        // `random_int` kriptografik olarak güvenli; `rand`/`mt_rand`
        // tahmin edilebilir ve giriş kodu üretiminde kullanılamaz.
        $code = str_pad((string) random_int(0, 999_999), 6, '0', STR_PAD_LEFT);

        DB::table(self::TABLE)->insert([
            'phone' => $phone,
            'code_hash' => Hash::make($code),
            'expires_at' => BusinessTime::forStorage(
                BusinessTime::now()->addSeconds(self::TTL_SECONDS),
            ),
            'attempts' => 0,
            'consumed_at' => null,
            'created_at' => BusinessTime::forStorage(BusinessTime::now()),
        ]);

        $this->sms->send($phone, sprintf(
            'Benim Lezzet Dunyam giris kodunuz: %s. Kod %d dakika gecerlidir. '
            .'Bu istegi siz yapmadiysaniz dikkate almayin.',
            $code,
            (int) (self::TTL_SECONDS / 60),
        ));
    }

    /**
     * Kodu doğrular ve müşteriyi döndürür.
     *
     * @throws ApiException Kod geçersiz, süresi dolmuş ya da deneme hakkı bitmişse.
     */
    public function verify(string $phone, string $code): ApiCustomer
    {
        $phone = self::normalize($phone);

        $row = DB::table(self::TABLE)
            ->where('phone', $phone)
            ->whereNull('consumed_at')
            ->where('expires_at', '>', BusinessTime::forStorage(BusinessTime::now()))
            ->orderByDesc('id')
            ->first();

        if ($row === null) {
            throw ApiException::validationFailed('Kod geçersiz ya da süresi dolmuş.', [
                'code' => 'Yeni bir kod isteyin.',
            ]);
        }

        if ((int) $row->attempts >= self::MAX_ATTEMPTS) {
            // Hakkı biten kodu ÖLDÜR: aksi hâlde süresi dolana kadar
            // sorgulanmaya devam eder ve sayaç bir işe yaramaz.
            $this->consume((int) $row->id);

            throw ApiException::validationFailed('Çok fazla yanlış deneme yaptınız.', [
                'code' => 'Yeni bir kod isteyin.',
            ]);
        }

        if (!Hash::check($code, (string) $row->code_hash)) {
            DB::table(self::TABLE)->where('id', $row->id)->increment('attempts');

            throw ApiException::validationFailed('Kod hatalı.', [
                'code' => 'Girdiğiniz kod doğru değil.',
            ]);
        }

        $customer = ApiCustomer::where('telephone', $phone)->first();

        if (!$customer instanceof ApiCustomer) {
            // Kod üretildikten sonra müşteri silinmiş olabilir. Kodu yine de
            // tüketiyoruz: geçerli bir kodun ortada kalması istenmez.
            $this->consume((int) $row->id);

            throw ApiException::validationFailed('Kod geçersiz ya da süresi dolmuş.', [
                'code' => 'Yeni bir kod isteyin.',
            ]);
        }

        if ((bool) $customer->status !== true) {
            $this->consume((int) $row->id);

            throw ApiException::forbidden('Hesabınız devre dışı. Bizimle iletişime geçin.');
        }

        $this->consume((int) $row->id);

        /*
         * AYNI TELEFONUN DİĞER AÇIK KODLARI DA TÜKETİLİR.
         *
         * Kullanıcı üst üste iki kod istediyse ikisi de geçerli kalırdı;
         * ilkiyle girip ikincisini SMS kutusunda bırakmak, ele geçirilebilir
         * bir açık anahtar bırakmak demek.
         */
        DB::table(self::TABLE)
            ->where('phone', $phone)
            ->whereNull('consumed_at')
            ->update(['consumed_at' => BusinessTime::forStorage(BusinessTime::now())]);

        return $customer;
    }

    /**
     * Telefonu 10 haneye indirger: `0555...`, `+90555...`, `90555...` ve
     * boşluklu yazımların hepsi aynı anahtara düşsün.
     *
     * Normalleştirme OLMASAYDI, kayıt sırasında `5551112233` yazan müşteri
     * girişte `0555 111 22 33` yazdığında "numara kayıtlı değil" muamelesi
     * görürdü — ve numara sayımına kapı bırakmadığımız için sebebini de
     * asla öğrenemezdi.
     */
    public static function normalize(string $phone): string
    {
        $digits = preg_replace('/\D+/', '', $phone) ?? '';

        if (str_starts_with($digits, '90') && strlen($digits) === 12) {
            $digits = substr($digits, 2);
        }

        if (str_starts_with($digits, '0') && strlen($digits) === 11) {
            $digits = substr($digits, 1);
        }

        return $digits;
    }

    /**
     * Son kodun üzerinden yeterli süre geçti mi?
     *
     * @throws ApiException
     */
    private function assertNotThrottled(string $phone): void
    {
        $last = DB::table(self::TABLE)
            ->where('phone', $phone)
            ->orderByDesc('id')
            ->value('created_at');

        if ($last === null) {
            return;
        }

        /*
         * SAAT DİLİMİ VERİLMEZ VE BU ÖNEMLİ.
         *
         * `created_at`, `BusinessTime::forStorage()` ile yazıldı; o metot
         * değeri UYGULAMANIN varsayılan dilimine (UTC) çeviriyor. Geri
         * okurken `BusinessTime::ZONE` (Istanbul) verilseydi aynı an üç saat
         * geriye kayar, geçen süre her zaman 10.800 saniyeden büyük çıkar ve
         * 60 saniyelik bekleme HİÇ devreye girmezdi. Belirtisi de görünmez
         * olurdu: sınır çalışmıyor ama hata da vermiyor.
         *
         * Argümansız `Carbon::parse` uygulamanın dilimini kullanır, yani
         * yazıldığı biçimle aynı.
         */
        $elapsed = (int) Carbon::parse($last)
            ->diffInSeconds(BusinessTime::now(), absolute: true);

        if ($elapsed < self::RESEND_COOLDOWN_SECONDS) {
            throw ApiException::validationFailed('Yeni kod için biraz bekleyin.', [
                'retry_after' => self::RESEND_COOLDOWN_SECONDS - $elapsed,
            ]);
        }
    }

    private function consume(int $id): void
    {
        DB::table(self::TABLE)
            ->where('id', $id)
            ->update(['consumed_at' => BusinessTime::forStorage(BusinessTime::now())]);
    }
}
