<?php

declare(strict_types=1);

namespace Veykemtu\Payment\Payments;

/**
 * Cari hesap. Kurumsal müşterinin hesabına işlenir, tahsilat sistem dışında.
 *
 * Kod sözleşmedeki `account` değeriyle birebir aynıdır.
 */
class AccountPayment extends OfflinePayment
{
    public const string CODE = 'account';
}
