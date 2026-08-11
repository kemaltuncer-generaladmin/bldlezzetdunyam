<?php

declare(strict_types=1);

namespace Veykemtu\Payment\Refunds;

use Igniter\Cart\Models\Order;
use Override;

/**
 * Cari hesaplı siparişin iadesi — para hareketi YOK, defter kaydı var.
 *
 * Kurumsal müşteri ay sonunda ödüyor; sipariş küçüldüğünde yapılacak şey
 * para göndermek değil, borcu azaltmaktır. Bunu `OrderEditor` cari
 * deftere ters kayıt yazarak yapıyor; bu sınıf yalnızca "iade tamamlandı,
 * ayrıca yapılacak bir şey yok" der.
 *
 * NEDEN YİNE DE BİR GEÇİT: iade kayıtları tek tabloda toplansın ve
 * "bu siparişin iadesi ne oldu" sorusu ödeme yöntemine bakmadan
 * cevaplanabilsin diye.
 */
class AccountRefund implements RefundGateway
{
    public const string CODE = 'account';

    #[Override]
    public function refund(Order $order, int $amountKurus, string $reason): RefundResult
    {
        return RefundResult::succeeded('cari-defter');
    }

    #[Override]
    public function code(): string
    {
        return self::CODE;
    }
}
