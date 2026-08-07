<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi;

use Igniter\Admin\Classes\Navigation;
use Igniter\System\Classes\BaseExtension;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Console\Scheduling\Schedule;
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
use Veykemtu\BridgeApi\Console\AccountEntryCommand;
use Veykemtu\BridgeApi\Console\AccountPeriodCommand;
use Veykemtu\BridgeApi\Console\AdminUserCommand;
use Veykemtu\BridgeApi\Console\DemoMenuCommand;
use Veykemtu\BridgeApi\Console\KitchenDeviceCommand;
use Veykemtu\BridgeApi\Console\MenuImageCommand;
use Veykemtu\BridgeApi\Console\PurgeOrdersCommand;
use Veykemtu\BridgeApi\Console\SetupCommand;
use Veykemtu\BridgeApi\Console\SiteContentImportCommand;
use Veykemtu\BridgeApi\Console\SubscriptionGenerateCommand;
use Veykemtu\BridgeApi\Console\TranslationAuditCommand;
use Veykemtu\BridgeApi\Exceptions\ApiExceptionRenderer;
use Veykemtu\BridgeApi\Http\Middleware\AuthenticateToken;
use Veykemtu\BridgeApi\Http\Middleware\RequireAppHeaders;
use Veykemtu\BridgeApi\Http\Middleware\RequireScope;
use Veykemtu\BridgeApi\Models\SiteContent;
use Veykemtu\BridgeApi\Models\SitePost;
use Veykemtu\BridgeApi\Models\SiteService;
use Veykemtu\BridgeApi\Observers\SiteContentObserver;
use Veykemtu\BridgeApi\Support\BusinessTime;

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
        $this->registerConsoleCommand('veykemtu.menuGorselleri', MenuImageCommand::class);
        $this->registerConsoleCommand('veykemtu.siparisTemizle', PurgeOrdersCommand::class);
        $this->registerConsoleCommand('veykemtu.ceviriDenetle', TranslationAuditCommand::class);
        $this->registerConsoleCommand('veykemtu.siteIceriginiAktar', SiteContentImportCommand::class);
        $this->registerConsoleCommand('veykemtu.cariHareket', AccountEntryCommand::class);
        $this->registerConsoleCommand('veykemtu.cariDonemOzeti', AccountPeriodCommand::class);
        $this->registerConsoleCommand('veykemtu.abonelikUret', SubscriptionGenerateCommand::class);
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

    /**
     * Zamanlanmış işler — sunucudaki `schedule:run` cron'u tetikler.
     *
     * Gece üretim işi kesim saatinden ÖNCE (22:00) koşar; müşteriye sabaha
     * kadar adet değiştirme payı kalır. İkisi de `withoutOverlapping` —
     * uzun süren bir koşum bir sonrakiyle üst üste binmez. Saat dilimi
     * `BusinessTime::ZONE` (Istanbul); sunucu UTC olsa da işler yerel saatle.
     */
    #[Override]
    public function registerSchedule(Schedule $schedule): void
    {
        $schedule->command('veykemtu:abonelik-uret')
            ->name('BLD abonelik üretim')
            ->dailyAt('22:00')
            ->timezone(BusinessTime::ZONE)
            ->withoutOverlapping()
            ->runInBackground();

        // 04:00 Istanbul = 01:00 UTC — ayın 1'inde kalır. `01:00` seçilseydi
        // UTC'ye çevrilince önceki ayın son gününe kayar ve 31 çekmeyen
        // aylarda hiç tetiklenmezdi (timezone + monthlyOn tuzağı).
        $schedule->command('veykemtu:cari-donem-ozeti')
            ->name('BLD cari ay-sonu özeti')
            ->monthlyOn(1, '04:00')
            ->timezone(BusinessTime::ZONE)
            ->withoutOverlapping();
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
        $this->observeSiteContent();
    }

    /**
     * Kurumsal site içeriği değişince paket önbelleğini düşürür.
     *
     * KAYIT BURADA, MODELLERİN `booted()`'INDA DEĞİL: gerekçe
     * `Observers\SiteContentObserver` sınıf yorumundadır. Üç modelin de aynı
     * gözlemciyi paylaşması, "yeni bir içerik modeli eklendi ama önbellek
     * temizliği unutuldu" hatasını tek satıra indirir.
     */
    private function observeSiteContent(): void
    {
        SiteContent::observe(SiteContentObserver::class);
        SiteService::observe(SiteContentObserver::class);
        SitePost::observe(SiteContentObserver::class);
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
     * Oran sınırları — `docs/03-api-sozlesmesi.md` §10.
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

        /*
         * Teklif formu — SAATLİK pencere, dakikalık değil.
         *
         * `bld-auth` (10/dakika) yeniden kullanılmadı: o sınır kaba kuvvet
         * denemesini yavaşlatmak için var ve saatte 600 gönderime izin
         * veriyor. Teklif formunda 600 gönderim spam'dir ve hepsi panele
         * düşerdi; gerçek talepler o yığının içinde kaybolurdu.
         *
         * 10/saat, aynı ofisten (tek NAT arkasından) birkaç kişinin ayrı
         * ayrı teklif istemesine yer bırakırken otomatik doldurmayı
         * anlamsız kılar. Sınır IP başına: talebi gönderende hesap yok.
         */
        RateLimiter::for('bld-quote', static fn(Request $request): Limit => Limit::perHour(10)
            ->by($request->ip() ?? 'bilinmeyen'));
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
