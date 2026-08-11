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
use Veykemtu\BridgeApi\Http\Controllers\HealthController;
use Veykemtu\BridgeApi\Http\Controllers\KitchenController;
use Veykemtu\BridgeApi\Http\Controllers\OrderController;
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
        });

        Route::get('locations', [CatalogController::class, 'locations']);
        Route::get('locations/{location}/menu', [CatalogController::class, 'menu']);
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
    });
