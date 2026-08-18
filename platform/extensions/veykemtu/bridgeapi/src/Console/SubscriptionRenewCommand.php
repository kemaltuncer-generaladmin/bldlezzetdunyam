<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Console;

use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use RuntimeException;
use Throwable;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Models\SubscriptionPayment;
use Veykemtu\BridgeApi\Services\Sms\SmsDispatcher;
use Veykemtu\BridgeApi\Services\SubscriptionLifecycle;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\BridgeApi\Support\Money;

/**
 * Abonelik dönem yenileme — I4.
 *
 * ═════════════════════════════════════════════════════════════════════════
 * OTOMATİK YENİLEME DİYE BİR ŞEY YOKTU VE BU, ABONELİK MODELİNİN
 * KENDİSİNİ ÇALIŞMAZ KILIYORDU.
 *
 * Akış şöyle bitiyordu: ödenmiş 30 günlük dönem doluyor →
 * `SubscriptionGenerateCommand::reportLapsedPeriods()` aboneliği SESSİZCE
 * `paused` yapıyor → üretim duruyor. Bu noktadan sonra:
 *   · yeni dönem borcu AÇILMIYOR (yönetici elle açacak),
 *   · müşteriye hatırlatma GİTMİYOR (`subscription_payment_due` şablonu
 *     göçte tohumlanmış ama HİÇBİR YERDEN gönderilmiyordu),
 *   · fatura kesilmiyor.
 * Yani her ay, her abone için birinin elle borç açması gerekiyordu; kimse
 * açmadığında müşteri sabah yemeğinin gelmediğini görüyordu.
 *
 * Bu komut o boşluğu kapatıyor: dönem bitmeden N gün önce SONRAKİ DÖNEMİN
 * BORCUNU AÇAR ve hatırlatma SMS'ini gönderir.
 * ═════════════════════════════════════════════════════════════════════════
 *
 * ─────────────────────────────────────────────────────────────────────────
 * NEDEN "TAHSİL ET" DEĞİL "BORÇ AÇ".
 *
 * Kayıtlı kart yok, saklanan ödeme aracı yok ve olmayacak (sanal POS
 * sözleşmesi hâlâ beklemede). Otomatik TAHSİLAT sözü vermek, veremeyeceğimiz
 * bir sözdür. Verebileceğimiz söz şu: dönem bitmeden borç görünür olur,
 * müşteri haberdar edilir ve ödediği anda üretim kesintisiz sürer.
 * ─────────────────────────────────────────────────────────────────────────
 *
 * İDEMPOTENT — ÜÇ KAT:
 *   1. Bu komut aynı dönem için ikinci kez borç açmaz (varlık kontrolü),
 *   2. `UNIQUE(subscription_id, period_start)` bir yarışta bile ikinci
 *      satırı reddeder,
 *   3. hatırlatma SMS'i `('subscription', payment_id)` referansıyla gidiyor
 *      ve `veykemtu_sms_log` benzersiz indeksi ikinci mesajı düşürüyor.
 * Üçü de gerekli: komut zamanlayıcıdan GÜNDE BİR koşuyor ve pencere N gün
 * geniş, yani aynı abonelik pencere boyunca her gün buraya uğruyor.
 *
 * BAŞARISIZLIK BİR ABONELİĞİ AŞMAZ. Tek bir abonelikte patlayan bir hata
 * (fiyatı silinmiş, dönemi boş) bütün yenilemeyi durdurmamalı; satır
 * yazılır ve döngü sürer — `SubscriptionGenerateCommand`'ın üretim
 * döngüsündeki karar aynısı.
 */
class SubscriptionRenewCommand extends Command
{
    protected $signature = 'veykemtu:abonelik-yenile
        {--days= : Dönem bitişine kaç gün kala borç açılsın (varsayılan: ayardan)}
        {--dry-run : Hiçbir şey yazmadan neyin açılacağını göster}';

    protected $description = 'Biten dönemlerin sonraki borcunu açar ve hatırlatma SMS\'i gönderir.';

    /** Ayar anahtarı — `location_options`. */
    private const string OPT_DAYS = 'bld_subscription_renew_days';

    /** Hatırlatma şablonu (`veykemtu_sms_templates`). */
    private const string TEMPLATE = 'subscription_payment_due';

    /**
     * Pencerenin en geniş hâli.
     *
     * Sınırsız bırakılsaydı, ayarı 400 yazan biri bütün aboneliklerin bir
     * yıllık borcunu tek gecede açardı ve iadesi elle yapılırdı.
     */
    private const int MAX_DAYS = 30;

    public function handle(SubscriptionLifecycle $lifecycle, SmsDispatcher $sms): int
    {
        $days = $this->windowDays();
        $dryRun = (bool) $this->option('dry-run');
        $today = BusinessTime::now()->startOfDay();
        $horizon = $today->copy()->addDays($days);

        /*
         * YALNIZ ÜRETEN ABONELİKLER. `paused` olanı da almak isterdik ama
         * duraklatma iki ayrı sebepten olabiliyor (yönetici duraklattı /
         * dönem bitti) ve ikincisinde borç zaten AÇILMIŞ olmalıydı — bu
         * komut tam da onu önlemek için var. `cancelled` ve `awaiting_*`
         * için yenilenecek bir dönem yok.
         */
        $subscriptions = Subscription::query()
            ->active()
            ->with(['pauses', 'exceptions', 'delivery_points', 'customer'])
            ->get();

        $opened = 0;
        $notified = 0;
        $skipped = 0;

        foreach ($subscriptions as $subscription) {
            try {
                $result = $this->renewOne($lifecycle, $sms, $subscription, $today, $horizon, $dryRun);
            } catch (Throwable $e) {
                // TEK ABONELİK BÜTÜN İŞİ DÜŞÜREMEZ.
                $this->components->error(sprintf(
                    '#%d yenilenemedi: %s',
                    (int) $subscription->id,
                    $e->getMessage(),
                ));
                $skipped++;

                continue;
            }

            $opened += $result['opened'];
            $notified += $result['notified'];
        }

        $this->components->info(sprintf(
            '%s — %d dönem borcu açıldı, %d hatırlatma gönderildi, %d abonelik atlandı.%s',
            $today->toDateString(),
            $opened,
            $notified,
            $skipped,
            $dryRun ? ' (kuru koşum — HİÇBİR ŞEY YAZILMADI)' : '',
        ));

        // BAŞARISIZ ABONELİK KOMUTU BAŞARISIZ SAYMAZ: zamanlayıcının alarmı
        // her fiyatsız abonelikte çalarsa gerçek arızaların sinyalini boğar
        // (`reportLapsedPeriods()` ile aynı gerekçe).
        return self::SUCCESS;
    }

    /**
     * Tek aboneliğin sıradaki dönemini açar.
     *
     * @return array{opened: int, notified: int}
     */
    private function renewOne(
        SubscriptionLifecycle $lifecycle,
        SmsDispatcher $sms,
        Subscription $subscription,
        Carbon $today,
        Carbon $horizon,
        bool $dryRun,
    ): array {
        $start = $lifecycle->nextPeriodStart($subscription);

        /*
         * PENCERE DIŞINDAYSA DOKUNULMAZ.
         *
         * Sıradaki dönem ufkun ötesinde başlıyorsa ödenmiş dönem hâlâ
         * sürüyor demektir; borcu şimdi açmak, abonenin daha yemediği
         * günler için parasını istemek olurdu.
         */
        if ($start->gt($horizon)) {
            return ['opened' => 0, 'notified' => 0];
        }

        /*
         * BİTİŞ GÜNÜ GEÇMİŞ ABONELİK YENİLENMEZ. `end_date` dolu ve sıradaki
         * dönem onun ötesindeyse abonelik doğal olarak bitiyor; borç açmak,
         * bitmiş bir hizmet için fatura çıkarmak olurdu.
         */
        if ($subscription->end_date !== null
            && $start->gt($subscription->end_date->copy()->startOfDay())
        ) {
            return ['opened' => 0, 'notified' => 0];
        }

        $quote = $lifecycle->quote($subscription, $start);

        if ($quote['portions'] < 1) {
            // Bu dönemde hiç servis günü yok (tatil, duraklatma, bitiş).
            return ['opened' => 0, 'notified' => 0];
        }

        if ($quote['unit_price'] < 1) {
            // FİYATSIZ ABONELİĞE SIFIR TUTARLI BORÇ AÇMAK, "ödendi" diye
            // kapanan ve hiçbir şey tahsil etmeyen bir kayıt üretirdi.
            throw new RuntimeException('Anlaşmalı birim fiyat girilmemiş.');
        }

        $existing = SubscriptionPayment::query()
            ->where('subscription_id', $subscription->id)
            ->whereDate('period_start', $quote['start']->toDateString())
            ->first();

        if ($existing !== null) {
            // Borç zaten açık: yalnız hatırlatmayı dener. Mesaj idempotans
            // indeksinden geçemezse sessizce düşer, yani müşteri günde bir
            // kez değil, dönem başına bir kez uyarılır.
            return [
                'opened' => 0,
                'notified' => $this->remind($sms, $subscription, $existing, $dryRun) ? 1 : 0,
            ];
        }

        $this->components->info(sprintf(
            '#%d · %s – %s · %d porsiyon · %s',
            (int) $subscription->id,
            $quote['start']->toDateString(),
            $quote['end']->toDateString(),
            $quote['portions'],
            self::lira($quote['amount']),
        ));

        if ($dryRun) {
            return ['opened' => 0, 'notified' => 0];
        }

        $payment = $this->openPeriod($subscription, $quote, $today);

        return [
            'opened' => 1,
            'notified' => $this->remind($sms, $subscription, $payment, $dryRun) ? 1 : 0,
        ];
    }

    /**
     * Dönem borcunu yazar.
     *
     * `due_date` DÖNEM BAŞIDIR (peşin tahsilat kuralı). Panelden açılan
     * borçta bu alan artık gönderilebiliyor ama otomatik yenileme bir
     * pazarlık yapmıyor: sözleşmedeki varsayılan neyse o.
     *
     * @param  array{start: Carbon, end: Carbon, portions: int, unit_price: int, amount: int}  $quote
     */
    private function openPeriod(Subscription $subscription, array $quote, Carbon $today): SubscriptionPayment
    {
        $payment = new SubscriptionPayment;
        $payment->subscription_id = (int) $subscription->id;
        $payment->period_start = $quote['start']->toDateString();
        $payment->period_end = $quote['end']->toDateString();
        $payment->portions_planned = $quote['portions'];
        $payment->unit_price_kurus = $quote['unit_price'];
        $payment->amount_kurus = $quote['amount'];
        $payment->status = SubscriptionPayment::STATUS_PENDING;

        if (Schema::hasColumn('veykemtu_subscription_payments', 'due_date')) {
            $payment->due_date = $quote['start']->toDateString();
        }

        if (Schema::hasColumn('veykemtu_subscription_payments', 'note')) {
            // KİMİN AÇTIĞI SORULACAK. Elle açılan borçla otomatik açılanı
            // ayırt edememek, "bunu ben açmadım" tartışmasını çözümsüz
            // bırakırdı.
            $payment->note = 'Otomatik yenileme ('.$today->toDateString().')';
        }

        // Adres tahmin edilemez olmalı (`storePayment()` ile aynı gerekçe).
        $payment->hash = bin2hex(random_bytes(16));
        $payment->created_at = BusinessTime::forStorage(BusinessTime::now());
        $payment->save();

        return $payment;
    }

    /**
     * Hatırlatma SMS'i — `subscription_payment_due`.
     *
     * ŞABLON KAPALIYSA HİÇBİR ŞEY GİTMEZ ve bu doğrudur: şablonlar kapalı
     * doğuyor ve borç hatırlatması, yöneticinin bilerek açması gereken bir
     * gönderimdir. `SmsDispatcher` kapalı şablonda sessizce dönüyor.
     *
     * REFERANS `('subscription', payment_id)`: komut pencere boyunca her
     * gün koşuyor ve referanssız gönderim aynı borç için N mesaj demekti.
     * Referans kimliği ABONELİK DEĞİL ÖDEME: abonelik kimliği verilseydi
     * ikinci dönemin hatırlatması birincinin yuvasına çarpar ve hiç
     * gitmezdi.
     */
    private function remind(SmsDispatcher $sms, Subscription $subscription,
                            SubscriptionPayment $payment, bool $dryRun): bool
    {
        $phone = trim((string) ($subscription->customer->telephone ?? ''));

        if ($phone === '') {
            return false;
        }

        $sms->send(
            self::TEMPLATE,
            $phone,
            [
                'customer_name' => $this->customerName($subscription),
                'period' => $payment->period_start->format('m.Y'),
                'amount' => self::lira((int) $payment->amount_kurus),
                'due_date' => ($payment->due_date ?? $payment->period_start)->format('d.m.Y'),
            ],
            SmsDispatcher::REF_SUBSCRIPTION,
            (int) $payment->id,
            $dryRun,
        );

        return true;
    }

    private function customerName(Subscription $subscription): string
    {
        $customer = $subscription->customer;

        if ($customer === null) {
            return 'Müşterimiz';
        }

        $organisation = trim((string) ($customer->bld_org_name ?? ''));

        if ($organisation !== '') {
            return $organisation;
        }

        $full = trim((string) ($customer->first_name ?? '').' '.(string) ($customer->last_name ?? ''));

        return $full !== '' ? $full : 'Müşterimiz';
    }

    /**
     * Pencere genişliği — bayrak > ayar > `RENEWAL_WINDOW_DAYS`.
     *
     * Varsayılan modelin kendi yenileme penceresiyle AYNI sayı: ödeme
     * ekranı zaten dönemin son 7 gününde açılıyor ve borcun ondan önce
     * doğması, müşteriye ödeyemeyeceği bir borç göstermek olurdu.
     */
    private function windowDays(): int
    {
        $given = $this->option('days');

        if ($given !== null && trim((string) $given) !== '') {
            return $this->clamp((int) $given);
        }

        try {
            $raw = DB::table('location_options')->where('item', self::OPT_DAYS)->value('value');
        } catch (Throwable) {
            $raw = null;
        }

        $decoded = $raw === null ? null : json_decode((string) $raw, true);

        return $this->clamp(
            is_numeric($decoded) ? (int) $decoded : SubscriptionPayment::RENEWAL_WINDOW_DAYS,
        );
    }

    private function clamp(int $days): int
    {
        return max(1, min(self::MAX_DAYS, $days));
    }

    /**
     * Kuruş → "1.920,00" (TL eki YOK).
     *
     * Şablon metni "{amount} TL" yazıyor; eki burada da eklemek "1.920,00 TL
     * TL" üretirdi. Biçim Türkçe: binlik nokta, kuruş virgül.
     */
    private static function lira(int $kurus): string
    {
        return number_format(Money::toDecimal($kurus), 2, ',', '.');
    }
}
