<?php

declare(strict_types=1);

namespace Veykemtu\Payment\Refunds;

use Igniter\Cart\Models\Order;
use Illuminate\Support\Facades\DB;

/**
 * Ödeme yöntemine göre doğru geçidi seçer ve sonucu kaydeder (K-13).
 *
 * SEÇİM ÖDEME YÖNTEMİNDEN TÜRÜYOR, yapılandırmadan değil: bir siparişin
 * parası nasıl alındıysa öyle iade edilir. Nakit alınan bir siparişi
 * sanal POS'tan iade etmek imkânsız; cari hesaplı bir siparişe para
 * göndermek de yanlış (borç azaltılmalı).
 *
 * `BLD_REFUND_DRIVER` yalnız **online** siparişler için geçerli: gerçek
 * sanal POS bağlandığında oraya yeni sürücünün adı yazılacak.
 */
class RefundManager
{
    /**
     * İadeyi yürütür ve `veykemtu_payment_refunds` satırını yazar.
     *
     * @param  int|null  $revisionId  Hangi revizyondan doğdu (K-12).
     */
    public function refund(
        Order $order,
        int $amountKurus,
        string $reason,
        ?int $revisionId = null,
    ): RefundResult {
        if ($amountKurus <= 0) {
            return RefundResult::succeeded('tutar-yok');
        }

        $gateway = $this->gatewayFor($order);
        $result = $gateway->refund($order, $amountKurus, $reason);

        // İADE HER ZAMAN KAYDEDİLİR — başarısız olsa bile. Başarısız bir
        // iadeyi kaydetmemek, onu görünmez kılar: müşteri parasını bekler,
        // kimse bir şey bilmez. Kayıt admin panelde açık durur.
        DB::table('veykemtu_payment_refunds')->insert([
            'order_id' => (int) $order->order_id,
            'revision_id' => $revisionId,
            'amount_kurus' => $amountKurus,
            'gateway' => $gateway->code(),
            'status' => $result->status,
            'provider_ref' => $result->providerRef,
            'error' => $result->isFailure() ? $result->message : null,
            'reason' => $reason,
            'created_at' => now(),
            'settled_at' => $result->status === RefundResult::SUCCEEDED ? now() : null,
        ]);

        return $result;
    }

    public function gatewayFor(Order $order): RefundGateway
    {
        return match ((string) $order->payment) {
            // Cari hesap: para hareketi yok, borç azalır.
            'account' => new AccountRefund(),
            // Online: yapılandırılmış sürücü. Gerçek sanal POS bağlanana
            // kadar simülasyon (ve o da üretimde kapalı).
            'online' => $this->onlineGateway(),
            // Nakit ve bilinmeyen: yazılım tahsilat yapmadı, iadeyi de
            // yapamaz.
            default => new ManualRefund(),
        };
    }

    private function onlineGateway(): RefundGateway
    {
        return match ((string) env('BLD_REFUND_DRIVER', 'simulated')) {
            'manual' => new ManualRefund(),
            default => new SimulatedRefund(),
        };
    }
}
