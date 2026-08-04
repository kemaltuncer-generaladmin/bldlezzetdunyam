<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Models\KitchenDevice;

/**
 * Kapsam ayrımı — ADR-08, `docs/10-test-kabul.md` S5.
 *
 * Müşteri token'ı `/api/kitchen/*` uçlarına, mutfak token'ı da müşteri
 * uçlarına **erişemez**. Mutfak token'ı fiyat, iletişim bilgisi ve rapor
 * göremez; kasa çalınırsa sızacak veri sınırlı kalır.
 *
 * Kullanım: `->middleware('bld.scope:kitchen')`
 */
class RequireScope
{
    public function handle(Request $request, Closure $next, string $scope): Response
    {
        $user = $request->user();

        if ($user === null) {
            throw ApiException::unauthenticated(
                $scope === KitchenDevice::SCOPE
                    ? 'Cihaz eşlenmemiş.'
                    : 'Oturum bulunamadı, tekrar giriş yapın.',
            );
        }

        // İptal edilmiş cihaz: yetkisiz değil, **iptal edilmiş** demek gerekir.
        // KDS bu kodu görünce eşleme ekranına döner (docs/05 §7 adım 5).
        if ($user instanceof KitchenDevice && $user->isRevoked()) {
            throw ApiException::deviceRevoked();
        }

        $expectedType = match ($scope) {
            KitchenDevice::SCOPE => KitchenDevice::class,
            ApiCustomer::SCOPE => ApiCustomer::class,
            default => throw ApiException::serverError('Tanımsız kapsam: '.$scope),
        };

        // İki katmanlı kontrol: hem tokenable tipi hem token yeteneği.
        // Yalnızca yeteneğe bakmak, elle üretilmiş bir token'ın yanlış model
        // tipiyle geçmesine izin verirdi.
        if (!$user instanceof $expectedType) {
            throw ApiException::forbidden();
        }

        if (!$user->tokenCan($scope)) {
            throw ApiException::forbidden();
        }

        if ($user instanceof KitchenDevice) {
            $user->touchLastSeen();
        }

        return $next($request);
    }
}
