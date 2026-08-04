<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Exceptions;

use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Symfony\Component\HttpKernel\Exception\TooManyRequestsHttpException;
use Throwable;

/**
 * Her istisnayı sözleşmedeki tek hata biçimine çevirir
 * (`docs/03-api-sozlesmesi.md` §1.2).
 *
 * NEDEN TEK YER: dört istemci hata işlemeyi `error.code` üzerine kuruyor.
 * Laravel'in varsayılan yanıtları (validation için `errors`, 404 için HTML)
 * o sözleşmeyi tutmaz. Buradan geçmeyen tek bir hata biçimi bile istemcide
 * "Beklenmeyen hata" olarak görünür ve sahada teşhis edilemez.
 */
final class ApiExceptionRenderer
{
    private function __construct() {}

    public static function render(Throwable $e, Request $request): JsonResponse
    {
        return match (true) {
            $e instanceof ApiException => $e->render(),

            $e instanceof ValidationException => self::body(
                'VALIDATION_FAILED',
                'Gönderilen bilgilerde hata var.',
                422,
                // Alan bazlı ayrıntı: sözleşme `details`'i alan adı → mesaj
                // haritası olarak tanımlar.
                array_map(
                    static fn(array $messages): string => $messages[0],
                    $e->errors(),
                ),
            ),

            $e instanceof AuthenticationException => self::body(
                'UNAUTHENTICATED',
                'Oturum bulunamadı, tekrar giriş yapın.',
                401,
            ),

            $e instanceof AuthorizationException => self::body(
                'FORBIDDEN',
                'Bu uca erişim yetkiniz yok.',
                403,
            ),

            // Varlık sızdırmama: başkasının kaydı da "yok" görünür
            // (docs/10-test-kabul.md S5 adım 4).
            $e instanceof ModelNotFoundException,
            $e instanceof NotFoundHttpException => self::body(
                'NOT_FOUND',
                'Kayıt bulunamadı.',
                404,
            ),

            $e instanceof TooManyRequestsHttpException => self::body(
                'RATE_LIMITED',
                'Çok fazla istek gönderildi. Biraz bekleyip tekrar deneyin.',
                429,
            ),

            // Yönlendirme/metot hataları gibi diğer HTTP istisnaları kendi
            // durum kodlarını korur ama gövdeleri yine sözleşmeye uyar.
            $e instanceof HttpExceptionInterface => self::body(
                self::codeForStatus($e->getStatusCode()),
                'İstek işlenemedi.',
                $e->getStatusCode(),
            ),

            default => self::unexpected($e),
        };
    }

    /**
     * Beklenmeyen hata.
     *
     * Mesaj her zaman genel geçerdir — yığın izi veya SQL parçası istemciye
     * sızmaz. Ayrıntı yalnızca `APP_DEBUG` açıkken, geliştirme için eklenir.
     */
    private static function unexpected(Throwable $e): JsonResponse
    {
        report($e);

        return self::body(
            'SERVER_ERROR',
            'Beklenmeyen bir hata oluştu.',
            500,
            config('app.debug') === true
                ? [
                    'exception' => $e::class,
                    'message' => $e->getMessage(),
                    'at' => $e->getFile().':'.$e->getLine(),
                ]
                : null,
        );
    }

    private static function codeForStatus(int $status): string
    {
        return match ($status) {
            401 => 'UNAUTHENTICATED',
            403 => 'FORBIDDEN',
            404 => 'NOT_FOUND',
            422 => 'VALIDATION_FAILED',
            429 => 'RATE_LIMITED',
            default => 'SERVER_ERROR',
        };
    }

    /** @param array<string, mixed>|null $details */
    private static function body(
        string $code,
        string $message,
        int $status,
        ?array $details = null,
    ): JsonResponse {
        return new JsonResponse([
            'error' => array_filter([
                'code' => $code,
                'message' => $message,
                'details' => $details,
            ], static fn($value): bool => $value !== null),
        ], $status, [], JSON_UNESCAPED_UNICODE);
    }
}
