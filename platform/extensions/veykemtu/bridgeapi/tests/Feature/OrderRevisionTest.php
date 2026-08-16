<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Order;
use Illuminate\Support\Facades\DB;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;
use Veykemtu\BridgeApi\Support\Money;

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

    public function test_SECENEK_ADET_DEGISINCE_KORUNUR_ve_tutara_yansir(): void
    {
        /*
         * SESSİZ KAYIP. `editable()` yalnız seçenek ADLARINI döndürüyordu;
         * kimlik hiç dışarı çıkmadığı için KDS onu geri gönderemiyor,
         * `LineResolver` satırı **seçeneksiz** yeniden fiyatlıyordu.
         *
         * Sonuç: personel yalnız adedi değiştirdiğinde müşteri eksik
         * ücretlendiriliyor ve seçenek satırı mutfak fişinden düşüyordu —
         * hiçbir hata dönmeden, yemek yanlış çıkarak.
         */
        $menuId = $this->menuId('Tavuk Sote');
        $valueId = $this->bolPorsiyonOption($menuId);

        // 4 × (185,00 + 25,00) = 840,00. Teslimat ücreti ayrı satır;
        // burada sınanan şey kalem fiyatlaması, tarife değil.
        $order = $this->confirmedOrder(quantity: 4, optionValueIds: [$valueId]);
        $this->assertSame(84000, $this->subtotalKurus($order));

        $editable = $this->asKitchen()
            ->getJson("/api/kitchen/orders/{$order->order_id}/editable", self::HEADERS)
            ->assertOk()
            ->json('data');

        // Ekran seçeneği personele ADLA yazıyor, kimlikle değil.
        $this->assertSame(['Bol'], $editable['items'][0]['options']);

        // PERSONEL SEÇENEĞE DOKUNMUYOR: yalnız adet düşüyor. İstemci
        // sunucudan geleni aynen geri gönderiyor (`EditableItem.toRequest`).
        $items = $this->revisionItemsFrom($editable);
        $items[0]['quantity'] = 2;

        $this->asKitchen()->postJson(
            "/api/kitchen/orders/{$order->order_id}/revisions",
            ['reason' => 'Müşteri talebi', 'items' => $items],
            self::HEADERS,
        )->assertOk();

        // (a) SEÇENEK KORUNUR — kimlik satırda duruyor.
        $this->assertSame(
            [$valueId],
            DB::table('order_menu_options')
                ->where('order_id', $order->order_id)
                ->pluck('menu_option_value_id')
                ->map(intval(...))
                ->all(),
            'Personel seçeneğe dokunmadı; seçenek aynen korunmalı.',
        );

        // (b) TUTAR SEÇENEK FARKINI İÇERİR: 2 × (185,00 + 25,00) = 420,00.
        // Seçenek düşmüş olsaydı 2 × 185,00 = 370,00 çıkardı ve aradaki
        // 50,00 sessizce müşterinin lehine kaybolurdu.
        $this->assertSame(42000, $this->subtotalKurus($order->refresh()));
    }

    public function test_KIMLIKSIZ_ESKI_SATIR_revizyonu_cokertmez(): void
    {
        // Kimlik `order_menu_options` tablosundan okunuyor. Göç öncesi ya
        // da başka bir yoldan yazılmış satırlarda o kayıt olmayabilir;
        // düzenleme yine de çalışmalı — seçeneksiz, ama çökmeden.
        $menuId = $this->menuId('Tavuk Sote');
        $valueId = $this->bolPorsiyonOption($menuId);
        $order = $this->confirmedOrder(quantity: 3, optionValueIds: [$valueId]);

        DB::table('order_menu_options')->where('order_id', $order->order_id)->delete();

        $editable = $this->asKitchen()
            ->getJson("/api/kitchen/orders/{$order->order_id}/editable", self::HEADERS)
            ->assertOk()
            ->json('data');

        $this->assertSame([], $editable['items'][0]['option_value_ids']);

        $items = $this->revisionItemsFrom($editable);
        $items[0]['quantity'] = 1;

        $this->asKitchen()->postJson(
            "/api/kitchen/orders/{$order->order_id}/revisions",
            ['reason' => 'Müşteri talebi', 'items' => $items],
            self::HEADERS,
        )->assertOk();

        $this->assertSame(18500, $this->subtotalKurus($order->refresh()));
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

    /**
     * İKİNCİ REVİZYON DA KENDİ PARA KAYDINI DOĞURUR.
     *
     * Para kaydı REVİZYONA bağlanıyor, siparişe değil. Siparişe
     * bağlansaydı aynı siparişin ikinci düzenlemesi ya sessizce yutulur ya
     * da birincisinin üstüne yazardı — iki kez küçültülen bir siparişin
     * ikinci iadesi kimsenin görmediği bir yerde kaybolurdu.
     *
     * (Bu değişmez eskiden cari defter üzerinden ölçülüyordu; cari hesap
     * kaldırılınca aynı soru iade tablosuna soruluyor.)
     */
    public function test_IKINCI_REVIZYON_kendi_iade_kaydini_acar(): void
    {
        $order = $this->confirmedOrder(quantity: 10);
        $menuId = $this->menuId('Tavuk Sote');

        foreach ([8, 6] as $quantity) {
            $this->asKitchen()->postJson(
                "/api/kitchen/orders/{$order->order_id}/revisions",
                ['reason' => 'Müşteri talebi', 'items' => [['menu_id' => $menuId, 'quantity' => $quantity]]],
                self::HEADERS,
            )->assertOk();
        }

        $revisionIds = DB::table('veykemtu_payment_refunds')
            ->where('order_id', $order->order_id)
            ->pluck('revision_id');

        $this->assertCount(2, $revisionIds, 'Her revizyon kendi iade satırını açmalı.');
        $this->assertCount(
            2,
            array_unique($revisionIds->all()),
            'İki iade satırı AYRI revizyonlara bağlı olmalı.',
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

    /**
     * Düzenleme ekranının gördüğünü olduğu gibi revizyon gövdesine çevirir.
     *
     * KDS'in `EditableItem.toRequest()` davranışının birebir karşılığı:
     * personel dokunmadığı sürece sunucudan geleni AYNEN geri gönderir.
     * Test bu köprüyü taklit etmezse asıl hata (kimliğin yolda düşmesi)
     * hiç sınanmamış olur.
     *
     * @param  array<string, mixed>  $editable
     * @return list<array<string, mixed>>
     */
    private function revisionItemsFrom(array $editable): array
    {
        return array_map(static fn(array $item): array => [
            'menu_id' => $item['menu_id'],
            'quantity' => $item['quantity'],
            'option_value_ids' => $item['option_value_ids'] ?? [],
            'note' => $item['note'],
        ], $editable['items']);
    }

    /** Kalemlerin toplamı — teslimat ücreti hariç. */
    private function subtotalKurus(Order $order): int
    {
        return Money::toKurus(
            DB::table('order_totals')
                ->where('order_id', $order->order_id)
                ->where('code', 'subtotal')
                ->value('value'),
        );
    }

    /**
     * Ürüne "Porsiyon: Bol (+25,00)" seçeneği takar ve değer kimliğini döner.
     *
     * Demo menüde seçenek yok — seçenek kaybını sınayan test kendi
     * kurulumunu yapmak zorunda.
     */
    private function bolPorsiyonOption(int $menuId): int
    {
        $optionId = DB::table('menu_options')->insertGetId([
            'option_name' => 'Porsiyon',
            'display_type' => 'radio',
            'priority' => 0,
        ]);

        $optionValueId = DB::table('menu_option_values')->insertGetId([
            'option_id' => $optionId,
            'name' => 'Bol',
            'price' => Money::toDecimal(2500),
            'priority' => 0,
        ]);

        $menuOptionId = DB::table('menu_item_options')->insertGetId([
            'option_id' => $optionId,
            'menu_id' => $menuId,
            'is_required' => false,
            'priority' => 0,
            'min_selected' => 0,
            'max_selected' => 1,
            'free_quantity' => 0,
        ]);

        return (int) DB::table('menu_item_option_values')->insertGetId([
            'menu_option_id' => $menuOptionId,
            'option_value_id' => $optionValueId,
            'override_price' => null,
            'priority' => 0,
            'is_default' => false,
            'free_quantity' => 0,
        ]);
    }

    /**
     * Onaylanmış (düzenlenebilir) bir sipariş üretir.
     *
     * @param  list<int>  $optionValueIds
     */
    private function confirmedOrder(
        int $quantity = 2,
        string $deliveryType = 'delivery',
        string $payment = 'cash',
        array $optionValueIds = [],
    ): Order {
        $item = ['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => $quantity];

        if ($optionValueIds !== []) {
            $item['option_value_ids'] = $optionValueIds;
        }

        $payload = [
            'location_id' => $this->locationId(),
            'items' => [$item],
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
