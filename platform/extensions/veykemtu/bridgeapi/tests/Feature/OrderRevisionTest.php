<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Order;
use Illuminate\Support\Facades\DB;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Services\AccountLedger;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;

/**
 * Sipariş düzenleme (K-12) ve iade (K-13).
 *
 * EN KRİTİK TEST: `orders.updated_at` bumplanıyor mu. KDS artımlı
 * yoklaması `since` ile o alan üzerinden çalışıyor; yalnız `order_menus`
 * değişip `orders` dokunulmasaydı, düzenleme mutfak ekranına **hiç
 * düşmez** ve personel eski adedi hazırlamaya devam ederdi.
 */
class OrderRevisionTest extends KitchenTestCase
{
    public function test_adet_azaltilinca_toplam_ve_kalem_guncellenir(): void
    {
        $order = $this->confirmedOrder(quantity: 20);
        $menuId = $this->menuId('Tavuk Sote');

        $this->asKitchen()->postJson(
            "/api/kitchen/orders/{$order->order_id}/revisions",
            [
                'reason' => 'Müşteri talebi',
                'items' => [['menu_id' => $menuId, 'quantity' => 10]],
            ],
            self::HEADERS,
        )->assertOk()->assertJsonPath('revision.revision_no', 1);

        $order->refresh();

        $this->assertSame(10, (int) $order->total_items);
        $this->assertSame(
            10,
            (int) DB::table('order_menus')
                ->where('order_id', $order->order_id)
                ->value('quantity'),
        );
    }

    public function test_TOPLAM_SATIRLARI_IKIYE_KATLANMAZ(): void
    {
        // Eski `storeTotals()` yalnız `insert` yapıyordu ve
        // `order_totals` tablosunda `(order_id, code)` tekilliği YOK.
        // İkinci kez çağrılsa sipariş iki "Ara Toplam" satırı taşır ve
        // admin panelde toplam iki katı görünürdü.
        $order = $this->confirmedOrder(quantity: 4);
        $menuId = $this->menuId('Tavuk Sote');

        foreach ([3, 2] as $quantity) {
            $this->asKitchen()->postJson(
                "/api/kitchen/orders/{$order->order_id}/revisions",
                ['reason' => 'Düzeltme', 'items' => [['menu_id' => $menuId, 'quantity' => $quantity]]],
                self::HEADERS,
            )->assertOk();
        }

        $this->assertSame(
            1,
            DB::table('order_totals')
                ->where('order_id', $order->order_id)
                ->where('code', 'subtotal')
                ->count(),
        );
    }

    public function test_UPDATED_AT_BUMPLANIR_ve_kds_degisikligi_gorur(): void
    {
        $order = $this->confirmedOrder(quantity: 5);
        $menuId = $this->menuId('Tavuk Sote');

        // Değişiklikten hemen önceki an — KDS'in elindeki `since`.
        $since = $order->updated_at->copy();
        sleep(1);

        $this->asKitchen()->postJson(
            "/api/kitchen/orders/{$order->order_id}/revisions",
            ['reason' => 'Müşteri talebi', 'items' => [['menu_id' => $menuId, 'quantity' => 2]]],
            self::HEADERS,
        )->assertOk();

        $ids = $this->asKitchen()->getJson(
            '/api/kitchen/orders?since='.urlencode($since->toIso8601ZuluString()),
            self::HEADERS,
        )->assertOk()->json('data.*.id');

        $this->assertContains(
            (int) $order->order_id,
            $ids,
            'Düzenlenen sipariş artımlı yoklamada dönmeli; dönmezse mutfak '
            .'eski adedi hazırlamaya devam eder.',
        );
    }

    public function test_kalem_cikarilabilir_ve_eklenebilir(): void
    {
        $order = $this->confirmedOrder(quantity: 2);
        $tavuk = $this->menuId('Tavuk Sote');
        $corba = $this->menuId('Mercimek Çorbası');

        $this->asKitchen()->postJson(
            "/api/kitchen/orders/{$order->order_id}/revisions",
            [
                'reason' => 'Müşteri talebi',
                'items' => [['menu_id' => $corba, 'quantity' => 3]],
            ],
            self::HEADERS,
        )->assertOk();

        $rows = DB::table('order_menus')->where('order_id', $order->order_id)->get();

        $this->assertCount(1, $rows);
        $this->assertSame($corba, (int) $rows->first()->menu_id);
        $this->assertNotSame($tavuk, (int) $rows->first()->menu_id);
    }

    public function test_bos_kalem_listesi_reddedilir(): void
    {
        // Tümünü kaldırmak "iptal" demek ve o ayrı bir durum geçişi.
        // Sessizce iptale çevirmek, personelin niyetini tahmin etmek olurdu.
        $order = $this->confirmedOrder();

        $this->asKitchen()->postJson(
            "/api/kitchen/orders/{$order->order_id}/revisions",
            ['reason' => 'Boş', 'items' => []],
            self::HEADERS,
        )->assertStatus(422);
    }

    public function test_teslim_edilmis_siparis_duzenlenemez(): void
    {
        $order = $this->confirmedOrder(deliveryType: 'pickup');
        $this->advance((int) $order->order_id, [
            OrderStatusTransition::PREPARING,
            OrderStatusTransition::READY,
            OrderStatusTransition::DELIVERED,
        ]);

        $this->asKitchen()->postJson(
            "/api/kitchen/orders/{$order->order_id}/revisions",
            [
                'reason' => 'Geç kaldık',
                'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 1]],
            ],
            self::HEADERS,
        )->assertStatus(422);
    }

    public function test_IKINCI_REVIZYON_cari_deftere_YAZILABILIR(): void
    {
        // Defterdeki `UNIQUE(source, reference_type, reference_id,
        // entry_type)` kısıtı sipariş kimliğine bağlansaydı, aynı
        // siparişin ikinci düzenlemesi `insertOrIgnore` tarafından
        // sessizce yutulur ve müşteri fazla borçlu kalırdı. Referans
        // REVİZYONA bağlı olduğu için ikisi de yazılıyor.
        $order = $this->confirmedOrder(quantity: 10, payment: 'account');
        $menuId = $this->menuId('Tavuk Sote');

        foreach ([8, 6] as $quantity) {
            $this->asKitchen()->postJson(
                "/api/kitchen/orders/{$order->order_id}/revisions",
                ['reason' => 'Müşteri talebi', 'items' => [['menu_id' => $menuId, 'quantity' => $quantity]]],
                self::HEADERS,
            )->assertOk();
        }

        $this->assertSame(
            2,
            DB::table('veykemtu_account_ledger')
                ->where('reference_type', 'order_revision')
                ->count(),
        );
    }

    public function test_tutar_dusunce_iade_kaydi_acilir(): void
    {
        $order = $this->confirmedOrder(quantity: 10);

        $this->asKitchen()->postJson(
            "/api/kitchen/orders/{$order->order_id}/revisions",
            [
                'reason' => 'Müşteri talebi',
                'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 4]],
            ],
            self::HEADERS,
        )->assertOk()->assertJsonPath('revision.settlement.kind', 'refund');

        $refund = DB::table('veykemtu_payment_refunds')
            ->where('order_id', $order->order_id)
            ->first();

        $this->assertNotNull($refund, 'Başarısız olsa bile iade kaydı açılmalı.');
        $this->assertGreaterThan(0, (int) $refund->amount_kurus);
    }

    public function test_tutar_artinca_iade_degil_EK_TAHSILAT_kaydedilir(): void
    {
        $order = $this->confirmedOrder(quantity: 2);

        $this->asKitchen()->postJson(
            "/api/kitchen/orders/{$order->order_id}/revisions",
            [
                'reason' => 'Müşteri ekleme istedi',
                'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 6]],
            ],
            self::HEADERS,
        )
            ->assertOk()
            ->assertJsonPath('revision.settlement.kind', 'extra_charge');

        $this->assertSame(
            0,
            DB::table('veykemtu_payment_refunds')->where('order_id', $order->order_id)->count(),
            'Tutar arttığında iade kaydı açılmamalı.',
        );
    }

    public function test_musteri_revizyonlari_gorur(): void
    {
        $order = $this->confirmedOrder(quantity: 10);

        $this->asKitchen()->postJson(
            "/api/kitchen/orders/{$order->order_id}/revisions",
            [
                'reason' => 'Müşteri talebi',
                'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 5]],
            ],
            self::HEADERS,
        )->assertOk();

        $this->asCustomer()->getJson("/api/orders/{$order->order_id}", self::HEADERS)
            ->assertOk()
            ->assertJsonPath('revision_no', 1)
            ->assertJsonPath('revisions.0.reason', 'Müşteri talebi');
    }

    public function test_mutfak_duzenleme_gorunumunde_FIYAT_YOKTUR(): void
    {
        // ADR-08 daraltıldı ama kaldırılmadı: telefon görünür, fiyat görünmez.
        $order = $this->confirmedOrder();

        $data = $this->asKitchen()
            ->getJson("/api/kitchen/orders/{$order->order_id}/editable", self::HEADERS)
            ->assertOk()
            ->json('data');

        $this->assertArrayHasKey('customer_phone', $data);
        foreach ($data['items'] as $item) {
            $this->assertArrayNotHasKey('unit_price', $item);
            $this->assertArrayNotHasKey('line_total', $item);
        }
    }

    public function test_mutfak_kartinda_TELEFON_VAR_adres_yok(): void
    {
        $this->confirmedOrder();

        $row = $this->asKitchen()
            ->getJson('/api/kitchen/orders', self::HEADERS)
            ->assertOk()
            ->json('data.0');

        $this->assertArrayHasKey('customer_phone', $row);
        $this->assertArrayNotHasKey('address', $row);
        $this->assertArrayNotHasKey('total', $row);
    }

    public function test_kurye_fisi_tahsil_edilecek_tutari_tasir(): void
    {
        $order = $this->confirmedOrder(quantity: 3);

        $receipt = $this->asKitchen()
            ->getJson("/api/kitchen/orders/{$order->order_id}/receipt?type=kurye", self::HEADERS)
            ->assertOk()
            ->json();

        $this->assertSame('kurye', $receipt['type']);
        $this->assertArrayHasKey('customer_phone', $receipt);
        $this->assertArrayHasKey('collect_amount', $receipt);
        // Kapıda ödemeli sipariş ödenmemiş: tamamı tahsil edilecek.
        $this->assertSame($receipt['total'], $receipt['collect_amount']);
    }

    /** Onaylanmış (düzenlenebilir) bir sipariş üretir. */
    private function confirmedOrder(
        int $quantity = 2,
        string $deliveryType = 'delivery',
        string $payment = 'cash',
    ): Order {
        $payload = [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => $quantity]],
            'delivery_type' => $deliveryType,
            'payment_method' => $payment,
        ];

        if ($deliveryType === 'delivery') {
            $payload['address'] = [
                'line1' => 'Örnek Mah. 12. Sk No:3',
                'district' => 'Selçuklu',
                'city' => 'Konya',
            ];
        }

        $created = $this->asCustomer()
            ->postJson('/api/orders', $payload, self::HEADERS)
            ->assertCreated()
            ->json();

        $this->advance((int) $created['id'], [OrderStatusTransition::CONFIRMED]);

        return Order::findOrFail((int) $created['id']);
    }
}
