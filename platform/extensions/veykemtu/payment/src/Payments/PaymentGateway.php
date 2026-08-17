<?php

declare(strict_types=1);

namespace Veykemtu\Payment\Payments;

use Illuminate\Http\Request;

/**
 * Sipariş bağımsız tahsilat geçidi — abonelik dönem ödemesinin yüzü.
 *
 * ╔═══════════════════════════════════════════════════════════════════════╗
 * ║  BU ARAYÜZ TAM İKİ METOTTUR VE ÜÇÜNCÜSÜ EKLENMEZ.                     ║
 * ║                                                                       ║
 * ║  "Gerçek POS geldiğinde tek sınıf değişecek" cümlesi ancak bu kadar   ║
 * ║  dar bir yüzeyle GERÇEK olur. Üçüncü bir metot (kod yeniden gönder,   ║
 * ║  taksit sorgula, iade et...) eklendiği an her yeni sağlayıcı o        ║
 * ║  metodu da uygulamak zorunda kalır; uygulayamayan sağlayıcı için      ║
 * ║  arayüz "kısmen desteklenir" hâline gelir ve söz aspirasyona döner.   ║
 * ╚═══════════════════════════════════════════════════════════════════════╝
 *
 * `Igniter\PayRegister` geçitleriyle KARIŞTIRILMAMALI: onlar bir SİPARİŞİN
 * bedelini tahsil eder (`processPaymentForm($data, $host, $order)`) ve
 * siparişsiz çalışamaz. Abonelik dönem ödemesinde ortada tek bir sipariş
 * yoktur — ödenen şey 30 günlük bir sözleşme dilimidir. Bu ayrımın uzun
 * gerekçesi `docs/control/_devralinan-odeme-yapisi.md` §1'de.
 *
 * Bugün `SimulatedPos` uyguluyor; Kuveyt Türk sözleşmesi tamamlandığında
 * yanına `KuveytTurk` eklenir ve kapsayıcı bağı (`Veykemtu\Payment\Extension`)
 * tek satırda değişir.
 */
interface PaymentGateway
{
    /**
     * Tahsilat niyetini açar ve SIRADAKİ ADIMI söyler.
     *
     * Burada para tahsil edilmez — `next_action = none` dalında sağlayıcı
     * aynı çağrıda karar verdiyse sonuç `PaymentIntentResult::$result`
     * içinde gelir, aksi hâlde niyet açık kalır ve sonucu `handleCallback()`
     * bildirir.
     *
     * @param  int  $amountKurus  Tam sayı kuruş; her zaman pozitif.
     * @param  string  $reference  Bizim tarafımızın tanımlayıcısı (ödeme `hash`'i).
     *                             Geri-arama gövdesinde geri döner ve hangi
     *                             ödemenin bildirildiğini söyleyen tek alandır.
     */
    public function createIntent(int $amountKurus, string $reference): PaymentIntentResult;

    /**
     * Sağlayıcıdan gelen bildirimi tek biçime çevirir.
     *
     * TEK METOT, İKİ ÇAĞIRAN: hem simülasyon sayfasının form gönderimi hem
     * de API'nin OTP onay ucu buradan geçer. Sonucu iki yerde ayrı ayrı
     * yorumlasaydık, sağlayıcı bir alanın anlamını değiştirdiğinde biri
     * güncellenir öbürü unutulurdu.
     *
     * **İdempotanslık ÇAĞIRANIN İŞİDİR.** Geçit "bu bildirim ne diyor"
     * sorusunu yanıtlar; "bu ödeme zaten kesinleşmiş miydi" sorusunu
     * veritabanı yanıtlar (`UNIQUE(subscription_id, period_start)` +
     * `status` denetimi).
     */
    public function handleCallback(Request $request): PaymentResult;
}
