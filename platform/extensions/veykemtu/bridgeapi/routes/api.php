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
use Veykemtu\BridgeApi\Http\Controllers\AppVersionController;
use Veykemtu\BridgeApi\Http\Controllers\AuthController;
use Veykemtu\BridgeApi\Http\Controllers\CatalogController;
use Veykemtu\BridgeApi\Http\Controllers\HealthController;
use Veykemtu\BridgeApi\Http\Controllers\KitchenController;
use Veykemtu\BridgeApi\Http\Controllers\OrderController;

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

        // Eşleme kodu tek kullanımlık ve 10 dk ömürlü; kaba kuvvete karşı
        // ayrıca oran sınırı uygulanır.
        Route::post('kitchen/pair', [KitchenController::class, 'pair'])
            ->middleware('throttle:bld-auth');

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
        });

        // ── Mutfak kapsamı ───────────────────────────────────────────────
        Route::prefix('kitchen')
            ->middleware(['bld.auth', 'bld.scope:kitchen', 'throttle:bld-kitchen'])
            ->group(function (): void {
                Route::get('orders', [KitchenController::class, 'orders']);
                Route::post('orders/{order}/status', [KitchenController::class, 'setStatus']);
                Route::get('orders/{order}/receipt', [KitchenController::class, 'receipt']);
                Route::post('print-jobs/{order}/ack', [KitchenController::class, 'ackPrint']);
                Route::get('production-list', [KitchenController::class, 'productionList']);
                Route::get('heartbeat', [KitchenController::class, 'heartbeat']);
                Route::post('busy', [KitchenController::class, 'setBusy']);
            });
    });
