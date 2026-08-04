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
        return $this->json([
            'status' => 'ok',
            'server_time' => Carbon::now()->utc()->toIso8601ZuluString(),
        ]);
    }
}
