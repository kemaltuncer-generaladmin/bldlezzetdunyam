<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Menu;
use Igniter\Local\Models\Location;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Models\ClosedDay;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Models\DailyMenuItem;
use Veykemtu\BridgeApi\Services\LocationGate;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Günün menüsü — katalog, satış kuralı ve paketin sipariş satırı (B-19).
 *
 * PAKETTEKİ EN PAHALI SESSİZ ARIZA: "Günün Menüsü" ürününün kendi fiyatı
 * 0,00 ve gerçek fiyat o günün paket fiyatı. Gün çözülmeden fiyatlanmasına
 * izin verilirse günün menüsü BEDAVA satılır. `test_paket_gun_cozulmeden_
 * fiyatlanamaz` tam olarak bunu kilitliyor.
 */
class DailyMenuTest extends KitchenTestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        // Günün menüsü rejimi kapalı doğuyor (sunucu şalteri); bu paketteki
        // testler onu açık varsayıyor.
        $gate = app(LocationGate::class);
        $gate->setDailyMenuEnabled($this->location(), true);

        // `veykemtu:setup` asgari sepeti 250,00 TL yazıyor. Bu paket günün
        // menüsünü sınıyor, asgari tutar kuralını değil; sıfırlanmazsa
        // 180,00 TL'lik bir menü paketi hiç sipariş edilemez ve testlerin
        // yarısı ilgisiz bir sebeple kırmızı olur.
        $gate->setMinOrderTotal($this->location(), 0);
    }

    // ── Katalog ─────────────────────────────────────────────────────────

    public function test_yayinlanmis_gun_paket_ve_kalemleriyle_doner(): void
    {
        $menu = $this->publishDay(BusinessTime::now(), 18000, [
            ['Mercimek Çorbası', 4000],
            ['Tavuk Sote', 9000],
        ]);

        $data = $this->getJson($this->dailyMenuUrl(), self::HEADERS)
            ->assertOk()
            ->json('data');

        $this->assertSame((int) $menu->id, $data['id']);
        $this->assertTrue($data['is_orderable']);
        $this->assertNull($data['unavailable_reason']);
        $this->assertSame(18000, $data['package']['price']);
        $this->assertCount(2, $data['package']['components']);
        $this->assertCount(2, $data['items']);

        // Kalemlerin tek tek toplamı sunucudan geliyor ki "paketle şu kadar
        // avantaj" cümlesini kuran istemci çıkarma yapmak zorunda kalmasın.
        $this->assertSame(13000, $data['items_total']);
    }

    /**
     * Yönetici bir ay öncesinden plan giriyor; yarım kalmış bir günün
     * müşteriye sızması, pişmeyecek bir yemeğin satılması demek.
     */
    public function test_taslak_gun_musteriye_SIZMAZ(): void
    {
        $menu = $this->publishDay(BusinessTime::now(), 18000, [['Tavuk Sote', 9000]]);
        $menu->status = DailyMenu::STATUS_DRAFT;
        $menu->save();

        $data = $this->getJson($this->dailyMenuUrl(), self::HEADERS)
            ->assertOk()
            ->json('data');

        $this->assertNull($data['id']);
        $this->assertNull($data['package']);
        $this->assertSame([], $data['items']);
        $this->assertFalse($data['is_orderable']);
        $this->assertSame('not_published', $data['unavailable_reason']);
    }

    /**
     * PAKET FİYATI GİRİLİ AMA VİTRİNİN PAKET ÜRÜNÜ YOK → paket satılmıyor.
     *
     * Sahada yaşandı: yönetici güne 250 TL paket fiyatı girdi, panel
     * "kaydedildi" dedi, sitede paket kartı hiç çıkmadı ve menü kalem kalem
     * göründü. Sebep `location_options.bld_daily_package_menu_id` satırının
     * hiç yazılmamış olmasıydı (`veykemtu:setup` o kurulumda koşmamıştı) ve
     * bunu söyleyen tek bir işaret yoktu.
     *
     * Yanıt biçimi DEĞİŞMİYOR — `package: null` doğru cevap, çünkü sipariş
     * edilemeyen bir paketi fiyatıyla göstermek sepete eklenemeyen bir kart
     * üretirdi. Kilitlenen şey SEBEBİN AYRIŞMASI: `packageBlockReason()`
     * hangi kapının kapalı olduğunu söylüyor ve panel ile günlük onu okuyor.
     */
    public function test_paket_urunu_tanimsizsa_paket_satilmaz_ve_sebep_ayrisir(): void
    {
        $menu = $this->publishDay(BusinessTime::now(), 25000, [['Tavuk Sote', 9000]]);

        // Vitrinin paket ürünü ayarını kaldır — `veykemtu:setup` koşmamış kurulum.
        DB::table('location_options')
            ->where('location_id', $this->locationId())
            ->where('item', DailyMenu::PACKAGE_OPTION_KEY)
            ->delete();

        $data = $this->getJson($this->dailyMenuUrl(), self::HEADERS)
            ->assertOk()
            ->json('data');

        // Kalemler görünmeye devam ediyor: müşteri hâlâ tek tek sipariş verebilir.
        $this->assertNull($data['package']);
        $this->assertCount(1, $data['items']);

        $this->assertSame(
            DailyMenu::PACKAGE_BLOCK_NO_PRODUCT,
            $menu->refresh()->packageBlockReason(null),
        );
    }

    /**
     * ZORUNLU KALEMİ OLMAYAN GÜN → paketin içi boş olurdu.
     *
     * `packagePayload()` yalnız `is_required` kalemleri paketin içine
     * koyuyor; hiçbiri işaretli değilse paket "içindekiler" bölümü boş bir
     * fiyat etiketine dönerdi.
     */
    public function test_zorunlu_kalemi_olmayan_gunde_paket_satilmaz(): void
    {
        $menu = $this->publishDay(BusinessTime::now(), 25000, [['Tavuk Sote', 9000]]);

        DailyMenuItem::query()
            ->where('daily_menu_id', $menu->id)
            ->update(['is_required' => false]);

        $data = $this->getJson($this->dailyMenuUrl(), self::HEADERS)
            ->assertOk()
            ->json('data');

        $this->assertNull($data['package']);
        $this->assertSame(
            DailyMenu::PACKAGE_BLOCK_NO_COMPONENTS,
            $menu->refresh()->packageBlockReason($this->packageMenuId()),
        );
    }

    /**
     * Fiyatı olmayan gün ARIZA DEĞİL — o gün yalnız kalemler satılıyor.
     *
     * Ayrı bir sebep kodu taşıması gerekiyor, yoksa günlük ve panel uyarısı
     * her normal günde de öterdi.
     */
    public function test_paket_fiyati_yoksa_sebep_ariza_degil(): void
    {
        $menu = $this->publishDay(BusinessTime::now(), null, [['Tavuk Sote', 9000]]);

        $this->assertSame(
            DailyMenu::PACKAGE_BLOCK_NO_PRICE,
            $menu->packageBlockReason($this->packageMenuId()),
        );
    }

    /** Her şey yerindeyse kapı açık. */
    public function test_yapilandirma_tamsa_paket_engellenmiyor(): void
    {
        $menu = $this->publishDay(BusinessTime::now(), 25000, [['Tavuk Sote', 9000]]);

        $this->assertNull($menu->packageBlockReason($this->packageMenuId()));
    }

    /** Menü olmayan gün bir hata değil, bir cevaptır. */
    public function test_menusu_olmayan_gun_200_doner(): void
    {
        $this->getJson($this->dailyMenuUrl(BusinessTime::now()->addDays(3)), self::HEADERS)
            ->assertOk()
            ->assertJsonPath('data.id', null)
            ->assertJsonPath('data.unavailable_reason', 'not_published');
    }

    /** Kapalı gün, menü girilmiş olsa bile kazanır. */
    public function test_kapali_gun_menu_olsa_bile_satilamaz(): void
    {
        $date = BusinessTime::now()->addDay();
        $this->publishDay($date, 18000, [['Tavuk Sote', 9000]]);

        ClosedDay::create([
            'closed_on' => $date->toDateString(),
            'description' => 'Kurban Bayramı',
        ]);

        $data = $this->getJson($this->dailyMenuUrl($date), self::HEADERS)
            ->assertOk()
            ->json('data');

        $this->assertTrue($data['closed']);
        $this->assertFalse($data['is_orderable']);
        $this->assertSame('closed_day', $data['unavailable_reason']);
    }

    public function test_ileri_gorus_penceresi_disindaki_gun_satilamaz(): void
    {
        app(LocationGate::class)->setMaxLookaheadDays($this->location(), 3);

        $date = BusinessTime::now()->addDays(10);
        $this->publishDay($date, 18000, [['Tavuk Sote', 9000]]);

        $this->getJson($this->dailyMenuUrl($date), self::HEADERS)
            ->assertOk()
            ->assertJsonPath('data.is_orderable', false)
            ->assertJsonPath('data.unavailable_reason', 'too_far');
    }

    public function test_gun_icin_girilen_fiyat_istisnasi_urun_fiyatini_ezer(): void
    {
        $this->publishDay(BusinessTime::now(), 18000, [
            ['Tavuk Sote', 9000, 7500],
        ]);

        $this->getJson($this->dailyMenuUrl(), self::HEADERS)
            ->assertOk()
            ->assertJsonPath('data.items.0.price', 7500);
    }

    // ── Takvim ──────────────────────────────────────────────────────────

    public function test_takvim_yalniz_menusu_olan_ve_kapali_gunleri_doner(): void
    {
        $today = BusinessTime::now();
        $this->publishDay($today, 18000, [['Tavuk Sote', 9000]]);

        ClosedDay::create([
            'closed_on' => $today->copy()->addDays(2)->toDateString(),
            'description' => 'Bayram',
        ]);

        $data = $this->getJson(
            '/api/locations/'.$this->locationId().'/menu-calendar'
                .'?from='.$today->toDateString()
                .'&to='.$today->copy()->addDays(5)->toDateString(),
            self::HEADERS,
        )->assertOk()->json('data');

        // Altı günlük aralık, iki dolu gün: geri kalanı hiç dönmüyor.
        $this->assertCount(2, $data);
        $this->assertTrue($data[0]['has_menu']);
        $this->assertTrue($data[1]['closed']);
        $this->assertSame('Bayram', $data[1]['note']);
    }

    public function test_cok_genis_takvim_araligi_reddedilir(): void
    {
        $today = BusinessTime::now();

        $this->getJson(
            '/api/locations/'.$this->locationId().'/menu-calendar'
                .'?from='.$today->toDateString()
                .'&to='.$today->copy()->addDays(200)->toDateString(),
            self::HEADERS,
        )->assertStatus(422)->assertJsonPath('error.code', 'VALIDATION_FAILED');
    }

    // ── Sipariş ─────────────────────────────────────────────────────────

    public function test_paket_siparisi_tek_ust_satir_ve_sifir_fiyatli_bilesenler_yazar(): void
    {
        $this->publishDay(BusinessTime::now(), 18000, [
            ['Mercimek Çorbası', 4000],
            ['Tavuk Sote', 9000],
        ]);

        $orderId = $this->placeOrder([
            ['menu_id' => $this->packageMenuId(), 'quantity' => 2],
        ]);

        $rows = DB::table('order_menus')->where('order_id', $orderId)
            ->orderBy('order_menu_id')->get();

        $this->assertCount(3, $rows, 'Bir paket satırı + iki bileşen bekleniyor.');

        $package = $rows->firstWhere('bld_line_role', 'package');
        $this->assertNotNull($package);
        $this->assertEqualsWithDelta(360.0, (float) $package->subtotal, 0.001);

        $components = $rows->where('bld_line_role', 'component');
        $this->assertCount(2, $components);

        foreach ($components as $component) {
            $this->assertEqualsWithDelta(
                0.0,
                (float) $component->subtotal,
                0.001,
                'Parayı paket satırı taşır.',
            );
            // Her bileşen: 2 paket × pakette 1 porsiyon = 2 adet.
            $this->assertSame(2, (int) $component->quantity);
            $this->assertSame(
                (int) $package->order_menu_id,
                (int) $component->bld_parent_line_id,
            );
        }

        // Sipariş toplamı paket fiyatından: satırların toplamıyla tutuyor.
        $total = (int) DB::table('order_totals')->where('order_id', $orderId)
            ->where('code', 'order_total')->value('value');
        $this->assertSame(360, $total);

        // `total_items` ÜST satırları sayar; bileşenler adet şişirmez.
        $this->assertSame(2, (int) DB::table('orders')->where('order_id', $orderId)->value('total_items'));
    }

    /**
     * PAKETİN SIFIR LİRAYA SATILAMAMASI — bu paketteki en önemli test.
     *
     * Paket ürününün `menu_price` değeri 0,00. Günün menüsü çözülmeden
     * fiyatlanabilseydi her paket siparişi bedava olurdu.
     */
    public function test_paket_gun_cozulmeden_fiyatlanamaz(): void
    {
        // Menü YAYINLANMADI; paket ürünü yine de sipariş ediliyor.
        app(LocationGate::class)->setDailyMenuEnabled($this->location(), false);

        $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->packageMenuId(), 'quantity' => 1]],
            'delivery_type' => 'pickup',
            'payment_method' => 'cash',
        ], self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'ITEM_UNAVAILABLE');

        $this->assertSame(0, DB::table('orders')->count());
    }

    public function test_o_gunun_menusunde_olmayan_urun_reddedilir(): void
    {
        $this->publishDay(BusinessTime::now(), 18000, [['Tavuk Sote', 9000]]);

        $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->menuId('Mercimek Çorbası'), 'quantity' => 1]],
            'delivery_type' => 'pickup',
            'payment_method' => 'cash',
        ], self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'ITEM_UNAVAILABLE');
    }

    public function test_menu_kalemi_tek_basina_alinabilir(): void
    {
        $this->publishDay(BusinessTime::now(), 18000, [
            ['Tavuk Sote', 9000, 7500],
        ]);

        $orderId = $this->placeOrder([
            ['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 2],
        ]);

        // O güne girilen fiyat istisnası geçerli: 2 × 75,00 = 150,00.
        $this->assertEqualsWithDelta(
            150.0,
            (float) DB::table('order_menus')->where('order_id', $orderId)->value('subtotal'),
            0.001,
        );
    }

    public function test_yayinlanmamis_gune_siparis_reddedilir(): void
    {
        $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 1]],
            'delivery_type' => 'pickup',
            'payment_method' => 'cash',
            'service_date' => BusinessTime::now()->addDays(2)->toDateString(),
        ], self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED')
            ->assertJsonPath('error.details.reason', 'not_published');
    }

    public function test_gecmis_gune_siparis_reddedilir(): void
    {
        $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 1]],
            'delivery_type' => 'pickup',
            'payment_method' => 'cash',
            'service_date' => BusinessTime::now()->subDay()->toDateString(),
        ], self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.details.reason', 'past');
    }

    /**
     * "Cuma menüsünü perşembe 12:00'ye" — mutfağın karşılayamayacağı bir
     * sipariş. Sessizce birini seçmek, ya yanlış gün pişirir ya yanlış
     * saatte yollar.
     */
    public function test_servis_gunu_ile_istenen_zaman_celisirse_reddedilir(): void
    {
        $date = BusinessTime::now()->addDay();
        $this->publishDay($date, 18000, [['Tavuk Sote', 9000]]);

        $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->packageMenuId(), 'quantity' => 1]],
            'delivery_type' => 'pickup',
            'payment_method' => 'cash',
            'service_date' => $date->toDateString(),
            'requested_at' => $date->copy()->addDays(2)->setTime(12, 0)->utc()->toIso8601ZuluString(),
        ], self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED');
    }

    public function test_ileri_tarihli_siparisin_servis_gunu_yanitta_doner(): void
    {
        $date = BusinessTime::now()->addDays(3);
        $this->publishDay($date, 18000, [['Tavuk Sote', 9000]]);

        $orderId = $this->placeOrder(
            [['menu_id' => $this->packageMenuId(), 'quantity' => 1]],
            $date->toDateString(),
        );

        $this->asCustomer()->getJson('/api/orders/'.$orderId, self::HEADERS)
            ->assertOk()
            ->assertJsonPath('service_date', $date->toDateString());

        // Değişmez: `bld_service_date === DATE(order_date)`.
        $row = DB::table('orders')->where('order_id', $orderId)->first();
        $this->assertSame(
            Carbon::parse($row->order_date)->toDateString(),
            Carbon::parse($row->bld_service_date)->toDateString(),
        );
    }

    // ── Mutfak ──────────────────────────────────────────────────────────

    public function test_ileri_tarihli_siparis_bugunun_panosuna_dusmez(): void
    {
        $date = BusinessTime::now()->addDays(2);
        $this->publishDay($date, 18000, [['Tavuk Sote', 9000]]);

        $this->placeOrder(
            [['menu_id' => $this->packageMenuId(), 'quantity' => 1]],
            $date->toDateString(),
        );

        $this->asKitchen()->getJson('/api/kitchen/orders', self::HEADERS)
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    /**
     * DOĞRULANMIŞ ÜRETİM HATASININ REGRESYONU (B-19).
     *
     * KDS artımlı çekiyor (`since = son server_time`) ve tam yenilemeyi
     * yalnız açılışta yapıyor. Pazartesi verilip cuma teslim edilecek bir
     * siparişin `updated_at`'i pazartesidir; cuma günü `updated_at > since`
     * hiçbir zaman geçmez ve sipariş PİŞECEĞİ GÜN panoda hiç görünmez.
     *
     * Bugün nadir, gün seçiciyle birlikte varsayılan yol. Düzeltme tamamen
     * sunucuda: imleç iş gününün başlangıcından eskiyse, o gün servis
     * edilecek ama daha önce oluşturulmuş siparişler de yanıta katılıyor.
     */
    public function test_dun_verilen_bugunun_siparisi_artimli_cekimde_gorunur(): void
    {
        $this->publishDay(BusinessTime::now(), 18000, [['Tavuk Sote', 9000]]);

        $orderId = $this->placeOrder([
            ['menu_id' => $this->packageMenuId(), 'quantity' => 1],
        ]);

        // Sipariş dün verilmiş gibi geriye alınıyor: bugünün servis günü,
        // dünün zaman damgaları.
        $yesterday = BusinessTime::forStorage(BusinessTime::now()->subDay());
        DB::table('orders')->where('order_id', $orderId)->update([
            'created_at' => $yesterday,
            'updated_at' => $yesterday,
        ]);

        // İstemcinin imleci dün akşamdan kalma.
        $since = BusinessTime::now()->subDay()->setTime(22, 0)->utc()->toIso8601ZuluString();

        $this->asKitchen()
            ->getJson('/api/kitchen/orders?since='.urlencode($since), self::HEADERS)
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $orderId);
    }

    /**
     * Mutfağın şeridi "40 Günün Menüsü" değil "40 tavuk sote" demeli —
     * o şerit tam olarak bunun için var (`docs/02` §4).
     */
    public function test_uretim_listesi_paketi_bilesenlerine_acar(): void
    {
        $this->publishDay(BusinessTime::now(), 18000, [
            ['Mercimek Çorbası', 4000],
            ['Tavuk Sote', 9000],
        ]);

        $orderId = $this->placeOrder([
            ['menu_id' => $this->packageMenuId(), 'quantity' => 3],
        ]);
        $this->advance($orderId, ['onaylandi']);

        $list = $this->asKitchen()->getJson('/api/kitchen/production-list', self::HEADERS)
            ->assertOk()
            ->json('data');

        $names = array_column($list, 'name');
        $this->assertNotContains('Günün Menüsü', $names);
        $this->assertContains('Tavuk Sote', $names);

        $sote = collect($list)->firstWhere('name', 'Tavuk Sote');
        $this->assertSame(3, $sote['total']);
    }

    /**
     * Paket bir BİRİM olarak düzenlenir. Bileşenler de listelenseydi KDS
     * onları geri gönderir, sunucu tek tek satılan ürünler gibi
     * fiyatlandırır ve siparişin toplamı kendiliğinden şişerdi.
     */
    public function test_duzenleme_ekrani_bilesen_satirlarini_gostermez(): void
    {
        $this->publishDay(BusinessTime::now(), 18000, [
            ['Mercimek Çorbası', 4000],
            ['Tavuk Sote', 9000],
        ]);

        $orderId = $this->placeOrder([
            ['menu_id' => $this->packageMenuId(), 'quantity' => 2],
        ]);
        $this->advance($orderId, ['onaylandi']);

        $items = $this->asKitchen()
            ->getJson('/api/kitchen/orders/'.$orderId.'/editable', self::HEADERS)
            ->assertOk()
            ->json('data.items');

        $this->assertCount(1, $items);
        $this->assertSame($this->packageMenuId(), $items[0]['menu_id']);
    }

    public function test_paket_adedi_dusurulunce_bilesenler_yeniden_acilir(): void
    {
        $this->publishDay(BusinessTime::now(), 18000, [
            ['Mercimek Çorbası', 4000],
            ['Tavuk Sote', 9000],
        ]);

        $orderId = $this->placeOrder([
            ['menu_id' => $this->packageMenuId(), 'quantity' => 3],
        ]);
        $this->advance($orderId, ['onaylandi']);

        $this->asKitchen()->postJson('/api/kitchen/orders/'.$orderId.'/revisions', [
            'reason' => 'musteri_talebi',
            'items' => [['menu_id' => $this->packageMenuId(), 'quantity' => 2]],
        ], self::HEADERS)->assertOk();

        $rows = DB::table('order_menus')->where('order_id', $orderId)->get();
        $this->assertCount(3, $rows);

        $package = $rows->firstWhere('bld_line_role', 'package');
        $this->assertSame(2, (int) $package->quantity);
        $this->assertEqualsWithDelta(360.0, (float) $package->subtotal, 0.001);

        foreach ($rows->where('bld_line_role', 'component') as $component) {
            $this->assertSame(2, (int) $component->quantity);
        }
    }

    /**
     * Mutfak YALNIZCA pişirilecek yemekleri görür.
     *
     * "Ev Yemeği Menüsü (20.08.2026)" bir başlık, bir yemek değil. Rolü
     * istemciye gönderip panoya ve fişe "bu bir başlık" mantığı yazmak yerine
     * satır hiç gönderilmiyor: daha az kod, daha az kavram ve mutfak yazılımı
     * bu değişiklikten hiç haberdar olmuyor.
     */
    public function test_mutfaga_paket_satiri_GONDERILMEZ(): void
    {
        $this->publishDay(BusinessTime::now(), 18000, [
            ['Mercimek Çorbası', 4000],
            ['Tavuk Sote', 9000],
        ]);

        $orderId = $this->placeOrder([
            ['menu_id' => $this->packageMenuId(), 'quantity' => 1],
        ]);
        $this->advance($orderId, ['onaylandi']);

        $names = array_column(
            $this->asKitchen()->getJson('/api/kitchen/orders', self::HEADERS)
                ->assertOk()
                ->json('data.0.items'),
            'name',
        );

        $this->assertSame(['Mercimek Çorbası', 'Tavuk Sote'], $names);

        // Mutfak fişi de aynı listeyi kullanıyor.
        $receiptNames = array_column(
            $this->asKitchen()
                ->getJson('/api/kitchen/orders/'.$orderId.'/receipt?type=mutfak', self::HEADERS)
                ->assertOk()
                ->json('lines'),
            'name',
        );

        $this->assertSame(['Mercimek Çorbası', 'Tavuk Sote'], $receiptNames);
    }

    /**
     * Tükenme ekranı bugüne daralır.
     *
     * Katalogda seksen küsur ürün var ama o gün yalnız menüdekiler
     * satılıyor; satılmayan yetmiş ürünü listelemek mutfağın aradığı üç
     * kalemi bulmasını zorlaştırmaktan başka işe yaramıyor.
     */
    public function test_mutfak_menusu_bugunun_menusune_daralir(): void
    {
        $this->publishDay(BusinessTime::now(), 18000, [
            ['Tavuk Sote', 9000],
        ]);

        $names = array_column(
            $this->asKitchen()->getJson('/api/kitchen/menu-availability', self::HEADERS)
                ->assertOk()
                ->json('data'),
            'name',
        );

        $this->assertContains('Tavuk Sote', $names);
        // Paket de listede: mutfak yalnız paketi kapatabilmeli.
        $this->assertContains('Günün Menüsü', $names);
        $this->assertNotContains('Mercimek Çorbası', $names);
    }

    /**
     * Menü yayınlanmamış bir günde liste BOŞA DÜŞMEZ.
     *
     * Boş bir ekran, uzun bir ekrandan daha kötü bir arıza: plansız bir günde
     * mutfak hiçbir şeyi tükendi işaretleyemez hâle gelirdi.
     */
    public function test_menusuz_gunde_mutfak_katalogu_tam_gelir(): void
    {
        $names = array_column(
            $this->asKitchen()->getJson('/api/kitchen/menu-availability', self::HEADERS)
                ->assertOk()
                ->json('data'),
            'name',
        );

        $this->assertContains('Tavuk Sote', $names);
        $this->assertContains('Mercimek Çorbası', $names);
    }

    // ── Yardımcılar ─────────────────────────────────────────────────────

    private function location(): Location
    {
        return Location::query()->where('location_id', $this->locationId())->firstOrFail();
    }

    private function packageMenuId(): int
    {
        return (int) DailyMenu::packageMenuIdFor($this->locationId());
    }

    private function dailyMenuUrl(?Carbon $date = null): string
    {
        $url = '/api/locations/'.$this->locationId().'/daily-menu';

        return $date !== null ? $url.'?date='.$date->toDateString() : $url;
    }

    /**
     * O güne menü kurar ve yayınlar.
     *
     * @param  list<array{0:string, 1:int, 2?:int}>  $items  [ürün adı, ürün fiyatı, gün fiyatı?]
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
            $override = $items[$index][2] ?? null;

            $product = Menu::query()->where('menu_name', $name)->firstOrFail();
            $product->menu_price = $price / 100;
            $product->save();

            DailyMenuItem::create([
                'daily_menu_id' => $menu->id,
                'menu_id' => $product->menu_id,
                'quantity' => 1,
                'sort_order' => $index,
                'price_override_kurus' => $override,
            ]);
        }

        return $menu->refresh();
    }

    /** @param  list<array<string, mixed>>  $items */
    private function placeOrder(array $items, ?string $serviceDate = null): int
    {
        $payload = [
            'location_id' => $this->locationId(),
            'items' => $items,
            'delivery_type' => 'pickup',
            'payment_method' => 'cash',
        ];

        if ($serviceDate !== null) {
            $payload['service_date'] = $serviceDate;
        }

        return (int) $this->asCustomer()
            ->postJson('/api/orders', $payload, self::HEADERS)
            ->assertCreated()
            ->json('id');
    }
}
