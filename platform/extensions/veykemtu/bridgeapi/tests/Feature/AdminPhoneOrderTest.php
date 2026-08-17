<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Order;
use Igniter\User\Facades\AdminAuth;
use Igniter\User\Models\User;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Http\Middleware\RequireAdminPanel;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Models\SubscriptionException;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Telefonla alınan siparişin panelden girilmesi — B-13.
 *
 * Bu ekranın riski yüksek, çünkü tek tıkla ÜÇ geri alınamaz şey yapıyor:
 * müşteri kaydı açıyor, sipariş yaratıyor ve mutfağa fiş bastırıyor.
 * Testler o üçünü ayrı ayrı sabitliyor:
 *
 *  1. **Sipariş `onaylandi` doğar ve mutfak beslemesine düşer.** `yeni`
 *     kalsaydı mutfak siparişi hiç görmezdi ve bunun tek belirtisi aç kalan
 *     bir müşteri olurdu.
 *  2. **Vitrin kapıları atlanır.** Sipariş alımı kapalıyken panel sipariş
 *     açabilmeli — telefonda teyit zaten alınmış. (Cari limit kapısı, cari
 *     hesabın kendisiyle birlikte kaldırıldı.)
 *  3. **Abonelik bağı sahibiyle sınırlı.** A firmasının siparişi B'nin
 *     sözleşmesine yazılamaz.
 */
class AdminPhoneOrderTest extends KitchenTestCase
{
    private const string BASE_URI = '/admin/veykemtu/bridgeapi/phone_orders';

    /**
     * Panel şalteri TEST İÇİN AÇILIYOR — F4.
     *
     * `/admin/*` üretimde kapalı (`RequireAdminPanel`, varsayılan kapalı):
     * tek yönetim yüzeyi Kontrol Merkezi. Panel bir YEDEK olarak duruyor ve
     * yedeğin değeri, ihtiyaç anında çalıştığının bilinmesinde — bu yüzden
     * testler silinmedi, şalteri açıp koşuyorlar. Kapatmanın kendi testi
     * `AdminPanelClosedTest`.
     */
    protected function setUp(): void
    {
        parent::setUp();

        config([RequireAdminPanel::CONFIG_KEY => true]);
    }

    public function test_ekran_acilir_ve_ham_ceviri_anahtari_sizmaz(): void
    {
        $this->actingAsAdmin();

        $this->get(self::BASE_URI)
            ->assertOk()
            ->assertSee(lang('veykemtu.bridgeapi::phoneorder.section_customer'))
            ->assertSee(lang('veykemtu.bridgeapi::phoneorder.section_items'))
            ->assertDontSee('veykemtu.bridgeapi::phoneorder');
    }

    public function test_giris_yapmadan_acilmaz(): void
    {
        $this->get(self::BASE_URI)->assertRedirect();
    }

    /**
     * Mutlu yol: sipariş doğar, `onaylandi` olur ve MUTFAK BESLEMESİNDE görünür.
     *
     * "Fiş kuyruğa girdi mi" diye bakılmıyor, çünkü öyle bir kuyruk yok:
     * `veykemtu_print_jobs` sunucunun ürettiği bir iş listesi değil, kasanın
     * bastıktan sonra yazdığı ONAY kaydı (`KitchenController::ack`). Fişin
     * gerçekten basılacağının sunucu tarafındaki tek göstergesi, siparişin
     * kasanın yokladığı listede `onaylandi` olarak görünmesi.
     */
    public function test_siparis_onaylandi_dogar_ve_mutfaga_duser(): void
    {
        $this->actingAsAdmin();
        $customer = $this->corporateCustomer();

        $this->post(self::BASE_URI, [
            '_handler' => 'onCreateOrder',
            'customer_id' => $customer->customer_id,
            'delivery_type' => 'collection',
            'payment_method' => 'cash',
            'line_menu_id' => [$this->menuId('Mercimek Çorbası')],
            'line_quantity' => [3],
            'line_note' => [''],
        ])->assertRedirect();

        $order = Order::query()->latest('order_id')->first();

        $this->assertNotNull($order, 'Sipariş oluşmalı.');
        $this->assertSame(
            OrderStatusTransition::CONFIRMED,
            resolve(OrderStatusTransition::class)->codeOf($order),
            'Telefon siparişi doğrudan onaylandı olmalı — yoksa mutfağa düşmez.',
        );
        $ids = collect(
            $this->asKitchen()->getJson('/api/kitchen/orders', self::HEADERS)->json('data'),
        )
            ->pluck('id')
            ->all();

        $this->assertContains(
            (int) $order->order_id,
            $ids,
            'Telefon siparişi mutfağın yokladığı listede görünmeli.',
        );
    }

    /**
     * Adet 0 ve ürünsüz satırlar atlanır; form altı boş satırla açılıyor.
     */
    public function test_bos_satirlar_yok_sayilir(): void
    {
        $this->actingAsAdmin();
        $customer = $this->corporateCustomer();

        $this->post(self::BASE_URI, [
            '_handler' => 'onCreateOrder',
            'customer_id' => $customer->customer_id,
            'delivery_type' => 'collection',
            'payment_method' => 'cash',
            'line_menu_id' => [0, $this->menuId('Mercimek Çorbası'), 0],
            'line_quantity' => [5, 2, 0],
            'line_note' => ['', '', ''],
        ])->assertRedirect();

        $order = Order::query()->latest('order_id')->first();

        $this->assertSame(2, (int) $order->total_items);
    }

    public function test_urunsuz_siparis_olusturulamaz(): void
    {
        $this->actingAsAdmin();
        $customer = $this->corporateCustomer();

        $onceki = Order::query()->count();

        $this->post(self::BASE_URI, [
            '_handler' => 'onCreateOrder',
            'customer_id' => $customer->customer_id,
            'delivery_type' => 'collection',
            'payment_method' => 'cash',
            'line_menu_id' => [0],
            'line_quantity' => [0],
        ]);

        $this->assertSame($onceki, Order::query()->count());
    }

    /**
     * Kayıtlı olmayan müşteri aynı ekranda açılır ve `corporate` etiketiyle
     * doğar.
     *
     * Etiket artık bir yetki değil (kurumsal sipariş kapısı kalktı), ama
     * değerin sabit kalması önemli: panelden açılan kayıtlarla web'den
     * açılanlar aynı varsayılanı taşımalı, yoksa müşteri listesi zamanla
     * iki farklı geçmişe bölünür.
     */
    public function test_yeni_musteri_kurumsal_etiketiyle_dogar(): void
    {
        $this->actingAsAdmin();

        $this->post(self::BASE_URI, [
            '_handler' => 'onCreateOrder',
            'customer_id' => 0,
            'new_org_name' => 'Yeni Kurumsal AS',
            'new_contact' => 'Ayse Yetkili',
            'new_phone' => '05559998877',
            'delivery_type' => 'collection',
            'payment_method' => 'cash',
            'line_menu_id' => [$this->menuId('Mercimek Çorbası')],
            'line_quantity' => [1],
        ])->assertRedirect();

        $customer = ApiCustomer::where('bld_org_name', 'Yeni Kurumsal AS')->first();

        $this->assertNotNull($customer);
        $this->assertSame('corporate', $customer->bld_account_type);
    }

    public function test_unvani_olmayan_yeni_musteri_reddedilir(): void
    {
        $this->actingAsAdmin();

        $onceki = Order::query()->count();

        $this->post(self::BASE_URI, [
            '_handler' => 'onCreateOrder',
            'customer_id' => 0,
            'new_org_name' => '',
            'new_phone' => '05559998877',
            'delivery_type' => 'collection',
            'payment_method' => 'cash',
            'line_menu_id' => [$this->menuId('Mercimek Çorbası')],
            'line_quantity' => [1],
        ]);

        $this->assertSame($onceki, Order::query()->count());
        $this->assertSame(0, ApiCustomer::where('telephone', '05559998877')->count());
    }

    // ── Abonelik bağı ─────────────────────────────────────────────────────

    public function test_baska_musterinin_aboneligine_baglanamaz(): void
    {
        $this->actingAsAdmin();

        $customer = $this->corporateCustomer();
        $other = $this->corporateCustomer('Baska Firma', 'baska@ornek.com');
        $subscription = $this->activeSubscription($other);

        $onceki = Order::query()->count();

        $this->post(self::BASE_URI, [
            '_handler' => 'onCreateOrder',
            'customer_id' => $customer->customer_id,
            'subscription_id' => $subscription->id,
            'delivery_type' => 'collection',
            'payment_method' => 'cash',
            'line_menu_id' => [$this->menuId('Mercimek Çorbası')],
            'line_quantity' => [1],
        ]);

        $this->assertSame($onceki, Order::query()->count());
    }

    public function test_kendi_aboneligine_baglanan_siparis_isaretlenir(): void
    {
        $this->actingAsAdmin();

        $customer = $this->corporateCustomer();
        $subscription = $this->activeSubscription($customer);

        $this->post(self::BASE_URI, [
            '_handler' => 'onCreateOrder',
            'customer_id' => $customer->customer_id,
            'subscription_id' => $subscription->id,
            'delivery_type' => 'collection',
            'payment_method' => 'cash',
            'line_menu_id' => [$this->menuId('Mercimek Çorbası')],
            'line_quantity' => [1],
        ])->assertRedirect();

        $order = Order::query()->latest('order_id')->first();

        $this->assertSame((int) $subscription->id, (int) $order->bld_subscription_id);
    }

    // ── Ek porsiyon (istisna) ─────────────────────────────────────────────

    /**
     * EK PORSİYON MEVCUT ADEDİN ÜSTÜNE EKLENİR, YERİNE GEÇMEZ.
     *
     * `quantity_override` o günün TOPLAM porsiyonudur. Ek porsiyon oraya
     * doğrudan yazılsaydı 100 kişilik bir abonelik 10 kişiye düşerdi ve
     * bunun tek belirtisi ertesi sabah mutfakta görülürdü.
     */
    public function test_ek_porsiyon_varsayilan_adedin_ustune_eklenir(): void
    {
        $this->actingAsAdmin();

        $customer = $this->corporateCustomer();
        $subscription = $this->activeSubscription($customer, quantity: 100);
        $yarin = BusinessTime::now()->addDay();

        $this->post(self::BASE_URI, [
            '_handler' => 'onAddSubscriptionPortions',
            'extra_subscription_id' => $subscription->id,
            'extra_date' => $yarin->toDateString(),
            'extra_quantity' => 10,
        ])->assertRedirect();

        $exception = SubscriptionException::query()
            ->where('subscription_id', $subscription->id)
            ->first();

        $this->assertNotNull($exception);
        $this->assertSame(
            110,
            (int) $exception->quantity_override,
            '100 varsayılan + 10 ek = 110 olmalı.',
        );
    }

    public function test_ek_porsiyon_ikinci_kez_de_ustune_eklenir(): void
    {
        $this->actingAsAdmin();

        $customer = $this->corporateCustomer();
        $subscription = $this->activeSubscription($customer, quantity: 100);
        $yarin = BusinessTime::now()->addDay()->toDateString();

        foreach ([10, 5] as $adet) {
            $this->post(self::BASE_URI, [
                '_handler' => 'onAddSubscriptionPortions',
                'extra_subscription_id' => $subscription->id,
                'extra_date' => $yarin,
                'extra_quantity' => $adet,
            ])->assertRedirect();
        }

        $this->assertSame(
            115,
            (int) SubscriptionException::query()
                ->where('subscription_id', $subscription->id)
                ->value('quantity_override'),
        );
    }

    /**
     * Geçmiş gün reddedilir: o günün üretimi çoktan koştu, istisnanın hiçbir
     * etkisi olmaz ve yönetici bir şey yaptığını sanırdı.
     */
    public function test_gecmis_gune_ek_porsiyon_islenmez(): void
    {
        $this->actingAsAdmin();

        $customer = $this->corporateCustomer();
        $subscription = $this->activeSubscription($customer);

        $this->post(self::BASE_URI, [
            '_handler' => 'onAddSubscriptionPortions',
            'extra_subscription_id' => $subscription->id,
            'extra_date' => BusinessTime::now()->subDay()->toDateString(),
            'extra_quantity' => 10,
        ]);

        $this->assertSame(0, SubscriptionException::query()->count());
    }

    /**
     * BUGÜN de reddedilir — üretim dün gece 22:00'de koştu.
     */
    public function test_bugune_ek_porsiyon_islenmez(): void
    {
        $this->actingAsAdmin();

        $customer = $this->corporateCustomer();
        $subscription = $this->activeSubscription($customer);

        $this->post(self::BASE_URI, [
            '_handler' => 'onAddSubscriptionPortions',
            'extra_subscription_id' => $subscription->id,
            'extra_date' => BusinessTime::now()->toDateString(),
            'extra_quantity' => 10,
        ]);

        $this->assertSame(0, SubscriptionException::query()->count());
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    private function corporateCustomer(
        string $orgName = 'Test Kurumsal',
        string $email = 'kurumsal@ornek.com',
    ): ApiCustomer {
        $customer = new ApiCustomer;
        $customer->first_name = 'Yetkili';
        $customer->last_name = 'Kisi';
        $customer->email = $email;
        $customer->telephone = '05001112233';
        $customer->status = true;
        $customer->bld_account_type = 'corporate';
        $customer->bld_org_name = $orgName;
        $customer->save();

        return $customer;
    }

    private function activeSubscription(ApiCustomer $customer, int $quantity = 10): Subscription
    {
        $subscription = new Subscription;
        $subscription->customer_id = $customer->customer_id;
        $subscription->location_id = $this->locationId();
        $subscription->status = Subscription::STATUS_ACTIVE;
        $subscription->start_date = BusinessTime::now()->subMonth()->toDateString();
        $subscription->end_date = null;
        $subscription->delivery_type = 'pickup';
        $subscription->service_days = [1, 2, 3, 4, 5, 6, 7];
        $subscription->menu_mode = Subscription::MENU_FIXED_LIST;
        $subscription->default_quantity = $quantity;
        $subscription->agreed_unit_price_kurus = 5000;
        $subscription->payment_mode = Subscription::PAYMENT_PREPAID;
        $subscription->save();

        return $subscription;
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
