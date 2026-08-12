<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi;

use Igniter\Admin\Classes\AdminController;
use Igniter\Admin\Classes\Navigation;
use Igniter\Admin\Facades\Template;
use Igniter\Flame\Support\Facades\Igniter;
use Igniter\System\Classes\BaseExtension;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Contracts\View\View;
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
use Veykemtu\BridgeApi\Http\Middleware\VerifyBbdSignature;
use Veykemtu\BridgeApi\Models\SiteContent;
use Veykemtu\BridgeApi\Models\SitePost;
use Veykemtu\BridgeApi\Models\SiteService;
use Veykemtu\BridgeApi\Observers\SiteContentObserver;
use Veykemtu\BridgeApi\Services\Sms\LogSmsSender;
use Veykemtu\BridgeApi\Services\Sms\NetgsmSmsSender;
use Veykemtu\BridgeApi\Services\Sms\SmsSender;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\Payment\Payments\SimulatedPos;

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
        $this->disableStorefrontTheme();
        $this->registerSmsSender();

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
     * TastyIgniter'ın kendi vitrin temasını kapatır (I-07).
     *
     * SORUN: `IGNITER_URI` tanımsız olduğu için çekirdek, kurulu
     * `ti-theme-orange` temasının bütün sayfalarını `/` altına bağlıyordu
     * (`Igniter\Main\Classes\RouteRegistrar::forThemePages`). Sonuç:
     * api.benimlezzetdunyam.com.tr kökünde, kimsenin bakmadığı ve
     * güncellenmeyen ikinci bir "BLD sitesi" duruyordu — gerçek müşteri
     * yüzü ise `website/` (Next.js).
     *
     * NEDEN `register()`, `boot()` DEĞİL: rotalar
     * `Igniter\Main\ServiceProvider::boot()` içinde tanımlanıyor. Eklentiler
     * `ExtensionServiceProvider::register()` sırasında kaydediliyor, yani
     * bizim `register()`'ımız çekirdeğin `boot()`'undan önce koşuyor;
     * `boot()`'a yazsaydık bayrağı rotalar kurulduktan SONRA çevirmiş
     * olurduk ve hiçbir etkisi olmazdı.
     *
     * `_assets` birleştirici rotası ETKİLENMEZ — o `forAssets()` içinde ayrı
     * kaydediliyor ve admin panelin CSS/JS'i oradan geliyor.
     */
    private function disableStorefrontTheme(): void
    {
        Igniter::disableThemeRoutes(true);
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
        $this->brandAdminPanel();
        $this->observeSiteContent();
    }

    /**
     * SMS göndericisini seçer — B-18.
     *
     * SAĞLAYICI SIRLARI ORTAM DEĞİŞKENİNDE, VERİTABANINDA DEĞİL. Panelden
     * girilebilir bir ayar olsaydı sır her veritabanı yedeğine girerdi;
     * yedekler ise sırlardan çok daha kolay dolaşıyor.
     *
     * ÜÇÜ BİRDEN TANIMLI DEĞİLSE GÜNLÜĞE DÜŞER, PATLAMAZ. Yarım
     * yapılandırmayla ayağa kalkmayı reddetmek, tek bir eksik değişken
     * yüzünden bütün siteyi indirmek olurdu — oysa SMS yalnızca ikinci bir
     * giriş yolu; e-posta + şifre çalışmaya devam ediyor. `LogSmsSender`
     * ayrıca `warning` seviyesinde yazıyor, yani eksiklik günlükte
     * gözden kaçmıyor.
     */
    private function registerSmsSender(): void
    {
        $this->app->singleton(SmsSender::class, static function (): SmsSender {
            $username = (string) env('NETGSM_USERNAME', '');
            $password = (string) env('NETGSM_PASSWORD', '');
            $header = (string) env('NETGSM_HEADER', '');

            if ($username === '' || $password === '' || $header === '') {
                return new LogSmsSender;
            }

            return new NetgsmSmsSender($username, $password, $header);
        });
    }

    /**
     * Panele BLD kimliğini ve simülasyon uyarısını giydirir (B-12).
     *
     * CSS `admin.controller.beforeRemap` ile ekleniyor: olay HER admin
     * denetleyicisinde (giriş ekranı dahil — `igniter.user::Login` de bir
     * `AdminController`) ve sayfa çizilmeden önce tetikleniyor. Bir
     * denetleyiciye tek tek eklemek, ileride yazılan her ekranda
     * unutulabilecek bir satır olurdu.
     *
     * Dosya `public/` altına YAYINLANMIYOR: çekirdeğin varlık
     * birleştiricisi (`_assets/{hash}`) onu doğrudan eklenti klasöründen
     * okuyor. Yayınlansaydı, `Dockerfile.web` için ikinci bir kopyalama
     * adımı daha gerekirdi (bkz. I-08).
     *
     * Şerit `startHeader` kancasına bağlı; `ti-ext-user`'ın kimliğe bürünme
     * şeridi de aynı mekanizmayı kullanıyor.
     */
    private function brandAdminPanel(): void
    {
        Event::listen(
            'admin.controller.beforeRemap',
            static function(AdminController $controller): void {
                $controller->addCss('veykemtu.bridgeapi::/css/admin.css', 'bld-admin-css');
            },
        );

        if (!SimulatedPos::isAllowed()) {
            return;
        }

        Template::registerHook(
            'startHeader',
            static fn(): View => view('veykemtu.bridgeapi::_partials.admin.simulation_banner'),
        );
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
        // BBD Store köprüsü (K-16) — HMAC imzası, token değil.
        $router->aliasMiddleware('bbd.signature', VerifyBbdSignature::class);
    }

    /**
     * Oran sınırları — `docs/03-api-sozlesmesi.md` §10.
     *
     * Mutfak sınırı cihaz başınadır, IP başına değil: kasa ve yönetici
     * çoğu zaman aynı ağdan çıkar ve IP sınırı ikisini birbirine kırdırırdı.
     */
    private function registerRateLimiters(): void
    {
        RateLimiter::for('bld-auth', static fn(Request $request): Limit => Limit::perMinute(60)
            ->by($request->ip() ?? 'bilinmeyen'));

        RateLimiter::for('bld-order', static fn(Request $request): Limit => Limit::perHour(20)
            ->by((string) ($request->user()?->getKey() ?? $request->ip())));

        /*
         * MUTFAK SINIRI — bütçe hesaplı (12.08.2026'da yeniden ölçüldü).
         *
         * Sınır 600'den 1200'e, oradan 2000'e çıktı. Her seferinde
         * kasanın gerçekte attığı istek sayısı sayıldı; "biraz daha
         * yükseltelim" diye değil.
         *
         * Kasa başına saatlik istek bütçesi:
         *
         *   sipariş yoklaması   5 sn  → 720   (docs/05 §4)
         *   BBD kuyruğu        20 sn  → 180   (K-16)
         *   heartbeat          60 sn  →  60
         *   sağlık bildirimi   60 sn  →  60
         *   satış şalteri      60 sn  →  60   (K-11, yavaş saat)
         *   abonelik listesi   60 sn  →  60   (yavaş saat)
         *                              ────
         *   sürekli toplam              1140
         *
         * Kalan ~860 kullanıcı kaynaklı ve patlamalı: F5 tam yenileme,
         * fiş yeniden basma, düzenleme ekranı (editable + menu +
         * revisions), satış kontrolü ekranı, abonelik planı sekmeleri.
         * Yoğun bir vardiyada bunlar yüzlerce isteğe çıkabiliyor.
         *
         * SINIR NEDEN BU KADAR ÖNEMLİ: aşıldığında kasa `429` alıyor ve
         * mutfak SİPARİŞ GÖRMÜYOR. Sessiz değil (bağlantı uyarısı çalar)
         * ama sebebi anlaşılmaz — ağ sağlam, sunucu ayakta, yalnız
         * sayaç dolmuş.
         */
        RateLimiter::for('bld-kitchen', static fn(Request $request): Limit => Limit::perHour(2000)
            ->by((string) ($request->user()?->getKey() ?? $request->ip())));

        /*
         * Teklif formu — SAATLİK pencere, dakikalık değil.
         *
         * `bld-auth` (60/dakika) yeniden kullanılmadı: o sınır kaba kuvvet
         * denemesini yavaşlatmak için var ve saatte 3600 gönderime izin
         * veriyor. Teklif formunda 3600 gönderim spam'dir ve hepsi panele
         * düşerdi; gerçek talepler o yığının içinde kaybolurdu.
         *
         * 10/saat, aynı ofisten (tek NAT arkasından) birkaç kişinin ayrı
         * ayrı teklif istemesine yer bırakırken otomatik doldurmayı
         * anlamsız kılar. Sınır IP başına: talebi gönderende hesap yok.
         */
        RateLimiter::for('bld-quote', static fn(Request $request): Limit => Limit::perHour(10)
            ->by($request->ip() ?? 'bilinmeyen'));

        /*
         * BBD Store köprüsü (K-16).
         *
         * 300/saat: BBD'nin sipariş hacmi mutfağınkinden küçük ve tek
         * kaynaktan geliyor. Sınır, hatalı bir döngünün mutfağın
         * yazıcısını kâğıt bitene kadar çalıştırmasını engelliyor —
         * imzalı bir uçta asıl risk saldırı değil, karşı taraftaki bir
         * hata.
         *
         * Sınır IP başına: BBD tek sunucudan geliyor ve ayrı bir kimlik
         * anahtarı yok (kimliği imza taşıyor, istek gövdesi değil).
         */
        RateLimiter::for('bld-partner', static fn(Request $request): Limit => Limit::perHour(300)
            ->by($request->ip() ?? 'bilinmeyen'));

        /*
         * Fişteki imzalı bağlantılar (K-20).
         *
         * SINIR SİPARİŞ BAŞINA, IP BAŞINA DEĞİL. Takip ucunu çağıran taraf
         * müşterinin telefonu değil, **Next.js sunucusu**: bütün müşteriler
         * tek çıkış IP'sini paylaşıyor ve IP başına bir sınır, yoğun saatte
         * takip sayfasını herkese birden kapatırdı.
         *
         * Sipariş başına sınır, imzayı ele geçiren birinin tek bir siparişi
         * dövmesini de sınırlar ve komşu siparişleri etkilemez.
         *
         * Takipte 30/dk: sayfa 5 saniyede bir yokluyor (12/dk), aynı
         * siparişi iki cihazdan açan müşteriye ve yenilemelere yer kalıyor.
         */
        RateLimiter::for('bld-track', static fn(Request $request): Limit => Limit::perMinute(30)
            ->by('track:'.(string) $request->route('order')));

        /*
         * Teslim onayı 10/dk: kurye sayfayı açıp bir düğmeye basıyor, o
         * kadar. Dar tutmak, imzayı deneme yanılma ile bulma girişimini
         * (128 bitte zaten ulaşılamaz) ölçülebilir olmaktan da çıkarıyor.
         */
        RateLimiter::for('bld-teslimat', static fn(Request $request): Limit => Limit::perMinute(10)
            ->by('teslimat:'.(string) $request->route('order')));
    }

    /**
     * Rotalar iki ayrı yığına kaydedilir.
     *
     * `routes/api.php` → `api` yığını. TastyIgniter'ın web/admin
     * middleware'i (oturum, CSRF, tema) bilinçli olarak uygulanmaz: API
     * durumsuzdur ve token ile kimliklenir.
     *
     * `routes/web.php` → `web` yığını. K-20 ile geldi ve yukarıdaki kuralın
     * istisnası DEĞİL, kapsamı dışında: oradaki tek sayfa kuryenin telefonda
     * açtığı gerçek bir HTML formu ve **CSRF koruması gerekiyor**. Emsali
     * `Veykemtu\Payment\Extension::registerSimulationRoutes()`.
     */
    private function registerRoutes(): void
    {
        Route::middleware('api')
            ->group(__DIR__.'/../routes/api.php');

        Route::middleware('web')
            ->group(__DIR__.'/../routes/web.php');
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
