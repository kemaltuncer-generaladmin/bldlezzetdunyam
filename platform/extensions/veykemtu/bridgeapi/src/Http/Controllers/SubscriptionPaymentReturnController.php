<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers;

use Illuminate\Contracts\View\View;
use Illuminate\Http\Response;
use Illuminate\Routing\Controller;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Models\SubscriptionPayment;
use Veykemtu\BridgeApi\Support\Money;

/**
 * Sanal POS'un aboneyi geri bıraktığı iki sayfa — sonuç ve iptal.
 *
 * NEDEN HTML, JSON DEĞİL: bu adresleri açan şey bir istemci uygulaması
 * değil, sağlayıcının tarayıcıda yaptığı yönlendirme. Emsalleri
 * `DeliveryConfirmController` ve `ContractPageController`: ikisi de sistemde
 * hesabı olmayan birinin telefonunda açılan, sunucuda çizilen sayfalar.
 *
 * SINIF ADI VE İKİ METOT ADI `routes/web.php`'DEN GELİR — rota dosyası
 * sabittir, denetleyici ona uyar. Üstelik oradaki `class_exists()` nöbetçisi
 * yüzünden ad tutmazsa rota HİÇ KAYDEDİLMEZ: sayfa hata vermez, sessizce
 * yok olur.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * BU SAYFALAR HİÇBİR DURUMU DEĞİŞTİRMEZ. Tamamı okumadır.
 *
 * Devralınan yapının en pahalı dersi (`docs/control/_devralinan-odeme-
 * yapisi.md` §5): mutabakat SAĞLAYICININ GERİ-ARAMASINDA olur, kullanıcının
 * döndüğü sayfada değil. Dönüş adresi güvenilmez bir kanaldır — abone geri
 * tuşuna basar, sayfayı yeniler, bağlantıyı paylaşır. Burada tek satır
 * yazsaydık her yenileme ikinci bir tahsilat denemesi, her paylaşılan
 * bağlantı başkasının aboneliğini ilerleten bir düğme olurdu. Yazan tek yer
 * `SubscriptionLifecycle::settle()`.
 *
 * Sonuç: sayfayı iki kez açmak da, yüz kez açmak da aynı ekranı üretir.
 * ─────────────────────────────────────────────────────────────────────────
 *
 * DIŞA KİMLİK `hash` (devralınan yapı §3): sıralı `id` adreste görünseydi
 * komşu numaralar denenerek başkasının ödeme sonucu okunurdu. Bilinmeyen
 * hash 404 alır ve 404 sayfası ödeme hakkında TEK KELİME söylemez.
 *
 * ÖN YÜZE BAĞLANTI YOK — bilinçli. Ödeme akışı SMS'teki sözleşme
 * bağlantısından da başlayabiliyor; o aboneyi `FRONTEND_URL` altındaki bir
 * hesap sayfasına göndermek, hiç girmediği bir hesabın kapısına bırakmak
 * olurdu. Sayfa bu yüzden kendi kendine yeter: ne olduğunu, aboneliğin
 * hangi durumda olduğunu ve ne yapılacağını kendi içinde söyler.
 */
class SubscriptionPaymentReturnController extends Controller
{
    private const string VIEW = 'veykemtu.bridgeapi::subscription.payment_return';

    /**
     * Sağlayıcı işi bitirdi — niyetin BUGÜNKÜ hâli gösterilir.
     *
     * Gösterilen durum ödemenin kendi kaydından okunur, adresten değil:
     * sağlayıcı "başarılı" diyerek bu adrese bıraksa bile geri-araması
     * henüz işlenmemiş olabilir ve o an doğru cevap "beklemede"dir. Adresteki
     * iddiaya inansaydık, kesinleşmemiş bir tahsilatı abone "ödendi" diye
     * görür ve mutfaktan yemek beklerdi.
     */
    public function showResult(string $hash): Response|View
    {
        $payment = $this->byHash($hash);

        if ($payment === null) {
            return $this->unknown();
        }

        return $this->render($payment, self::stateOf($payment));
    }

    /**
     * Abone ödemeden vazgeçti.
     *
     * NİYET `pending` KALIR, İPTAL EDİLMEZ. `failed` yazsaydık abone aynı
     * dönem için ikinci bir denemeye başladığında niyet TAZE bir `hash` ile
     * yeniden doğardı (`SubscriptionPaymentController::store`) — yani
     * sağlayıcıda hâlâ yaşayabilecek eski işlem numarasını kendi elimizle
     * kayıttan düşürmüş olurduk. Vazgeçmek bir sonuç değil, sonucun
     * gelmemesidir.
     *
     * Abonelik de olduğu yerde kalır: sözleşmesi onaylanmış ama ödemesi
     * beklenen abonelik `pending`dir (`SubscriptionLifecycle` §onContract-
     * Approved — "ödeme bekliyor" ayrı bir durum DEĞİL, ödeme kaydının
     * kendisinde duran bir bilgi).
     */
    public function showCancelled(string $hash): Response|View
    {
        $payment = $this->byHash($hash);

        if ($payment === null) {
            return $this->unknown();
        }

        /*
         * KAYIT NE DİYORSA O GÖSTERİLİR. İptal adresi geri-aramadan SONRA da
         * açılabilir: abone ödemeyi tamamlar, sonuç sayfasında geri tuşuna
         * basar ve sağlayıcının iptal adresine düşer. O anda "vazgeçtiniz"
         * demek, alınmış bir parayı alınmamış göstermek olurdu.
         */
        if (!$payment->isPending()) {
            return $this->render($payment, self::stateOf($payment));
        }

        return $this->render($payment, 'cancelled');
    }

    // ── Yardımcılar ─────────────────────────────────────────────────────

    private function byHash(string $hash): ?SubscriptionPayment
    {
        /** @var SubscriptionPayment|null */
        return SubscriptionPayment::query()
            ->where('hash', $hash)
            ->with('subscription')
            ->first();
    }

    /** Veritabanı dağarcığı → sayfanın hâli. */
    private static function stateOf(SubscriptionPayment $payment): string
    {
        return match ((string) $payment->status) {
            SubscriptionPayment::STATUS_SUCCEEDED => 'succeeded',
            SubscriptionPayment::STATUS_FAILED => 'failed',
            SubscriptionPayment::STATUS_REFUNDED => 'refunded',
            default => 'pending',
        };
    }

    private function render(SubscriptionPayment $payment, string $state): View
    {
        /** @var Subscription|null $subscription */
        $subscription = $payment->subscription;

        return view(self::VIEW, [
            'state' => $state,
            'period' => $payment->period_start->format('d.m.Y')
                .' – '.$payment->period_end->format('d.m.Y'),
            'amount' => self::lira((int) $payment->amount_kurus),
            // Tutarın nereden geldiği ekranda duruyor: devralınan yapıdaki
            // `balance_at_start` ile aynı gerekçe — "neden bu kadar ödedim"
            // sorusu sayfayı kapatmadan cevaplanabilmeli.
            'portions' => (int) $payment->portions_planned,
            'unitPrice' => self::lira((int) $payment->unit_price_kurus),
            'subscriptionState' => $subscription === null
                ? null
                : (string) $subscription->status,
            /*
             * Yenileme bağlantısı ADLANDIRILMIŞ ROTADAN çözülür, elle
             * birleştirilmez: adres bir gün değişirse burası da onunla
             * değişsin. Yalnız `pending` hâlinde çiziliyor — oran sınırı
             * (20/dk/ödeme) tam da bu yenilemeyi karşılamak için cömert.
             */
            'refreshUrl' => route(
                'veykemtu.bridgeapi.subscription_payment_result',
                ['hash' => (string) $payment->hash],
            ),
        ]);
    }

    /**
     * Bulunamayan hash.
     *
     * ÖDEME VERİSİ YOK ve olmamalı: hangi hash'in karşılığı olduğunu
     * söylemek, adres tahmin ederek dönem/tutar taramanın önünü açardı.
     * Kendi 404 sayfamız çiziliyor çünkü sağlayıcıdan dönen aboneye
     * vitrinin genel "sayfa bulunamadı" ekranı hiçbir şey anlatmaz
     * (`ContractPageController::fail()` emsali).
     */
    private function unknown(): Response
    {
        return response()->view(self::VIEW, [
            'state' => 'unknown',
            'period' => null,
            'amount' => null,
            'portions' => 0,
            'unitPrice' => null,
            'subscriptionState' => null,
            'refreshUrl' => null,
        ], 404);
    }

    private static function lira(int $kurus): string
    {
        return number_format(Money::toDecimal($kurus), 2, ',', '.');
    }
}
