<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Menu;
use Igniter\Cart\Models\Order;
use Igniter\Local\Models\Location;
use Igniter\User\Facades\AdminAuth;
use Igniter\User\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Http\Middleware\RequireAdminPanel;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Models\DailyMenuItem;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Services\LocationGate;
use Veykemtu\BridgeApi\Services\SubscriptionKitchenPlan;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * `menu_mode = daily_menu` aboneliği — üretim, eksik menü ve mutfak uyarısı.
 *
 * BU PAKETİN KİLİTLEDİĞİ ÜÇ ŞEY:
 *
 *  1. **Şekil.** Abonelik siparişi tek seferlik menü siparişiyle AYNI
 *     şekli taşımalı: fiyatlı bir `package` üst satırı + sıfır fiyatlı
 *     `component` satırları. Şekil ayrışırsa `bld_line_role != 'package'`
 *     süzgeci (üretim listesi, mutfak toplamları, KDS yükü) iki kaynakta
 *     iki farklı sonuç verir ve mutfak şeridinde "40 Günün Menüsü" diye
 *     pişirilemeyecek bir satır belirir.
 *  2. **Sessizlik yok.** Menü yayınlanmamışsa sipariş üretilmez AMA
 *     `veykemtu_subscription_runs` satırı da YAZILMAZ — yoksa gün
 *     "üretildi" sayılır, menü sonradan yayınlansa bile sipariş bir daha
 *     doğmaz ve eksiklik yemek saatinde görülür.
 *  3. **Fiyat sözleşmeden gelir.** `agreed_unit_price_kurus` bu modda da
 *     zorunlu; fiyatı günün menüsünden almak, mutfak pahalı bir gün
 *     girdiğinde faturayı sessizce büyütürdü.
 */
class SubscriptionDailyMenuTest extends KitchenTestCase
{
    /** Anlaşmalı porsiyon fiyatı (kuruş) — 150,00 TL. */
    private const int AGREED_PRICE = 15000;

    protected function setUp(): void
    {
        parent::setUp();

        // Bu paketin bir testi abonelik ekranını PANELDEN açıyor; `/admin/*`
        // üretimde kapalı (`RequireAdminPanel`, F4) ve yedek yüzeyin
        // çalıştığı doğrulanmaya devam etmeli — `AdminPanelClosedTest`.
        config([RequireAdminPanel::CONFIG_KEY => true]);

        // Abonelik vitrin kapılarına bakmıyor ama günün menüsü rejimi
        // gösterge paneli ve müşteri uçları için açık olmalı.
        app(LocationGate::class)->setDailyMenuEnabled($this->location(), true);
    }

    // ── Üretim ──────────────────────────────────────────────────────────

    public function test_gunun_menusu_aboneligi_yayinlanmis_gunden_uretir(): void
    {
        $date = BusinessTime::now()->addDay();
        $this->publishDay($date, [['Mercimek Çorbası', 1], ['Tavuk Sote', 2]]);
        $subscription = $this->dailySubscription(portions: 20);

        $this->artisan('veykemtu:abonelik-uret', ['--date' => $date->toDateString()])
            ->assertSuccessful();

        $order = Order::query()
            ->where('bld_subscription_id', $subscription->id)
            ->firstOrFail();

        $this->assertSame($date->toDateString(), (string) $order->bld_service_date);
        $this->assertSame($date->toDateString(), Carbon::parse($order->order_date)->toDateString());
        // Toplam = porsiyon × anlaşmalı porsiyon fiyatı; günün menüsünün
        // paket fiyatı bilerek KULLANILMIYOR.
        $this->assertSame(3000.0, (float) $order->order_total);

        $lines = $this->linesOf($order);
        $this->assertCount(3, $lines);

        // Parayı ÜST SATIR taşıyor.
        $this->assertSame('package', $lines[0]->bld_line_role);
        $this->assertSame(20, (int) $lines[0]->quantity);
        $this->assertSame(150.0, (float) $lines[0]->price);
        $this->assertStringContainsString('Ev Yemeği Menüsü', (string) $lines[0]->name);
        $this->assertNotNull($lines[0]->bld_daily_menu_id);

        // Bileşenler sıfır fiyatlı ve üst satıra bağlı; adet PORSİYON ×
        // günün menüsündeki kalem adedi.
        $this->assertSame('component', $lines[1]->bld_line_role);
        $this->assertSame(20, (int) $lines[1]->quantity);
        $this->assertSame(0.0, (float) $lines[1]->price);
        $this->assertSame((int) $lines[0]->order_menu_id, (int) $lines[1]->bld_parent_line_id);

        $this->assertSame('component', $lines[2]->bld_line_role);
        $this->assertSame(40, (int) $lines[2]->quantity);

        // Koşum satırı yazıldı: aynı gün ikinci kez üretilmesin.
        $this->assertSame(1, $this->runCount($subscription, $date));
    }

    /**
     * Mutfağın şeridinde "20 Günün Menüsü" diye pişirilemeyecek bir satır
     * belirmemeli; toplamlar bileşenlerin GERÇEK adlarından gelir.
     */
    public function test_mutfak_toplamlarinda_paket_ust_satiri_SAYILMAZ(): void
    {
        $date = BusinessTime::now()->addDay();
        $this->publishDay($date, [['Mercimek Çorbası', 1], ['Tavuk Sote', 1]]);
        $this->dailySubscription(portions: 20);

        $this->artisan('veykemtu:abonelik-uret', ['--date' => $date->toDateString()])
            ->assertSuccessful();

        $totals = app(SubscriptionKitchenPlan::class)->forDate($date)['totals'];
        $names = array_column($totals, 'name');

        $this->assertContains('Mercimek Çorbası', $names);
        $this->assertContains('Tavuk Sote', $names);
        $this->assertNotContains('Ev Yemeği Menüsü ('.$date->format('d.m.Y').')', $names);
        $this->assertCount(2, $totals);
    }

    // ── Menü yoksa ──────────────────────────────────────────────────────

    public function test_menu_yoksa_komut_FAILURE_doner_ve_kosum_satiri_YAZILMAZ(): void
    {
        $date = BusinessTime::now()->addDay();
        $subscription = $this->dailySubscription(portions: 20);

        $this->artisan('veykemtu:abonelik-uret', ['--date' => $date->toDateString()])
            ->assertFailed();

        $this->assertSame(0, Order::query()->where('bld_subscription_id', $subscription->id)->count());
        /*
         * SATIR YAZILMAMALI. Yazılsaydı gün "üretildi" sayılır, menü
         * sonradan yayınlansa bile sipariş bir daha doğmazdı.
         */
        $this->assertSame(0, $this->runCount($subscription, $date));
    }

    public function test_menu_yayinlandiktan_sonra_yeniden_kosum_TEK_siparis_uretir(): void
    {
        $date = BusinessTime::now()->addDay();
        $subscription = $this->dailySubscription(portions: 20);

        $this->artisan('veykemtu:abonelik-uret', ['--date' => $date->toDateString()])
            ->assertFailed();

        $this->publishDay($date, [['Mercimek Çorbası', 1]]);

        $this->artisan('veykemtu:abonelik-uret', ['--date' => $date->toDateString()])
            ->assertSuccessful();

        // Üçüncü koşum idempotent: UNIQUE kısıtı + varlık kontrolü.
        $this->artisan('veykemtu:abonelik-uret', ['--date' => $date->toDateString()])
            ->assertSuccessful();

        $this->assertSame(1, Order::query()->where('bld_subscription_id', $subscription->id)->count());
        $this->assertSame(1, $this->runCount($subscription, $date));
    }

    /**
     * `mutfakapp/lib/src/data/subscription_plan.dart` içinde
     * `isCritical => kind == 'not_generated'` SABİT KODLU. Yeni bir tür
     * mavi/bilgi olarak çizilirdi; "yarınki 400 porsiyonun menüsü yok"
     * bilgi değil, alarmdır.
     */
    public function test_mutfak_plani_menusuz_gunu_not_generated_ile_uyarir(): void
    {
        $date = BusinessTime::now()->addDay();
        $this->dailySubscription(portions: 400);

        $warnings = app(SubscriptionKitchenPlan::class)->forDate($date)['warnings'];
        $kinds = array_column($warnings, 'kind');

        $this->assertContains('not_generated', $kinds);

        $menuWarning = collect($warnings)->first(
            static fn(array $w): bool => str_contains($w['message'], 'YAYINLANMAMIŞ'),
        );

        $this->assertNotNull($menuWarning);
        $this->assertSame('not_generated', $menuWarning['kind']);
        $this->assertStringContainsString('400 porsiyon', $menuWarning['message']);
    }

    public function test_menu_yayinlandiginda_mutfak_uyarisi_KALKAR(): void
    {
        $date = BusinessTime::now()->addDay();
        $this->publishDay($date, [['Mercimek Çorbası', 1]]);
        $this->dailySubscription(portions: 20);

        $this->artisan('veykemtu:abonelik-uret', ['--date' => $date->toDateString()])
            ->assertSuccessful();

        $warnings = app(SubscriptionKitchenPlan::class)->forDate($date)['warnings'];

        $this->assertSame([], $warnings);
    }

    // ── Fiyat ───────────────────────────────────────────────────────────

    /**
     * Anlaşmalı fiyat `daily_menu`'de de ZORUNLU: sözleşme "o gün ne
     * pişerse pişsin porsiyonu şu kadar" der (`docs/11` §7.5).
     */
    public function test_anlasmali_fiyatsiz_gunun_menusu_aboneligi_REDDEDILIR(): void
    {
        $date = BusinessTime::now()->addDay();
        $this->publishDay($date, [['Mercimek Çorbası', 1]]);
        $subscription = $this->dailySubscription(portions: 20, price: null);

        $this->artisan('veykemtu:abonelik-uret', ['--date' => $date->toDateString()])
            ->assertFailed();

        $this->assertSame(0, Order::query()->where('bld_subscription_id', $subscription->id)->count());
        $this->assertSame(0, $this->runCount($subscription, $date));
    }

    // ── Sözleşme (müşteri ucu) ──────────────────────────────────────────

    public function test_musteri_gunun_menusu_modunda_talep_acabilir(): void
    {
        $this->corporateCustomer();

        $this->asCustomer()->postJson('/api/subscriptions', [
            'location_id' => $this->locationId(),
            'delivery_type' => 'pickup',
            'start_date' => BusinessTime::now()->addDay()->toDateString(),
            'service_days' => [1, 2, 3, 4, 5],
            'default_quantity' => 20,
            'menu_mode' => 'daily_menu',
        ], self::HEADERS)
            ->assertCreated()
            ->assertJsonPath('menu_mode', 'daily_menu')
            ->assertJsonPath('status', 'pending')
            ->assertJsonPath('lines', []);
    }

    /** Gönderilmeyen alan eski davranışı birebir korumalı. */
    public function test_menu_modu_gonderilmezse_fixed_list_kalir(): void
    {
        $this->corporateCustomer();

        $this->asCustomer()->postJson('/api/subscriptions', [
            'location_id' => $this->locationId(),
            'delivery_type' => 'pickup',
            'start_date' => BusinessTime::now()->addDay()->toDateString(),
            'service_days' => [1],
            'default_quantity' => 5,
        ], self::HEADERS)
            ->assertCreated()
            ->assertJsonPath('menu_mode', 'fixed_list');
    }

    /**
     * İki içerik kaynağı olmaz: satırlar hiçbir zaman okunmayacağı için
     * panelde gerçekle çelişen bir liste gösterirdi. Sessizce atmak
     * istemci hatasını sahaya taşırdı.
     */
    public function test_gunun_menusu_modunda_urun_satiri_REDDEDILIR(): void
    {
        $this->corporateCustomer();

        $this->asCustomer()->postJson('/api/subscriptions', [
            'location_id' => $this->locationId(),
            'delivery_type' => 'pickup',
            'start_date' => BusinessTime::now()->addDay()->toDateString(),
            'service_days' => [1],
            'default_quantity' => 5,
            'menu_mode' => 'daily_menu',
            'lines' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 1]],
        ], self::HEADERS)
            ->assertStatus(422);

        $this->assertSame(0, Subscription::query()->count());
    }

    // ── Admin formu ─────────────────────────────────────────────────────

    /**
     * ASIL KİLİT BURADAYDI.
     *
     * `OrderFactory` ve `SubscriptionController` düzeltilse bile mod
     * seçilemiyordu: `resources/models/subscription.php` içinde `menu_mode`
     * alanı hiç yoktu ve `formExtendModel`'deki `??=` yalnızca varsayılanı
     * yazıyordu. Alan formda yoksa her kayıt `fixed_list` doğar.
     *
     * Ürün satırı repeater'ı da `trigger` ile `fixed_list`'e bağlı; bağ
     * kopsa günün menüsü modunda okunmayacak ürünler sorulurdu.
     */
    public function test_olusturma_formunda_menu_modu_secilebilir(): void
    {
        $this->actingAsAdmin();

        $html = $this->get('/admin/veykemtu/bridgeapi/subscriptions/create')
            ->assertOk()
            ->getContent();

        $this->assertStringContainsString(
            lang('veykemtu.bridgeapi::subscription.label_menu_mode'),
            $html,
        );
        $this->assertStringContainsString(
            lang('veykemtu.bridgeapi::subscription.menu_mode_daily'),
            $html,
        );
        $this->assertStringContainsString("data-trigger-condition=\"value[fixed_list]\"", $html);
        $this->assertStringNotContainsString('veykemtu.bridgeapi::subscription', $html);
    }

    // ── Yardımcılar ─────────────────────────────────────────────────────

    /**
     * O gün için yayınlanmış menü.
     *
     * @param  list<array{0:string, 1:int}>  $items  [ürün adı, porsiyon başına adet]
     */
    private function publishDay(Carbon $date, array $items): DailyMenu
    {
        $menu = DailyMenu::create([
            'location_id' => $this->locationId(),
            'menu_date' => $date->toDateString(),
            'title' => 'Ev Yemeği Menüsü',
            // Paket fiyatı BİLEREK girilmiyor: abonelikte fiyat sözleşmeden
            // gelir ve o gün vitrinde paket satılmasa bile üretim koşmalı.
            'package_price_kurus' => null,
            'status' => DailyMenu::STATUS_PUBLISHED,
            'published_at' => BusinessTime::forStorage(BusinessTime::now()),
        ]);

        foreach ($items as $index => [$name, $quantity]) {
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

    private function dailySubscription(int $portions, ?int $price = self::AGREED_PRICE): Subscription
    {
        $subscription = new Subscription;
        $subscription->customer_id = $this->corporateCustomer()->customer_id;
        $subscription->location_id = $this->locationId();
        $subscription->status = Subscription::STATUS_ACTIVE;
        $subscription->start_date = BusinessTime::now()->subMonth()->toDateString();
        $subscription->end_date = null;
        $subscription->delivery_type = 'pickup';
        $subscription->service_days = [1, 2, 3, 4, 5, 6, 7];
        $subscription->menu_mode = Subscription::MENU_DAILY;
        $subscription->default_quantity = $portions;
        $subscription->agreed_unit_price_kurus = $price;
        $subscription->payment_mode = Subscription::PAYMENT_PREPAID;
        $subscription->save();

        return $subscription->refresh();
    }

    private function corporateCustomer(): ApiCustomer
    {
        $customer = ApiCustomer::query()->where('email', 'test@ornek.com')->first();

        if ($customer === null) {
            $this->postJson('/api/auth/register', $this->registerPayload(), self::HEADERS);
            $customer = ApiCustomer::query()->where('email', 'test@ornek.com')->firstOrFail();
        }

        // Abonelik yalnız KURUMSAL hesaplarda açılır (`docs/00` B2B kararı).
        $customer->bld_account_type = 'corporate';
        $customer->bld_org_name = 'Test Kurumu';
        $customer->save();

        return $customer;
    }

    /** @return list<object> */
    private function linesOf(Order $order): array
    {
        return DB::table('order_menus')
            ->where('order_id', $order->order_id)
            ->orderBy('order_menu_id')
            ->get()
            ->all();
    }

    private function runCount(Subscription $subscription, Carbon $date): int
    {
        return DB::table('veykemtu_subscription_runs')
            ->where('subscription_id', $subscription->id)
            ->where('service_date', $date->toDateString())
            ->count();
    }

    private function location(): Location
    {
        return Location::findOrFail($this->locationId());
    }

    private function actingAsAdmin(): void
    {
        $user = new User;
        $user->fill([
            'name' => 'Test Yönetici',
            'username' => 'testyonetici',
            'email' => 'yonetici@ornek.com',
            'status' => true,
            'super_user' => true,
        ]);
        $user->password = 'parola123';
        $user->is_activated = true;
        $user->activated_at = now();
        $user->save();

        AdminAuth::login($user);
    }
}
