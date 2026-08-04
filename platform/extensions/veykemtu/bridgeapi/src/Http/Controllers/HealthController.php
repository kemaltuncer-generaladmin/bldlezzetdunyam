<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Support\Carbon;

/**
 * Uptime kontrolü — `docs/08-kurulum-deploy.md` §5.
 *
 * Harici bir izleme servisi bunu dakikada bir çağırır. Kasten hafiftir:
 * veritabanına dokunmaz, çünkü DB düştüğünde bu ucun da düşmesi izlemenin
 * "sunucu ayakta mı" sorusunu cevaplamasını engellerdi — o ayrı bir alarm.
 */
class HealthController extends ApiController
{
    public function show(): JsonResponse
    {
        return $this->json(array_filter([
            'status' => 'ok',
            'server_time' => Carbon::now()->utc()->toIso8601ZuluString(),
            // Tehlikeli durum kendini duyurur. Simülasyon geçidi üretim
            // ortamında açıksa her sipariş bedavadır; bunu yalnızca bir
            // ortam değişkenine gömüp unutulmasına izin vermek yerine
            // sağlık ucundan ilan ediyoruz. İzleme servisi de görür.
            'payment_simulation_active' => $this->simulationWarning(),
        ], static fn($v): bool => $v !== null));
    }

    /**
     * Üretimde simülasyon açıksa uyarı, değilse `null` (alan hiç görünmez).
     *
     * Geliştirme ve staging'de simülasyonun açık olması normaldir ve
     * bildirilmez — her yerde uyarı basmak, uyarıyı görünmez yapar.
     */
    private function simulationWarning(): ?bool
    {
        $sinif = 'Veykemtu\\Payment\\Payments\\SimulatedPos';

        if (!class_exists($sinif) || config('app.env') !== 'production') {
            return null;
        }

        return $sinif::isAllowed() ? true : null;
    }
}
