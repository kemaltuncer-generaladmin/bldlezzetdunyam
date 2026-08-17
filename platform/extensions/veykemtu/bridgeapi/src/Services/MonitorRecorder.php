<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Illuminate\Support\Facades\App;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Throwable;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ErrorEvent;

/**
 * Sunucu istisnalarını durum monitörüne yazar — `docs/control/monitor.md`.
 *
 * Monitörün dört kaynağı var (kasa, mobil, web, sunucu). Üçünü istemciler
 * `POST /api/client-errors` ile besliyor; DÖRDÜNCÜSÜNÜ BESLEYEN TEK YER
 * BURASI. Bu sınıf yokken `Extension::registerExceptionReporter()` bir
 * `class_exists()` nöbetçisine takılıp sessizce erken dönüyordu: ekran
 * çalışıyor, `source = server` satırı hiç doğmuyordu.
 *
 * Çağıran `reportable()` kancasıdır, yani `renderable()`'ın göremediği
 * hatalar da buraya gelir: gece koşan abonelik üretimi, stok tazeleme, SMS
 * duyurusu, kuyruk işleri. Onların hiçbiri kimseye yanıt döndürmüyor ve
 * arızaları yalnız burada görünür oluyor.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * BU SINIF ASLA İSTİSNA FIRLATMAZ.
 *
 * Kendisi bir HATA BİLDİRME yoludur ve hata bildirmenin kendisi hata
 * üretirse döngü kapanır: veritabanı düşer → istisna → yazma denemesi →
 * ikinci istisna → yeniden buraya… Tek bir DB kesintisi sonsuz döngüye ve
 * dolan bir yığına dönerdi.
 *
 * İki katman var ve İKİSİ DE GEREKLİ:
 *
 *   1. `$recording` bayrağı — YENİDEN GİRİŞİ keser. Yazma sırasında doğan
 *      istisna `report()` üzerinden bu metoda geri girebilir; sarmalayıcı
 *      `catch` o iç içe girişi görmez, çünkü henüz `catch`'e ulaşmamıştır.
 *      Bayrak STATİK: kancayı taşıyan kap her istisnada `make()` ile YENİ
 *      bir örnek çözüyor ve örnek alanı ikinci çağrıda sıfırdan başlardı.
 *      `finally` ile sıfırlanıyor — kalıcı `true` kalsaydı ilk hatadan
 *      sonra monitör bir daha hiç yazmazdı.
 *
 *   2. Sarmalayıcı `catch (Throwable)` — yazma hatası SESSİZCE YUTULUR.
 *      Yerine bir şey günlüğe düşürmek de aynı riski taşıyor. Hatayı asıl
 *      isteyen zaten Laravel'in kendi günlük kanalı; o kanal bu kancadan
 *      bağımsız çalışıyor ve burada bir şey yutulsa bile kaydı tutuyor.
 * ─────────────────────────────────────────────────────────────────────────
 *
 * TEKİLLEŞTİRME `ErrorEvent::record()`'A BIRAKILIYOR. Parmak izi üretimi,
 * yarışa dayanıklı artırım ve sütun kırpması orada tek bir yerde duruyor;
 * ikinci bir kopya çıkarmak, istemci ile sunucu satırlarının zamanla farklı
 * kurallarla toplanmasına ve "hangi bileşen daha çok hata üretiyor"
 * sorusunun cevabının bozulmasına yol açardı.
 */
class MonitorRecorder
{
    /**
     * Parmak izine giren yığın çerçevesi sayısı.
     *
     * Üç, "hata nerede doğdu" sorusunu ayırt etmeye yeter — istemci
     * tarafındaki tarifle (`packages/core/lib/src/error_fingerprint.dart`)
     * bilerek aynı. Daha derini, aynı hatanın farklı çağrı yollarından gelen
     * kopyalarını ayrı satırlara böler ve tekilleştirmeyi işe yaramaz kılar.
     */
    private const int FRAME_COUNT = 3;

    /** `context.route` için tavan — `ClientErrorController` ile aynı. */
    private const int ROUTE_LIMIT = 200;

    /**
     * Yazma sürüyor mü? Sınıf yorumundaki (1) numaralı katman.
     */
    private static bool $recording = false;

    /**
     * Bir sunucu istisnasını monitöre yazar.
     *
     * DÖNÜŞ YOK VE İSTİSNA YOK: çağıran `reportable()` kancası ve onun tek
     * beklentisi "beni etkileme".
     */
    public function recordServerException(Throwable $e): void
    {
        if (self::$recording) {
            return;
        }

        self::$recording = true;

        try {
            $this->write($e);
        } catch (Throwable) {
            // BİLEREK BOŞ — sınıf yorumundaki (2) numaralı katman. Buraya
            // `report()`, `Log::` ya da `error_log()` koymak, hata
            // bildirmenin kendisini yeniden hata üreten bir işe çevirir.
        } finally {
            self::$recording = false;
        }
    }

    /** Asıl yazma; her istisnası çağıranda yutulur. */
    private function write(Throwable $e): void
    {
        if (self::isClientFault($e)) {
            return;
        }

        $type = $e::class;
        $frames = self::frames($e);

        /*
         * PARMAK İZİNE GİREN ÜÇ ÇERÇEVE.
         *
         * `ErrorEvent::fingerprint()` anahtarı `kaynak|tür|ayırt edici|mesaj`
         * diye kuruyor ve bütün anahtardan rakamları siliyor; yığın buraya,
         * "ayırt edici" alandan giriyor.
         *
         * ÇERÇEVESİZ BİR İZ ÇOK GENİŞ TOPLARDI: "Undefined array key" ya da
         * "Call to a member function on null" gibi mesajlar sistemin on ayrı
         * yerinden aynı metinle gelir. Hepsi tek satıra katlanır ve
         * `occurrences` yükselirken hangi kodun bozuk olduğu görünmez olurdu.
         *
         * EKSİK ÇERÇEVELER BOŞ DİZEYLE TAMAMLANIYOR (istemci tarifiyle aynı):
         * tamamlanmasaydı iki çerçeveli bir hata ile üç çerçeveli başka bir
         * hata aynı metne katlanabilirdi.
         */
        $trace = implode('|', array_pad(
            array_slice($frames, 0, self::FRAME_COUNT),
            self::FRAME_COUNT,
            '',
        ));

        ErrorEvent::record(
            // SABİT `server`. İstemciden gelen `source` burada hiç okunmaz;
            // o `ClientErrorController`'ın işi ve orada `X-App-Id`'den
            // türetiliyor. Buradan yazılan her satır tanım gereği sunucunun
            // kendi hatası.
            source: ErrorEvent::SOURCE_SERVER,
            level: ErrorEvent::LEVEL_ERROR,
            type: $type,
            message: self::messageOf($e, $type),
            stack: implode("\n", $frames),
            context: self::contextFor($e),
            // `occurred_at` BOŞ BIRAKILIYOR: o sütun "hata İSTEMCİDE ne
            // zaman oldu" sorusunun cevabı ve çevrimdışı biriktirilip sonra
            // gönderilen raporları ayırt etmek için var. Sunucu hatasında
            // oluş anı ile alış anı aynı; doldurmak `last_seen_at`'i ikinci
            // kez yazmaktan ibaret olurdu.
            discriminator: $trace,
        );
    }

    /**
     * İstemcinin kendi hatası mı? (4xx)
     *
     * VARSAYIM: 4xx ayıklanıyor. Süzgeç olmasaydı süresi dolmuş her
     * belirteç, yanlış yazılmış her telefon numarası ve bulunamayan her
     * sipariş monitöre "sunucu hatası" olarak düşerdi — çünkü `ApiException`
     * düz bir `Exception` ve Laravel'in `dontReport` listesine girmiyor. O
     * satırlar sayıca gerçek çökmeleri kat kat aşar ve ekranı tam da
     * görülmesi gereken şeyi gizleyecek şekilde doldururdu.
     *
     * Bilgi KAYBOLMUYOR: 4xx zaten istemciye sözleşmedeki gövdeyle dönüyor
     * ve Laravel'in günlük kanalına da düşüyor. Monitör, BAŞKA HİÇBİR YERDE
     * GÖRÜNMEYEN arızalar için var.
     *
     * 5xx ayıklanmıyor: `ApiException::serverError()` bizim tarafımızdaki
     * bir arızayı anlatır ve monitörün asıl işi odur.
     */
    private static function isClientFault(Throwable $e): bool
    {
        $status = match (true) {
            $e instanceof ApiException => $e->status,
            $e instanceof HttpExceptionInterface => $e->getStatusCode(),
            default => 0,
        };

        return $status >= 400 && $status < 500;
    }

    /**
     * Mesaj; boşsa istisnanın sınıf adı.
     *
     * `message` sütunu NOT NULL ve `ErrorEvent::record()` boş metni `null`'a
     * çeviriyor. Mesajsız bir istisna (`throw new RuntimeException;`)
     * yakalanmasaydı yazma SQL hatasıyla düşer, yani "hata kaydedilemedi"
     * durumu tam da bir hata varken doğardı. Sınıf adı en azından nerede
     * arayacağını söylüyor.
     */
    private static function messageOf(Throwable $e, string $type): string
    {
        $message = trim($e->getMessage());

        return $message === '' ? $type : $message;
    }

    /**
     * Yığın çerçeveleri — İLK ÇERÇEVE HATANIN DOĞDUĞU YER.
     *
     * `getTrace()` sıfırıncı çerçeve olarak fırlatan fonksiyonun
     * ÇAĞIRANINI verir; `getFile()`/`getLine()` ise `throw` satırının
     * kendisidir. Yalnız izle yetinilseydi parmak izi, hatanın doğduğu
     * satırı hiç görmez ve aynı yardımcıdan çağrılan iki farklı arıza tek
     * satıra katlanırdı.
     *
     * ARGÜMANLAR HİÇ OKUNMAZ. `getTraceAsString()` skaler argümanları
     * metne basar — parola, telefon, adres. Monitör satırları Kontrol
     * Merkezi ekranında görünüyor ve hata kaydı kişisel veri saklamak için
     * yanlış yer (aynı gerekçe `ClientErrorController::pathOnly()`'de).
     * Bu yüzden çerçeveler elle kuruluyor: dosya, satır ve çağrı adı.
     *
     * @return list<string>
     */
    private static function frames(Throwable $e): array
    {
        $frames = [self::position($e->getFile(), $e->getLine())];
        $length = mb_strlen($frames[0]);

        foreach ($e->getTrace() as $frame) {
            /*
             * TAVANA GELİNCE DURULUYOR. Sonsuz özyinelemeye giren bir kod
             * on binlerce çerçeve üretir; hepsini biçimlendirip sonra
             * kesmek, kesilecek metni önce belleğe kurmak demekti — hem de
             * belleğin zaten daraldığı anda.
             */
            if ($length >= ErrorEvent::STACK_LIMIT) {
                break;
            }

            $line = self::describe($frame);
            $frames[] = $line;
            $length += mb_strlen($line) + 1;
        }

        return $frames;
    }

    /**
     * Tek çerçevenin metni: `dosya:satır: Sınıf->metot()`.
     *
     * @param array<string, mixed> $frame
     */
    private static function describe(array $frame): string
    {
        $where = isset($frame['file'])
            ? self::position((string) $frame['file'], (int) ($frame['line'] ?? 0))
            // Dahili çağrılarda (`array_map`, `call_user_func`) dosya yok;
            // çerçeveyi atlamak yerine işaretlemek gerekiyor ki sonraki
            // çerçeveler parmak izinde bir kaydırmaya sebep olmasın.
            : '[internal]';

        $call = (string) ($frame['class'] ?? '')
            .(string) ($frame['type'] ?? '')
            .(string) ($frame['function'] ?? '');

        return self::normalize($where.': '.$call.'()');
    }

    private static function position(string $file, int $line): string
    {
        return $file.':'.$line;
    }

    /**
     * Serbest bağlam — "hangi yol patladı" sorusunun cevabı.
     *
     * KİŞİSEL VERİ GİRMEZ: istek gövdesi, sorgu dizesi ve başlıklar hiç
     * okunmuyor. `path()` zaten sorgusuz döner.
     *
     * @return array<string, mixed>
     */
    private static function contextFor(Throwable $e): array
    {
        $context = ['origin' => self::position($e->getFile(), $e->getLine())];

        $previous = $e->getPrevious();

        if ($previous !== null) {
            // Sarmalayan istisnanın sınıfı çoğu zaman hiçbir şey anlatmıyor
            // (`QueryException`); asıl teşhis sarılanda (`PDOException`).
            $context['previous'] = $previous::class;
        }

        /*
         * KONSOLDA ROTA YAZILMAZ. Laravel konsolda da bir `Request` örneği
         * tutuyor ama yolu `/`, metodu `GET` olur; yazsaydık her gece işi
         * hatası panelde ana sayfada olmuş gibi görünürdü. (PHPUnit de
         * konsol sayılır — testlerde bu dal beklenen şekilde `console`
         * döner.)
         */
        if (App::runningInConsole()) {
            $context['channel'] = 'console';

            return $context;
        }

        $request = request();

        $context['channel'] = 'http';
        $context['route'] = mb_substr('/'.ltrim($request->path(), '/'), 0, self::ROUTE_LIMIT);
        $context['method'] = $request->method();

        return $context;
    }

    /**
     * Boşluk dizilerini tekleştirir.
     *
     * Parmak izine giren metinlerde şart: aynı çerçeve sürümden sürüme
     * farklı girintilenirse iki ayrı olay doğardı.
     */
    private static function normalize(string $value): string
    {
        return trim((string) preg_replace('/\s+/u', ' ', $value));
    }
}
