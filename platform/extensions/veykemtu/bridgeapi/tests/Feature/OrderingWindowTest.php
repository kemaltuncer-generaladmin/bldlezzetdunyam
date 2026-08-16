<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Menu;
use Igniter\Local\Models\Location;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Models\DailyMenuItem;
use Veykemtu\BridgeApi\Services\DailyMenuService;
use Veykemtu\BridgeApi\Services\LocationGate;
use Veykemtu\BridgeApi\Services\OrderingWindow;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Sipariş penceresi — kesim saati, hafta sonu ve ileri görüş penceresi (S1).
 *
 * BU PAKET İKİ SESSİZ ARIZAYI KİLİTLİYOR; ikisi de "kural doğru yazıldı ama
 * hiç çalışmadı" türünden:
 *
 *   (a) `bld_daily_menu_enabled` KAPALIYKEN kesim saati.
 *       Kesim `LocationGate`'ten `OrderingWindow`'a taşınırken, şalter kapalı
 *       bir kurulumda hiç kesim kalmaması işten bile değildi: menü rejimi
 *       kapalıyken `DailyMenuService::assertOrderable()` zaten hiç
 *       çağrılmıyor. `test_gunun_menusu_kapaliyken_de_kesim_uygulanir` tam
 *       olarak bunu tutuyor.
 *
 *   (b) Cumartesi günü PAZARTESİYE sipariş.
 *       `LocationGate::isOpen()` TastyIgniter'ın çalışma takvimine bakıyordu
 *       ve o takvim hafta sonunu kapalı gösterirse "Çalışma saatlerimiz
 *       dışındasınız" hatası, hafta sonu satış kanalını tamamen kapatıyordu
 *       (iş kuralı 3'ün sessiz ihlali).
 *       `test_cumartesi_pazartesiye_siparis_verilebilir` takvimi bilerek
 *       hafta sonuna kapatıp siparişin yine de geçtiğini doğruluyor.
 *
 * Zaman DONDURULUYOR: kesim kuralı "şimdi"ye göre karar veriyor ve gerçek
 * saate bağlı bir test günün belli saatlerinde kırmızı olurdu. Sabit günler
 * de bilerek seçildi — 2026-09-05 cumartesi, 2026-09-07 pazartesi,
 * 2026-09-08 salı.
 */
class OrderingWindowTest extends KitchenTestCase
{
    private const string TUESDAY = '2026-09-08';

    private const string WEDNESDAY = '2026-09-09';

    private const string SATURDAY = '2026-09-05';

    private const string MONDAY = '2026-09-07';

    protected function setUp(): void
    {
        parent::setUp();

        $gate = app(LocationGate::class);
        $gate->setDailyMenuEnabled($this->location(), true);

        // `veykemtu:setup` asgari sepeti 250,00 TL yazıyor. Bu paket sipariş
        // penceresini sınıyor, asgari tutar kuralını değil; sıfırlanmazsa
        // testler ilgisiz bir sebeple kırmızı olurdu.
        $gate->setMinOrderTotal($this->location(), 0);
    }

    protected function tearDown(): void
    {
        // Donmuş saat sızarsa sonraki test paketleri sebepsiz kırılır.
        Carbon::setTestNow();

        parent::tearDown();
    }

    // ── Kesim saati ─────────────────────────────────────────────────────

    /**
     * Her servis günü KENDİ kesim saatinde kapanır; gelecek gün etkilenmez.
     *
     * Eski kodda kesim "yalnız bugünse bak" özel durumuyla yazılıydı ve aynı
     * özel durum iki dosyada kopyalıydı. Kural güne bağlanınca özel durum
     * kayboldu: gelecek bir günün kesimi tanımı gereği gelecektedir.
     */
    public function test_bugun_kendi_kesim_saatinde_kapanir_yarin_acik_kalir(): void
    {
        $this->freeze(self::TUESDAY.' 07:59');
        app(LocationGate::class)->setOrderCutoff($this->location(), '08:00');

        $this->publishDay(self::TUESDAY);
        $this->publishDay(self::WEDNESDAY);

        $this->assertTrue(
            $this->verdict(self::TUESDAY)['orderable'],
            'Kesimden bir dakika önce bugüne sipariş verilebilmeli.',
        );

        $this->freeze(self::TUESDAY.' 08:01');

        $today = $this->verdict(self::TUESDAY);
        $this->assertFalse($today['orderable']);
        $this->assertSame(DailyMenuService::REASON_CUTOFF, $today['reason']);

        $this->assertTrue(
            $this->verdict(self::WEDNESDAY)['orderable'],
            'Yarının kesimi yarın; bugünün saati onu kapatmamalı.',
        );

        // Kapı gerçekten sipariş ucunda da duruyor.
        $this->orderRequest(self::TUESDAY)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'LOCATION_CLOSED');

        $this->orderRequest(self::WEDNESDAY)->assertCreated();
    }

    /**
     * Güne özel kesim saati, vitrinin genel saatini YENER.
     *
     * Birleştirme kuralı tek cümle: `gün.cutoff_time ?? ayar.order_cutoff`
     * (`docs/control/settings.md`). Genel saat girilmiş günleri ETKİLEMEZ;
     * tersi olsaydı yönetici genel saati değiştirdiğinde tek tek girilmiş
     * bütün günler sessizce kayardı.
     */
    public function test_gune_ozel_kesim_saati_genel_saati_yener(): void
    {
        $this->freeze(self::TUESDAY.' 07:00');
        app(LocationGate::class)->setOrderCutoff($this->location(), '08:00');

        $this->publishDay(self::TUESDAY, '06:00');
        $this->publishDay(self::WEDNESDAY);

        $window = app(OrderingWindow::class);
        $location = $this->location();

        $this->assertSame(
            '06:00',
            $window->cutoffFor($location, Carbon::parse(self::TUESDAY, BusinessTime::ZONE))?->format('H:i'),
        );
        $this->assertSame(
            '08:00',
            $window->cutoffFor($location, Carbon::parse(self::WEDNESDAY, BusinessTime::ZONE))?->format('H:i'),
        );

        // Sözleşme kesimi MUTLAK AN olarak yayınlıyor (`cutoff_at`): İstanbul
        // 06:00 = 03:00Z. Saat değil an göndermek, kuralı üç dilde yeniden
        // hesaplamanın doğurduğu sapmayı ortadan kaldırıyor.
        $this->assertSame(
            '2026-09-08T03:00:00Z',
            $window->cutoffFor($location, Carbon::parse(self::TUESDAY, BusinessTime::ZONE))
                ?->utc()->toIso8601ZuluString(),
        );

        // 07:00: güne özel 06:00 geçti, genel 08:00 geçmedi.
        $this->assertSame(DailyMenuService::REASON_CUTOFF, $this->verdict(self::TUESDAY)['reason']);
        $this->assertTrue($this->verdict(self::WEDNESDAY)['orderable']);
    }

    /**
     * TUZAK (a): `bld_daily_menu_enabled` kapalıyken de kesim uygulanır.
     *
     * Şalter kapalıyken sipariş yolu `DailyMenuService`'e hiç uğramıyor.
     * Kesim yalnız orada dursaydı, menü rejimine geçmemiş bir kurulumda
     * gece 03:00'te bugüne sipariş girer ve mutfak sabah pişiremeyeceği bir
     * siparişle uyanırdı.
     */
    public function test_gunun_menusu_kapaliyken_de_kesim_uygulanir(): void
    {
        $gate = app(LocationGate::class);
        $gate->setDailyMenuEnabled($this->location(), false);
        $gate->setOrderCutoff($this->location(), '08:00');

        $this->freeze(self::TUESDAY.' 09:00');

        $this->catalogOrderRequest()
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'LOCATION_CLOSED');

        $this->assertSame(0, DB::table('orders')->count());

        // Karşı kanıt: kapı her zaman kapalı değil, yalnız kesimden sonra.
        $this->freeze(self::TUESDAY.' 07:00');

        $this->catalogOrderRequest()->assertCreated();
    }

    // ── Hafta sonu ──────────────────────────────────────────────────────

    /**
     * TUZAK (b): cumartesi günü pazartesiye sipariş verilebilir.
     *
     * Çalışma takvimi bilerek hafta sonuna kapatılıyor. Eski kod bu durumda
     * `assertAcceptsOrder()` içinden "Çalışma saatlerimiz dışındasınız" diye
     * patlıyordu ve hafta sonu satış kanalı tamamen kapanıyordu. Çalışma
     * takvimi artık yalnız `Location.is_open` görüntüleme alanını besliyor.
     */
    public function test_cumartesi_pazartesiye_siparis_verilebilir(): void
    {
        $this->closeWeekendSchedule();
        $this->freeze(self::SATURDAY.' 10:00');

        $this->assertFalse(
            app(LocationGate::class)->isOpen($this->location()),
            'Ön koşul: çalışma takvimi cumartesi kapalı olmalı.',
        );

        $this->publishDay(self::MONDAY);

        $this->assertTrue(
            $this->verdict(self::MONDAY)['orderable'],
            'Hafta sonu menü yok ama satış kanalı açık (iş kuralı 3).',
        );

        $this->orderRequest(self::MONDAY)->assertCreated();
    }

    /**
     * Takvim her hücrenin kendi servis gününü söyler.
     *
     * Adı "weekend" ama anlamı "o gün servis yok". Kontrol Merkezi'nin ay
     * ızgarası bu alanla hücreyi griletiyor; istemcinin haftanın gününü
     * kendi hesaplaması gerekmiyor.
     *
     * HAFTA SONUNA MENÜ YAYINLAMAK UYARIR, ENGELLEMEZ: yayınlanmış bir
     * cumartesi normalde satılır.
     */
    public function test_takvim_hafta_sonu_hucresini_isaretler(): void
    {
        $this->freeze(self::SATURDAY.' 10:00');

        $this->publishDay(self::SATURDAY);
        $this->publishDay(self::MONDAY);

        $days = collect(app(DailyMenuService::class)->calendar(
            $this->location(),
            Carbon::parse(self::SATURDAY, BusinessTime::ZONE),
            Carbon::parse(self::MONDAY, BusinessTime::ZONE),
        ));

        $saturday = $days->firstWhere('date', self::SATURDAY);
        $monday = $days->firstWhere('date', self::MONDAY);

        $this->assertTrue($saturday['weekend']);
        $this->assertFalse($monday['weekend']);

        $this->assertTrue($saturday['is_orderable'], 'Uyarır, engellemez.');
        $this->assertTrue($monday['is_orderable']);
    }

    // ── İleri görüş penceresi ───────────────────────────────────────────

    /**
     * Varsayılan pencere 7 gün: gün+7 satılır, gün+8 `too_far`.
     *
     * Sabit 30'dan 7'ye indi (iş kuralı 2). Yönetici ayara hiç dokunmadığı
     * kurulumda kararın sessizce delinmemesi için varsayılanın kendisi
     * değişti; `docs/control/settings.md` tavanı da 7.
     */
    public function test_ileri_gorus_penceresi_varsayilan_yedi_gun(): void
    {
        $this->assertSame(7, LocationGate::DEFAULT_LOOKAHEAD_DAYS);

        $this->freeze(self::TUESDAY.' 09:00');

        $window = app(OrderingWindow::class);
        $this->assertSame(
            '2026-09-15',
            $window->lastOrderableDate($this->location())->toDateString(),
        );

        $this->publishDay('2026-09-15');
        $this->publishDay('2026-09-16');

        $this->assertTrue($this->verdict('2026-09-15')['orderable']);

        $tooFar = $this->verdict('2026-09-16');
        $this->assertFalse($tooFar['orderable']);
        $this->assertSame(DailyMenuService::REASON_TOO_FAR, $tooFar['reason']);

        // Sipariş ucu aynı sınırı yeniden uyguluyor.
        $this->orderRequest('2026-09-16')
            ->assertStatus(422)
            ->assertJsonPath('error.details.reason', DailyMenuService::REASON_TOO_FAR);
    }

    // ── Takvimin maliyeti ───────────────────────────────────────────────

    /**
     * Kesim gün başına soruluyor ama SORGU SAYISI gün sayısıyla büyümüyor.
     *
     * Güne özel saat menü satırının kendi kolonunda ve o satırlar zaten tek
     * sorguyla çekiliyor; vitrinin genel saati de vitrin başına bir kez
     * okunuyor. Naif bir uygulama (gün başına `cutoffFor()`) doksan günlük
     * bir aralıkta doksan sorgu açardı — takvim ucu tam da bundan kaçınmak
     * için iki toplu sorguya indirilmişti.
     */
    public function test_takvim_sorgu_sayisi_gun_sayisiyla_buyumez(): void
    {
        $this->freeze(self::TUESDAY.' 09:00');
        app(LocationGate::class)->setOrderCutoff($this->location(), '08:00');

        $this->publishDay(self::TUESDAY, '07:30');
        $this->publishDay(self::WEDNESDAY);
        $this->publishDay('2026-09-10');

        $location = $this->location();

        $short = $this->countQueries(static fn(): array => app(DailyMenuService::class)->calendar(
            $location,
            Carbon::parse(self::TUESDAY, BusinessTime::ZONE),
            Carbon::parse('2026-09-10', BusinessTime::ZONE),
        ));

        $long = $this->countQueries(static fn(): array => app(DailyMenuService::class)->calendar(
            $location,
            Carbon::parse(self::TUESDAY, BusinessTime::ZONE),
            Carbon::parse('2026-11-01', BusinessTime::ZONE),
        ));

        $this->assertSame(
            $short,
            $long,
            '3 günlük ve 55 günlük aralık aynı sayıda sorgu etmeli.',
        );
    }

    // ── Yardımcılar ─────────────────────────────────────────────────────

    /** İşletme saatiyle "şimdi"yi dondurur. */
    private function freeze(string $moment): void
    {
        Carbon::setTestNow(Carbon::parse($moment, BusinessTime::ZONE));
    }

    private function location(): Location
    {
        return Location::query()->where('location_id', $this->locationId())->firstOrFail();
    }

    /** @return array{menu: DailyMenu|null, closed: bool, closed_note: string|null, orderable: bool, reason: string|null} */
    private function verdict(string $date): array
    {
        return app(DailyMenuService::class)->verdict(
            $this->location(),
            Carbon::parse($date, BusinessTime::ZONE),
        );
    }

    private function packageMenuId(): int
    {
        return (int) DailyMenu::packageMenuIdFor($this->locationId());
    }

    /**
     * Çalışma takvimini hafta sonuna kapatır.
     *
     * TastyIgniter haftayı 0 = Pazartesi sayar (`WorkingHour::$weekDays`);
     * 5 cumartesi, 6 pazar. Kapalı satır `status = 0` ile ifade edilir ve
     * çekirdek onu çizelgeye hiç almaz.
     */
    private function closeWeekendSchedule(): void
    {
        $locationId = $this->locationId();

        DB::table('working_hours')->where('location_id', $locationId)->delete();

        foreach (range(0, 6) as $weekday) {
            DB::table('working_hours')->insert([
                'location_id' => $locationId,
                'type' => 'opening',
                'weekday' => $weekday,
                'opening_time' => '09:00:00',
                'closing_time' => '18:00:00',
                'status' => $weekday <= 4 ? 1 : 0,
            ]);
        }
    }

    /** O güne tek kalemli bir menü kurar ve yayınlar. */
    private function publishDay(string $date, ?string $cutoffTime = null): DailyMenu
    {
        $menu = DailyMenu::create([
            'location_id' => $this->locationId(),
            'menu_date' => $date,
            'title' => 'Ev Yemeği Menüsü',
            'package_price_kurus' => 18000,
            'cutoff_time' => $cutoffTime,
            'status' => DailyMenu::STATUS_PUBLISHED,
            'published_at' => BusinessTime::forStorage(BusinessTime::now()),
        ]);

        $product = Menu::query()->where('menu_name', 'Tavuk Sote')->firstOrFail();

        DailyMenuItem::create([
            'daily_menu_id' => $menu->id,
            'menu_id' => $product->menu_id,
            'quantity' => 1,
            'sort_order' => 0,
        ]);

        return $menu->refresh();
    }

    /** Günün menüsü paketiyle sipariş isteği. */
    private function orderRequest(string $serviceDate): TestResponse
    {
        return $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->packageMenuId(), 'quantity' => 1]],
            'delivery_type' => 'pickup',
            'payment_method' => 'cash',
            'service_date' => $serviceDate,
        ], self::HEADERS);
    }

    /** Katalog ürünüyle sipariş isteği — günün menüsü şalteri kapalıyken. */
    private function catalogOrderRequest(): TestResponse
    {
        return $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 1]],
            'delivery_type' => 'pickup',
            'payment_method' => 'cash',
        ], self::HEADERS);
    }

    private function countQueries(callable $work): int
    {
        DB::flushQueryLog();
        DB::enableQueryLog();

        $work();

        $count = count(DB::getQueryLog());
        DB::disableQueryLog();

        return $count;
    }
}
