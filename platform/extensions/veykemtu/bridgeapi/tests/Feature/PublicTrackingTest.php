<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Support\SignedLink;

/**
 * Fişteki takip QR'ının açtığı girişsiz uç — K-20.
 *
 * NEDEN VAR: eski takip bağlantısı `/siparis/{id}` idi ve o sayfa oturum
 * istiyordu; fişteki kareyi okutan müşteri sipariş durumunu değil giriş
 * ekranını görüyordu. Kâğıda basılan bir QR giriş isteyemez.
 *
 * EN KRİTİK TEST: `test_takip_yaniti_adres_ve_telefon_ICERMEZ`. Bu ucu açan
 * şey bir oturum değil, kâğıda basılmış bir kare; fiş düşürülebilir,
 * fotoğraflanabilir, çöpten çıkarılabilir.
 */
class PublicTrackingTest extends KitchenTestCase
{
    private const string SECRET = 'test-baglanti-sirri-0123456789abcdef';

    protected function setUp(): void
    {
        parent::setUp();

        putenv('BLD_LINK_SECRET='.self::SECRET);
        $_ENV['BLD_LINK_SECRET'] = self::SECRET;
        config(['app.frontend_url' => 'https://ornek.test']);
    }

    protected function tearDown(): void
    {
        putenv('BLD_LINK_SECRET');
        unset($_ENV['BLD_LINK_SECRET']);

        parent::tearDown();
    }

    public function test_imzali_baglantiyla_giris_olmadan_takip_okunur(): void
    {
        $order = $this->confirmedOrder();
        $orderId = (int) $order['id'];

        // Hiçbir token yok — `withToken` çağrılmıyor. Test bu.
        $this->getJson($this->trackUrl($orderId), self::HEADERS)
            ->assertOk()
            ->assertJsonPath('id', $orderId)
            ->assertJsonPath('status', 'onaylandi');
    }

    /**
     * Yanıt siparişin DAR yüzü: adres, ad, telefon ve kalem listesi yok.
     *
     * Buradan çıkarılan her şey zaten fişin üstünde yazıyor; kâğıttan daha
     * uzun yaşayan bir URL üzerinden ikinci kez sızdırmak hiçbir şey
     * kazandırmıyor.
     */
    public function test_takip_yaniti_adres_ve_telefon_ICERMEZ(): void
    {
        $order = $this->confirmedOrder();

        $data = $this->getJson($this->trackUrl((int) $order['id']), self::HEADERS)
            ->assertOk()
            ->json();

        $this->assertArrayNotHasKey('address', $data);
        $this->assertArrayNotHasKey('customer_name', $data);
        $this->assertArrayNotHasKey('customer_phone', $data);
        $this->assertArrayNotHasKey('items', $data);
        $this->assertArrayNotHasKey('customer_note', $data);

        // Ödeme başlatma girişli akışın işi; yönlendirme adresi sızmamalı.
        $this->assertArrayNotHasKey('redirect_url', $data['payment']);
    }

    public function test_imzasiz_istek_reddedilir(): void
    {
        $order = $this->confirmedOrder();

        $this->getJson('/api/public/orders/'.$order['id'].'/tracking', self::HEADERS)
            ->assertStatus(403)
            ->assertJsonPath('error.code', 'FORBIDDEN');
    }

    public function test_YANLIS_IMZA_reddedilir(): void
    {
        $order = $this->confirmedOrder();
        $orderId = (int) $order['id'];
        $expires = time() + 3600;

        $this->getJson(
            "/api/public/orders/{$orderId}/tracking?e={$expires}&s=uydurma",
            self::HEADERS,
        )->assertStatus(403);
    }

    public function test_suresi_dolmus_baglanti_reddedilir(): void
    {
        $order = $this->confirmedOrder();
        $orderId = (int) $order['id'];
        $expires = time() - 60;
        $signature = SignedLink::sign(SignedLink::PURPOSE_TRACK, $orderId, $expires);

        $this->getJson(
            "/api/public/orders/{$orderId}/tracking?e={$expires}&s={$signature}",
            self::HEADERS,
        )->assertStatus(403);
    }

    /**
     * BİR SİPARİŞİN İMZASI KOMŞUSUNU AÇMAZ.
     *
     * Sipariş kimliği imzanın içinde; olmasaydı elinde tek geçerli bağlantı
     * olan kişi numarayı arttırarak bütün siparişleri gezerdi.
     */
    public function test_baska_siparisin_imzasi_kabul_edilmez(): void
    {
        $first = (int) $this->confirmedOrder()['id'];
        $expires = time() + 3600;
        $signature = SignedLink::sign(SignedLink::PURPOSE_TRACK, $first, $expires);

        $other = $first + 1;

        $this->getJson(
            "/api/public/orders/{$other}/tracking?e={$expires}&s={$signature}",
            self::HEADERS,
        )->assertStatus(403);
    }

    /** Teslim imzası takip ucunda geçmez — amaç imzanın içinde. */
    public function test_teslim_imzasi_takip_ucunda_kabul_edilmez(): void
    {
        $orderId = (int) $this->confirmedOrder()['id'];
        $expires = time() + 3600;
        $signature = SignedLink::sign(SignedLink::PURPOSE_DELIVER, $orderId, $expires);

        $this->getJson(
            "/api/public/orders/{$orderId}/tracking?e={$expires}&s={$signature}",
            self::HEADERS,
        )->assertStatus(403);
    }

    /**
     * İmzası geçerli ama sipariş yoksa `404`.
     *
     * İmza doğrulaması veritabanından ÖNCE koşuyor; sıra ters olsaydı var
     * olmayan sipariş `404`, var olan ama imzası bozuk sipariş `403`
     * dönerdi ve fark, hangi numaraların var olduğunu ele verirdi.
     */
    public function test_gecerli_imza_ama_olmayan_siparis_404_doner(): void
    {
        $missing = 999_999;
        $expires = time() + 3600;
        $signature = SignedLink::sign(SignedLink::PURPOSE_TRACK, $missing, $expires);

        $this->getJson(
            "/api/public/orders/{$missing}/tracking?e={$expires}&s={$signature}",
            self::HEADERS,
        )->assertStatus(404);
    }

    private function trackUrl(int $orderId): string
    {
        $expires = time() + 3600;
        $signature = SignedLink::sign(SignedLink::PURPOSE_TRACK, $orderId, $expires);

        return "/api/public/orders/{$orderId}/tracking?e={$expires}&s={$signature}";
    }

    /** @return array<string, mixed> */
    private function confirmedOrder(): array
    {
        $created = $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 2]],
            'delivery_type' => 'delivery',
            'payment_method' => 'cash',
            'address' => [
                'line1' => 'Örnek Mah. 12. Sk No:3',
                'district' => 'Selçuklu',
                'city' => 'Konya',
            ],
        ], self::HEADERS)->assertCreated()->json();

        $this->advance((int) $created['id'], ['onaylandi']);

        return $created;
    }
}
