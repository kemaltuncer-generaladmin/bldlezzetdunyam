<?php

declare(strict_types=1);

namespace Veykemtu\Payment\Payments;

use Igniter\Cart\Models\Order;
use Igniter\PayRegister\Classes\BasePaymentGateway;
use Igniter\PayRegister\Models\Payment;
use Override;

/**
 * Sistem dışında tahsil edilen ödemeler — kapıda ödeme ve cari hesap.
 *
 * NEDEN GEÇİT OLARAK VAR: bu yöntemlerde yazılımın yapacağı bir tahsilat
 * yok; para kapıda alınıyor ya da cari hesaba işleniyor. Yine de
 * TastyIgniter'da bir `payments` kaydı olmaları gerekiyor, çünkü
 * `orders.payment` alanı `payments.code` ile eşleşir. Kayıt yoksa
 * `Order::$payment_method` ilişkisi `null` döner ve ödeme günlüğü
 * "property on null" ile patlar.
 *
 * Kodlar sözleşmedeki değerlerle **birebir aynıdır** (`cash`, `account`).
 * Ayrı bir eşleme tablosu tutmak yerine tek kelime dağarcığı kullanıyoruz;
 * admin panelinde de doğru isim görünür.
 *
 * Sipariş `payment.status = pending` kalır ve öyle kalmalıdır: para henüz
 * tahsil edilmemiştir. Tahsilat gerçekleşince yönetici admin panelden
 * siparişi ödendi işaretler.
 */
abstract class OfflinePayment extends BasePaymentGateway
{
    #[Override]
    public function defineFieldsConfig(): string
    {
        return 'veykemtu.payment::/models/offlinepayment';
    }

    /**
     * @param  array<string, mixed>  $data
     * @param  Payment  $host
     * @param  Order  $order
     */
    #[Override]
    public function processPaymentForm($data, $host, $order): void
    {
        // Kasten boş: tahsilat sistem dışında. Sipariş normal akışına
        // devam eder, ödeme durumu `pending` kalır.
        //
        // `markAsPaymentProcessed()` ÇAĞRILMAZ — çağırmak, alınmamış bir
        // parayı alınmış göstermek olurdu ve raporlar yalan söylerdi.
    }
}
