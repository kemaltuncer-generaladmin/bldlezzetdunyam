<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi;

use Igniter\Admin\Classes\AdminController;
use Igniter\Admin\Classes\Navigation;
use Igniter\Admin\Facades\Template;
use Igniter\Flame\Support\Facades\Igniter;
use Igniter\System\Classes\BaseExtension;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Cache\RateLimiting\Unlimited;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Contracts\View\View;
use Illuminate\Database\Eloquent\Relations\Relation;
use Illuminate\Http\Request;
use Illuminate\Routing\Router;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Route;
use Override;
use Throwable;
use Veykemtu\BridgeApi\Admin\AdminRegistrar;
use Veykemtu\BridgeApi\Admin\NavigationTrimmer;
use Veykemtu\BridgeApi\Console\AccountArchiveCommand;
use Veykemtu\BridgeApi\Console\AdminUserCommand;
use Veykemtu\BridgeApi\Console\AppReleaseCommand;
use Veykemtu\BridgeApi\Console\DemoMenuCommand;
use Veykemtu\BridgeApi\Console\KitchenDeviceCommand;
use Veykemtu\BridgeApi\Console\MenuImageCommand;
use Veykemtu\BridgeApi\Console\PurgeOrdersCommand;
use Veykemtu\BridgeApi\Console\SetupCommand;
use Veykemtu\BridgeApi\Console\SiteContentImportCommand;
use Veykemtu\BridgeApi\Console\SubscriptionGenerateCommand;
use Veykemtu\BridgeApi\Console\SubscriptionRenewCommand;
use Veykemtu\BridgeApi\Console\TranslationAuditCommand;
use Veykemtu\BridgeApi\Exceptions\ApiExceptionRenderer;
use Veykemtu\BridgeApi\Http\Middleware\AuthenticateToken;
use Veykemtu\BridgeApi\Http\Middleware\RequireAdminPanel;
use Veykemtu\BridgeApi\Http\Middleware\RequireAppHeaders;
use Veykemtu\BridgeApi\Http\Middleware\RequireScope;
use Veykemtu\BridgeApi\Http\Controllers\Admin\DailyMenus;
use Veykemtu\BridgeApi\Http\Middleware\VerifyBbdSignature;
use Veykemtu\BridgeApi\Http\Middleware\VerifyControlSignature;
use Veykemtu\BridgeApi\Models\SiteContent;
use Veykemtu\BridgeApi\Models\SitePost;
use Veykemtu\BridgeApi\Models\SiteService;
use Veykemtu\BridgeApi\Observers\SiteContentObserver;
use Veykemtu\BridgeApi\Services\Geocoding\FakeGeocoder;
use Veykemtu\BridgeApi\Services\Geocoding\Geocoder;
use Veykemtu\BridgeApi\Services\Geocoding\NominatimGeocoder;
use Veykemtu\BridgeApi\Services\Sms\LogSmsSender;
use Veykemtu\BridgeApi\Services\Sms\NetgsmSettings;
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
        $this->closeAdminPanel();
        $this->registerSmsSender();
        $this->registerGeocoder();

        $this->registerConsoleCommand('veykemtu.setup', SetupCommand::class);
        $this->registerConsoleCommand('veykemtu.admin', AdminUserCommand::class);
        $this->registerConsoleCommand('veykemtu.kds', KitchenDeviceCommand::class);
        $this->registerConsoleCommand('veykemtu.demoMenu', DemoMenuCommand::class);
        $this->registerConsoleCommand('veykemtu.menuGorselleri', MenuImageCommand::class);
        $this->registerConsoleCommand('veykemtu.siparisTemizle', PurgeOrdersCommand::class);
        $this->registerConsoleCommand('veykemtu.ceviriDenetle', TranslationAuditCommand::class);
        $this->registerConsoleCommand('veykemtu.siteIceriginiAktar', SiteContentImportCommand::class);
        // Cari hesap kaldırıldı; komut yalnızca ARŞİV içindir ve kaldırma
        // göçünden önce elle koşulur (`docs/RUNBOOK.md` §9). Kayıtlı
        // kalıyor ki arşiv, göçten bağımsız olarak tekrar alınabilsin.
        $this->registerConsoleCommand('veykemtu.cariArsivle', AccountArchiveCommand::class);
        $this->registerConsoleCommand('veykemtu.abonelikUret', SubscriptionGenerateCommand::class);
        $this->registerConsoleCommand('veykemtu.abonelikYenile', SubscriptionRenewCommand::class);
        $this->registerConsoleCommand('veykemtu.surum', AppReleaseCommand::class);

        $this->registerPendingConsoleCommands();
    }

    /**
     * Sınıfları paralel yazılan konsol komutları.
     *
     * SINIF YOKSA KAYIT HİÇ YAPILMAZ ve bu, rota dosyasındaki
     * `class_exists()` denetiminin konsol karşılığıdır — ama sebebi DAHA
     * SERT: `registerConsoleCommand()` bağlamayı `$this->commands()` ile
     * Artisan'a veriyor ve Artisan açılırken her komutu KONTEYNERDEN
     * ÇÖZÜYOR. Var olmayan bir sınıf orada `BindingResolutionException`
     * ile patlar; yani tek bir eksik dosya `php artisan`'ın tamamını —
     * `migrate` dahil — kullanılamaz hâle getirirdi.
     *
     * ZAMANLAMA BUNA BAKMAZ (`registerSchedule()`): orada yalnız bir dize
     * duruyor ve gerekçesi o metodun yorumunda.
     *
     * Anahtarlar `veykemtu.<deveKasası>` kalıbını, komut adları
     * `veykemtu:<türkçe-tire>` kalıbını izliyor — ikisi de yukarıdaki
     * listeden geliyor.
     */
    private function registerPendingConsoleCommands(): void
    {
        /** @var array<string, class-string> $commands */
        $commands = [
            // Yarının stok tablosunu hazırlar; 21:30'da koşar.
            'veykemtu.stokTazele' => Console\StockReconcileCommand::class,
            // Eskimiş/çözülmüş hata olaylarını kapatır; 03:30'da koşar.
            'veykemtu.hataTemizle' => Console\MonitorPurgeCommand::class,
            // Günün menüsünü SMS ile duyurur; ayarlanabilir saatte koşar.
            'veykemtu.menuDuyur' => Console\MenuAnnounceCommand::class,
        ];

        foreach ($commands as $key => $class) {
            if (class_exists($class)) {
                $this->registerConsoleCommand($key, $class);
            }
        }
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
     * TastyIgniter admin panelini kapatır — varsayılan KAPALI (F4).
     *
     * Sahip Kontrol Merkezi'ni tek yönetim yüzeyi yaptı. Panel artık ne
     * kullanılıyor ne bakımı yapılıyor; ayakta durduğu sürece iki şey
     * getiriyor: parola denemesine açık bir giriş formu ve KM ile
     * çelişebilecek ikinci bir yazma yolu (aynı ayarı iki yerden
     * değiştirmek, hangisinin doğru olduğunu kimsenin bilmediği bir
     * durum üretir).
     *
     * ── KOD SİLİNMEDİ, YOL KAPATILDI ────────────────────────────────────
     *
     * Üç sebep:
     *
     *   1. **Geri alınabilirlik.** KM çöktüğünde ya da imza anahtarı
     *      kaybolduğunda yönetim yüzeyi tek bir ortam değişkeniyle geri
     *      gelmeli. Silinmiş bir panel için tek yol yeni bir sürüm
     *      yayınlamaktır ve o an, tam da yayın yapılamayan andır.
     *   2. **Ölçülemeyen cerrahi.** 13 admin denetleyicisini silmek
     *      `AdminRegistrar`, izinler, blade'ler ve dil dosyalarında geniş
     *      bir kazımaya dönüşür; bu turda sonucu ölçülemez.
     *   3. **Çekirdeğe bağlılık.** Admin sınıfları TastyIgniter'ın kayıt
     *      akışına (`Igniter::loadControllersFrom`, izin sağlayıcısı,
     *      gösterge paneli parçacıkları) bağlı; yarısını silmek açılışı
     *      kırabilir.
     *
     * ── NEDEN İKİ LİSTE ─────────────────────────────────────────────────
     *
     * Panel tek bir rota kümesi değil. `adminMiddleware` yalnızca admin
     * DENETLEYİCİLERİNİ taşıyor; **giriş, çıkış ve parola sıfırlama**
     * (`Igniter\User\Classes\RouteRegistrar`) ile varlık birleştiricisi
     * (`Admin\Classes\RouteRegistrar::forAssets`) genel `middleware`
     * listesini kullanıyor. Yalnız birincisi kapatılsaydı bütün ekranlar
     * `404` döner ama `/admin/login` açık kalırdı — yani kapattığımızı
     * sandığımız hâlde asıl saldırı yüzeyi ayakta kalırdı.
     *
     * Genel liste storefront tarafında da kullanılıyor; ara katman bu
     * yüzden isteğin YOLUNA bakıyor ve yalnız yönetim önekinin altını
     * kapatıyor (gerekçe `RequireAdminPanel` sınıf yorumunda).
     *
     * ── NEDEN `register()`, `boot()` DEĞİL ──────────────────────────────
     *
     * `disableStorefrontTheme()` ile aynı gerekçe, aynı zamanlama: iki
     * liste de rotalar kurulurken okunuyor
     * (`Igniter\Admin\ServiceProvider::boot()`), eklentiler ise çekirdeğin
     * `boot()`'undan ÖNCE `register()` ediliyor
     * (`Igniter\System\ServiceProvider::register()` sırası: eklentiler,
     * sonra `Igniter\Admin\ServiceProvider`). `boot()`'a yazsaydık ara
     * katmanı rotalar kurulduktan sonra eklemiş olurduk ve hiçbir etkisi
     * olmazdı.
     *
     * ── NEDEN LİSTENİN BAŞINA ───────────────────────────────────────────
     *
     * `array_unshift`, yani `web` grubundan da önce. Sonuna eklenseydi
     * oturum ve CSRF ara katmanları önce koşardı ve token'sız bir
     * `POST /admin/login` `404` yerine `419` alırdı — panelin varlığını
     * yanıt kodundan ele veren tam olarak budur.
     */
    private function closeAdminPanel(): void
    {
        config()->set(
            RequireAdminPanel::CONFIG_KEY,
            RequireAdminPanel::enabledByEnvironment(),
        );

        foreach (['igniter-routes.middleware', 'igniter-routes.adminMiddleware'] as $key) {
            /** @var list<string> $stack */
            $stack = (array) config($key, []);

            if (!in_array(RequireAdminPanel::class, $stack, strict: true)) {
                array_unshift($stack, RequireAdminPanel::class);
                config()->set($key, $stack);
            }
        }
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
     * SIRA ANLAMLIDIR, saatler rastgele seçilmedi:
     *
     *   21:30  `veykemtu:stok-tazele`   yarının stok tablosunu hazırlar
     *   22:00  `veykemtu:abonelik-uret` abonelik siparişlerini üretir
     *   03:30  `veykemtu:hata-temizle`  eskimiş hata olaylarını kapatır
     *   09:00  `veykemtu:menu-duyur`    YARININ menüsünü SMS ile duyurur
     *
     * STOK TAZELEME ÜRETİMDEN ÖNCE OLMAK ZORUNDA. Abonelikler stoku ÖNCE
     * REZERVE EDİYOR (iş kuralı); rezervasyonun yazılacağı gün satırı
     * üretim koştuğunda hazır değilse abonelik siparişleri stoksuz bir güne
     * düşer ve o günün serbest satış kapasitesi olduğundan büyük görünür.
     * Yarım saatlik ara, uzun süren bir tazelemenin üretimin başlangıcına
     * taşmasına pay bırakıyor.
     *
     * HATA TEMİZLİĞİ 03:30'DA: gecenin iki iş yükünden de sonra, sabah
     * duyurusundan da önce. Panelde "bir şey çalışmıyor" diye bakılan ekran
     * (`docs/control/monitor.md`) mesai başlarken temizlenmiş olmalı.
     *
     * `withoutOverlapping` — uzun süren bir koşum bir sonrakiyle üst üste
     * binmez. Saat dilimi `BusinessTime::ZONE` (Istanbul); sunucu UTC olsa
     * da iş yerel saatle.
     *
     * KOMUT SINIFLARI BAŞKA AJANLARIN KULVARINDA. Zamanlama, sınıf var
     * olmasa bile kaydedilir ve bu bilinçli: `$schedule->command()` yalnız
     * bir dize taşıyor, çözümlemeyi `schedule:run` yapıyor. Eksik bir komut
     * o dakikada bir hata satırı yazar; koşullu kayıt ise komut eklendiği
     * gün zamanlamanın sessizce yokluğu demek olurdu — çok daha sinsi bir
     * arıza.
     *
     * Ay-sonu cari özeti işi kaldırıldı: cari hesap iş modelinden çıktı.
     */
    #[Override]
    public function registerSchedule(Schedule $schedule): void
    {
        $schedule->command('veykemtu:stok-tazele')
            ->name('BLD stok tazeleme')
            ->dailyAt('21:30')
            ->timezone(BusinessTime::ZONE)
            ->withoutOverlapping()
            ->runInBackground();

        $schedule->command('veykemtu:abonelik-uret')
            ->name('BLD abonelik üretim')
            ->dailyAt('22:00')
            ->timezone(BusinessTime::ZONE)
            ->withoutOverlapping()
            ->runInBackground();

        /*
         * ABONELİK DÖNEM YENİLEME — I4.
         *
         * ÜRETİMDEN ÖNCE (21:45) KOŞUYOR VE BU BİLİNÇLİ. Üretim işi
         * (`22:00`) ödenmiş dönemi bitmiş aboneliği duraklatıyor; yenileme
         * ondan SONRA koşsaydı, borç açılmadan önce abonelik çoktan
         * durdurulmuş ve o günün yemeği düşmüş olurdu. Yenileme dönem
         * bitmeden N gün önce borcu açtığı için pratikte ikisi aynı gecede
         * karşılaşmaz — ama sıralamayı şansa bırakmak, sadece bir kez
         * gerçekleşmesi yeten bir arıza demekti.
         *
         * Stok tazeleme (21:30) ile arasında 15 dakika var: ikisi de
         * `withoutOverlapping` ve ayrı komutlar, çakışmaları beklenmiyor.
         */
        $schedule->command('veykemtu:abonelik-yenile')
            ->name('BLD abonelik dönem yenileme')
            ->dailyAt('21:45')
            ->timezone(BusinessTime::ZONE)
            ->withoutOverlapping()
            ->runInBackground();

        $schedule->command('veykemtu:hata-temizle')
            ->name('BLD hata temizliği')
            ->dailyAt('03:30')
            ->timezone(BusinessTime::ZONE)
            ->withoutOverlapping()
            ->runInBackground();

        /*
         * GÜNÜN MENÜSÜ DUYURUSU — saati panelden ayarlanabilir.
         *
         * Sabit bir saat yeterli değildi: duyuru SMS'i müşterinin sipariş
         * verebileceği saatten önce gitmeli ve kesim saati
         * (`bld_order_cutoff`) panelden değiştirilebiliyor. İkisi elle
         * eşitlenseydi kesim öne alındığı gün duyuru kapanmış bir gün için
         * gitmeye devam ederdi.
         *
         * ŞABLON VARSAYILAN KAPALI DOĞUYOR (iş kuralı): iş her gün koşar
         * ama duyuru şablonu kapalıyken komut hiçbir şey göndermez. Kapalı
         * bir şablonu zamanlamanın da kapalı olmasıyla ifade etseydik,
         * şablonu açan yönetici ertesi gün hiçbir şey gelmediğini görür ve
         * sebebini başka yerde arardı.
         */
        /*
         * DUYURU BİR GÜN ÖNCEDEN. Pazartesi koşan iş SALI'nın menüsünü
         * duyurur (18.08.2026 kullanıcı kararı) — müşterinin kesim saatinden
         * önce sipariş verecek vakti olsun diye. Saat yine ayardan gelir;
         * değişen "hangi gün" sorusunun cevabı, "saat kaçta" değil.
         */
        $schedule->command('veykemtu:menu-duyur')
            ->name('BLD yarının menüsü duyurusu')
            ->dailyAt(self::menuAnnounceTime())
            ->timezone(BusinessTime::ZONE)
            ->withoutOverlapping()
            ->runInBackground();
    }

    /**
     * Menü duyurusunun `HH:mm` saati — `location_options`'tan.
     *
     * VARSAYIM: anahtar `bld_menu_announce_time`, biçim `HH:mm`, varsayılan
     * `09:00`. `docs/control/sms.md` duyuru taslağının üç anahtarını
     * donduruyor ama zamanlama saatini adlandırmıyor; ad `bld_*` kalıbını
     * ve komşu anahtarların (`bld_order_cutoff`,
     * `bld_subscription_release_time`) biçimini izliyor.
     *
     * VİTRİN AYRIMI YOK: `Schedule` tek bir saat kabul ediyor ve sistemde
     * bugün tek vitrin var. Birden çok vitrin gelirse doğru çözüm burada
     * dallanmak değil, komutun kendi içinde vitrin vitrin dolaşmasıdır.
     *
     * OKUMA HER TÜRLÜ HATAYI YUTAR ve varsayılana düşer. Bu metot konsol
     * açılışında koşuyor; kurulmamış bir veritabanında (`migrate` öncesi,
     * ilk `composer install` sonrası) bir istisna `php artisan`'ın TAMAMINI
     * kullanılamaz hâle getirirdi — göç koşturmak dahil.
     */
    private static function menuAnnounceTime(): string
    {
        $default = '09:00';

        try {
            $raw = DB::table('location_options')
                ->where('item', 'bld_menu_announce_time')
                ->value('value');
        } catch (Throwable) {
            return $default;
        }

        $value = $raw !== null ? json_decode((string) $raw, true) : null;

        return is_string($value) && preg_match('/^([01]\d|2[0-3]):[0-5]\d$/', $value) === 1
            ? $value
            : $default;
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
     * SMS göndericisini seçer — B-18, F ile gözden geçirildi.
     *
     * SAĞLAYICI SIRLARI ORTAM DEĞİŞKENİNDE, VERİTABANINDA DEĞİL. Panelden
     * girilebilir bir ayar olsaydı sır her veritabanı yedeğine girerdi;
     * yedekler ise sırlardan çok daha kolay dolaşıyor.
     *
     * ─────────────────────────────────────────────────────────────────────
     * BAŞLIK BU KURALIN DIŞINDADIR VE AYARDAN DA OKUNUR (`NetgsmSettings`).
     *
     * Gönderici adı (`BLEZZETDNYM`) bir sır değil; müşterinin telefonunda
     * görünen, Netgsm panelinde onaylı bir addır. Yalnız ortam değişkeninde
     * durduğu sürece yönetici onu göremiyor, düzeltemiyor ve yanlış
     * olduğunda tek belirti "SMS gitmiyor" oluyordu — üstelik düzeltmek
     * Coolify'a girip konteyneri yeniden başlatmayı gerektiriyordu.
     * Öncelik bbdkantin'inkiyle aynı: AYAR ÖNCE, ORTAM SONRA.
     * ─────────────────────────────────────────────────────────────────────
     *
     * ÜÇÜ BİRDEN TANIMLI DEĞİLSE GÜNLÜĞE DÜŞER, PATLAMAZ. Yarım
     * yapılandırmayla ayağa kalkmayı reddetmek, tek bir eksik değişken
     * yüzünden bütün siteyi indirmek olurdu — oysa SMS yalnızca ikinci bir
     * giriş yolu; e-posta + şifre çalışmaya devam ediyor.
     *
     * UYARI ARTIK HANGİ ALANIN EKSİK OLDUĞUNU SÖYLÜYOR. Eski hâlde tek iz
     * `LogSmsSender`'ın gönderim ANINDA yazdığı satırdı; yani yapılandırma
     * eksikliği ancak biri SMS beklerken fark ediliyordu ve o satır da
     * hangi alanın boş olduğunu yazmıyordu. Kontrol Merkezi aynı bilgiyi
     * `GET /control/sms/netgsm` ile ekranda gösteriyor (`missing`).
     */
    private function registerSmsSender(): void
    {
        $this->app->singleton(SmsSender::class, static function (): SmsSender {
            $missing = NetgsmSettings::missing();

            if ($missing !== []) {
                Log::warning(
                    'Netgsm yapılandırması eksik — SMS GÖNDERİLMEYECEK, mesajlar yalnız günlüğe yazılacak.',
                    [
                        'missing' => $missing,
                        // Parola ASLA günlüğe girmez; başlık bir sır değil ve
                        // "hangi başlıkla gidiyor" sorusu tam da burada
                        // sorulacak soru.
                        'header' => NetgsmSettings::header(),
                        'header_source' => NetgsmSettings::source(),
                    ],
                );

                return new LogSmsSender;
            }

            return new NetgsmSmsSender(
                NetgsmSettings::username(),
                NetgsmSettings::password(),
                NetgsmSettings::header(),
            );
        });
    }

    /**
     * Adres önerisi sürücüsünü seçer — B-21.
     *
     * TEK SATIRLIK GEÇİŞ NOKTASI. `docs/11-yol-haritasi.md` §F2-01 Google
     * Places'e geçmeyi planlıyor; o gün değişecek yer burasıdır. Önbellek,
     * hizmet alanı elemesi, oran sınırı ve denetleyici sürücüyü tanımıyor
     * (`Services\Geocoding\Geocoder` arayüzü).
     *
     * `GEOCODER_USER_AGENT` BOŞSA UYGULAMA AYAĞA KALKMAYA DEVAM EDER ve site
     * adresinden bir başlık türetilir. OSM kullanım şartı "uygulamayı
     * tanıtan, iletişim bilgisi taşıyan bir User-Agent" istiyor; site adresi
     * bunu karşılıyor. Eksik bir değişken yüzünden bütün API'yi indirmek,
     * öneri gibi bir kolaylık için ödenecek en pahalı bedel olurdu — SMS'te
     * verilen kararın aynısı.
     *
     * `GEOCODER_BASE_URL` neden var: `nominatim.openstreetmap.org` saniyede
     * 1 istek şart koşuyor. Trafik büyüdüğünde doğru hamle oran sınırını
     * yükseltmek değil, kendi Nominatim örneğimizi göstermek.
     *
     * `fake` sürücüsü ağa çıkmaz ve sabit bir liste döndürür — ağsız bir
     * makinede formu ve akışı çalıştırmak için. Testler sürücüyü konteynere
     * doğrudan bağlıyor, bu değere bakmıyor.
     */
    private function registerGeocoder(): void
    {
        $this->app->singleton(Geocoder::class, static function (): Geocoder {
            if (trim((string) env('GEOCODER_DRIVER', '')) === FakeGeocoder::SOURCE) {
                return new FakeGeocoder;
            }

            $url = trim((string) env('GEOCODER_BASE_URL', ''));
            $agent = trim((string) env('GEOCODER_USER_AGENT', ''));

            return new NominatimGeocoder(
                baseUrl: $url !== '' ? $url : 'https://nominatim.openstreetmap.org',
                userAgent: $agent !== ''
                    ? $agent
                    : 'BLD-Siparis/1.0 (+'.config('app.url').')',
            );
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
                // Belirteçler ÖNCE: `admin.css` yalnızca `--bld-*` değişkenlerini
                // Bootstrap'in `--bs-*` değişkenlerine çeviriyor, paleti kendisi
                // taşımıyor. `tokens.css` üretilen bir dosyadır — kaynağı
                // `packages/design_system/tokens/bld.tokens.json`.
                $controller->addCss('veykemtu.bridgeapi::/css/tokens.css', 'bld-tokens-css');
                $controller->addCss('veykemtu.bridgeapi::/css/admin.css', 'bld-admin-css');

                /*
                 * TAKVIM CSS'İ YALNIZ KENDİ EKRANINDA — B-19.
                 *
                 * `admin.css` panelin tamamına giydirilen marka katmanı ve
                 * her sayfada yükleniyor. Ay ızgarası ise tek bir ekranın
                 * düzeni: yedi sütunlu grid, gün kutusu, gün düzenleyici
                 * diyaloğu. Oraya yazılsaydı hem `admin.css` bir ekranın
                 * düzenini taşımaya başlardı hem de her sayfa bu kuralları
                 * boşuna indirirdi.
                 *
                 * Denetleyicinin kendi `__construct`'ında da eklenebilirdi;
                 * burada duruyor ki eklentinin YÜKLEDİĞİ BÜTÜN CSS TEK
                 * YERDE görünsün — hangi sayfanın hangi dosyayı çektiği
                 * sorusunun cevabı bir dosyaya bakmakla verilebilsin.
                 */
                if ($controller instanceof DailyMenus) {
                    $controller->addCss('veykemtu.bridgeapi::/css/dailymenu.css', 'bld-dailymenu-css');
                }
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
        // Kontrol Merkezi (K-21) — imza + zaman penceresi + nonce.
        // `bbd.signature` YENİDEN KULLANILMADI: o şema yalnız gövdeyi
        // imzalıyor, yani tekrar (replay) saldırısına açık. "Cihazı iptal
        // et" isteğini tekrar oynatmak mutfağı sipariş göremez hâle
        // getirirdi. Gerekçenin tamamı `VerifyControlSignature` içinde.
        $router->aliasMiddleware('control.signature', VerifyControlSignature::class);
    }

    /**
     * Kendi kovasını ilan etmiş rotalarda STOK `api` KOVASINI ÇEKER.
     *
     * SORUN: `registerRoutes()` bütün API'yi Laravel'in hazır `api` ara
     * katman kümesine sarıyor ve o kümenin ilk üyesi `throttle:api`, yani
     * **60/dakika/IP**. Aşağıdaki bütçelerin hepsi onun İÇİNDE kalıyordu;
     * gerçek tavan her zaman `min(60/dk, kendi kovası)` idi. Yani:
     *
     *   - `bld-kitchen` 2000/saat diye hesaplandı — kasa saniyede bir
     *     yokluyor, tam 60/dk; tek bir fazladan istek `429` demek ve
     *     mutfak sipariş göremiyor.
     *   - `bld-control` 1200/saat ve `bld-control-panel` 3000/saat
     *     (`docs/control/00-genel.md` §2) kâğıt üstünde ayrı iki kovaydı;
     *     uygulamada ikisi de aynı 60/dk kovasında buluşuyordu, yani
     *     ayrılığın koruduğu şey — paneldeki patlamanın mutfağı
     *     kilitlememesi — hiç sağlanmıyordu.
     *
     * İKİNCİ BELİRTİ, HATAYI GÖRÜNÜR KILAN: `X-RateLimit-*` başlıklarını
     * EN DIŞTAKİ `throttle` yazar (her katman dönüşte kendi başlığını
     * üstüne basar). Dışarıdan bakan herkes — panel, KDS, testler —
     * bütçesini `60` görüyordu.
     *
     * ÇÖZÜM KOVAYI KALDIRMAK DEĞİL, GERİ ÇEKMEK: `throttle:api`'yi rota
     * kümesinden atsaydık `health`, `locations`, `site-content`, adres ve
     * sipariş listesi gibi KENDİ KOVASI OLMAYAN uçlar tamamen sınırsız
     * kalırdı. Bu yüzden stok kova yalnızca rota kendi adlandırılmış
     * kovasını ilan etmişse `Unlimited` döner; ilan etmemiş her uç 60/dk
     * korumasını aynen sürdürür. `Unlimited` durumunda Laravel sayaç da
     * tutmaz, başlık da yazmaz — içteki kovanın başlıkları sağ kalır.
     *
     * TANIM BURADA EZİLİYOR, `RouteServiceProvider`'da DEĞİL: `app/`
     * TastyIgniter'ın kendi iskeleti; kuralı uçların yaşadığı yere yazmak
     * doğru yer.
     *
     * `booted()` KUYRUĞUNA ALINIYOR, DOĞRUDAN ÇAĞRILMIYOR: eklentiler
     * TastyIgniter'ın paket sağlayıcısıyla, yani UYGULAMA sağlayıcılarından
     * ÖNCE açılıyor. Doğrudan çağırsaydık `App\Providers\RouteServiceProvider`
     * ve `ti-ext-api` kendi `boot()`'larında `for('api')`'yi ARDIMIZDAN
     * yeniden tanımlar ve 60/dk geri gelirdi — nitekim geldi, tanım
     * sessizce üzerine yazıldı. `booted` geri çağrıları bütün sağlayıcılar
     * açıldıktan sonra koşar, yani son söz bizde.
     */
    private function yieldStockApiLimiter(): void
    {
        $this->app->booted(static function (): void {
            RateLimiter::for('api', static function (Request $request): Limit|Unlimited {
                foreach ($request->route()?->gatherMiddleware() ?? [] as $middleware) {
                    // Küme adı (`api`) çözülmemiş hâlde durur; `throttle:`
                    // ile başlayan her giriş rotanın KENDİ ilan ettiği kova.
                    if (is_string($middleware) && str_starts_with($middleware, 'throttle:')) {
                        return Limit::none();
                    }
                }

                return Limit::perMinute(60)
                    ->by((string) ($request->user()?->getKey() ?? $request->ip() ?? 'bilinmeyen'));
            });
        });
    }

    /**
     * Oran sınırları — `docs/03-api-sozlesmesi.md` §10.
     *
     * Mutfak sınırı cihaz başınadır, IP başına değil: kasa ve yönetici
     * çoğu zaman aynı ağdan çıkar ve IP sınırı ikisini birbirine kırdırırdı.
     */
    private function registerRateLimiters(): void
    {
        $this->yieldStockApiLimiter();

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
         * ADRES ÖNERİSİ (B-21) — 30/dakika, HESAP BAŞINA.
         *
         * IP BAŞINA DEĞİL ve sebebi somut: dışarıdaki geocoder'a giden tek
         * yol `/addresses/suggest` ile `/addresses/reverse` ve fatura orada
         * doğuyor. IP başına sayılsaydı tek NAT arkasından çıkan bir ofisin
         * çalışanları birbirini kilitlerdi — kurumsal müşterinin tipik ağı
         * tam olarak budur (`docs/openapi.yaml` §Oran sınırları).
         *
         * 30/dakika neden yeter: istemci 300 ms debounce uyguluyor ve 3
         * karakterin altında hiç çağırmıyor, yani sürekli yazan bir
         * kullanıcı bile dakikada ~20 istek üretiyor. Üstü kalan pay
         * haritadan iğne oynatan ters geocoding çağrıları için.
         *
         * `$request->user()` BURADA HER ZAMAN DOLU: iki uç da müşteri
         * kapsamının içinde. IP'ye düşme yalnızca savunma amaçlı — kimliksiz
         * bir geocoder proxy'si kotamızı yabancılara harcatırdı.
         */
        RateLimiter::for('bld-adres', static fn(Request $request): Limit => Limit::perMinute(30)
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
         * KONTROL MERKEZİ (K-21) — 1200/saat/IP.
         *
         * `bld-partner` (300/saat) YETMEZ ve `bld-kitchen` (2000/saat)
         * FAZLA. BBD tek bir uca sipariş yazıyor; Kontrol Merkezi ise
         * AÇIK DURAN BİR PANEL: cihaz listesi, sipariş listesi ve özet
         * yoklanıyor, üstüne yöneticinin tıkladığı her şey geliyor.
         * Yoklama 10 saniyede bir yapılsa tek başına 360/saat eder ve
         * aynı anda iki yönetici panel açabilir.
         *
         * Mutfak bütçesi kadar cömert olmaması bilinçli: kasa saniyede
         * bir soruyor ve sipariş göremezse mutfak durur. Panel yavaşlarsa
         * kimse aç kalmaz.
         *
         * SINIR IP BAŞINA: Kontrol Merkezi tek sunucudan çıkıyor ve ayrı
         * bir kimlik anahtarı yok — kimliği imza taşıyor, istek gövdesi
         * değil (`bld-partner` ile aynı gerekçe).
         */
        RateLimiter::for('bld-control', static fn(Request $request): Limit => Limit::perHour(1200)
            ->by($request->ip() ?? 'bilinmeyen'));

        /*
         * KONTROL PANELİ — 3000/saat/IP (`docs/control/00-genel.md` §2).
         *
         * AYRI KOVA, ŞİŞİRİLMİŞ `bld-control` DEĞİL. Yukarıdaki 1200'lük
         * bütçe YALNIZ KDS EKRANLARI için akıl yürütülmüştü: tek panel,
         * cihaz + sipariş + özet yoklaması. Kontrol Merkezi'ne on dört
         * yönetim alanı eklendi ve bunların beşi yokluyor; o bütçeyi
         * vardiya ortasında tüketirler.
         *
         * Aynı kovaya koymanın bedeli SOMUT: panel `429` aldığı an mutfak
         * kasası yönetimi de kilitlenir — cihaz iptal edilemez, ayar
         * itilemez, sipariş revize edilemez. Yani paneldeki bir liste
         * patlaması mutfağı vurur. Kovaları ayırmak cömertlik değil,
         * bu bağı koparmak içindir.
         *
         * Sürekli yoklama bütçesi (tek yönetici, panel açık):
         *
         *   dashboard/overview   30 sn → 120
         *   orders listesi       15 sn → 240
         *   monitor/summary      60 sn →  60
         *   menu/calendar       120 sn →  30
         *   notifications rozeti 120 sn →  30
         *                              ────
         *                                480
         *
         * Kalan ~2520 kullanıcı kaynaklı: sayfalama, arama, düzenleme
         * ekranları ve ikinci bir yöneticinin paneli.
         *
         * SINIR YİNE IP BAŞINA — Kontrol Merkezi tek sunucudan çıkıyor ve
         * kimliği imza taşıyor, istek gövdesinde ayrı bir anahtar yok
         * (`bld-control` ile aynı gerekçe).
         */
        RateLimiter::for('bld-control-panel', static fn(Request $request): Limit => Limit::perHour(3000)
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

        /*
         * ABONELİK SÖZLEŞMESİ — 10/dk, SÖZLEŞME BAŞINA (`bld-teslimat` emsali).
         *
         * Aynı kova iki yüzeyi birden koruyor ve sayacı bağladığı kimlik
         * yüzeye göre değişiyor:
         *
         *   - `/sozlesme/{contract}/{expires}/{signature}` (web sayfası) →
         *     `{contract}`, yani kayıt kimliği.
         *   - `/api/contracts/{token}/*` (sözleşme uçları) → `{token}`,
         *     yani imzalı bağlantının kendisi.
         *
         * İKİSİ DE IP BAŞINA DEĞİL, iki ayrı sebeple. Web sayfasında sebep
         * `bld-track` ile aynı: bağlantıyı bir kısaltıcı ya da önizleme
         * getirici açtığında herkes tek IP'den görünür. API tarafında sebep
         * `docs/openapi.yaml` §Oran sınırlarında yazılı: uç kimlik istemez,
         * aynı ofisten bakan iki abone birbirini kilitlemesin ve henüz
         * oturum yokken sayacın bağlanabileceği tek kimlik bağlantıdır.
         *
         * IP'YE DÜŞME YALNIZ SAVUNMA AMAÇLI: yol parçası beklenen kalıba
         * bağlı olduğu için ikisinden biri her zaman dolu. Boş bir sayaç
         * anahtarı bütün trafiği tek kovaya toplar ve sınırı herkesi birden
         * kilitleyen bir şeye çevirirdi.
         */
        RateLimiter::for('bld-sozlesme', static fn(Request $request): Limit => Limit::perMinute(10)
            ->by('sozlesme:'.(string) (
                $request->route('contract')
                ?? $request->route('token')
                ?? $request->ip()
                ?? 'bilinmeyen'
            )));

        /*
         * SÖZLEŞME ONAY KODU — 5/SAAT, BELİRTEÇ BAŞINA.
         *
         * Sözleşmeden birebir gelir (`docs/openapi.yaml` §Oran sınırları) ve
         * `bld-sozlesme`'nin İÇİNDE ikinci bir kapıdır: o kova kaba kuvveti
         * yavaşlatmak için dakikalık, bu kova SMS ısmarlamayı durdurmak için
         * saatlik. Tek kova olsaydı dakikada 10 SMS meşru sayılırdı ve bir
         * sözleşme bağlantısına sınırsız SMS ısmarlanabilmesi DOĞRUDAN PARA
         * KAYBIDIR — gönderilen her mesajın faturası bize çıkıyor.
         *
         * `bld-auth` (60/dk) yeniden kullanılmadı: o sınır IP başına ve
         * parola denemesini yavaşlatmak için ölçüldü; buradaki kaynak para,
         * zaman değil.
         */
        RateLimiter::for('bld-sozlesme-otp', static fn(Request $request): Limit => Limit::perHour(5)
            ->by('sozlesme-otp:'.(string) ($request->route('token') ?? $request->ip() ?? 'bilinmeyen')));

        /*
         * İSTEMCİ HATA BİLDİRİMİ — 60 İSTEK/DAKİKA/IP. KARAR VERİLDİ (F4).
         *
         * ── ÇELİŞKİ KAPANDI ─────────────────────────────────────────────
         *
         * Bir faz notu 60/SAAT diyordu, sözleşme 60/DAKİKA. Tek doğru
         * kaynak `docs/openapi.yaml` §Oran sınırlarıdır (AGENTS.md §2.3:
         * normatif biçim odur) ve bu satır oradan birebir gelir. Değer
         * DEĞİŞTİRİLECEKSE ÖNCE SÖZLEŞME değişir; buradaki sayıyı tek
         * başına oynatmak, iki kaynağı yeniden ayırmak demektir.
         *
         * ── DAKİKALIK KOVA NEDEN SEÇİLDİ ────────────────────────────────
         *
         * Saatlik kova (60/saat = 1/dakika) ölçüldü ve REDDEDİLDİ:
         *
         *   - Uç bir HATA BOŞALTMA YERİ. Değerinin tamamı, bir çökme
         *     dalgasının ilk dakikalarında yazdığı satırlarda. Saatlik bir
         *     kova tam o dakikada kapanır ve elde yalnızca dalganın ilk
         *     kaydı kalır — hangi sürümde, kaç cihazda, hangi ekranda
         *     olduğu sorularının cevabı kaybolur.
         *   - Sınır IP BAŞINA ve ÜÇ YÜZEYDE DE IP PAYLAŞILIYOR: web
         *     raporlarının bir kısmını Next.js SUNUCUSU gönderiyor
         *     (`instrumentation.ts` → `onRequestError`, yani tek çıkış
         *     IP'si), mutfak kasası ile yönetici aynı ağdan çıkıyor,
         *     kurumsal müşteri tek NAT arkasında. Saatlik bir kovada
         *     döngüye giren TEK bir istemci, aynı IP'nin arkasındaki
         *     herkesin raporunu bir saat boyunca susturur.
         *
         * ── ASIL KORUMA SUNUCUDA DEĞİL, İSTEMCİDE ───────────────────────
         *
         * Bu kova bir sel kapağı değil, tavan. Sel istemcide durduruluyor
         * ve dört kemer var (`musteriapp/lib/src/data/crash_reporter.dart`,
         * `website/lib/report-error.ts`): parmak izi tekilleştirme,
         * açılışlar arası 6 saatlik soğuma (KALICI — açılışta çöken bir
         * yapının her yeniden başlayışta yeniden rapor yollamasını bu
         * durduruyor), oturum başına 5 jetonluk kova + en az 10 saniye ara
         * ve örnekleme. Bir istemcinin dakikada üretebileceği rapor
         * gerçekte ~5; 60'a ulaşmak için aynı IP'nin arkasında aynı anda
         * onlarca istemcinin çökmesi gerekir — yani bozuk bir sürüm
         * yayınladığımız an, raporlara en çok ihtiyaç duyduğumuz an.
         *
         * Sunucu kovasının işi bu yüzden "hızı kesmek" değil, İSTEMCİ
         * KEMERLERİ ÇALIŞMAZSA (eski bir sürüm, elle yazılmış bir istemci,
         * kasıtlı gürültü) tabloyu sınırsız büyümekten korumak.
         *
         * BİRİM İSTEK, OLAY DEĞİL: uç toplu gönderim kabul ediyor ve tek
         * istekte en çok 20 olay alıyor (`ClientErrorController::MAX_EVENTS`).
         * Yani gerçek tavan IP başına 1200 olay/dakika. Bu sayı bilinçli
         * olarak yüksek: çevrimdışı kalmış bir istemcinin biriktirdiklerini
         * tek seferde boşaltabilmesi için toplu gönderim var ve onu istek
         * sayısıyla cezalandırmak, toplu göndermenin sebebini ortadan
         * kaldırırdı. Tablonun sınırsız büyümesini oran sınırı değil, gece
         * koşan `veykemtu:hata-temizle` engelliyor.
         *
         * Sınır IP başına: uçta kimlik opsiyonel ve raporların önemli bir
         * kısmı tam da oturum açılamadığı için doğuyor.
         *
         * DİKKAT — sınıra takılan istek İSTEMCİ TARAFINDA SESSİZCE DÜŞMELİ.
         * Uç `429` döndüğünde istemci bunu yeni bir hata sayarsa hata
         * bildirimi kendi kendini besleyen bir döngüye girer.
         */
        RateLimiter::for('bld-hata', static fn(Request $request): Limit => Limit::perMinute(60)
            ->by('hata:'.(string) ($request->ip() ?? 'bilinmeyen')));

        /*
         * ABONELİK ÖDEMESİ DÖNÜŞ SAYFASI — 20/dk, ÖDEME BAŞINA.
         *
         * `bld-teslimat` ve `bld-track` ile aynı aile: imzalı/tahmin
         * edilemez bir adresi olan, oturumsuz bir sayfa. Sınır ödeme
         * kaydına bağlı, IP'ye değil — sağlayıcıdan dönen kullanıcı çoğu
         * zaman operatör NAT'ı arkasından geliyor ve IP başına bir sınır
         * yoğun saatte birbirini tanımayan abonelere sonuç sayfasını
         * kapatırdı.
         *
         * Teslim onayından (10/dk) cömert olmasının sebebi: sonuç sayfası
         * "ödemem geçti mi" diye yenilenen sayfadır ve yenileme burada
         * beklenen davranıştır.
         */
        RateLimiter::for('bld-odeme-donus', static fn(Request $request): Limit => Limit::perMinute(20)
            ->by('odeme-donus:'.(string) ($request->route('hash') ?? $request->ip() ?? 'bilinmeyen')));
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

        $this->registerExceptionReporter();
    }

    /**
     * Sunucu istisnalarını hata monitörüne yazar — `docs/control/monitor.md`.
     *
     * `renderable` KARDEŞİ AMA AYNI ŞEY DEĞİL. O, istemciye DÖNEN gövdeyi
     * biçimlendiriyor ve yalnız bir HTTP isteği varken çalışıyor. Monitörün
     * beslenmesi gereken hatalar ise çoğunlukla oradan geçmiyor: gece
     * koşan abonelik üretimi, stok tazeleme, SMS duyurusu ve kuyruk işleri
     * kimseye yanıt döndürmüyor. `reportable` bunların hepsini görüyor.
     *
     * `source = server` SABİT. Monitör dört kaynağı ayırıyor (kasa, mobil,
     * web, sunucu) ve buradan yazılan her satır tanım gereği sunucunun
     * kendi hatası.
     *
     * ÖZYİNELEME KORUMASI — BU METODUN VAR OLMA SEBEBİ KADAR ÖNEMLİ.
     * Hata satırını yazmak bir VERİTABANI YAZMASIDIR. Veritabanı düştüğünde
     * ilk istisna buraya gelir, yazma denemesi ikinci bir istisna atar, o da
     * buraya gelir — tek bir DB kesintisi sonsuz döngüye ve dolan bir
     * yığına dönerdi. İki katman birden var:
     *
     *   1. `$writing` bayrağı: yazma sırasında doğan istisna geri
     *      girdiğinde hemen çıkılır. Sarmalayıcı `try/catch` tek başına
     *      yetmez — `MonitorRecorder` içindeki bir hata `report()`
     *      üzerinden yeniden buraya girebilir ve `catch` bloğu o iç içe
     *      girişi görmez.
     *   2. Sarmalayıcı `catch (Throwable)`: yazma hatası SESSİZCE YUTULUR.
     *      Yerine bir şey günlüğe düşürmek de aynı riski taşıyor; hata
     *      bildirmenin kendisi hata üretmemeli.
     *
     * `class_exists()` NÖBETÇİSİ KALDIRILDI — bir daha konmayacak.
     * Kanca uzun süre "kayıt sınıfı başka ajanın kulvarında" gerekçesiyle
     * o nöbetçinin arkasında durdu; sınıf depoya hiç girmedi ve metot her
     * açılışta sessizce erken döndü. Sonuç: monitörün dört kaynağından biri
     * — sunucu — hiç yazmadı, ekran çalıştığı için de kimse fark etmedi.
     * Sınıf artık burada; koruma yok ki yeniden kaybolursa açılışta
     * patlasın, sessizce boş bir ekran bırakmasın.
     */
    private function registerExceptionReporter(): void
    {
        $writing = false;

        $this->app->make(\Illuminate\Contracts\Debug\ExceptionHandler::class)
            ->reportable(function (Throwable $e) use (&$writing): void {
                if ($writing) {
                    return;
                }

                $writing = true;

                try {
                    $this->app->make(Services\MonitorRecorder::class)->recordServerException($e);
                } catch (Throwable) {
                    // Bilerek boş — yukarıdaki sınıf yorumuna bakın.
                } finally {
                    $writing = false;
                }
            });
    }
}
