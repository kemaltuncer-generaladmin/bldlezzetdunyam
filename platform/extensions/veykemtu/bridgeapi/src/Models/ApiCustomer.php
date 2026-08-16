<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\User\Models\Customer;
use Laravel\Sanctum\HasApiTokens;

/**
 * API token taşıyabilen müşteri.
 *
 * NEDEN ALT SINIF: Sanctum'un guard'ı `Guard::supportsTokens()` ile
 * tokenable modelde `HasApiTokens` trait'ini arar; yoksa kimlik doğrulama
 * sessizce `null` döner. TastyIgniter'ın `Customer` modelinde bu trait yok
 * ve çekirdeğe trait eklemek ADR-02 ihlali olurdu.
 *
 * Çözüm: aynı tabloyu kullanan bir alt sınıf. Token'lar
 * `tokenable_type = ApiCustomer::class` ile saklanır, Sanctum bu sınıfı
 * çözer ve `instanceof Customer` her yerde doğru kalır.
 *
 * `credit_limit_lira` erişimcileri cari hesapla birlikte kaldırıldı;
 * dayandıkları `bld_credit_limit_kurus` kolonu artık yok
 * (`2026_08_20_000002_drop_account_tables`).
 */
class ApiCustomer extends Customer
{
    use HasApiTokens;

    /** Kapsam adı — `docs/03-api-sozlesmesi.md` ADR-08. */
    public const string SCOPE = 'customer';

    protected $table = 'customers';
}
