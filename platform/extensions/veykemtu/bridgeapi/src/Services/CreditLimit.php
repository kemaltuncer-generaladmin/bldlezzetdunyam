<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ApiCustomer;

/**
 * Cari hesap borç limiti kuralı — B-14.
 *
 * TEK YERDE, ÇÜNKÜ ÜÇ YERDEN SORULUYOR: sipariş oluşturulurken
 * (`OrderFactory`), ödeme yöntemleri listelenirken (müşteriye `account`
 * gösterilecek mi) ve panelden telefon siparişi girilirken. Üç ayrı `if`
 * yazılsaydı, biri güncellenip diğerleri unutulduğunda kural sessizce
 * delinirdi.
 *
 * ÜÇ DURUM (migration 2026_08_13_000001):
 *   0     → cari hesap KAPALI (yeni hesapların varsayılanı)
 *   n > 0 → borç n kuruşu aşamaz
 *   NULL  → sınırsız; göç öncesinden gelen müşteriler ve bilinçli seçim
 *
 * KONTROL SİPARİŞ ÖNCESİ YAPILIR, SONRASI DEĞİL: borç deftere yazıldıktan
 * sonra bakmak, limiti aşan siparişi zaten kabul etmiş olmak demektir.
 * Kontrol "mevcut bakiye + bu siparişin tutarı" üzerinden yapılır.
 */
final class CreditLimit
{
    public function __construct(private readonly AccountLedger $ledger) {}

    /**
     * Müşteri cari hesapla ödeyebilir mi? (limit 0 ise hayır)
     *
     * Tutar verilirse "bu tutarı da eklersek limiti aşar mı" sorusuna cevap
     * verir; verilmezse yalnızca cari hesabın açık olup olmadığına bakar —
     * ödeme yöntemi listesini çizerken sepet tutarı henüz bilinmiyor olabilir.
     */
    public function allows(ApiCustomer $customer, int $additionalKurus = 0): bool
    {
        $limit = $customer->bld_credit_limit_kurus;

        if ($limit === null) {
            return true;
        }

        $limit = (int) $limit;

        if ($limit === 0) {
            return false;
        }

        return $this->ledger->balance((int) $customer->customer_id) + $additionalKurus <= $limit;
    }

    /**
     * Limit aşılıyorsa siparişi durdurur.
     *
     * Hata mesajı RAKAM İÇERİR (kalan limit): "limitiniz doldu" diyen bir
     * uyarı, müşteriye ne kadar ödemesi gerektiğini söylemez ve telefonla
     * sormaya zorlar.
     *
     * @throws ApiException
     */
    public function assertAllows(ApiCustomer $customer, int $additionalKurus): void
    {
        if ($this->allows($customer, $additionalKurus)) {
            return;
        }

        $limit = (int) ($customer->bld_credit_limit_kurus ?? 0);

        if ($limit === 0) {
            throw ApiException::validationFailed(
                'Bu hesap için cari hesap (veresiye) tanımlı değil.',
                ['payment_method' => 'Cari hesap açılması için yönetimle görüşün.'],
            );
        }

        $balance = $this->ledger->balance((int) $customer->customer_id);

        throw ApiException::validationFailed(
            'Cari hesap limiti aşılıyor.',
            [
                'payment_method' => 'Bu sipariş cari hesap limitinizi aşıyor.',
                'credit_limit_kurus' => $limit,
                'balance_kurus' => $balance,
                'remaining_kurus' => max(0, $limit - $balance),
            ],
        );
    }

    /**
     * Kalan borçlanma alanı (kuruş). Sınırsız limitte `null` döner.
     *
     * Müşteri arayüzü bunu "kalan limitiniz" olarak gösteriyor; `null`
     * geldiğinde hiç göstermiyor — "sınırsız" yazmak, yöneticinin bilerek
     * verdiği bir ayrıcalığı müşteriye ilan etmek olurdu.
     */
    public function remaining(ApiCustomer $customer): ?int
    {
        $limit = $customer->bld_credit_limit_kurus;

        if ($limit === null) {
            return null;
        }

        return max(0, (int) $limit - $this->ledger->balance((int) $customer->customer_id));
    }
}
