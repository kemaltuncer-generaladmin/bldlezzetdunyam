<?php

declare(strict_types=1);

namespace Veykemtu\Payment\Refunds;

/**
 * Bir iade denemesinin sonucu.
 *
 * DÖRT DURUM, ÜÇÜ DEĞİL: `manual` ile `pending` ayrı. `pending` "sağlayıcı
 * işliyor, bekle" demek; `manual` "yazılım bir şey yapmadı, birinin elle
 * yapması gerekiyor" demek. İkisini birleştirmek, kimsenin yapmadığı bir
 * iadenin sonsuza kadar "işleniyor" görünmesine yol açardı.
 */
final class RefundResult
{
    private function __construct(
        public readonly string $status,
        public readonly ?string $providerRef = null,
        public readonly ?string $message = null,
    ) {}

    public const string SUCCEEDED = 'succeeded';

    public const string PENDING = 'pending';

    /** Yazılım tahsilat/iade yapmıyor; kayıt açıldı, insan tamamlayacak. */
    public const string MANUAL = 'manual';

    public const string FAILED = 'failed';

    public static function succeeded(?string $providerRef = null): self
    {
        return new self(self::SUCCEEDED, $providerRef);
    }

    public static function pending(?string $providerRef = null): self
    {
        return new self(self::PENDING, $providerRef);
    }

    public static function manual(string $message): self
    {
        return new self(self::MANUAL, null, $message);
    }

    public static function failed(string $message): self
    {
        return new self(self::FAILED, null, $message);
    }

    public function isFailure(): bool
    {
        return $this->status === self::FAILED;
    }
}
