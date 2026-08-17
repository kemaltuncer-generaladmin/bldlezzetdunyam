<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Menu;
use Igniter\Cart\Models\Order;
use Igniter\Local\Models\Location;
use Illuminate\Contracts\Console\Kernel as ConsoleKernel;
use Illuminate\Routing\Middleware\ThrottleRequests;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Console\StockReconcileCommand;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Models\ClosedDay;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Models\DailyMenuItem;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Services\DailyStock;
use Veykemtu\BridgeApi\Services\LocationGate;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Abonelik stok rezervasyonu ve uzlaştırma — iş kuralı 6 (A2).
 *
 * BU PAKETİN KİLİTLEDİĞİ CÜMLE: "abonelikler stoku ÖNCE rezerve eder."
 * Rezervasyon İLERİYE DÖNÜK olmak zorunda, çünkü D+5'in serbest satışı
 * D+5'in abonelik siparişi doğmadan çok önce açılıyor. Rezervasyon sipariş
 * üretimine bağlansaydı, kapasite beş gün boyunca boşmuş gibi görünür ve
 * aboneye ayrılmış porsiyonlar serbest satışta tükenirdi — arıza da ancak
 * üretim gecesi, satış kapandıktan sonra ortaya çıkardı.
 *
 * DÖRT AŞAMA, TEK SAYI: rezerve → satış → iade. Aynı porsiyon
 * `reserved`'dan çıkıp `sold`'a geçiyor, iptalde `sold`'dan geri veriliyor
 * ve hiçbir aşamada iki kez sayılmıyor. Testlerin çoğu tam olarak bunu,
 * `capacity - reserved - sold` üçlüsünün toplamını izleyerek sınıyor.
 *
 * SERVİS GÜNÜ HEP İLERİ BİR HAFTA İÇİ (`DailyStockTest` ile aynı gerekçe):
 * bugüne sipariş vermek testi kesim saatine bağlar ve öğleden sonra
 * koşturulduğunda arıza stokla hiç ilgili olmaz.
 */
class SubscriptionStockTest extends KitchenTestCase
{
    private const string TABLE = 'veykemtu_daily_menu_stock';

    /** Anlaşmalı porsiyon fiyatı (kuruş) — 150,00 TL. */
    private const int AGREED_PRICE = 15000;

    protected function setUp(): void
    {
        parent::setUp();

        $gate = app(LocationGate::class);
        $gate->setDailyMenuEnabled($this->location(), true);
        // `veykemtu:setup` asgari sepeti 250,00 TL yazıyor; bu paket stok
        // aritmetiğini sınıyor, asgari tutar kuralını değil.
        $gate->setMinOrderTotal($this->location(), 0);

        /*
         * KOMUT ELLE KAYDEDİLİYOR — kulvar sınırı.
         *
         * `Extension::registerPendingConsoleCommands()` `veykemtu.stokTazele`
         * anahtarını BAŞKA bir sınıf adına (`DailyStockRefreshCommand`)
         * bağlamış durumda ve o dosya bu kulvarın dışında. Kayıt düzeltilene
         * kadar komut Artisan'da görünmüyor; test onu kendi kaydediyor ki
         * DAVRANIŞ bugünden kilitlensin. Kayıt düzeltildiğinde bu satır
         * zararsız hâle gelir (aynı ad ikinci kez kaydedilir, üzerine yazar).
         */
        $this->app[ConsoleKernel::class]->registerCommand(
            $this->app->make(StockReconcileCommand::class),
        );
    }

    // ── Rezervasyon serbest satışı sınırlar ─────────────────────────────

    /**
     * KAPASİTE 50, ABONELİK 30 → SERBEST SATIŞ 20 ALIR, 21. DÜŞER.
     *
     * İş kuralının tamamı bu tek testte: abone daha sipariş vermeden
     * porsiyonunu almış oluyor ve serbest satış yalnızca ARTANI görüyor.
     */
    public function test_abonelik_rezervasyonu_serbest_satisi_kalanla_sinirlar(): void
    {
        $date = $this->serviceDay();
        $this->publishDay($date);
        $this->subscription(portions: 30);

        $this->artisan('veykemtu:stok-tazele')->assertSuccessful();

        $this->setCapacity(DailyStock::DAY_TOTAL, $date, 50);
        $this->artisan('veykemtu:stok-tazele')->assertSuccessful();

        $this->assertSame(30, $this->reservedOf(DailyStock::DAY_TOTAL, $date));

        $this->asCustomer();

        $this->order($this->menuId('Tavuk Sote'), 20, $date)->assertCreated();

        $this->order($this->menuId('Tavuk Sote'), 1, $date)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'ITEM_UNAVAILABLE');

        $this->assertSame(20, $this->soldOf(DailyStock::DAY_TOTAL, $date));
        $this->assertSame(30, $this->reservedOf(DailyStock::DAY_TOTAL, $date));
    }

    /**
     * ABONE ATLAYINCA 21. ALINABİLİR.
     *
     * Atlanan porsiyon serbest satışa döner (iş kuralı). Dönmeseydi
     * kapasite abonelik adına kilitli kalır, mutfak boş yere pişirmeye
     * hazırlanır ve satılabilecek porsiyon satılamazdı.
     */
    public function test_abone_gunu_atlayinca_porsiyon_serbest_satisa_doner(): void
    {
        $date = $this->serviceDay();
        $this->publishDay($date);
        $subscription = $this->subscription(portions: 30);
        $this->setCapacity(DailyStock::DAY_TOTAL, $date, 50);
        $this->artisan('veykemtu:stok-tazele')->assertSuccessful();

        $tavuk = $this->menuId('Tavuk Sote');
        $this->asCustomer();
        $this->order($tavuk, 20, $date)->assertCreated();
        $this->order($tavuk, 1, $date)->assertStatus(422);

        $this->skipDay($subscription, $date)->assertOk();

        // Rezervasyon düştü: gün artık o abonelik için üretim yapmıyor.
        $this->assertSame(0, $this->reservedOf(DailyStock::DAY_TOTAL, $date));

        $this->order($tavuk, 1, $date)->assertCreated();
        $this->assertSame(21, $this->soldOf(DailyStock::DAY_TOTAL, $date));
    }

    /** Atlama geri alınınca porsiyon yeniden ayrılır. */
    public function test_atlama_geri_alininca_rezervasyon_geri_gelir(): void
    {
        $date = $this->serviceDay();
        $this->publishDay($date);
        $subscription = $this->subscription(portions: 30);
        $this->setCapacity(DailyStock::DAY_TOTAL, $date, 50);
        $this->artisan('veykemtu:stok-tazele')->assertSuccessful();

        $this->asCustomer();
        $this->skipDay($subscription, $date)->assertOk();
        $this->assertSame(0, $this->reservedOf(DailyStock::DAY_TOTAL, $date));

        $this->skipDay($subscription, $date, skip: false)->assertOk();
        $this->assertSame(30, $this->reservedOf(DailyStock::DAY_TOTAL, $date));
    }

    /** Tek-günlük adet istisnası rezervasyona birebir yansır. */
    public function test_adet_istisnasi_rezervasyonu_gunu_gunune_degistirir(): void
    {
        $date = $this->serviceDay();
        $this->publishDay($date);
        $subscription = $this->subscription(portions: 30);
        $this->setCapacity(DailyStock::DAY_TOTAL, $date, 50);
        $this->artisan('veykemtu:stok-tazele')->assertSuccessful();

        $this->asCustomer();
        $this->asCustomer()->postJson(
            '/api/subscriptions/'.$subscription->id.'/exceptions',
            ['service_date' => $date->toDateString(), 'quantity_override' => 12],
            self::HEADERS,
        )->assertOk();

        $this->assertSame(12, $this->reservedOf(DailyStock::DAY_TOTAL, $date));
    }

    // ── Uzlaştırma ──────────────────────────────────────────────────────

    /**
     * UZLAŞTIRMA ELLE BOZULMUŞ `reserved` DEĞERİNİ DÜZELTİR.
     *
     * Bu işin tek varlık sebebi: artımlı kancalar (aktifleştirme,
     * duraklatma, gün atlama, menü yayınlama) kaçınılmaz olarak eksik
     * kalır. Sıfırdan hesap her gece koştuğu için her artımlı hata en geç
     * 24 saat içinde ve ÜRETİMDEN ÖNCE kendini onarır.
     */
    public function test_uzlastirma_elle_bozulmus_rezervasyonu_duzeltir(): void
    {
        $date = $this->serviceDay();
        $this->publishDay($date);
        $this->subscription(portions: 30);
        $this->setCapacity(DailyStock::DAY_TOTAL, $date, 50);

        // Sapma: biri elle yazdı, bir kanca kaçtı, bir istek yarıda kesildi.
        $this->forceReserved(DailyStock::DAY_TOTAL, $date, 99);

        $this->artisan('veykemtu:stok-tazele')->assertSuccessful();

        $this->assertSame(30, $this->reservedOf(DailyStock::DAY_TOTAL, $date));
    }

    /** Fazlası kadar eksiği de düzeltilir — hesap sıfırdan yapılıyor. */
    public function test_uzlastirma_eksik_kalmis_rezervasyonu_tamamlar(): void
    {
        $date = $this->serviceDay();
        $this->publishDay($date);
        $this->subscription(portions: 30);
        $this->setCapacity(DailyStock::DAY_TOTAL, $date, 50);
        $this->forceReserved(DailyStock::DAY_TOTAL, $date, 4);

        $this->artisan('veykemtu:stok-tazele')->assertSuccessful();

        $this->assertSame(30, $this->reservedOf(DailyStock::DAY_TOTAL, $date));
    }

    /** Bileşen tavanı da rezerve edilir — gün bol olsa bile ürün bitebilir. */
    public function test_bilesen_tavani_porsiyon_basina_rezerve_edilir(): void
    {
        $date = $this->serviceDay();
        $this->publishDay($date, [['Mercimek Çorbası', 2], ['Tavuk Sote', 1]]);
        $this->subscription(portions: 10);

        $corba = $this->menuId('Mercimek Çorbası');
        $this->setCapacity(DailyStock::DAY_TOTAL, $date, 100);
        $this->setCapacity($corba, $date, 40);

        $this->artisan('veykemtu:stok-tazele')->assertSuccessful();

        // Porsiyon başına 2 çorba: 10 porsiyon → 20 çorba.
        $this->assertSame(20, $this->reservedOf($corba, $date));
        $this->assertSame(10, $this->reservedOf(DailyStock::DAY_TOTAL, $date));
    }

    /** Kuru koşum sapmayı gösterir ama HİÇBİR ŞEY yazmaz. */
    public function test_kuru_kosum_yazmaz(): void
    {
        $date = $this->serviceDay();
        $this->publishDay($date);
        $this->subscription(portions: 30);
        $this->setCapacity(DailyStock::DAY_TOTAL, $date, 50);
        $this->forceReserved(DailyStock::DAY_TOTAL, $date, 99);

        $this->artisan('veykemtu:stok-tazele', ['--dry-run' => true])
            ->assertSuccessful();

        $this->assertSame(99, $this->reservedOf(DailyStock::DAY_TOTAL, $date));
    }

    /**
     * DURAKLATILMIŞ ABONELİK PORSİYON AYIRMAZ.
     *
     * Duraklatma kancası başka bir kulvarda yazılıyor; uzlaştırma o kanca
     * hiç yazılmasa bile aynı sonucu veriyor — kancanın işi yalnızca
     * sonucu ERKENE almak.
     */
    public function test_duraklatilmis_abonelik_rezervasyonu_birakir(): void
    {
        $date = $this->serviceDay();
        $this->publishDay($date);
        $subscription = $this->subscription(portions: 30);
        $this->setCapacity(DailyStock::DAY_TOTAL, $date, 50);
        $this->artisan('veykemtu:stok-tazele')->assertSuccessful();
        $this->assertSame(30, $this->reservedOf(DailyStock::DAY_TOTAL, $date));

        $subscription->status = Subscription::STATUS_PAUSED;
        $subscription->save();

        $this->artisan('veykemtu:stok-tazele')->assertSuccessful();

        $this->assertSame(0, $this->reservedOf(DailyStock::DAY_TOTAL, $date));
    }

    /** Kapalı gün (tatil) üretim yapmaz, dolayısıyla porsiyon da ayırmaz. */
    public function test_kapali_gun_rezerve_edilmez(): void
    {
        $date = $this->serviceDay();
        $this->publishDay($date);
        $this->subscription(portions: 30);
        $this->setCapacity(DailyStock::DAY_TOTAL, $date, 50);

        ClosedDay::create([
            'closed_on' => $date->toDateString(),
            'description' => 'Resmî tatil',
        ]);

        $this->artisan('veykemtu:stok-tazele')->assertSuccessful();

        $this->assertSame(0, $this->reservedOf(DailyStock::DAY_TOTAL, $date));
    }

    /**
     * MENÜSÜ YAYINLANMAMIŞ GÜNE REZERVASYON YAZILMAZ — bilinçli.
     *
     * Ne pişeceği bilinmiyor, sipariş de üretilemiyor; uydurma bir gün
     * toplamı yazmak `DailyStock::demandOf()` ile ayrışmak olurdu. Aşırı
     * satış riski yok: yayınlanmamış güne serbest satış zaten kapalı.
     */
    public function test_menusu_yayinlanmamis_gune_rezervasyon_yazilmaz(): void
    {
        $date = $this->serviceDay();
        $this->subscription(portions: 30);
        $this->setCapacity(DailyStock::DAY_TOTAL, $date, 50);

        $this->artisan('veykemtu:stok-tazele')->assertSuccessful();
        $this->assertSame(0, $this->reservedOf(DailyStock::DAY_TOTAL, $date));

        // Menü yayınlanınca aynı hesap porsiyonu ayırır.
        $this->publishDay($date);
        $this->artisan('veykemtu:stok-tazele')->assertSuccessful();

        $this->assertSame(30, $this->reservedOf(DailyStock::DAY_TOTAL, $date));
    }

    // ── Rezervasyon → satış ─────────────────────────────────────────────

    /**
     * ÜRETİM REZERVASYONU SATIŞA ÇEVİRİR — toplam DEĞİŞMEZ.
     *
     * `reserved` 30 → 0 ve `sold` 0 → 30. İkisi tek `UPDATE` içinde
     * yürüdüğü için arada porsiyonun "herkese açık" göründüğü bir an yok;
     * serbest satışın gördüğü kalan her iki hâlde de 20.
     */
    public function test_uretim_rezervasyonu_satisa_cevirir(): void
    {
        $date = $this->serviceDay();
        $this->publishDay($date);
        $this->subscription(portions: 30);
        $this->setCapacity(DailyStock::DAY_TOTAL, $date, 50);
        $this->artisan('veykemtu:stok-tazele')->assertSuccessful();

        $this->artisan('veykemtu:abonelik-uret', ['--date' => $date->toDateString()])
            ->assertSuccessful();

        $this->assertSame(0, $this->reservedOf(DailyStock::DAY_TOTAL, $date));
        $this->assertSame(30, $this->soldOf(DailyStock::DAY_TOTAL, $date));

        // Serbest satışın payı değişmedi: hâlâ 20.
        $this->asCustomer();
        $this->order($this->menuId('Tavuk Sote'), 20, $date)->assertCreated();
        $this->order($this->menuId('Tavuk Sote'), 1, $date)->assertStatus(422);
    }

    /** İkinci koşum idempotent: aynı gün ikinci kez satışa çevrilmez. */
    public function test_ikinci_kosum_stogu_ikinci_kez_dusmez(): void
    {
        $date = $this->serviceDay();
        $this->publishDay($date);
        $this->subscription(portions: 30);
        $this->setCapacity(DailyStock::DAY_TOTAL, $date, 50);
        $this->artisan('veykemtu:stok-tazele')->assertSuccessful();

        $this->artisan('veykemtu:abonelik-uret', ['--date' => $date->toDateString()])
            ->assertSuccessful();
        $this->artisan('veykemtu:abonelik-uret', ['--date' => $date->toDateString()])
            ->assertSuccessful();

        $this->assertSame(30, $this->soldOf(DailyStock::DAY_TOTAL, $date));
        $this->assertSame(0, $this->reservedOf(DailyStock::DAY_TOTAL, $date));
    }

    /**
     * ÜRETİLMİŞ GÜN YENİDEN REZERVE EDİLMEZ.
     *
     * Uzlaştırma her gece bugünü de kapsıyor. Koşum satırı olan bir günü
     * yeniden rezerve etseydi aynı porsiyon hem `reserved` hem `sold`
     * olarak sayılır, kapasite iki kez düşerdi.
     */
    public function test_uretimden_sonra_uzlastirma_rezervasyonu_geri_getirmez(): void
    {
        $date = $this->serviceDay();
        $this->publishDay($date);
        $this->subscription(portions: 30);
        $this->setCapacity(DailyStock::DAY_TOTAL, $date, 50);
        $this->artisan('veykemtu:stok-tazele')->assertSuccessful();
        $this->artisan('veykemtu:abonelik-uret', ['--date' => $date->toDateString()])
            ->assertSuccessful();

        $this->artisan('veykemtu:stok-tazele')->assertSuccessful();

        $this->assertSame(0, $this->reservedOf(DailyStock::DAY_TOTAL, $date));
        $this->assertSame(30, $this->soldOf(DailyStock::DAY_TOTAL, $date));
    }

    /**
     * ÜRETİMDEN SONRA ATLAMA: rezervasyon değil, SİPARİŞ iptal edilir.
     *
     * Porsiyon serbest satışa iptalin normal yolundan dönüyor
     * (`OrderStatusTransition` → `releaseOrder`), çünkü ortada mutfağa
     * düşmüş gerçek bir sipariş var ve onu görünmez biçimde yok saymak
     * mutfakla stoku ayrıştırırdı.
     */
    public function test_uretimden_sonra_atlama_siparisi_iptal_eder(): void
    {
        $date = $this->serviceDay();
        $this->publishDay($date);
        $subscription = $this->subscription(portions: 30);
        $this->setCapacity(DailyStock::DAY_TOTAL, $date, 50);
        $this->artisan('veykemtu:stok-tazele')->assertSuccessful();
        $this->artisan('veykemtu:abonelik-uret', ['--date' => $date->toDateString()])
            ->assertSuccessful();

        $order = Order::query()->where('bld_subscription_id', $subscription->id)->firstOrFail();

        $this->asCustomer();
        $this->skipDay($subscription, $date)->assertOk();

        $this->assertSame(
            OrderStatusTransition::CANCELLED,
            app(OrderStatusTransition::class)->codeOf($order->refresh()),
        );
        $this->assertSame(0, $this->soldOf(DailyStock::DAY_TOTAL, $date));
        $this->assertSame(0, $this->reservedOf(DailyStock::DAY_TOTAL, $date));

        // Elli porsiyonun tamamı serbest satışa açıldı.
        $this->order($this->menuId('Tavuk Sote'), 50, $date)->assertCreated();
    }

    /** Geçmiş güne istisna girilebilir ama stok kımıldamaz. */
    public function test_gecmis_gune_istisna_stogu_bozmaz(): void
    {
        $date = $this->serviceDay();
        $past = BusinessTime::now()->subDays(3)->startOfDay();
        $this->publishDay($date);
        $subscription = $this->subscription(portions: 30);
        $this->setCapacity(DailyStock::DAY_TOTAL, $date, 50);
        $this->setCapacity(DailyStock::DAY_TOTAL, $past, 50, reserved: 30);
        $this->artisan('veykemtu:stok-tazele')->assertSuccessful();

        $this->asCustomer();
        $this->skipDay($subscription, $past)->assertOk();

        // Geçmiş gün pencerede değil ve elle de düzeltilmiyor.
        $this->assertSame(30, $this->reservedOf(DailyStock::DAY_TOTAL, $past));
        $this->assertSame(30, $this->reservedOf(DailyStock::DAY_TOTAL, $date));
    }

    // ── Yardımcılar ─────────────────────────────────────────────────────

    /** İleri, hafta içi bir servis günü (kesim saatinden bağımsız). */
    private function serviceDay(): Carbon
    {
        $date = BusinessTime::now()->addDay()->startOfDay();

        while (in_array($date->dayOfWeekIso, [6, 7], true)) {
            $date->addDay();
        }

        return $date;
    }

    /**
     * O güne menü kurar ve yayınlar.
     *
     * @param  list<array{0:string, 1:int}>|null  $items  [ürün adı, porsiyon başına adet]
     */
    private function publishDay(Carbon $date, ?array $items = null): DailyMenu
    {
        $menu = DailyMenu::create([
            'location_id' => $this->locationId(),
            'menu_date' => $date->toDateString(),
            'title' => 'Ev Yemeği Menüsü',
            'package_price_kurus' => null,
            'status' => DailyMenu::STATUS_PUBLISHED,
            'published_at' => BusinessTime::forStorage(BusinessTime::now()),
        ]);

        foreach ($items ?? [['Tavuk Sote', 1]] as $index => [$name, $quantity]) {
            $product = Menu::query()->where('menu_name', $name)->firstOrFail();

            DailyMenuItem::create([
                'daily_menu_id' => $menu->id,
                'menu_id' => $product->menu_id,
                'quantity' => $quantity,
                'sort_order' => $index,
                'is_required' => true,
                'sellable_alone' => true,
            ]);
        }

        return $menu->refresh();
    }

    /** Aktif, günün menüsü modunda, tek noktalı abonelik. */
    private function subscription(int $portions): Subscription
    {
        $subscription = new Subscription;
        $subscription->customer_id = $this->customer()->customer_id;
        $subscription->location_id = $this->locationId();
        $subscription->status = Subscription::STATUS_ACTIVE;
        $subscription->start_date = BusinessTime::now()->subMonth()->toDateString();
        $subscription->end_date = null;
        $subscription->delivery_type = 'pickup';
        $subscription->service_days = [1, 2, 3, 4, 5, 6, 7];
        $subscription->menu_mode = Subscription::MENU_DAILY;
        $subscription->default_quantity = $portions;
        $subscription->agreed_unit_price_kurus = self::AGREED_PRICE;
        $subscription->payment_mode = Subscription::PAYMENT_PREPAID;
        $subscription->save();

        return $subscription->refresh();
    }

    private function customer(): ApiCustomer
    {
        $customer = ApiCustomer::query()->where('email', 'test@ornek.com')->first();

        if ($customer === null) {
            $this->postJson('/api/auth/register', $this->registerPayload(), self::HEADERS);
            $customer = ApiCustomer::query()->where('email', 'test@ornek.com')->firstOrFail();
        }

        return $customer;
    }

    private function skipDay(Subscription $subscription, Carbon $date, bool $skip = true): TestResponse
    {
        return $this->asCustomer()->postJson(
            '/api/subscriptions/'.$subscription->id.'/exceptions',
            ['service_date' => $date->toDateString(), 'skip' => $skip],
            self::HEADERS,
        );
    }

    private function order(int $menuId, int $quantity, Carbon $date): TestResponse
    {
        /*
         * HIZ SINIRI KAPALI — ölçülen şey o değil (`DailyStockTest` ile
         * aynı gerekçe). `bld-order` kovası müşteri başına 20/saat ve bu
         * paket aynı müşteriyle arka arkaya sipariş deniyor.
         */
        $this->withoutMiddleware(ThrottleRequests::class);

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

    /** Sapma üretir: kimse böyle yazmamalı, uzlaştırma tam da bunu düzeltir. */
    private function forceReserved(int $menuId, Carbon $date, int $reserved): void
    {
        DB::table(self::TABLE)
            ->where('location_id', $this->locationId())
            ->where('service_date', $date->toDateString())
            ->where('menu_id', $menuId)
            ->update(['reserved' => $reserved]);
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

    private function reservedOf(int $menuId, Carbon $date): int
    {
        return (int) $this->rowOf($menuId, $date)->reserved;
    }

    private function soldOf(int $menuId, Carbon $date): int
    {
        return (int) $this->rowOf($menuId, $date)->sold;
    }

    private function location(): Location
    {
        return Location::query()->where('location_id', $this->locationId())->firstOrFail();
    }
}
