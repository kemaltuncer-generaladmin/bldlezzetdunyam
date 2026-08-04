<?php

declare(strict_types=1);

namespace Veykemtu\Payment;

use Igniter\System\Classes\BaseExtension;
use Illuminate\Support\Facades\Route;
use Override;
use Veykemtu\Payment\Http\Controllers\SimulationController;
use Veykemtu\Payment\Payments\AccountPayment;
use Veykemtu\Payment\Payments\CashPayment;
use Veykemtu\Payment\Payments\SimulatedPos;

/**
 * BLD Ödeme eklentisi.
 *
 * Faz 1'de yalnızca **simülasyon** geçidi var; gerçek tahsilat yapmaz
 * (`SimulatedPos` sınıfının başındaki uyarıya bakın).
 *
 * Kuveyt Türk sözleşmesi tamamlandığında buraya `Payments/KuveytTurk.php`
 * eklenir ve `registerPaymentGateways()` listesine girer. Simülasyon
 * silinmez — geliştirme ve staging'de kullanılmaya devam eder. Hangisinin
 * müşteriye görüneceğini vitrinin `payment_methods` listesi belirler
 * (`docs/03-api-sozlesmesi.md` §3).
 */
class Extension extends BaseExtension
{
    #[Override]
    public function registerPaymentGateways(): array
    {
        return [
            SimulatedPos::class => [
                'code' => SimulatedPos::CODE,
                'name' => 'Online ödeme (SİMÜLASYON — gerçek tahsilat yok)',
                'description' => 'Sanal POS entegrasyonu tamamlanana kadar '.
                    'online ödeme akışını test etmek için. Girilen her kartı onaylar.',
            ],
            CashPayment::class => [
                'code' => CashPayment::CODE,
                'name' => 'Kapıda ödeme',
                'description' => 'Tahsilat teslimatta yapılır; yazılım tahsilat yapmaz.',
            ],
            AccountPayment::class => [
                'code' => AccountPayment::CODE,
                'name' => 'Cari hesap',
                'description' => 'Kurumsal müşteri cari hesabına işlenir; yazılım tahsilat yapmaz.',
            ],
        ];
    }

    #[Override]
    public function boot(): void
    {
        $this->registerSimulationRoutes();
    }

    /**
     * Simülasyon sayfası rotaları.
     *
     * `web` middleware grubu bilinçli: sayfa bir HTML formudur ve CSRF
     * koruması gerekir. API rotalarımız (durumsuz, token'lı) bundan ayrı
     * bir dünyada yaşar.
     *
     * Üretimde simülasyon kapalıysa rotalar HİÇ kaydedilmez — kapalı bir
     * geçide giden bir adres bırakmak, ileride yanlışlıkla açılmasının
     * en kolay yoludur.
     */
    private function registerSimulationRoutes(): void
    {
        if (!SimulatedPos::isAllowed()) {
            return;
        }

        Route::middleware('web')->group(function (): void {
            Route::get('/odeme-simulasyon/{hash}', [SimulationController::class, 'show'])
                ->name('veykemtu.payment.simulation');
            Route::post('/odeme-simulasyon/{hash}', [SimulationController::class, 'process']);
        });
    }
}
