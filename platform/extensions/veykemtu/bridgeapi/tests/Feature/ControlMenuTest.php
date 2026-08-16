<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Menu;
use Igniter\Local\Models\Location;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Models\ControlAudit;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Models\DailyMenuItem;
use Veykemtu\BridgeApi\Models\DailyMenuStock;
use Veykemtu\BridgeApi\Services\DailyMenuService;
use Veykemtu\BridgeApi\Services\LocationGate;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Kontrol Merkezi — günlük menü takvimi uçları (`/api/control/menu/*`).
 *
 * Sözleşme: `docs/control/menu.md`. Testler o dosyadaki kuralları tek tek
 * sabitliyor; asıl riski şu üç başlık taşıyor:
 *
 * 1. **Yanlış giren bir kural BİR AYI birden etkiler.** Takvimi dolduran
 *    yönetici otuz günü tek oturumda giriyor; kopyalama yanlış davranırsa
 *    hata otuz güne birden yayılır ve ancak o sabah görülür.
 * 2. **Kuru prova gerçekten hiçbir şeyi değiştirmemeli** ama uyarıları
 *    GERÇEKTEN hesaplamalı. `PUT stock`'un bütün değeri bu: yönetici
 *    tavanı yazmadan önce kaç siparişin altında kaldığını görmeli.
 * 3. **Siparişli gün kilitli.** Silme, taslağa çekme ve kalem çıkarma,
 *    siparişin neye karşılık geldiğini kaybettiren eylemler.
 *
 * Kapı (imza, nonce, zaman penceresi) `ControlKdsTest`'te ayrıntılı
 * sınanıyor; burada yalnız yeni rota ailesinin de aynı kapıdan geçtiği
 * doğrulanıyor — kopyalamak, aynı iddiayı iki yerde bakıma mahkûm ederdi.
 */
class ControlMenuTest extends KitchenTestCase
{
    private const string SECRET = 'test-kontrol-merkezi-sirri';

    private const string ACTOR = 'Ayşe Yönetici';

    private const string REASON = 'Takvim düzenlemesi için yapıldı';

    private const string BASE = '/api/control/menu';

    protected function setUp(): void
    {
        parent::setUp();

        putenv('BLD_CONTROL_SECRET='.self::SECRET);
        $_ENV['BLD_CONTROL_SECRET'] = self::SECRET;

        /*
         * Sipariş açan testler için iki kapı: günün menüsü şalteri kapalı
         * doğuyor ve `veykemtu:setup` asgari sepeti 250,00 TL yazıyor. Bu
         * paket menü uçlarını sınıyor, o iki kuralı değil.
         */
        $gate = app(LocationGate::class);
        $gate->setDailyMenuEnabled($this->location(), true);
        $gate->setMinOrderTotal($this->location(), 0);
    }

    // ── Kapı ──────────────────────────────────────────────────────────────

    public function test_IMZASIZ_istek_reddedilir(): void
    {
        $this->getJson(self::BASE.'/calendar?from='.$this->today().'&to='.$this->today(), [
            'Accept' => 'application/json',
        ])->assertStatus(401)->assertJsonPath('error.code', 'UNAUTHENTICATED');
    }

    // ── Takvim ────────────────────────────────────────────────────────────

    /**
     * ARALIKTAKİ HER GÜN DÖNER, menüsü olmayanlar dâhil.
     *
     * Eksik günü atlamak ızgarayı çizen ekranı boşlukları kendi
     * hesaplamaya zorlardı — üstelik "22 Ağustos'a menü girilmemiş" tam da
     * yöneticinin görmesi gereken şey.
     */
    public function test_takvim_bos_gunleri_de_dondurur(): void
    {
        $start = BusinessTime::now()->startOfDay();
        $this->makeDay($start, 18000, ['Tavuk Sote'], DailyMenu::STATUS_PUBLISHED);

        $body = $this->signed(
            'GET',
            self::BASE.'/calendar?from='.$start->toDateString().'&to='.$start->copy()->addDays(2)->toDateString(),
        )->assertOk()->json();

        $this->assertCount(3, $body['data'], 'Aralıktaki üç günün üçü de dönmeli.');
        $this->assertSame($start->toDateString(), $body['data'][0]['date']);
        $this->assertNotNull($body['data'][0]['id']);
        $this->assertSame(1, $body['data'][0]['item_count']);

        // Menüsüz gün: kimlik null, sebep sözleşmedeki sabit.
        $this->assertNull($body['data'][1]['id']);
        $this->assertNull($body['data'][1]['status']);
        $this->assertFalse($body['data'][1]['orderable']);
        $this->assertSame(
            DailyMenuService::REASON_NOT_PUBLISHED,
            $body['data'][1]['not_orderable_reason'],
        );

        $this->assertSame($this->locationId(), $body['meta']['location_id']);
        $this->assertArrayHasKey('max_lookahead_days', $body['meta']);
        $this->assertArrayNotHasKey('page', $body['meta'], 'Takvim sayfalanmaz (§5).');
    }

    /** Tavan `DailyMenuService::MAX_CALENDAR_DAYS`; aşan aralık 422. */
    public function test_takvim_araligi_tavani_asamaz(): void
    {
        $from = BusinessTime::now()->startOfDay();
        $to = $from->copy()->addDays(DailyMenuService::MAX_CALENDAR_DAYS);

        $this->signed(
            'GET',
            self::BASE.'/calendar?from='.$from->toDateString().'&to='.$to->toDateString(),
        )->assertStatus(422)->assertJsonPath('error.code', 'VALIDATION_FAILED');
    }

    /** `remaining_total` tavan yoksa `null` — sıfır ile karıştırılmamalı. */
    public function test_takvim_tavansiz_gunde_kalani_null_dondurur(): void
    {
        $day = BusinessTime::now()->startOfDay();
        $this->makeDay($day, 18000, ['Tavuk Sote'], DailyMenu::STATUS_PUBLISHED);

        $row = $this->signed(
            'GET',
            self::BASE.'/calendar?from='.$day->toDateString().'&to='.$day->toDateString(),
        )->assertOk()->json('data.0');

        $this->assertNull($row['capacity_total']);
        $this->assertNull($row['remaining_total']);
    }

    // ── Gün okuma ─────────────────────────────────────────────────────────

    public function test_gun_okumasi_taslagi_da_dondurur(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $this->makeDay($day, 18000, ['Tavuk Sote', 'Mercimek Çorbası']);

        $data = $this->signed('GET', self::BASE.'/days/'.$day->toDateString())
            ->assertOk()
            ->json('data');

        $this->assertSame(DailyMenu::STATUS_DRAFT, $data['status']);
        $this->assertSame(18000, $data['package_price_kurus']);
        $this->assertCount(2, $data['items']);
        // `published_by` / `created_by` DÖNMEZ: BLD yönetici kimlikleri
        // Kontrol Merkezi kullanıcılarına karşılık gelmiyor.
        $this->assertArrayNotHasKey('published_by', $data);
        $this->assertArrayNotHasKey('created_by', $data);
        $this->assertArrayHasKey('items_total_kurus', $data);
    }

    /** Menü yoksa 404 — boş gövde "menü yok" ile "boş menü var"ı karıştırırdı. */
    public function test_menusuz_gun_404_dondurur(): void
    {
        $this->signed('GET', self::BASE.'/days/'.BusinessTime::now()->addDays(5)->toDateString())
            ->assertStatus(404)
            ->assertJsonPath('error.code', 'NOT_FOUND');
    }

    /** Takvimde olmayan bir gün (31 Şubat) sessizce başka güne kaymamalı. */
    public function test_gecersiz_tarih_sessizce_kaymaz(): void
    {
        $this->signed('GET', self::BASE.'/days/2026-02-31')
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED');
    }

    // ── Gün oluşturma ─────────────────────────────────────────────────────

    public function test_yeni_gun_taslak_dogar_ve_201_doner(): void
    {
        $day = BusinessTime::now()->addDays(2)->startOfDay();

        $data = $this->signed('POST', self::BASE.'/days', $this->intent([
            'date' => $day->toDateString(),
            'title' => 'Ev Yemeği Menüsü',
            'package_price_kurus' => 18000,
            'cutoff_time' => '08:00',
            'capacity_total' => 120,
            'items' => [
                ['menu_id' => $this->productId('Tavuk Sote'), 'quantity' => 1, 'sort_order' => 10],
            ],
        ]))->assertStatus(201)->json();

        $this->assertTrue($data['ok']);
        $this->assertFalse($data['dry_run']);
        // Yayın AYRI bir eylem: yarım girilmiş bir gün kaydedildiği anda
        // müşteriye görünmemeli.
        $this->assertSame(DailyMenu::STATUS_DRAFT, $data['data']['status']);
        $this->assertSame('08:00', $data['data']['cutoff_time']);
        $this->assertSame(120, $data['data']['capacity_total']);
        $this->assertNull($data['data']['published_at']);

        $audit = ControlAudit::query()->where('action', 'menu.day.create')->firstOrFail();
        $this->assertSame(ControlAudit::RESULT_APPLIED, $audit->result);
        $this->assertSame(self::ACTOR, $audit->actor);
    }

    public function test_ayni_tarihe_ikinci_gun_409_verir(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $this->makeDay($day, 18000, ['Tavuk Sote']);

        $this->signed('POST', self::BASE.'/days', $this->intent([
            'date' => $day->toDateString(),
        ]))
            ->assertStatus(409)
            ->assertJsonPath('error.code', 'CONFLICT')
            ->assertJsonPath('error.details.conflict', 'date');
    }

    public function test_gecmis_gune_menu_kurulamaz(): void
    {
        $this->signed('POST', self::BASE.'/days', $this->intent([
            'date' => BusinessTime::now()->subDay()->toDateString(),
        ]))->assertStatus(422)->assertJsonPath('error.code', 'VALIDATION_FAILED');
    }

    /** Sıfır paket fiyatı "bedava paket" demek olurdu; `LineResolver` da reddediyor. */
    public function test_sifir_paket_fiyati_reddedilir(): void
    {
        $this->signed('POST', self::BASE.'/days', $this->intent([
            'date' => BusinessTime::now()->addDay()->toDateString(),
            'package_price_kurus' => 0,
        ]))->assertStatus(422);
    }

    public function test_ayni_urun_iki_kez_verilemez(): void
    {
        $id = $this->productId('Tavuk Sote');

        $this->signed('POST', self::BASE.'/days', $this->intent([
            'date' => BusinessTime::now()->addDay()->toDateString(),
            'items' => [
                ['menu_id' => $id, 'quantity' => 1],
                ['menu_id' => $id, 'quantity' => 2],
            ],
        ]))->assertStatus(422);
    }

    /**
     * KURU PROVA HİÇBİR ŞEY YAZMAZ ama çakışmayı RAPORLAR.
     *
     * `would.conflicts_with_existing` sözleşmede tanımlı bir alan; kuru
     * provada 409 fırlatılsaydı alan her zaman `false` olur ve hiçbir şey
     * anlatmazdı. Gerçek gönderim yine 409 verir.
     */
    public function test_kuru_prova_yazmaz_ve_cakismayi_raporlar(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $this->makeDay($day, 18000, ['Tavuk Sote']);

        $body = $this->signed('POST', self::BASE.'/days', $this->intent([
            'date' => $day->toDateString(),
            'dry_run' => true,
        ]))->assertOk()->json();

        $this->assertTrue($body['dry_run']);
        $this->assertTrue($body['would']['conflicts_with_existing']);
        $this->assertArrayNotHasKey('data', $body);

        $this->assertSame(1, DailyMenu::query()->whereDate('menu_date', $day->toDateString())->count());
        $this->assertSame(
            ControlAudit::RESULT_DRY_RUN,
            ControlAudit::query()->where('action', 'menu.day.create')->firstOrFail()->result,
        );
    }

    public function test_gerekcesiz_yazma_reddedilir_ve_denetim_satiri_acilmaz(): void
    {
        $this->signed('POST', self::BASE.'/days', [
            'actor' => self::ACTOR,
            'reason' => 'kısa',
            'date' => BusinessTime::now()->addDay()->toDateString(),
        ])->assertStatus(422);

        // Geçerli bir istek hiç oluşmadı; denetim satırı da yok.
        $this->assertSame(0, ControlAudit::count());
    }

    // ── Gün güncelleme ────────────────────────────────────────────────────

    /**
     * KISMİ YAZMA: gönderilmeyen alan değişmez, `null` gönderilen temizlenir.
     *
     * İkisi ayrı olmasaydı yönetici bir iç notu asla silemezdi.
     */
    public function test_patch_kismi_yazar_ve_null_alani_temizler(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $menu = $this->makeDay($day, 18000, ['Tavuk Sote']);
        $menu->internal_note = 'Tedarikçi B firması';
        $menu->save();

        $data = $this->signed('PATCH', self::BASE.'/days/'.$day->toDateString(), $this->intent([
            'package_price_kurus' => 19000,
        ]))->assertOk()->json('data');

        $this->assertSame(19000, $data['package_price_kurus']);
        $this->assertSame('Tedarikçi B firması', $data['internal_note'], 'Gönderilmeyen alan değişmemeli.');
        $this->assertSame('Ev Yemeği Menüsü', $data['title']);

        $data = $this->signed('PATCH', self::BASE.'/days/'.$day->toDateString(), $this->intent([
            'internal_note' => null,
        ]))->assertOk()->json('data');

        $this->assertNull($data['internal_note'], '`null` gönderilen alan temizlenmeli.');
    }

    /** `status` bu uçtan yazılamaz; sessizce yok saymak yerine 422. */
    public function test_patch_durumu_yazamaz(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $this->makeDay($day, 18000, ['Tavuk Sote']);

        $this->signed('PATCH', self::BASE.'/days/'.$day->toDateString(), $this->intent([
            'status' => DailyMenu::STATUS_PUBLISHED,
        ]))->assertStatus(422)->assertJsonPath('error.details.field', 'status');
    }

    // ── Silme ─────────────────────────────────────────────────────────────

    public function test_yayindaki_gun_silinemez(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $this->makeDay($day, 18000, ['Tavuk Sote'], DailyMenu::STATUS_PUBLISHED);

        $this->signed('DELETE', self::BASE.'/days/'.$day->toDateString(), $this->intent())
            ->assertStatus(409)
            ->assertJsonPath('error.details.conflict', 'status');
    }

    public function test_taslak_gun_kalemleriyle_silinir(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $menu = $this->makeDay($day, 18000, ['Tavuk Sote', 'Mercimek Çorbası']);

        $this->signed('DELETE', self::BASE.'/days/'.$day->toDateString(), $this->intent())
            ->assertOk()
            ->assertJsonPath('data.deleted', true);

        $this->assertNull(DailyMenu::find($menu->id));
        $this->assertSame(0, DailyMenuItem::query()->where('daily_menu_id', $menu->id)->count());
    }

    // ── Yayın ─────────────────────────────────────────────────────────────

    public function test_kalemsiz_gun_yayinlanamaz(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $this->makeDay($day, 18000, []);

        $this->signed('POST', self::BASE.'/days/'.$day->toDateString().'/publish', $this->intent())
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED');
    }

    /** Paket kapalı + kalemler kapalı = o gün hiçbir şey satılamaz. */
    public function test_satilamaz_gun_yayinlanamaz(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $menu = $this->makeDay($day, null, ['Tavuk Sote']);
        $menu->components_sellable = false;
        $menu->save();

        $this->signed('POST', self::BASE.'/days/'.$day->toDateString().'/publish', $this->intent())
            ->assertStatus(422);
    }

    /**
     * Satıştan kaldırılmış ürünü içeren menüyü yayınlamak, sepete
     * eklenemeyecek bir menü yayınlamaktır.
     */
    public function test_kapali_urun_iceren_gun_yayinlanamaz(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $this->makeDay($day, 18000, ['Tavuk Sote']);

        Menu::query()->where('menu_id', $this->productId('Tavuk Sote'))
            ->update(['menu_status' => 0]);

        $this->signed('POST', self::BASE.'/days/'.$day->toDateString().'/publish', $this->intent())
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'ITEM_UNAVAILABLE')
            ->assertJsonPath('error.details.menu_id', $this->productId('Tavuk Sote'));
    }

    public function test_yayinlama_damgayi_yazar_ve_ikinci_kez_409_verir(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $this->makeDay($day, 18000, ['Tavuk Sote']);
        $path = self::BASE.'/days/'.$day->toDateString().'/publish';

        $data = $this->signed('POST', $path, $this->intent())->assertOk()->json('data');

        $this->assertSame(DailyMenu::STATUS_PUBLISHED, $data['status']);
        $this->assertNotNull($data['published_at']);

        $this->signed('POST', $path, $this->intent())
            ->assertStatus(409)
            ->assertJsonPath('error.details.conflict', 'status');
    }

    /** Ön denetim KURU PROVADA DA koşar — "prova geçti" yanıltmamalı. */
    public function test_kuru_provada_da_on_denetim_kosar(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $this->makeDay($day, 18000, []);

        $this->signed('POST', self::BASE.'/days/'.$day->toDateString().'/publish', $this->intent([
            'dry_run' => true,
        ]))->assertStatus(422);
    }

    public function test_siparisli_gun_taslaga_cekilemez(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $this->makePublishedDayWithOrder($day);

        $this->signed('POST', self::BASE.'/days/'.$day->toDateString().'/unpublish', $this->intent())
            ->assertStatus(409)
            ->assertJsonPath('error.details.conflict', 'orders')
            ->assertJsonPath('error.details.order_count', 1);
    }

    // ── Kalemler ──────────────────────────────────────────────────────────

    /** Sıra verilmezse mevcut en büyük + 10 — araya kalem sokulabilsin. */
    public function test_kalem_eklenir_ve_sira_onar_artar(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $menu = $this->makeDay($day, 18000, ['Tavuk Sote']);
        $menu->items()->first()->update(['sort_order' => 10]);

        $data = $this->signed('POST', self::BASE.'/days/'.$day->toDateString().'/items', $this->intent([
            'menu_id' => $this->productId('Mercimek Çorbası'),
            'quantity' => 1,
        ]))->assertOk()->json('data');

        $this->assertCount(2, $data['items']);
        $this->assertSame(20, $data['items'][1]['sort_order']);
    }

    public function test_ayni_urun_ikinci_kez_eklenemez(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $this->makeDay($day, 18000, ['Tavuk Sote']);

        $this->signed('POST', self::BASE.'/days/'.$day->toDateString().'/items', $this->intent([
            'menu_id' => $this->productId('Tavuk Sote'),
        ]))
            ->assertStatus(409)
            ->assertJsonPath('error.details.conflict', 'menu_id');
    }

    /** Ürünü değiştirmek kalemi silip yenisini eklemektir — iki ayrı iz. */
    public function test_kalem_urunu_degistirilemez(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $menu = $this->makeDay($day, 18000, ['Tavuk Sote']);
        $item = $menu->items()->first();

        $this->signed(
            'PATCH',
            self::BASE.'/days/'.$day->toDateString().'/items/'.$item->id,
            $this->intent(['menu_id' => $this->productId('Mercimek Çorbası')]),
        )->assertStatus(422)->assertJsonPath('error.details.field', 'menu_id');
    }

    public function test_kalem_guncellemesi_kismidir(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $menu = $this->makeDay($day, 18000, ['Tavuk Sote']);
        $item = $menu->items()->first();
        $item->update(['label' => 'Günün Ana Yemeği', 'quantity' => 1]);

        $data = $this->signed(
            'PATCH',
            self::BASE.'/days/'.$day->toDateString().'/items/'.$item->id,
            $this->intent(['quantity' => 2]),
        )->assertOk()->json('data.items.0');

        $this->assertSame(2, $data['quantity']);
        $this->assertSame('Günün Ana Yemeği', $data['label'], 'Gönderilmeyen alan değişmemeli.');
    }

    /**
     * Denetim izinde kalem eylemlerinin HEDEFİ GÜNDÜR, kalem değil:
     * "17 Ağustos menüsüne ne oldu" tek `target_id` ile cevaplanabilmeli.
     */
    public function test_kalem_denetimi_gunu_hedefler(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $menu = $this->makeDay($day, 18000, ['Tavuk Sote']);

        $this->signed('POST', self::BASE.'/days/'.$day->toDateString().'/items', $this->intent([
            'menu_id' => $this->productId('Mercimek Çorbası'),
        ]))->assertOk();

        $audit = ControlAudit::query()->where('action', 'menu.item.create')->firstOrFail();

        $this->assertSame('daily_menu', $audit->target_type);
        $this->assertSame((int) $menu->id, (int) $audit->target_id);
    }

    /** Mutfağın bugün pişirdiği bir kalem listeden sessizce düşmemeli. */
    public function test_siparisde_kullanilan_kalem_silinemez(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $menu = $this->makePublishedDayWithOrder($day);
        $item = $menu->items()->first();

        $this->signed(
            'DELETE',
            self::BASE.'/days/'.$day->toDateString().'/items/'.$item->id,
            $this->intent(),
        )->assertStatus(409)->assertJsonPath('error.details.conflict', 'orders');
    }

    public function test_kullanilmayan_kalem_silinir(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $menu = $this->makeDay($day, 18000, ['Tavuk Sote']);
        $item = $menu->items()->first();

        $this->signed(
            'DELETE',
            self::BASE.'/days/'.$day->toDateString().'/items/'.$item->id,
            $this->intent(),
        )->assertOk()->assertJsonPath('data.deleted', true);

        $this->assertNull(DailyMenuItem::find($item->id));
    }

    // ── Stok ──────────────────────────────────────────────────────────────

    /**
     * `sold` İKİ BİLEŞENLİ ve ikisi ayrı gösterilir.
     *
     * Abonelikler stoku ÖNCE rezerve ediyor (`reserved` kolonu); yönetici
     * "34 porsiyon kaldı" dediğinde bunun kaçının aboneliğe ayrıldığını
     * bilmeli.
     */
    public function test_stok_okumasi_satilani_ve_rezerveyi_ayirir(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $menu = $this->makeDay($day, 18000, ['Tavuk Sote'], DailyMenu::STATUS_PUBLISHED);
        $this->setCapacity($day, DailyMenuStock::DAY_TOTAL, 120, sold: 66, reserved: 20);

        $data = $this->signed('GET', self::BASE.'/days/'.$day->toDateString().'/stock')
            ->assertOk()
            ->json('data');

        $this->assertSame($day->toDateString(), $data['date']);
        $this->assertSame(120, $data['day']['capacity']);
        $this->assertSame(86, $data['day']['sold']);
        $this->assertSame(66, $data['day']['sold_orders']);
        $this->assertSame(20, $data['day']['sold_subscriptions']);
        $this->assertSame(34, $data['day']['remaining']);
        $this->assertFalse($data['day']['full']);

        // Tavanı olmayan kalem: `remaining` SIFIR DEĞİL `null` — "tavan
        // konmamış" ile "doldu" karıştırılmamalı.
        $this->assertSame((int) $menu->items()->first()->id, $data['items'][0]['item_id']);
        $this->assertNull($data['items'][0]['capacity']);
        $this->assertNull($data['items'][0]['remaining']);
        // Tavan dolması OTOMATİK, `sold_out` MUTFAĞIN işareti — ikisi ayrı.
        $this->assertFalse($data['items'][0]['full']);
        $this->assertFalse($data['items'][0]['sold_out']);
        $this->assertSame([], $data['blocking']['items']);
    }

    /** Tavanı dolan kalem `blocking.items` içinde `menu_id` ile listelenir. */
    public function test_tavani_dolan_kalem_blocking_listesine_girer(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $this->makeDay($day, 18000, ['Tavuk Sote'], DailyMenu::STATUS_PUBLISHED);
        $this->setCapacity($day, $this->productId('Tavuk Sote'), 60, sold: 46, reserved: 14);

        $data = $this->signed('GET', self::BASE.'/days/'.$day->toDateString().'/stock')
            ->assertOk()
            ->json('data');

        $this->assertSame(0, $data['items'][0]['remaining']);
        $this->assertTrue($data['items'][0]['full']);
        $this->assertSame([$this->productId('Tavuk Sote')], $data['blocking']['items']);
        $this->assertFalse($data['blocking']['day']);
    }

    /**
     * `PUT stock` TAM LİSTEDİR: gönderilmeyen kalemin tavanı `null`'a düşer.
     *
     * Fark göndermek, iki sekmede açık iki yöneticinin birbirinin tavanını
     * sessizce koruması demekti.
     */
    public function test_stok_yazmasi_tam_listedir(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $menu = $this->makeDay($day, 18000, ['Tavuk Sote', 'Mercimek Çorbası']);
        $items = $menu->items()->get();

        $this->setCapacity($day, $this->productId('Tavuk Sote'), 50);
        $this->setCapacity($day, $this->productId('Mercimek Çorbası'), 50);

        $this->signed('PUT', self::BASE.'/days/'.$day->toDateString().'/stock', $this->intent([
            'capacity_total' => 120,
            'items' => [['item_id' => (int) $items[0]->id, 'capacity' => 60]],
        ]))->assertOk();

        $this->assertSame(120, $this->capacityOf($day, DailyMenuStock::DAY_TOTAL));
        $this->assertSame(60, $this->capacityOf($day, $this->productId('Tavuk Sote')));
        // "Satır yoksa sınırsız": listede olmayan kalemin satırı düşer.
        $this->assertNull(
            $this->capacityOf($day, $this->productId('Mercimek Çorbası')),
            'Listede olmayan kalemin tavanı kalkmalı.',
        );
    }

    /** SAYAÇLAR KORUNUR: tavanı yeniden yazmak satılanı sıfırlamaz. */
    public function test_tavan_yazmasi_sayaclari_sifirlamaz(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $this->makeDay($day, 18000, ['Tavuk Sote']);
        $this->setCapacity($day, DailyMenuStock::DAY_TOTAL, 100, sold: 12, reserved: 5);

        $this->signed('PUT', self::BASE.'/days/'.$day->toDateString().'/stock', $this->intent([
            'capacity_total' => 150,
        ]))->assertOk();

        $row = $this->stockRow($day, DailyMenuStock::DAY_TOTAL);

        $this->assertSame(150, (int) $row->capacity);
        $this->assertSame(12, (int) $row->sold);
        $this->assertSame(5, (int) $row->reserved);
    }

    /** Sıfır geçerli bir tavandır: "bugün satılmıyor". */
    public function test_sifir_tavan_gecerlidir(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $menu = $this->makeDay($day, 18000, ['Tavuk Sote']);
        $item = $menu->items()->first();

        $this->signed('PUT', self::BASE.'/days/'.$day->toDateString().'/stock', $this->intent([
            'capacity_total' => 0,
            'items' => [['item_id' => (int) $item->id, 'capacity' => 0]],
        ]))->assertOk();

        $this->assertSame(0, $this->capacityOf($day, DailyMenuStock::DAY_TOTAL));
        $this->assertSame(0, $this->capacityOf($day, $this->productId('Tavuk Sote')));
    }

    /** Başka güne ait kalem kimliği yazdırılamaz. */
    public function test_baska_gunun_kalemi_yazilamaz(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $this->makeDay($day, 18000, ['Tavuk Sote']);
        $other = $this->makeDay($day->copy()->addDay(), 18000, ['Mercimek Çorbası']);

        $this->signed('PUT', self::BASE.'/days/'.$day->toDateString().'/stock', $this->intent([
            'capacity_total' => 100,
            'items' => [['item_id' => (int) $other->items()->first()->id, 'capacity' => 10]],
        ]))->assertStatus(422);
    }

    /**
     * Tavanı satılmışın altına çekmek 409 VERMEZ — gerçek hayatta malzeme
     * biter. Ama yanıt bunu açıkça söyler ve kuru prova da hesaplar.
     */
    public function test_satilanin_altina_cekilen_tavan_uyari_uretir(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $menu = $this->makeDay($day, 18000, ['Tavuk Sote'], DailyMenu::STATUS_PUBLISHED);
        $item = $menu->items()->first();

        $this->setCapacity($day, $this->productId('Tavuk Sote'), 80, sold: 46, reserved: 14);

        $body = $this->signed('PUT', self::BASE.'/days/'.$day->toDateString().'/stock', $this->intent([
            'dry_run' => true,
            'items' => [['item_id' => (int) $item->id, 'capacity' => 50]],
        ]))->assertOk()->json();

        $this->assertTrue($body['dry_run']);
        $this->assertNotEmpty(
            $body['would']['warnings'],
            'Kuru provanın asıl işi bu: tavan yazılmadan önce kaç siparişin altında kaldığı.',
        );
        $this->assertSame('capacity_below_sold', $body['would']['warnings'][0]['code']);
        $this->assertSame(60, $body['would']['warnings'][0]['sold']);
        // `remaining` negatife düşmez, `0` olur; gerçek bilgi `oversold`.
        $this->assertSame(0, $body['would']['items'][0]['remaining']);
        $this->assertTrue($body['would']['items'][0]['oversold']);

        // Kuru prova hiçbir şey yazmadı.
        $this->assertSame(80, $this->capacityOf($day, $this->productId('Tavuk Sote')));
    }

    // ── Kopyalama ─────────────────────────────────────────────────────────

    /**
     * KOPYA HER ZAMAN TASLAK DÜŞER, kaynak yayında olsa bile.
     *
     * Aksi hâlde bir haftayı kopyalayan yönetici, yarım kalmış yedi günü
     * de satışa çıkarmış olurdu.
     */
    public function test_kopya_taslak_duser_ve_kalemleri_tasir(): void
    {
        $source = BusinessTime::now()->addDay()->startOfDay();
        $target = $source->copy()->addDays(7);

        $menu = $this->makeDay($source, 18000, ['Tavuk Sote', 'Mercimek Çorbası'], DailyMenu::STATUS_PUBLISHED);
        $menu->internal_note = 'Kaynak günün notu';
        $menu->image_path = 'veykemtu/daily/kaynak.jpg';
        $menu->save();

        // Tavan taşınır, SAYAÇ taşınmaz: hedef güne henüz kimse sipariş
        // vermedi.
        $this->setCapacity($source, DailyMenuStock::DAY_TOTAL, 120, sold: 40);

        $data = $this->signed(
            'POST',
            self::BASE.'/days/'.$source->toDateString().'/duplicate',
            $this->intent(['target_date' => $target->toDateString()]),
        )->assertOk()->json('data');

        $this->assertSame(DailyMenu::STATUS_DRAFT, $data['status']);
        $this->assertSame(2, $data['item_count']);

        $copy = DailyMenu::query()
            ->whereDate('menu_date', $target->toDateString())
            ->firstOrFail();

        $this->assertSame(18000, (int) $copy->package_price_kurus);
        $this->assertNull($copy->published_at);
        // Görsel ve iç not güne özgü: kopyalamak yanlış fotoğrafı yayınlatırdı.
        $this->assertNull($copy->internal_note);
        $this->assertNull($copy->image_path);

        $this->assertSame(120, $this->capacityOf($target, DailyMenuStock::DAY_TOTAL));
        $this->assertSame(
            0,
            (int) $this->stockRow($target, DailyMenuStock::DAY_TOTAL)->sold,
            'Sayaçlar taşınmaz: hedef güne henüz sipariş girmedi.',
        );
    }

    public function test_dolu_hedefe_onaysiz_kopyalanmaz(): void
    {
        $source = BusinessTime::now()->addDay()->startOfDay();
        $target = $source->copy()->addDay();

        $this->makeDay($source, 18000, ['Tavuk Sote']);
        $this->makeDay($target, 20000, ['Mercimek Çorbası']);

        $this->signed(
            'POST',
            self::BASE.'/days/'.$source->toDateString().'/duplicate',
            $this->intent(['target_date' => $target->toDateString()]),
        )->assertStatus(409)->assertJsonPath('error.details.conflict', 'target_date');
    }

    public function test_yayindaki_hedefin_uzerine_kopyalanmaz(): void
    {
        $source = BusinessTime::now()->addDay()->startOfDay();
        $target = $source->copy()->addDay();

        $this->makeDay($source, 18000, ['Tavuk Sote']);
        $this->makeDay($target, 20000, ['Mercimek Çorbası'], DailyMenu::STATUS_PUBLISHED);

        $this->signed(
            'POST',
            self::BASE.'/days/'.$source->toDateString().'/duplicate',
            $this->intent(['target_date' => $target->toDateString(), 'overwrite' => true]),
        )->assertStatus(409)->assertJsonPath('error.details.conflict', 'status');
    }

    /** Denetimde hedef GÜNDÜR; kaynak yükte durur ("bu gün nereden geldi"). */
    public function test_kopyalama_denetimi_kaynagi_yuke_yazar(): void
    {
        $source = BusinessTime::now()->addDay()->startOfDay();
        $target = $source->copy()->addDays(7);

        $this->makeDay($source, 18000, ['Tavuk Sote']);

        $this->signed(
            'POST',
            self::BASE.'/days/'.$source->toDateString().'/duplicate',
            $this->intent(['target_date' => $target->toDateString()]),
        )->assertOk();

        $audit = ControlAudit::query()->where('action', 'menu.duplicate')->firstOrFail();

        $this->assertSame($source->toDateString(), $audit->payload_json['source_date']);
        $this->assertSame($target->toDateString(), $audit->payload_json['target_date']);
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    /**
     * İmzalı istek — kanonik dize `docs/control/00-genel.md` §1.
     *
     * `ControlKdsTest`'teki kopyanın aynısı; oradaki `private` ve o dosya
     * K-21 paketinin bakımında.
     *
     * @param  array<string, mixed>|null  $body
     */
    private function signed(string $method, string $path, ?array $body = null): TestResponse
    {
        $raw = $body === null ? '' : (string) json_encode($body, JSON_UNESCAPED_UNICODE);
        $timestamp = time();
        $nonce = bin2hex(random_bytes(12));

        $canonical = implode("\n", [
            strtoupper($method),
            // Sorgu dizesi imzaya GİRMEZ.
            (string) parse_url($path, PHP_URL_PATH),
            (string) $timestamp,
            $nonce,
            hash('sha256', $raw),
        ]);

        return $this->call($method, $path, [], [], [], [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_X_CONTROL_TIMESTAMP' => (string) $timestamp,
            'HTTP_X_CONTROL_NONCE' => $nonce,
            'HTTP_X_CONTROL_SIGNATURE' => 'sha256='.hash_hmac('sha256', $canonical, self::SECRET),
        ], $raw);
    }

    /**
     * @param  array<string, mixed>  $extra
     * @return array<string, mixed>
     */
    private function intent(array $extra = []): array
    {
        return ['actor' => self::ACTOR, 'reason' => self::REASON, ...$extra];
    }

    private function today(): string
    {
        return BusinessTime::now()->toDateString();
    }

    private function location(): Location
    {
        return Location::query()->where('location_id', $this->locationId())->firstOrFail();
    }

    private function productId(string $name): int
    {
        return (int) Menu::query()->where('menu_name', $name)->firstOrFail()->menu_id;
    }

    private function packageMenuId(): int
    {
        return (int) DailyMenu::packageMenuIdFor($this->locationId());
    }

    /**
     * Stok satırı kurar.
     *
     * Tavan `veykemtu_daily_menus`'ta değil, `veykemtu_daily_menu_stock`
     * satırında yaşıyor: sayaçlar (`sold`, `reserved`) tavanla aynı satırda
     * durmak zorunda ki düşüm tek koşullu `UPDATE` ile yapılabilsin
     * (`DailyStock`). `menu_id = 0` gün toplamıdır.
     */
    private function setCapacity(
        Carbon $date,
        int $menuId,
        int $capacity,
        int $sold = 0,
        int $reserved = 0,
    ): DailyMenuStock {
        return DailyMenuStock::create([
            'location_id' => $this->locationId(),
            'service_date' => $date->toDateString(),
            'menu_id' => $menuId,
            'capacity' => $capacity,
            'sold' => $sold,
            'reserved' => $reserved,
        ]);
    }

    private function stockRow(Carbon $date, int $menuId): DailyMenuStock
    {
        return DailyMenuStock::query()
            ->where('location_id', $this->locationId())
            ->whereDate('service_date', $date->toDateString())
            ->where('menu_id', $menuId)
            ->firstOrFail();
    }

    /** Tavan; satır yoksa `null` ("sınırsız"). */
    private function capacityOf(Carbon $date, int $menuId): ?int
    {
        $row = DailyMenuStock::query()
            ->where('location_id', $this->locationId())
            ->whereDate('service_date', $date->toDateString())
            ->where('menu_id', $menuId)
            ->first();

        return $row === null ? null : (int) $row->capacity;
    }

    /** @param list<string> $items */
    private function makeDay(
        Carbon $date,
        ?int $packagePriceKurus,
        array $items,
        string $status = DailyMenu::STATUS_DRAFT,
    ): DailyMenu {
        $menu = DailyMenu::create([
            'location_id' => $this->locationId(),
            'menu_date' => $date->toDateString(),
            'title' => 'Ev Yemeği Menüsü',
            'package_price_kurus' => $packagePriceKurus,
            'components_sellable' => true,
            'status' => $status,
            'published_at' => $status === DailyMenu::STATUS_PUBLISHED
                ? BusinessTime::forStorage(BusinessTime::now())
                : null,
        ]);

        foreach ($items as $index => $name) {
            DailyMenuItem::create([
                'daily_menu_id' => $menu->id,
                'menu_id' => $this->productId($name),
                'quantity' => 1,
                'sort_order' => ($index + 1) * 10,
            ]);
        }

        return $menu->refresh();
    }

    /**
     * O güne yayında bir menü kurar VE gerçek bir sipariş açar.
     *
     * Sipariş `OrderFactory` üzerinden geçiyor: kilidin dayandığı
     * `orders.bld_service_date` değerini o yazıyor. Elle insert edilseydi
     * test, gerçekte var olmayan bir değişmezi doğrulardı.
     */
    private function makePublishedDayWithOrder(Carbon $date): DailyMenu
    {
        $menu = $this->makeDay($date, 25000, ['Tavuk Sote'], DailyMenu::STATUS_PUBLISHED);

        $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->packageMenuId(), 'quantity' => 1]],
            'delivery_type' => 'pickup',
            'payment_method' => 'cash',
            'service_date' => $date->toDateString(),
        ], self::HEADERS)->assertCreated();

        $this->assertSame(
            1,
            DB::table('orders')->whereDate('bld_service_date', $date->toDateString())->count(),
        );

        // Müşteri belirteci sonraki panel isteklerine bulaşmasın.
        $this->withHeaders(['Authorization' => '']);

        return $menu->refresh();
    }
}
