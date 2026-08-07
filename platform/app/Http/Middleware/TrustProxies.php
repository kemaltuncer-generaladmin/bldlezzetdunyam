<?php

namespace App\Http\Middleware;

use Illuminate\Http\Middleware\TrustProxies as Middleware;
use Illuminate\Http\Request;

class TrustProxies extends Middleware
{
    /**
     * Güvenilen ters vekiller.
     *
     * ## Neden boş bırakılamaz
     *
     * `null` iken uygulama HİÇBİR vekile güvenmiyor, yani `X-Forwarded-For`
     * başlığını tamamen yok sayıyor ve `$request->ip()` her istekte Caddy
     * konteynerinin iç adresini döndürüyor.
     *
     * Sonuç sessiz ama ağır: bütün oran sınırları `->by($request->ip())` ile
     * anahtarlanıyor (`Extension::registerRateLimiters`), dolayısıyla hepsi
     * TEK KÜRESEL KOVAYA düşüyordu. Pratikte:
     *   - `bld-auth`   → tüm site için dakikada 10 giriş denemesi
     *   - `bld-quote`  → tüm site için saatte 10 teklif talebi
     *   - `bld-order`  → oturum açmamış her istek aynı kovada
     *
     * Yani birinci müşteri sınırı doldurunca ikinci müşteri giriş yapamıyor.
     * Kimse hata görmüyor; yalnızca "sistem bugün tuhaf" deniyor.
     *
     * ## Neden `'*'` değil, özel ağ aralıkları
     *
     * Laravel BAĞLANAN adrese bakıyor: bu adres güvenilenler listesindeyse
     * `X-Forwarded-For` zincirini okuyor. Bize bağlanan tek şey aynı Docker
     * ağındaki Caddy ve onun adresi her zaman özel aralıkta.
     *
     * `'*'` yazsaydık, uygulama ileride herhangi bir sebeple doğrudan
     * erişilebilir hâle geldiğinde saldırgan `X-Forwarded-For` uydurup oran
     * sınırını tamamen atlayabilirdi. Özel aralıklarla sınırlamak bu kapıyı
     * kapatıyor ve mevcut topolojide hiçbir şey kaybettirmiyor.
     *
     * @var array<int, string>|string|null
     */
    protected $proxies = [
        '10.0.0.0/8',
        '172.16.0.0/12',
        '192.168.0.0/16',
        '127.0.0.1',
        '::1',
        'fc00::/7',
    ];

    /**
     * The headers that should be used to detect proxies.
     *
     * @var int
     */
    protected $headers =
        Request::HEADER_X_FORWARDED_FOR |
        Request::HEADER_X_FORWARDED_HOST |
        Request::HEADER_X_FORWARDED_PORT |
        Request::HEADER_X_FORWARDED_PROTO |
        Request::HEADER_X_FORWARDED_AWS_ELB;
}
