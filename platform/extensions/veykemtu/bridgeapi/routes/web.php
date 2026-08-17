<?php

declare(strict_types=1);

/**
 * Sunucuda çizilen HTML sayfaları — API değil.
 *
 * Buradaki sayfaların ortak yanı, onları açan şeyin bir istemci uygulaması
 * OLMAMASI: kuryenin kamerası, abonenin SMS'teki bağlantısı, sanal POS'un
 * geri yönlendirmesi. `routes/api.php`'den AYRI, çünkü burası `web`
 * middleware yığınında yaşıyor: sayfalar gerçek HTML ve form gönderenler
 * CSRF koruması istiyor. API rotalarımız durumsuz ve token'lı, ayrı bir
 * dünya.
 *
 * SÖZLEŞMEDE YOK VE OLMAYACAK: `docs/openapi.yaml` üretilen istemciler
 * için; sunucuda çizilen bir sayfanın istemcisi yok. Emsali
 * `/odeme-simulasyon/{hash}`, o da sözleşmede değil. Belgesi
 * `docs/03-api-sozlesmesi.md` ve `docs/05-mutfakapp.md` düzyazısında.
 *
 * DİKKAT — `infra/Caddyfile.internal`: API alan adında vitrin dışı her yol
 * ana siteye 308'leniyor. `/teslimat/*`, `/sozlesme/*` ve
 * `/abonelik-odemesi/*` o dosyadaki izin listesinde olmazsa bu rotalar
 * üretimde hiç çalışmaz.
 *
 * SINIF YOKSA ROTA HİÇ KAYDEDİLMEZ — `routes/api.php`'deki `class_exists()`
 * denetiminin aynısı ve buradaki sebebi SOMUT bir arızadır: var olmayan bir
 * denetleyiciye bakan tek bir rota `php artisan route:list`'in TAMAMINI
 * `ReflectionException` ile düşürüyor (`RouteListCommand` her rotanın sınıf
 * dosyasını yansımayla okuyor). Yani eksik bir dosya, ilgisiz bir rotayı
 * arayan herkesin teşhis aracını da elinden alırdı. `route:cache` bundan
 * etkilenmiyor; kırılan yalnız listeleme.
 */

use Illuminate\Support\Facades\Route;
use Veykemtu\BridgeApi\Http\Controllers\ContractPageController;
use Veykemtu\BridgeApi\Http\Controllers\DeliveryConfirmController;
use Veykemtu\BridgeApi\Http\Controllers\SubscriptionPaymentReturnController;

Route::get('/teslimat/{order}', [DeliveryConfirmController::class, 'show'])
    ->whereNumber('order')
    ->middleware('throttle:bld-teslimat')
    ->name('veykemtu.bridgeapi.delivery_confirm');

Route::post('/teslimat/{order}', [DeliveryConfirmController::class, 'confirm'])
    ->whereNumber('order')
    ->middleware('throttle:bld-teslimat');

/*
 * ── Abonelik sözleşmesi sayfası ──────────────────────────────────────────
 *
 * Aboneye SMS ile giden bağlantı. `/teslimat/{order}` emsali: açan kişinin
 * sistemde hesabı yok, yetki URL'nin kendisinde.
 *
 * İMZA YOL PARÇASINDA, SORGU DİZESİNDE DEĞİL — `/teslimat`'tan ayrıldığı
 * tek nokta bu. Bağlantı SMS'e giriyor ve operatör/kısaltıcı zincirinden
 * geçiyor; o zincirde sorgu dizesi kırpılabiliyor. Kırpılan bir `?e=&s=`
 * imzayı geçersiz kılar ve abone sözleşmesini hiç göremez. Yol parçası
 * kırpılmaz.
 *
 * ÜÇ PARÇA DA İMZANIN İÇİNDE (`Support\SignedLink` deseni): sözleşme
 * kimliği sıralı denemeyle komşu sözleşmeye geçmeyi, bitiş anı bağlantının
 * kendi süresini uzatmayı engeller.
 *
 * YALNIZ `GET` — POST KARDEŞİ YOK VE OLMAYACAK. Sayfanın iki yazma adımı
 * (kod iste, onayla) DONMUŞ SÖZLEŞMEDE tanımlı uçlardır:
 * `POST /api/contracts/{token}/otp` ve `.../approve`. Sayfaya kendi form
 * gönderimini yazsaydık aynı iş iki yerde yaşar, oran sınırı ve OTP deneme
 * sayacı ikiye bölünürdü — kodu web sayfasından deneyen biri API
 * bütçesine hiç dokunmazdı.
 */
if (class_exists(ContractPageController::class)) {
    Route::get('/sozlesme/{contract}/{expires}/{signature}', [ContractPageController::class, 'show'])
        ->whereNumber('contract')
        ->whereNumber('expires')
        ->where('signature', '[A-Za-z0-9_-]{16,64}')
        ->middleware('throttle:bld-sozlesme')
        ->name('veykemtu.bridgeapi.contract_page');
}

/*
 * ── Abonelik ödemesi — sağlayıcıdan dönüş ────────────────────────────────
 *
 * SİMÜLASYON SAYFASI BURADA DEĞİL: o `veykemtu/payment` eklentisinde ve
 * `docs/control/_devralinan-odeme-yapisi.md` §6 onu ÜÇÜNCÜ bir rota olarak
 * tarif ediyor. Buradaki iki rota sağlayıcının kullanıcıyı GERİ
 * bıraktığı yer; simülasyon kapalıyken de yaşarlar, çünkü gerçek POS da
 * aynı adreslere döner.
 *
 * İKİ AYRI ADRES, TEK ADRES + `durum` PARAMETRESİ DEĞİL: sanal POS
 * yapılandırması başarı ve iptal için iki ayrı URL istiyor ve o iki alanı
 * aynı adresle doldurmak, sağlayıcı parametreyi göndermediğinde iptali
 * başarı saymak demek olurdu.
 *
 * ABONE UYGULAMADA OLMAYABİLİR: ödeme akışı SMS'teki sözleşme
 * bağlantısından da başlayabiliyor, yani `FRONTEND_URL` altındaki bir hesap
 * sayfasına dönmek her zaman mümkün değil. Sonuç bu yüzden sunucuda
 * çiziliyor.
 *
 * `{hash}` KAYIT KİMLİĞİ DEĞİL (devralınan yapı §3): sıralı bir kimlik
 * dışarı verilseydi adres tahmin edilerek başkasının ödeme sonucu
 * okunabilirdi.
 */
if (class_exists(SubscriptionPaymentReturnController::class)) {
    Route::middleware('throttle:bld-odeme-donus')
        ->where(['hash' => '[a-f0-9]{32,64}'])
        ->group(function (): void {
            Route::get('/abonelik-odemesi/{hash}/sonuc', [SubscriptionPaymentReturnController::class, 'showResult'])
                ->name('veykemtu.bridgeapi.subscription_payment_result');

            Route::get('/abonelik-odemesi/{hash}/iptal', [SubscriptionPaymentReturnController::class, 'showCancelled'])
                ->name('veykemtu.bridgeapi.subscription_payment_cancelled');
        });
}
