<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Exceptions;

use Exception;
use Illuminate\Http\JsonResponse;

/**
 * Sözleşmedeki tek hata biçimi — `docs/03-api-sozlesmesi.md` §1.2.
 *
 * Tüm API hataları bu tipe indirgenir; istemciler HTTP durum koduna değil
 * `error.code` alanına bakar. `message` doğrudan kullanıcıya gösterilebilir
 * Türkçe metindir.
 */
class ApiException extends Exception
{
    /** @param array<string, mixed>|null $details */
    public function __construct(
        public readonly string $errorCode,
        string $message,
        public readonly int $status,
        public readonly ?array $details = null,
    ) {
        parent::__construct($message);
    }

    public function render(): JsonResponse
    {
        return new JsonResponse([
            'error' => array_filter([
                'code' => $this->errorCode,
                'message' => $this->getMessage(),
                'details' => $this->details,
            ], static fn($value): bool => $value !== null),
        ], $this->status, [], JSON_UNESCAPED_UNICODE);
    }

    public static function unauthenticated(
        string $message = 'Oturum bulunamadı, tekrar giriş yapın.',
    ): self {
        return new self('UNAUTHENTICATED', $message, 401);
    }

    public static function forbidden(
        string $message = 'Bu uca erişim yetkiniz yok.',
    ): self {
        return new self('FORBIDDEN', $message, 403);
    }

    public static function deviceRevoked(): self
    {
        return new self(
            'DEVICE_REVOKED',
            'Bu cihazın yetkisi iptal edilmiş. Yönetici ile görüşün.',
            403,
        );
    }

    public static function notFound(string $message = 'Kayıt bulunamadı.'): self
    {
        return new self('NOT_FOUND', $message, 404);
    }

    /** @param array<string, mixed>|null $details */
    public static function validationFailed(string $message, ?array $details = null): self
    {
        return new self('VALIDATION_FAILED', $message, 422, $details);
    }

    public static function invalidTransition(string $from, string $to, string $reason): self
    {
        return new self('INVALID_TRANSITION', $reason, 422, [
            'from' => $from,
            'to' => $to,
        ]);
    }

    public static function locationClosed(
        string $message = 'Şu anda sipariş alınmıyor.',
    ): self {
        return new self('LOCATION_CLOSED', $message, 422);
    }

    public static function itemUnavailable(string $message, int $menuId): self
    {
        return new self('ITEM_UNAVAILABLE', $message, 422, ['menu_id' => $menuId]);
    }

    public static function serverError(
        string $message = 'Beklenmeyen bir hata oluştu.',
    ): self {
        return new self('SERVER_ERROR', $message, 500);
    }
}
