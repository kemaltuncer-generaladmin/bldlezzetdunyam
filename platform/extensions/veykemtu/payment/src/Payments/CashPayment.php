<?php

declare(strict_types=1);

namespace Veykemtu\Payment\Payments;

/**
 * Kapıda ödeme. Tahsilat teslimatta, elden yapılır.
 *
 * Kod sözleşmedeki `cash` değeriyle birebir aynıdır — `orders.payment`
 * doğrudan bu koda karşılık gelir, arada eşleme tablosu yoktur.
 */
class CashPayment extends OfflinePayment
{
    public const string CODE = 'cash';
}
