<?php

declare(strict_types=1);

namespace Veykemtu\Payment\Payments;

use Igniter\Cart\Models\Order;
use Igniter\PayRegister\Classes\BasePaymentGateway;
use Igniter\PayRegister\Models\Payment;
use Illuminate\Support\Facades\Log;
use Override;
use RuntimeException;

/**
 * Simülasyon sanal POS'u — **gerçek tahsilat yapmaz.**
 *
 * Kuveyt Türk sağlayıcı sözleşmesi tamamlanana kadar, online ödeme akışının
 * uçtan uca geliştirilip test edilebilmesi için var. Girilen her kartı
 * onaylar.
 *
 * ╔═══════════════════════════════════════════════════════════════════════╗
 * ║  BU GEÇİT ÜRETİMDE AÇIK KALIRSA HER SİPARİŞ BEDAVA OLUR.              ║
 * ║                                                                       ║
 * ║  Bu yüzden `APP_ENV=production` iken, `POS_ALLOW_SIMULATION=true`     ║
 * ║  açıkça verilmedikçe ÇALIŞMAYI REDDEDER. Bayrağı açmak bilinçli bir   ║
 * ║  karardır ve loga "gerçek tahsilat yapılmadı" diye yazılır.           ║
 * ╚═══════════════════════════════════════════════════════════════════════╝
 *
 * Gerçek POS geldiğinde bu sınıf SİLİNMEZ — geliştirme ve staging'de
 * kullanılmaya devam eder. `KuveytTurk` sınıfı yanına eklenir ve vitrinin
 * `payment_methods` listesi hangisinin açık olacağını belirler.
 */
class SimulatedPos extends BasePaymentGateway
{
    // Kod sözleşmedeki değerle BİREBİR aynı. TastyIgniter `orders.payment`
    // alanını `payments.code` ile eşleştirir; ayrı bir eşleme tablosu
    // tutmak yerine tek kelime dağarcığı kullanıyoruz.
    public const string CODE = 'online';

    /** Simüle edilmiş her ödeme bu önekle işaretlenir; denetimde ayırt edilir. */
    public const string REFERENCE_PREFIX = 'SIM-';

    /**
     * Bu ortamda simülasyon kullanılabilir mi?
     *
     * Üretimde varsayılan HAYIR. Açmak için `POS_ALLOW_SIMULATION=true`.
     */
    public static function isAllowed(): bool
    {
        if (config('app.env') !== 'production') {
            return true;
        }

        return filter_var(
            env('POS_ALLOW_SIMULATION', false),
            FILTER_VALIDATE_BOOLEAN,
        );
    }

    /** @throws RuntimeException */
    public static function assertAllowed(): void
    {
        if (self::isAllowed()) {
            return;
        }

        throw new RuntimeException(
            'Simülasyon ödeme geçidi üretim ortamında kapalıdır. '.
            'Gerçek tahsilat yapmadan sipariş "ödendi" işaretlenemez.',
        );
    }

    #[Override]
    public function defineFieldsConfig(): string
    {
        return 'veykemtu.payment::/models/simulatedpos';
    }

    /**
     * Ödemeyi onaylar.
     *
     * Kart bilgisi **saklanmaz** — simülasyonda bile. Gerçek POS'ta kart
     * verisi zaten sunucumuza hiç uğramaz (sağlayıcının sayfasında girilir);
     * burada da aynı alışkanlığı koruyoruz ki gerçek entegrasyona geçerken
     * "kartı bir yere yazmıştık" sürprizi çıkmasın.
     *
     * @param  array<string, mixed>  $data
     * @param  Payment  $host
     * @param  Order  $order
     */
    #[Override]
    public function processPaymentForm($data, $host, $order): void
    {
        self::assertAllowed();

        $referans = self::REFERENCE_PREFIX.strtoupper(bin2hex(random_bytes(6)));

        // Denetim izi: bu siparişin parası GERÇEKTEN tahsil edilmedi.
        Log::warning('Simüle edilmiş ödeme onaylandı — gerçek tahsilat YOK.', [
            'order_id' => $order->order_id,
            'reference' => $referans,
            'total' => $order->order_total,
            'env' => config('app.env'),
        ]);

        $order->logPaymentAttempt(
            'Simüle ödeme onaylandı (GERÇEK TAHSİLAT YOK)',
            1,
            ['gateway' => self::CODE],
            ['reference' => $referans, 'simulated' => true],
            true,
        );

        $order->updateOrderStatus($host->order_status, ['notify' => false]);
        $order->markAsPaymentProcessed();
    }
}
