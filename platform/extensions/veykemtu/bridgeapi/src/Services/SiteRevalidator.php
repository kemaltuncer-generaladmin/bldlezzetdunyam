<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Illuminate\Support\Facades\Http;
use Throwable;

/**
 * İçerik değiştiğinde kurumsal siteye "önbelleğini tazele" der.
 *
 * ## Neden gerekli?
 *
 * Panelde kaydet'e basmak sunucu önbelleğini düşürüyor (`SiteContentObserver`)
 * ama site kendi kopyasını Next.js ISR ile tutuyor. Haber vermezsek yönetici
 * değişikliğini beş dakikaya kadar göremez ve "kaydettim ama olmadı" diye
 * tekrar tekrar kaydeder.
 *
 * ## Hata SESSİZ YUTULUR — bilerek
 *
 * Site kapalıysa, adres yanlışsa veya ağ kopuksa **kaydetme işlemi yine de
 * başarılı olmalı.** İçerik veritabanına yazıldı; sitenin haberi olmaması
 * yalnızca gecikme demek, veri kaybı değil. Burada istisna fırlatmak,
 * yöneticinin kaydını reddedip yazdığı metni çöpe atardı.
 *
 * Site zaten en geç ISR süresi dolduğunda kendini toparlar; bu istek sadece
 * o süreyi kısaltıyor. Yani "en iyi çaba" bir bildirim, kritik bir yol değil.
 *
 * ## Yapılandırılmadıysa sessizce atlanır
 *
 * Geliştirme makinesinde ve testlerde site ayakta olmayabilir. Adres veya sır
 * tanımsızken her kaydetmede günlüğe uyarı basmak, gerçek hataları görünmez
 * hâle getirirdi.
 */
final class SiteRevalidator
{
    /**
     * Kısa zaman aşımı: yönetici kaydet'e bastığında panelin kilitlenmemesi
     * gerekiyor. Site yavaşsa beklemek yerine vazgeçip ISR'a bırakıyoruz.
     */
    private const int TIMEOUT_SECONDS = 3;

    public function revalidate(): void
    {
        $url = trim((string) config('veykemtu.site_revalidate_url', env('SITE_REVALIDATE_URL', '')));
        $secret = trim((string) config('veykemtu.site_revalidate_secret', env('SITE_REVALIDATE_SECRET', '')));

        if ($url === '' || $secret === '') {
            return;
        }

        try {
            Http::timeout(self::TIMEOUT_SECONDS)
                ->withToken($secret)
                ->post($url);
        } catch (Throwable $exception) {
            // Günlüğe yazılıyor ama yukarı fırlatılmıyor: gerekçe sınıf başlığında.
            report($exception);
        }
    }
}
