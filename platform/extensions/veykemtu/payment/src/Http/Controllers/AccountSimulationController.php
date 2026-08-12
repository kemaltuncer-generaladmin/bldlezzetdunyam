<?php

declare(strict_types=1);

namespace Veykemtu\Payment\Http\Controllers;

use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\View\View;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Veykemtu\BridgeApi\Models\AccountLedgerEntry;
use Veykemtu\BridgeApi\Models\AccountPaymentIntent;
use Veykemtu\BridgeApi\Services\AccountLedger;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\Payment\Payments\SimulatedPos;

/**
 * Cari borç ödeme simülasyonu — B-14 / W-12.
 *
 * `SimulationController`'ın kardeşi ama ayrı: o bir SİPARİŞİN bedelini
 * tahsil eder ve siparişi `processed` işaretler; bu ise birikmiş BAKİYEYİ
 * öder ve sonucu deftere bir alacak satırı olarak yazar. İkisini tek sınıfa
 * sıkıştırmak, her adımda "elimdeki hangisi" dallanması demekti.
 *
 * Gerçek sanal POS bağlandığında bu sayfa devre dışı kalır; değişmeyen
 * kısım niyet tablosu ve deftere yazma anıdır — sağlayıcı yalnızca
 * "başarılı/başarısız" bilgisini nereden aldığımızı değiştirir.
 */
class AccountSimulationController extends Controller
{
    public function show(Request $request, string $hash): View
    {
        $intent = $this->intentByHash($hash);

        return view('veykemtu.payment::account_simulation', [
            'intent' => $intent,
            'hash' => $hash,
            'returnUrl' => $this->returnUrl($request),
            'total' => number_format($intent->amount_kurus / 100, 2, ',', '.'),
            'alreadySettled' => !$intent->isPending(),
        ]);
    }

    public function process(Request $request, string $hash): RedirectResponse
    {
        SimulatedPos::assertAllowed();

        $intent = $this->intentByHash($hash);
        $returnUrl = $this->returnUrl($request);

        // Kesinleşmiş niyet ikinci kez işlenmez. Gerçek POS'ta callback iki
        // kez gelebiliyor (docs/04 §5); simülasyon aynı davranışı taklit
        // etmeli, yoksa istemciler bu duruma karşı yazılmaz.
        if (!$intent->isPending()) {
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

        // Kart verisi hiçbir yere yazılmaz — `SimulationController` ile aynı
        // kural, aynı gerekçe.

        /*
         * NİYET VE DEFTER TEK TRANSACTION'DA.
         *
         * İkisi ayrılsaydı ve arada süreç düşseydi iki bozuk sonuçtan biri
         * çıkardı: defter yazılıp niyet `pending` kalır (müşteri ikinci kez
         * ödemeye çalışır) ya da niyet `succeeded` olup defter boş kalır
         * (para alınmış görünür, borç durur). İkisi de elle onarım demek.
         *
         * Defterdeki `(payment, account_payment, id, credit)` tekil indeksi
         * ikinci kemer: transaction bir yarışta iki kez koşsa bile alacak
         * satırı bir kez yazılır.
         */
        DB::transaction(function () use ($intent): void {
            resolve(AccountLedger::class)->record(
                customerId: (int) $intent->customer_id,
                type: AccountLedgerEntry::TYPE_CREDIT,
                amountKurus: (int) $intent->amount_kurus,
                source: AccountLedgerEntry::SOURCE_PAYMENT,
                referenceType: AccountPaymentIntent::LEDGER_REFERENCE,
                referenceId: (int) $intent->id,
                description: 'Online cari ödeme #'.$intent->id,
                effectiveDate: BusinessTime::now(),
            );

            $intent->status = AccountPaymentIntent::STATUS_SUCCEEDED;
            $intent->gateway = SimulatedPos::CODE;
            $intent->settled_at = BusinessTime::forStorage(BusinessTime::now());
            $intent->save();
        });

        Log::warning('SİMÜLASYON: cari ödeme deftere işlendi, para tahsil edilmedi.', [
            'intent_id' => $intent->id,
            'customer_id' => $intent->customer_id,
            'amount_kurus' => $intent->amount_kurus,
        ]);

        return redirect()->away(self::withStatus($returnUrl, 'odendi'));
    }

    /**
     * Dönüş adresine `durum` parametresini ekler.
     *
     * `SimulationController::withStatus` ile aynı gerekçe (K-20): dönüş
     * adresi artık sorgu parametresi taşıyabiliyor ve düz birleştirme
     * ikinci bir `?` üretip `durum`u okunamaz kılıyordu.
     */
    private static function withStatus(string $url, string $durum): string
    {
        return $url.(str_contains($url, '?') ? '&' : '?').'durum='.$durum;
    }

    private function intentByHash(string $hash): AccountPaymentIntent
    {
        $intent = AccountPaymentIntent::where('hash', $hash)->first();

        if ($intent === null) {
            throw new NotFoundHttpException('Ödeme kaydı bulunamadı.');
        }

        return $intent;
    }

    /**
     * Dönüş adresi — açık yönlendirme (open redirect) açığına karşı yalnızca
     * yapılandırılmış ön yüz adresine izin verilir.
     *
     * `SimulationController::returnUrl` ile aynı kural; oradaki sipariş
     * bazlı varsayılan yerine burada cari sayfası kullanılıyor.
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

        return $varsayilan.'/hesabim/cari';
    }
}
