<?php

declare(strict_types=1);

namespace Veykemtu\Payment\Payments;

use Igniter\Cart\Models\Order;
use Igniter\PayRegister\Classes\BasePaymentGateway;
use Igniter\PayRegister\Models\Payment;
use Illuminate\Http\Request;
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
 *
 * İKİ AYRI ŞAPKA TAKIYOR ve bu bilinçli:
 *
 *  - `BasePaymentGateway` — bir SİPARİŞİN bedelini tahsil eder (Faz 1).
 *  - `PaymentGateway` — siparişsiz tahsilat: abonelik dönem ödemesi (Faz 3).
 *
 * Ayrı sınıfa bölünmedi çünkü ikisi de AYNI sağlayıcının aynı sanal POS'u.
 * Bölseydik "simülasyon açık mı" bayrağı, referans öneki ve tahsilat
 * yapılmadığını söyleyen günlük satırı iki yerde yaşardı; biri açık biri
 * kapalı kaldığı gün üretimde bedava sipariş çıkardı.
 */
class SimulatedPos extends BasePaymentGateway implements PaymentGateway
{
    // Kod sözleşmedeki değerle BİREBİR aynı. TastyIgniter `orders.payment`
    // alanını `payments.code` ile eşleştirir; ayrı bir eşleme tablosu
    // tutmak yerine tek kelime dağarcığı kullanıyoruz.
    public const string CODE = 'online';

    /** Simüle edilmiş her ödeme bu önekle işaretlenir; denetimde ayırt edilir. */
    public const string REFERENCE_PREFIX = 'SIM-';

    /**
     * Bu tutardan itibaren ek doğrulama (OTP) istenir — 500,00 TL.
     *
     * Gerçek POS'ta bu eşik BANKADADIR ve bize sorulmaz; simülasyonda bir
     * eşik kullanmanın tek sebebi, `none` ve `otp` dallarının İKİSİNİN de
     * elle ve testle koşturulabilmesi. Rastgele seçseydik aynı istek iki kez
     * farklı akış üretir, istemci geliştiricisi hangi ekranı yazdığını
     * bilemezdi.
     */
    public const int OTP_THRESHOLD_KURUS = 50_000;

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

    // ── Siparişsiz tahsilat (`PaymentGateway`) ──────────────────────────

    /**
     * Abonelik dönem ödemesi için niyet açar.
     *
     * Küçük tutarda ek adım yok ve sağlayıcı aynı çağrıda onaylıyor; eşiğin
     * üstünde kod isteniyor. Gerekçe [OTP_THRESHOLD_KURUS] notunda.
     */
    public function createIntent(int $amountKurus, string $reference): PaymentIntentResult
    {
        self::assertAllowed();

        if ($amountKurus < self::OTP_THRESHOLD_KURUS) {
            return PaymentIntentResult::settled(
                PaymentResult::succeeded(self::CODE, $reference, self::newProviderRef()),
            );
        }

        /*
         * SİMÜLASYONDA KOD SMS İLE GİTMEZ.
         *
         * Gerçek akışta kodu banka üretip aboneye yollar; biz yalnız
         * iletiriz. Burada üretecek bir banka yok, o yüzden kod
         * referanstan TÜRETİLİYOR ([expectedCode]) ve günlüğe yazılıyor:
         * istemci geliştiricisi ile testin kodu bulabildiği tek yer burası.
         * Rastgele üretip saklasaydık şemaya yalnız simülasyonun kullandığı
         * bir sütun eklemek gerekirdi.
         */
        Log::warning('SİMÜLASYON: abonelik ödemesi doğrulama kodu bekliyor.', [
            'reference' => $reference,
            'code' => self::expectedCode($reference),
            'amount_kurus' => $amountKurus,
            'env' => config('app.env'),
        ]);

        return PaymentIntentResult::otp(self::CODE);
    }

    /**
     * Sağlayıcı bildirimi — hem simülasyon sayfasının formu hem API'nin
     * OTP onay ucu buradan geçer.
     *
     * `reference` alanını ÇAĞIRAN koyar: simülasyon sayfası yol parçasından,
     * API ucu ödeme kaydından. Gerçek sağlayıcıda bu alan geri-arama
     * gövdesinde kendi adıyla gelir ve çevirisi yine burada yapılır — bir
     * adaptörün işi tam olarak budur.
     */
    public function handleCallback(Request $request): PaymentResult
    {
        self::assertAllowed();

        $reference = (string) $request->input('reference', '');
        $code = trim((string) $request->input('code', ''));

        // Kod GÖNDERİLDİYSE doğrulanır. Gönderilmemesi "kod istenmiyordu"
        // demektir (kart formu dalı); istenip istenmediğine karar veren yer
        // `createIntent` ve o karar çağıranın elinde.
        if ($code !== '' && !hash_equals(self::expectedCode($reference), $code)) {
            return PaymentResult::failed(
                self::CODE,
                $reference,
                'Doğrulama kodu hatalı.',
            );
        }

        Log::warning('SİMÜLASYON: abonelik ödemesi onaylandı — gerçek tahsilat YOK.', [
            'reference' => $reference,
            'env' => config('app.env'),
        ]);

        return PaymentResult::succeeded(self::CODE, $reference, self::newProviderRef());
    }

    /**
     * Referanstan türetilen 6 haneli doğrulama kodu — YALNIZ SİMÜLASYON.
     *
     * Kriptografik bir gizlilik iddiası yoktur ve olmamalı: gerçek POS'ta
     * kodu banka üretir. Burada tek istenen, aynı ödeme için her çağrıda
     * aynı kodun çıkması.
     */
    public static function expectedCode(string $reference): string
    {
        $sayi = (int) hexdec(substr(hash('sha256', self::REFERENCE_PREFIX.$reference), 0, 8));

        return str_pad((string) ($sayi % 1_000_000), 6, '0', STR_PAD_LEFT);
    }

    private static function newProviderRef(): string
    {
        return self::REFERENCE_PREFIX.strtoupper(bin2hex(random_bytes(6)));
    }
}
