<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Order;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Models\KitchenDevice;
use Veykemtu\BridgeApi\Models\PrintJob;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;

/**
 * Sözleşme uyum testleri — `docs/openapi.yaml`.
 *
 * `docs/04-platform.md` §6: her uç için en az 200 mutlu yol, 401/403 yetki
 * ve 422 doğrulama testi. Buradaki beklentiler sözleşmeden gelir, koddan
 * değil: kod sözleşmeden saparsa test kırılmalıdır, tersi değil.
 */
class ContractTest extends TestCase
{
    use RefreshDatabase;

    private const array HEADERS = [
        'X-App-Id' => 'website',
        'X-App-Version' => '1.0.0',
        'Accept' => 'application/json',
    ];

    protected function setUp(): void
    {
        parent::setUp();

        $this->artisan('veykemtu:setup');
        $this->artisan('veykemtu:demo-menu');
    }

    // ── Zorunlu başlıklar ─────────────────────────────────────────────────

    public function test_baslik_eksikse_422_doner(): void
    {
        $this->getJson('/api/health')
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED')
            ->assertJsonPath('error.details.missing_headers', ['X-App-Id', 'X-App-Version']);
    }

    public function test_gecersiz_app_id_reddedilir(): void
    {
        $this->getJson('/api/health', [
            'X-App-Id' => 'korsan',
            'X-App-Version' => '1.0.0',
        ])->assertStatus(422)->assertJsonPath('error.code', 'VALIDATION_FAILED');
    }

    public function test_saglik_ucu_calisir(): void
    {
        $this->getJson('/api/health', self::HEADERS)
            ->assertOk()
            ->assertJsonPath('status', 'ok')
            ->assertJsonStructure(['status', 'server_time']);
    }

    // ── Katalog ───────────────────────────────────────────────────────────

    public function test_tek_vitrin_doner_ve_sozlesme_alanlarini_tasir(): void
    {
        $this->getJson('/api/locations', self::HEADERS)
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonStructure(['data' => [[
                'id', 'name', 'slug', 'is_open', 'ordering_enabled',
                'order_cutoff', 'min_order_total', 'payment_methods',
            ]]]);
    }

    public function test_faz1_de_online_odeme_kapali(): void
    {
        $methods = $this->getJson('/api/locations', self::HEADERS)
            ->json('data.0.payment_methods');

        $this->assertNotContains('online', $methods);
        $this->assertContains('cash', $methods);
        $this->assertContains('account', $methods);
    }

    public function test_menu_uc_kategori_on_iki_urun_doner(): void
    {
        $data = $this->getJson('/api/locations/'.$this->locationId().'/menu', self::HEADERS)
            ->assertOk()
            ->json('data');

        $this->assertCount(3, $data);
        $this->assertSame(12, array_sum(array_map(
            static fn(array $c): int => count($c['items']),
            $data,
        )));
    }

    public function test_tukenmis_urun_listede_kalir_ama_isaretlenir(): void
    {
        $items = collect($this->getJson('/api/locations/'.$this->locationId().'/menu', self::HEADERS)
            ->json('data'))->flatMap(static fn(array $c): array => $c['items']);

        $sold = $items->firstWhere('name', 'Izgara Köfte');

        $this->assertNotNull($sold, 'Tükenmiş ürün listeden düşmemeli (docs/03 §3)');
        $this->assertFalse($sold['is_available']);
    }

    public function test_olmayan_vitrin_404_doner(): void
    {
        $this->getJson('/api/locations/9999/menu', self::HEADERS)
            ->assertNotFound()
            ->assertJsonPath('error.code', 'NOT_FOUND');
    }

    // ── Kimlik ────────────────────────────────────────────────────────────

    public function test_kvkk_onaysiz_kayit_reddedilir(): void
    {
        $this->postJson('/api/auth/register', $this->registerPayload(['kvkk_accepted' => false]), self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED')
            ->assertJsonStructure(['error' => ['details' => ['kvkk_accepted']]]);
    }

    public function test_kayit_ve_giris_token_uretir(): void
    {
        $this->postJson('/api/auth/register', $this->registerPayload(), self::HEADERS)
            ->assertCreated()
            ->assertJsonStructure(['token', 'customer' => ['id', 'first_name']]);

        $this->postJson('/api/auth/login', [
            'email' => 'test@ornek.com',
            'password' => 'parola123',
        ], self::HEADERS)->assertOk()->assertJsonStructure(['token']);
    }

    public function test_yanlis_sifre_kullanici_varligini_sizdirmaz(): void
    {
        $this->postJson('/api/auth/register', $this->registerPayload(), self::HEADERS);

        $varOlan = $this->postJson('/api/auth/login', [
            'email' => 'test@ornek.com', 'password' => 'yanlis',
        ], self::HEADERS);

        $olmayan = $this->postJson('/api/auth/login', [
            'email' => 'yok@ornek.com', 'password' => 'yanlis',
        ], self::HEADERS);

        // İki yanıt ayırt edilemez olmalı: aksi halde hangi e-postaların
        // kayıtlı olduğu numaralandırılabilir.
        $this->assertSame($varOlan->json('error'), $olmayan->json('error'));
    }

    public function test_me_sozlesme_alanlarini_doner_ve_group_icermez(): void
    {
        $json = $this->asCustomer()->getJson('/api/auth/me', self::HEADERS)
            ->assertOk()
            ->json();

        $this->assertSame(
            ['id', 'first_name', 'last_name', 'email', 'telephone', 'default_location_id'],
            array_keys($json),
        );
        // `group` alanı öğrenci kanalıyla birlikte kaldırıldı (docs/00 §4).
        $this->assertArrayNotHasKey('group', $json);
    }

    // ── Kapsam ayrımı (docs/10 S5) ────────────────────────────────────────

    public function test_tokensiz_istek_401_doner(): void
    {
        $this->getJson('/api/orders', self::HEADERS)
            ->assertUnauthorized()
            ->assertJsonPath('error.code', 'UNAUTHENTICATED');
    }

    public function test_musteri_tokeni_mutfak_uclarina_giremez(): void
    {
        $this->asCustomer()->getJson('/api/kitchen/orders', self::HEADERS)
            ->assertForbidden()
            ->assertJsonPath('error.code', 'FORBIDDEN');
    }

    public function test_mutfak_tokeni_musteri_uclarina_giremez(): void
    {
        $this->asKitchen()->getJson('/api/orders', self::HEADERS)
            ->assertForbidden()
            ->assertJsonPath('error.code', 'FORBIDDEN');
    }

    public function test_iptal_edilmis_cihaz_device_revoked_doner(): void
    {
        $device = $this->pairedDevice();
        $token = $device['token'];
        $device['model']->revoke();

        $this->withToken($token)->getJson('/api/kitchen/orders', self::HEADERS)
            ->assertForbidden()
            ->assertJsonPath('error.code', 'UNAUTHENTICATED');
    }

    public function test_baskasinin_siparisi_404_doner_403_degil(): void
    {
        $order = $this->placeOrder();

        // İkinci müşteri
        $this->postJson('/api/auth/register', $this->registerPayload([
            'email' => 'baskasi@ornek.com',
        ]), self::HEADERS);
        $token = $this->postJson('/api/auth/login', [
            'email' => 'baskasi@ornek.com', 'password' => 'parola123',
        ], self::HEADERS)->json('token');

        $this->withToken($token)->getJson('/api/orders/'.$order['id'], self::HEADERS)
            ->assertNotFound()
            ->assertJsonPath('error.code', 'NOT_FOUND');
    }

    // ── Sipariş oluşturma ─────────────────────────────────────────────────

    public function test_tutar_sunucuda_hesaplanir(): void
    {
        $order = $this->placeOrder(quantity: 2);

        // Tavuk Sote 18500 × 2 = 37000
        $this->assertSame(37000, $order['total']);
    }

    public function test_istemcinin_gonderdigi_tutar_yok_sayilir(): void
    {
        $response = $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 2]],
            'delivery_type' => 'pickup',
            'payment_method' => 'cash',
            'total' => 1, // uydurma
            'subtotal' => 1,
        ], self::HEADERS)->assertCreated();

        $this->assertSame(37000, $response->json('total'));
    }

    public function test_tukenmis_urun_siparise_eklenemez(): void
    {
        $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->menuId('Izgara Köfte'), 'quantity' => 2]],
            'delivery_type' => 'pickup',
            'payment_method' => 'cash',
        ], self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'ITEM_UNAVAILABLE');
    }

    public function test_kapali_odeme_yontemi_reddedilir(): void
    {
        $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 2]],
            'delivery_type' => 'pickup',
            'payment_method' => 'online', // Faz 1'de kapalı
        ], self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED');
    }

    public function test_adressiz_adrese_gonderim_reddedilir(): void
    {
        $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 2]],
            'delivery_type' => 'delivery',
            'payment_method' => 'cash',
        ], self::HEADERS)->assertStatus(422);
    }

    public function test_asgari_tutar_altinda_siparis_reddedilir(): void
    {
        $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->menuId('Ayran'), 'quantity' => 1]], // 3000 < 25000
            'delivery_type' => 'pickup',
            'payment_method' => 'cash',
        ], self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED');
    }

    public function test_siparis_yanitinda_kanal_alanlari_yok(): void
    {
        $order = $this->placeOrder();

        $this->assertArrayNotHasKey('channel', $order);
        $this->assertArrayNotHasKey('pickup_code', $order);
    }

    public function test_gel_al_siparisinde_teslimat_ucreti_yok(): void
    {
        $order = $this->placeOrder(deliveryType: 'pickup');

        $detail = $this->asCustomer()->getJson('/api/orders/'.$order['id'], self::HEADERS)->json();

        $this->assertSame(0, $detail['delivery_fee']);
        $this->assertNull($detail['address']);
        $this->assertSame('pickup', $detail['delivery_type']);
    }

    // ── Durum geçişleri (docs/10 S6) ──────────────────────────────────────

    public function test_adim_atlamak_reddedilir(): void
    {
        $order = $this->placeOrder();

        $this->asKitchen()->postJson(
            '/api/kitchen/orders/'.$order['id'].'/status',
            ['status' => OrderStatusTransition::READY],
            self::HEADERS,
        )
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'INVALID_TRANSITION')
            ->assertJsonPath('error.details.from', 'yeni')
            ->assertJsonPath('error.details.to', 'hazir');
    }

    public function test_gel_al_siparisi_yola_cikarilamaz(): void
    {
        $order = $this->placeOrder(deliveryType: 'pickup');
        $this->advance($order['id'], ['onaylandi', 'hazirlaniyor', 'hazir']);

        $this->asKitchen()->postJson(
            '/api/kitchen/orders/'.$order['id'].'/status',
            ['status' => OrderStatusTransition::ON_THE_WAY],
            self::HEADERS,
        )->assertStatus(422)->assertJsonPath('error.code', 'INVALID_TRANSITION');
    }

    public function test_adrese_gonderim_kurye_adimini_atlayamaz(): void
    {
        $order = $this->placeOrder(deliveryType: 'delivery');
        $this->advance($order['id'], ['onaylandi', 'hazirlaniyor', 'hazir']);

        $this->asKitchen()->postJson(
            '/api/kitchen/orders/'.$order['id'].'/status',
            ['status' => OrderStatusTransition::DELIVERED],
            self::HEADERS,
        )->assertStatus(422)->assertJsonPath('error.code', 'INVALID_TRANSITION');
    }

    public function test_terminal_durumdan_cikilamaz(): void
    {
        $order = $this->placeOrder(deliveryType: 'pickup');
        $this->advance($order['id'], ['onaylandi', 'hazirlaniyor', 'hazir', 'teslim_edildi']);

        $this->asKitchen()->postJson(
            '/api/kitchen/orders/'.$order['id'].'/status',
            ['status' => OrderStatusTransition::CANCELLED],
            self::HEADERS,
        )->assertStatus(422)->assertJsonPath('error.code', 'INVALID_TRANSITION');
    }

    public function test_musteri_hazirlanan_siparisi_iptal_edemez(): void
    {
        $order = $this->placeOrder();
        $this->advance($order['id'], ['onaylandi', 'hazirlaniyor']);

        $this->asCustomer()->postJson('/api/orders/'.$order['id'].'/cancel', [], self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'INVALID_TRANSITION');
    }

    public function test_musteri_yeni_siparisi_iptal_edebilir(): void
    {
        $order = $this->placeOrder();

        $this->asCustomer()->postJson('/api/orders/'.$order['id'].'/cancel', [], self::HEADERS)
            ->assertOk()
            ->assertJsonPath('status', 'iptal');
    }

    // ── Mutfak ────────────────────────────────────────────────────────────

    public function test_mutfak_listesi_fiyat_ve_adres_icermez(): void
    {
        $this->placeOrder();

        $data = $this->asKitchen()->getJson('/api/kitchen/orders', self::HEADERS)
            ->assertOk()
            ->json('data');

        foreach ($data as $order) {
            $this->assertArrayNotHasKey('total', $order);
            $this->assertArrayNotHasKey('address', $order);
            $this->assertArrayNotHasKey('telephone', $order);
            foreach ($order['items'] as $item) {
                $this->assertArrayNotHasKey('unit_price', $item);
            }
        }
    }

    public function test_customer_label_yalnizca_bas_harf_icerir(): void
    {
        $this->placeOrder();

        $label = $this->asKitchen()->getJson('/api/kitchen/orders', self::HEADERS)
            ->json('data.0.customer_label');

        $this->assertSame('Test M.', $label);
    }

    public function test_tamamlanan_siparis_mutfak_listesinde_gorunmez(): void
    {
        $order = $this->placeOrder(deliveryType: 'pickup');
        $this->advance($order['id'], ['onaylandi', 'hazirlaniyor', 'hazir', 'teslim_edildi']);

        $ids = array_column(
            $this->asKitchen()->getJson('/api/kitchen/orders', self::HEADERS)->json('data'),
            'id',
        );

        $this->assertNotContains($order['id'], $ids);
    }

    public function test_artimli_cekme_since_ile_bos_doner(): void
    {
        $this->placeOrder();

        $first = $this->asKitchen()->getJson('/api/kitchen/orders', self::HEADERS)->json();
        $this->assertCount(1, $first['data']);

        $second = $this->asKitchen()
            ->getJson('/api/kitchen/orders?since='.urlencode($first['server_time']), self::HEADERS)
            ->json();

        $this->assertCount(0, $second['data'], 'Değişiklik yokken since boş dönmeli');
        $this->assertSame($first['max_id'], $second['max_id'], 'max_id geriye kaymamalı');
    }

    public function test_mutfak_fisi_fiyat_icermez_musteri_fisi_icerir(): void
    {
        $order = $this->placeOrder();

        $mutfak = $this->asKitchen()
            ->getJson('/api/kitchen/orders/'.$order['id'].'/receipt?type=mutfak', self::HEADERS)
            ->assertOk()->json();
        $this->assertArrayNotHasKey('total', $mutfak);
        $this->assertSame('mutfak', $mutfak['type']);

        $musteri = $this->asKitchen()
            ->getJson('/api/kitchen/orders/'.$order['id'].'/receipt?type=musteri', self::HEADERS)
            ->assertOk()->json();
        $this->assertSame(37000, $musteri['total']);
    }

    public function test_teslim_fisi_tipi_kaldirildi(): void
    {
        $order = $this->placeOrder();

        $this->asKitchen()
            ->getJson('/api/kitchen/orders/'.$order['id'].'/receipt?type=teslim', self::HEADERS)
            ->assertStatus(422);
    }

    public function test_fis_ack_idempotenttir(): void
    {
        $order = $this->placeOrder();
        $body = ['type' => 'mutfak', 'printed_at' => '2026-08-04T11:30:07Z'];

        $this->asKitchen()->postJson('/api/kitchen/print-jobs/'.$order['id'].'/ack', $body, self::HEADERS)
            ->assertNoContent();

        $this->asKitchen()->postJson('/api/kitchen/print-jobs/'.$order['id'].'/ack', [
            'type' => 'mutfak', 'printed_at' => '2026-08-04T12:00:00Z',
        ], self::HEADERS)->assertNoContent();

        $this->assertSame(
            1,
            PrintJob::where('order_id', $order['id'])->where('type', 'mutfak')->count(),
            'Aynı fiş iki kez kaydedilmemeli (docs/10 S4)',
        );
    }

    public function test_uretim_listesi_aktif_siparisleri_toplar(): void
    {
        $order = $this->placeOrder(quantity: 3);
        $this->advance($order['id'], ['onaylandi']);

        $data = $this->asKitchen()->getJson('/api/kitchen/production-list', self::HEADERS)
            ->assertOk()->json('data');

        $this->assertSame('Tavuk Sote', $data[0]['name']);
        $this->assertSame(3, $data[0]['total']);
    }

    public function test_heartbeat_min_surum_doner(): void
    {
        $this->asKitchen()->getJson('/api/kitchen/heartbeat', self::HEADERS)
            ->assertOk()
            ->assertJsonStructure(['server_time', 'min_supported_version']);
    }

    public function test_gecersiz_eslesme_kodu_404_doner(): void
    {
        $this->postJson('/api/kitchen/pair', [
            'pairing_code' => 'AAAA-BBBB',
            'device_name' => 'Sahte',
        ], self::HEADERS)->assertNotFound()->assertJsonPath('error.code', 'NOT_FOUND');
    }

    // ── Sürüm ─────────────────────────────────────────────────────────────

    public function test_surum_ucu_bilinmeyen_uygulamayi_reddeder(): void
    {
        $this->getJson('/api/app-version?app_id=korsan', self::HEADERS)->assertStatus(422);
    }

    public function test_surum_ucu_calisir(): void
    {
        $this->getJson('/api/app-version?app_id=mutfakapp', self::HEADERS)
            ->assertOk()
            ->assertJsonStructure(['app_id', 'latest', 'min_supported']);
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    /** @return array<string, mixed> */
    private function registerPayload(array $overrides = []): array
    {
        return array_merge([
            'first_name' => 'Test',
            'last_name' => 'Müşteri',
            'email' => 'test@ornek.com',
            'telephone' => '5551234567',
            'password' => 'parola123',
            'kvkk_accepted' => true,
        ], $overrides);
    }

    private function locationId(): int
    {
        return (int) $this->getJson('/api/locations', self::HEADERS)->json('data.0.id');
    }

    private function menuId(string $name): int
    {
        $items = collect($this->getJson('/api/locations/'.$this->locationId().'/menu', self::HEADERS)
            ->json('data'))->flatMap(static fn(array $c): array => $c['items']);

        return (int) $items->firstWhere('name', $name)['id'];
    }

    private function asCustomer(): static
    {
        if (ApiCustomer::where('email', 'test@ornek.com')->doesntExist()) {
            $this->postJson('/api/auth/register', $this->registerPayload(), self::HEADERS);
        }

        $token = $this->postJson('/api/auth/login', [
            'email' => 'test@ornek.com', 'password' => 'parola123',
        ], self::HEADERS)->json('token');

        return $this->withToken($token);
    }

    /** @return array{token:string, model:KitchenDevice} */
    private function pairedDevice(): array
    {
        $device = new KitchenDevice;
        $device->name = 'Test Kasası';
        $device->save();
        $code = $device->refreshPairingCode();

        $token = $this->postJson('/api/kitchen/pair', [
            'pairing_code' => $code,
            'device_name' => 'Test Kasası',
        ], self::HEADERS)->json('token');

        return ['token' => $token, 'model' => $device->refresh()];
    }

    private function asKitchen(): static
    {
        return $this->withToken($this->pairedDevice()['token']);
    }

    /** @return array<string, mixed> */
    private function placeOrder(int $quantity = 2, string $deliveryType = 'delivery'): array
    {
        $payload = [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => $quantity]],
            'delivery_type' => $deliveryType,
            'payment_method' => 'cash',
        ];

        if ($deliveryType === 'delivery') {
            $payload['address'] = [
                'line1' => 'Örnek Mah. 12. Sk No:3',
                'district' => 'Çankaya',
                'city' => 'Ankara',
            ];
        }

        return $this->asCustomer()->postJson('/api/orders', $payload, self::HEADERS)
            ->assertCreated()
            ->json();
    }

    /** @param list<string> $statuses */
    private function advance(int $orderId, array $statuses): void
    {
        foreach ($statuses as $status) {
            $this->asKitchen()->postJson(
                '/api/kitchen/orders/'.$orderId.'/status',
                ['status' => $status],
                self::HEADERS,
            )->assertOk();
        }

        $this->assertNotNull(Order::find($orderId));
    }
}
