<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi;

use Igniter\Admin\Classes\Navigation;
use Igniter\System\Classes\BaseExtension;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Database\Eloquent\Relations\Relation;
use Illuminate\Http\Request;
use Illuminate\Routing\Router;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Route;
use Override;
use Throwable;
use Veykemtu\BridgeApi\Admin\AdminRegistrar;
use Veykemtu\BridgeApi\Admin\NavigationTrimmer;
use Veykemtu\BridgeApi\Console\AdminUserCommand;
use Veykemtu\BridgeApi\Console\DemoMenuCommand;
use Veykemtu\BridgeApi\Console\KitchenDeviceCommand;
use Veykemtu\BridgeApi\Console\PurgeOrdersCommand;
use Veykemtu\BridgeApi\Console\SetupCommand;
use Veykemtu\BridgeApi\Console\TranslationAuditCommand;
use Veykemtu\BridgeApi\Exceptions\ApiExceptionRenderer;
use Veykemtu\BridgeApi\Http\Middleware\AuthenticateToken;
use Veykemtu\BridgeApi\Http\Middleware\RequireAppHeaders;
use Veykemtu\BridgeApi\Http\Middleware\RequireScope;

/**
 * BLD Köprü API eklentisi.
 *
 * Sözleşme: `docs/openapi.yaml` (normatif). Bu eklenti onu uygular.
 *
 * Çekirdeğe (`platform/vendor/`) dokunulmaz — ADR-02. Davranış değişikliği
 * yalnızca olay dinleyicisi, kendi rotalarımız ve eklemeli migration'larla
 * yapılır.
 */
class Extension extends BaseExtension
{
    /**
     * TastyIgniter polimorfik ilişkilerde morph map'i **zorunlu** kılar
     * (`Relation::enforceMorphMap`, çekirdeğin EventServiceProvider'ında).
     * Kayıtsız model kullanan ilk sorgu `ClassMorphViolationException` ile
     * patlar — Sanctum token'ının `tokenable_type` alanı da polimorfiktir.
     *
     * DİKKAT: `BaseExtension` `$morphMap` diye bir özelliği **okumaz**
     * (B-02'de doğrulandı — çekirdek eklentiler bile `Relation::morphMap()`'i
     * boot içinde elle çağırıyor). Özellik olarak tanımlamak sessizce
     * etkisiz kalır.
     *
     * Takma adlar sınıf yollarından bağımsızdır: sınıfı taşırsak veritabanı
     * satırları bozulmaz.
     */
    private const array MORPH_MAP = [
        'veykemtu_customer' => Models\ApiCustomer::class,
        'veykemtu_kitchen_device' => Models\KitchenDevice::class,
        'veykemtu_print_job' => Models\PrintJob::class,
    ];

    #[Override]
    public function register(): void
    {
        $this->registerConsoleCommand('veykemtu.setup', SetupCommand::class);
        $this->registerConsoleCommand('veykemtu.admin', AdminUserCommand::class);
        $this->registerConsoleCommand('veykemtu.kds', KitchenDeviceCommand::class);
        $this->registerConsoleCommand('veykemtu.demoMenu', DemoMenuCommand::class);
        $this->registerConsoleCommand('veykemtu.siparisTemizle', PurgeOrdersCommand::class);
        $this->registerConsoleCommand('veykemtu.ceviriDenetle', TranslationAuditCommand::class);
    }

    /**
     * Admin yüzeyleri `src/Admin/AdminRegistrar` içinde tanımlıdır.
     *
     * Burada yalnızca çağrılıyorlar: kayıt tanımlarının gövdesi bu
     * dosyada dursaydı, admin paneli üzerinde çalışan biriyle API
     * üzerinde çalışan biri aynı dosyada çakışırdı.
     */
    #[Override]
    public function registerSettings(): array
    {
        return AdminRegistrar::registerSettings();
    }

    #[Override]
    public function registerNavigation(): array
    {
        return AdminRegistrar::registerNavigation();
    }

    #[Override]
    public function registerPermissions(): array
    {
        return AdminRegistrar::registerPermissions();
    }

    #[Override]
    public function registerDashboardWidgets(): array
    {
        return AdminRegistrar::registerDashboardWidgets();
    }

    #[Override]
    public function boot(): void
    {
        Relation::morphMap(self::MORPH_MAP);
        $this->registerMiddlewareAliases();
        $this->registerRateLimiters();
        $this->registerRoutes();
        $this->registerExceptionRenderer();
        $this->trimAdminNavigation();
    }

    /**
     * Catering'e ait olmayan menü girdilerini gizler.
     *
     * Olay, `Navigation::loadItems()` tüm eklenti girdilerini kaydettikten
     * SONRA tetikleniyor; daha erken bir kancada silinen girdi hemen
     * ardından yeniden ekleniyordu.
     *
     * Dinleyici DEĞER DÖNDÜRMEMELİ: `fireSystemEvent` varsayılan olarak
     * `halt = true` ile çağrılıyor ve null olmayan ilk yanıt zinciri
     * kesiyor — buradan bir değer dönseydi bizden sonraki dinleyiciler
     * (ve ileride kuracağımız kendi girdilerimiz) hiç çalışmazdı.
     */
    private function trimAdminNavigation(): void
    {
        Event::listen(
            'admin.navigation.extendItems',
            static function(Navigation $navigation): void {
                NavigationTrimmer::trim($navigation);
            },
        );
    }

    private function registerMiddlewareAliases(): void
    {
        /** @var Router $router */
        $router = $this->app->make(Router::class);
        $router->aliasMiddleware('bld.headers', RequireAppHeaders::class);
        $router->aliasMiddleware('bld.auth', AuthenticateToken::class);
        $router->aliasMiddleware('bld.scope', RequireScope::class);
    }

    /**
     * Oran sınırları — `docs/03-api-sozlesmesi.md` §8.
     *
     * Mutfak sınırı cihaz başınadır, IP başına değil: kasa ve yönetici
     * çoğu zaman aynı ağdan çıkar ve IP sınırı ikisini birbirine kırdırırdı.
     */
    private function registerRateLimiters(): void
    {
        RateLimiter::for('bld-auth', static fn(Request $request): Limit => Limit::perMinute(10)
            ->by($request->ip() ?? 'bilinmeyen'));

        RateLimiter::for('bld-order', static fn(Request $request): Limit => Limit::perHour(20)
            ->by((string) ($request->user()?->getKey() ?? $request->ip())));

        RateLimiter::for('bld-kitchen', static fn(Request $request): Limit => Limit::perHour(1200)
            ->by((string) ($request->user()?->getKey() ?? $request->ip())));
    }

    /**
     * Rotalar yalnızca API isteklerinde yüklenir.
     *
     * TastyIgniter'ın web/admin middleware yığını (oturum, CSRF, tema)
     * bilinçli olarak uygulanmaz: API durumsuzdur ve token ile kimliklenir.
     */
    private function registerRoutes(): void
    {
        Route::middleware('api')
            ->group(__DIR__.'/../routes/api.php');
    }

    /**
     * Tüm API hatalarını sözleşmedeki tek biçime çevirir.
     *
     * Yalnızca `/api/*` isteklerinde devreye girer — admin panelin kendi hata
     * sayfaları bozulmamalı.
     */
    private function registerExceptionRenderer(): void
    {
        $this->app->make(\Illuminate\Contracts\Debug\ExceptionHandler::class)
            ->renderable(static function (Throwable $e, Request $request) {
                if (!$request->is('api/*')) {
                    return null;
                }

                return ApiExceptionRenderer::render($e, $request);
            });
    }
}
