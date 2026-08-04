<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Routing\Controller;
use Illuminate\Support\Carbon;

/**
 * API denetleyicilerinin ortak tabanı.
 *
 * Tek işi yanıt biçimini tekdüze tutmak: UTF-8 kaçışsız JSON (Türkçe
 * karakterler `ç` diye değil `ç` diye gitsin — fiş şablonlarında ve
 * hata mesajlarında okunabilirlik önemli) ve tutarlı zaman damgası biçimi.
 */
abstract class ApiController extends Controller
{
    /** @param array<string, mixed> $data */
    protected function json(array $data, int $status = 200): JsonResponse
    {
        return new JsonResponse($data, $status, [], JSON_UNESCAPED_UNICODE);
    }

    protected function noContent(): JsonResponse
    {
        return new JsonResponse(null, 204);
    }

    /**
     * Sözleşmedeki zaman biçimi: ISO 8601, UTC, `Z` sonekli.
     *
     * `toIso8601String()` `+00:00` üretir; sözleşme örnekleri `Z` kullanıyor
     * ve Dart'ın `DateTime.parse`'ı ikisini de okusa da tutarlılık,
     * istemci golden testlerinin kırılmamasını sağlar.
     */
    protected static function ts(mixed $value): ?string
    {
        if ($value === null) {
            return null;
        }

        return Carbon::parse($value)->utc()->toIso8601ZuluString();
    }
}
