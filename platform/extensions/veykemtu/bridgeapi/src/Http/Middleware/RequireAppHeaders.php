<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use Veykemtu\BridgeApi\Exceptions\ApiException;

/**
 * Zorunlu istemci başlıkları — `docs/03-api-sozlesmesi.md` §1.1.
 *
 * NEDEN ZORUNLU: sahada aynı anda farklı istemci sürümleri çalışır (ADR-09).
 * Bir hata raporu geldiğinde hangi uygulamanın hangi sürümünün gönderdiğini
 * bilmezsek hata ayıklanamaz. Başlığı isteğe bağlı bırakırsak kimse göndermez.
 *
 * Mock sunucu da aynı kontrolü yapar — istemciler eksikliği ilk günde görsün.
 */
class RequireAppHeaders
{
    private const array VALID_APP_IDS = ['website', 'musteriapp', 'mutfakapp'];

    public function handle(Request $request, Closure $next): Response
    {
        // API yanıtları HER ZAMAN JSON'dur (docs/03 §Taban adres). Laravel,
        // kimlik doğrulanmamış isteği `Accept` başlığına bakarak ya 401 JSON
        // döndürür ya da `login` rotasına yönlendirmeye çalışır. Bizde `login`
        // diye bir rota yok; yönlendirme "Route [login] not defined" ile
        // 500'e dönüşür ve gerçek hata (401) kaybolur. Başlığı istemciye
        // bırakmıyoruz — sınırda zorluyoruz.
        $request->headers->set('Accept', 'application/json');

        $appId = $request->header('X-App-Id');
        $appVersion = $request->header('X-App-Version');

        $missing = [];
        if (blank($appId)) {
            $missing[] = 'X-App-Id';
        }
        if (blank($appVersion)) {
            $missing[] = 'X-App-Version';
        }

        if ($missing !== []) {
            throw ApiException::validationFailed(
                'Zorunlu başlık eksik. Her istek X-App-Id ve X-App-Version göndermelidir.',
                ['missing_headers' => $missing],
            );
        }

        if (!in_array($appId, self::VALID_APP_IDS, true)) {
            throw ApiException::validationFailed(
                'Geçersiz X-App-Id değeri.',
                ['X-App-Id' => 'website, musteriapp veya mutfakapp olmalı.'],
            );
        }

        return $next($request);
    }
}
