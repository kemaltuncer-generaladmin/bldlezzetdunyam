<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\User\Models\Customer;
use Laravel\Sanctum\HasApiTokens;
use Veykemtu\BridgeApi\Admin\LiraField;

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
 */
class ApiCustomer extends Customer
{
    use HasApiTokens;

    /** Kapsam adı — `docs/03-api-sozlesmesi.md` ADR-08. */
    public const string SCOPE = 'customer';

    protected $table = 'customers';

    /**
     * Admin formundaki TL alanı ↔ `bld_credit_limit_kurus` (B-14).
     *
     * ÜÇ DURUMU İKİYE İNDİRMEDEN taşır — ve bu, alanın en ince yeri:
     *
     *   ""    ↔ NULL  → limitsiz
     *   "0"   ↔ 0     → cari hesap kapalı
     *   "250" ↔ 25000 → 250 TL tavan
     *
     * `LiraField::toKurus('')` sıfır döndürüyor; onu doğrudan kullansaydık
     * "alanı boş bırakan yönetici limitsiz istiyor" ile "sıfır yazan yönetici
     * cariyi kapatmak istiyor" aynı sonuca varırdı. Boş girdi bu yüzden
     * dönüşümden önce ayrılıyor.
     *
     * Aynı desen `Subscription::agreed_price_lira`'da da var.
     */
    public function getCreditLimitLiraAttribute(): string
    {
        $kurus = $this->attributes['bld_credit_limit_kurus'] ?? null;

        return $kurus !== null ? LiraField::toInput((int) $kurus) : '';
    }

    public function setCreditLimitLiraAttribute(mixed $value): void
    {
        $this->attributes['bld_credit_limit_kurus'] = trim((string) $value) === ''
            ? null
            : max(0, LiraField::toKurus($value));
    }
}
