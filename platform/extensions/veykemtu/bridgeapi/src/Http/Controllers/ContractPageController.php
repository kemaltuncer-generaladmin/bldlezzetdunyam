<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers;

use Illuminate\Contracts\View\View;
use Illuminate\Http\Response;
use Illuminate\Routing\Controller;
use Veykemtu\BridgeApi\Models\SubscriptionContract;
use Veykemtu\BridgeApi\Services\ContractService;
use Veykemtu\BridgeApi\Support\SignedLink;

/**
 * Aboneye SMS ile giden sözleşme sayfası — sunucuda çizilir.
 *
 * NEDEN HTML, JSON DEĞİL: bunu açan şey bir istemci uygulaması değil,
 * abonenin SMS'teki bağlantıya dokunan telefonu. Onaylayan kişi çoğu zaman
 * uygulamayı hiç kurmamış olan satın alma yetkilisidir. Emsali
 * `DeliveryConfirmController`.
 *
 * SINIF ADI VE METOT ADI `routes/web.php`'DEN GELİR — rota dosyası sabittir,
 * denetleyici ona uyar. Üstelik `class_exists()` nöbetçisi yüzünden ad
 * tutmazsa rota hiç kaydedilmez ve sayfa sessizce 404 olur.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * DURUM KODLARI API'DEN BİLEREK FARKLI:
 *
 * | Durum              | Sayfa | `GET /api/contracts/{token}` |
 * |--------------------|-------|------------------------------|
 * | Kurcalanmış imza   | 403   | 404                          |
 * | Süresi dolmuş      | 410   | 200 + `status: expired`      |
 *
 * Sebep, iki kapının farklı şeyler yapması: API bir İSTEMCİYE konuşuyor ve o
 * istemci "süresi doldu, yenisini isteyin" cümlesini kurabilmeli, yani gövde
 * almalı. Sayfa ise doğrudan insana konuşuyor ve tarayıcı geçmişinde,
 * paylaşılan bağlantılarda, arama motorlarında doğru semantiği taşımalı:
 * `410 Gone` "bu adres vardı, artık yok" demek ve bir daha taranmamasını
 * sağlıyor.
 * ─────────────────────────────────────────────────────────────────────────
 *
 * SAYFANIN KENDİ POST'U YOK. İki yazma adımı (kod iste, onayla) donmuş
 * sözleşmedeki uçlara gidiyor; aynı işi ikinci kez yazsaydık oran sınırı ve
 * OTP deneme sayacı ikiye bölünür, kodu sayfadan deneyen biri API bütçesine
 * hiç dokunmazdı.
 */
class ContractPageController extends Controller
{
    private const string VIEW = 'veykemtu.bridgeapi::subscription.contract';

    public function __construct(private readonly ContractService $contracts) {}

    public function show(int $contract, int $expires, string $signature): Response|View
    {
        /*
         * İMZA ÖNCE, VERİTABANI SONRA. Sıra ters olsaydı var olmayan
         * sözleşme ile imzası bozuk sözleşme farklı yanıt verir, elinde
         * bağlantı olmayan biri kimlik numaralarını tarayabilirdi
         * (`PublicTrackingController` ile aynı disiplin).
         */
        if (!SignedLink::verify(SignedLink::PURPOSE_CONTRACT, $contract, $expires, $signature)) {
            return $this->fail('invalid', 403);
        }

        if (SignedLink::isExpired($expires)) {
            return $this->fail('expired', 410);
        }

        $token = $contract.'-'.$expires.'-'.$signature;
        $model = $this->contracts->find($token);

        /*
         * KAYIT YOK ya da ÖZET TUTMUYOR (bağlantı yenilenmiş, eskisi ölü).
         * İkisi de `403`: imzası doğru ama karşılığı olmayan bir bağlantıyı
         * "bulunamadı" diye ayırmak, hangi kimliklerin var olduğunu
         * söylerdi.
         */
        if (!$model instanceof SubscriptionContract) {
            return $this->fail('invalid', 403);
        }

        // Kayıt üzerinden ikinci bir süre denetimi: `expires_at` imzadaki
        // andan farklı olamaz (özet ikisini birden bağlıyor) ama sözleşme
        // iptal edilmiş olabilir.
        return view(self::VIEW, [
            'state' => $this->stateOf($model),
            'contract' => $this->contracts->apiPayload($model),
            'bodyHtml' => (string) $model->body_html,
            'token' => $token,
            'approvedName' => $model->approved_full_name,
        ]);
    }

    private function stateOf(SubscriptionContract $model): string
    {
        return match ($model->effectiveStatus()) {
            SubscriptionContract::STATUS_APPROVED => 'approved',
            SubscriptionContract::STATUS_CANCELLED => 'cancelled',
            SubscriptionContract::STATUS_EXPIRED => 'expired',
            default => 'sign',
        };
    }

    /**
     * Metinsiz hata hâlleri.
     *
     * Sözleşme verisi YOK — imza doğrulanamadığı için hangi sözleşme olduğunu
     * bilmiyoruz ve tahmin etmeye çalışmak tam da engellemek istediğimiz şey.
     */
    private function fail(string $state, int $status): Response
    {
        return response()->view(self::VIEW, [
            'state' => $state,
            'contract' => null,
            'bodyHtml' => '',
            'token' => '',
            'approvedName' => null,
        ], $status);
    }
}
