<?php

declare(strict_types=1);

/**
 * Sunucuda çizilen HTML sayfaları — API değil.
 *
 * Bu dosyada tek bir akış var: kuryenin fişteki QR'ı okutunca gördüğü
 * teslim onayı (K-20). `routes/api.php`'den AYRI, çünkü burası `web`
 * middleware yığınında yaşıyor: sayfa gerçek bir HTML formu ve CSRF
 * koruması gerekiyor. API rotalarımız durumsuz ve token'lı, ayrı bir
 * dünya.
 *
 * SÖZLEŞMEDE YOK VE OLMAYACAK: `docs/openapi.yaml` üretilen istemciler
 * için; sunucuda çizilen bir kurye sayfasının istemcisi yok. Emsali
 * `/odeme-simulasyon/{hash}`, o da sözleşmede değil. Belgesi
 * `docs/03-api-sozlesmesi.md` ve `docs/05-mutfakapp.md` düzyazısında.
 *
 * DİKKAT — `infra/Caddyfile.internal`: API alan adında vitrin dışı her yol
 * ana siteye 308'leniyor. `/teslimat/*` o dosyadaki izin listesinde
 * olmazsa bu rotalar üretimde hiç çalışmaz.
 */

use Illuminate\Support\Facades\Route;
use Veykemtu\BridgeApi\Http\Controllers\DeliveryConfirmController;

Route::get('/teslimat/{order}', [DeliveryConfirmController::class, 'show'])
    ->whereNumber('order')
    ->middleware('throttle:bld-teslimat')
    ->name('veykemtu.bridgeapi.delivery_confirm');

Route::post('/teslimat/{order}', [DeliveryConfirmController::class, 'confirm'])
    ->whereNumber('order')
    ->middleware('throttle:bld-teslimat');
