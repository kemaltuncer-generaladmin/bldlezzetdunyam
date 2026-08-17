<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Menu;
use Igniter\Cart\Models\Order;
use Igniter\Local\Models\Location;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Models\ControlAudit;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Models\DailyMenuItem;
use Veykemtu\BridgeApi\Models\DailyMenuStock;
use Veykemtu\BridgeApi\Services\DailyMenuService;
use Veykemtu\BridgeApi\Services\LocationGate;
use Veykemtu\BridgeApi\Services\OrderFactory;
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

    // ── Gerekçe politikası ────────────────────────────────────────────────

    /*
     * TASLAK KURMAK BİR TAAHHÜT DEĞİL, YAYINLAMAK TAAHHÜTTÜR.
     *
     * Gerekçe yalnız müşteriye görünür hâle gelen ve geri alınması zor olan
     * uçlarda isteniyor: `publish`, `unpublish`, `DELETE days`,
     * `duplicate`. Gün kurmak/düzenlemek, kalem yazmak ve tavan yazmak
     * gerekçesiz. Sütun sözleşmesi `docs/control/menu.md` "Uçlar"
     * tablosundadır.
     *
     * Aşağıdaki testler politikanın İKİ YÜZÜNÜ birden sabitliyor: gevşeyen
     * uçta yazma geçiyor, gevşemeyen uçta eski disiplin (422 + denetim
     * satırı YOK) aynen duruyor. Yalnız biri yazılsaydı, ikinci turda
     * "hepsini gevşetelim" demek serbest kalırdı.
     */

    /** Sahibin şikâyetinin tam karşılığı: kalem eklemek gerekçe istemiyor. */
    public function test_gerekcesiz_kalem_eklenebilir(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $this->makeDay($day, 18000, ['Tavuk Sote']);

        $data = $this->signed(
            'POST',
            self::BASE.'/days/'.$day->toDateString().'/items',
            $this->withoutReason(['menu_id' => $this->productId('Mercimek Çorbası')]),
        )->assertOk()->json('data');

        $this->assertCount(2, $data['items'], 'Kalem gerekçesiz eklenebilmeli.');
    }

    /**
     * GEREKÇE SEYRELDİ, DENETİM İZİ SEYRELMEDİ.
     *
     * Satır yine açılıyor ve `actor` yine dolu — seyrelen yalnız "neden".
     * `reason` sütunu `NOT NULL` (`veykemtu_control_audit`); "sorulmadı"
     * boş dize olarak yazılıyor ve bunun için göç açılmadı.
     */
    public function test_gerekcesiz_yazma_da_denetim_satiri_acar(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $menu = $this->makeDay($day, 18000, ['Tavuk Sote']);

        $this->signed(
            'POST',
            self::BASE.'/days/'.$day->toDateString().'/items',
            $this->withoutReason(['menu_id' => $this->productId('Mercimek Çorbası')]),
        )->assertOk();

        $audit = ControlAudit::query()->where('action', 'menu.item.create')->firstOrFail();

        $this->assertSame(ControlAudit::RESULT_APPLIED, $audit->result);
        $this->assertSame(self::ACTOR, $audit->actor, '`actor` her yazmada kalır.');
        $this->assertSame('', (string) $audit->reason, 'Sorulmayan gerekçe boş dize yazılır, `null` değil.');
        $this->assertSame((int) $menu->id, (int) $audit->target_id);
    }

    /**
     * `actor` HER KOŞULDA ZORUNLU — gerekçe istemeyen uçta bile.
     *
     * "Kim yaptı" sorusu hiçbir yerde seyrelmiyor; gevşeyen tek alan
     * `reason`. Aksi hâlde imzalı ama sahipsiz bir yazma mümkün olurdu.
     */
    public function test_aktorsuz_yazma_gerekcesiz_ucta_da_reddedilir(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $menu = $this->makeDay($day, 18000, ['Tavuk Sote']);

        $this->signed('POST', self::BASE.'/days/'.$day->toDateString().'/items', [
            'menu_id' => $this->productId('Mercimek Çorbası'),
        ])->assertStatus(422);

        $this->assertSame(0, ControlAudit::count());
        $this->assertSame(1, DailyMenuItem::query()->where('daily_menu_id', $menu->id)->count());
    }

    /**
     * KURU PROVA DAVRANIŞI DEĞİŞMEDİ.
     *
     * Gerekçenin gevşemesi kabuğun geri kalanına dokunmuyor: `would`
     * dönüyor, `data` dönmüyor, hiçbir satır yazılmıyor ve iz `dry_run`
     * olarak açılıyor.
     */
    public function test_gerekcesiz_ucta_kuru_prova_degismedi(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $menu = $this->makeDay($day, 18000, ['Tavuk Sote']);

        $body = $this->signed(
            'POST',
            self::BASE.'/days/'.$day->toDateString().'/items',
            $this->withoutReason([
                'menu_id' => $this->productId('Mercimek Çorbası'),
                'dry_run' => true,
            ]),
        )->assertOk()->json();

        $this->assertTrue($body['dry_run']);
        $this->assertArrayNotHasKey('data', $body);
        $this->assertSame('menu.item.create', $body['would']['action']);

        $this->assertSame(1, DailyMenuItem::query()->where('daily_menu_id', $menu->id)->count());
        $this->assertSame(
            ControlAudit::RESULT_DRY_RUN,
            ControlAudit::query()->where('action', 'menu.item.create')->firstOrFail()->result,
        );
    }

    /**
     * GEREKÇE ZORUNLU OLAN UÇTA ESKİ DİSİPLİN AYNEN DURUYOR:
     * 422 **ve denetim satırı YOK** — geçerli bir istek hiç oluşmadı.
     */
    public function test_gerekcesiz_yayin_reddedilir_ve_denetim_satiri_acilmaz(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $menu = $this->makeDay($day, 18000, ['Tavuk Sote']);

        $this->signed(
            'POST',
            self::BASE.'/days/'.$day->toDateString().'/publish',
            $this->withoutReason(),
        )->assertStatus(422);

        $this->assertSame(0, ControlAudit::count());
        $this->assertSame(
            DailyMenu::STATUS_DRAFT,
            (string) $menu->refresh()->status,
            'Reddedilen yayın isteği günü taslakta bırakmalı.',
        );
    }

    /**
     * Gerekçe İSTENEN uçta alt sınır hâlâ on karakter.
     *
     * Sınırın kendisi gevşemedi, yalnız SORULDUĞU YER azaldı: "ok" yazıp
     * geçmek yayın gibi bir taahhütte hâlâ serbest değil.
     */
    public function test_yayin_gerekcesi_on_karakterin_altina_inemez(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $this->makeDay($day, 18000, ['Tavuk Sote']);
        $path = self::BASE.'/days/'.$day->toDateString().'/publish';

        // Dokuz karakter — sınırın bir altı.
        $this->signed('POST', $path, ['actor' => self::ACTOR, 'reason' => 'dokuz kar'])
            ->assertStatus(422);

        $this->assertSame(0, ControlAudit::count(), 'Reddedilen istek iz bırakmamalı.');

        // On karakter — sınırın tam üstü.
        $this->signed('POST', $path, ['actor' => self::ACTOR, 'reason' => 'on karakte'])
            ->assertOk()
            ->assertJsonPath('data.status', DailyMenu::STATUS_PUBLISHED);
    }

    /**
     * Geri alınması zor DİĞER iki uç da gerekçe istiyor.
     *
     * `DELETE days` gün ve kalemlerini birlikte götürüyor; `duplicate`
     * toplu çalışıyor ve hedefin üzerine yazabiliyor. Yayın uçları
     * yukarıda ayrıca sınanıyor; bu test tabloyu tamamlıyor.
     */
    public function test_silme_ve_kopyalama_gerekce_ister(): void
    {
        $day = BusinessTime::now()->addDay()->startOfDay();
        $this->makeDay($day, 18000, ['Tavuk Sote']);

        $this->signed('DELETE', self::BASE.'/days/'.$day->toDateString(), $this->withoutReason())
            ->assertStatus(422);

        $this->signed(
            'POST',
            self::BASE.'/days/'.$day->toDateString().'/duplicate',
            $this->withoutReason(['target_date' => $day->copy()->addDays(7)->toDateString()]),
        )->assertStatus(422);

        $this->assertSame(0, ControlAudit::count());
        $this->assertNotNull(
            DailyMenu::query()->whereDate('menu_date', $day->toDateString())->first(),
            'Gerekçesiz silme isteği günü silmemeli.',
        );
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

    // ── Kesim sonrası fiyat kapısı ────────────────────────────────────────

    /**
     * AÇIK BUYDU: kesim geçmiş bir güne KALEM fiyatı yazılabiliyordu.
     *
     * Gün düzeyindeki kapı yalnız `package_price_kurus`'u koruyordu. Kalem
     * ucu açık kalınca müşteri o günün fiyatını görüp sipariş verdikten
     * sonra fiyat değişebiliyordu: sipariş satırları kendi kopyalarını
     * taşıdığı için geçmiş sipariş bozulmuyor, ama MENÜDE GÖRÜNEN fiyat ile
     * O GÜN SATILAN fiyat ayrışıyor ve fark fatura/rapor tarafında
     * açıklanamıyordu.
     */
    public function test_kesim_gecmis_gunde_kalem_fiyati_degistirilemez(): void
    {
        $menu = $this->pastCutoffDay();
        $item = $menu->items()->first();
        $item->update(['price_override_kurus' => 4500]);

        $this->signed(
            'PATCH',
            self::BASE.'/days/'.$menu->menu_date->toDateString().'/items/'.$item->id,
            $this->intent(['price_override_kurus' => 9900]),
        )
            ->assertStatus(409)
            ->assertJsonPath('error.details.conflict', 'cutoff')
            ->assertJsonPath('error.details.fields', ['price_override_kurus']);

        $this->assertSame(
            4500,
            (int) $item->refresh()->price_override_kurus,
            'Reddedilen istek hiçbir şey yazmamalı.',
        );
    }

    /**
     * `quantity` de kilitli: fiyatın ÇARPANI.
     *
     * Birim fiyat aynı kalsa bile porsiyon sayısı o günün menüde görünen
     * tutarını (`DailyMenu::itemsTotalKurus()`) ve paketin fişe basılan
     * porsiyonunu değiştirir — yalnız fiyatı kilitlemek aynı ayrışmayı
     * çarpan üzerinden açık bırakırdı.
     */
    public function test_kesim_gecmis_gunde_kalem_porsiyonu_degistirilemez(): void
    {
        $menu = $this->pastCutoffDay();
        $item = $menu->items()->first();

        $this->signed(
            'PATCH',
            self::BASE.'/days/'.$menu->menu_date->toDateString().'/items/'.$item->id,
            $this->intent(['quantity' => 2]),
        )
            ->assertStatus(409)
            ->assertJsonPath('error.details.conflict', 'cutoff')
            ->assertJsonPath('error.details.fields', ['quantity']);

        $this->assertSame(1, (int) $item->refresh()->quantity);
    }

    /** Kesim geçmemişken kalem fiyatı serbestçe düzeltilir. */
    public function test_kesim_gecmemis_gunde_kalem_fiyati_degistirilebilir(): void
    {
        $menu = $this->openCutoffDay();
        $item = $menu->items()->first();

        $data = $this->signed(
            'PATCH',
            self::BASE.'/days/'.$menu->menu_date->toDateString().'/items/'.$item->id,
            $this->intent(['price_override_kurus' => 9900, 'quantity' => 2]),
        )->assertOk()->json('data.items.0');

        $this->assertSame(9900, $data['price_override_kurus']);
        $this->assertSame(2, $data['quantity']);
    }

    /**
     * KAPI YALNIZ PARAYI KORUYOR.
     *
     * Kesimden sonra mutfağın etiketi düzeltmesi, sırayı değiştirmesi ya da
     * kalemi tek tek satıştan çıkarması meşru; tavan ise aynı gün
     * `PUT .../stock` tarafından kapısız yazılıyor ve iki ucun farklı
     * davranması sessiz bir tuzak olurdu.
     */
    public function test_kesim_sonrasi_kilitlenmeyen_alanlar_yazilabilir(): void
    {
        $menu = $this->pastCutoffDay();
        $item = $menu->items()->first();

        $data = $this->signed(
            'PATCH',
            self::BASE.'/days/'.$menu->menu_date->toDateString().'/items/'.$item->id,
            $this->intent([
                'label' => 'Tavuk Şiş',
                'sort_order' => 40,
                'sellable_alone' => false,
                'is_required' => false,
                'capacity' => 60,
            ]),
        )->assertOk()->json('data.items.0');

        $this->assertSame('Tavuk Şiş', $data['label']);
        $this->assertSame(40, $data['sort_order']);
        $this->assertFalse($data['sellable_alone']);
        $this->assertFalse($data['is_required']);
        $this->assertSame(60, $data['capacity']);
    }

    /** Kalem EKLERKEN de o güne fiyat yazılamaz. */
    public function test_kesim_gecmis_gune_fiyatli_kalem_eklenemez(): void
    {
        $menu = $this->pastCutoffDay();

        $this->signed('POST', self::BASE.'/days/'.$menu->menu_date->toDateString().'/items', $this->intent([
            'menu_id' => $this->productId('Mercimek Çorbası'),
            'price_override_kurus' => 2500,
        ]))
            ->assertStatus(409)
            ->assertJsonPath('error.details.conflict', 'cutoff');

        $this->assertCount(1, $menu->refresh()->items, 'Kalem eklenmemeli.');
    }

    /**
     * Fiyatsız ekleme serbest: o gün için sipariş kapandığından yeni satır
     * satılmış hiçbir şeyi değiştirmiyor, kapalı olan yalnız PARA yazmak.
     */
    public function test_kesim_gecmis_gune_fiyatsiz_kalem_eklenebilir(): void
    {
        $menu = $this->pastCutoffDay();

        $data = $this->signed(
            'POST',
            self::BASE.'/days/'.$menu->menu_date->toDateString().'/items',
            $this->intent(['menu_id' => $this->productId('Mercimek Çorbası')]),
        )->assertOk()->json('data');

        $this->assertCount(2, $data['items']);
    }

    /**
     * Kapı KURU PROVADA DA koşar (`docs/control/00-genel.md` §3.1):
     * "kuru prova geçti" diyen ekran gerçek gönderimde patlamamalı.
     */
    public function test_kesim_kapisi_kuru_provada_da_kosar(): void
    {
        $menu = $this->pastCutoffDay();
        $item = $menu->items()->first();

        $this->signed(
            'PATCH',
            self::BASE.'/days/'.$menu->menu_date->toDateString().'/items/'.$item->id,
            $this->intent(['price_override_kurus' => 9900, 'dry_run' => true]),
        )->assertStatus(409)->assertJsonPath('error.details.conflict', 'cutoff');
    }

    /**
     * SİLMEYE kesim kapısı KONMADI — karar `destroyItem()` yorumunda.
     *
     * Fişte olan kalemi `assertItemUnused()` zaten kilitliyor (paketin
     * zorunlu bileşenleri `order_menus`'a gerçek `menu_id`'leriyle yazılır).
     * Üstüne kesim kapısı koymak yalnız HİÇ SİPARİŞ ALMAMIŞ bir kalemin
     * silinmesini engellerdi — yani "malzeme bitti, listeden çıkardık"ı.
     */
    public function test_kesim_gecmis_gunde_siparissiz_kalem_yine_silinebilir(): void
    {
        $menu = $this->pastCutoffDay();
        $item = $menu->items()->first();

        $this->signed(
            'DELETE',
            self::BASE.'/days/'.$menu->menu_date->toDateString().'/items/'.$item->id,
            $this->intent(),
        )->assertOk()->assertJsonPath('data.deleted', true);

        $this->assertNull(DailyMenuItem::find($item->id));
    }

    /**
     * GÜN düzeyindeki kapı yerinde duruyor ve hâlâ DAR.
     *
     * Kalem kapısı bu kapıyla ortak bir yardımcıya taşındı; gün ucunun
     * davranışı değişmemeli: fiyat 409, başlık serbest.
     */
    public function test_kesim_gecmis_gunde_paket_fiyati_degistirilemez(): void
    {
        $menu = $this->pastCutoffDay();
        $path = self::BASE.'/days/'.$menu->menu_date->toDateString();

        $this->signed('PATCH', $path, $this->intent(['package_price_kurus' => 21000]))
            ->assertStatus(409)
            ->assertJsonPath('error.details.conflict', 'cutoff');

        $this->assertSame(18000, (int) $menu->refresh()->package_price_kurus);

        $this->signed('PATCH', $path, $this->intent(['title' => 'Ev Yemeği Menüsü (düzeltildi)']))
            ->assertOk()
            ->assertJsonPath('data.title', 'Ev Yemeği Menüsü (düzeltildi)');
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

    /**
     * Gerekçesiz gövde — `actor` YİNE ZORUNLU.
     *
     * Kontrol Merkezi paneli gerekçe istemeyen uçlarda alanı hiç
     * göndermeyecek; testlerin de tam olarak o gövdeyi kurması gerekiyor.
     * `reason` boş dize ile göndermek başka bir şeyi sınardı.
     *
     * @param  array<string, mixed>  $extra
     * @return array<string, mixed>
     */
    private function withoutReason(array $extra = []): array
    {
        return ['actor' => self::ACTOR, ...$extra];
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
     * Kesim saati KESİN GEÇMİŞ bir gün.
     *
     * DÜNKÜ servis günü + güne özel `08:00`. `OrderingWindow::cutoffFor()`
     * günün kendi saatini vitrinin genel saatinin önüne aldığı için kesim
     * anı DÜN 08:00'dir ve testin koştuğu saatten bağımsız olarak
     * geçmiştir. Bugün kullanılsaydı test saate bağlanırdı: sabah 07:00'de
     * koşan bir iş kesimi geçmemiş sayar ve paket sessizce yeşil kalırdı.
     *
     * Gün YAYINDA doğuyor — kapının koruduğu şey satılmış bir günün fiyatı.
     */
    private function pastCutoffDay(): DailyMenu
    {
        $menu = $this->makeDay(
            BusinessTime::now()->subDay()->startOfDay(),
            18000,
            ['Tavuk Sote'],
            DailyMenu::STATUS_PUBLISHED,
        );

        $menu->update(['cutoff_time' => '08:00']);

        return $menu->refresh();
    }

    /** Kesimi HENÜZ GEÇMEMİŞ gün: yarın + `08:00`, her koşulda gelecekte. */
    private function openCutoffDay(): DailyMenu
    {
        $menu = $this->makeDay(
            BusinessTime::now()->addDay()->startOfDay(),
            18000,
            ['Tavuk Sote'],
            DailyMenu::STATUS_PUBLISHED,
        );

        $menu->update(['cutoff_time' => '08:00']);

        return $menu->refresh();
    }

    /**
     * O güne yayında bir menü kurar VE gerçek bir sipariş açar.
     *
     * Sipariş `OrderFactory` üzerinden geçiyor, doğrudan tabloya
     * yazılmıyor: kilidin dayandığı `orders.bld_service_date` değerini o
     * yazıyor. Elle insert edilseydi test, gerçekte var olmayan bir
     * değişmezi doğrulardı.
     *
     * NEDEN MÜŞTERİ UCU (`POST /api/orders`) DEĞİL, PANEL BAĞLAMI: müşteri
     * bugünden en fazla `LocationGate::DEFAULT_LOOKAHEAD_DAYS` (7) gün
     * ileriye sipariş verebiliyor ve `OrderingWindow::assertWithinWindow()`
     * daha ilerisini "Bu tarih için henüz sipariş alınmıyor." ile
     * reddediyor. Bu paketin kilitlediği günler bugün pencerenin içinde
     * kalıyor, yani test BUGÜN KIRIK DEĞİL — ama pencere daralırsa ya da
     * kilitli gün ileri taşınırsa sessizce kırılırdı. Kardeşi
     * `AdminDailyMenuTest` tam bu yüzden kırılmıştı ve orada aynı düzeltme
     * yapıldı.
     *
     * Gerçek hayatta da o güne sipariş yalnız yöneticinin telefon
     * siparişinden doğar; `adminContext: true` pencereyi bilerek atlayan
     * tek yol (`OrderFactory::create()` gerekçesi orada yazılı). Kural
     * bilinçli olduğu için gevşetilmiyor, test gerçek doğuş yoluna
     * taşınıyor.
     */
    private function makePublishedDayWithOrder(Carbon $date): DailyMenu
    {
        $menu = $this->makeDay($date, 25000, ['Tavuk Sote'], DailyMenu::STATUS_PUBLISHED);

        app(OrderFactory::class)->create(
            customer: $this->phoneCustomer(),
            location: $this->location(),
            deliveryType: Order::COLLECTION,
            items: [['menu_id' => $this->packageMenuId(), 'quantity' => 1]],
            address: null,
            requestedAt: null,
            paymentMethod: 'cash',
            customerNote: null,
            adminContext: true,
            serviceDate: $date->toDateString(),
        );

        $this->assertSame(
            1,
            DB::table('orders')->whereDate('bld_service_date', $date->toDateString())->count(),
            'Kilidi kuran değişmez: `orders.bld_service_date` yazılmış olmalı.',
        );

        return $menu->refresh();
    }

    /**
     * Panelden girilen siparişin müşterisi.
     *
     * `Admin\PhoneOrders::resolveCustomer()` ile aynı kalıp: telefonla
     * arayanın kaydı panelde açılır, müşteri kayıt/oturum ucundan geçmez —
     * zaten bu paketin sınadığı şey menü uçları, kimlik akışı değil.
     * `invalid.` alan adı RFC 6761 ile ayrılmıştır, kazara posta gitmez.
     *
     * Aynı testte ikinci kez çağrılırsa mevcut kayıt dönüyor: `customers`
     * tablosunda e-posta tekil ve ikinci `save()` kilitli gün kurulumunu
     * konuyla ilgisiz bir tekillik hatasıyla düşürürdü.
     */
    private function phoneCustomer(): ApiCustomer
    {
        $existing = ApiCustomer::query()->firstWhere('email', 'tel-05001112233@bld.invalid');

        if ($existing instanceof ApiCustomer) {
            return $existing;
        }

        $customer = new ApiCustomer;
        $customer->first_name = 'Telefon';
        $customer->last_name = 'Müşterisi';
        $customer->email = 'tel-05001112233@bld.invalid';
        $customer->telephone = '05001112233';
        $customer->status = true;
        $customer->save();

        return $customer;
    }
}
