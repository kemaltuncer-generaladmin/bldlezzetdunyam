<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ClosedDay;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Models\SubscriptionPayment;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\Payment\Payments\PaymentResult;

/**
 * Abonelik yaşam döngüsü — durumu değiştiren TEK yer.
 *
 * ```
 * pending --sözleşme onaylandı--> pending (ödeme bekleniyor)
 *         --ilk ödeme başarılı--> active
 * active  --ödenmiş dönem doldu--> paused   (gece denetlenir, GÜRÜLTÜLÜ uyarır)
 * paused  --yeni dönem ödendi---> active
 * ```
 *
 * NEDEN TEK GEÇİŞ FONKSİYONU: aboneliği `active` yapan üç ayrı çağıran var
 * (sözleşme onayı, ödeme mutabakatı, Kontrol Merkezi'nden elle
 * aktifleştirme). Her biri `status = 'active'` yazsaydı, "ödeme almadan
 * aktifleştirme" kuralı üç yerde ayrı ayrı yaşar ve biri unutulduğu gün
 * bedava abonelik çıkardı. Durum burada değişir, başka hiçbir yerde.
 *
 * `SubscriptionGenerateCommand` zaten `status = active` süzüyor; yani bu
 * sınıfın izin vermediği hiçbir şey mutfağa düşmez.
 */
final class SubscriptionLifecycle
{
    /** Sözleşme onaylandı — abonelik ödeme bekliyor, HÂLÂ `pending`. */
    public const string EVENT_CONTRACT_APPROVED = 'contract_approved';

    /** Dönem ödemesi kesinleşti. Aboneliği `active` yapan tek olay. */
    public const string EVENT_PAYMENT_SETTLED = 'payment_settled';

    /** Ödenmiş dönem doldu, yenisi gelmedi. */
    public const string EVENT_PERIOD_LAPSED = 'period_lapsed';

    /** Kontrol Merkezi'nden elle aktifleştirme (para dışı bir yönetici kararı). */
    public const string EVENT_MANUAL_ACTIVATION = 'manual_activation';

    /**
     * ABONELİĞİN DURUMUNU DEĞİŞTİREN TEK FONKSİYON.
     *
     * İzinsiz geçişte 422 atar; izinli ama durumu zaten hedefte olan geçişte
     * sessizce aynı kaydı döner (yinelenen geri-arama ikinci kez çağırabilir
     * ve bu bir hata değildir).
     *
     * @throws ApiException Geçiş bu durumdan yapılamıyorsa.
     */
    public function transition(Subscription $subscription, string $event): Subscription
    {
        $from = (string) $subscription->status;

        $to = match ($event) {
            self::EVENT_CONTRACT_APPROVED => $this->onContractApproved($from),
            self::EVENT_PAYMENT_SETTLED => $this->onPaymentSettled($from),
            self::EVENT_PERIOD_LAPSED => $this->onPeriodLapsed($from),
            self::EVENT_MANUAL_ACTIVATION => $this->onManualActivation($from),
            default => throw ApiException::validationFailed(
                'Bilinmeyen abonelik olayı.',
                ['event' => $event],
            ),
        };

        if ($to === $from) {
            return $subscription;
        }

        $subscription->status = $to;
        $subscription->save();

        Log::info('Abonelik durumu değişti.', [
            'subscription_id' => (int) $subscription->id,
            'event' => $event,
            'from' => $from,
            'to' => $to,
        ]);

        return $subscription;
    }

    /**
     * Ödeme mutabakatı — sonucu kaydeder ve aboneliği ilerletir.
     *
     * TEK NOKTA, İKİ ÇAĞIRAN (API'nin OTP onay ucu ve simülasyon sayfasının
     * form gönderimi). Ayrı ayrı yazılsaydı çift geri-arama koruması
     * birinde olup öbüründe olmayabilirdi.
     *
     * ÇİFT GERİ-ARAMA KORUMASI İKİ KATMAN — devralınan yapının en pahalı
     * öğrenilmiş dersi (`docs/control/_devralinan-odeme-yapisi.md` §5):
     *   1. `status` denetimi: kesinleşmiş niyet ikinci kez işlenmez;
     *   2. `UNIQUE(subscription_id, period_start)`: 1. katman bir yarışta
     *      delinse bile aynı dönem için ikinci bir satır YAZILAMAZ.
     *
     * Niyet ile aboneliğin durumu TEK İŞLEMDE değişir. Ayrılsalardı ve arada
     * süreç düşseydi ya para alınmış görünüp abonelik `pending` kalırdı
     * (abone ikinci kez öder) ya da abonelik `active` olup ödeme kaydı
     * `pending` kalırdı (dönem sonu denetimi onu hemen duraklatırdı).
     *
     * @return bool Bu çağrı ödemeyi kesinleştirdiyse `true`; zaten
     *              kesinleşmişse ya da başarısızsa `false`.
     */
    public function settle(SubscriptionPayment $payment, PaymentResult $result): bool
    {
        // KATMAN 1. Kesinleşmiş (ya da kapanmış) niyet ikinci kez işlenmez.
        // Gerçek POS'ta geri-arama iki kez gelebiliyor; simülasyon aynı
        // davranışı taklit etmeli, yoksa istemciler buna karşı yazılmaz.
        if (!$payment->isPending()) {
            return false;
        }

        if (!$result->success) {
            $payment->status = SubscriptionPayment::STATUS_FAILED;
            $payment->gateway = $result->gateway;
            $payment->settled_at = BusinessTime::forStorage(BusinessTime::now());
            $payment->save();

            return false;
        }

        DB::transaction(function () use ($payment, $result): void {
            $payment->status = SubscriptionPayment::STATUS_SUCCEEDED;
            $payment->gateway = $result->gateway;
            $payment->provider_ref = $result->providerRef;
            $payment->settled_at = BusinessTime::forStorage(BusinessTime::now());
            $payment->save();

            /** @var Subscription|null $subscription */
            $subscription = Subscription::query()->find($payment->subscription_id);

            if ($subscription !== null) {
                $this->transition($subscription, self::EVENT_PAYMENT_SETTLED);
            }
        });

        return true;
    }

    /**
     * Aboneliğin ödenmiş dönemi verilen günü kapsıyor mu?
     *
     * ÖDEME KAYDI HİÇ YOKSA `true` DÖNER ve bu bilinçlidir: ödeme kaydı
     * olmayan bir abonelik Kontrol Merkezi'nden elle aktifleştirilmiştir
     * (kurumsal anlaşma, deneme dönemi, cutover öncesi kayıt). Onu "ödenmemiş"
     * sayıp gece sessizce duraklatmak, yöneticinin bilinçli kararını geri
     * almak olurdu.
     */
    public function isCovered(Subscription $subscription, Carbon $date): bool
    {
        $payments = SubscriptionPayment::query()
            ->where('subscription_id', $subscription->id)
            ->where('status', SubscriptionPayment::STATUS_SUCCEEDED)
            ->orderBy('period_start')
            ->get();

        if ($payments->isEmpty()) {
            return true;
        }

        return $payments->contains(
            static fn(SubscriptionPayment $p): bool => $p->covers($date),
        );
    }

    /**
     * Sıradaki ödenmemiş dönemin başlangıcı.
     *
     * Son BAŞARILI dönemin ertesi günü; hiç ödeme yoksa aboneliğin başlangıcı
     * (geçmişte kaldıysa bugün). Geçmişe dönük dönem açmak, aboneden hiçbir
     * porsiyon almadığı günler için para istemek olurdu.
     */
    public function nextPeriodStart(Subscription $subscription): Carbon
    {
        /** @var SubscriptionPayment|null $last */
        $last = SubscriptionPayment::query()
            ->where('subscription_id', $subscription->id)
            ->where('status', SubscriptionPayment::STATUS_SUCCEEDED)
            ->orderByDesc('period_end')
            ->first();

        if ($last !== null) {
            return Carbon::parse($last->period_end->toDateString())->startOfDay()->addDay();
        }

        /*
         * KARŞILAŞTIRMA TARİH DİZESİYLE. İşletme günü Europe/Istanbul'da,
         * `date` dönüşümü ise PHP'nin varsayılan zaman diliminde gece
         * yarısı üretiyor; iki `Carbon` anını `lt()` ile karşılaştırmak aynı
         * takvim gününde bile "geçmişte" sonucunu verebiliyor. Dönen `Carbon`
         * da dizeden kuruluyor ki `runsOnDate()`'in okuduğu `start_date` ile
         * AYNI zaman dilimine düşsün — aksi hâlde dönemin ilk günü gün
         * kuralının dışında kalırdı.
         */
        $gun = max(BusinessTime::today(), $subscription->start_date->toDateString());

        return Carbon::parse($gun)->startOfDay();
    }

    /**
     * Dönemin fiyat dökümü.
     *
     * ÇARPANLAR SUNUCUDA HESAPLANIR, İSTEMCİDEN OKUNMAZ. İstemciden alınsaydı,
     * ekranındaki tutar ile gerçek tutar ayrıştığı anda (arada bir gün
     * atlanmışsa, fiyat güncellenmişse) abone eksik ödeyip "kapattım" sanırdı.
     * Devralınan yapıdaki `full` modu tartışmasının aynısı
     * (`docs/control/_devralinan-odeme-yapisi.md` §2).
     *
     * @return array{start: Carbon, end: Carbon, portions: int, unit_price: int, amount: int}
     */
    public function quote(Subscription $subscription, Carbon $periodStart): array
    {
        $start = $periodStart->copy()->startOfDay();
        $end = $start->copy()->addDays(SubscriptionPayment::PERIOD_DAYS - 1);

        $unitPrice = $subscription->agreed_unit_price_kurus !== null
            ? (int) $subscription->agreed_unit_price_kurus
            : 0;

        $portions = $this->plannedPortions($subscription, $start, $end);

        return [
            'start' => $start,
            'end' => $end,
            'portions' => $portions,
            'unit_price' => $unitPrice,
            'amount' => $portions * $unitPrice,
        ];
    }

    /**
     * Dönem boyunca üretilecek porsiyon toplamı.
     *
     * GÜN KURALI `Subscription::runsOnDate()`'TEN GELİR, burada yeniden
     * yazılmaz: duraklatma aralıkları, atlanan günler ve dönem sınırları o
     * metodun içinde. İki yerde tutulsaydı ödenen gün sayısı ile üretilen
     * sipariş sayısı zamanla ayrışır ve ayrışmayı fark edeceğimiz yer mutfak
     * olurdu.
     *
     * Nokta çarpanı `OrderFactory::createForSubscription()` ile aynı: her
     * teslimat noktası için o günün porsiyonu kadar sipariş üretiliyor.
     */
    private function plannedPortions(Subscription $subscription, Carbon $start, Carbon $end): int
    {
        $closed = ClosedDay::query()
            ->whereBetween('closed_on', [$start->toDateString(), $end->toDateString()])
            ->pluck('closed_on')
            ->map(static fn($d): string => Carbon::parse((string) $d)->toDateString())
            ->all();

        $probe = $this->pricingProbe($subscription);
        $points = max(1, $subscription->delivery_points->count());

        $total = 0;
        $cursor = $start->copy();

        while ($cursor->lte($end)) {
            if (!in_array($cursor->toDateString(), $closed, true) && $probe->runsOnDate($cursor)) {
                $total += max(1, $subscription->quantityForDate($cursor)) * $points;
            }

            $cursor->addDay();
        }

        return $total;
    }

    /**
     * Fiyatlama için `active` sayılan bir kopya.
     *
     * `runsOnDate()` ilk kontrolü `status === active`; oysa fiyatlanan
     * abonelik tam da HENÜZ AKTİF OLMAYAN abonelik — onu aktif yapacak olan
     * şey bu ödemenin kendisi. Gün kuralını kopyalamak yerine durumu tek
     * satırda geçici olarak değiştiriyoruz: kopya kaydedilmiyor, veritabanına
     * dokunmuyor, kural tek yerde kalıyor.
     */
    private function pricingProbe(Subscription $subscription): Subscription
    {
        if ($subscription->status === Subscription::STATUS_ACTIVE) {
            return $subscription;
        }

        $probe = clone $subscription;
        $probe->status = Subscription::STATUS_ACTIVE;

        return $probe;
    }

    // ── Geçiş kuralları ─────────────────────────────────────────────────

    private function onContractApproved(string $from): string
    {
        if ($from !== Subscription::STATUS_PENDING) {
            throw ApiException::invalidTransition(
                $from,
                Subscription::STATUS_PENDING,
                'Sözleşme yalnızca talep aşamasındaki abonelikte onaylanabilir.',
            );
        }

        /*
         * DURUM DEĞİŞMİYOR ve bu bir eksiklik değil.
         *
         * Sözleşmenin onaylanması aboneliği başlatmaz, yalnız ödemenin
         * ÖNÜNÜ AÇAR. `awaiting_payment` diye ayrı bir durum eklemek,
         * `status = active` süzen üretim komutundan KDS'e, panelden mobil
         * rozetlere kadar her yerde dördüncü bir dal açardı; oysa dışarıdan
         * bakınca ikisi de aynı şeydir: henüz başlamamış abonelik.
         * "Ödeme bekliyor" bilgisi ödeme kaydının kendisinde duruyor.
         */
        return Subscription::STATUS_PENDING;
    }

    private function onPaymentSettled(string $from): string
    {
        if ($from === Subscription::STATUS_CANCELLED) {
            throw ApiException::invalidTransition(
                $from,
                Subscription::STATUS_ACTIVE,
                'İptal edilmiş abonelik ödemeyle geri açılmaz.',
            );
        }

        return Subscription::STATUS_ACTIVE;
    }

    private function onPeriodLapsed(string $from): string
    {
        // Zaten duraklatılmış ya da iptal edilmiş aboneliği yeniden
        // duraklatmak sessiz bir işlemdir; hata değil.
        if ($from !== Subscription::STATUS_ACTIVE) {
            return $from;
        }

        return Subscription::STATUS_PAUSED;
    }

    private function onManualActivation(string $from): string
    {
        if ($from === Subscription::STATUS_CANCELLED) {
            throw ApiException::invalidTransition(
                $from,
                Subscription::STATUS_ACTIVE,
                'İptal edilmiş abonelik elle aktifleştirilemez; yeni abonelik açın.',
            );
        }

        return Subscription::STATUS_ACTIVE;
    }
}
