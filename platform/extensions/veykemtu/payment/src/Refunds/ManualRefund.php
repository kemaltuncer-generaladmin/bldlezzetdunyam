<?php

declare(strict_types=1);

namespace Veykemtu\Payment\Refunds;

use Igniter\Cart\Models\Order;
use Override;

/**
 * Yazılımın para hareketi yapmadığı iade — kapıda ödeme ve sağlayıcısız
 * kurulum için varsayılan (K-13).
 *
 * Kayıt açar ve `manual` bırakır: birinin gerçekten para iade etmesi
 * gerekiyor ve admin panelde "yapıldı" işaretlenene kadar açık duruyor.
 * "Başarılı" demek, yapılmamış bir iadeyi tamamlanmış göstermek olurdu.
 */
class ManualRefund implements RefundGateway
{
    public const string CODE = 'manual';

    #[Override]
    public function refund(Order $order, int $amountKurus, string $reason): RefundResult
    {
        return RefundResult::manual(
            'Tutar elden/havale ile iade edilmeli; admin panelden '
            .'"yapıldı" işaretlenecek.',
        );
    }

    #[Override]
    public function code(): string
    {
        return self::CODE;
    }
}
