<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Admin\Models\Status;
use Igniter\Cart\Models\Order;
use Igniter\Local\Models\Location;
use Igniter\System\Models\Settings;
use Igniter\User\Facades\AdminAuth;
use Igniter\User\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use Veykemtu\BridgeApi\Admin\AdminRegistrar;
use Veykemtu\BridgeApi\Admin\BldSettings;
use Veykemtu\BridgeApi\Admin\LiraField;
use Veykemtu\BridgeApi\Admin\OperationsSnapshot;
use Veykemtu\BridgeApi\Admin\SettingsRepository;
use Veykemtu\BridgeApi\Models\KitchenDevice;
use Veykemtu\BridgeApi\Models\PrintJob;
use Veykemtu\BridgeApi\Services\LocationGate;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * "BLD Ayarları" admin sayfası ve gösterge parçacığı.
 *
 * Buradaki testlerin ağırlık merkezi iki yerdedir:
 *
 *  1. **Para dönüşümü.** Arayüz TL alır, `LocationGate` kuruş `int` bekler.
 *     Bir kuruşluk sapma raporları tutmaz hâle getirir; dönüşüm tek yerdedir
 *     (`LiraField`) ve gidiş-dönüş burada sabitlenir.
 *  2. **Tek kaynak.** Sayfanın yazdığı her değer `LocationGate` üzerinden
 *     geri okunabilmelidir. Okunamıyorsa sayfa ikinci bir kaynak açmış
 *     demektir ve API ile panel birbirinden ayrı düşmüş olur.
 */
class AdminSettingsTest extends TestCase
{
    use RefreshDatabase {
        refreshTestDatabase as private laravelRefreshTestDatabase;
    }

    /** Çekirdek şeması yalnızca `igniter:up` ile kurulur — bkz. ContractTest. */
    protected function refreshTestDatabase(): void
    {
        $this->laravelRefreshTestDatabase();

        $this->artisan('igniter:up');
    }

    protected function setUp(): void
    {
        parent::setUp();

        $this->artisan('veykemtu:setup');
    }

    // ── TL ↔ kuruş dönüşümü ───────────────────────────────────────────────

    /**
     * Veri sağlayıcı DEĞİL, tek test: her senaryo ayrı test olsaydı
     * `setUp()` (şema + `veykemtu:setup`) on iki kez koşardı ve saniyelik
     * bir dönüşüm sınaması dakikalara çıkardı. `LiraField` veritabanına
     * hiç dokunmaz.
     */
    public function test_lira_girdisi_kurusa_cevrilir(): void
    {
        $cases = [
            'tam sayı' => ['250', 25000],
            'nokta ile kuruş' => ['250.50', 25050],
            'virgül ile kuruş' => ['250,50', 25050],
            'tek ondalık basamak' => ['250.5', 25050],
            'sıfır' => ['0', 0],
            'boş girdi' => ['', 0],
            'baştaki/sondaki boşluk' => ['  40,00  ', 4000],
            'yalnızca kuruş' => ['0,29', 29],
            'üçüncü basamak yukarı yuvarlanır' => ['1,005', 101],
            'üçüncü basamak aşağı yuvarlanır' => ['1,004', 100],
            'binlik ayıracı nokta' => ['1.250,75', 125075],
            'binlik ayıracı virgül' => ['1,250.75', 125075],
        ];

        foreach ($cases as $name => [$input, $expected]) {
            $this->assertSame($expected, LiraField::toKurus($input), $name);
        }
    }

    public function test_kurus_form_kutusuna_geri_yazilir(): void
    {
        $this->assertSame('45.50', LiraField::toInput(4550));
        $this->assertSame('0.00', LiraField::toInput(0));
        $this->assertSame('0.09', LiraField::toInput(9));
        $this->assertSame('1250.00', LiraField::toInput(125000));
    }

    /**
     * Gidiş-dönüş kaybı olmamalı: yönetici kaydedip sayfayı tekrar açıp
     * tekrar kaydettiğinde değer kaymamalıdır.
     */
    public function test_gidis_donus_kurusu_korur(): void
    {
        foreach ([0, 1, 9, 99, 100, 4050, 25050, 999_999] as $kurus) {
            $this->assertSame(
                $kurus,
                LiraField::toKurus(LiraField::toInput($kurus)),
                "Kuruş {$kurus} gidiş-dönüşte değişti",
            );
        }
    }

    // ── Depo: gate tek kaynaktır ──────────────────────────────────────────

    public function test_kaydedilen_degerler_gate_uzerinden_okunur(): void
    {
        [$repository, $gate, $location] = $this->wiring();

        $repository->save($location, $this->formData([
            SettingsRepository::FIELD_ORDERING => 0,
            SettingsRepository::FIELD_CUTOFF => '16:30',
            SettingsRepository::FIELD_MIN_TOTAL => '250,50',
            SettingsRepository::FIELD_DELIVERY_FEE => '40,00',
            SettingsRepository::FIELD_PAYMENTS => ['cash'],
        ]));

        $this->assertFalse($gate->orderingEnabled($location));
        $this->assertSame('16:30', $gate->orderCutoff($location));
        $this->assertSame(25050, $gate->minOrderTotal($location));
        $this->assertSame(4000, $gate->deliveryFee($location));
        $this->assertSame(['cash'], $gate->paymentMethods($location));
    }

    public function test_para_alani_kurus_int_olarak_saklanir(): void
    {
        [$repository, $gate, $location] = $this->wiring();

        $repository->save($location, $this->formData([
            SettingsRepository::FIELD_MIN_TOTAL => '99,99',
        ]));

        // Kritik: 9999, 9998 veya 10000 değil.
        $this->assertSame(9999, $gate->minOrderTotal($location));
        $this->assertIsInt($gate->minOrderTotal($location));
    }

    public function test_bos_kesim_saati_temizler(): void
    {
        [$repository, $gate, $location] = $this->wiring();

        $repository->save($location, $this->formData([
            SettingsRepository::FIELD_CUTOFF => '16:00',
        ]));
        $this->assertSame('16:00', $gate->orderCutoff($location));

        $repository->save($location, $this->formData([
            SettingsRepository::FIELD_CUTOFF => '',
        ]));
        $this->assertNull($gate->orderCutoff($location));
    }

    public function test_odeme_yontemi_secilmezse_varsayilana_doner(): void
    {
        [$repository, $gate, $location] = $this->wiring();

        $repository->save($location, $this->formData([
            SettingsRepository::FIELD_PAYMENTS => [],
        ]));

        $this->assertSame(LocationGate::DEFAULT_PAYMENT_METHODS, $gate->paymentMethods($location));
    }

    /**
     * Dakika alanları formda `number` tipindedir ve çekirdek onları
     * postback'te `(int)` ile daraltır. Para alanlarında bu daraltma kuruş
     * kaybettiriyordu; dakikalarda kaybedilecek bir şey olmadığını burada
     * sabitliyoruz — alan tipi ileride yanlışlıkla değiştirilirse bu test
     * düşmez ama gidiş-dönüşün bozulduğu an düşer.
     */
    public function test_dakika_alanlari_gate_uzerinden_okunur(): void
    {
        [$repository, $gate, $location] = $this->wiring();

        $repository->save($location, $this->formData([
            SettingsRepository::FIELD_PREP_MINUTES => 25,
            SettingsRepository::FIELD_DELIVERY_MINUTES => 35,
            SettingsRepository::FIELD_BUSY_EXTRA_MINUTES => 20,
        ]));

        $this->assertSame(25, $gate->prepMinutes($location));
        $this->assertSame(35, $gate->deliveryMinutes($location));
        $this->assertSame(20, $gate->busyExtraMinutes($location));

        // Sayfayı yeniden açtığımızda kutularda aynı değerler durmalı:
        // yönetici "kaydettim ama geri geldi" durumuyla karşılaşmamalı.
        $form = $repository->toFormData($location);
        $this->assertSame(25, $form[SettingsRepository::FIELD_PREP_MINUTES]);
        $this->assertSame(35, $form[SettingsRepository::FIELD_DELIVERY_MINUTES]);
        $this->assertSame(20, $form[SettingsRepository::FIELD_BUSY_EXTRA_MINUTES]);
    }

    /**
     * Sıfır ve saçma büyüklükteki değerler gate'te varsayılana/üst sınıra
     * çekilir. Form doğrulaması zaten 1-480 arası istiyor ama tek savunma
     * hattı olarak ona güvenmiyoruz: "0 dakikada teslim" sözü verilmemeli.
     */
    public function test_gecersiz_dakika_degeri_makul_sinira_cekilir(): void
    {
        [$repository, $gate, $location] = $this->wiring();

        $repository->save($location, $this->formData([
            SettingsRepository::FIELD_PREP_MINUTES => 0,
            SettingsRepository::FIELD_DELIVERY_MINUTES => 100_000,
        ]));

        $this->assertSame(40, $gate->prepMinutes($location));
        $this->assertSame(480, $gate->deliveryMinutes($location));
    }

    // ── Yoğunluk: mutfakla yarış ──────────────────────────────────────────

    /**
     * Sayfa açıkken mutfak tuşa bastıysa, yöneticinin dokunmadığı anahtar
     * geri alınmamalıdır — bu, mutfakta "tuş çalışmıyor" olarak görünen ve
     * sebebi bulunamayan bir hatadır.
     */
    public function test_yonetici_dokunmadiysa_mutfagin_yogunlugu_ezilmez(): void
    {
        [$repository, $gate, $location] = $this->wiring();

        // Sayfa "yoğun değil" iken çizildi.
        $rendered = $repository->toFormData($location);
        $this->assertSame(0, $rendered[SettingsRepository::FIELD_BUSY_SNAPSHOT]);

        // Mutfak bu arada yoğunluğu açtı.
        $gate->setBusy($location, true);

        // Yönetici ilgisiz bir alanı kaydetti.
        $repository->save($location, array_merge($rendered, [
            SettingsRepository::FIELD_CUTOFF => '17:00',
        ]));

        $this->assertTrue($gate->isBusy($location), 'Mutfağın açtığı yoğunluk ezildi');
        $this->assertSame('17:00', $gate->orderCutoff($location));
    }

    public function test_yonetici_yogunlugu_bilincli_kapatabilir(): void
    {
        [$repository, $gate, $location] = $this->wiring();

        $gate->setBusy($location, true);
        $rendered = $repository->toFormData($location);
        $this->assertSame(1, $rendered[SettingsRepository::FIELD_BUSY_SNAPSHOT]);

        $repository->save($location, array_merge($rendered, [
            SettingsRepository::FIELD_BUSY => 0,
        ]));

        $this->assertFalse($gate->isBusy($location));
    }

    public function test_yonetici_yogunlugu_bilincli_acabilir(): void
    {
        [$repository, $gate, $location] = $this->wiring();

        $repository->save($location, $this->formData([
            SettingsRepository::FIELD_BUSY => 1,
            SettingsRepository::FIELD_BUSY_SNAPSHOT => 0,
        ]));

        $this->assertTrue($gate->isBusy($location));
    }

    // ── Yoğunluk metni ────────────────────────────────────────────────────

    public function test_yogunluk_metni_kaydedilir(): void
    {
        [$repository, $gate, $location] = $this->wiring();

        $repository->save($location, $this->formData([
            SettingsRepository::FIELD_BUSY_MESSAGE => 'Bugün düğün siparişimiz var, gecikebiliriz.',
        ]));

        $this->assertSame(
            'Bugün düğün siparişimiz var, gecikebiliriz.',
            $gate->busyMessage($location),
        );
    }

    /**
     * Kutu boşaltıldığında ya da varsayılan metin olduğu gibi geri
     * gönderildiğinde özel metin saklanmaz; ikisi de varsayılana döner.
     * Aksi hâlde varsayılan metni ileride değiştirmek imkânsızlaşırdı.
     */
    public function test_bos_veya_varsayilan_metin_ozel_metni_temizler(): void
    {
        [$repository, $gate, $location] = $this->wiring();

        $repository->save($location, $this->formData([
            SettingsRepository::FIELD_BUSY_MESSAGE => 'Özel metin',
        ]));
        $this->assertSame('Özel metin', $gate->busyMessage($location));

        $repository->save($location, $this->formData([
            SettingsRepository::FIELD_BUSY_MESSAGE => '   ',
        ]));
        $this->assertSame(LocationGate::DEFAULT_BUSY_MESSAGE, $gate->busyMessage($location));

        $repository->save($location, $this->formData([
            SettingsRepository::FIELD_BUSY_MESSAGE => LocationGate::DEFAULT_BUSY_MESSAGE,
        ]));
        $this->assertSame(LocationGate::DEFAULT_BUSY_MESSAGE, $gate->busyMessage($location));
    }

    // ── Form nesnesi ──────────────────────────────────────────────────────

    public function test_form_modeli_gate_degerlerini_gosterir(): void
    {
        [, $gate, $location] = $this->wiring();

        $gate->setMinOrderTotal($location, 12345);
        $gate->setDeliveryFee($location, 4000);
        $gate->setOrderCutoff($location, '15:45');
        $gate->setBusy($location, true);

        $model = new BldSettings;

        $this->assertSame('123.45', $model->{SettingsRepository::FIELD_MIN_TOTAL});
        $this->assertSame('40.00', $model->{SettingsRepository::FIELD_DELIVERY_FEE});
        $this->assertSame('15:45', $model->{SettingsRepository::FIELD_CUTOFF});
        $this->assertSame(1, $model->{SettingsRepository::FIELD_BUSY});
    }

    public function test_form_modeli_kaydedince_gate_e_yazar(): void
    {
        [, $gate, $location] = $this->wiring();

        $model = new BldSettings;
        $this->assertTrue($model->set($this->formData([
            SettingsRepository::FIELD_MIN_TOTAL => '75,25',
            SettingsRepository::FIELD_ORDERING => 0,
        ])));

        $this->assertSame(7525, $gate->minOrderTotal($location));
        $this->assertFalse($gate->orderingEnabled($location));

        // Kaydetmenin ardından form kendini gate'ten tazeler.
        $this->assertSame('75.25', $model->{SettingsRepository::FIELD_MIN_TOTAL});
    }

    /**
     * Form tanımındaki her girdi alanının bir doğrulama kuralı olmalı.
     *
     * Kuralsız bir alan, doğrulamayı atlayıp doğrudan gate'e ulaşır; kesim
     * saati alanında bu, `orderCutoff()` okurken sessizce `null` dönmesi
     * demektir ve yönetici kesim saatinin neden işlemediğini bulamaz.
     */
    public function test_form_tanimindaki_her_alanin_kurali_var(): void
    {
        $config = (new BldSettings)->getFieldConfig();

        $ruleNames = array_column($config['rules'], 0);

        foreach ($config['fields'] as $name => $field) {
            if (($field['type'] ?? 'text') === 'section') {
                continue;
            }

            $this->assertContains($name, $ruleNames, "`{$name}` alanının doğrulama kuralı yok");
        }
    }

    public function test_form_alanlari_depo_sabitleriyle_ortusur(): void
    {
        $config = (new BldSettings)->getFieldConfig();

        foreach ([
            SettingsRepository::FIELD_ORDERING,
            SettingsRepository::FIELD_CUTOFF,
            SettingsRepository::FIELD_MIN_TOTAL,
            SettingsRepository::FIELD_DELIVERY_FEE,
            SettingsRepository::FIELD_PAYMENTS,
            SettingsRepository::FIELD_BUSY,
            SettingsRepository::FIELD_BUSY_SNAPSHOT,
            SettingsRepository::FIELD_BUSY_MESSAGE,
        ] as $field) {
            $this->assertArrayHasKey($field, $config['fields']);
        }
    }

    /**
     * Para alanları `number` tipinde OLMAMALI.
     *
     * `Form::getSaveData()` `number` tipindeki alanı postback'te `(int)` ile
     * daraltıyor: "45.50" değeri kaydedilmeden önce 45'e düşer ve kuruşlar
     * kaybolur. Bu test, ileride "daha doğru tip" diye yapılacak masum bir
     * değişikliği yakalar.
     */
    public function test_para_alanlari_number_tipinde_degil(): void
    {
        $fields = (new BldSettings)->getFieldConfig()['fields'];

        foreach ([SettingsRepository::FIELD_MIN_TOTAL, SettingsRepository::FIELD_DELIVERY_FEE] as $field) {
            $this->assertSame('text', $fields[$field]['type']);
        }
    }

    // ── Admin sayfası ─────────────────────────────────────────────────────

    public function test_ayarlar_sayfasi_yoneticiye_acilir(): void
    {
        $this->registerSettingItem();

        $this->actingAsAdmin();

        $this->get('/admin/extensions/edit/veykemtu/bridgeapi/'.BldSettings::SETTINGS_CODE)
            ->assertOk()
            ->assertSee('BLD Ayarları')
            ->assertSee(SettingsRepository::FIELD_MIN_TOTAL);
    }

    public function test_ayarlar_sayfasi_giris_yapmadan_acilmaz(): void
    {
        $this->registerSettingItem();

        $this->get('/admin/extensions/edit/veykemtu/bridgeapi/'.BldSettings::SETTINGS_CODE)
            ->assertRedirect();
    }

    // ── Gösterge paneli özeti ─────────────────────────────────────────────

    public function test_ozet_bugunku_siparisleri_ve_salterleri_bildirir(): void
    {
        [, $gate, $location] = $this->wiring();

        $gate->setOrderingEnabled($location, false);
        $gate->setBusy($location, true);
        $gate->setOrderCutoff($location, '16:00');

        $today = $this->makeOrder(OrderStatusTransition::NEW, 4550);
        $this->makeOrder(OrderStatusTransition::DELIVERED, 3000);
        $cancelled = $this->makeOrder(OrderStatusTransition::CANCELLED, 9900);

        // Dünkü sipariş bugünün sayısına girmemeli.
        $yesterday = $this->makeOrder(OrderStatusTransition::DELIVERED, 1000);
        $yesterday->created_at = BusinessTime::forStorage(BusinessTime::now()->subDay());
        $yesterday->saveQuietly();

        PrintJob::query()->create([
            'order_id' => $today->order_id,
            'type' => PrintJob::TYPE_KITCHEN,
            'printed_at' => BusinessTime::forStorage(BusinessTime::now()),
        ]);

        $snapshot = resolve(OperationsSnapshot::class)->collect();

        $this->assertTrue($snapshot['has_location']);
        $this->assertFalse($snapshot['ordering_enabled']);
        $this->assertTrue($snapshot['busy']);
        $this->assertSame('16:00', $snapshot['order_cutoff']);
        $this->assertSame(3, $snapshot['orders_today']);
        // İptal edilen sipariş ciroya girmez: 4550 + 3000.
        $this->assertSame(7550, $snapshot['revenue_today_kurus']);
        $this->assertSame(1, $snapshot['pending_orders']);
        // Bugünkü üç siparişten yalnızca birinin mutfak fişi basılmış.
        $this->assertSame(2, $snapshot['unprinted_orders']);
        $this->assertNotNull($cancelled);
    }

    public function test_ozet_cevrimici_kasalari_sayar(): void
    {
        $online = new KitchenDevice;
        $online->name = 'Kasa 1';
        $online->last_seen_at = BusinessTime::forStorage(BusinessTime::now()->subMinute());
        $online->save();

        $stale = new KitchenDevice;
        $stale->name = 'Kasa 2';
        $stale->last_seen_at = BusinessTime::forStorage(BusinessTime::now()->subHour());
        $stale->save();

        $revoked = new KitchenDevice;
        $revoked->name = 'Kasa 3';
        $revoked->last_seen_at = BusinessTime::forStorage(BusinessTime::now());
        $revoked->revoked_at = BusinessTime::forStorage(BusinessTime::now());
        $revoked->save();

        $snapshot = resolve(OperationsSnapshot::class)->collect();

        $this->assertSame(1, $snapshot['devices_online']);
        $this->assertSame(2, $snapshot['devices_total']);
    }

    /**
     * Parçacığın şablonu gerçekten çizilebilmeli.
     *
     * Bozuk bir `@directive` ya da eksik bir çeviri anahtarı yalnızca
     * gösterge paneli açıldığında ortaya çıkar — ve orada patlarsa yönetici
     * paneli boş bir sayfayla karşılar. Şablonu parçacık sınıfının verdiği
     * değişkenlerle burada çiziyoruz; geriye yalnızca sınıfın üç satırlık
     * tutkalı kalıyor.
     */
    public function test_gosterge_parcacigi_cizilir(): void
    {
        $snapshot = resolve(OperationsSnapshot::class)->collect();

        $html = view()->file(
            dirname(__DIR__, 2).'/resources/views/_partials/admin/dashboardwidgets/bldstatus/bldstatus.blade.php',
            [
                'bld' => $snapshot,
                'revenueToday' => 0.0,
                'settingsUrl' => admin_url('extensions/edit/veykemtu/bridgeapi/settings'),
            ],
        )->render();

        $this->assertStringContainsString('widget-bldstatus', $html);
        // Çeviri anahtarı ham hâliyle ekrana düşmemeli.
        $this->assertStringNotContainsString('veykemtu.bridgeapi::', $html);
    }

    // ── Kayıt tanımları ───────────────────────────────────────────────────

    public function test_kayit_tanimlari_gercek_siniflari_gosterir(): void
    {
        $settings = AdminRegistrar::registerSettings();

        $this->assertArrayHasKey(BldSettings::SETTINGS_CODE, $settings);
        $this->assertSame(
            BldSettings::class,
            $settings[BldSettings::SETTINGS_CODE]['model'],
        );
        $this->assertContains(
            AdminRegistrar::PERMISSION,
            $settings[BldSettings::SETTINGS_CODE]['permissions'],
        );

        $this->assertArrayHasKey(
            AdminRegistrar::PERMISSION,
            AdminRegistrar::registerPermissions(),
        );

        foreach (array_keys(AdminRegistrar::registerDashboardWidgets()) as $class) {
            $this->assertTrue(class_exists($class), "Parçacık sınıfı yok: {$class}");
        }
    }

    /**
     * Menüdeki kısayol ile çekirdeğin ayar girdisi için ürettiği adres aynı
     * olmalı. Ayrıldıklarında menü bağlantısı 404 verir ve bunu yalnızca
     * tıklayan fark eder.
     */
    public function test_menu_kisayolu_ayar_sayfasiyla_ayni_adresi_gosterir(): void
    {
        $navigation = AdminRegistrar::registerNavigation();
        $href = $navigation['restaurant']['child']['bld_settings']['href'];

        $this->assertSame(
            admin_url('extensions/edit/veykemtu/bridgeapi/'.BldSettings::SETTINGS_CODE),
            $href,
        );
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    /** @return array{SettingsRepository, LocationGate, Location} */
    private function wiring(): array
    {
        $repository = resolve(SettingsRepository::class);
        $location = $repository->location();

        $this->assertInstanceOf(Location::class, $location);

        return [$repository, resolve(LocationGate::class), $location];
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function formData(array $overrides = []): array
    {
        return array_merge([
            SettingsRepository::FIELD_ORDERING => 1,
            SettingsRepository::FIELD_CUTOFF => '',
            SettingsRepository::FIELD_MIN_TOTAL => '0.00',
            SettingsRepository::FIELD_DELIVERY_FEE => '0.00',
            SettingsRepository::FIELD_PAYMENTS => ['cash', 'account'],
            SettingsRepository::FIELD_BUSY => 0,
            SettingsRepository::FIELD_BUSY_SNAPSHOT => 0,
            SettingsRepository::FIELD_BUSY_MESSAGE => '',
            SettingsRepository::FIELD_PREP_MINUTES => 40,
            SettingsRepository::FIELD_DELIVERY_MINUTES => 20,
            SettingsRepository::FIELD_BUSY_EXTRA_MINUTES => 15,
        ], $overrides);
    }

    private function makeOrder(string $statusCode, int $totalKurus): Order
    {
        $order = new Order;
        $order->location_id = resolve(SettingsRepository::class)->location()?->getKey();
        $order->first_name = 'Test';
        $order->last_name = 'Müşteri';
        $order->email = 'ozet@ornek.com';
        $order->telephone = '5551234567';
        $order->order_type = Order::DELIVERY;
        $order->order_total = $totalKurus / 100;
        $order->total_items = 1;
        $order->status_id = (int) Status::where('status_code', $statusCode)->value('status_id');
        $order->save();

        return $order;
    }

    /**
     * Ayar girdisi normalde `Extension.php` üzerinden kaydedilir; o dosya bu
     * görevin dışındadır. Test, çekirdeğin kendi kayıt geri çağrısını
     * kullanarak aynı girdiyi üretir — böylece sayfa, bağlama yapıldığında
     * nasıl davranacaksa öyle sınanır.
     */
    private function registerSettingItem(): void
    {
        Settings::registerCallback(static function (Settings $manager): void {
            $manager->registerSettingItems('veykemtu.bridgeapi', AdminRegistrar::registerSettings());
        });
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
