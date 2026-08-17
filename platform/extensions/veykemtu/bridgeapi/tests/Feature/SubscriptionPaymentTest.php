<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Order;
use Illuminate\Support\Facades\DB;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Models\SubscriptionPayment;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\Payment\Payments\SimulatedPos;

/**
 * 30 günlük peşin abonelik ödemesi ve yaşam döngüsü.
 *
 * BU PAKETİN KİLİTLEDİĞİ DÖRT ŞEY:
 *
 *  1. **Ödeme aboneliği aktifleştirir, başka hiçbir şey aktifleştirmez.**
 *     `SubscriptionGenerateCommand` `status = active` süzüyor; yani ödeme
 *     alınmadan tek bir porsiyon bile mutfağa düşmemeli.
 *  2. **Yinelenen geri-arama ikinci `succeeded` üretmez.** Gerçek POS'ta
 *     callback iki kez gelebiliyor; koruma iki katmanlı ve ikincisi
 *     `UNIQUE(subscription_id, period_start)` ile ŞEMADA.
 *  3. **Tutar sunucuda hesaplanır.** İstekte tutar alanı yok; olsaydı
 *     ekrandaki tutar ile gerçek tutar ayrıştığı anda abone eksik ödeyip
 *     "kapattım" sanırdı.
 *  4. **Ödenmiş dönem bitince üretim durur ve GÜRÜLTÜLÜ durur.** Sessiz
 *     durmak, eksikliğin yemek saatinde fark edilmesi demekti.
 *  5. **Sağlayıcıdan dönüş sayfaları HİÇBİR DURUMU DEĞİŞTİRMEZ.** Mutabakat
 *     geri-aramada olur; dönüş adresi güvenilmez bir kanaldır (abone
 *     yeniler, geri tuşuna basar, bağlantıyı paylaşır). Yazsaydı her
 *     yenileme ikinci bir tahsilat denemesi olurdu.
 */
class SubscriptionPaymentTest extends KitchenTestCase
{
    /** Anlaşmalı porsiyon fiyatı (kuruş) — 150,00 TL. */
    private const int AGREED_PRICE = 15000;

    protected function setUp(): void
    {
        parent::setUp();

        config(['app.frontend_url' => 'https://ornek.test']);
    }

    // ── Mutabakat ───────────────────────────────────────────────────────

    /**
     * Eşiğin altındaki tutarda ek adım yok: sağlayıcı aynı çağrıda
     * onaylıyor, ödeme `paid` doğuyor ve abonelik `active` oluyor.
     */
    public function test_odeme_mutabakati_aboneligi_aktiflestirir(): void
    {
        // 30 gün × 1 porsiyon × 1,00 TL = 30,00 TL → OTP eşiğinin altında.
        $subscription = $this->subscription(quantity: 1, price: 100);

        $yanit = $this->asCustomer()
            ->postJson('/api/subscriptions/'.$subscription->id.'/payments', [], self::HEADERS)
            ->assertCreated()
            ->assertJsonPath('next_action', 'none')
            ->assertJsonPath('status', 'paid')
            ->assertJsonPath('currency', 'TRY')
            ->assertJsonPath('redirect_url', null)
            ->json();

        $this->assertSame(30, $yanit['portions']);
        $this->assertSame(3000, $yanit['amount']);
        $this->assertSame(100, $yanit['unit_price']);
        $this->assertNotNull($yanit['paid_at']);

        $this->assertSame(
            Subscription::STATUS_ACTIVE,
            (string) $subscription->refresh()->status,
            'ödeme kesinleşti ama abonelik aktifleşmedi',
        );

        $payment = SubscriptionPayment::query()->firstOrFail();
        $this->assertSame(SubscriptionPayment::STATUS_SUCCEEDED, (string) $payment->status);
        // Dönem 30 GÜN, takvim ayı değil.
        $this->assertSame(
            $payment->period_start->copy()->addDays(29)->toDateString(),
            $payment->period_end->toDateString(),
        );
    }

    /** Eşiğin üstünde kod isteniyor; kod doğrulanınca abonelik aktifleşir. */
    public function test_kod_isteyen_odeme_onaylaninca_aktiflestirir(): void
    {
        $subscription = $this->subscription(quantity: 20, price: self::AGREED_PRICE);

        $yanit = $this->asCustomer()
            ->postJson('/api/subscriptions/'.$subscription->id.'/payments', [], self::HEADERS)
            ->assertCreated()
            ->assertJsonPath('next_action', 'otp')
            ->assertJsonPath('status', 'pending')
            ->json();

        // Kod bekleyen ödeme aboneliği HENÜZ aktifleştirmemeli.
        $this->assertSame(Subscription::STATUS_PENDING, (string) $subscription->refresh()->status);

        $payment = SubscriptionPayment::query()->firstOrFail();
        $this->assertSame(30 * 20 * self::AGREED_PRICE, (int) $payment->amount_kurus);

        // Yoklama ucu da aynı adımı söylemeli — üç DS dönüşü yapan istemci
        // sonucu buradan okuyor.
        $this->asCustomer()
            ->getJson(
                '/api/subscriptions/'.$subscription->id.'/payments/'.$yanit['payment_id'],
                self::HEADERS,
            )
            ->assertOk()
            ->assertJsonPath('next_action', 'otp')
            ->assertJsonPath('status', 'pending');

        $this->asCustomer()
            ->postJson(
                '/api/subscriptions/'.$subscription->id.'/payments/'.$yanit['payment_id'].'/confirm',
                ['code' => SimulatedPos::expectedCode((string) $payment->hash)],
                self::HEADERS,
            )
            ->assertOk()
            ->assertJsonPath('status', 'paid')
            ->assertJsonPath('next_action', 'none');

        $this->assertSame(Subscription::STATUS_ACTIVE, (string) $subscription->refresh()->status);
    }

    /**
     * Sınırsız deneme, çalınan bir kartın kodunu aramanın önünü açardı.
     * Hak bitince ödeme `failed` kapanır ve abone yeni ödeme başlatır.
     */
    public function test_yanlis_kod_denemeyi_tuketir_hak_bitince_odeme_kapanir(): void
    {
        $subscription = $this->subscription(quantity: 20, price: self::AGREED_PRICE);

        $paymentId = (int) $this->asCustomer()
            ->postJson('/api/subscriptions/'.$subscription->id.'/payments', [], self::HEADERS)
            ->assertCreated()
            ->json('payment_id');

        $url = '/api/subscriptions/'.$subscription->id.'/payments/'.$paymentId.'/confirm';

        for ($i = 0; $i < 3; $i++) {
            $this->asCustomer()
                ->postJson($url, ['code' => '000000'], self::HEADERS)
                ->assertStatus(422);
        }

        $this->assertSame(
            SubscriptionPayment::STATUS_FAILED,
            (string) SubscriptionPayment::query()->findOrFail($paymentId)->status,
        );
        $this->assertSame(Subscription::STATUS_PENDING, (string) $subscription->refresh()->status);

        // Kapanmış ödemeye doğru kod da işlemez.
        $this->asCustomer()->postJson($url, ['code' => '123456'], self::HEADERS)->assertStatus(422);
    }

    // ── Çift geri-arama ─────────────────────────────────────────────────

    /**
     * ASIL KİLİT BURADA.
     *
     * Sağlayıcı sayfası iki kez gönderim yapsa da ikinci `succeeded` satırı
     * doğmamalı ve mutabakat anı değişmemeli. `UNIQUE(subscription_id,
     * period_start)` zaten ikinci satırı engelliyor; `status` denetimi de
     * mevcut satırın ikinci kez işlenmesini engelliyor.
     */
    public function test_yinelenen_geri_arama_ikinci_succeeded_satiri_uretmez(): void
    {
        $subscription = $this->subscription(quantity: 20, price: self::AGREED_PRICE);

        $this->asCustomer()
            ->postJson('/api/subscriptions/'.$subscription->id.'/payments', [], self::HEADERS)
            ->assertCreated();

        $payment = SubscriptionPayment::query()->firstOrFail();
        $adres = '/abonelik-odeme-simulasyon/'.$payment->hash;

        $this->post($adres, $this->kart())
            ->assertRedirect('https://ornek.test/hesabim/abonelik?durum=odendi');

        $payment->refresh();
        $ilkMutabakat = (string) $payment->settled_at;
        $this->assertSame(SubscriptionPayment::STATUS_SUCCEEDED, (string) $payment->status);
        $this->assertSame(Subscription::STATUS_ACTIVE, (string) $subscription->refresh()->status);

        // İKİNCİ GERİ-ARAMA.
        $this->post($adres, $this->kart())
            ->assertRedirect('https://ornek.test/hesabim/abonelik?durum=zaten_odendi');

        $this->assertSame(
            1,
            SubscriptionPayment::query()
                ->where('subscription_id', $subscription->id)
                ->where('status', SubscriptionPayment::STATUS_SUCCEEDED)
                ->count(),
            'ikinci geri-arama ikinci bir succeeded satırı üretti',
        );
        $this->assertSame($ilkMutabakat, (string) $payment->refresh()->settled_at);
    }

    /** Aynı dönem için ikinci niyet açılmaz; mevcut kayıt 200 ile döner. */
    public function test_ayni_donem_icin_ikinci_niyet_acilmaz(): void
    {
        $subscription = $this->subscription(quantity: 20, price: self::AGREED_PRICE);
        $url = '/api/subscriptions/'.$subscription->id.'/payments';

        $ilk = (int) $this->asCustomer()->postJson($url, [], self::HEADERS)
            ->assertCreated()->json('payment_id');

        $ikinci = (int) $this->asCustomer()->postJson($url, [], self::HEADERS)
            ->assertOk()
            ->assertJsonPath('next_action', 'otp')
            ->json('payment_id');

        $this->assertSame($ilk, $ikinci);
        $this->assertSame(1, SubscriptionPayment::query()->count());
    }

    /**
     * Dönemin ortasında bir sonraki dönem AÇILMAZ.
     *
     * Açılsaydı bu uç her çağrıldığında yeni bir dönem doğar, abone on iki
     * dönemi peşin ödeyebilir ve iptalde elle iade edilecek bir yığın kalırdı.
     */
    public function test_odenmis_donem_icin_yeni_odeme_REDDEDILIR(): void
    {
        $subscription = $this->subscription(quantity: 1, price: 100);
        $url = '/api/subscriptions/'.$subscription->id.'/payments';

        $this->asCustomer()->postJson($url, [], self::HEADERS)->assertCreated();
        $this->asCustomer()->postJson($url, [], self::HEADERS)->assertStatus(422);

        $this->assertSame(1, SubscriptionPayment::query()->count());
    }

    /**
     * Dönemin son günlerinde yenileme açılır ve yeni dönem ESKİSİNİN
     * ERTESİ GÜNÜ başlar.
     *
     * Yenileme ancak dönem bittikten sonra açılabilseydi, o sabahın gece
     * üretimi çoktan koşmuş ve abonelik duraklatılmış olurdu — her
     * yenilemede bir günlük yemek düşerdi.
     */
    public function test_yenileme_penceresinde_sonraki_donem_odenebilir(): void
    {
        $subscription = $this->subscription(quantity: 1, price: 100, status: Subscription::STATUS_ACTIVE);
        $current = $this->paidPeriod($subscription, startsDaysAgo: 25);

        $this->asCustomer()
            ->postJson('/api/subscriptions/'.$subscription->id.'/payments', [], self::HEADERS)
            ->assertCreated()
            ->assertJsonPath(
                'period_start',
                $current->period_end->copy()->addDay()->toDateString(),
            );

        $this->assertSame(2, SubscriptionPayment::query()->count());
    }

    // ── Yetki ve doğrulama ──────────────────────────────────────────────

    /** Fiyatı olmayan talep ödenemez: neyin ödeneceği belli değil. */
    public function test_fiyatlanmamis_abonelik_odeme_baslatamaz(): void
    {
        $subscription = $this->subscription(quantity: 20, price: null);

        $this->asCustomer()
            ->postJson('/api/subscriptions/'.$subscription->id.'/payments', [], self::HEADERS)
            ->assertStatus(422);

        $this->assertSame(0, SubscriptionPayment::query()->count());
    }

    /** Başkasının aboneliği için 404 — varlığını sızdırmamak için 403 değil. */
    public function test_baskasinin_aboneligi_icin_odeme_baslatilamaz(): void
    {
        $subscription = $this->subscription(quantity: 1, price: 100);

        $this->postJson('/api/auth/register', $this->registerPayload([
            'email' => 'yabanci@ornek.com',
            'telephone' => '5559998877',
        ]), self::HEADERS)->assertCreated();

        $token = $this->postJson('/api/auth/login', [
            'email' => 'yabanci@ornek.com', 'password' => 'parola123',
        ], self::HEADERS)->json('token');

        $this->withToken($token)
            ->postJson('/api/subscriptions/'.$subscription->id.'/payments', [], self::HEADERS)
            ->assertNotFound();

        $this->assertSame(0, SubscriptionPayment::query()->count());
    }

    // ── Üretim kapısı ───────────────────────────────────────────────────

    /** Ödeme alınmadan tek porsiyon bile mutfağa düşmemeli. */
    public function test_odeme_yokken_uretim_calismaz(): void
    {
        $subscription = $this->subscription(quantity: 1, price: 100);
        $tomorrow = BusinessTime::now()->addDay()->toDateString();

        $this->artisan('veykemtu:abonelik-uret', ['--date' => $tomorrow])->assertSuccessful();
        $this->assertSame(0, $this->orderCount($subscription));

        $this->asCustomer()
            ->postJson('/api/subscriptions/'.$subscription->id.'/payments', [], self::HEADERS)
            ->assertCreated();

        $this->artisan('veykemtu:abonelik-uret', ['--date' => $tomorrow])->assertSuccessful();
        $this->assertSame(1, $this->orderCount($subscription));
    }

    /** Ödenmiş dönem dolduysa gece işi aboneliği duraklatır ve üretmez. */
    public function test_odenmis_donem_bitince_gece_isi_duraklatir(): void
    {
        $subscription = $this->subscription(quantity: 1, price: 100, status: Subscription::STATUS_ACTIVE);
        $this->paidPeriod($subscription, startsDaysAgo: 40);

        $tomorrow = BusinessTime::now()->addDay()->toDateString();

        $this->artisan('veykemtu:abonelik-uret', ['--date' => $tomorrow])->assertSuccessful();

        $this->assertSame(Subscription::STATUS_PAUSED, (string) $subscription->refresh()->status);
        $this->assertSame(0, $this->orderCount($subscription));
    }

    /** Dönem sürüyorsa hiçbir şey duraklatılmaz. */
    public function test_suren_donemde_uretim_devam_eder(): void
    {
        $subscription = $this->subscription(quantity: 1, price: 100, status: Subscription::STATUS_ACTIVE);
        $this->paidPeriod($subscription, startsDaysAgo: 3);

        $this->artisan('veykemtu:abonelik-uret', [
            '--date' => BusinessTime::now()->addDay()->toDateString(),
        ])->assertSuccessful();

        $this->assertSame(Subscription::STATUS_ACTIVE, (string) $subscription->refresh()->status);
        $this->assertSame(1, $this->orderCount($subscription));
    }

    /**
     * ÖDEME KAYDI HİÇ OLMAYAN ABONELİK DURAKLATILMAZ.
     *
     * Böyle bir abonelik Kontrol Merkezi'nden elle aktifleştirilmiştir
     * (kurumsal anlaşma, deneme dönemi). Onu "ödenmemiş" sayıp gece sessizce
     * duraklatmak, yöneticinin bilinçli kararını geri almak olurdu.
     */
    public function test_odeme_kaydi_olmayan_elle_aktif_abonelik_duraklatilmaz(): void
    {
        $subscription = $this->subscription(quantity: 1, price: 100, status: Subscription::STATUS_ACTIVE);

        $this->artisan('veykemtu:abonelik-uret', [
            '--date' => BusinessTime::now()->addDay()->toDateString(),
        ])->assertSuccessful();

        $this->assertSame(Subscription::STATUS_ACTIVE, (string) $subscription->refresh()->status);
        $this->assertSame(1, $this->orderCount($subscription));
    }

    // ── Sözleşme yüzeyi ─────────────────────────────────────────────────

    /**
     * Abonelik gövdesindeki `payment` özeti — abone "şu an ne bekleniyor"u
     * ödeme uçlarına hiç gitmeden görebilmeli.
     */
    public function test_abonelik_ozeti_yururlukteki_donem_odemesini_tasir(): void
    {
        $subscription = $this->subscription(quantity: 1, price: 100);

        // Henüz niyet yok: önizleme, `payment_id` NULL.
        $ozet = $this->asCustomer()
            ->getJson('/api/subscriptions/'.$subscription->id, self::HEADERS)
            ->assertOk()
            ->json('payment');

        $this->assertNull($ozet['payment_id']);
        $this->assertSame(3000, $ozet['amount']);
        $this->assertSame('pending', $ozet['status']);
        $this->assertMatchesRegularExpression('/^\d{4}-\d{2}$/', $ozet['period']);

        $this->asCustomer()
            ->postJson('/api/subscriptions/'.$subscription->id.'/payments', [], self::HEADERS)
            ->assertCreated();

        $ozet = $this->asCustomer()
            ->getJson('/api/subscriptions/'.$subscription->id, self::HEADERS)
            ->assertOk()
            ->json('payment');

        $this->assertNotNull($ozet['payment_id']);
        $this->assertSame('paid', $ozet['status']);
    }

    /** Fiyatlanmamış talepte özet `null` — sıfır göstermek "bedava" demekti. */
    public function test_fiyatsiz_talepte_odeme_ozeti_null(): void
    {
        $subscription = $this->subscription(quantity: 20, price: null);

        $this->asCustomer()
            ->getJson('/api/subscriptions/'.$subscription->id, self::HEADERS)
            ->assertOk()
            ->assertJsonPath('payment', null);
    }

    // ── Sağlayıcıdan dönüş sayfaları ────────────────────────────────────

    /**
     * Bilinmeyen hash 404 ve ödeme hakkında TEK KELİME sızdırmaz.
     *
     * Hash tahmin edilemez olduğu için "bulundu / bulunamadı" ayrımı zaten
     * bilgi taşımaz; asıl kural gövdede: dönem ya da tutar görünseydi adres
     * tarayarak abonelik okumanın önü açılırdı.
     */
    public function test_bilinmeyen_hash_donus_sayfalarinda_404(): void
    {
        $hash = str_repeat('a', 64);

        foreach ([$this->resultUrl($hash), $this->cancelUrl($hash)] as $adres) {
            $this->get($adres)
                ->assertNotFound()
                ->assertSee('Ödeme kaydı bulunamadı')
                ->assertDontSee('Dönem özeti');
        }
    }

    /**
     * Sağlayıcı geri bıraktı ama sonucu bildirmedi: sayfa "beklemede" der.
     *
     * "Başarısız" deseydik, saniyeler sonra kesinleşecek bir ödemeyi abone
     * ikinci kez yapmaya kalkardı.
     */
    public function test_bekleyen_niyet_beklemede_sayfasi_gosterir(): void
    {
        $subscription = $this->subscription(quantity: 20, price: self::AGREED_PRICE);

        $this->asCustomer()
            ->postJson('/api/subscriptions/'.$subscription->id.'/payments', [], self::HEADERS)
            ->assertCreated()
            ->assertJsonPath('status', 'pending');

        $payment = SubscriptionPayment::query()->firstOrFail();

        $this->get($this->resultUrl((string) $payment->hash))
            ->assertOk()
            ->assertSee('Ödemeniz sonuçlanmadı')
            // Abonelik hangi durumda: sayfa kendi kendine yetmeli.
            ->assertSee('Ödeme bekliyor');

        // SAYFA OKUMADIR: ne niyet ne abonelik kımıldar.
        $this->assertSame(
            SubscriptionPayment::STATUS_PENDING,
            (string) $payment->refresh()->status,
        );
        $this->assertSame(Subscription::STATUS_PENDING, (string) $subscription->refresh()->status);
    }

    /** Kesinleşmiş ödeme: başarı sayfası ve abonelik `active`. */
    public function test_basarili_niyet_basarili_sayfasi_gosterir(): void
    {
        $subscription = $this->subscription(quantity: 1, price: 100);

        $this->asCustomer()
            ->postJson('/api/subscriptions/'.$subscription->id.'/payments', [], self::HEADERS)
            ->assertCreated()
            ->assertJsonPath('status', 'paid');

        $payment = SubscriptionPayment::query()->firstOrFail();

        $this->get($this->resultUrl((string) $payment->hash))
            ->assertOk()
            ->assertSee('Ödemeniz alındı')
            ->assertSee('Aktif')
            // Tutarın çarpanları ekranda: "neden bu kadar ödedim" sayfayı
            // kapatmadan cevaplanabilmeli.
            ->assertSee('30 × 1,00');

        $this->assertSame(Subscription::STATUS_ACTIVE, (string) $subscription->refresh()->status);
    }

    /**
     * İptal sayfası niyeti BOZMAZ; aynı dönem kaldığı yerden ödenebilir.
     *
     * Niyeti `failed` yazsaydık abone tekrar denediğinde kayıt taze bir
     * `hash` ile yeniden doğar, yani sağlayıcıda hâlâ yaşayabilecek eski
     * işlem numarasını kendi elimizle kayıttan düşürürdük.
     */
    public function test_iptal_sayfasi_niyeti_bozmaz_ve_tekrar_odenebilir(): void
    {
        $subscription = $this->subscription(quantity: 20, price: self::AGREED_PRICE);
        $url = '/api/subscriptions/'.$subscription->id.'/payments';

        $ilk = (int) $this->asCustomer()->postJson($url, [], self::HEADERS)
            ->assertCreated()->json('payment_id');

        $payment = SubscriptionPayment::query()->firstOrFail();

        $this->get($this->cancelUrl((string) $payment->hash))
            ->assertOk()
            ->assertSee('Ödemeden vazgeçtiniz')
            ->assertSee('Ödeme bekliyor');

        $this->assertSame(
            SubscriptionPayment::STATUS_PENDING,
            (string) $payment->refresh()->status,
            'iptal sayfası niyeti kapattı',
        );
        $this->assertSame(Subscription::STATUS_PENDING, (string) $subscription->refresh()->status);

        // Aynı dönem, aynı kayıt: ikinci niyet açılmıyor.
        $this->asCustomer()->postJson($url, [], self::HEADERS)
            ->assertOk()
            ->assertJsonPath('payment_id', $ilk)
            ->assertJsonPath('next_action', 'otp');

        // Ve kod hâlâ işliyor — vazgeçmek ödemeyi öldürmedi.
        $this->asCustomer()
            ->postJson(
                $url.'/'.$ilk.'/confirm',
                ['code' => SimulatedPos::expectedCode((string) $payment->hash)],
                self::HEADERS,
            )
            ->assertOk()
            ->assertJsonPath('status', 'paid');

        $this->assertSame(1, SubscriptionPayment::query()->count());
    }

    /**
     * SAYFAYI KAÇ KEZ AÇARSAN AÇ HİÇBİR ŞEY DEĞİŞMEZ.
     *
     * Dönüş adresi paylaşılabilir, yenilenebilir, geri tuşuyla tekrar
     * ziyaret edilebilir. Mutabakat anı ve durum sabit kalmalı; iptal adresi
     * geri-aramadan SONRA açıldığında da "vazgeçtiniz" demek yerine kaydın
     * gerçeğini göstermeli.
     */
    public function test_donus_sayfalarini_tekrar_acmak_hicbir_durumu_degistirmez(): void
    {
        $subscription = $this->subscription(quantity: 1, price: 100);

        $this->asCustomer()
            ->postJson('/api/subscriptions/'.$subscription->id.'/payments', [], self::HEADERS)
            ->assertCreated();

        $payment = SubscriptionPayment::query()->firstOrFail();
        $mutabakat = (string) $payment->settled_at;

        $this->get($this->resultUrl((string) $payment->hash))->assertOk();
        $this->get($this->resultUrl((string) $payment->hash))->assertOk();

        // İPTAL ADRESİ ÖDENMİŞ NİYETTE: kayıt ne diyorsa o gösterilir.
        $this->get($this->cancelUrl((string) $payment->hash))
            ->assertOk()
            ->assertSee('Ödemeniz alındı')
            ->assertDontSee('vazgeçtiniz');

        $payment->refresh();
        $this->assertSame(SubscriptionPayment::STATUS_SUCCEEDED, (string) $payment->status);
        $this->assertSame($mutabakat, (string) $payment->settled_at, 'mutabakat anı kaydı');
        $this->assertSame(Subscription::STATUS_ACTIVE, (string) $subscription->refresh()->status);
        $this->assertSame(1, SubscriptionPayment::query()->count());
    }

    // ── Yardımcılar ─────────────────────────────────────────────────────

    /*
     * ADRESLER ELLE YAZILI, `route()` İLE ÇÖZÜLMÜYOR: `routes/web.php`
     * yolları da metot adları gibi SABİTLİYOR ve sanal POS yapılandırmasına
     * elle girilen adres bunlar. `route()` kullansaydık yol bir gün
     * değiştiğinde test yine yeşil kalır, sağlayıcıdaki adres ölürdü.
     */
    private function resultUrl(string $hash): string
    {
        return '/abonelik-odemesi/'.$hash.'/sonuc';
    }

    private function cancelUrl(string $hash): string
    {
        return '/abonelik-odemesi/'.$hash.'/iptal';
    }

    private function subscription(
        int $quantity,
        ?int $price,
        string $status = Subscription::STATUS_PENDING,
    ): Subscription {
        $subscription = new Subscription;
        $subscription->customer_id = $this->corporateCustomer()->customer_id;
        $subscription->location_id = $this->locationId();
        $subscription->status = $status;
        // Bugün başlıyor: ilk dönem bugünden itibaren 30 gün ve yarının
        // üretimi bu dönemin içinde kalıyor.
        $subscription->start_date = BusinessTime::now()->toDateString();
        $subscription->end_date = null;
        $subscription->delivery_type = 'pickup';
        $subscription->service_days = [1, 2, 3, 4, 5, 6, 7];
        $subscription->menu_mode = Subscription::MENU_FIXED_LIST;
        $subscription->default_quantity = $quantity;
        $subscription->agreed_unit_price_kurus = $price;
        $subscription->payment_mode = Subscription::PAYMENT_PREPAID;
        $subscription->save();

        DB::table('veykemtu_subscription_lines')->insert([
            'subscription_id' => $subscription->id,
            'menu_id' => $this->menuId('Tavuk Sote'),
            'quantity' => 1,
            'agreed_unit_price_kurus' => null,
            'label' => null,
        ]);

        return $subscription->refresh();
    }

    /** Geçmişte başlamış, 30 günlük, ödenmiş bir dönem yazar. */
    private function paidPeriod(Subscription $subscription, int $startsDaysAgo): SubscriptionPayment
    {
        $start = BusinessTime::now()->subDays($startsDaysAgo)->startOfDay();

        $payment = new SubscriptionPayment;
        $payment->subscription_id = (int) $subscription->id;
        $payment->period_start = $start->toDateString();
        $payment->period_end = $start->copy()->addDays(SubscriptionPayment::PERIOD_DAYS - 1)->toDateString();
        $payment->portions_planned = 30;
        $payment->unit_price_kurus = 100;
        $payment->amount_kurus = 3000;
        $payment->status = SubscriptionPayment::STATUS_SUCCEEDED;
        $payment->hash = bin2hex(random_bytes(16));
        $payment->gateway = SimulatedPos::CODE;
        $payment->provider_ref = 'SIM-TEST';
        $payment->created_at = BusinessTime::forStorage($start);
        $payment->settled_at = BusinessTime::forStorage($start);
        $payment->save();

        return $payment;
    }

    /** Simülasyon sayfasının kart formu — biçimi doğru, her kart onaylanır. */
    private function kart(): array
    {
        return [
            'kart_no' => '4111 1111 1111 1111',
            'ad_soyad' => 'TEST KULLANICI',
            'son_kullanma' => '12/30',
            'cvv' => '123',
        ];
    }

    private function orderCount(Subscription $subscription): int
    {
        return Order::query()->where('bld_subscription_id', $subscription->id)->count();
    }

    private function corporateCustomer(): ApiCustomer
    {
        $customer = ApiCustomer::query()->where('email', 'test@ornek.com')->first();

        if ($customer === null) {
            $this->postJson('/api/auth/register', $this->registerPayload(), self::HEADERS);
            $customer = ApiCustomer::query()->where('email', 'test@ornek.com')->firstOrFail();
        }

        $customer->bld_account_type = 'corporate';
        $customer->bld_org_name = 'Test Kurumu';
        $customer->save();

        return $customer;
    }
}
