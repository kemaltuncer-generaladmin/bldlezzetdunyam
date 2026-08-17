<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Middleware;

use Closure;
use Igniter\Flame\Support\Facades\Igniter;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/**
 * TastyIgniter admin panelinin şalteri — kapalıyken `/admin/*` yoktur.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * NEDEN VAR: Kontrol Merkezi tek yönetim yüzeyi oldu. Panelin kendisi
 * KOD OLARAK DURUYOR (13 denetleyici, izinler, blade'ler, dil dosyaları);
 * kapatılan şey yalnızca ona giden yol. Gerekçe `docs/04-platform.md` §2.7:
 * KM çökerse yönetim tek bir ortam değişkeniyle geri gelmeli, bir sürüm
 * yayınlayarak değil.
 * ─────────────────────────────────────────────────────────────────────────
 *
 * ## 404, 403 DEĞİL
 *
 * `403` "burada bir panel var ama giremezsin" der; `404` panelin varlığını
 * hiç açık etmez. Kapatılan yüzeyin en değerli parçası giriş formuydu ve o
 * form kimlik bilgisi denemesinin (credential stuffing) tek hedefi. Var
 * olduğu bilinmeyen bir forma deneme yapılmaz.
 *
 * ## YOL DENETİMİ ŞART — ara katman iki listeye birden giriyor
 *
 * Panel tek bir rota kümesi değil, İKİ küme:
 *
 *   - `igniter-routes.adminMiddleware` → 13 admin denetleyicisi
 *     (`Igniter\Admin\Classes\RouteRegistrar::forAdminPages`)
 *   - `igniter-routes.middleware` → **giriş, çıkış ve parola sıfırlama**
 *     (`Igniter\User\Classes\RouteRegistrar`) ve varlık birleştiricisi
 *     (`forAssets`)
 *
 * İkincisi gözden kaçarsa kapatma işe yaramaz: bütün ekranlar `404` döner
 * ama `/admin/login` açık kalır — yani kapattığımızı sandığımız hâlde asıl
 * saldırı yüzeyi ayakta durur.
 *
 * İkinci liste storefront tarafında da kullanılıyor (`Igniter\Main`,
 * `ti-theme-orange`, `ti-ext-pages`). Bu yüzden karar İSTEĞİN YOLUNA
 * bakılarak veriliyor: yalnızca yönetim önekinin (`Igniter::adminUri()`,
 * varsayılan `/admin`) altındaki istekler kapanır. Yol denetimi olmasaydı
 * ara katman, aynı listeyi paylaşan her rotayı da kapatırdı.
 *
 * ## `/api/*` ETKİLENMEZ
 *
 * Bizim rotalarımız `api` yığınında (`Extension::registerRoutes()`) ve o
 * yığın ne `igniter` grubunu ne de bu iki listeyi kullanıyor. Yol denetimi
 * bunu ikinci kez garantiliyor: `/api/...` yönetim önekinin altında değil.
 * `Tests\Feature\AdminPanelClosedTest` bunu sabitliyor.
 */
class RequireAdminPanel
{
    /**
     * Şalterin ortam değişkeni. **Varsayılan kapalı.**
     *
     * Değişken hiç tanımlanmamışsa panel kapalıdır: unutulan bir satırın
     * cezası "panel kapalı kaldı" olsun, "panel açık kaldı" değil.
     */
    public const string ENV_KEY = 'BLD_ADMIN_ENABLED';

    /**
     * Çalışma anında okunan yapılandırma anahtarı.
     *
     * Ortam değişkeni `Extension::register()` içinde BİR KEZ okunup buraya
     * yazılıyor, ara katman ise her istekte BU anahtara bakıyor. İkisini
     * ayırmanın iki sebebi var:
     *
     *   1. `env()` çağrısı çalışma anında yapılmamalı — `config:cache`
     *      koşulduğunda yapılandırma dosyalarının dışındaki `env()`
     *      çağrıları hâlâ çalışır ama bu, Laravel'in açıkça uyardığı ve
     *      ileride kırılacak bir kullanım.
     *   2. Testler şalteri açabilmeli. Ortam değişkenini test içinden
     *      değiştirmek uygulamayı yeniden açmayı gerektirirdi; yapılandırma
     *      anahtarı `setUp()` içinde tek satırla çevriliyor
     *      (`docs/04-platform.md` §2.7).
     */
    public const string CONFIG_KEY = 'veykemtu.admin_panel_enabled';

    public function handle(Request $request, Closure $next): Response
    {
        if (self::enabled() || !self::isAdminPath($request)) {
            return $next($request);
        }

        /*
         * `abort(404)` YERİNE AÇIK `throw`: yardımcının dönüş tipi `never`
         * olarak bildirilmiş olsa da metodun `Response` sözü burada
         * okunabilir biçimde tutuluyor — istisnayı doğrudan atmak, "bu dal
         * hiç dönmez" bilgisini yardımcının içine gizlemiyor.
         */
        throw new NotFoundHttpException;
    }

    /** Panel şu an açık mı — çalışma anındaki tek doğru kaynak. */
    public static function enabled(): bool
    {
        return (bool) config(self::CONFIG_KEY, false);
    }

    /**
     * Ortam değişkeninin okunuşu — yalnızca açılışta, `Extension::register()`.
     *
     * `env()` "true"/"false" metinlerini kendiliğinden `bool`'a çeviriyor ama
     * `.env` dosyasına `1`, `on` ya da `evet` yazan biri de olacak. Metin
     * hâli açıkça karşılaştırılıyor: tanınmayan her değer KAPALI sayılır.
     */
    public static function enabledByEnvironment(): bool
    {
        $raw = env(self::ENV_KEY, false);

        if (is_bool($raw)) {
            return $raw;
        }

        return in_array(
            strtolower(trim((string) $raw)),
            ['1', 'true', 'on', 'yes'],
            strict: true,
        );
    }

    /**
     * İstek yönetim önekinin altında mı.
     *
     * `Igniter::runningInAdmin()` yeniden kullanılmadı: o metot yolu global
     * `request()` yardımcısından okuyor, yani ara katmana verilen istekten
     * değil. Aynı şeyi döndürdüğü sürece fark etmez; döndürmediği gün
     * (alt istek, test içinde elle kurulan istek) sessizce yanlış cevap
     * verir ve şalter ya hiç kapanmaz ya da her şeyi kapatır.
     *
     * Önek `IGNITER_ADMIN_URI` ile değiştirilebiliyor; sabit `/admin`
     * yazılsaydı öneki değiştiren kurulumda kapatma tamamen etkisiz kalırdı.
     */
    private static function isAdminPath(Request $request): bool
    {
        $prefix = trim(Igniter::adminUri(), '/');

        // Önek boşsa yönetim paneli kökte demektir; o kurulumda her isteği
        // kapatmak siteyi tümden kapatmak olurdu — bu şalterin işi değil.
        if ($prefix === '') {
            return false;
        }

        $path = trim($request->path(), '/');

        return $path === $prefix || str_starts_with($path, $prefix.'/');
    }
}
