<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services\Sms;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Throwable;

/**
 * Netgsm gönderici başlığının TEK kaynağı — F (BLD SMS başlığı).
 *
 * ═════════════════════════════════════════════════════════════════════════
 * NEDEN VAR: BAŞLIK YALNIZ ORTAM DEĞİŞKENİNDEYKEN ARIZA SESSİZDİ.
 *
 * `NETGSM_HEADER` boş bırakıldığında `Extension::registerSmsSender()`
 * `LogSmsSender`'a düşüyordu; uygulama ayakta kalıyor, panel "gönderildi"
 * diyor ve müşteriye hiçbir şey ulaşmıyordu. Tek iz `storage/logs` içindeki
 * bir `warning` satırıydı ve oraya kimse bakmıyor. Değeri düzeltmek de
 * Coolify'a girip konteyneri yeniden başlatmayı gerektiriyordu — yani
 * yöneticinin elinden gelmeyen bir iş.
 *
 * ÇÖZÜM bbdkantin'in önceliğidir (`Domain/Notification/NetgsmClient`):
 * **AYAR ÖNCE, ORTAM DEĞİŞKENİ SONRA.** Başlık artık Kontrol Merkezi'nden
 * okunup yazılabiliyor ve değişiklik yeniden başlatma istemiyor.
 * ═════════════════════════════════════════════════════════════════════════
 *
 * ─────────────────────────────────────────────────────────────────────────
 * KULLANICI ADI VE PAROLA BİLİNÇLİ OLARAK BU YOLA GİRMEZ.
 *
 * bbdkantin ikisini de `Setting` satırında tutuyor; BLD tutmuyor ve bu
 * ayrım `Extension::registerSmsSender()` yorumunda gerekçelendirilmiş bir
 * karar: sağlayıcı sırrı her veritabanı yedeğine girer ve yedekler
 * sırlardan çok daha kolay dolaşır. BAŞLIK BİR SIR DEĞİLDİR — Netgsm
 * panelinde onaylı, müşterinin telefonunda görünen bir gönderici adıdır
 * (`BLEZZETDNYM`). Yedeğe girmesinin bir bedeli yok; yönetici tarafından
 * düzeltilebilir olmasının ise büyük bir faydası var.
 *
 * Yani sıra şu: BAŞLIK ayardan da okunur, SIRLAR yalnız ortamdan.
 * ─────────────────────────────────────────────────────────────────────────
 *
 * `location_options` KENDİ TABLOSUNU AÇMAYA DEĞMEYECEK KADAR KÜÇÜK bir
 * ayar için kullanılıyor — `Control\SmsController` duyuru taslağını da orada
 * tutuyor ve aynı kapıdan geçmek iki farklı ayar deposu üretmiyor.
 */
final class NetgsmSettings
{
    /** `location_options.item` anahtarı — gönderici başlığı. */
    public const string OPT_HEADER = 'bld_sms_netgsm_header';

    /**
     * Netgsm'in gönderici adı sınırı.
     *
     * Sağlayıcı 11 karakterden uzun başlığı reddediyor; sınırı burada
     * tutmak, panelin ve ucun aynı sayıyı okumasını sağlıyor.
     */
    public const int HEADER_MAX = 11;

    /** Başlığın kaynağı: panelden yazılmış ayar. */
    public const string SOURCE_SETTING = 'setting';

    /** Başlığın kaynağı: `NETGSM_HEADER` ortam değişkeni. */
    public const string SOURCE_ENV = 'env';

    /** Başlık hiçbir yerde tanımlı değil — SMS GİTMEZ. */
    public const string SOURCE_NONE = 'none';

    /**
     * Yürürlükteki başlık. AYAR ÖNCE, ORTAM SONRA.
     *
     * Boş dize "tanımsız" demektir ve çağıran tarafın bunu `LogSmsSender`
     * ile karşılaması gerekir; burada uydurma bir varsayılan üretmek,
     * Netgsm'in `40` hatasını (başlık tanımlı değil) her gönderimde
     * tekrarlatırdı.
     */
    public static function header(): string
    {
        $stored = self::storedHeader();

        return $stored !== '' ? $stored : self::envHeader();
    }

    /** Panelden yazılmış başlık; yoksa boş dize. */
    public static function storedHeader(): string
    {
        return self::normalize((string) (self::option(self::OPT_HEADER) ?? ''));
    }

    /** `NETGSM_HEADER` ortam değişkeni; yoksa boş dize. */
    public static function envHeader(): string
    {
        return self::normalize((string) env('NETGSM_HEADER', ''));
    }

    /**
     * Başlık nereden geliyor.
     *
     * PANELİN GÖSTERMESİ GEREKEN AYRIM BUDUR: yönetici ayarı boş görüp
     * "demek ki hiç tanımlı değil" diye düşünürse, ortamdan gelen çalışan
     * bir başlığın üstüne yazar.
     */
    public static function source(): string
    {
        if (self::storedHeader() !== '') {
            return self::SOURCE_SETTING;
        }

        return self::envHeader() !== '' ? self::SOURCE_ENV : self::SOURCE_NONE;
    }

    /** Başlığı yazar. Boş dize AYARI SİLER, yani ortam değişkenine döner. */
    public static function setHeader(string $header): void
    {
        $header = self::normalize($header);
        $locationId = (int) (DB::table('locations')->orderBy('location_id')->value('location_id') ?? 1);

        DB::table('location_options')->updateOrInsert(
            ['location_id' => $locationId, 'item' => self::OPT_HEADER],
            ['value' => json_encode($header)],
        );
    }

    /**
     * Netgsm kullanıcı adı — YALNIZ ORTAMDAN (sınıf başlığındaki kutuya bakın).
     */
    public static function username(): string
    {
        return trim((string) env('NETGSM_USERNAME', ''));
    }

    /** Netgsm parolası — YALNIZ ORTAMDAN. Hiçbir uçtan geri dönmez. */
    public static function password(): string
    {
        return (string) env('NETGSM_PASSWORD', '');
    }

    /**
     * Eksik olan alanların adları — `['username', 'password', 'header']`.
     *
     * BOŞ LİSTE "GÖNDERİM YAPILABİLİR" DEMEKTİR. Panel bu listeyi olduğu
     * gibi gösteriyor; "yapılandırma eksik" gibi genel bir cümle,
     * yöneticiye hangi alanı dolduracağını söylemezdi.
     *
     * @return list<string>
     */
    public static function missing(): array
    {
        $missing = [];

        if (self::username() === '') {
            $missing[] = 'username';
        }

        if (self::password() === '') {
            $missing[] = 'password';
        }

        if (self::header() === '') {
            $missing[] = 'header';
        }

        return $missing;
    }

    /**
     * Başlığı biçimler: kırpar ve 11 karaktere daraltır.
     *
     * Sınırı SESSİZCE kırpmak yerine reddetmek doğru olurdu ama bu metot
     * OKUMA yolunda da çalışıyor: ortam değişkenine 14 karakter yazılmışsa
     * uygulamanın ayağa kalkmayı reddetmesi, tek bir yazım hatası yüzünden
     * bütün siteyi indirmek olurdu. Yazma yolunda sınır AYRICA doğrulanıyor
     * (`Control\SmsController::updateNetgsm`) ve orada 422 dönüyor.
     */
    private static function normalize(string $value): string
    {
        return mb_substr(trim($value), 0, self::HEADER_MAX);
    }

    /**
     * Ayarı okur; tablo yoksa ya da okunamazsa `null`.
     *
     * GÖÇ KOŞMADAN ÖNCE DE ÇAĞRILABİLİR: gönderici konteynere kayıtlı bir
     * tekil olarak çözülüyor ve konsol komutları (`migrate` dahil) onu
     * çözebilir. Burada patlamak, göçün kendisini düşürürdü.
     */
    private static function option(string $key): mixed
    {
        try {
            if (!Schema::hasTable('location_options')) {
                return null;
            }

            $raw = DB::table('location_options')->where('item', $key)->value('value');
        } catch (Throwable) {
            // Veritabanı henüz yok (kurulum) ya da erişilemiyor: ortam
            // değişkenine düşmek, istisna fırlatmaktan iyidir.
            return null;
        }

        if ($raw === null) {
            return null;
        }

        $decoded = json_decode((string) $raw, true);

        return is_string($decoded) ? $decoded : null;
    }
}
