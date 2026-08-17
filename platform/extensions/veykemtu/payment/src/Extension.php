<?php

declare(strict_types=1);

namespace Veykemtu\Payment;

use Igniter\System\Classes\BaseExtension;
use Illuminate\Support\Facades\Route;
use Override;
use Veykemtu\Payment\Http\Controllers\SimulationController;
use Veykemtu\Payment\Http\Controllers\SubscriptionSimulationController;
use Veykemtu\Payment\Payments\CashPayment;
use Veykemtu\Payment\Payments\PaymentGateway;
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
        ];
    }

    /**
     * Siparişsiz tahsilat geçidinin bağı — **"tek sınıf değişecek" sözü bu satır.**
     *
     * Abonelik dönem ödemesini kuran denetleyiciler somut sınıfı hiç anmaz,
     * `PaymentGateway` arayüzünü ister. Kuveyt Türk sözleşmesi tamamlandığında
     * burada `SimulatedPos::class` yerine `KuveytTurk::class` yazılır ve başka
     * hiçbir dosya değişmez. Somut sınıf denetleyicilerde `new` ile
     * kurulsaydı bu söz iki dosyada birden yalan olurdu.
     *
     * BAĞ ORTAMA GÖRE KALDIRILMIYOR: `SimulatedPos` üretimde kendini zaten
     * reddediyor (`assertAllowed`). Bağı koşullu yapsaydık üretimde ödeme ucu
     * "geçit bulunamadı" diye 500 dönerdi — teşhis edilmesi, açık ve gürültülü
     * bir "simülasyon üretimde kapalıdır" hatasından çok daha zor bir arıza.
     */
    #[Override]
    public function register(): void
    {
        // `parent::register()` ŞART: taban sınıf global scope'ları ve morph
        // haritasını orada kuruyor. Atlanırsa eklenti sessizce yarım açılır.
        parent::register();

        $this->app->bind(PaymentGateway::class, static fn(): SimulatedPos => new SimulatedPos);
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

            // Cari borç ödemesi rotaları (`/cari-odeme-simulasyon/{hash}`)
            // kaldırıldı — cari hesap iş modelinden çıktı. Akışın
            // devralınmaya değer iskeleti (niyet → hash → dönüş adresi →
            // çift geri-arama koruması) `docs/control/_devralinan-odeme-yapisi.md`
            // dosyasına çıkarıldı; abonelik ödemesi ORADAN KURULDU:

            /*
             * ÜÇÜNCÜ ROTA — abonelik dönem ödemesi.
             *
             * Sipariş ödemesiyle aynı adrese konmadı: orada bir siparişin
             * bedeli tahsil edilip sipariş `processed` işaretleniyor, burada
             * ortada sipariş yok. Tek adrese iki anlam yüklemek, dönüş
             * adresinden yazıcı tetiğine kadar her adımda "bu hangisiydi"
             * dallanması demekti.
             */
            Route::get('/abonelik-odeme-simulasyon/{hash}', [SubscriptionSimulationController::class, 'show'])
                ->name('veykemtu.payment.subscription_simulation');
            Route::post('/abonelik-odeme-simulasyon/{hash}', [SubscriptionSimulationController::class, 'process']);
        });
    }
}
