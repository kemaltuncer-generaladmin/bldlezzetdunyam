<?php

declare(strict_types=1);

namespace Veykemtu\Payment\Refunds;

use Igniter\Cart\Models\Order;
use Override;
use Veykemtu\Payment\Payments\SimulatedPos;

/**
 * Simülasyon iadesi — `SimulatedPos` ile aynı korumaya tabidir.
 *
 * Üretimde `POS_ALLOW_SIMULATION=true` olmadan çalışmaz ve o durumda
 * `failed` döner. Sessizce "başarılı" demek, gerçekte hiç yapılmamış bir
 * iadeyi tamamlanmış göstermek olurdu — müşteri parasını beklerken
 * sistemde iş bitmiş görünürdü.
 */
class SimulatedRefund implements RefundGateway
{
    public const string CODE = 'simulated';

    #[Override]
    public function refund(Order $order, int $amountKurus, string $reason): RefundResult
    {
        if (!SimulatedPos::isAllowed()) {
            return RefundResult::failed(
                'Simülasyon iadesi bu ortamda kapalı. Gerçek sanal POS '
                .'bağlanana kadar iade elle yapılmalı.',
            );
        }

        return RefundResult::succeeded('sim-'.$order->order_id.'-'.$amountKurus);
    }

    #[Override]
    public function code(): string
    {
        return self::CODE;
    }
}
