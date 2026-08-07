<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;
use Veykemtu\BridgeApi\Models\ApiCustomer;

/**
 * Adres koordinatları — `docs/openapi.yaml` §Address.
 *
 * NEDEN AYRI DOSYA: koordinat, adres defterinin geri kalanından farklı bir
 * kurala uyuyor. Diğer alanlarda "gönderilmedi" ile "boş gönderildi" aynı
 * şeydir; koordinatta değildir:
 *
 *   - alan HİÇ gönderilmedi  → mevcut iğne KORUNUR
 *   - alan `null` gönderildi → iğne SİLİNİR
 *
 * Bu ayrım olmadan, iğnesini kaldıran müşterinin eski noktası kayıtta kalır
 * ve kurye bir daha oraya gider. Ayrım `fill()` içinde `array_key_exists` ile
 * kuruluyor; biri onu `??` ile sadeleştirdiğinde derleme bozulmaz, testler
 * susar ve kusur ancak sahada görünürdü. Aşağıdaki iki test tam olarak o
 * sadeleştirmeyi yakalar.
 *
 * Üçüncü kural: koordinat ÇİFT olarak anlamlıdır. Yarısı dolu bir kayıt
 * haritada gösterilemez ama istemci "koordinat var" sanıp iğneyi ekvatora
 * koyar; bu yüzden yarım çift yanıtta tamamen `null` döner.
 */
class AddressCoordinateTest extends TestCase
{
    // `refreshTestDatabase` bir trait metodudur; `parent::` ile çağrılamaz.
    use RefreshDatabase {
        refreshTestDatabase as private laravelRefreshTestDatabase;
    }

    private const array HEADERS = [
        'X-App-Id' => 'musteriapp',
        'X-App-Version' => '1.0.0',
        'Accept' => 'application/json',
    ];

    /** Konya Selçuklu civarı — hizmet alanının içinde gerçekçi bir nokta. */
    private const float LAT = 37.8901234;

    private const float LNG = 32.4876543;

    /** Gerekçe `ContractTest::refreshTestDatabase` üzerinde. */
    protected function refreshTestDatabase(): void
    {
        $this->assertTestDatabase();
        $this->laravelRefreshTestDatabase();
        $this->artisan('igniter:up');
    }

    /** Gerekçe `ContractTest::assertTestDatabase` üzerinde — aynı koruma. */
    private function assertTestDatabase(): void
    {
        $name = (string) DB::connection()->getDatabaseName();

        if (!str_ends_with($name, '_test')) {
            $this->fail(
                "Testler '{$name}' veritabanına bağlı ve bir sonraki adım "
                .'tüm tabloları düşürecekti.',
            );
        }
    }

    protected function setUp(): void
    {
        parent::setUp();
        $this->artisan('veykemtu:setup');
    }

    public function test_koordinat_kaydedilir_ve_tam_duyarlilikla_geri_doner(): void
    {
        $response = $this->asCustomer()->postJson('/api/addresses', $this->payload([
            'latitude' => self::LAT,
            'longitude' => self::LNG,
        ]), self::HEADERS);

        $response->assertCreated();

        // Tam eşitlik BİLEREK: sütun `DECIMAL(10,7)`. `FLOAT` olsaydı değer
        // gidip gelirken birkaç metre kayar ve "iğneyi taşımadım ama yeri
        // değişti" şikâyetine dönerdi.
        $this->assertSame(self::LAT, $response->json('latitude'));
        $this->assertSame(self::LNG, $response->json('longitude'));
    }

    public function test_koordinatsiz_adres_kabul_edilir(): void
    {
        // Harita bir kolaylık, kapı değil: konum izni vermeyen müşteri de
        // sipariş verebilmeli.
        $response = $this->asCustomer()->postJson('/api/addresses', $this->payload(), self::HEADERS);

        $response->assertCreated();
        $this->assertNull($response->json('latitude'));
        $this->assertNull($response->json('longitude'));
    }

    public function test_alan_gonderilmezse_mevcut_koordinat_korunur(): void
    {
        $id = $this->createWithPin();

        $response = $this->asCustomer()->patchJson(
            "/api/addresses/{$id}",
            $this->payload(['label' => 'Yeni etiket']),
            self::HEADERS,
        );

        $response->assertOk();
        $this->assertSame(self::LAT, $response->json('latitude'), 'Etiket düzenlemek iğneyi düşürdü.');
        $this->assertSame(self::LNG, $response->json('longitude'));
    }

    public function test_null_gonderilirse_koordinat_silinir(): void
    {
        $id = $this->createWithPin();

        $response = $this->asCustomer()->patchJson("/api/addresses/{$id}", $this->payload([
            'latitude' => null,
            'longitude' => null,
        ]), self::HEADERS);

        $response->assertOk();
        $this->assertNull($response->json('latitude'), 'İğne kaldırıldı ama kayıtta duruyor.');
        $this->assertNull($response->json('longitude'));
    }

    public function test_yarim_cift_koordinat_sayilmaz(): void
    {
        $response = $this->asCustomer()->postJson('/api/addresses', $this->payload([
            'latitude' => self::LAT,
        ]), self::HEADERS);

        $response->assertCreated();
        $this->assertNull($response->json('latitude'));
        $this->assertNull($response->json('longitude'));
    }

    public function test_aralik_disi_koordinat_reddedilir(): void
    {
        // Ters çevrilmiş enlem/boylam en sık yapılan istemci hatasıdır ve
        // sessizce kabul edilirse kurye okyanusa gönderilir.
        $this->asCustomer()
            ->postJson('/api/addresses', $this->payload([
                'latitude' => 91,
                'longitude' => 0,
            ]), self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED');

        $this->asCustomer()
            ->postJson('/api/addresses', $this->payload([
                'latitude' => 0,
                'longitude' => 181,
            ]), self::HEADERS)
            ->assertStatus(422);
    }

    public function test_hizmet_alani_disindaki_ilce_reddedilir(): void
    {
        // İstemcilerdeki kilit bir kolaylıktır; kuralı asıl uygulayan burası.
        // Eski sürüm bir uygulama ya da doğrudan atılan istek o kilidi görmez.
        $this->asCustomer()
            ->postJson('/api/addresses', $this->payload([
                'district' => 'Meram',
            ]), self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED');
    }

    public function test_hizmet_alani_disindaki_il_reddedilir(): void
    {
        $this->asCustomer()
            ->postJson('/api/addresses', $this->payload([
                'district' => 'Selçuklu',
                'city' => 'Ankara',
            ]), self::HEADERS)
            ->assertStatus(422);
    }

    public function test_ilce_buyuk_harfle_de_kabul_edilir(): void
    {
        // Eski kayıtlarda ve elle girişte ilçe adı büyük harfle geçebiliyor;
        // aynı ilçeyi yazım yüzünden reddetmek kullanıcıya kural gibi değil
        // kusur gibi görünür.
        $this->asCustomer()
            ->postJson('/api/addresses', $this->payload([
                'district' => 'KARATAY',
            ]), self::HEADERS)
            ->assertStatus(201);
    }

    public function test_hizmet_alani_disindaki_igne_reddedilir(): void
    {
        // Aralık denetimi (`between`) yalnızca "dünya üzerinde bir yer mi"
        // diye sorar. Ankara'daki bir nokta geçerli bir koordinattır ama
        // oraya teslimat yapmıyoruz; fişteki QR kuryeyi başka şehre yollardı.
        $this->asCustomer()
            ->postJson('/api/addresses', $this->payload([
                'latitude' => 39.9208,
                'longitude' => 32.8541,
            ]), self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED');
    }

    public function test_siparis_adresi_koordinati_tasir(): void
    {
        // Sipariş adresi defterden KOPYALANIR. Koordinat kopyalanmazsa
        // mutfak fişinde ve kurye ekranında nokta kaybolur.
        $locationId = (int) $this->getJson('/api/locations', self::HEADERS)->json('data.0.id');

        $order = $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $locationId,
            // Adet 1 DEĞİL: tek porsiyon asgari sipariş tutarının altında
            // kalıyor ve sipariş, koordinatla ilgisi olmayan bir kuralla
            // reddediliyordu. Beş porsiyon eşiği her fiyat için aşar.
            'items' => [['menu_id' => $this->firstMenuId($locationId), 'quantity' => 5]],
            'delivery_type' => 'delivery',
            'payment_method' => 'cash',
            'address' => $this->payload([
                'latitude' => self::LAT,
                'longitude' => self::LNG,
            ]),
        ], self::HEADERS);

        $order->assertCreated();

        // Adres, sipariş OLUŞTURMA yanıtında yok — o yanıt bilinçli olarak
        // dar tutuluyor. Koordinatın taşındığı yer sipariş detayı; takip
        // ekranı ve mutfak fişi de oradan besleniyor.
        $detail = $this->asCustomer()->getJson('/api/orders/'.$order->json('id'), self::HEADERS);

        $detail->assertOk();
        $this->assertSame(self::LAT, $detail->json('address.latitude'));
        $this->assertSame(self::LNG, $detail->json('address.longitude'));
    }

    public function test_siparis_hizmet_alani_disina_verilemez(): void
    {
        // Defter ucu kısıtlı ama sipariş ucu serbest kalsaydı, adres
        // defterine hiç uğramayan bir istek kuralı tamamen atlardı.
        $locationId = (int) $this->getJson('/api/locations', self::HEADERS)->json('data.0.id');

        $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $locationId,
            'items' => [['menu_id' => $this->firstMenuId($locationId), 'quantity' => 5]],
            'delivery_type' => 'delivery',
            'payment_method' => 'cash',
            'address' => $this->payload(['district' => 'Meram']),
        ], self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED');
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    /** @param array<string, mixed> $overrides */
    private function payload(array $overrides = []): array
    {
        return array_merge([
            'line1' => 'Atatürk Caddesi No:12',
            'district' => 'Selçuklu',
            'city' => 'Konya',
        ], $overrides);
    }

    /** İğnesi olan bir defter kaydı açar ve kimliğini döndürür. */
    private function createWithPin(): int
    {
        return (int) $this->asCustomer()->postJson('/api/addresses', $this->payload([
            'latitude' => self::LAT,
            'longitude' => self::LNG,
        ]), self::HEADERS)->json('id');
    }

    private function firstMenuId(int $locationId): int
    {
        $this->artisan('veykemtu:demo-menu');

        $categories = $this->getJson("/api/locations/{$locationId}/menu", self::HEADERS)->json('data');

        return (int) $categories[0]['items'][0]['id'];
    }

    /** Gerekçe `ContractTest::asCustomer` üzerinde — aynı akış. */
    private function asCustomer(): static
    {
        if (ApiCustomer::where('email', 'test@ornek.com')->doesntExist()) {
            $this->postJson('/api/auth/register', [
                'first_name' => 'Test',
                'last_name' => 'Müşteri',
                'email' => 'test@ornek.com',
                'telephone' => '5551234567',
                'password' => 'parola123',
                'kvkk_accepted' => true,
            ], self::HEADERS);
        }

        $token = $this->postJson('/api/auth/login', [
            'email' => 'test@ornek.com',
            'password' => 'parola123',
        ], self::HEADERS)->json('token');

        return $this->withToken($token);
    }
}
