<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Models\SubscriptionPayment;
use Veykemtu\BridgeApi\Services\SubscriptionLifecycle;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\Payment\Payments\PaymentGateway;
use Veykemtu\Payment\Payments\PaymentIntentResult;

/**
 * Abonelik dönem ödemesi uçları — `docs/openapi.yaml` §Ödeme.
 *
 * AYRI DENETLEYİCİ, `SubscriptionController`'A EKLENMEDİ: oradaki `store`
 * ABONELİK açıyor, buradaki `store` ÖDEME başlatıyor (gerekçe
 * `routes/api.php`'de, ödeme rotalarının başında).
 *
 * TUTAR İSTEKTE GÖNDERİLMEZ — ne yolda ne gövdede. Dönem tutarı sunucuda
 * hesaplanır (`SubscriptionLifecycle::quote`); istemciden alınsaydı,
 * arada bir gün atlandığında ekrandaki tutar ile gerçek tutar ayrışır ve
 * abone eksik ödeyip "kapattım" sanırdı.
 */
class SubscriptionPaymentController extends ApiController
{
    /** Bir ödemeye yapılabilecek yanlış kod denemesi. */
    private const int MAX_CODE_ATTEMPTS = 3;

    /** Deneme sayacının ömrü — bir ödeme oturumundan uzun tutmanın anlamı yok. */
    private const int ATTEMPT_TTL_SECONDS = 1800;

    public function __construct(
        private readonly SubscriptionLifecycle $lifecycle,
        private readonly PaymentGateway $gateway,
    ) {}

    /**
     * Yürürlükteki dönem için ödeme başlatır.
     *
     * Aynı dönem için açık bir niyet varsa YENİSİ YARATILMAZ ve mevcut kayıt
     * 200 ile döner (sözleşme böyle diyor). İkinci bir kayıt açsaydık geri
     * dönüp tekrar deneyen abone iki niyet bırakır, ikisi de sağlayıcıda ayrı
     * ayrı yaşar ve biri gecikmeli başarıya dönerse aynı dönem iki kez tahsil
     * edilirdi.
     */
    public function store(Request $request, int $subscription): JsonResponse
    {
        $model = $this->owned($request, $subscription);

        $this->assertPayable($model);
        $this->assertRenewalWindow($model);

        $periodStart = $this->lifecycle->nextPeriodStart($model);
        $quote = $this->lifecycle->quote($model, $periodStart);

        if ($quote['portions'] < 1) {
            throw ApiException::validationFailed(
                'Bu dönemde servis günü yok; ödenecek bir tutar oluşmuyor.',
                ['period_start' => $quote['start']->toDateString()],
            );
        }

        $existing = SubscriptionPayment::query()
            ->where('subscription_id', $model->id)
            ->whereDate('period_start', $quote['start']->toDateString())
            ->first();

        if ($existing !== null && $existing->isSucceeded()) {
            throw ApiException::validationFailed('Bu dönem zaten ödendi.', [
                'period' => $existing->period(),
            ]);
        }

        if ($existing !== null && $existing->isPending()) {
            return $this->json($this->present($existing, $this->pendingAction($existing)));
        }

        /*
         * BAŞARISIZ NİYET YENİDEN AÇILIR, İKİNCİSİ YAZILMAZ.
         *
         * `UNIQUE(subscription_id, period_start)` ikinci satırı zaten
         * engelliyor; kartı reddedilen aboneye "bu dönem için bir daha
         * deneyemezsiniz" demek ise ödemeyi imkânsız kılardı. Aynı satır
         * TAZE bir `hash` ile yeniden `pending` doğar — eski adres ölür,
         * eski doğrulama kodu geçersizleşir.
         */
        $payment = $existing ?? new SubscriptionPayment;
        $payment->subscription_id = (int) $model->id;
        $payment->period_start = $quote['start']->toDateString();
        $payment->period_end = $quote['end']->toDateString();
        $payment->portions_planned = $quote['portions'];
        $payment->unit_price_kurus = $quote['unit_price'];
        $payment->amount_kurus = $quote['amount'];
        $payment->status = SubscriptionPayment::STATUS_PENDING;
        // 32 bayt rastgele: adres tahmin edilerek başkasının ödeme sayfası
        // açılamamalı. Sıralı `id` bu yüzden dışarı verilmiyor.
        $payment->hash = bin2hex(random_bytes(16));
        $payment->gateway = null;
        $payment->provider_ref = null;
        $payment->settled_at = null;
        $payment->created_at = BusinessTime::forStorage(BusinessTime::now());
        $payment->save();

        Cache::forget($this->attemptKey($payment));

        $intent = $this->gateway->createIntent($payment->amount_kurus, $payment->hash);

        $payment->gateway = $intent->gateway;
        $payment->save();

        // `none` dalında sağlayıcı aynı çağrıda karar verdi; sonucu
        // beklemeye bırakmak, hiç gelmeyecek bir geri-aramayı sonsuza kadar
        // yoklayan istemci demekti.
        if ($intent->result !== null) {
            $this->lifecycle->settle($payment, $intent->result);
            $payment->refresh();
        }

        return $this->json(
            $this->present($payment, $intent->nextAction, $intent->redirectUrl),
            201,
        );
    }

    /**
     * Ödemenin güncel hâli.
     *
     * `bld-order` kovasında DEĞİL (rota dosyası): sözleşme istemciye sonucu
     * yoklamasını söylüyor ve 20/saatlik yazma bütçesi tek bir ödemenin
     * yoklamasında biterdi.
     */
    public function show(Request $request, int $subscription, int $payment): JsonResponse
    {
        $model = $this->owned($request, $subscription);
        $record = $this->paymentOf($model, $payment);

        return $this->json($this->present($record, $this->pendingAction($record)));
    }

    /**
     * Ödemeyi doğrulama koduyla onaylar (`next_action = otp`).
     *
     * Yanlış kod DENEMEYİ TÜKETİR. Sınırsız deneme, çalınan bir kartın
     * kodunu aramanın önünü açardı. Hak bittiğinde ödeme `failed` kapanır ve
     * abone yeni bir ödeme başlatır.
     *
     * SAYAÇ ŞEMADA DEĞİL, ÖNBELLEKTE: deneme hakkı ödeme oturumu kadar
     * yaşayan geçici bir sayıdır, denetim izi değil. Şemaya sütun eklemek onu
     * kalıcı bir olguya çevirir ve "kaç kez denedi" sorusu ödeme kaydının
     * anlamını bulandırırdı.
     */
    public function confirm(Request $request, int $subscription, int $payment): JsonResponse
    {
        $model = $this->owned($request, $subscription);
        $record = $this->paymentOf($model, $payment);

        $data = $request->validate([
            'code' => ['required', 'string', 'min:4', 'max:8'],
        ]);

        if (!$record->isPending()) {
            throw ApiException::validationFailed('Bu ödeme onay bekleyen durumda değil.', [
                'status' => (string) $record->status,
            ]);
        }

        $key = $this->attemptKey($record);
        $attempts = (int) Cache::get($key, 0);

        if ($attempts >= self::MAX_CODE_ATTEMPTS) {
            $this->failPayment($record, 'Doğrulama hakkınız doldu. Yeni bir ödeme başlatın.');

            throw ApiException::validationFailed(
                'Doğrulama hakkınız doldu. Yeni bir ödeme başlatın.',
                ['status' => (string) $record->status],
            );
        }

        // Geçit `reference` alanını okuyor; gerçek sağlayıcıda o alan
        // geri-arama gövdesinde kendi adıyla gelir, burada kayıttan konuyor.
        $request->merge(['reference' => (string) $record->hash]);

        $result = $this->gateway->handleCallback($request);

        if (!$result->success) {
            $attempts++;
            Cache::put($key, $attempts, self::ATTEMPT_TTL_SECONDS);

            if ($attempts >= self::MAX_CODE_ATTEMPTS) {
                $this->failPayment($record, (string) $result->failureReason);
            }

            throw ApiException::validationFailed((string) $result->failureReason, [
                'code' => 'Kalan deneme: '.max(0, self::MAX_CODE_ATTEMPTS - $attempts),
            ]);
        }

        $this->lifecycle->settle($record, $result);
        Cache::forget($key);

        return $this->json($this->present($record->refresh(), PaymentIntentResult::ACTION_NONE));
    }

    // ── Yardımcılar ─────────────────────────────────────────────────────

    /**
     * Aboneliği getirir; başkasınınsa "yok" der (404).
     *
     * Sipariş deseninin aynısı: varlığını sızdırmamak için 403 değil 404.
     */
    private function owned(Request $request, int $id): Subscription
    {
        /** @var ApiCustomer $customer */
        $customer = $request->user();

        $subscription = Subscription::query()
            ->where('id', $id)
            ->where('customer_id', $customer->customer_id)
            ->with(['lines', 'delivery_points', 'pauses', 'exceptions'])
            ->first();

        if ($subscription === null) {
            throw ApiException::notFound('Abonelik bulunamadı.');
        }

        return $subscription;
    }

    /**
     * Ödemeyi getirir ve ABONELİĞE BAĞINI DOĞRULAR.
     *
     * Yol yapısı (`subscriptions/{id}/payments/{paymentId}`) tek savunma
     * değildir: bağ burada da denetlenmezse başka bir abonenin ödeme
     * kimliğini kendi aboneliğinin altına yazan bir istek komşu kaydı okurdu.
     */
    private function paymentOf(Subscription $subscription, int $paymentId): SubscriptionPayment
    {
        $payment = SubscriptionPayment::query()
            ->where('id', $paymentId)
            ->where('subscription_id', $subscription->id)
            ->first();

        if ($payment === null) {
            throw ApiException::notFound('Ödeme bulunamadı.');
        }

        return $payment;
    }

    /** Ödeme başlatılabilir mi? */
    private function assertPayable(Subscription $subscription): void
    {
        if ($subscription->status === Subscription::STATUS_CANCELLED) {
            throw ApiException::validationFailed('İptal edilmiş abonelik için ödeme alınmaz.', [
                'status' => (string) $subscription->status,
            ]);
        }

        if ($subscription->agreed_unit_price_kurus === null) {
            throw ApiException::validationFailed(
                'Aboneliğin fiyatı henüz belirlenmedi; ödeme başlatılamaz.',
                ['agreed_unit_price' => null],
            );
        }
    }

    /**
     * Yürürlükteki dönem ödenmişse, YENİLEME PENCERESİNE kadar yeni ödeme
     * açılmaz.
     *
     * Pencere olmasaydı bu uç her çağrıldığında bir sonraki dönemi açardı ve
     * abone on iki dönemi peşin ödeyebilirdi; iptal geldiğinde geriye elle
     * iade edilecek bir yığın kalırdı. Pencerenin genişliği ve ikinci
     * gerekçesi `SubscriptionPayment::RENEWAL_WINDOW_DAYS` notunda.
     */
    private function assertRenewalWindow(Subscription $subscription): void
    {
        /** @var SubscriptionPayment|null $current */
        $current = SubscriptionPayment::query()
            ->where('subscription_id', $subscription->id)
            ->where('status', SubscriptionPayment::STATUS_SUCCEEDED)
            ->orderByDesc('period_end')
            ->first();

        if ($current === null || !$current->covers(BusinessTime::now())) {
            return;
        }

        if (BusinessTime::today() >= $current->renewableFrom()) {
            return;
        }

        throw ApiException::validationFailed('Bu dönem zaten ödendi.', [
            'period' => $current->period(),
            'renewable_from' => $current->renewableFrom(),
        ]);
    }

    private function failPayment(SubscriptionPayment $payment, string $reason): void
    {
        $payment->status = SubscriptionPayment::STATUS_FAILED;
        $payment->settled_at = BusinessTime::forStorage(BusinessTime::now());
        $payment->save();

        Cache::forget($this->attemptKey($payment));
        Cache::put($this->failureKey($payment), $reason, self::ATTEMPT_TTL_SECONDS);
    }

    /**
     * Kayıtlı bir ödemenin SIRADAKİ ADIMI.
     *
     * Kesinleşmiş ya da kapanmış ödemede `none` — kullanıcı ikinci kez
     * doğrulama ekranına gönderilmemeli. Bekleyen ödemede `otp`: bugünkü tek
     * geçit ek adım gerekmeyen ödemeyi ANINDA kesinleştiriyor, yani `pending`
     * kalmış bir kayıt tanımı gereği kod bekliyor. Gerçek POS `three_ds`
     * üretmeye başladığında bu türetme yerini sağlayıcıdan gelen adıma
     * bırakacak; sözleşme zaten "bilmediğin adımı görürsen yoklamaya düş"
     * diyor.
     */
    private function pendingAction(SubscriptionPayment $payment): string
    {
        return $payment->isPending()
            ? PaymentIntentResult::ACTION_OTP
            : PaymentIntentResult::ACTION_NONE;
    }

    private function attemptKey(SubscriptionPayment $payment): string
    {
        return 'bld:abonelik-odeme:deneme:'.$payment->hash;
    }

    private function failureKey(SubscriptionPayment $payment): string
    {
        return 'bld:abonelik-odeme:hata:'.$payment->hash;
    }

    /**
     * Sözleşmedeki `SubscriptionPayment` gövdesi.
     *
     * `status` DIŞARIYA `paid` DİYE ÇIKAR: sözleşmedeki `PaymentStatus`
     * dağarcığı `pending|paid`, veritabanınınki `pending|succeeded|failed|
     * refunded`. İkisini eşitlemek için sözleşmeyi değiştirmek, bugün
     * sahadaki istemcileri kırardı; tabloyu değiştirmek ise devralınan
     * yapının dağarcığından sapmak olurdu. Çeviri tek satırda, tek yerde.
     *
     * @return array<string, mixed>
     */
    private function present(
        SubscriptionPayment $payment,
        string $nextAction,
        ?string $redirectUrl = null,
    ): array {
        return [
            'payment_id' => (int) $payment->id,
            'subscription_id' => (int) $payment->subscription_id,
            'period' => $payment->period(),
            'period_start' => $payment->period_start->toDateString(),
            'period_end' => $payment->period_end->toDateString(),
            'portions' => (int) $payment->portions_planned,
            'unit_price' => (int) $payment->unit_price_kurus,
            'amount' => (int) $payment->amount_kurus,
            'currency' => 'TRY',
            'status' => self::wireStatus((string) $payment->status),
            'next_action' => $nextAction,
            'redirect_url' => $redirectUrl,
            'failure_reason' => $payment->status === SubscriptionPayment::STATUS_FAILED
                ? (string) Cache::get($this->failureKey($payment), 'Ödeme tamamlanamadı.')
                : null,
            'created_at' => self::ts($payment->created_at),
            'paid_at' => $payment->isSucceeded() ? self::ts($payment->settled_at) : null,
        ];
    }

    /** Veritabanı dağarcığı → sözleşme dağarcığı. */
    public static function wireStatus(string $status): string
    {
        return $status === SubscriptionPayment::STATUS_SUCCEEDED ? 'paid' : $status;
    }
}
