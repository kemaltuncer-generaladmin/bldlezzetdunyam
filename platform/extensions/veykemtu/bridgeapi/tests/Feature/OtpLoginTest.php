<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Override;
use Tests\TestCase;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Services\OtpService;
use Veykemtu\BridgeApi\Services\Sms\SmsSender;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Telefonla giriş — B-18.
 *
 * Bu akış bir KİMLİK KAPISI, yani hata payı yok. Testler üç saldırıyı ve
 * bir kullanılabilirlik tuzağını sabitliyor:
 *
 *  1. Numara sayımı: kayıtlı olmayan numara için de aynı yanıt döner.
 *  2. Kaba kuvvet: yanlış denemenin sayacı KODA bağlı, IP'ye değil.
 *  3. Yeniden kullanım: tüketilen kod bir daha kabul edilmez.
 *  4. Numara biçimi: `0555…`, `+90 555…` ve `555…` aynı kişiye çıkar.
 */
class OtpLoginTest extends TestCase
{
    use RefreshDatabase {
        refreshTestDatabase as private laravelRefreshTestDatabase;
    }

    /** Çekirdek şeması yalnızca `igniter:up` ile kurulur — bkz. ContractTest. */
    protected function refreshTestDatabase(): void
    {
        $this->laravelRefreshTestDatabase();

        $this->artisan('igniter:up');
    }

    /** @var list<array{phone: string, message: string}> */
    private array $sent = [];

    private const array HEADERS = [
        'X-App-Id' => 'website',
        'X-App-Version' => '1.0.0',
        'Accept-Language' => 'tr',
    ];

    private const string PHONE = '5551112233';

    #[Override]
    protected function setUp(): void
    {
        parent::setUp();

        /*
         * SMS sahtesi: gerçek gönderici yerine mesajı diziye yazıyor.
         * `SmsSender` arayüzü tam olarak bunun için var — testin gerçek
         * sağlayıcıya bağlanmaması ya da kodu okumak için günlük dosyası
         * ayrıştırması gerekmiyor.
         */
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

    // ── Numara normalleştirme ─────────────────────────────────────────────

    /**
     * Aynı numaranın dört yazımı da tek anahtara düşer.
     *
     * Normalleştirme olmasaydı, kayıtta `5551112233` yazan müşteri girişte
     * `0555 111 22 33` yazdığında "kayıtlı değil" muamelesi görür ve —
     * numara sayımına kapı bırakmadığımız için — sebebini asla öğrenemezdi.
     */
    public function test_telefon_yazimlari_tek_bicime_iner(): void
    {
        foreach (['5551112233', '05551112233', '+905551112233', '0555 111 22 33'] as $input) {
            $this->assertSame(self::PHONE, OtpService::normalize($input), $input);
        }
    }

    // ── Kod isteme ────────────────────────────────────────────────────────

    public function test_kayitli_numaraya_kod_gonderilir(): void
    {
        $this->customer();

        $this->postJson('/api/auth/otp/request', ['phone' => self::PHONE], self::HEADERS)
            ->assertStatus(202)
            ->assertJsonPath('expires_in', OtpService::TTL_SECONDS);

        $this->assertCount(1, $this->sent);
        $this->assertSame(self::PHONE, $this->sent[0]['phone']);
        $this->assertMatchesRegularExpression('/\b\d{6}\b/', $this->sent[0]['message']);
    }

    /**
     * NUMARA SAYIMINA KAPI YOK: kayıtsız numara da 202 alır ve yanıt gövdesi
     * birebir aynıdır. Tek fark SMS'in gitmemesi — ve bunu yalnızca numaranın
     * gerçek sahibi fark edebilir.
     */
    public function test_kayitsiz_numara_da_ayni_yaniti_alir(): void
    {
        $kayitli = $this->postJson(
            '/api/auth/otp/request',
            ['phone' => '5559998877'],
            self::HEADERS,
        )->assertStatus(202);

        $this->assertSame([], $this->sent, 'Kayıtsız numaraya SMS gitmemeli.');
        $this->assertSame(0, DB::table('veykemtu_otp_codes')->count());

        $this->customer();
        $this->sent = [];

        $ikinci = $this->postJson(
            '/api/auth/otp/request',
            ['phone' => self::PHONE],
            self::HEADERS,
        )->assertStatus(202);

        $this->assertSame(
            $kayitli->json(),
            $ikinci->json(),
            'Kayıtlı ve kayıtsız numaranın yanıtı ayırt edilememeli.',
        );
    }

    /**
     * Kod veritabanında AÇIK durmaz.
     *
     * Bir yedek sızıntısı, o anda geçerli her kodu aktif giriş anahtarına
     * çevirirdi.
     */
    public function test_kod_veritabaninda_acik_saklanmaz(): void
    {
        $this->customer();

        $this->postJson('/api/auth/otp/request', ['phone' => self::PHONE], self::HEADERS);

        $code = $this->lastCode();
        $hash = (string) DB::table('veykemtu_otp_codes')->value('code_hash');

        $this->assertNotSame($code, $hash);
        $this->assertTrue(Hash::check($code, $hash));
    }

    /**
     * 60 saniye dolmadan ikinci kod istenemez.
     *
     * Sınır yalnız arayüzdeki geri sayımda olsaydı, isteği doğrudan atan
     * biri hem SMS bütçesini hem de müşterinin telefonunu yakardı.
     */
    public function test_pes_pese_kod_istenemez(): void
    {
        $this->customer();

        $this->postJson('/api/auth/otp/request', ['phone' => self::PHONE], self::HEADERS)
            ->assertStatus(202);

        $this->postJson('/api/auth/otp/request', ['phone' => self::PHONE], self::HEADERS)
            ->assertStatus(422);

        $this->assertCount(1, $this->sent);
    }

    // ── Doğrulama ─────────────────────────────────────────────────────────

    public function test_dogru_kod_oturum_acar(): void
    {
        $customer = $this->customer();

        $this->postJson('/api/auth/otp/request', ['phone' => self::PHONE], self::HEADERS);

        $this->postJson('/api/auth/otp/verify', [
            'phone' => self::PHONE,
            'code' => $this->lastCode(),
        ], self::HEADERS)
            ->assertOk()
            ->assertJsonStructure(['token', 'customer'])
            ->assertJsonPath('customer.id', (int) $customer->customer_id);
    }

    /** Farklı yazımla girilen numara da aynı hesabı açar. */
    public function test_bicimi_farkli_numarayla_da_dogrulanir(): void
    {
        $this->customer();

        $this->postJson('/api/auth/otp/request', ['phone' => '0555 111 22 33'], self::HEADERS);

        $this->postJson('/api/auth/otp/verify', [
            'phone' => '+905551112233',
            'code' => $this->lastCode(),
        ], self::HEADERS)->assertOk();
    }

    public function test_yanlis_kod_reddedilir(): void
    {
        $this->customer();

        $this->postJson('/api/auth/otp/request', ['phone' => self::PHONE], self::HEADERS);

        $this->postJson('/api/auth/otp/verify', [
            'phone' => self::PHONE,
            'code' => $this->wrongCode(),
        ], self::HEADERS)->assertStatus(422);
    }

    /**
     * KABA KUVVET KAPISI: beş yanlış denemeden sonra kod ölür — doğru kod
     * girilse bile kabul edilmez.
     */
    public function test_bes_yanlis_denemeden_sonra_kod_oldurulur(): void
    {
        $this->customer();

        $this->postJson('/api/auth/otp/request', ['phone' => self::PHONE], self::HEADERS);
        $code = $this->lastCode();

        for ($i = 0; $i < OtpService::MAX_ATTEMPTS; $i++) {
            $this->postJson('/api/auth/otp/verify', [
                'phone' => self::PHONE,
                'code' => $this->wrongCode(),
            ], self::HEADERS)->assertStatus(422);
        }

        $this->postJson('/api/auth/otp/verify', [
            'phone' => self::PHONE,
            'code' => $code,
        ], self::HEADERS)->assertStatus(422);
    }

    /** Tüketilen kod ikinci kez kullanılamaz. */
    public function test_kullanilmis_kod_tekrar_kabul_edilmez(): void
    {
        $this->customer();

        $this->postJson('/api/auth/otp/request', ['phone' => self::PHONE], self::HEADERS);
        $code = $this->lastCode();

        $this->postJson('/api/auth/otp/verify', [
            'phone' => self::PHONE,
            'code' => $code,
        ], self::HEADERS)->assertOk();

        $this->postJson('/api/auth/otp/verify', [
            'phone' => self::PHONE,
            'code' => $code,
        ], self::HEADERS)->assertStatus(422);
    }

    public function test_suresi_dolmus_kod_kabul_edilmez(): void
    {
        $this->customer();

        $this->postJson('/api/auth/otp/request', ['phone' => self::PHONE], self::HEADERS);
        $code = $this->lastCode();

        DB::table('veykemtu_otp_codes')->update([
            'expires_at' => BusinessTime::forStorage(BusinessTime::now()->subMinute()),
        ]);

        $this->postJson('/api/auth/otp/verify', [
            'phone' => self::PHONE,
            'code' => $code,
        ], self::HEADERS)->assertStatus(422);
    }

    /**
     * Devre dışı hesap koda rağmen giremez — şifreli girişteki kuralın aynısı.
     */
    public function test_devre_disi_hesap_kodla_da_giremez(): void
    {
        $customer = $this->customer();

        $this->postJson('/api/auth/otp/request', ['phone' => self::PHONE], self::HEADERS);
        $code = $this->lastCode();

        $customer->status = false;
        $customer->save();

        $this->postJson('/api/auth/otp/verify', [
            'phone' => self::PHONE,
            'code' => $code,
        ], self::HEADERS)->assertStatus(403);
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    private function customer(): ApiCustomer
    {
        $customer = new ApiCustomer;
        $customer->first_name = 'Test';
        $customer->last_name = 'Musteri';
        $customer->email = 'otp@ornek.com';
        $customer->telephone = self::PHONE;
        $customer->password = 'parola123';
        $customer->status = true;
        $customer->bld_account_type = 'corporate';
        $customer->is_activated = true;
        $customer->activated_at = now();
        $customer->save();

        return $customer;
    }

    /** Sahte göndericiye düşen son mesajdaki 6 haneli kod. */
    private function lastCode(): string
    {
        $this->assertNotEmpty($this->sent, 'SMS gönderilmemiş.');

        preg_match('/\b(\d{6})\b/', end($this->sent)['message'], $m);

        return $m[1];
    }

    /** Gerçek koddan kesinlikle farklı, 6 haneli bir dize. */
    private function wrongCode(): string
    {
        $code = $this->lastCode();

        return $code === '000000' ? '111111' : '000000';
    }
}
