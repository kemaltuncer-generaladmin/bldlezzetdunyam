<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Laravel\Sanctum\PersonalAccessToken;
use Symfony\Component\HttpFoundation\Response;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\KitchenDevice;

/**
 * Bearer token'ı çözer ve isteğe kullanıcıyı bağlar.
 *
 * NEDEN LARAVEL'İN `auth:sanctum` MIDDLEWARE'İ KULLANILMIYOR:
 * `Illuminate\Auth\Middleware\Authenticate`, kimliksiz istekte `expectsJson()`
 * false ise `login` adlı rotaya yönlendirmeye çalışır. Bu projede öyle bir
 * rota yok; sonuç, sözleşmedeki `401 UNAUTHENTICATED` yerine
 * "Route [login] not defined" 500'ü oluyordu. Gerçek hata kaybolduğu için
 * sahada teşhis edilemezdi.
 *
 * Kendi çözümümüz Laravel'in tarayıcı varsayımlarına hiç girmez ve her
 * durumda sözleşmedeki gövdeyi döner.
 */
class AuthenticateToken
{
    public function handle(Request $request, Closure $next): Response
    {
        $plain = $request->bearerToken();

        if ($plain === null || $plain === '') {
            throw ApiException::unauthenticated();
        }

        $accessToken = PersonalAccessToken::findToken($plain);

        if ($accessToken === null) {
            throw ApiException::unauthenticated('Oturum geçersiz, tekrar giriş yapın.');
        }

        $tokenable = $accessToken->tokenable;

        if ($tokenable === null) {
            throw ApiException::unauthenticated('Oturum geçersiz, tekrar giriş yapın.');
        }

        // İptal edilmiş cihaz, "yetkisiz" değil "iptal edilmiş"tir: KDS bu
        // kodu görünce eşleme ekranına döner (docs/05 §7 adım 5).
        if ($tokenable instanceof KitchenDevice && $tokenable->isRevoked()) {
            throw ApiException::deviceRevoked();
        }

        $accessToken->forceFill(['last_used_at' => now()])->saveQuietly();

        $request->setUserResolver(
            static fn() => $tokenable->withAccessToken($accessToken),
        );

        return $next($request);
    }
}
