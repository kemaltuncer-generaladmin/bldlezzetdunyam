<?php

declare(strict_types=1);

namespace Veykemtu\Payment\Http\Controllers;

use Igniter\Cart\Models\Order;
use Igniter\PayRegister\Models\Payment;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\Log;
use Illuminate\View\View;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Veykemtu\Payment\Payments\SimulatedPos;

/**
 * Simülasyon ödeme sayfası — gerçek sanal POS'un yerini tutar.
 *
 * NEDEN AYRI SAYFA, NEDEN OTOMATİK ONAY DEĞİL:
 * Gerçek sanal POS akışı "sipariş oluştur → sağlayıcının sayfasına git →
 * kart gir → geri dön" şeklindedir. İstemciler (web ve mobil) bu
 * yönlendirme-ve-dönüş akışını uygulamak zorunda. Simülasyonu tek satırda
 * "ödendi" işaretlemek o akışı hiç yazdırmazdı ve Kuveyt Türk geldiğinde
 * web ile mobilin ikisi de baştan yazılırdı.
 *
 * Bu sayfa gerçek POS'un iskeletini taklit eder: kart formu, onay,
 * dönüş adresi. Sağlayıcı değişince yalnızca bu sayfa devre dışı kalır.
 */
class SimulationController extends Controller
{
    public function show(Request $request, string $hash): View
    {
        $order = $this->orderByHash($hash);

        return view('veykemtu.payment::simulation', [
            'order' => $order,
            'hash' => $hash,
            'returnUrl' => $this->returnUrl($request, $order),
            'total' => number_format((float) $order->order_total, 2, ',', '.'),
            'alreadyPaid' => (bool) $order->processed,
        ]);
    }

    public function process(Request $request, string $hash): RedirectResponse
    {
        SimulatedPos::assertAllowed();

        $order = $this->orderByHash($hash);
        $returnUrl = $this->returnUrl($request, $order);

        // Zaten ödenmiş siparişi ikinci kez işlemeyiz. Gerçek POS'ta da
        // callback iki kez gelebilir; idempotentlik oradan geliyor
        // (docs/04 §5) ve simülasyon aynı davranışı taklit etmeli.
        if ((bool) $order->processed) {
            return redirect()->away($returnUrl.'?durum=zaten_odendi');
        }

        $data = $request->validate([
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
        // Simülasyonda bile bu alışkanlığı koruyoruz; gerçek entegrasyonda
        // kart zaten sunucumuza uğramayacak.
        unset($data);

        $host = $this->paymentHost($order);

        // Geçit KENDİ Payment modeliyle kurulur. `new SimulatedPos` demek
        // BasePaymentGateway'i modelsiz bırakır ve içeride `$this->model->code`
        // okunurken "property on null" ile patlar.
        $gateway = new SimulatedPos($host);

        $gateway->processPaymentForm([], $host, $order);

        Log::warning('SİMÜLASYON: sipariş ödendi işaretlendi, para tahsil edilmedi.', [
            'order_id' => $order->order_id,
        ]);

        return redirect()->away($returnUrl.'?durum=odendi');
    }

    private function orderByHash(string $hash): Order
    {
        $order = Order::where('hash', $hash)->first();

        if ($order === null) {
            throw new NotFoundHttpException('Sipariş bulunamadı.');
        }

        return $order;
    }

    /**
     * Dönüş adresi.
     *
     * İstemci `?return=` ile verir. Açık yönlendirme (open redirect)
     * açığı olmaması için YALNIZCA yapılandırılmış ön yüz adresine izin
     * verilir; başka bir host verilirse yok sayılır.
     */
    private function returnUrl(Request $request, Order $order): string
    {
        $varsayilan = rtrim((string) config('app.frontend_url', env('FRONTEND_URL', '')), '/');
        $istenen = (string) $request->query('return', '');

        if ($istenen === '' || $varsayilan === '') {
            return $varsayilan !== ''
                ? $varsayilan.'/siparis/'.$order->order_id
                : url('/');
        }

        $izinliHost = parse_url($varsayilan, PHP_URL_HOST);
        $istenenHost = parse_url($istenen, PHP_URL_HOST);

        if ($izinliHost !== null && $izinliHost === $istenenHost) {
            return $istenen;
        }

        return $varsayilan.'/siparis/'.$order->order_id;
    }

    /**
     * Geçidin `payments` tablosundaki kaydı.
     *
     * Kayıt yoksa oluşturulur ve PASİF bırakılır: bir ödeme geçidini
     * kendiliğinden etkinleştirmek, yöneticinin görmediği bir ödeme
     * yönteminin müşteriye açılması demek olurdu. Simülasyonun API
     * üzerinden çalışması için kaydın var olması yeterli, aktif olması
     * gerekmiyor.
     */
    private function paymentHost(Order $order): Payment
    {
        $host = Payment::where('code', SimulatedPos::CODE)->first();

        if ($host !== null) {
            return $host;
        }

        $host = new Payment;
        $host->code = SimulatedPos::CODE;
        $host->name = 'Simülasyon POS (gerçek tahsilat yok)';
        $host->class_name = SimulatedPos::class;
        $host->status = false;
        $host->is_default = false;
        $host->save();

        return $host;
    }
}
