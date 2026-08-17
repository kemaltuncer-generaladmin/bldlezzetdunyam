<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Models\SubscriptionContract;
use Veykemtu\BridgeApi\Services\Sms\SmsSender;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\BridgeApi\Support\Money;
use Veykemtu\BridgeApi\Support\SignedLink;

/**
 * Abonelik sözleşmesinin tamamı — üretim, bağlantı, OTP, onay (iş kararı 9).
 *
 * AKIŞ: talep → Kontrol Merkezi'nde fiyat → **bu servis** metni dondurur ve
 * imzalı bağlantıyı SMS ile yollar → müşteri açar, telefonuna gelen kodu
 * girer → onay damgalanır ve abonelik ödeme beklemeye geçer.
 *
 * NEDEN DENETLEYİCİDE DEĞİL: aynı işi üç ayrı kapı çağırıyor — müşteriye
 * açık API (`ContractController`), sunucuda çizilen sayfa
 * (`ContractPageController`) ve Kontrol Merkezi paneli
 * (`Control\SubscriptionController`, başka kulvar). Mantık denetleyiciye
 * yazılsaydı üç kopya doğar, biri "onaylanmış sözleşme tekrar onaylanamaz"
 * kuralını unuturdu.
 *
 * DONDURMA İLKESİ: `create()` metni ve koşulları yazdıktan sonra bu servis
 * onlara BİR DAHA DOKUNMAZ. Onay yalnız damga kolonlarını (`approved_*`,
 * `otp_verified_at`) ve durumu yazar.
 */
final class ContractService
{
    /**
     * Şablon sürümü.
     *
     * SAYISAL BİR DİZE OLMAK ZORUNDA: `docs/openapi.yaml` →
     * `SubscriptionContract.version` tam sayı ve `minimum: 1`. `v1` yazsaydık
     * uçta 0'a düşer ve sözleşme sessizce kırılırdı.
     *
     * Metin değiştiğinde bu sabit artırılır. Eski sözleşmeler etkilenmez —
     * metinlerini kendi satırlarında taşıyorlar.
     */
    public const string TEMPLATE_VERSION = '1';

    /** Peşin ödenen dönem — iş kuralı: 30 günlük peşin ödeme. */
    public const int DEFAULT_TERM_DAYS = 30;

    /**
     * A4'ün yazdığı abonelik yaşam döngüsü servisi.
     *
     * DİZE OLARAK TUTULUYOR ÇÜNKÜ SINIF HENÜZ YOK. `use` ile içe aktarıp
     * doğrudan çağırsaydık, A4 kulvarı inmeden bu dosya ölümcül hata
     * verirdi. `class_exists` denetimi `routes/api.php`'deki desenin aynısı.
     *
     * VARSAYILAN ARAYÜZ: `contractApproved(Subscription, SubscriptionContract): void`.
     */
    private const string LIFECYCLE = 'Veykemtu\\BridgeApi\\Services\\SubscriptionLifecycle';

    /**
     * Yaşam döngüsü servisi yokken aboneliğin geçeceği durum.
     *
     * `docs/03-api-sozlesmesi.md` §15.1: `Subscription.status` sözlüğüne
     * `awaiting_contract` ve `awaiting_payment` eklendi. Onay geldiğinde
     * aboneliği HİÇ ELLEMESEYDİK akış ölürdü: sözleşme onaylı, abonelik
     * hâlâ `pending` ve ödeme ekranı hiç açılmazdı.
     */
    private const string STATUS_AWAITING_PAYMENT = 'awaiting_payment';

    /**
     * Aboneliğin sözleşme beklediği durum — A4 ile paylaşılan sözlük.
     *
     * DİKKAT: bu değer 17 KARAKTER ve `veykemtu_subscriptions.status`
     * kolonu `varchar(16)`. Yani bu durum bugün o kolona YAZILAMAZ; buradaki
     * karşılaştırma yalnız kolon genişletildikten sonra tutar. Kolonu
     * genişletmek abonelik kulvarının (A4) işi — sözleşme kulvarı başka bir
     * kulvarın tablosunu değiştirmez. `awaiting_payment` 16 karakter, yani
     * yedek yol bugün de çalışıyor.
     */
    private const string STATUS_AWAITING_CONTRACT = 'awaiting_contract';

    public function __construct(
        private readonly OtpService $otp,
        private readonly SmsSender $sms,
    ) {}

    // ── Üretim ────────────────────────────────────────────────────────────

    /**
     * Sözleşmeyi hazırlar: metni ve koşulları DONDURUR, bağlantıyı üretir.
     *
     * Kayıt `draft` doğar; SMS `send()` ile ayrı atılır. Ayrı olmasının
     * sebebi `docs/control/subscriptions.md` → `send_sms: false`: yönetici
     * bağlantıyı elden iletebiliyor ve o hâlde kayıt gönderilmiş
     * sayılmamalı.
     *
     * @param  string|null  $phone  Verilmezse müşterinin kayıtlı numarası.
     *
     * @throws ApiException Fiyat konmamışsa ya da numara hiç yoksa.
     */
    public function create(
        Subscription $subscription,
        ?string $phone = null,
        ?int $expiresInDays = null,
        ?string $createdBy = null,
        ?int $termDays = null,
    ): SubscriptionContract {
        $price = $subscription->agreed_unit_price_kurus;
        if ($price === null || (int) $price <= 0) {
            /*
             * FİYATSIZ SÖZLEŞME OLMAZ. Talep `pending` doğuyor ve fiyatı
             * Kontrol Merkezi koyuyor; fiyatsız bir metni imzalatmak,
             * müşteriye tutarı boş bir belge onaylatmak olurdu.
             */
            throw ApiException::validationFailed('Sözleşme için önce porsiyon fiyatı belirlenmeli.', [
                'agreed_unit_price_kurus' => 'Abonelikte anlaşmalı fiyat yok.',
            ]);
        }

        $phone = OtpService::normalize((string) ($phone ?? $this->customerPhone($subscription)));
        if ($phone === '') {
            throw ApiException::validationFailed('Sözleşme gönderilecek telefon numarası yok.', [
                'phone' => 'Müşterinin kayıtlı numarası da boş.',
            ]);
        }

        $termDays = $termDays !== null && $termDays > 0 ? $termDays : self::DEFAULT_TERM_DAYS;
        $terms = $this->freezeTerms($subscription, (int) $price, $termDays);

        $contract = new SubscriptionContract;
        $contract->subscription_id = (int) $subscription->getKey();
        $contract->version = self::TEMPLATE_VERSION;
        $contract->body_html = $this->composeBody($subscription, $terms);
        $contract->agreed_unit_price_kurus = (int) $price;
        $contract->term_days = $termDays;
        $contract->terms_json = $terms;
        $contract->status = SubscriptionContract::STATUS_DRAFT;
        $contract->sent_to_phone = $phone;
        $contract->created_by = $createdBy;

        /*
         * TOKEN KAYIT KİMLİĞİNE BAĞLI, YANİ ÖNCE KAYDETMEK GEREKİYOR.
         * `token_hash` NOT NULL olduğu için iki adımda yazılıyor: geçici bir
         * özet, sonra gerçeği. Geçici değer de rastgele — sabit bir nöbetçi
         * dize olsaydı UNIQUE indeksi ikinci taslakta patlardı.
         */
        $contract->token_hash = hash('sha256', 'gecici:'.bin2hex(random_bytes(16)));
        $contract->save();

        $this->issueLink($contract, $expiresInDays ?? SignedLink::CONTRACT_TTL_DAYS);

        return $contract;
    }

    /**
     * Bu abonelikte hâlâ onaylanabilir bir sözleşme var mı?
     *
     * `docs/control/subscriptions.md`: aynı abonelikte açık bir sözleşme
     * varken ikincisi açılamaz (`409 CONFLICT`) — iki geçerli bağlantı,
     * hangisinin imzalandığını belirsiz kılardı.
     *
     * "AÇIK" TANIMI BURADA DURUYOR ve panel ucunu yazan taraf da bunu
     * çağırmalı: süresi dolmuş bir taslak artık açık değildir ve tanımı
     * ikinci kez yazan taraf bu ayrımı kaçırırsa, kimsenin
     * onaylayamayacağı bir sözleşme yüzünden yenisi hiç açılamaz.
     */
    public function openContractFor(Subscription $subscription): ?SubscriptionContract
    {
        $candidates = SubscriptionContract::query()
            ->where('subscription_id', (int) $subscription->getKey())
            ->whereIn('status', [
                SubscriptionContract::STATUS_DRAFT,
                SubscriptionContract::STATUS_SENT,
            ])
            ->orderByDesc('id')
            ->get();

        foreach ($candidates as $candidate) {
            if ($candidate->isApprovable()) {
                return $candidate;
            }
        }

        return null;
    }

    /**
     * Bağlantıyı (yeniden) üretir ve süresini belirler.
     *
     * DİKKAT — TOKEN TÜRETİLMİŞTİR: `{id}-{bitiş}-{imza}` ve imza bitiş anını
     * da kapsıyor. Yani `expires_at` her değiştiğinde ESKİ BAĞLANTI ÖLÜR.
     * `docs/control/subscriptions.md` "yeniden gönderimde yeni token
     * üretilmez" diyor; bu ikisi ancak süre tazelenmediğinde birlikte
     * yaşayabilir. Bu yüzden `resend()` varsayılan olarak süreye DOKUNMAZ.
     */
    public function issueLink(SubscriptionContract $contract, int $expiresInDays): void
    {
        $expiresAt = BusinessTime::now()->addDays(max(1, $expiresInDays));

        $contract->expires_at = BusinessTime::forStorage($expiresAt);
        $contract->token_hash = hash('sha256', $this->tokenFor($contract, $expiresAt->getTimestamp()));
        $contract->save();
    }

    /**
     * Bağlantıyı SMS ile gönderir ve kaydı `sent` yapar.
     *
     * SMS ŞABLON SİSTEMİNDEN GEÇMİYOR. `docs/control/sms.md` bir
     * `subscription_contract` şablonu tanımlıyor ama şablonlar **varsayılan
     * kapalı doğuyor**; kapalı bir şablon, yöneticinin "gönder" dediği
     * bağlantının hiç gitmemesi demek olurdu. Şablon kulvarı indiğinde bu
     * çağrı oraya bağlanmalı — mesaj metni o zaman panelden yönetilir.
     */
    public function send(SubscriptionContract $contract): void
    {
        $phone = (string) ($contract->sent_to_phone ?? '');
        if ($phone === '') {
            throw ApiException::validationFailed('Sözleşmede telefon numarası yok.');
        }

        // ASCII: operatör GSM-7 dışına çıkan mesajı çok parçalı gönderiyor
        // ve maliyet ikiye katlanıyor (`OtpService` ile aynı üslup).
        $this->sms->send($phone, sprintf(
            'Benim Lezzet Dunyam abonelik sozlesmeniz hazir. Okuyup onaylamak icin: %s '
            .'Baglanti %s tarihine kadar gecerlidir.',
            $this->signUrl($contract),
            BusinessTime::at(Carbon::createFromTimestamp($this->expiresTimestamp($contract)))
                ->format('d.m.Y'),
        ));

        $contract->sent_at = BusinessTime::forStorage(BusinessTime::now());
        $contract->status = SubscriptionContract::STATUS_SENT;
        $contract->save();
    }

    /**
     * Aynı sözleşmenin bağlantısını yeniden gönderir.
     *
     * `$expiresInDays` VERİLMEZSE SÜRE TAZELENMEZ ve müşterinin elindeki
     * eski SMS çalışmaya devam eder — panelin istediği davranış. Verilirse
     * yeni bir bağlantı doğar ve eskisi ölür; çağıran bunu bilerek yapar.
     */
    public function resend(SubscriptionContract $contract, ?int $expiresInDays = null): void
    {
        if (!$contract->isApprovable()) {
            throw ApiException::validationFailed('Bu sözleşmenin bağlantısı yeniden gönderilemez.', [
                'status' => $contract->effectiveStatus(),
            ]);
        }

        if ($expiresInDays !== null) {
            $this->issueLink($contract, $expiresInDays);
        }

        $this->send($contract);
    }

    /**
     * Sözleşmeyi iptal eder.
     *
     * ONAYLANMIŞ SÖZLEŞME İPTAL EDİLEMEZ: imzalanmış bir belgeyi iptal
     * edilmiş göstermek, imzanın kendisini geçersiz kılmaktır. Yeni koşullar
     * yeni bir sözleşme gerektirir.
     */
    public function cancel(SubscriptionContract $contract, ?string $reason = null): void
    {
        if ($contract->effectiveStatus() === SubscriptionContract::STATUS_APPROVED) {
            throw ApiException::validationFailed('Onaylanmış sözleşme iptal edilemez.', [
                'conflict' => 'signed',
            ]);
        }

        $contract->status = SubscriptionContract::STATUS_CANCELLED;
        $contract->cancelled_at = BusinessTime::forStorage(BusinessTime::now());
        $contract->cancel_reason = $reason;
        $contract->save();
    }

    // ── Bağlantı ──────────────────────────────────────────────────────────

    /**
     * Ham belirteç: `{id}-{bitiş}-{imza}`.
     *
     * ÜÇ PARÇA DA İMZANIN İÇİNDE (`SignedLink` deseni): amaç, kayıt kimliği
     * ve bitiş anı. Kimlik sıralı denemeyle komşu sözleşmeye geçmeyi, bitiş
     * anı bağlantının kendi süresini uzatmayı, amaç ise takip/teslim
     * bağlantısının burada yeniden oynatılmasını engelliyor.
     *
     * BİÇİM `[A-Za-z0-9_-]{20,200}` KALIBINA UYAR (`routes/api.php`): imza
     * base64url ve tire içerebilir; bu yüzden çözümleme `explode(..., 3)`
     * ile yapılır, son parça olduğu gibi bırakılır.
     */
    public function tokenFor(SubscriptionContract $contract, ?int $expiresAt = null): string
    {
        $expires = $expiresAt ?? $this->expiresTimestamp($contract);
        $id = (int) $contract->getKey();

        return $id.'-'.$expires.'-'.SignedLink::sign(SignedLink::PURPOSE_CONTRACT, $id, $expires);
    }

    /**
     * Müşterinin SMS'te göreceği sayfa adresi.
     *
     * `config('app.url')` KULLANILIYOR, `url()` YARDIMCISI DEĞİL: bağlantı
     * bir konsol komutundan da üretilebilir (toplu gönderim, yeniden
     * gönderim işi) ve orada istek yoktur — `url()` o hâlde de aynı ayara
     * düşer ama istek varken isteğin sunucu adına bağlanır. Ters vekil
     * arkasında bu ad iç konteyner adı olabilir ve müşteriye açılmayan bir
     * adres göndermek, bağlantıyı hiç göndermemekten kötüdür.
     * `ReceiptBuilder::deliverUrl()` ile aynı desen.
     */
    public function signUrl(SubscriptionContract $contract): string
    {
        $expires = $this->expiresTimestamp($contract);
        $id = (int) $contract->getKey();

        return rtrim((string) config('app.url'), '/').'/sozlesme/'.$id.'/'.$expires.'/'
            .SignedLink::sign(SignedLink::PURPOSE_CONTRACT, $id, $expires);
    }

    /**
     * Belirteci sözleşmeye çözer — SÜRE DENETLEMEZ.
     *
     * Süre bilerek dışarıda: iki kapı iki farklı şey yapıyor. API süresi
     * dolmuş bağlantıya `200` + `status: expired` dönüyor (istemci "yenisini
     * isteyin" cümlesini kurabilsin), sayfa ise `410`. Süreyi buraya
     * gömseydik ikisinden biri yanlış davranırdı.
     *
     * İMZA ÖNCE, VERİTABANI SONRA — `PublicTrackingController` ile aynı
     * disiplin: geçersiz imza ile var olmayan sözleşme ayırt edilememeli.
     */
    public function find(string $token): ?SubscriptionContract
    {
        $parts = explode('-', $token, 3);
        if (count($parts) !== 3) {
            return null;
        }

        [$rawId, $rawExpires, $signature] = $parts;
        if (!ctype_digit($rawId) || !ctype_digit($rawExpires)) {
            return null;
        }

        $id = (int) $rawId;
        $expires = (int) $rawExpires;

        if (!SignedLink::verify(SignedLink::PURPOSE_CONTRACT, $id, $expires, $signature)) {
            return null;
        }

        $contract = SubscriptionContract::query()->find($id);
        if (!$contract instanceof SubscriptionContract) {
            return null;
        }

        /*
         * ÖZET DE DENETLENİR. İmza tek başına yeterli görünür ama değil:
         * süresi tazelenmiş bir sözleşmede ESKİ bağlantının imzası hâlâ
         * doğrudur (imza sırrı değişmedi). Kayıttaki özet yalnız yürürlükteki
         * bağlantıya aittir, yani eskisi burada ölür.
         */
        if (!hash_equals((string) $contract->token_hash, hash('sha256', $token))) {
            return null;
        }

        return $contract;
    }

    // ── Onay ──────────────────────────────────────────────────────────────

    /**
     * Sözleşmedeki numaraya SMS kodu ister.
     *
     * NUMARA İSTEKTE ALINMAZ, kayıttan okunur: istemciden alınsaydı
     * bağlantıyı ele geçiren kodu kendi telefonuna ısmarlayıp sözleşmeyi
     * onaylardı. İmzalı bağlantı tek başına kimlik değildir; SMS kodu ikinci
     * etkendir.
     *
     * `OtpService` SIFIR DEĞİŞİKLİKLE kullanılıyor — bekleme süresi, bcrypt
     * özet, deneme sayacı ve kayıtsız numarada sessiz çıkış hepsi doğru.
     * TEK NOT: `verify()` o telefona ait TÜM açık kodları tüketiyor, yani
     * giriş OTP'si ile sözleşme OTP'si aynı havuzu paylaşıyor. Kabul
     * edilebilir — ikisi de aynı şeyi kanıtlıyor: telefonun sahipliğini.
     * Pratik sonucu, sözleşme kodunu bekleyen müşteri araya giriş kodu
     * isterse ilk kodun ölmesidir.
     *
     * SESSİZ ÇIKIŞIN BURADAKİ ANLAMI: numara bir müşteriye bağlı değilse
     * `OtpService` hiçbir şey göndermez ve uç yine `202` döner. Sözleşme
     * müşterinin kayıtlı numarasına gittiği sürece bu yol boş kalır;
     * yönetici elle başka bir numara yazdıysa kod hiç gelmez.
     */
    public function requestOtp(SubscriptionContract $contract): void
    {
        $this->assertApprovable($contract);

        $phone = (string) ($contract->sent_to_phone ?? '');
        if ($phone === '') {
            throw ApiException::validationFailed('Sözleşmede telefon numarası yok.');
        }

        $this->otp->request($phone);
    }

    /**
     * Kodu doğrular ve sözleşmeyi onaylar.
     *
     * İDEMPOTENT: onaylanmış sözleşmede kod HİÇ DOĞRULANMAZ, aynı kayıt
     * döner. Doğrulasaydık ikinci dokunuş "kod hatalı" alırdı — kod zaten
     * ilk çağrıda tüketildi — ve onaylanmış bir sözleşmede "onaylanamadı"
     * yazan bir ekran doğardı. SMS'in gecikip kullanıcının iki kez dokunması
     * sık yaşanıyor.
     *
     * ONAY GERİ ALINAMAZ. Vazgeçme sözleşmenin değil aboneliğin iptalidir;
     * onay kaydı hukuki bir izdir ve silinmez.
     */
    public function approve(
        SubscriptionContract $contract,
        string $code,
        ?string $fullName = null,
        ?string $ip = null,
        ?string $userAgent = null,
    ): SubscriptionContract {
        if ($contract->effectiveStatus() === SubscriptionContract::STATUS_APPROVED) {
            return $contract;
        }

        $this->assertApprovable($contract);

        $phone = (string) ($contract->sent_to_phone ?? '');
        if ($phone === '') {
            throw ApiException::validationFailed('Sözleşmede telefon numarası yok.');
        }

        // Yanlış kod burada `422` fırlatır ve AŞAĞIYA HİÇ İNİLMEZ: sözleşme
        // `sent` kalır, hiçbir damga yazılmaz.
        $this->otp->verify($phone, $code);

        $now = BusinessTime::forStorage(BusinessTime::now());

        DB::transaction(function () use ($contract, $fullName, $ip, $userAgent, $now): void {
            $contract->otp_verified_at = $now;
            $contract->approved_at = $now;
            $contract->approved_ip = $ip;
            $contract->approved_user_agent = $userAgent === null
                ? null
                : mb_substr($userAgent, 0, 255);
            $contract->approved_full_name = $fullName === null
                ? null
                : mb_substr(trim($fullName), 0, 120);
            $contract->status = SubscriptionContract::STATUS_APPROVED;
            $contract->save();

            $this->handOver($contract);
        });

        return $contract;
    }

    /**
     * Onaylanan sözleşmeyi aboneliğe bağlar.
     *
     * İKİ İŞ: donmuş fiyatı aboneliğe kopyalamak ve durumu yaşam döngüsüne
     * devretmek. Fiyat kopyalanıyor çünkü sözleşme imzalandığı andan itibaren
     * geçerli olan tek fiyat odur — panelde arada bir düzeltme yapıldıysa
     * müşterinin onayladığı rakam kazanır.
     *
     * ABONELİK BURADA `active` OLMAZ. 30 günlük peşin ödeme daha yapılmadı;
     * onayla birlikte aktifleştirmek, ödemesiz üretim demek olurdu.
     */
    private function handOver(SubscriptionContract $contract): void
    {
        $subscription = Subscription::query()->find($contract->subscription_id);
        if (!$subscription instanceof Subscription) {
            return;
        }

        $subscription->agreed_unit_price_kurus = (int) $contract->agreed_unit_price_kurus;
        $subscription->save();

        if (class_exists(self::LIFECYCLE)) {
            /** @var object{contractApproved: callable} $lifecycle */
            $lifecycle = app(self::LIFECYCLE);
            if (method_exists($lifecycle, 'contractApproved')) {
                $lifecycle->contractApproved($subscription, $contract);

                return;
            }
        }

        /*
         * YEDEK YOL — A4 (`SubscriptionLifecycle`) henüz inmediyse.
         *
         * YALNIZ SÖZLEŞME BEKLEYEN DURUMLARDAN ÇIKAR. `active`, `paused` ya
         * da `cancelled` bir aboneliğe dokunmak, çalışan bir üretimi
         * durdurmak olurdu; sözleşme yenilemesi bunu yapmamalı.
         */
        $current = (string) $subscription->status;
        if (in_array($current, [Subscription::STATUS_PENDING, self::STATUS_AWAITING_CONTRACT], true)) {
            $subscription->status = self::STATUS_AWAITING_PAYMENT;
            $subscription->save();
        }
    }

    /** @throws ApiException */
    private function assertApprovable(SubscriptionContract $contract): void
    {
        if ($contract->isApprovable()) {
            return;
        }

        throw ApiException::validationFailed(
            match ($contract->effectiveStatus()) {
                SubscriptionContract::STATUS_EXPIRED => 'Sözleşme bağlantısının süresi doldu. Yeni bağlantı isteyin.',
                SubscriptionContract::STATUS_CANCELLED => 'Bu sözleşme iptal edilmiş.',
                default => 'Sözleşme onaya uygun durumda değil.',
            },
            ['status' => $contract->effectiveStatus()],
        );
    }

    // ── Sunum ─────────────────────────────────────────────────────────────

    /**
     * `docs/openapi.yaml` → `SubscriptionContract`.
     *
     * DEĞERLER DONMUŞ KOŞULLARDAN OKUNUR, canlı abonelikten değil. Abonelik
     * sonradan değişirse sözleşme sayfası değişmemeli: "neyi onayladım"
     * sorusunun cevabı ekranda da doğru durmalı.
     *
     * @return array<string, mixed>
     */
    public function apiPayload(SubscriptionContract $contract): array
    {
        return [
            'status' => $contract->effectiveStatus(),
            'version' => (int) $contract->version,
            'title' => $contract->term('title'),
            /*
             * METİN DÜZ GİDER, HTML GİTMEZ (`docs/03-api-sozlesmesi.md`
             * §15.4). Saklanan biçim HTML — sayfayı sunucu çiziyor — ama
             * uçtan HTML yollamak, istemcinin onu bir görünüme gömmesini ve
             * oraya script sokulabilmesini davet ederdi. Düz metin
             * projeksiyonu donmuş kaydı DEĞİŞTİRMEZ; kayıt olduğu gibi
             * durur.
             */
            'body' => self::bodyText((string) $contract->body_html),
            'body_format' => 'plain',
            'customer_label' => $contract->term('customer_label'),
            'masked_phone' => self::maskPhone((string) ($contract->sent_to_phone ?? '')),
            'start_date' => $contract->term('start_date'),
            'end_date' => $contract->term('end_date'),
            'service_days' => array_map('intval', (array) $contract->term('service_days', [])),
            'default_quantity' => (int) $contract->term('default_quantity', 1),
            'unit_price' => (int) $contract->agreed_unit_price_kurus,
            'monthly_estimate' => $contract->term('monthly_estimate_kurus'),
            'currency' => 'TRY',
            'expires_at' => self::iso($contract->expires_at),
            'approved_at' => self::iso($contract->approved_at),
        ];
    }

    /**
     * Maskeli telefon: `0555 *** ** 33`.
     *
     * TAM NUMARA BASILMAZ. Uç kimlik istemiyor; bağlantıyı ele geçirene
     * doğrulanmış bir telefon numarası hediye etmek olurdu. Baş üç hane
     * operatör kodu, son iki hane ise "benim numaram mı" sorusunu
     * cevaplamaya yetiyor.
     */
    public static function maskPhone(string $phone): string
    {
        $digits = OtpService::normalize($phone);

        if (strlen($digits) < 10) {
            return '';
        }

        return '0'.substr($digits, 0, 3).' *** ** '.substr($digits, -2);
    }

    /**
     * Donmuş HTML'in düz metin izdüşümü.
     *
     * Blok bitişleri satır sonuna çevrilir, etiketler atılır, varlıklar
     * çözülür. Kayba uğrayan tek şey biçimlendirmedir; cümlelerin sırası ve
     * içeriği aynıdır.
     */
    public static function bodyText(string $html): string
    {
        $text = preg_replace('#<br\s*/?>#i', "\n", $html) ?? $html;
        $text = preg_replace('#</(p|li|h[1-6]|div|tr)>#i', "\n\n", $text) ?? $text;
        $text = preg_replace('#<li[^>]*>#i', '- ', $text) ?? $text;
        $text = strip_tags($text);
        $text = html_entity_decode($text, ENT_QUOTES | ENT_HTML5, 'UTF-8');

        // Satır başlarındaki girintiler HTML kaynağından geliyor; metinde
        // anlamları yok.
        $text = preg_replace('/[ \t]+\n/', "\n", $text) ?? $text;
        $text = preg_replace('/\n{3,}/', "\n\n", $text) ?? $text;

        return trim($text);
    }

    // ── Metin ve koşullar ─────────────────────────────────────────────────

    /**
     * İmzalanan koşulların tamamı — bir daha değişmez.
     *
     * `docs/control/subscriptions.md` bu yapıyı `terms_snapshot` adıyla
     * yayınlıyor; alan adları oradan birebir alındı ki panel ucunu yazan
     * ajan JSON'u olduğu gibi geçirebilsin.
     *
     * @return array<string, mixed>
     */
    private function freezeTerms(Subscription $subscription, int $priceKurus, int $termDays): array
    {
        $days = array_values(array_map('intval', (array) ($subscription->service_days ?? [])));
        sort($days);

        $quantity = max(1, (int) $subscription->default_quantity);

        // Tarih alanları gün çözünürlüğünde: zaman dilimi taşımıyorlar ve
        // `BusinessTime::at()` ile çevirmek gece yarısını bir gün
        // kaydırabilirdi.
        $start = $subscription->start_date !== null
            ? Carbon::parse($subscription->start_date)
            : BusinessTime::now();

        $serviceDayCount = $this->countServiceDays($start, $days, $termDays);

        return [
            'title' => 'Abonelik Sözleşmesi',
            'customer_label' => $this->customerLabel($subscription),
            'agreed_unit_price_kurus' => $priceKurus,
            'service_days' => $days,
            'default_quantity' => $quantity,
            'start_date' => $start->toDateString(),
            'end_date' => $subscription->end_date !== null
                ? Carbon::parse($subscription->end_date)->toDateString()
                : null,
            'payment_mode' => Subscription::PAYMENT_PREPAID,
            'menu_mode' => (string) $subscription->menu_mode,
            'delivery_type' => (string) $subscription->delivery_type,
            'term_days' => $termDays,
            'term_service_days' => $serviceDayCount,
            /*
             * AYLIK TAHMİN DE DONAR. Onaylayan kişi neyi imzaladığını
             * porsiyon fiyatından zihninde çarparak değil yazılı bir rakamla
             * görmelidir (`docs/openapi.yaml` → `monthly_estimate`). Tahmin
             * olduğu metinde açıkça yazıyor: atlanan günler düşülünce gerçek
             * tutar aşağı iner.
             */
            'monthly_estimate_kurus' => $serviceDayCount * $quantity * $priceKurus,
        ];
    }

    /**
     * Dönem içindeki servis günü sayısı.
     *
     * Takvimden sayılıyor, `termDays / 7 * günSayısı` ile tahmin
     * edilmiyor: 30 gün 4 tam hafta değil ve yuvarlama, imzalanan tutarı
     * gerçek tutardan ayırırdı.
     *
     * @param  list<int>  $serviceDays  ISO hafta günleri.
     */
    private function countServiceDays(Carbon $start, array $serviceDays, int $termDays): int
    {
        if ($serviceDays === []) {
            return 0;
        }

        $count = 0;
        $cursor = $start->copy()->startOfDay();

        for ($i = 0; $i < $termDays; $i++, $cursor->addDay()) {
            if (in_array($cursor->dayOfWeekIso, $serviceDays, true)) {
                $count++;
            }
        }

        return $count;
    }

    /**
     * Sözleşme metnini üretir — ÇAĞRILDIĞI ANDA DONAR.
     *
     * HTML burada elle kuruluyor ve dışarıdan gelen HER DEĞER `e()` ile
     * kaçırılıyor. Şablon dosyasından render edilmiyor çünkü metnin kendisi
     * kayda giriyor: bir Blade dosyası sonradan değiştiğinde eski
     * sözleşmelerin metni de değişirdi — dondurmanın tam olarak engellemek
     * istediği şey bu.
     *
     * @param  array<string, mixed>  $terms
     */
    private function composeBody(Subscription $subscription, array $terms): string
    {
        $seller = trim((string) (setting('site_name') ?: 'Benim Lezzet Dünyam'));
        $customer = (string) ($terms['customer_label'] ?? '');
        $price = self::lira((int) $terms['agreed_unit_price_kurus']);
        $quantity = (int) $terms['default_quantity'];
        $termDays = (int) $terms['term_days'];
        $estimate = self::lira((int) $terms['monthly_estimate_kurus']);
        $dayNames = self::dayNames((array) $terms['service_days']);
        $start = (string) $terms['start_date'];
        $end = $terms['end_date'] === null ? 'süresiz' : (string) $terms['end_date'];
        $menuMode = $subscription->menu_mode === Subscription::MENU_DAILY
            ? 'Her servis gününde o günün menüsü teslim edilir.'
            : 'Teslim edilecek ürünler sözleşme ekindeki listeye göredir.';

        $rows = [
            ['Servis günleri', $dayNames],
            ['Günlük porsiyon', $quantity.' porsiyon'],
            ['Porsiyon fiyatı', $price],
            ['Başlangıç', self::date($start)],
            ['Bitiş', $end === 'süresiz' ? 'Süresiz' : self::date($end)],
            ['Dönem', $termDays.' gün (peşin)'],
            ['Dönem tahmini', $estimate],
        ];

        $rowsHtml = '';
        foreach ($rows as [$label, $value]) {
            $rowsHtml .= '<tr><th>'.e($label).'</th><td>'.e($value).'</td></tr>';
        }

        return '<h2>'.e((string) $terms['title']).'</h2>'
            .'<p>İşbu sözleşme, <strong>'.e($seller).'</strong> (Hizmet Veren) ile '
            .'<strong>'.e($customer).'</strong> (Abone) arasında, aşağıdaki koşullarla '
            .'düzenlenmiştir.</p>'
            .'<h3>1. Koşullar</h3>'
            .'<table class="kosullar">'.$rowsHtml.'</table>'
            .'<h3>2. Hizmetin kapsamı</h3>'
            .'<p>'.e($menuMode).' Teslimat, sözleşmede belirtilen adrese ve saat aralığında '
            .'yapılır. Resmî tatiller ve önceden duyurulan kapalı günlerde üretim yapılmaz; '
            .'bu günler dönem tutarından düşülür.</p>'
            .'<h3>3. Ödeme</h3>'
            .'<p>Hizmet bedeli '.e((string) $termDays).' günlük dönemler hâlinde <strong>peşin</strong> '
            .'tahsil edilir. Dönem tutarı, o dönemde fiilen teslim edilecek porsiyon sayısı ile '
            .'porsiyon fiyatının çarpımıdır; yukarıdaki dönem tahmini bilgi amaçlıdır ve '
            .'atlanan günler düşüldükçe azalır. Porsiyon fiyatı dönem içinde değişmez.</p>'
            .'<h3>4. Gün atlama ve değişiklik</h3>'
            .'<p>Abone, servis gününün kesim saatine kadar o günü atlayabilir; atlanan porsiyonun '
            .'bedeli tahsil edilmez. Porsiyon sayısı ve servis günleri değişikliği, Hizmet Veren '
            .'ile mutabakat gerektirir ve yeni bir sözleşme ile belgelenir.</p>'
            .'<h3>5. Süre ve fesih</h3>'
            .'<p>Sözleşme '.e(self::date($start)).' tarihinde başlar'
            .($terms['end_date'] === null
                ? ' ve taraflardan biri feshedene kadar yürürlükte kalır.'
                : ' ve '.e(self::date((string) $terms['end_date'])).' tarihinde sona erer.')
            .' Fesih, yürürlükteki dönemin sonunda geçerli olur; peşin tahsil edilmiş dönemin '
            .'kullanılmayan günleri iade edilir.</p>'
            .'<h3>6. Onay</h3>'
            .'<p>Abone, bu sözleşmeyi kendisine SMS ile gönderilen bağlantı üzerinden okuyup, '
            .'kayıtlı telefon numarasına gelen tek kullanımlık kodu girerek onaylar. Onay anı, '
            .'onaylayanın IP adresi ve tarayıcı bilgisi kayıt altına alınır ve sözleşmenin '
            .'ayrılmaz parçasıdır.</p>';
    }

    /** @param array<int, mixed> $days */
    private static function dayNames(array $days): string
    {
        $names = [
            1 => 'Pazartesi', 2 => 'Salı', 3 => 'Çarşamba', 4 => 'Perşembe',
            5 => 'Cuma', 6 => 'Cumartesi', 7 => 'Pazar',
        ];

        $labels = [];
        foreach ($days as $day) {
            $labels[] = $names[(int) $day] ?? '';
        }

        $labels = array_values(array_filter($labels));

        return $labels === [] ? 'belirlenmedi' : implode(', ', $labels);
    }

    /** Kuruş → `1.234,56 TL`. */
    private static function lira(int $kurus): string
    {
        return number_format(Money::toDecimal($kurus), 2, ',', '.').' TL';
    }

    /** `2026-09-01` → `01.09.2026`. */
    private static function date(string $isoDate): string
    {
        return Carbon::parse($isoDate)->format('d.m.Y');
    }

    /** Sözleşmedeki zaman biçimi: ISO 8601, UTC, `Z` sonekli. */
    private static function iso(mixed $value): ?string
    {
        return $value === null ? null : Carbon::parse($value)->utc()->toIso8601ZuluString();
    }

    /**
     * Bitiş anının unix saniyesi — imzanın üçüncü parçası.
     *
     * `(string)` DÖNÜŞÜMÜ YOK: Carbon'u dizeye çevirip yeniden ayrıştırmak
     * zaman dilimi bilgisini atar ve `BusinessTime` başlığındaki 3 saatlik
     * kaymayı davet eder. Mutlak an, mutlak an olarak taşınır.
     */
    private function expiresTimestamp(SubscriptionContract $contract): int
    {
        $value = $contract->expires_at;

        return $value === null ? 0 : Carbon::parse($value)->getTimestamp();
    }

    private function customerPhone(Subscription $subscription): string
    {
        $customer = ApiCustomer::query()->find($subscription->customer_id);

        return $customer instanceof ApiCustomer ? (string) ($customer->telephone ?? '') : '';
    }

    /** Sözleşmenin karşı tarafı: kurum unvanı, yoksa ad soyad. */
    private function customerLabel(Subscription $subscription): string
    {
        $customer = ApiCustomer::query()->find($subscription->customer_id);
        if (!$customer instanceof ApiCustomer) {
            return '';
        }

        $org = trim((string) ($customer->bld_org_name ?? ''));

        return $org !== ''
            ? $org
            : trim((string) $customer->first_name.' '.(string) $customer->last_name);
    }
}
