<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Veykemtu\BridgeApi\Exceptions\ApiException;

/**
 * Sürüm ucu — `docs/openapi.yaml` §Sürüm.
 *
 * İstemci sürümü `min_supported` altındaysa engelleyici güncelleme ekranı
 * gösterir. Kasa uygulaması ayrıca `download_url`'den `.deb` indirir
 * (`docs/05-mutfakapp.md` §9).
 *
 * `veykemtu_app_releases` tablosu `veykemtu/appversion` eklentisine aittir
 * (`B-10`). Tablo yokken uç, kurulu sürümü zorunlu kılmayan güvenli bir
 * varsayılan döner — sürüm kaydı girilmediği için hiçbir istemci
 * kilitlenmemeli.
 */
class AppVersionController extends ApiController
{
    private const string FALLBACK_VERSION = '1.0.0';

    public function show(Request $request): JsonResponse
    {
        $data = $request->validate([
            'app_id' => ['required', Rule::in(['musteriapp', 'mutfakapp'])],
        ]);

        $appId = $data['app_id'];

        if (!DB::getSchemaBuilder()->hasTable('veykemtu_app_releases')) {
            return $this->json($this->fallback($appId));
        }

        $release = DB::table('veykemtu_app_releases')
            ->where('app_id', $appId)
            ->orderByDesc('released_at')
            ->first();

        if ($release === null) {
            return $this->json($this->fallback($appId));
        }

        return $this->json([
            'app_id' => $appId,
            'latest' => (string) $release->version,
            'min_supported' => (string) $release->min_supported,
            'download_url' => $release->download_url !== null
                ? (string) $release->download_url
                : null,
            'notes' => $release->notes !== null ? (string) $release->notes : null,
        ]);
    }

    /** @return array<string, mixed> */
    private function fallback(string $appId): array
    {
        return [
            'app_id' => $appId,
            'latest' => self::FALLBACK_VERSION,
            'min_supported' => self::FALLBACK_VERSION,
            'download_url' => null,
            'notes' => 'Sürüm kaydı henüz girilmedi.',
        ];
    }
}
