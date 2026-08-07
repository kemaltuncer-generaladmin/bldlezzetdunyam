<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ApiCustomer;

/**
 * Müşteri tipi kapısı — B2B kararı (`docs/00-genel-bakis.md`).
 *
 * İş modeli kurumsala döndü: yalnızca kurumsal müşteri sipariş verebilir.
 * Ayrım `customers.bld_account_type` kolonundadır (`corporate | individual`);
 * `LocationGate`'in vitrin şalterlerini okuduğu gibi bu da müşteri tipini
 * okur — tek sorumluluk, tek yer.
 *
 * GRANDFATHER: kolon varsayılanı `corporate` olduğundan bugüne kadar kayıtlı
 * herkes kurumsal sayılır ve sipariş vermeye devam eder. Bu kapı yalnızca
 * admin panelden bilinçle `individual` işaretlenmiş bir hesabı durdurur —
 * yani mevcut hiçbir akışı kırmaz.
 */
final class CustomerGate
{
    public const string TYPE_CORPORATE = 'corporate';

    public const string TYPE_INDIVIDUAL = 'individual';

    /**
     * Müşteri kurumsal değilse siparişi reddeder.
     *
     * @throws ApiException FORBIDDEN — bireysel hesap.
     */
    public function assertCorporate(ApiCustomer $customer): void
    {
        if ($this->accountType($customer) !== self::TYPE_CORPORATE) {
            throw ApiException::forbidden(
                'Bireysel hesapla sipariş verilemez; kurumsal hesabınızla giriş yapın.',
            );
        }
    }

    /**
     * Müşterinin hesap tipi; kolon boşsa (teorik) kurumsal kabul edilir —
     * grandfather davranışının çalışma anındaki güvencesi.
     */
    public function accountType(ApiCustomer $customer): string
    {
        $type = $customer->getAttribute('bld_account_type');

        return is_string($type) && $type !== '' ? $type : self::TYPE_CORPORATE;
    }
}
