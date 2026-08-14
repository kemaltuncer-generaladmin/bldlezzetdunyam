<?php

declare(strict_types=1);

/**
 * Sözleşme rotaları — `docs/openapi.yaml` (normatif).
 *
 * Buradaki yol, metot ve isimler sözleşmeden birebir gelir. Yeni uç eklemeden
 * önce sözleşme güncellenir; tersi değil (`docs/00-INDEX.md` çelişki kuralı).
 *
 * `igniter.api` eklentisi devre dışıdır (docs/04 §3) — `/api` öneki bizimdir.
 */

use Illuminate\Support\Facades\Route;
use Veykemtu\BridgeApi\Http\Controllers\AccountController;
use Veykemtu\BridgeApi\Http\Controllers\AddressController;
use Veykemtu\BridgeApi\Http\Controllers\AppVersionController;
use Veykemtu\BridgeApi\Http\Controllers\AuthController;
use Veykemtu\BridgeApi\Http\Controllers\BbdController;
use Veykemtu\BridgeApi\Http\Controllers\CatalogController;
use Veykemtu\BridgeApi\Http\Controllers\Control\DeviceController as ControlDeviceController;
use Veykemtu\BridgeApi\Http\Controllers\Control\MenuController as ControlMenuController;
use Veykemtu\BridgeApi\Http\Controllers\Control\OrderController as ControlOrderController;
use Veykemtu\BridgeApi\Http\Controllers\Control\OverviewController as ControlOverviewController;
use Veykemtu\BridgeApi\Http\Controllers\Control\PrintJobController as ControlPrintJobController;
use Veykemtu\BridgeApi\Http\Controllers\HealthController;
use Veykemtu\BridgeApi\Http\Controllers\KitchenController;
use Veykemtu\BridgeApi\Http\Controllers\OrderController;
use Veykemtu\BridgeApi\Http\Controllers\PublicTrackingController;
use Veykemtu\BridgeApi\Http\Controllers\QuoteRequestController;
use Veykemtu\BridgeApi\Http\Controllers\SiteContentController;
use Veykemtu\BridgeApi\Http\Controllers\SubscriptionController;

Route::prefix('api')
    ->middleware(['bld.headers'])
    ->group(function (): void {

        // ── Kimlik gerektirmeyen uçlar ───────────────────────────────────
        Route::get('health', [HealthController::class, 'show']);

        Route::middleware('throttle:bld-auth')->group(function (): void {
            Route::post('auth/register', [AuthController::class, 'register']);
            Route::post('auth/login', [AuthController::class, 'login']);

            /*
             * TELEFONLA GİRİŞ (B-18) — şifre yolunun yanında ikinci bir kapı.
             *
             * Aynı `bld-auth` sınırının içinde: ikisi de kimlik doğrulama
             * denemesi ve aynı bütçeyi paylaşmaları doğru.
             *
             * Asıl koruma bu sınırda DEĞİL — sınır IP başına ve saldırgan IP
             * değiştirebilir. Gerçek kapılar `OtpService` içinde: koda bağlı
             * deneme sayacı, 60 saniyelik yeniden gönderim beklemesi ve
             * kayıtlı olmayan numarada sessiz çıkış.
             */
            Route::post('auth/otp/request', [AuthController::class, 'requestOtp']);
            Route::post('auth/otp/verify', [AuthController::class, 'verifyOtp']);
        });

        Route::get('locations', [CatalogController::class, 'locations']);
        Route::get('locations/{location}/menu', [CatalogController::class, 'menu']);

        /*
         * Günün menüsü ve menü takvimi (B-19). Kimlik gerektirmez:
         * `/menu` ile aynı gerekçe — site bunları SSR sırasında çekiyor ve
         * token istemek statik üretimi zorlaştırıp hiçbir şeyi korumazdı.
         */
        Route::get('locations/{location}/daily-menu', [CatalogController::class, 'dailyMenu']);
        Route::get('locations/{location}/menu-calendar', [CatalogController::class, 'menuCalendar']);
        Route::get('app-version', [AppVersionController::class, 'show']);

        // Kurumsal site içeriği. Kimlik gerektirmez — içerik zaten herkese
        // açık yayınlanıyor; token istemek statik üretimi zorlaştırıp hiçbir
        // şeyi korumazdı.
        Route::get('site-content', [SiteContentController::class, 'show']);

        // Teklif talebi. Kimlik gerektirmez — formu dolduran kişi henüz
        // müşteri değil; hesap açmaya zorlamak formun terk edilme sebebidir.
        // Koruma oran sınırında: `bld-quote`, saatlik pencere.
        Route::post('quote-requests', [QuoteRequestController::class, 'store'])
            ->middleware('throttle:bld-quote');

        // Eşleme kodu tek kullanımlık ve 10 dk ömürlü; kaba kuvvete karşı
        // ayrıca oran sınırı uygulanır.
        Route::post('kitchen/pair', [KitchenController::class, 'pair'])
            ->middleware('throttle:bld-auth');

        // Fişteki takip QR'ı (K-20). Kimlik gerektirmez; yetki URL'deki
        // HMAC imzasında. `/orders/{id}` ile karıştırılmamalı — bu uç
        // siparişin çok daha DAR bir yüzünü döner (adres, ad, telefon ve
        // kalem listesi yok).
        Route::get('public/orders/{order}/tracking', [PublicTrackingController::class, 'show'])
            ->middleware('throttle:bld-track');

        // ── Ortak (BBD Store) ────────────────────────────────────────────
        //
        // Kimlik doğrulaması HMAC İMZASIYLA, token'la değil: BBD ayrı bir
        // sunucudaki ayrı bir proje ve arada paylaşılan tek şey bir sır.
        // Sabit bir token her istekte ağdan geçen ve loglara düşen bir
        // parola olurdu.
        //
        // `bld.headers` UYGULANMAZ: BBD bizim istemcimiz değil, ortak bir
        // sistem; ondan `X-App-Id` beklemek anlamsız olurdu.
        Route::withoutMiddleware(['bld.headers'])->group(function (): void {
            Route::post('partner/bbd/orders', [BbdController::class, 'store'])
                ->middleware(['bbd.signature', 'throttle:bld-partner']);
        });

        // ── Müşteri kapsamı ──────────────────────────────────────────────
        Route::middleware(['bld.auth', 'bld.scope:customer'])->group(function (): void {
            Route::post('auth/logout', [AuthController::class, 'logout']);
            Route::get('auth/me', [AuthController::class, 'me']);
            Route::patch('auth/me', [AuthController::class, 'updateMe']);
            // Parola değişimi kaba kuvvete açık (mevcut parolayı deneme):
            // giriş/kayıtla aynı sıkı sınırı paylaşır.
            Route::post('auth/password', [AuthController::class, 'changePassword'])
                ->middleware('throttle:bld-auth');
            Route::post('me/push-token', [AuthController::class, 'pushToken']);

            // Adres defteri. Sipariş adresi buradan KOPYALANIR, bağlanmaz —
            // gerekçe AddressController sınıf yorumunda.
            Route::get('addresses', [AddressController::class, 'index']);
            Route::post('addresses', [AddressController::class, 'store']);

            /*
             * Adres yardımcıları (B-21) — SABİT PARÇALI YOLLAR `{address}`
             * ÖNÜNDE. Yönlendirici önce eşleşeni alır: `addresses/{address}`
             * üstte kalsaydı `suggest` bir kimlik sanılıp 404 dönerdi.
             * Bugün `{address}` yalnızca PATCH/DELETE ile tanımlı, yani
             * çakışma henüz yok — sıra, ileride bir `GET addresses/{id}`
             * eklendiği gün sessizce kırılmasın diye şimdiden doğru.
             *
             * KİMLİK GEREKİR (müşteri kapsamının içindeler): anonim bir
             * geocoder proxy'si sağlayıcı kotamızı yabancılara harcatır.
             * Sınır da hesap başına — gerekçe `Extension::registerRateLimiters`.
             */
            Route::middleware('throttle:bld-adres')->group(function (): void {
                Route::get('addresses/suggest', [AddressController::class, 'suggest']);
                Route::get('addresses/reverse', [AddressController::class, 'reverse']);
            });

            Route::patch('addresses/{address}', [AddressController::class, 'update']);
            Route::delete('addresses/{address}', [AddressController::class, 'destroy']);

            Route::get('orders', [OrderController::class, 'index']);
            Route::post('orders', [OrderController::class, 'store'])
                ->middleware('throttle:bld-order');
            Route::get('orders/{order}', [OrderController::class, 'show']);
            Route::post('orders/{order}/cancel', [OrderController::class, 'cancel']);

            // Cari hesap (self-servis): güncel bakiye + tarih aralığı ekstresi.
            // Yalnız istek sahibinin verisi döner (controller `$request->user()`).
            Route::get('account/summary', [AccountController::class, 'summary']);
            Route::get('account/statement', [AccountController::class, 'statement']);
            // Cari borç ödemesi başlatır (B-14). `bld-order` sınırı yeniden
            // kullanılıyor: para hareketi başlatan bir uç, katalog okumakla
            // aynı bütçeyi paylaşmamalı.
            Route::post('account/payments', [AccountController::class, 'startPayment'])
                ->middleware('throttle:bld-order');

            // Abonelik (self-servis): müşteri kendi aboneliğini görür, TALEP
            // açar (fiyatı admin belirler), duraklatır/devam/iptal, tek-gün
            // istisna girer. Anlaşmalı fiyat müşteri tarafından set edilmez.
            Route::get('subscriptions', [SubscriptionController::class, 'index']);
            Route::post('subscriptions', [SubscriptionController::class, 'store'])
                ->middleware('throttle:bld-order');
            Route::get('subscriptions/{subscription}', [SubscriptionController::class, 'show']);
            Route::post('subscriptions/{subscription}/pause', [SubscriptionController::class, 'pause']);
            Route::post('subscriptions/{subscription}/resume', [SubscriptionController::class, 'resume']);
            Route::post('subscriptions/{subscription}/cancel', [SubscriptionController::class, 'cancel']);
            Route::post('subscriptions/{subscription}/exceptions', [SubscriptionController::class, 'storeException']);
        });

        // ── Mutfak kapsamı ───────────────────────────────────────────────
        Route::prefix('kitchen')
            ->middleware(['bld.auth', 'bld.scope:kitchen', 'throttle:bld-kitchen'])
            ->group(function (): void {
                Route::get('orders', [KitchenController::class, 'orders']);
                Route::get('subscription-orders', [KitchenController::class, 'subscriptionOrders']);
                // Abonelik üretim planı (K-15): toplamlar, saatler, uyarılar.
                Route::get('subscription-plan', [KitchenController::class, 'subscriptionPlan']);
                Route::post('orders/{order}/status', [KitchenController::class, 'setStatus']);
                Route::get('orders/{order}/receipt', [KitchenController::class, 'receipt']);
                Route::post('print-jobs/{order}/ack', [KitchenController::class, 'ackPrint']);
                Route::get('production-list', [KitchenController::class, 'productionList']);
                Route::get('heartbeat', [KitchenController::class, 'heartbeat']);
                Route::post('busy', [KitchenController::class, 'setBusy']);
                Route::post('health', [KitchenController::class, 'health']);

                // ── Satış kontrolü (K-11) ────────────────────────────
                //
                // `busy` yalnız uyarır; aşağıdakiler satışı gerçekten
                // keser. Kasa tarafında onay + sebep + süre + açılış
                // şifresi isteniyor (`docs/05` §11).
                Route::get('ordering', [KitchenController::class, 'ordering']);
                Route::post('ordering', [KitchenController::class, 'setOrdering']);
                Route::get('menu-availability', [KitchenController::class, 'menuAvailability']);
                Route::post('menu-availability', [KitchenController::class, 'setMenuAvailability']);

                // ── Sipariş düzenleme (K-12) ─────────────────────────
                //
                // Personel müşteriyle TELEFONDA anlaşıp uyguluyor; bu
                // uçlar bir onay akışı değil, bir kayıt akışıdır.
                Route::get('orders/{order}/editable', [KitchenController::class, 'editable']);
                Route::get('orders/{order}/revisions', [KitchenController::class, 'revisions']);
                Route::post('orders/{order}/revisions', [KitchenController::class, 'storeRevision']);
                Route::get('menu', [KitchenController::class, 'menu']);

                // ── BBD Store köprüsü (K-16) ─────────────────────────
                //
                // Basılmayı bekleyen BBD fişleri. Bunlar BLD siparişi
                // DEĞİL; panoya girmez, yalnız ses + kâğıt üretir.
                Route::get('bbd-orders', [KitchenController::class, 'bbdOrders']);
                Route::post('bbd-orders/{receipt}/ack', [KitchenController::class, 'ackBbd']);
            });

        // ── Kontrol Merkezi (K-21) ───────────────────────────────────────
        //
        // Kimlik doğrulaması İMZAYLA, cihaz token'ıyla değil. Kontrol
        // Merkezi kasa gibi eşleşMEZ: eşleşseydi her isteği bir kasanın
        // `last_seen_at`'ini tazeler ve panelde açık duran bir ekran,
        // mutfakta olmayan bir kasayı "çevrimiçi" gösterirdi. Gerekçenin
        // tamamı `Http\Middleware\VerifyControlSignature` sınıf yorumunda.
        //
        // `bld.headers` UYGULANMAZ: Kontrol Merkezi bir müşteri istemcisi
        // değil, yöneten bir sistem; ondan `X-App-Id` beklemek anlamsız
        // olurdu (BBD köprüsüyle aynı gerekçe).
        Route::withoutMiddleware(['bld.headers'])->group(function (): void {
            Route::prefix('control/kds')
                ->middleware(['control.signature', 'throttle:bld-control'])
                ->group(function (): void {
                    // Panel açılışı: tek istekte cihaz, sipariş ve fiş sayıları.
                    Route::get('overview', [ControlOverviewController::class, 'show']);

                    // Cihazlar. Yazma uçlarının hepsi `reason` + `actor`
                    // ister ve `veykemtu_control_audit`'e satır yazar.
                    Route::get('devices', [ControlDeviceController::class, 'index']);
                    Route::post('devices', [ControlDeviceController::class, 'store']);
                    Route::patch('devices/{device}', [ControlDeviceController::class, 'update']);
                    Route::post('devices/{device}/pairing-code', [ControlDeviceController::class, 'pairingCode']);
                    // İPTAL SATIRI SİLMEZ — `KitchenDevice::revoke()`.
                    Route::post('devices/{device}/revoke', [ControlDeviceController::class, 'revoke']);
                    Route::patch('devices/{device}/settings', [ControlDeviceController::class, 'updateSettings']);
                    Route::get('devices/{device}/commands', [ControlDeviceController::class, 'commands']);
                    Route::post('devices/{device}/commands', [ControlDeviceController::class, 'sendCommand']);

                    // Fiş DENETİM kaydı. Kuyruk değil: KDS'in kalıcı
                    // kuyruğu kasanın diskinde ve sunucuda karşılığı yok.
                    Route::get('print-jobs', [ControlPrintJobController::class, 'index']);

                    // Siparişler ve revizyon. İş mantığı `OrderEditor` ve
                    // `OrderStatusTransition`'da; bu uçlar yalnız kabuk.
                    Route::get('orders', [ControlOrderController::class, 'index']);
                    Route::get('orders/{order}', [ControlOrderController::class, 'show']);
                    Route::get('orders/{order}/revisions', [ControlOrderController::class, 'revisions']);
                    Route::post('orders/{order}/revisions', [ControlOrderController::class, 'storeRevision']);
                    Route::post('orders/{order}/status', [ControlOrderController::class, 'setStatus']);

                    // Düzenleme ekranının ürün seçicisi. `menu_id` kimsenin
                    // ezberinde değil; elle yazılan bir kimlik siparişe
                    // başka bir ürün koyar ve bunu mutfak fark eder.
                    Route::get('menu', [ControlMenuController::class, 'index']);
                });
        });
    });
