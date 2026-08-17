<?php

declare(strict_types=1);

namespace Veykemtu\Payment\Http\Controllers;

use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\Log;
use Illuminate\View\View;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Veykemtu\BridgeApi\Models\SubscriptionPayment;
use Veykemtu\BridgeApi\Services\SubscriptionLifecycle;
use Veykemtu\BridgeApi\Support\Money;
use Veykemtu\Payment\Payments\PaymentGateway;

/**
 * Abonelik dönem ödemesinin simülasyon sayfası — ÜÇÜNCÜ ROTA.
 *
 * NEDEN SİPARİŞ ÖDEMESİYLE AYNI ROTAYA KONMADI: sipariş akışı bir siparişin
 * bedelini tahsil eder ve siparişi `processed` işaretler; burada sipariş
 * yoktur, ödenen şey 30 günlük bir sözleşme dilimidir. Aynı rotaya iki anlam
 * yüklemek, dönüş adresinden yazıcı tetiğine kadar her adımda "bu hangisiydi"
 * dallanması demekti (`docs/control/_devralinan-odeme-yapisi.md` §6).
 *
 * MOBİL BU SAYFAYI KULLANMAZ. Simülasyon `next_action` olarak `none` ya da
 * `otp` üretiyor; ikisi de uygulamanın içinde çözülüyor, WebView yok. Bu
 * sayfa web vitrini ve gerçek POS'un 3D Secure dalı için duran iskelettir:
 * geri-arama gövdesini `PaymentGateway::handleCallback()`'e, sonucu
 * `SubscriptionLifecycle::settle()`'a veriyor — yani API'nin onay ucuyla
 * TAM AYNI mutabakat yolundan geçiyor.
 */
class SubscriptionSimulationController extends Controller
{
    public function __construct(
        private readonly SubscriptionLifecycle $lifecycle,
        private readonly PaymentGateway $gateway,
    ) {}

    public function show(Request $request, string $hash): View
    {
        $payment = $this->paymentByHash($hash);

        return view('veykemtu.payment::subscription_simulation', [
            'payment' => $payment,
            'hash' => $hash,
            'returnUrl' => $this->returnUrl($request),
            'total' => number_format(Money::toDecimal((int) $payment->amount_kurus), 2, ',', '.'),
            'period' => $payment->period_start->format('d.m.Y').' – '.$payment->period_end->format('d.m.Y'),
            'alreadySettled' => !$payment->isPending(),
        ]);
    }

    public function process(Request $request, string $hash): RedirectResponse
    {
        $payment = $this->paymentByHash($hash);
        $returnUrl = $this->returnUrl($request);

        // KATMAN 1'İN DIŞ KAPISI. Kesinleşmiş niyet ikinci kez işlenmez;
        // `settle()` de aynı kontrolü yapıyor ama kullanıcıya "zaten ödendi"
        // demek için burada da bakılıyor.
        if (!$payment->isPending()) {
            return redirect()->away(self::withStatus($returnUrl, 'zaten_odendi'));
        }

        $request->validate([
            'kart_no' => ['required', 'string', 'min:12', 'max:23'],
            'ad_soyad' => ['required', 'string', 'max:64'],
            'son_kullanma' => ['required', 'string', 'regex:#^\d{2}/\d{2}$#'],
            'cvv' => ['required', 'string', 'regex:/^\d{3,4}$/'],
        ], [
            'kart_no.required' => 'Kart numarası girin.',
            'son_kullanma.regex' => 'Son kullanma tarihi AA/YY biçiminde olmalı.',
            'cvv.regex' => 'CVV 3 veya 4 haneli olmalı.',
        ]);

        // Kart verisi HİÇBİR YERE yazılmaz — loga da, veritabanına da.
        // Gerçek entegrasyonda kart zaten sunucumuza uğramayacak; simülasyonda
        // da aynı alışkanlık korunuyor ki geçişte "kartı bir yere yazmıştık"
        // sürprizi çıkmasın.

        // Kart formu dalında kod sorulmuyor: `code` göndermemek geçide
        // "ek doğrulama istenmemişti" demektir.
        $request->merge(['reference' => (string) $payment->hash, 'code' => '']);

        $result = $this->gateway->handleCallback($request);

        $settled = $this->lifecycle->settle($payment, $result);

        Log::warning('SİMÜLASYON: abonelik dönem ödemesi işlendi, para tahsil edilmedi.', [
            'payment_id' => (int) $payment->id,
            'subscription_id' => (int) $payment->subscription_id,
            'amount_kurus' => (int) $payment->amount_kurus,
            'settled' => $settled,
        ]);

        return redirect()->away(self::withStatus($returnUrl, $settled ? 'odendi' : 'basarisiz'));
    }

    /**
     * Dönüş adresine `durum` parametresini ekler.
     *
     * Düz birleştirme yetmiyor (K-20): dönüş adresi sorgu parametresi
     * taşıyabiliyor ve ikinci bir `?` üretmek `durum`u okunamaz kılıyor.
     */
    private static function withStatus(string $url, string $durum): string
    {
        return $url.(str_contains($url, '?') ? '&' : '?').'durum='.$durum;
    }

    private function paymentByHash(string $hash): SubscriptionPayment
    {
        $payment = SubscriptionPayment::query()->where('hash', $hash)->first();

        if ($payment === null) {
            throw new NotFoundHttpException('Ödeme bulunamadı.');
        }

        return $payment;
    }

    /**
     * Dönüş adresi.
     *
     * AÇIK YÖNLENDİRME (open redirect) KAPISI: adres kullanıcıdan gelen bir
     * sorgu parametresidir; doğrulanmazsa ödeme sayfamız üçüncü bir siteye
     * yönlendirme aracına döner. YALNIZCA yapılandırılmış ön yüzün HOST'u
     * kabul edilir.
     */
    private function returnUrl(Request $request): string
    {
        $varsayilan = rtrim((string) config('app.frontend_url', env('FRONTEND_URL', '')), '/');
        $istenen = (string) $request->query('return', '');

        if ($varsayilan === '') {
            return url('/');
        }

        if ($istenen !== '') {
            $izinliHost = parse_url($varsayilan, PHP_URL_HOST);
            $istenenHost = parse_url($istenen, PHP_URL_HOST);

            if ($izinliHost !== null && $izinliHost === $istenenHost) {
                return $istenen;
            }
        }

        return $varsayilan.'/hesabim/abonelik';
    }
}
