<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Menu;
use Igniter\Cart\Models\Order;
use Igniter\Local\Models\Location;
use Illuminate\Routing\Middleware\ThrottleRequests;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Models\DailyMenuItem;
use Veykemtu\BridgeApi\Services\DailyStock;
use Veykemtu\BridgeApi\Services\LocationGate;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Günlük stok tavanı — gün toplamı + ürün bazlı, atomik (S2).
 *
 * İŞ KURALI 4: "gün toplamı VE ürün bazlı tavan; hangisi önce dolarsa
 * kapatır. Satır yoksa sınırsız." Bu paketin tamamı o cümleyi kilitliyor.
 *
 * SERVİS GÜNÜ HEP İLERİ BİR HAFTA İÇİ. Bugüne sipariş vermek, testi kesim
 * saatine bağlar: paket öğleden sonra koşturulduğunda `cutoff_passed` ile
 * kırmızıya döner ve arıza stokla hiç ilgili olmaz. Hafta sonu da eleniyor
 * (iş kuralı 3: hafta sonu menü yok).
 */
class DailyStockTest extends KitchenTestCase
{
    private const string TABLE = 'veykemtu_daily_menu_stock';

    protected function setUp(): void
    {
        parent::setUp();

        $gate = app(LocationGate::class);
        $gate->setDailyMenuEnabled($this->location(), true);

        // `veykemtu:setup` asgari sepeti 250,00 TL yazıyor. Bu paket stok
        // aritmetiğini sınıyor, asgari tutar kuralını değil; sıfırlanmazsa
        // tek porsiyonluk siparişlerin hiçbiri geçmez.
        $gate->setMinOrderTotal($this->location(), 0);
    }

    // ── Tavan ───────────────────────────────────────────────────────────

    /**
     * Kapasite 10: onuncu sipariş geçer, on birincisi düşer.
     *
     * Tavanın ASIL işi bu — mutfağın pişirebileceğinden fazla porsiyon
     * satılmaması. Sessizce geçseydi, arıza akşam mutfakta ortaya çıkardı.
     */
    public function test_gun_tavani_dolunca_siparis_reddedilir(): void
    {
        $date = $this->serviceDay();
        $this->publishDay($date, null, [['Tavuk Sote', 9000]]);
        $this->setCapacity(DailyStock::DAY_TOTAL, $date, 10);

        $menuId = $this->menuId('Tavuk Sote');
        $this->asCustomer();

        for ($i = 1; $i <= 10; $i++) {
            $this->order($menuId, 1, $date)->assertCreated();
        }

        $this->order($menuId, 1, $date)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'ITEM_UNAVAILABLE');

        $this->assertSame(10, Order::query()->count());
        $this->assertSame(10, $this->soldOf(DailyStock::DAY_TOTAL, $date));
    }

    /**
     * Gün toplamı 20, kalem tavanı 5.
     *
     * "HANGİSİ ÖNCE DOLARSA KAPATIR" TAM OLARAK BU: gün bolluk içindeyken
     * tek bir yemek bitebilir ve o yemek kapanırken ötekiler satılmaya
     * devam eder.
     */
    public function test_kalem_tavani_gun_bol_olsa_bile_kapatir(): void
    {
        $date = $this->serviceDay();
        $this->publishDay($date, null, [
            ['Tavuk Sote', 9000],
            ['Mercimek Çorbası', 4000],
        ]);

        $tavuk = $this->menuId('Tavuk Sote');
        $corba = $this->menuId('Mercimek Çorbası');

        $this->setCapacity(DailyStock::DAY_TOTAL, $date, 20);
        $this->setCapacity($tavuk, $date, 5);

        $this->asCustomer();

        $this->order($tavuk, 5, $date)->assertCreated();

        $this->order($tavuk, 1, $date)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'ITEM_UNAVAILABLE');

        // Tavanı olmayan kalem hâlâ satılıyor: gün toplamında yer var.
        $this->order($corba, 3, $date)->assertCreated();

        $this->assertSame(5, $this->soldOf($tavuk, $date));
        $this->assertSame(8, $this->soldOf(DailyStock::DAY_TOTAL, $date));
        // Reddedilen sipariş gün toplamından da düşmedi: düşüm işlemin
        // içinde ve başarısız kalem tüm siparişi geri alıyor.
        $this->assertSame(2, Order::query()->count());
    }

    /**
     * SON PORSİYON İÇİN YARIŞ — tam bir kazanan.
     *
     * NE KANITLIYOR: son porsiyona iki alıcı geldiğinde sonuç HER ZAMAN bir
     * 201 + bir 422 ve `sold === capacity`. Yirmi tur, tavanı her turda tek
     * porsiyona indirerek koşuyor; PHP tarafında bir "önce oku, sonra yaz"
     * penceresi açılsaydı turlardan biri iki 201 üretirdi.
     *
     * NE KANITLAMIYOR — dürüstlük payı: PHPUnit tek süreçte ve tek
     * bağlantıda koşuyor (`RefreshDatabase` her testi bir işleme sarıyor),
     * yani işletim sistemi düzeyinde gerçek eşzamanlılık kurulamıyor. Asıl
     * güvence koşulun SQL'de olması: `capacity - reserved - sold >= :qty`
     * `WHERE` içinde ve InnoDB eşleşen satırı kilitliyor. Bu test o
     * sözleşmenin gözlenebilir yüzünü kilitliyor.
     */
    public function test_son_porsiyon_yarisinda_tek_kazanan_olur(): void
    {
        /*
         * HIZ SINIRI BU TESTTE KAPALI — ölçülen şey o değil.
         *
         * Döngü 20 turda 40 `POST /api/orders` atıyor; `bld-order` kovası
         * ise müşteri başına 20/saat. Onuncu turdan sonra iki istek de
         * `429` dönüyordu ve test "iki alıcıdan biri kazandı" yerine
         * "ikisi de kovaya takıldı" durumunu görüyordu — yani stok
         * atomikliği 11. turdan itibaren HİÇ sınanmıyordu.
         *
         * Turu azaltmak yanlış çözüm olurdu: yarış testinin değeri tur
         * sayısındadır, tek turluk bir yarış hiçbir şey kanıtlamaz.
         * Kovaların kendi testleri var (`ControlPanelTest`); burada
         * sınanan tek şey `DailyStock::take()`'in koşullu `UPDATE`'i.
         */
        $this->withoutMiddleware(ThrottleRequests::class);

        $date = $this->serviceDay();
        $this->publishDay($date, null, [['Tavuk Sote', 9000]]);

        $menuId = $this->menuId('Tavuk Sote');
        $this->setCapacity(DailyStock::DAY_TOTAL, $date, 1);
        $this->asCustomer();

        for ($round = 1; $round <= 20; $round++) {
            // Tavanı "satılan + 1"e çekiyoruz: her turda tam bir porsiyon
            // kalıyor ve iki alıcı onun için yarışıyor.
            DB::table(self::TABLE)
                ->where('service_date', $date->toDateString())
                ->where('menu_id', DailyStock::DAY_TOTAL)
                ->update(['capacity' => DB::raw('sold + 1')]);

            $codes = [
                $this->order($menuId, 1, $date)->getStatusCode(),
                $this->order($menuId, 1, $date)->getStatusCode(),
            ];
            sort($codes);

            $this->assertSame([201, 422], $codes, "tur {$round}");

            $row = $this->rowOf(DailyStock::DAY_TOTAL, $date);
            $this->assertSame(
                (int) $row->capacity,
                (int) $row->sold,
                "tur {$round}: satılan, tavanı geçmemeli",
            );
        }

        $this->assertSame(20, Order::query()->count());
    }

    // ── Geri verme ──────────────────────────────────────────────────────

    /**
     * İptal porsiyonları geri verir — ve YALNIZ BİR KEZ.
     *
     * Çift kredi sessiz bir arızadır: kimse bir hata görmez, yalnız o gün
     * tavanın üstünde satış açılır ve mutfak akşam fazladan sipariş bulur.
     */
    public function test_iptal_stoku_bir_kez_geri_verir(): void
    {
        $date = $this->serviceDay();
        $this->publishDay($date, null, [['Tavuk Sote', 9000]]);

        $menuId = $this->menuId('Tavuk Sote');
        $this->setCapacity(DailyStock::DAY_TOTAL, $date, 5);
        $this->setCapacity($menuId, $date, 5);

        $orderId = (int) $this->asCustomer()
            ->order($menuId, 2, $date)
            ->assertCreated()
            ->json('id');

        $this->assertSame(2, $this->soldOf(DailyStock::DAY_TOTAL, $date));

        $this->advance($orderId, ['iptal']);

        $this->assertSame(0, $this->soldOf(DailyStock::DAY_TOTAL, $date));
        $this->assertSame(0, $this->soldOf($menuId, $date));
        $this->assertNotNull(
            DB::table('orders')->where('order_id', $orderId)->value('bld_stock_released_at'),
        );

        /*
         * İKİNCİ GERİ VERME NO-OP. Durum makinesi ikinci bir iptali zaten
         * reddediyor, ama asıl koruma `bld_stock_released_at`; servisi
         * doğrudan çağırıp onu sınıyoruz. Araya BAŞKA bir satış konuyor ki
         * "geri verilmedi" ile "geri verilecek bir şey yoktu" karışmasın.
         */
        $stock = app(DailyStock::class);
        $stock->take($this->locationId(), $date, [DailyStock::DAY_TOTAL => 2]);

        $order = Order::query()->where('order_id', $orderId)->firstOrFail();
        $this->assertFalse($stock->releaseOrder($order));
        $this->assertSame(2, $this->soldOf(DailyStock::DAY_TOTAL, $date));

        // Durum makinesi de aynı fikirde.
        $this->asKitchen()->postJson(
            '/api/kitchen/orders/'.$orderId.'/status',
            ['status' => 'iptal'],
            self::HEADERS,
        )->assertStatus(422)->assertJsonPath('error.code', 'INVALID_TRANSITION');
    }

    // ── Sınırsız ────────────────────────────────────────────────────────

    /**
     * Satır yoksa SINIRSIZ — mevcut her testin gerilemesine karşı koruma.
     *
     * `null`'ı `0` sayan bir uygulama burada satışı tamamen keserdi ve
     * tavanı hiç konmamış her gün tükenmiş görünürdü.
     */
    public function test_stok_satiri_yoksa_sinirsiz_satilir(): void
    {
        $date = $this->serviceDay();
        $this->publishDay($date, null, [['Tavuk Sote', 9000]]);

        $this->asCustomer()
            ->order($this->menuId('Tavuk Sote'), 50, $date)
            ->assertCreated();

        $this->assertSame(0, DB::table(self::TABLE)->count());

        $payload = $this->getJson(
            '/api/locations/'.$this->locationId().'/daily-menu?date='.$date->toDateString(),
            self::HEADERS,
        )->assertOk()->json('data');

        // `null` = sınırsız. `0` yazsaydık istemci tükenmiş gösterirdi.
        $this->assertNull($payload['remaining_portions']);
        $this->assertNull($payload['items'][0]['remaining_portions']);
    }

    // ── Sözleşme alanları ───────────────────────────────────────────────

    public function test_katalog_kalan_porsiyonlari_bildirir(): void
    {
        $date = $this->serviceDay();
        $this->publishDay($date, 18000, [
            ['Tavuk Sote', 9000],
            ['Mercimek Çorbası', 4000],
        ]);

        $tavuk = $this->menuId('Tavuk Sote');
        $this->setCapacity(DailyStock::DAY_TOTAL, $date, 40);
        $this->setCapacity($tavuk, $date, 6);
        $this->setCapacity($this->packageMenuId(), $date, 12);

        $this->asCustomer()->order($tavuk, 2, $date)->assertCreated();

        $payload = $this->getJson(
            '/api/locations/'.$this->locationId().'/daily-menu?date='.$date->toDateString(),
            self::HEADERS,
        )->assertOk()->json('data');

        $this->assertSame(38, $payload['remaining_portions']);
        $this->assertSame(12, $payload['package']['remaining_portions']);

        $item = collect($payload['items'])->firstWhere('id', $tavuk);
        $this->assertSame(4, $item['remaining_portions']);

        // Tavanı olmayan kalem `null` döner — sınırsız.
        $this->assertNull(
            collect($payload['items'])
                ->firstWhere('id', $this->menuId('Mercimek Çorbası'))['remaining_portions'],
        );

        // Stok GÜNE bağlıdır, ürüne değil: katalog ucu her zaman `null`.
        $catalog = collect($this->getJson(
            '/api/locations/'.$this->locationId().'/menu',
            self::HEADERS,
        )->assertOk()->json('data'))->flatMap(static fn(array $c): array => $c['items']);

        $this->assertNull($catalog->firstWhere('id', $tavuk)['remaining_portions']);
    }

    /**
     * Paket bileşenleri KENDİ tavanlarından düşer, gün toplamı porsiyonu
     * sayar.
     *
     * Bileşenler gün toplamına da girseydi, dört kalemlik bir menü gün
     * tavanından beş porsiyon yer ve 200 porsiyonluk bir gün 40 menüde
     * kapanırdı.
     */
    public function test_paket_bilesenleri_kendi_tavanindan_duser(): void
    {
        $date = $this->serviceDay();
        $this->publishDay($date, 18000, [
            ['Tavuk Sote', 9000],
            ['Mercimek Çorbası', 4000],
        ]);

        $this->setCapacity(DailyStock::DAY_TOTAL, $date, 30);
        $this->setCapacity($this->menuId('Tavuk Sote'), $date, 30);

        $this->asCustomer()->order($this->packageMenuId(), 3, $date)->assertCreated();

        // Üç paket = üç porsiyon; içindeki tavuk da üç.
        $this->assertSame(3, $this->soldOf(DailyStock::DAY_TOTAL, $date));
        $this->assertSame(3, $this->soldOf($this->menuId('Tavuk Sote'), $date));
    }

    /**
     * Rezervasyon satışı kapatır (iş kuralı 5).
     *
     * Abone sabah siparişini garanti eder; tek seferlik satış artandan
     * yürür. `reserved` kalanın içinde sayılmasaydı aynı porsiyon iki kez
     * satılırdı.
     */
    public function test_rezerve_porsiyon_satisa_kapali(): void
    {
        $date = $this->serviceDay();
        $this->publishDay($date, null, [['Tavuk Sote', 9000]]);

        $menuId = $this->menuId('Tavuk Sote');
        $this->setCapacity(DailyStock::DAY_TOTAL, $date, 4, reserved: 4);

        $this->asCustomer()->order($menuId, 1, $date)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'ITEM_UNAVAILABLE');

        app(DailyStock::class)->unreserve($this->locationId(), $date, [
            DailyStock::DAY_TOTAL => 1,
        ]);

        $this->order($menuId, 1, $date)->assertCreated();
    }

    /**
     * REVİZYON TAVANI AŞABİLİR — ve aşımı kayda geçer.
     *
     * Personel müşteriyle telefonda konuşup adedi artırıyor; o gün tavan
     * dolduğu için düzenlemenin reddedilmesi, verilmiş bir sözü geri almak
     * olurdu. Aynı felsefe `enforceAvailability: false` kararında da var.
     */
    public function test_revizyon_tavani_asabilir_ve_kayda_gecer(): void
    {
        $date = $this->serviceDay();
        $this->publishDay($date, null, [['Tavuk Sote', 9000]]);

        $menuId = $this->menuId('Tavuk Sote');
        $this->setCapacity(DailyStock::DAY_TOTAL, $date, 2);

        $orderId = (int) $this->asCustomer()
            ->order($menuId, 2, $date)
            ->assertCreated()
            ->json('id');

        $this->asKitchen()->postJson(
            '/api/kitchen/orders/'.$orderId.'/revisions',
            [
                'items' => [['menu_id' => $menuId, 'quantity' => 5]],
                'reason' => 'Müşteri telefonda artırdı',
            ],
            self::HEADERS,
        )->assertOk();

        // Tavan 2, satılan 5: aşım bilerek yapıldı ve tabloda duruyor.
        $this->assertSame(5, $this->soldOf(DailyStock::DAY_TOTAL, $date));

        $note = (string) DB::table('veykemtu_order_revisions')
            ->where('order_id', $orderId)
            ->value('note');

        $this->assertStringContainsString('STOK TAVANI AŞILDI', $note);

        // Adet geri düşünce fazlası da geri veriliyor.
        $this->asKitchen()->postJson(
            '/api/kitchen/orders/'.$orderId.'/revisions',
            [
                'items' => [['menu_id' => $menuId, 'quantity' => 1]],
                'reason' => 'Müşteri yeniden azalttı',
            ],
            self::HEADERS,
        )->assertOk();

        $this->assertSame(1, $this->soldOf(DailyStock::DAY_TOTAL, $date));
    }

    // ── Yardımcılar ─────────────────────────────────────────────────────

    /**
     * Sipariş verilecek gün: ileri bir hafta içi.
     *
     * Bugün kullanılsaydı test kesim saatine, hafta sonu kullanılsaydı
     * servis günü kuralına takılırdı; ikisi de stokla ilgisiz kırmızı
     * üretir. İleri görüş penceresi 7 gün, bu yüzden en fazla +3 gün
     * ilerleniyor.
     */
    private function serviceDay(): Carbon
    {
        $date = BusinessTime::now()->addDay()->startOfDay();

        while (in_array($date->dayOfWeekIso, [6, 7], true)) {
            $date->addDay();
        }

        return $date;
    }

    private function order(int $menuId, int $quantity, Carbon $date): TestResponse
    {
        return $this->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $menuId, 'quantity' => $quantity]],
            'delivery_type' => 'pickup',
            'payment_method' => 'cash',
            'service_date' => $date->toDateString(),
        ], self::HEADERS);
    }

    private function setCapacity(
        int $menuId,
        Carbon $date,
        int $capacity,
        int $reserved = 0,
    ): void {
        DB::table(self::TABLE)->insert([
            'location_id' => $this->locationId(),
            'service_date' => $date->toDateString(),
            'menu_id' => $menuId,
            'capacity' => $capacity,
            'reserved' => $reserved,
            'sold' => 0,
            'updated_by' => 'test',
            'created_at' => BusinessTime::forStorage(BusinessTime::now()),
            'updated_at' => BusinessTime::forStorage(BusinessTime::now()),
        ]);
    }

    private function rowOf(int $menuId, Carbon $date): object
    {
        $row = DB::table(self::TABLE)
            ->where('location_id', $this->locationId())
            ->where('service_date', $date->toDateString())
            ->where('menu_id', $menuId)
            ->first();

        $this->assertNotNull($row, "stok satırı yok: menu_id={$menuId}");

        return $row;
    }

    private function soldOf(int $menuId, Carbon $date): int
    {
        return (int) $this->rowOf($menuId, $date)->sold;
    }

    private function location(): Location
    {
        return Location::query()->where('location_id', $this->locationId())->firstOrFail();
    }

    private function packageMenuId(): int
    {
        return (int) DailyMenu::packageMenuIdFor($this->locationId());
    }

    /**
     * O güne menü kurar ve yayınlar.
     *
     * @param  list<array{0:string, 1:int}>  $items  [ürün adı, ürün fiyatı]
     */
    private function publishDay(Carbon $date, ?int $packagePrice, array $items): DailyMenu
    {
        $menu = DailyMenu::create([
            'location_id' => $this->locationId(),
            'menu_date' => $date->toDateString(),
            'title' => 'Ev Yemeği Menüsü',
            'package_price_kurus' => $packagePrice,
            'status' => DailyMenu::STATUS_PUBLISHED,
            'published_at' => BusinessTime::forStorage(BusinessTime::now()),
        ]);

        foreach ($items as $index => [$name, $price]) {
            $product = Menu::query()->where('menu_name', $name)->firstOrFail();
            $product->menu_price = $price / 100;
            $product->save();

            DailyMenuItem::create([
                'daily_menu_id' => $menu->id,
                'menu_id' => $product->menu_id,
                'quantity' => 1,
                'sort_order' => $index,
            ]);
        }

        return $menu->refresh();
    }
}
