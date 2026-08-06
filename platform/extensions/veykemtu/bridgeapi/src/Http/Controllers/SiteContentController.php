<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Veykemtu\BridgeApi\Services\SiteContentRepository;

/**
 * Kurumsal site içeriği ucu — `docs/openapi.yaml` §Site.
 *
 * Kimlik gerektirmez: içeriğin tamamı zaten sitede herkese açık yayınlanıyor.
 * Token istemek, siteyi statik üretebilmek için sunucuya sır koymak
 * anlamına gelirdi ve hiçbir şey korumazdı.
 */
class SiteContentController extends ApiController
{
    public function __construct(private readonly SiteContentRepository $repository) {}

    public function show(): JsonResponse
    {
        return $this->json($this->repository->bundle());
    }
}
