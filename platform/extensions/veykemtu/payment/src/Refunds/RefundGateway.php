<?php

declare(strict_types=1);

namespace Veykemtu\Payment\Refunds;

use Igniter\Cart\Models\Order;

/**
 * İade geçidi — sağlayıcıdan bağımsız sözleşme (K-13).
 *
 * NEDEN ARAYÜZ: gerçek sanal POS henüz seçilmedi (`docs/11` §10 açık
 * madde). Sipariş düzenleme iadesiz çalışamaz; iade de olmayan bir
 * sağlayıcıyı bekleyemez. Arayüz, düzenleme akışının bugün bitmesini ve
 * sağlayıcı seçildiğinde **tek bir sınıf** eklenerek bağlanmasını
 * sağlıyor.
 *
 * NEDEN "SİMÜLASYON" DEĞİL DE "MANUEL" VARSAYILAN: simülasyon her iadeyi
 * başarılı gösterir. Canlıda bu, gerçekte yapılmamış bir iadeyi
 * "tamamlandı" olarak kaydetmek demektir — müşteri parasını beklerken
 * sistem işi bitmiş sanır. Manuel sürücü işi `pending` bırakır ve birinin
 * gerçekten yapmasını bekler.
 */
interface RefundGateway
{
    /**
     * Kısmi ya da tam iade başlatır.
     *
     * @param  int  $amountKurus  Pozitif tutar (kuruş).
     */
    public function refund(Order $order, int $amountKurus, string $reason): RefundResult;

    /** Bu geçidin `veykemtu_payment_refunds.gateway` sütununa yazılan adı. */
    public function code(): string;
}
