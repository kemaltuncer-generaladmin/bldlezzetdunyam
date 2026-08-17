<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Override;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Models\SubscriptionContract;
use Veykemtu\BridgeApi\Services\ContractService;
use Veykemtu\BridgeApi\Services\Sms\SmsSender;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\BridgeApi\Support\SignedLink;

/**
 * Abonelik sözleşmesi — imzalı link + SMS OTP onayı (iş kararı 9).
 *
 * BU AKIŞ BİR İMZA KAPISI, yani hata payı yok. Testler dört şeyi sabitliyor:
 *
 *  1. **Bağlantının kendisi yetkidir.** Kurcalanmış imza `403`, süresi dolmuş
 *     bağlantı `410`; ikisi de veritabanına hiç dokunmadan.
 *  2. **Metin ve fiyat DONAR.** Sözleşme yazıldıktan sonra abonelikte yapılan
 *     değişiklik, müşterinin gördüğü belgeyi değiştirmez.
 *  3. **İkinci etken şart.** İmzalı bağlantı tek başına onaylatmaz; kod
 *     sözleşmenin kayıtlı numarasına gider ve beş yanlış denemede ölür.
 *  4. **Onay ödeme demek değil.** Damgalar yazılır ama abonelik `active`
 *     olmaz — 30 günlük peşin ödeme daha yapılmadı.
 */
class SubscriptionContractTest extends KitchenTestCase
{
    private const string SECRET = 'test-sozlesme-sirri-0123456789abcd';

    private const string PHONE = '5321234567';

    private const int PRICE = 16000;

    /** @var list<array{phone: string, message: string}> */
    private array $sent = [];

    #[Override]
    protected function setUp(): void
    {
        parent::setUp();

        putenv('BLD_LINK_SECRET='.self::SECRET);
        $_ENV['BLD_LINK_SECRET'] = self::SECRET;

        // Sahte gönderici: `SmsSender` arayüzü tam olarak bunun için var.
        $this->sent = [];
        $this->app->instance(SmsSender::class, new class($this->sent) implements SmsSender
        {
            /** @param list<array{phone: string, message: string}> $sink */
            public function __construct(private array &$sink) {}

            public function send(string $phone, string $message): void
            {
                $this->sink[] = ['phone' => $phone, 'message' => $message];
            }
        });
    }

    #[Override]
    protected function tearDown(): void
    {
        putenv('BLD_LINK_SECRET');
        unset($_ENV['BLD_LINK_SECRET']);

        parent::tearDown();
    }

    // ── Bağlantı ──────────────────────────────────────────────────────────

    /**
     * KURCALANMIŞ İMZA → 403.
     *
     * Tek karakter değişmesi yeter. Sayfa veritabanına hiç bakmadan
     * dönüyor: bakmış olsaydı var olan ve olmayan sözleşme farklı
     * davranır, elinde bağlantı olmayan biri kimlik tarayabilirdi.
     */
    public function test_kurcalanmis_imza_403_doner(): void
    {
        [$id, $expires, $signature] = $this->link($this->contract());

        $this->get('/sozlesme/'.$id.'/'.$expires.'/'.$this->tamper($signature))
            ->assertStatus(403)
            ->assertSee('Bağlantı geçersiz');
    }

    /**
     * BAŞKA AMACIN İMZASI SÖZLEŞMEYE ÇÖZÜLMEZ.
     *
     * Amaç HMAC'in İÇİNDE. Aynı kimlik ve aynı bitiş anı için üretilmiş bir
     * takip bağlantısı burada da geçseydi, siparişini takip eden müşteri
     * aynı imzayla sözleşme onaylayabilirdi.
     */
    public function test_takip_imzasi_sozlesme_sayfasinda_gecmez(): void
    {
        [$id, $expires] = $this->link($this->contract());

        $baskaAmac = SignedLink::sign(SignedLink::PURPOSE_TRACK, (int) $id, (int) $expires);

        $this->get('/sozlesme/'.$id.'/'.$expires.'/'.$baskaAmac)->assertStatus(403);
    }

    /**
     * SÜRESİ GEÇMİŞ BAĞLANTI → 410 (`Gone`).
     *
     * `404` değil: adres vardı, artık yok. Fark yalnız semantik de değil —
     * `410` arama motorlarına ve paylaşılan bağlantılara "bir daha deneme"
     * diyor.
     */
    public function test_suresi_gecmis_baglanti_410_doner(): void
    {
        $contract = $this->expire($this->contract());

        $this->get($this->service()->signUrl($contract))
            ->assertStatus(410)
            ->assertSee('süresi doldu');
    }

    /**
     * BAĞLANTI YENİLENİNCE ESKİSİ ÖLÜR.
     *
     * Token türetilmiş (`{id}-{bitiş}-{imza}`) ve kayıttaki özet yalnız
     * yürürlükteki bağlantıya ait. Eski bağlantının imzası hâlâ doğru
     * olduğu için imza denetimi tek başına yetmez; özet denetimi burayı
     * kapatıyor.
     */
    public function test_sure_tazelenince_eski_baglanti_olur(): void
    {
        $contract = $this->contract();
        $eskiUrl = $this->service()->signUrl($contract);

        // Aynı saniyede kalıp aynı bitiş anını üretmesin diye ileri bir gün.
        $this->service()->issueLink($contract, 14);

        $this->assertNotSame($eskiUrl, $this->service()->signUrl($contract));
        $this->get($eskiUrl)->assertStatus(403);
        $this->get($this->service()->signUrl($contract))->assertOk();
    }

    /**
     * YENİDEN GÖNDERİM SÜREYE DOKUNMAZSA BAĞLANTI AYNI KALIR.
     *
     * `docs/control/subscriptions.md`: "Yeni token üretilmez — müşterinin
     * elindeki eski SMS'in çalışmaya devam etmesi, 'hangi linke
     * tıklayacağım' sorusunu ortadan kaldırır."
     */
    public function test_yeniden_gonderim_ayni_baglantiyi_yollar(): void
    {
        $contract = $this->contract();
        $url = $this->service()->signUrl($contract);

        $this->service()->resend($contract);

        $this->assertSame($url, $this->service()->signUrl($contract));
        $this->assertStringContainsString($url, end($this->sent)['message']);
    }

    // ── Sayfa ─────────────────────────────────────────────────────────────

    /**
     * DOĞRU BAĞLANTI → 200 VE DONMUŞ FİYAT.
     *
     * Sözleşme yazıldıktan SONRA abonelikte fiyat değişse bile sayfada
     * anlaşılan rakam duruyor. Aksi hâlde müşteri, onayladığı belgeden
     * başka bir belgeye bakıyor olurdu.
     */
    public function test_dogru_baglanti_donmus_fiyati_gosterir(): void
    {
        $subscription = $this->subscription();
        $contract = $this->contract($subscription);

        $subscription->agreed_unit_price_kurus = 99900;
        $subscription->save();

        $this->get($this->service()->signUrl($contract))
            ->assertOk()
            ->assertSee('160,00 TL')
            ->assertDontSee('999,00 TL');
    }

    /** Sayfa, kodun gideceği numarayı maskeli gösterir. */
    public function test_sayfa_telefonu_maskeli_gosterir(): void
    {
        $contract = $this->contract();

        $this->get($this->service()->signUrl($contract))
            ->assertOk()
            ->assertSee('0532 *** ** 67')
            ->assertDontSee(self::PHONE);
    }

    // ── API ───────────────────────────────────────────────────────────────

    /** Tanınmayan belirteç `404` — süresi dolmuş bağlantıdan AYRIDIR. */
    public function test_api_tanimayan_belirtec_404_doner(): void
    {
        $this->getJson('/api/contracts/'.str_repeat('x', 40), self::HEADERS)
            ->assertStatus(404)
            ->assertJsonPath('error.code', 'NOT_FOUND');
    }

    /**
     * API'DE SÜRESİ DOLMUŞ BAĞLANTI `410` DEĞİL, `200` + `status: expired`.
     *
     * İstemci "bu bağlantının süresi doldu, yenisini isteyin" cümlesini
     * kurabilmeli; boş bir hata gövdesiyle o ekran çizilemez. Sayfanın `410`
     * dönmesiyle çelişmiyor: ikisi farklı izleyiciye konuşuyor.
     */
    public function test_api_suresi_dolmus_baglanti_200_ve_expired_doner(): void
    {
        $contract = $this->expire($this->contract());

        $this->getJson('/api/contracts/'.$this->service()->tokenFor($contract), self::HEADERS)
            ->assertOk()
            ->assertJsonPath('data.status', SubscriptionContract::STATUS_EXPIRED)
            ->assertJsonPath('data.unit_price', self::PRICE);
    }

    /**
     * Yanıt DAR: metin düz gider, telefon maskelidir, müşteri kimliği yoktur.
     *
     * HTML gönderilseydi istemci onu bir görünüme gömer ve oraya script
     * sokulabilirdi (`docs/03-api-sozlesmesi.md` §15.4).
     */
    public function test_api_metni_duz_gonderir(): void
    {
        $contract = $this->contract();

        $data = $this->getJson('/api/contracts/'.$this->service()->tokenFor($contract), self::HEADERS)
            ->assertOk()
            ->assertJsonPath('data.body_format', 'plain')
            ->assertJsonPath('data.currency', 'TRY')
            ->assertJsonPath('data.masked_phone', '0532 *** ** 67')
            ->json('data');

        $this->assertStringNotContainsString('<', (string) $data['body']);
        $this->assertStringContainsString('Abonelik Sözleşmesi', (string) $data['body']);
        $this->assertSame(1, $data['version'], 'sözleşme sürümü tam sayı yayınlanır');
        $this->assertArrayNotHasKey('customer_id', $data);
    }

    // ── Onay ──────────────────────────────────────────────────────────────

    /**
     * BEŞ YANLIŞ DENEME KODU ÖLDÜRÜR VE SÖZLEŞME `sent` KALIR.
     *
     * Sayaç KODA bağlı (`OtpService`), IP'ye değil: bağlantıyı eline
     * geçiren biri IP değiştirerek 10^6 olasılığı tarayamaz. Ölen kodun
     * ardından DOĞRU kod bile kabul edilmiyor — yeni kod istenmeli.
     */
    public function test_bes_yanlis_kod_kodu_oldurur_sozlesme_sent_kalir(): void
    {
        $contract = $this->contract();
        $token = $this->service()->tokenFor($contract);

        $this->postJson('/api/contracts/'.$token.'/otp', [], self::HEADERS)->assertStatus(202);
        $dogru = $this->lastCode();

        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/contracts/'.$token.'/approve', [
                'code' => $this->wrongCode(),
            ], self::HEADERS)->assertStatus(422)->assertJsonPath('error.code', 'VALIDATION_FAILED');
        }

        $this->postJson('/api/contracts/'.$token.'/approve', ['code' => $dogru], self::HEADERS)
            ->assertStatus(422);

        $contract->refresh();
        $this->assertSame(SubscriptionContract::STATUS_SENT, $contract->status);
        $this->assertNull($contract->approved_at, 'hiçbir damga yazılmamalı');
        $this->assertNull($contract->otp_verified_at);
    }

    /**
     * DOĞRU KOD → DAMGALAR YAZILIR, ABONELİK HÂLÂ AKTİF DEĞİL.
     *
     * Onay ödemenin yerine geçmez: 30 günlük peşin ödeme yapılmadan üretim
     * başlarsa, ödenmemiş bir aboneliğin yemeği pişer.
     */
    public function test_dogru_kod_damgalari_yazar_abonelik_aktif_olmaz(): void
    {
        $subscription = $this->subscription();
        $contract = $this->contract($subscription);
        $token = $this->service()->tokenFor($contract);

        $this->postJson('/api/contracts/'.$token.'/otp', [], self::HEADERS)->assertStatus(202);

        $this->withHeader('User-Agent', 'Test Tarayici 1.0')
            ->postJson('/api/contracts/'.$token.'/approve', [
                'code' => $this->lastCode(),
                'full_name' => 'Ayşe Yılmaz',
            ], self::HEADERS)
            ->assertOk()
            ->assertJsonPath('data.status', SubscriptionContract::STATUS_APPROVED);

        $contract->refresh();
        $this->assertSame(SubscriptionContract::STATUS_APPROVED, $contract->status);
        $this->assertNotNull($contract->approved_at);
        $this->assertNotNull($contract->otp_verified_at);
        $this->assertSame('Ayşe Yılmaz', $contract->approved_full_name);
        $this->assertNotNull($contract->approved_ip, 'onayın IP delili tutulmalı');
        $this->assertSame('Test Tarayici 1.0', $contract->approved_user_agent);

        $subscription->refresh();
        $this->assertNotSame(
            Subscription::STATUS_ACTIVE,
            $subscription->status,
            'ödeme yapılmadan abonelik aktifleşemez',
        );
        /*
         * AKIŞ İLERLEMİŞ OLMALI. Durumun tam değeri burada BİLEREK
         * denetlenmiyor: onay sonrası geçişi `SubscriptionLifecycle` (A4)
         * devralacak ve sözlüğü o belirleyecek. Sabitlenen şey, sözleşmesi
         * onaylanmış bir aboneliğin "talep" hâlinde ÇAKILI KALMAMASI.
         */
        $this->assertNotSame(
            Subscription::STATUS_PENDING,
            $subscription->status,
            'onaydan sonra abonelik talep durumunda kalamaz',
        );
        $this->assertSame(self::PRICE, (int) $subscription->agreed_unit_price_kurus);
    }

    /**
     * İKİNCİ DOKUNUŞ HATA DEĞİL.
     *
     * SMS gecikip kullanıcı iki kez dokunuyor. Kod ilk çağrıda tüketildiği
     * için ikinci çağrıda doğrulansaydı "kod hatalı" derdi — onaylanmış bir
     * sözleşmede "onaylanamadı" yazan ekran.
     */
    public function test_onay_idempotenttir(): void
    {
        $contract = $this->contract();
        $token = $this->service()->tokenFor($contract);

        $this->postJson('/api/contracts/'.$token.'/otp', [], self::HEADERS)->assertStatus(202);
        $code = $this->lastCode();

        $ilk = $this->postJson('/api/contracts/'.$token.'/approve', ['code' => $code], self::HEADERS)
            ->assertOk()->json('data');

        $ikinci = $this->postJson('/api/contracts/'.$token.'/approve', ['code' => $code], self::HEADERS)
            ->assertOk()->json('data');

        $this->assertSame($ilk, $ikinci, 'aynı gövde dönmeli');
    }

    /** Onaylanmış sözleşmenin sayfası onay ekranını değil sonucu gösterir. */
    public function test_onaylanmis_sozlesme_sayfasi_sonucu_gosterir(): void
    {
        $contract = $this->contract();
        $token = $this->service()->tokenFor($contract);

        $this->postJson('/api/contracts/'.$token.'/otp', [], self::HEADERS)->assertStatus(202);
        $this->postJson('/api/contracts/'.$token.'/approve', [
            'code' => $this->lastCode(),
        ], self::HEADERS)->assertOk();

        $this->get($this->service()->signUrl($contract))
            ->assertOk()
            ->assertSee('Sözleşme onaylandı')
            ->assertDontSee('Onay kodu gönder');
    }

    /**
     * SÜRESİ DOLMUŞ BAĞLANTIYA KOD ISMARLANAMAZ.
     *
     * Sınır SMS maliyeti kadar güvenlik meselesi de: ölü bir bağlantıya
     * sınırsız kod gönderilebilseydi, bir yıl önceki SMS'i eline geçiren
     * bugün kod ısmarlardı.
     */
    public function test_suresi_dolmus_sozlesmeye_kod_gonderilmez(): void
    {
        $contract = $this->expire($this->contract());

        $this->postJson(
            '/api/contracts/'.$this->service()->tokenFor($contract).'/otp',
            [],
            self::HEADERS,
        )->assertStatus(422)->assertJsonPath('error.details.status', SubscriptionContract::STATUS_EXPIRED);

        $this->assertCount(1, $this->sent, 'yalnız sözleşme bağlantısı SMS\'i gitmiş olmalı');
    }

    /** Kod, İSTEKTEKİ numaraya değil sözleşmenin kayıtlı numarasına gider. */
    public function test_kod_sozlesmedeki_numaraya_gider(): void
    {
        $contract = $this->contract();

        $this->postJson('/api/contracts/'.$this->service()->tokenFor($contract).'/otp', [
            'phone' => '5559998877',
        ], self::HEADERS)->assertStatus(202);

        $this->assertSame(self::PHONE, end($this->sent)['phone']);
    }

    // ── Dondurma ──────────────────────────────────────────────────────────

    /**
     * METİN VE KOŞULLAR DONAR.
     *
     * Yalnız sürüm etiketi saklansaydı, şablon değiştiğinde müşterinin
     * "imzaladığı" metin de sessizce değişirdi.
     */
    public function test_metin_ve_kosullar_donmus_saklanir(): void
    {
        $subscription = $this->subscription();
        $contract = $this->contract($subscription);
        $metin = (string) $contract->body_html;

        $subscription->agreed_unit_price_kurus = 99900;
        $subscription->default_quantity = 5;
        $subscription->service_days = [6, 7];
        $subscription->save();

        $contract->refresh();

        $this->assertSame($metin, (string) $contract->body_html);
        $this->assertSame(self::PRICE, (int) $contract->agreed_unit_price_kurus);
        $this->assertSame([1, 2, 3, 4, 5], $contract->term('service_days'));
        $this->assertSame(20, $contract->term('default_quantity'));
        $this->assertStringContainsString('160,00 TL', $metin);
    }

    /**
     * SÜRESİ DOLMUŞ SÖZLEŞME "AÇIK" SAYILMAZ.
     *
     * Panel aynı abonelikte açık sözleşme varken ikincisini reddediyor.
     * Süresi dolmuş bir kayıt açık sayılsaydı, kimsenin onaylayamayacağı
     * bir bağlantı yüzünden yeni sözleşme hiç açılamazdı.
     */
    public function test_suresi_dolmus_sozlesme_acik_sayilmaz(): void
    {
        $subscription = $this->subscription();
        $contract = $this->contract($subscription);

        $this->assertNotNull($this->service()->openContractFor($subscription));

        $this->expire($contract);

        $this->assertNull($this->service()->openContractFor($subscription));
    }

    /** Fiyatsız abonelikten sözleşme çıkmaz. */
    public function test_fiyatsiz_abonelikten_sozlesme_uretilmez(): void
    {
        $subscription = $this->subscription();
        $subscription->agreed_unit_price_kurus = null;
        $subscription->save();

        $this->expectExceptionMessage('Sözleşme için önce porsiyon fiyatı belirlenmeli.');

        $this->service()->create($subscription);
    }

    /** Onaylanmış sözleşme iptal edilemez — imzayı geçersiz kılmak olurdu. */
    public function test_onaylanmis_sozlesme_iptal_edilemez(): void
    {
        $contract = $this->contract();
        $token = $this->service()->tokenFor($contract);

        $this->postJson('/api/contracts/'.$token.'/otp', [], self::HEADERS)->assertStatus(202);
        $this->postJson('/api/contracts/'.$token.'/approve', [
            'code' => $this->lastCode(),
        ], self::HEADERS)->assertOk();

        $this->expectExceptionMessage('Onaylanmış sözleşme iptal edilemez.');

        $this->service()->cancel($contract->refresh(), 'gerekçe');
    }

    /** İptal edilmiş sözleşme onaylanamaz ve sayfası onay düğmesi çizmez. */
    public function test_iptal_edilmis_sozlesme_onaylanamaz(): void
    {
        $contract = $this->contract();
        $this->service()->cancel($contract, 'Koşullar değişti');

        $this->postJson(
            '/api/contracts/'.$this->service()->tokenFor($contract).'/approve',
            ['code' => '123456'],
            self::HEADERS,
        )->assertStatus(422);

        $this->get($this->service()->signUrl($contract))
            ->assertOk()
            ->assertSee('Sözleşme iptal edilmiş');
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    private function service(): ContractService
    {
        return resolve(ContractService::class);
    }

    private function customer(): ApiCustomer
    {
        $customer = new ApiCustomer;
        $customer->first_name = 'Kurum';
        $customer->last_name = 'Yetkilisi';
        $customer->email = 'abonelik@ornek.com';
        $customer->telephone = self::PHONE;
        $customer->password = 'parola123';
        $customer->status = true;
        $customer->bld_org_name = 'Örnek Kurum A.Ş.';
        $customer->is_activated = true;
        $customer->activated_at = now();
        $customer->save();

        return $customer;
    }

    private function subscription(): Subscription
    {
        $subscription = new Subscription;
        $subscription->customer_id = (int) $this->customer()->customer_id;
        $subscription->location_id = $this->locationId();
        $subscription->status = Subscription::STATUS_PENDING;
        $subscription->start_date = BusinessTime::now()->addDay()->toDateString();
        $subscription->delivery_type = 'delivery';
        $subscription->service_days = [1, 2, 3, 4, 5];
        $subscription->menu_mode = Subscription::MENU_DAILY;
        $subscription->default_quantity = 20;
        $subscription->agreed_unit_price_kurus = self::PRICE;
        $subscription->payment_mode = Subscription::PAYMENT_PREPAID;
        $subscription->save();

        return $subscription;
    }

    private function contract(?Subscription $subscription = null): SubscriptionContract
    {
        $contract = $this->service()->create(
            $subscription ?? $this->subscription(),
            null,
            SignedLink::CONTRACT_TTL_DAYS,
            'Test Yönetici',
        );

        $this->service()->send($contract);

        return $contract;
    }

    /**
     * Bağlantıyı geçmişe taşır.
     *
     * `issueLink()` geçmişe bakan bir süre üretmiyor (en az 1 gün) — o
     * doğru; testin geçmişe gitmesi için kaydı ve özeti elle yazmak
     * gerekiyor, tıpkı bir hafta bekleyip açılan bağlantı gibi.
     */
    private function expire(SubscriptionContract $contract): SubscriptionContract
    {
        $past = BusinessTime::now()->subDays(2);

        $contract->expires_at = BusinessTime::forStorage($past);
        $contract->token_hash = hash(
            'sha256',
            $this->service()->tokenFor($contract, $past->getTimestamp()),
        );
        $contract->save();

        return $contract;
    }

    /**
     * `{id}-{bitiş}-{imza}` parçaları.
     *
     * `explode(..., 3)`: imza base64url ve TİRE İÇEREBİLİR; sınırsız
     * bölünürse imza ikiye ayrılır ve test sessizce yanlış şeyi doğrular.
     *
     * @return array{0: string, 1: string, 2: string}
     */
    private function link(SubscriptionContract $contract): array
    {
        $parts = explode('-', $this->service()->tokenFor($contract), 3);

        $this->assertCount(3, $parts);

        /** @var array{0: string, 1: string, 2: string} $parts */
        return $parts;
    }

    /** İmzanın tek karakterini bozar; biçim geçerli kalır. */
    private function tamper(string $signature): string
    {
        $ilk = $signature[0] === 'A' ? 'B' : 'A';

        return $ilk.substr($signature, 1);
    }

    /** Sahte göndericiye düşen son giriş kodundaki 6 hane. */
    private function lastCode(): string
    {
        foreach (array_reverse($this->sent) as $mesaj) {
            if (str_contains($mesaj['message'], 'giris kodunuz')
                && preg_match('/\b(\d{6})\b/', $mesaj['message'], $m) === 1) {
                return $m[1];
            }
        }

        $this->fail('Giriş kodu SMS\'i gönderilmemiş.');
    }

    /** Gerçek koddan kesinlikle farklı, 6 haneli bir dize. */
    private function wrongCode(): string
    {
        return $this->lastCode() === '000000' ? '111111' : '000000';
    }
}
