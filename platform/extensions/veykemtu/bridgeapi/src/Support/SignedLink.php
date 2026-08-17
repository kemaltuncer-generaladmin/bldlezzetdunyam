<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Support;

/**
 * Fişe basılan bağlantıların imzası (K-20).
 *
 * Kâğıda basılan iki QR var ve ikisini de **giriş yapmamış** biri okutuyor:
 * müşteri takip bağlantısını, kurye teslim bağlantısını. Yetki oturumda
 * değil, URL'nin kendisinde.
 *
 * NEDEN LARAVEL'İN `URL::temporarySignedRoute`'U KULLANILMIYOR: onun imzası
 * **mutlak URL'ye** bağlıdır, yani API alan adına. Takip bağlantısı ise
 * müşteri sitesinde (`FRONTEND_URL`) açılıyor ve doğrulaması API'de
 * yapılıyor; URL'ye bağlı bir imza bu atlamayı yaşayamaz. İki bağlantıdan
 * birinde çerçeve imzası, diğerinde kendi imzamız olsaydı iki ayrı kripto
 * yolu, iki ayrı hata biçimi ve iki ayrı test yüzeyi doğardı.
 *
 * Bu, "kendi kütüphaneni yazma" (AGENTS §4) ihlali değil: depo aynı deseni
 * zaten taşıyor — `Http/Middleware/VerifyBbdSignature.php`, kanonik dize →
 * `hash_hmac('sha256', ...)` → `hash_equals`.
 *
 * Sınıf **ilkel değerlerle** çalışır; `Order` bilmez. Zaman çıpası çağırandan
 * gelir, çünkü siparişin "istenen teslim anı" hesabı `OrderPresenter`'da ve
 * orada kalmalı.
 */
final class SignedLink
{
    /**
     * Amaç, imzanın İÇİNDEDİR.
     *
     * Takip bağlantısı teslim bağlantısı olarak yeniden oynatılamasın diye:
     * ikisi de aynı sipariş ve aynı süre için üretilse bile imzaları farklı
     * çıkar. Amaç dışarıda kalsaydı, siparişini takip eden müşteri aynı
     * imzayla siparişini "teslim edildi" işaretleyebilirdi.
     */
    public const string PURPOSE_TRACK = 't';

    public const string PURPOSE_DELIVER = 'd';

    /**
     * Abonelik sözleşmesi bağlantısı (iş kararı 9).
     *
     * AMAÇ HMAC'İN İÇİNDE OLDUĞU İÇİN bir takip bağlantısı sözleşme onayı
     * olarak yeniden oynatılamaz: aynı kimlik ve aynı süre için üretilseler
     * bile imzaları farklı çıkar. Bu, sınıfın en başından beri taşıdığı
     * özellik; sözleşme onun üçüncü kullanıcısı.
     *
     * DİKKAT — kimlik alanı burada SİPARİŞ DEĞİL SÖZLEŞME kimliğidir.
     * `sign()` ilkel bir tam sayı aldığı için tip bunu ayırt etmez; ayrımı
     * yapan tek şey amaç sabitidir. Sipariş 7'nin takip bağlantısı ile
     * sözleşme 7'nin bağlantısı bu yüzden birbirine çözülmez.
     */
    public const string PURPOSE_CONTRACT = 'c';

    /**
     * Takip bağlantısı 14 gün yaşar.
     *
     * VARSAYIM: müşteri fişi buzdolabı kapağında kalıyor ve sipariş
     * kapandıktan sonra da "ne zaman gelmişti" diye okunabiliyor. İki hafta,
     * fişin masada unutulma süresinden uzun, sonsuz olmaktan kısa.
     */
    public const int TRACK_TTL_DAYS = 14;

    /**
     * Teslim bağlantısı 2 gün yaşar.
     *
     * VARSAYIM: kurye kâğıdı aldığı gün kullanıyor. Kısa tutmak, çöpten
     * çıkarılan bir fişin siparişi kapatabildiği pencereyi daraltıyor.
     */
    public const int DELIVER_TTL_DAYS = 2;

    /**
     * Sözleşme bağlantısı 7 gün yaşar.
     *
     * `docs/control/subscriptions.md` → `POST /{id}/contracts`:
     * `expires_in_days` 1–30, varsayılan 7. Süresiz bir imza bağlantısı bir
     * yıl sonra ele geçtiğinde hâlâ geçerli olurdu; bir hafta ise kurumsal
     * onayın elden ele dolaşmasına yetiyor.
     */
    public const int CONTRACT_TTL_DAYS = 7;

    private function __construct() {}

    /**
     * İmzalama yapılabiliyor mu?
     *
     * `false` ise çağıranlar bağlantı üretmiyor ve KDS QR'ı hiç basmıyor —
     * fiş bugünkü hâline, QR'sız, geriliyor. Çalışmayan bir kare basmak,
     * okutup boş sayfa gören müşteri üretmekten iyi değil.
     */
    public static function isConfigured(): bool
    {
        return self::secret() !== '';
    }

    /**
     * Bağlantının son geçerlilik anı — **saate değil siparişe** bağlı.
     *
     * NEDEN `now()->addDays()` DEĞİL, iki sebep:
     *
     * 1. **Belirlilik.** KDS fişi birden çok kez çekiyor (yeniden deneme,
     *    "yeniden bas", kuyruk). Saatten türeyen bir süre her çekilişte
     *    başka bir URL üretirdi; golden test tutmaz, aynı siparişin iki
     *    kâğıdındaki QR birbirini tutmazdı.
     * 2. **Catering ileri tarihli.** Pazartesi verilen cumartesi siparişinin
     *    teslim bağlantısı, yemek mutfaktan çıkmadan ölmüş olurdu. Bu yüzden
     *    çıpa teslim anından da erken olamaz.
     *
     * @param int      $createdAt   Siparişin oluşturulma anı (unix saniye).
     * @param int|null $requestedAt İstenen teslim anı; ASAP siparişte `null`.
     */
    public static function expiresAt(int $createdAt, ?int $requestedAt, int $days): int
    {
        return max($createdAt, $requestedAt ?? 0) + ($days * 86400);
    }

    /**
     * Kanonik yük: `{amaç}.{sipariş}.{bitiş}` — JSON değil, URL değil.
     *
     * Üç parça da imzanın içinde: amaç yeniden oynatmayı, sipariş kimliği
     * sıralı deneme ile başkasının siparişine geçmeyi, bitiş anı ise
     * bağlantının kendi süresini uzatmayı engelliyor.
     */
    public static function sign(string $purpose, int $orderId, int $expiresAt): string
    {
        $raw = hash_hmac(
            'sha256',
            $purpose.'.'.$orderId.'.'.$expiresAt,
            self::secret(),
            true,
        );

        /*
         * 128 BİTE KIRPILIYOR. Tam altılık gösterim 64 karakter; QR modül
         * sayısı 80 mm termal kafada gerçek bir kısıt ve kare büyüdükçe ucuz
         * yazıcıda okunurluk düşüyor. 128 bit, sırrı bilmeden imza uydurmak
         * için gereken denemeyi hâlâ ulaşılamaz kılıyor.
         */
        return rtrim(strtr(base64_encode(substr($raw, 0, 16)), '+/', '-_'), '=');
    }

    /**
     * İmza doğru mu?
     *
     * `hash_equals` KULLANILIYOR, `===` DEĞİL: eşitlik karşılaştırması ilk
     * farklı baytta duruyor ve geçen süreden imza tahmin edilebiliyor. Aynı
     * gerekçe `VerifyBbdSignature` içinde de yazılı.
     */
    public static function verify(
        string $purpose,
        int $orderId,
        int $expiresAt,
        string $signature,
    ): bool {
        if (!self::isConfigured() || $signature === '') {
            return false;
        }

        return hash_equals(self::sign($purpose, $orderId, $expiresAt), $signature);
    }

    /** Bağlantının süresi doldu mu? */
    public static function isExpired(int $expiresAt): bool
    {
        return $expiresAt < time();
    }

    /**
     * İmzalama sırrı.
     *
     * `BLD_LINK_SECRET` AYRI BİR DEĞİŞKEN, çünkü bağlantı imzaları
     * döndürülebilmeli; `APP_KEY` döndürmek oturumları ve şifrelenmiş
     * sütunları da geçersiz kılardı.
     *
     * VARSAYIM: tanımsızsa `app.key`'e düşülüyor. BBD ucu boş sırla kapalı
     * kalıyor çünkü orası **gelen** bir kapı ve açık bırakmak tehlikeli.
     * Burada kapalı kalmak yalnızca fişten iki QR'ı sessizce siler — eksik
     * bir dağıtım adımının sebep olduğu operasyonel bir gerileme. `app.key`
     * ayağa kalkmış her Laravel uygulamasında var, yani özellik ilk günden
     * çalışıyor ve ayrı değişken bir iyileştirme oluyor, önkoşul değil.
     */
    private static function secret(): string
    {
        $dedicated = trim((string) env('BLD_LINK_SECRET', ''));
        if ($dedicated !== '') {
            return $dedicated;
        }

        return trim((string) config('app.key', ''));
    }
}
