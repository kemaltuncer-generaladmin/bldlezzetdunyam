<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Order;
use Illuminate\Support\Facades\DB;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Models\BbdReceipt;

/**
 * BBD Store köprüsü — K-16.
 *
 * BBD Store bir **kitap e-ticaret sitesi** (catering değil), ayrı
 * sunucuda ayrı proje. Köprünün tek varlık sebebi termal yazıcıyı
 * paylaşmak.
 *
 * EN KRİTİK TEST: BBD siparişi BLD'nin `orders` tablosuna GİRMEMELİ.
 * Girseydi ciro raporu, üretim listesi ve cari hesap bir gecede yanlış
 * olurdu — BBD'nin ürünleri BLD menüsünde, fiyatları BLD fiyat listesinde
 * ve müşterisi BLD müşterisinde yok.
 */
class BbdBridgeTest extends KitchenTestCase
{
    private const string SECRET = 'test-bbd-sirri';

    protected function setUp(): void
    {
        parent::setUp();

        // Sır ortamdan okunuyor; test için sabitliyoruz.
        putenv('BBD_WEBHOOK_SECRET='.self::SECRET);
        $_ENV['BBD_WEBHOOK_SECRET'] = self::SECRET;
    }

    public function test_imzali_istek_kabul_edilir(): void
    {
        $this->postBbd($this->payload())
            ->assertOk()
            ->assertJsonPath('accepted', true);

        $this->assertSame(1, BbdReceipt::count());
    }

    public function test_IMZASIZ_istek_reddedilir(): void
    {
        $this->postJson(
            '/api/partner/bbd/orders',
            $this->payload(),
            ['Accept' => 'application/json'],
        )->assertStatus(401);

        $this->assertSame(0, BbdReceipt::count());
    }

    public function test_YANLIS_IMZA_reddedilir(): void
    {
        $body = json_encode($this->payload(), JSON_UNESCAPED_UNICODE);

        $this->call(
            'POST',
            '/api/partner/bbd/orders',
            [],
            [],
            [],
            [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_ACCEPT' => 'application/json',
                'HTTP_X_BBD_SIGNATURE' => 'sha256=yanlis',
            ],
            $body,
        )->assertStatus(401);

        $this->assertSame(0, BbdReceipt::count());
    }

    public function test_GOVDE_DEGISTIRILIRSE_imza_tutmaz(): void
    {
        // İmza ham gövde üzerinde; tek karakter değişse doğrulanmamalı.
        $original = $this->payload();
        $signature = 'sha256='.hash_hmac(
            'sha256',
            json_encode($original, JSON_UNESCAPED_UNICODE),
            self::SECRET,
        );

        $tampered = $original;
        $tampered['items'][0]['quantity'] = 999;

        $this->call(
            'POST',
            '/api/partner/bbd/orders',
            [],
            [],
            [],
            [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_ACCEPT' => 'application/json',
                'HTTP_X_BBD_SIGNATURE' => $signature,
            ],
            json_encode($tampered, JSON_UNESCAPED_UNICODE),
        )->assertStatus(401);
    }

    public function test_AYNI_external_id_IKINCI_FIS_URETMEZ(): void
    {
        // BBD ağ hatasında tekrar gönderiyor; ikinci fiş basılmamalı.
        $payload = $this->payload();

        $this->postBbd($payload)->assertOk()->assertJsonPath('accepted', true);
        $this->postBbd($payload)->assertOk()->assertJsonPath('accepted', false);

        $this->assertSame(1, BbdReceipt::count());
    }

    public function test_BBD_SIPARISI_ORDERS_TABLOSUNA_GIRMEZ(): void
    {
        // Girseydi ciro raporu, üretim listesi ve cari hesap yanlış olurdu.
        $before = Order::count();

        $this->postBbd($this->payload())->assertOk();

        $this->assertSame($before, Order::count());
    }

    public function test_BBD_SIPARISI_gunluk_sayaca_karismaz(): void
    {
        $this->postBbd($this->payload())->assertOk();

        $health = $this->asKitchen()->postJson('/api/kitchen/health', [
            'printer_ok' => true,
            'print_queue_pending' => 0,
            'print_queue_failed' => 0,
        ], self::HEADERS)->assertOk();

        $this->assertSame(0, $health->json('orders_today'));
    }

    public function test_BBD_SIPARISI_MUTFAK_PANOSUNDA_GORUNMEZ(): void
    {
        $this->postBbd($this->payload())->assertOk();

        $this->asKitchen()
            ->getJson('/api/kitchen/orders', self::HEADERS)
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    public function test_kasa_bekleyen_fisleri_ceker(): void
    {
        $this->postBbd($this->payload())->assertOk();

        $this->asKitchen()
            ->getJson('/api/kitchen/bbd-orders', self::HEADERS)
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.external_id', 'BBD-TEST-1');
    }

    public function test_onaylanan_fis_kuyruktan_duser(): void
    {
        $this->postBbd($this->payload())->assertOk();
        $id = (int) BbdReceipt::firstOrFail()->id;

        $this->asKitchen()
            ->postJson("/api/kitchen/bbd-orders/{$id}/ack", [], self::HEADERS)
            ->assertNoContent();

        $this->asKitchen()
            ->getJson('/api/kitchen/bbd-orders', self::HEADERS)
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    public function test_ONAY_IDEMPOTENTTIR_ilk_zaman_korunur(): void
    {
        // Ağ hatasında kasa tekrar gönderirse "ne zaman basıldı" cevabı
        // değişmemeli.
        $this->postBbd($this->payload())->assertOk();
        $id = (int) BbdReceipt::firstOrFail()->id;

        $this->asKitchen()
            ->postJson("/api/kitchen/bbd-orders/{$id}/ack", [], self::HEADERS)
            ->assertNoContent();
        $first = BbdReceipt::findOrFail($id)->printed_at;

        $this->asKitchen()
            ->postJson("/api/kitchen/bbd-orders/{$id}/ack", [], self::HEADERS)
            ->assertNoContent();

        $this->assertEquals($first, BbdReceipt::findOrFail($id)->printed_at);
    }

    public function test_musteri_bbd_kuyrugunu_goremez(): void
    {
        $this->asCustomer()
            ->getJson('/api/kitchen/bbd-orders', self::HEADERS)
            ->assertForbidden();
    }

    public function test_eksik_kalem_reddedilir(): void
    {
        $payload = $this->payload();
        $payload['items'] = [];

        $this->postBbd($payload)->assertStatus(422);
    }

    public function test_ham_govde_saklanir(): void
    {
        // "BBD ne göndermişti" sorusunun cevabı burada; fiş içeriği de
        // bundan üretiliyor.
        $this->postBbd($this->payload())->assertOk();

        $stored = BbdReceipt::firstOrFail()->payload_json;

        $this->assertSame(
            "Türkiye'nin Yakın Tarihi — Cilt II",
            $stored['items'][0]['name'],
        );
        // Stok kodu ve kargo bilgisi de saklanmalı: fiş bunlardan üretiliyor.
        $this->assertSame('9789750718533', $stored['items'][0]['sku']);
        $this->assertSame('1234567890123', $stored['tracking_number']);
        $this->assertSame(18500, $stored['amount_kurus']);
    }

    /** @param array<string, mixed> $payload */
    private function postBbd(array $payload): \Illuminate\Testing\TestResponse
    {
        $body = json_encode($payload, JSON_UNESCAPED_UNICODE);

        return $this->call(
            'POST',
            '/api/partner/bbd/orders',
            [],
            [],
            [],
            [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_ACCEPT' => 'application/json',
                'HTTP_X_BBD_SIGNATURE' => 'sha256='.hash_hmac(
                    'sha256',
                    $body,
                    self::SECRET,
                ),
            ],
            $body,
        );
    }

    /** @return array<string, mixed> */
    private function payload(): array
    {
        return [
            'external_id' => 'BBD-TEST-1',
            'order_number' => 'BBD-1',
            'created_at' => '2026-08-12T11:32:00Z',
            'customer_label' => 'Ayşe Y.',
            'phone' => '0555 123 45 67',
            'delivery_type' => 'delivery',
            'address' => 'Örnek Mah. 12. Sk No:3',
            'items' => [
                [
                    'name' => "Türkiye'nin Yakın Tarihi — Cilt II",
                    'quantity' => 2,
                    'sku' => '9789750718533',
                    'attributes' => ['Ahmet Yılmaz', 'Ciltli, 3. baskı'],
                ],
            ],
            'cargo_company' => 'Yurtiçi Kargo',
            'tracking_number' => '1234567890123',
            'payment_label' => 'Kapıda ödeme',
            'amount_kurus' => 18500,
        ];
    }
}
