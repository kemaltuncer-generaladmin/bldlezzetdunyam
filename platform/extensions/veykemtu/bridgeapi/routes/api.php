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
use Veykemtu\BridgeApi\Http\Controllers\AddressController;
use Veykemtu\BridgeApi\Http\Controllers\AnnouncementController;
use Veykemtu\BridgeApi\Http\Controllers\AppVersionController;
use Veykemtu\BridgeApi\Http\Controllers\AuthController;
use Veykemtu\BridgeApi\Http\Controllers\BbdController;
use Veykemtu\BridgeApi\Http\Controllers\CatalogController;
use Veykemtu\BridgeApi\Http\Controllers\ClientErrorController;
use Veykemtu\BridgeApi\Http\Controllers\ContractController;
use Veykemtu\BridgeApi\Http\Controllers\Control\AuditController as ControlAuditController;
use Veykemtu\BridgeApi\Http\Controllers\Control\CmsController as ControlCmsController;
use Veykemtu\BridgeApi\Http\Controllers\Control\CustomerController as ControlCustomerController;
use Veykemtu\BridgeApi\Http\Controllers\Control\DailyMenuController as ControlDailyMenuController;
use Veykemtu\BridgeApi\Http\Controllers\Control\DashboardController as ControlDashboardController;
use Veykemtu\BridgeApi\Http\Controllers\Control\DeviceController as ControlDeviceController;
use Veykemtu\BridgeApi\Http\Controllers\Control\InvoiceController as ControlInvoiceController;
use Veykemtu\BridgeApi\Http\Controllers\Control\MenuController as ControlMenuController;
use Veykemtu\BridgeApi\Http\Controllers\Control\MonitorController as ControlMonitorController;
use Veykemtu\BridgeApi\Http\Controllers\Control\NotificationController as ControlNotificationController;
use Veykemtu\BridgeApi\Http\Controllers\Control\OrderController as ControlOrderController;
use Veykemtu\BridgeApi\Http\Controllers\Control\OverviewController as ControlOverviewController;
use Veykemtu\BridgeApi\Http\Controllers\Control\PrintJobController as ControlPrintJobController;
use Veykemtu\BridgeApi\Http\Controllers\Control\ProductController as ControlProductController;
use Veykemtu\BridgeApi\Http\Controllers\Control\SettingsController as ControlSettingsController;
use Veykemtu\BridgeApi\Http\Controllers\Control\SmsController as ControlSmsController;
use Veykemtu\BridgeApi\Http\Controllers\Control\SubscriptionController as ControlSubscriptionController;
use Veykemtu\BridgeApi\Http\Controllers\HealthController;
use Veykemtu\BridgeApi\Http\Controllers\KitchenController;
use Veykemtu\BridgeApi\Http\Controllers\OrderController;
use Veykemtu\BridgeApi\Http\Controllers\PublicTrackingController;
use Veykemtu\BridgeApi\Http\Controllers\QuoteRequestController;
use Veykemtu\BridgeApi\Http\Controllers\SiteContentController;
use Veykemtu\BridgeApi\Http\Controllers\SubscriptionController;
use Veykemtu\BridgeApi\Http\Controllers\SubscriptionPaymentController;

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

        /*
         * ── Abonelik sözleşmesi (açık) ───────────────────────────────────
         *
         * KİMLİK GEREKTİRMEZ ve bu bilinçli: bağlantı aboneye SMS ile
         * gidiyor, onaylayan kişi çoğu zaman uygulamada oturum açmış kişi
         * değil satın almayı onaylayan yetkilidir. Oturum istemek onayı
         * imkânsız kılardı (`docs/openapi.yaml` → `getContract`).
         *
         * BELİRTEÇ KİMLİK TAŞIMAZ. `{token}` sıralı bir kayıt kimliği
         * değil; kalıp da onu bağlıyor. Sıralı olsaydı bir bağlantıyı
         * eline geçiren komşu numaraları deneyerek başkalarının
         * sözleşmelerini okurdu.
         *
         * İKİ SINIR ÜST ÜSTE:
         *
         *   - `bld-sozlesme` (10/dk/belirteç) üç ucun tamamında. Kaba
         *     kuvvetle kod deneyen birini yavaşlatır.
         *   - `bld-sozlesme-otp` (5/saat/belirteç) YALNIZ SMS ISMARLAYAN
         *     uçta ve sözleşmeden birebir gelir. Bir sözleşme bağlantısına
         *     sınırsız SMS ısmarlanabilmesi doğrudan para kaybıdır.
         *
         * İkisi de BELİRTEÇ başına, IP başına değil: uç kimlik istemez,
         * aynı ofisten bakan iki abone birbirini kilitlememeli ve henüz
         * oturum olmadığı için sayacın bağlanabileceği tek kimlik
         * bağlantının kendisidir.
         */
        if (class_exists(ContractController::class)) {
            Route::middleware('throttle:bld-sozlesme')
                ->where(['token' => '[A-Za-z0-9_-]{20,200}'])
                ->group(function (): void {
                    Route::get('contracts/{token}', [ContractController::class, 'show']);
                    Route::post('contracts/{token}/otp', [ContractController::class, 'requestOtp'])
                        ->middleware('throttle:bld-sozlesme-otp');
                    Route::post('contracts/{token}/approve', [ContractController::class, 'approve']);
                });
        }

        /*
         * İstemci hata bildirimi — `docs/control/monitor.md` havuzunu besler.
         *
         * KİMLİK OPSİYONEL, bu yüzden müşteri kapsamının DIŞINDA: hataların
         * önemli bir kısmı tam da oturum açılamadığı için doğuyor ve orada
         * token istemek en çok ihtiyaç duyulan kaydı kaybettirirdi. Token
         * varsa denetleyici raporu müşteriye bağlar.
         *
         * `bld.headers` UYGULANIR ve şart: raporun hangi uygulamadan
         * geldiğini sunucu `X-App-Id` başlığından türetiyor. Gövdedeki
         * `source` sessizce yok sayılır — web sitesi `mutfakapp` yazan bir
         * rapor üretebilseydi mutfağın güvendiği hata monitörüne sahte KDS
         * alarmı düşerdi.
         */
        if (class_exists(ClientErrorController::class)) {
            Route::post('client-errors', [ClientErrorController::class, 'store'])
                ->middleware('throttle:bld-hata');
        }

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

            // Cari hesap uçları (`account/summary|statement|payments`)
            // KALDIRILDI — cari hesap iş modelinden çıktı. Adresler bilerek
            // yeniden kullanılmıyor: eski bir istemci sürümü çağırdığında
            // 404 alması, başka bir anlama gelen 200 almasından iyidir.

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

            /*
             * ── Abonelik dönem ödemesi ───────────────────────────────
             *
             * AYRI DENETLEYİCİ, `SubscriptionController`'A EKLENMEDİ: o
             * sınıfın `store`'u ABONELİK açıyor, buradaki `store` ÖDEME
             * başlatıyor. Aynı sınıfta iki `store` olamayacağı için
             * ikincisi `storePayment` gibi bir ada kaçardı ve müşteri
             * yüzündeki adlar Kontrol Merkezi'ndekilerle karışırdı
             * (`control/subscriptions` ailesinde `storePayment` BAŞKA bir
             * şey — yönetici tarafında elle ödeme kaydı açar).
             *
             * TUTAR YOLDA DA GÖVDEDE DE YOK: dönem tutarı sunucuda
             * hesaplanır. İstemciden alınsaydı, arada bir gün atlandığında
             * ekrandaki tutar ile gerçek tutar ayrışır ve abone eksik
             * ödeyip "kapattım" sanırdı.
             *
             * `{payment}` YOL PARÇASI ABONELİĞİN ALTINDA: ödeme kimliği tek
             * başına yeterli olsaydı bir abonenin ödeme kimliğini deneyen
             * başka bir abone komşu kaydı okuyabilirdi. Denetleyici yine de
             * ikisinin bağını doğrular — yol yapısı tek savunma değildir.
             */
            if (class_exists(SubscriptionPaymentController::class)) {
                Route::where(['subscription' => '\\d+', 'payment' => '\\d+'])->group(function (): void {
                    Route::middleware('throttle:bld-order')->group(function (): void {
                        Route::post('subscriptions/{subscription}/payments', [SubscriptionPaymentController::class, 'store']);
                        Route::post('subscriptions/{subscription}/payments/{payment}/confirm', [SubscriptionPaymentController::class, 'confirm']);
                    });

                    // OKUMA `bld-order` KOVASINDA DEĞİL: sözleşme istemciye
                    // sonucu YOKLAMASINI söylüyor (2 sn aralık) ve 20/saatlik
                    // yazma bütçesi tek bir ödemenin yoklamasında biterdi.
                    Route::get('subscriptions/{subscription}/payments/{payment}', [SubscriptionPaymentController::class, 'show']);
                });
            }

            /*
             * ── Uygulama-içi duyuru ──────────────────────────────────
             *
             * Push (FCM) YOK; duyuru uygulamanın içinde yaşıyor. Pencere ve
             * kapatma süzgeci SUNUCUDA: üç istemci aynı kuralı üç kez
             * yazmasın ve saati kaymış bir telefon süresi dolmuş duyuruyu
             * göstermeye devam etmesin.
             *
             * `seen` ile `dismiss` AYRI UÇLAR: görülmek duyuruyu listeden
             * düşürmez, kapatmak düşürür. Tek uca indirilseydi ekranda
             * çizilen her duyuru ilk karede kaybolurdu.
             */
            if (class_exists(AnnouncementController::class)) {
                Route::get('announcements', [AnnouncementController::class, 'index']);
                Route::post('announcements/{announcement}/seen', [AnnouncementController::class, 'markSeen'])
                    ->whereNumber('announcement');
                Route::post('announcements/{announcement}/dismiss', [AnnouncementController::class, 'dismiss'])
                    ->whereNumber('announcement');
            }
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

            /*
             * ── Kontrol paneli alanları — `docs/control/` (14 dosya) ──────
             *
             * KDS ailesinin YANINA gelirler, yerine değil: `control/kds/*`
             * yayınlanmış bir yüzeydir ve Kontrol Merkezi'nin `bld_kds`
             * modülü onu kullanıyor.
             *
             * TEK FARK HIZ SINIRI KOVASI: bu alanlar `bld-control-panel`
             * (3000/saat) kullanır, KDS ise `bld-control` (1200/saat).
             * Gerekçesi `Extension::registerRateLimiters()` içindedir ve
             * özeti şudur: paneldeki bir yoklama patlaması mutfağın kasa
             * yönetimini KİLİTLEMEMELİ.
             *
             * SINIF YOKSA GRUP HİÇ KAYDEDİLMEZ. Bu alanların
             * denetleyicileri paralel yazılıyor ve bir kısmı bu dosya
             * yazıldığında henüz yoktu. `class_exists()` denetimi olmadan
             * `route:cache` (ve yol çakışması denetimi) var olmayan bir
             * sınıfa bakıp uygulamayı AÇILIŞTA düşürebilirdi — yani tek bir
             * eksik dosya bütün API'yi indirirdi.
             *
             * Kaydedilmeyen bir alan Laravel'in kendi 404'ünü döner ve bu
             * BİLİNÇLİDİR: `docs/control/00-genel.md` §7 sonundaki ayrım
             * ("uç yayında değil" ≠ "kayıt yok") tam olarak budur. Kontrol
             * Merkezi geçidi o farka bakarak ekranı "yakında" diye
             * gösterebilir; sözleşmeli bir `ApiException::notFound()`
             * dönseydi ekran olmayan bir kaydı aradığını sanırdı.
             *
             * DENETLEYİCİ ADLARI BURADA SABİTLENİYOR. Alan dosyaları sınıf
             * adı vermiyor; aşağıdaki eşleme, denetleyicileri yazan
             * ajanların uyması gereken sözleşmedir. Tek istisna günlük menü
             * takvimidir: `Control\MenuController` adı KDS'in ürün seçicisi
             * tarafından kullanılıyor, bu yüzden takvim alanı
             * `Control\DailyMenuController` adını alır (`Models\DailyMenu`,
             * `Admin\DailyMenus`, `Services\DailyMenuService` ile aynı ad).
             *
             * `$where` GRUP DÜZEYİNDE VERİLİYOR: kimlik parçalarını `\d+`,
             * tarih parçalarını `\d{4}-\d{2}-\d{2}` ile bağlamak, sabit
             * parçaların (`export`, `categories`, `requests`) yanlışlıkla
             * kimlik sanılmasını sıraya değil KALIBA bağlar. Sıra hâlâ doğru
             * ama tek savunma o değil.
             *
             * @param  array<string, string>  $where
             */
            $alan = static function (
                string $prefix,
                string $controller,
                Closure $routes,
                array $where = [],
            ): void {
                if (!class_exists($controller)) {
                    return;
                }

                Route::prefix('control/'.$prefix)
                    ->middleware(['control.signature', 'throttle:bld-control-panel'])
                    ->where($where)
                    ->group($routes);
            };

            // ── Günlük menü takvimi — `docs/control/menu.md` ──────────────
            //
            // Yol parçası TARİHTİR, kimlik değil: `veykemtu_daily_menus`
            // içinde (vitrin, gün) çifti tekil ve yönetici takvimden bir
            // güne tıklıyor. Kalıp `\d{4}-\d{2}-\d{2}` ile bağlanıyor ki
            // `days/stock` gibi bir yazım hatası tarih sanılmasın.
            $alan('menu', ControlDailyMenuController::class, static function (): void {
                Route::get('calendar', [ControlDailyMenuController::class, 'calendar']);
                Route::post('days', [ControlDailyMenuController::class, 'store']);
                Route::get('days/{date}', [ControlDailyMenuController::class, 'show']);
                Route::patch('days/{date}', [ControlDailyMenuController::class, 'update']);
                Route::delete('days/{date}', [ControlDailyMenuController::class, 'destroy']);
                Route::post('days/{date}/publish', [ControlDailyMenuController::class, 'publish']);
                Route::post('days/{date}/unpublish', [ControlDailyMenuController::class, 'unpublish']);
                Route::post('days/{date}/duplicate', [ControlDailyMenuController::class, 'duplicate']);
                Route::get('days/{date}/stock', [ControlDailyMenuController::class, 'stock']);
                Route::put('days/{date}/stock', [ControlDailyMenuController::class, 'setStock']);
                Route::post('days/{date}/items', [ControlDailyMenuController::class, 'storeItem']);
                Route::patch('days/{date}/items/{item}', [ControlDailyMenuController::class, 'updateItem']);
                Route::delete('days/{date}/items/{item}', [ControlDailyMenuController::class, 'destroyItem']);
            }, ['date' => '\\d{4}-\\d{2}-\\d{2}', 'item' => '\\d+']);

            // ── Ürün kataloğu — `docs/control/products.md` ────────────────
            //
            // `categories` SABİT PARÇASI `{menu}`'DEN ÖNCE. Yönlendirici
            // önce eşleşeni alır; sıra ters olsaydı `/categories` bir ürün
            // kimliği sanılır ve kategori ekranı 404 görürdü. Aynı tuzak
            // `addresses/suggest`'te bir kez yaşandı.
            $alan('products', ControlProductController::class, static function (): void {
                Route::get('/', [ControlProductController::class, 'index']);
                Route::post('/', [ControlProductController::class, 'store']);

                Route::get('categories', [ControlProductController::class, 'categories']);
                Route::post('categories', [ControlProductController::class, 'storeCategory']);
                Route::patch('categories/{category}', [ControlProductController::class, 'updateCategory']);

                Route::get('{menu}', [ControlProductController::class, 'show']);
                Route::patch('{menu}', [ControlProductController::class, 'update']);
                // YUMUŞAK KALDIRMA (`menu_status = 0`) — satır silinmez.
                Route::delete('{menu}', [ControlProductController::class, 'destroy']);
                Route::put('{menu}/image', [ControlProductController::class, 'setImage']);
                Route::delete('{menu}/image', [ControlProductController::class, 'destroyImage']);
                Route::post('{menu}/sold-out', [ControlProductController::class, 'soldOut']);
                Route::delete('{menu}/sold-out', [ControlProductController::class, 'clearSoldOut']);
            }, ['menu' => '\\d+', 'category' => '\\d+']);

            // ── Satış ayarları — `docs/control/settings.md` ───────────────
            //
            // `ordering_enabled` BİLEREK `PUT /sales` DIŞINDA: şalteri
            // gerekçesiz ve süresiz çevirmek, durdurmanın en sık hatasını
            // (açmayı unutmak) üretirdi. Kendi uçları var.
            $alan('settings', ControlSettingsController::class, static function (): void {
                // Şube listesi — abonelik açarken `location_id` seçilebilsin
                // diye (I1). Kimliği ekrana gömmek, kurulumdan kuruluma
                // değişen bir sabiti donduracaktı.
                Route::get('locations', [ControlSettingsController::class, 'locations']);
                Route::get('sales', [ControlSettingsController::class, 'sales']);
                Route::put('sales', [ControlSettingsController::class, 'updateSales']);
                Route::post('ordering/pause', [ControlSettingsController::class, 'pause']);
                Route::post('ordering/resume', [ControlSettingsController::class, 'resume']);
                Route::get('closed-days', [ControlSettingsController::class, 'closedDays']);
                Route::post('closed-days', [ControlSettingsController::class, 'storeClosedDay']);
                Route::delete('closed-days/{date}', [ControlSettingsController::class, 'destroyClosedDay']);
            }, ['date' => '\\d{4}-\\d{2}-\\d{2}']);

            /*
             * ── Siparişler — `docs/control/orders.md` ─────────────────────
             *
             * BEŞ UÇ İKİ YOLDA BİRDEN YAYINDA (`show`, `revisions` ×2,
             * `status` aynı metotlar; liste ayrı). Eski yol silinseydi
             * Kontrol Merkezi'nin `bld_kds` modülü kırılırdı; yeni yol
             * açılmasaydı panel siparişleri KDS bütçesinden yer ve kasa
             * yönetimini kilitlerdi.
             *
             * LİSTE AYRI METOT (`panelIndex`): `control/kds/orders` bugünün
             * AKTİF siparişlerini döndürür ve mutfak panosuyla aynı kümedir;
             * panel listesi geçmişe bakar, sayfalanır ve süzülür. Tek metot
             * olsaydı KDS ekranının gördüğü küme değişirdi.
             *
             * `export` SABİT PARÇASI `{order}`'DAN ÖNCE ve `{order}` sayıya
             * bağlı — ikisi birden, çünkü tek başına sıra ileride eklenecek
             * bir sabit parçada yeniden düşünülmek zorunda kalırdı.
             */
            $alan('orders', ControlOrderController::class, static function (): void {
                Route::get('/', [ControlOrderController::class, 'panelIndex']);
                /*
                 * ELLE SİPARİŞ GİRİŞİ — `control/kds` altında KARŞILIĞI YOK.
                 * Mutfak kasası sipariş açmaz; açtığı an mutfak hem satıcı
                 * hem üretici olurdu. Beş ucun iki yolda yayında olması bu
                 * uca genişletilmiyor.
                 */
                Route::post('/', [ControlOrderController::class, 'store']);
                Route::get('export', [ControlOrderController::class, 'export']);
                Route::get('{order}', [ControlOrderController::class, 'show']);
                Route::get('{order}/revisions', [ControlOrderController::class, 'revisions']);
                Route::post('{order}/revisions', [ControlOrderController::class, 'storeRevision']);
                Route::post('{order}/status', [ControlOrderController::class, 'setStatus']);
                Route::post('{order}/cancel', [ControlOrderController::class, 'cancel']);
                Route::get('{order}/invoice', [ControlOrderController::class, 'invoice']);
            }, ['order' => '\\d+']);

            // ── Abonelik, talep, sözleşme, ödeme ──────────────────────────
            //
            // Dört alt aile tek önekte: `docs/control/subscriptions.md`
            // hepsini `/api/control/subscriptions` altında topluyor.
            // SABİT PARÇALI AİLELER (`requests`, `contracts`, `payments`,
            // `orders`) `{subscription}`'DAN ÖNCE — aksi hâlde "requests"
            // bir abonelik kimliği sanılırdı.
            $alan('subscriptions', ControlSubscriptionController::class, static function (): void {
                Route::get('/', [ControlSubscriptionController::class, 'index']);
                Route::post('/', [ControlSubscriptionController::class, 'store']);

                Route::get('requests', [ControlSubscriptionController::class, 'requests']);
                Route::get('requests/{request}', [ControlSubscriptionController::class, 'showRequest']);
                Route::patch('requests/{request}', [ControlSubscriptionController::class, 'updateRequest']);
                Route::post('requests/{request}/convert', [ControlSubscriptionController::class, 'convertRequest']);

                Route::get('contracts/{contract}', [ControlSubscriptionController::class, 'showContract']);
                Route::post('contracts/{contract}/resend', [ControlSubscriptionController::class, 'resendContract']);
                Route::post('contracts/{contract}/cancel', [ControlSubscriptionController::class, 'cancelContract']);

                Route::post('payments/{payment}/mark-paid', [ControlSubscriptionController::class, 'markPaymentPaid']);

                // Hedefi SİPARİŞTİR, abonelik değil: soru "bu sipariş neden
                // erken düştü" biçiminde sorulur.
                Route::post('orders/{order}/release', [ControlSubscriptionController::class, 'releaseOrder']);

                Route::get('{subscription}', [ControlSubscriptionController::class, 'show']);
                Route::patch('{subscription}', [ControlSubscriptionController::class, 'update']);
                Route::post('{subscription}/activate', [ControlSubscriptionController::class, 'activate']);
                Route::post('{subscription}/pause', [ControlSubscriptionController::class, 'pause']);
                Route::post('{subscription}/resume', [ControlSubscriptionController::class, 'resume']);
                Route::post('{subscription}/cancel', [ControlSubscriptionController::class, 'cancel']);
                Route::get('{subscription}/calendar', [ControlSubscriptionController::class, 'calendar']);
                Route::post('{subscription}/exceptions', [ControlSubscriptionController::class, 'storeException']);
                Route::delete('{subscription}/exceptions/{date}', [ControlSubscriptionController::class, 'destroyException']);
                Route::get('{subscription}/runs', [ControlSubscriptionController::class, 'runs']);
                Route::post('{subscription}/generate', [ControlSubscriptionController::class, 'generate']);
                Route::get('{subscription}/contracts', [ControlSubscriptionController::class, 'contracts']);
                Route::post('{subscription}/contracts', [ControlSubscriptionController::class, 'storeContract']);
                Route::get('{subscription}/payments', [ControlSubscriptionController::class, 'payments']);
                Route::post('{subscription}/payments', [ControlSubscriptionController::class, 'storePayment']);
            }, [
                'subscription' => '\\d+',
                'request' => '\\d+',
                'contract' => '\\d+',
                'payment' => '\\d+',
                'order' => '\\d+',
                'date' => '\\d{4}-\\d{2}-\\d{2}',
            ]);

            // ── Müşteriler — KVKK, `docs/control/customers.md` ────────────
            //
            // Bu ailede OKUMALAR DA denetim izine düşer (`customer.read`);
            // kuralın gerekçesi `00-genel.md` §9'da. Rota katmanı bunu
            // bilmez — zorunluluk denetleyicinin içindedir.
            $alan('customers', ControlCustomerController::class, static function (): void {
                Route::get('/', [ControlCustomerController::class, 'index']);
                Route::get('{customer}', [ControlCustomerController::class, 'show']);
                Route::patch('{customer}', [ControlCustomerController::class, 'update']);
                Route::get('{customer}/orders', [ControlCustomerController::class, 'orders']);
                Route::get('{customer}/subscriptions', [ControlCustomerController::class, 'subscriptions']);
                Route::get('{customer}/addresses', [ControlCustomerController::class, 'addresses']);
                Route::post('{customer}/disable', [ControlCustomerController::class, 'disable']);
                Route::post('{customer}/enable', [ControlCustomerController::class, 'enable']);
            }, ['customer' => '\\d+']);

            // ── Fatura belgesi — `docs/control/invoices.md` ───────────────
            //
            // `{invoice}/html` JSON DEĞİL, yazdırılabilir A4 döner; tek
            // istisna budur ve sözleşmede yazılıdır.
            $alan('invoices', ControlInvoiceController::class, static function (): void {
                Route::get('/', [ControlInvoiceController::class, 'index']);
                Route::post('/', [ControlInvoiceController::class, 'store']);
                Route::get('{invoice}', [ControlInvoiceController::class, 'show']);
                Route::get('{invoice}/html', [ControlInvoiceController::class, 'html']);
                Route::post('{invoice}/void', [ControlInvoiceController::class, 'void']);
            }, ['invoice' => '\\d+']);

            // ── Site içeriği — `docs/control/cms.md` ──────────────────────
            //
            // `content/{key}` kimlik değil METİN anahtar taşır
            // (`veykemtu_site_content` birincil anahtarı bir metin); kalıp
            // `[a-z_]+` ile bağlanıyor.
            $alan('cms', ControlCmsController::class, static function (): void {
                Route::get('content', [ControlCmsController::class, 'content']);
                Route::put('content/{key}', [ControlCmsController::class, 'updateContent'])
                    ->where('key', '[a-z_]+');

                Route::get('services', [ControlCmsController::class, 'services']);
                Route::post('services', [ControlCmsController::class, 'storeService']);
                Route::patch('services/{service}', [ControlCmsController::class, 'updateService']);
                Route::delete('services/{service}', [ControlCmsController::class, 'destroyService']);

                Route::get('posts', [ControlCmsController::class, 'posts']);
                Route::post('posts', [ControlCmsController::class, 'storePost']);
                Route::patch('posts/{post}', [ControlCmsController::class, 'updatePost']);
                Route::delete('posts/{post}', [ControlCmsController::class, 'destroyPost']);

                Route::post('revalidate', [ControlCmsController::class, 'revalidate']);
            }, ['service' => '\\d+', 'post' => '\\d+']);

            // ── SMS şablon, kayıt, duyuru — `docs/control/sms.md` ─────────
            $alan('sms', ControlSmsController::class, static function (): void {
                Route::get('templates', [ControlSmsController::class, 'templates']);
                Route::patch('templates/{key}', [ControlSmsController::class, 'updateTemplate'])
                    ->where('key', '[a-z0-9_]+');
                Route::post('templates/{key}/preview', [ControlSmsController::class, 'previewTemplate'])
                    ->where('key', '[a-z0-9_]+');
                Route::post('send-test', [ControlSmsController::class, 'sendTest']);
                Route::get('log', [ControlSmsController::class, 'log']);
                Route::get('announcement', [ControlSmsController::class, 'announcement']);
                Route::put('announcement', [ControlSmsController::class, 'updateAnnouncement']);
                Route::post('announcement/run', [ControlSmsController::class, 'runAnnouncement']);

                /*
                 * Gönderici başlığı — F. `templates` yolundan AYRI durur
                 * çünkü şablon değil, SAĞLAYICI ayarıdır: metni düzeltmekle
                 * bütün gönderimlerin görünen adını değiştirmek aynı iş
                 * değil ve panelde de ayrı bir sekmede duruyor.
                 *
                 * Kullanıcı adı/parola BURADAN YAZILMAZ ve okunmaz; ikisi de
                 * ortam değişkeninde (`Services\Sms\NetgsmSettings`).
                 */
                Route::get('netgsm', [ControlSmsController::class, 'netgsm']);
                Route::put('netgsm', [ControlSmsController::class, 'updateNetgsm']);
            });

            // ── Uygulama içi duyuru — `docs/control/notifications.md` ─────
            $alan('notifications', ControlNotificationController::class, static function (): void {
                Route::get('/', [ControlNotificationController::class, 'index']);
                Route::post('/', [ControlNotificationController::class, 'store']);
                Route::patch('{notification}', [ControlNotificationController::class, 'update']);
                // ARŞİVLEME (yumuşak) — satır silinmez.
                Route::delete('{notification}', [ControlNotificationController::class, 'destroy']);
                Route::post('{notification}/publish', [ControlNotificationController::class, 'publish']);
                Route::get('{notification}/stats', [ControlNotificationController::class, 'stats']);
            }, ['notification' => '\\d+']);

            // ── Hata olayları ve kasa sağlığı — `docs/control/monitor.md` ─
            $alan('monitor', ControlMonitorController::class, static function (): void {
                Route::get('events', [ControlMonitorController::class, 'events']);
                Route::get('events/{event}', [ControlMonitorController::class, 'showEvent']);
                Route::post('events/{event}/resolve', [ControlMonitorController::class, 'resolveEvent']);
                Route::get('devices', [ControlMonitorController::class, 'devices']);
                Route::get('summary', [ControlMonitorController::class, 'summary']);
            }, ['event' => '\\d+']);

            // ── Açılış özeti — `docs/control/dashboard.md` ────────────────
            //
            // `control/kds/overview` ile KARIŞTIRILMAMALI: o, kasa yönetim
            // ekranının dar özeti; bu, panelin açılış sayfası.
            $alan('dashboard', ControlDashboardController::class, static function (): void {
                Route::get('overview', [ControlDashboardController::class, 'overview']);
            });

            // ── Denetim izi — `docs/control/audit.md` ─────────────────────
            //
            // YAZMA UCU YOKTUR ve olmayacak: denetim izi silinemez,
            // düzeltilemez. `actions` sabit parçası `{audit}`'ten önce.
            $alan('audit', ControlAuditController::class, static function (): void {
                Route::get('/', [ControlAuditController::class, 'index']);
                Route::get('actions', [ControlAuditController::class, 'actions']);
                Route::get('{audit}', [ControlAuditController::class, 'show']);
            }, ['audit' => '\\d+']);
        });
    });
