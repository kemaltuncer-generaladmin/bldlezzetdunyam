<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Order;
use Illuminate\Contracts\Console\Kernel as ConsoleKernel;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\RefreshDatabaseState;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Models\KitchenCommand;
use Veykemtu\BridgeApi\Models\KitchenDevice;
use Veykemtu\BridgeApi\Models\PrintJob;
use Igniter\Local\Models\Location;
use Veykemtu\BridgeApi\Services\KitchenDeviceSettings;
use Veykemtu\BridgeApi\Services\LocationGate;
use Veykemtu\BridgeApi\Services\MenuAvailability;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;

/**
 * Sözleşme uyum testleri — `docs/openapi.yaml`.
 *
 * `docs/04-platform.md` §6: her uç için en az 200 mutlu yol, 401/403 yetki
 * ve 422 doğrulama testi. Buradaki beklentiler sözleşmeden gelir, koddan
 * değil: kod sözleşmeden saparsa test kırılmalıdır, tersi değil.
 */
class ContractTest extends TestCase
{
    // `refreshTestDatabase` bir trait metodudur; `parent::` ile çağrılamaz.
    use RefreshDatabase;

    private const array HEADERS = [
        'X-App-Id' => 'website',
        'X-App-Version' => '1.0.0',
        'Accept' => 'application/json',
    ];

    /**
     * Şema kurulumu: `migrate:fresh` + `igniter:up`, İŞLEM AÇILMADAN ÖNCE.
     *
     * `migrate:fresh` TastyIgniter'ın tablolarını KURMAZ; çekirdek göçler
     * eklenti sisteminden gelir ve yalnızca `igniter:up` ile koşar.
     *
     * NEDEN LARAVEL'İN METODUNU ÇAĞIRMIYORUZ: o metot şemayı kurduktan
     * sonra **işlemi de başlatıyor** (`beginDatabaseTransaction`). Önceki
     * hâlde `igniter:up` o çağrıdan SONRA koşuyordu, yani açık bir işlemin
     * içinde DDL çalışıyordu. MySQL'de DDL **örtük commit** yapar:
     * savepoint yok olur, `DB::transaction()` kullanan her uç
     * `SAVEPOINT trans2 does not exist` ile 500 döner ve testler arası
     * geri alma çalışmaz — demo menü her testte üstüne yüklenirdi.
     * Sahada 25 testi tek başına düşürüyordu (12.08.2026).
     *
     * Şema yenilemesi koşum başına bir kez; sonrası işlemle geri alınır.
     */
    protected function refreshTestDatabase(): void
    {
        $this->assertTestDatabase();

        if (!RefreshDatabaseState::$migrated) {
            $this->artisan('migrate:fresh', [
                '--drop-views' => $this->shouldDropViews(),
                '--drop-types' => $this->shouldDropTypes(),
            ]);

            $this->app[ConsoleKernel::class]->setArtisan(null);

            $this->artisan('igniter:up');

            RefreshDatabaseState::$migrated = true;
        }

        $this->beginDatabaseTransaction();
    }

    /**
     * Test veritabanına bağlı olduğumuzu ŞEMA DÜŞÜRÜLMEDEN ÖNCE doğrular.
     *
     * NEDEN BURADA VE NEDEN BU KADAR SERT: bir sonraki satır
     * `migrate:fresh` koşuyor, yani bağlı olduğu veritabanının bütün
     * tablolarını düşürüyor. Yanlış veritabanına bağlıysak veri gider ve
     * bunu ancak sonradan fark ederiz.
     *
     * İki kez yaşandı: PHPUnit'in `<env>` girdisi ortamda zaten tanımlı
     * `DB_DATABASE`'i ezmiyor ve testler geliştirme veritabanını
     * siliyordu. `force="true"` bunu düzeltti; bu kontrol de aynı hatanın
     * sessizce geri gelmesini engelliyor.
     */
    private function assertTestDatabase(): void
    {
        $name = (string) DB::connection()->getDatabaseName();

        if (!str_ends_with($name, '_test')) {
            $this->fail(
                "Testler '{$name}' veritabanına bağlı ve bir sonraki adım "
                ."tüm tabloları düşürecekti. Test veritabanı adı '_test' ile "
                .'bitmelidir — platform/phpunit.xml içindeki DB_DATABASE '
                .'girdisine bakın (force="true" olmalı).',
            );
        }
    }

    protected function setUp(): void
    {
        parent::setUp();

        $this->artisan('veykemtu:setup');
        $this->artisan('veykemtu:demo-menu');
    }

    // ── Zorunlu başlıklar ─────────────────────────────────────────────────

    public function test_baslik_eksikse_422_doner(): void
    {
        $this->getJson('/api/health')
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED')
            ->assertJsonPath('error.details.missing_headers', ['X-App-Id', 'X-App-Version']);
    }

    public function test_gecersiz_app_id_reddedilir(): void
    {
        $this->getJson('/api/health', [
            'X-App-Id' => 'korsan',
            'X-App-Version' => '1.0.0',
        ])->assertStatus(422)->assertJsonPath('error.code', 'VALIDATION_FAILED');
    }

    public function test_saglik_ucu_calisir(): void
    {
        $this->getJson('/api/health', self::HEADERS)
            ->assertOk()
            ->assertJsonPath('status', 'ok')
            ->assertJsonStructure(['status', 'server_time']);
    }

    // ── Katalog ───────────────────────────────────────────────────────────

    public function test_tek_vitrin_doner_ve_sozlesme_alanlarini_tasir(): void
    {
        $this->getJson('/api/locations', self::HEADERS)
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonStructure(['data' => [[
                'id', 'name', 'slug', 'is_open', 'ordering_enabled',
                'order_cutoff', 'min_order_total', 'payment_methods',
            ]]]);
    }

    /**
     * E-06 ile online ödeme AÇILDI; bu test eskiden kapalı olmasını
     * bekliyordu. Arkasında henüz gerçek POS yok, simülasyon geçidi var
     * ve tehlikeli durum `GET /api/health` üzerinden ilan ediliyor.
     */
    public function test_online_odeme_sunuluyor(): void
    {
        $methods = $this->getJson('/api/locations', self::HEADERS)
            ->json('data.0.payment_methods');

        $this->assertContains('cash', $methods);
        $this->assertContains('online', $methods);
        // Cari hesap kaldırıldı; sözleşmede iki yöntem kaldı.
        $this->assertNotContains('account', $methods);
    }

    public function test_include_completed_sorgu_dizesi_bicimlerini_kabul_eder(): void
    {
        // SAHADA YAŞANDI: Laravel'in `boolean` kuralı `"true"` dizgesini
        // REDDEDİYOR (yalnızca 1/0/"1"/"0" kabul eder). Sorgu dizesinde
        // boolean ancak metin olabilir ve OpenAPI serileştirmesi
        // `?include_completed=true` üretir. KDS'in artımlı yoklaması her
        // çağrıda 422 aldı; ekran tam listeye düşüp geri geldi ve bağlantı
        // göstergesi sürekli yanıp söndü.
        foreach (['true', 'false', '1', '0'] as $value) {
            $this->asKitchen()
                ->getJson('/api/kitchen/orders?include_completed='.$value, self::HEADERS)
                ->assertOk();
        }
    }

    public function test_artimli_yoklama_tam_haliyle_calisir(): void
    {
        // KDS'in gerçekte gönderdiği istek: `since` + `include_completed`
        // birlikte. İkisi ayrı ayrı sınanıyordu, birlikte hiç sınanmamıştı.
        $this->asKitchen()->getJson(
            '/api/kitchen/orders?since=2026-08-05T11:06:54.000Z&include_completed=true',
            self::HEADERS,
        )->assertOk();
    }

    public function test_anlamsiz_include_completed_reddedilir(): void
    {
        $this->asKitchen()
            ->getJson('/api/kitchen/orders?include_completed=belki', self::HEADERS)
            ->assertStatus(422);
    }

    // ── Kasa sağlığı ──────────────────────────────────────────────────────

    public function test_saglik_bildirimi_kaydedilir(): void
    {
        $device = $this->pairedDevice();

        $this->withToken($device['token'])->postJson('/api/kitchen/health', [
            'printer_ok' => false,
            'print_queue_pending' => 7,
            'print_queue_failed' => 2,
            'app_version' => '1.2.3',
        ], self::HEADERS)->assertOk();

        $device['model']->refresh();

        $this->assertFalse($device['model']->printer_ok);
        $this->assertSame(7, $device['model']->print_queue_pending);
        $this->assertSame(2, $device['model']->print_queue_failed);
        $this->assertSame('1.2.3', $device['model']->app_version);
        $this->assertNotNull($device['model']->health_reported_at);
    }

    public function test_saglik_yaniti_vitrin_ozetini_doner(): void
    {
        // Cihaz bugünkü sayıyı KENDİ hesaplayamaz: mutfak listesi yalnızca
        // aktif siparişleri taşır, teslim edilenler düşer.
        $this->placeOrder();

        $this->asKitchen()->postJson('/api/kitchen/health', [
            'printer_ok' => true,
            'print_queue_pending' => 0,
            'print_queue_failed' => 0,
        ], self::HEADERS)
            ->assertOk()
            ->assertJsonStructure(['server_time', 'orders_today', 'orders_active'])
            ->assertJsonPath('orders_today', 1)
            ->assertJsonPath('orders_active', 1);
    }

    public function test_iptal_edilen_siparis_bugunku_sayiya_girmez(): void
    {
        $order = $this->placeOrder();
        $this->asCustomer()->postJson('/api/orders/'.$order['id'].'/cancel', [], self::HEADERS);

        $this->asKitchen()->postJson('/api/kitchen/health', [
            'printer_ok' => true,
            'print_queue_pending' => 0,
            'print_queue_failed' => 0,
        ], self::HEADERS)->assertJsonPath('orders_today', 0);
    }

    public function test_saglik_bildirimi_dogrulanir(): void
    {
        $this->asKitchen()
            ->postJson('/api/kitchen/health', ['printer_ok' => true], self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED');
    }

    public function test_musteri_saglik_bildiremez(): void
    {
        $this->asCustomer()->postJson('/api/kitchen/health', [
            'printer_ok' => true,
            'print_queue_pending' => 0,
            'print_queue_failed' => 0,
        ], self::HEADERS)->assertForbidden();
    }

    // ── Satış kontrolü (K-11) ─────────────────────────────────────────────

    public function test_mutfak_siparis_almayi_durdurabilir(): void
    {
        // `docs/03` §3'teki "mutfak cirosu kapatamaz" kuralı kaldırıldı
        // (11.08.2026): sahada mutfak sipariş almaya devam edip gelenleri
        // telefonla iptal ediyordu — müşteri için çok daha kötü.
        $this->asKitchen()->postJson('/api/kitchen/ordering', [
            'enabled' => false,
            'reason' => 'Yoğunluk',
            'minutes' => 30,
        ], self::HEADERS)
            ->assertOk()
            ->assertJsonPath('ordering_enabled', false)
            ->assertJsonPath('reason', 'Yoğunluk');

        // Müşteri artık sipariş veremez.
        $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 1]],
            'delivery_type' => 'pickup',
            'payment_method' => 'cash',
        ], self::HEADERS)->assertStatus(422);
    }

    public function test_durdurma_sebebi_musteriye_gider(): void
    {
        // "Şu anda sipariş alınmıyor" tek başına müşteriyi tekrar tekrar
        // denemeye itiyor; sebep ve saat beklemeyi bilinçli kılıyor.
        $this->asKitchen()->postJson('/api/kitchen/ordering', [
            'enabled' => false,
            'reason' => 'Fırın arızalandı',
            'minutes' => 60,
        ], self::HEADERS)->assertOk();

        $payload = $this->getJson('/api/locations', self::HEADERS)->json('data.0');

        $this->assertFalse($payload['ordering_enabled']);
        $this->assertSame('Fırın arızalandı', $payload['ordering_pause_reason']);
        $this->assertNotNull($payload['ordering_resumes_at']);
    }

    public function test_sure_dolunca_siparis_KENDILIGINDEN_acilir(): void
    {
        // Cron YOK: süre okuma anında değerlendiriliyor. Zamanlayıcıya
        // bağlansaydı, kuyruk durduğunda dükkân kapalı kalırdı.
        $gate = app(LocationGate::class);
        $location = Location::where('location_status', true)->firstOrFail();

        $gate->pauseOrdering($location, now()->subMinute(), 'Yoğunluk');

        $this->assertTrue(
            $gate->orderingEnabled($location),
            'Süresi dolmuş durdurma kendiliğinden kalkmalı.',
        );
        $this->assertNull($gate->pauseReason($location));
    }

    public function test_suresiz_durdurma_kendiliginden_acilmaz(): void
    {
        $gate = app(LocationGate::class);
        $location = Location::where('location_status', true)->firstOrFail();

        $gate->pauseOrdering($location, null, 'Ben açana kadar');

        $this->assertFalse($gate->orderingEnabled($location));
    }

    public function test_tukenen_urun_siparise_eklenemez(): void
    {
        $menuId = $this->menuId('Tavuk Sote');

        $this->asKitchen()->postJson('/api/kitchen/menu-availability', [
            'menu_id' => $menuId,
            'sold_out' => true,
            'reason' => 'Malzeme bitti',
        ], self::HEADERS)->assertOk();

        $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $menuId, 'quantity' => 1]],
            'delivery_type' => 'pickup',
            'payment_method' => 'cash',
        ], self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'ITEM_UNAVAILABLE');
    }

    public function test_tukendi_isareti_menude_gorunur(): void
    {
        $menuId = $this->menuId('Tavuk Sote');

        $this->asKitchen()->postJson('/api/kitchen/menu-availability', [
            'menu_id' => $menuId,
            'sold_out' => true,
        ], self::HEADERS)->assertOk();

        $menu = $this->getJson(
            '/api/locations/'.$this->locationId().'/menu',
            self::HEADERS,
        )->json('data');

        $item = collect($menu)
            ->flatMap(fn(array $category): array => $category['items'])
            ->firstWhere('id', $menuId);

        $this->assertFalse($item['is_available']);
        $this->assertTrue($item['sold_out_today']);
    }

    public function test_tukendi_isareti_KALDIRILABILIR(): void
    {
        $menuId = $this->menuId('Tavuk Sote');
        $availability = app(MenuAvailability::class);

        $availability->markSoldOut($menuId);
        $this->assertTrue($availability->isSoldOut($menuId));

        $this->asKitchen()->postJson('/api/kitchen/menu-availability', [
            'menu_id' => $menuId,
            'sold_out' => false,
        ], self::HEADERS)->assertOk();

        $this->assertFalse($availability->isSoldOut($menuId));
    }

    public function test_ayni_urun_iki_kez_isaretlenince_tek_satir_olur(): void
    {
        $menuId = $this->menuId('Tavuk Sote');
        $availability = app(MenuAvailability::class);

        $availability->markSoldOut($menuId, 'İlk sebep');
        $availability->markSoldOut($menuId, 'İkinci sebep');

        $this->assertSame(
            1,
            DB::table('veykemtu_menu_soldout')->where('menu_id', $menuId)->count(),
        );
        // İlk sebep korunur: `insertOrIgnore` ikinciyi yutar ve "kim ne
        // zaman ne yazdı" izi bulanmaz.
        $this->assertSame('İlk sebep', $availability->reasonFor($menuId));
    }

    public function test_mutfak_urun_listesinde_FIYAT_YOKTUR(): void
    {
        // ADR-08 korunuyor: mutfak kapsamı para görmez.
        $items = $this->asKitchen()
            ->getJson('/api/kitchen/menu-availability', self::HEADERS)
            ->assertOk()
            ->json('data');

        $this->assertNotEmpty($items);
        foreach ($items as $item) {
            $this->assertArrayNotHasKey('price', $item);
            $this->assertArrayHasKey('sold_out', $item);
        }
    }

    public function test_musteri_satis_salterini_ceviremez(): void
    {
        $this->asCustomer()->postJson('/api/kitchen/ordering', [
            'enabled' => false,
        ], self::HEADERS)->assertForbidden();
    }

    // ── Geri alma penceresi (K-10) ────────────────────────────────────────

    public function test_tek_adim_geri_alinabilir(): void
    {
        // Dokunmatik monitörde yanlışlıkla kaydırma gerçek; geri alınamayan
        // bir dokunuş siparişi yanlış sütuna gönderiyor.
        $order = $this->orderInStatus(OrderStatusTransition::PREPARING);

        $this->asKitchen()->postJson(
            "/api/kitchen/orders/{$order->order_id}/status",
            ['status' => OrderStatusTransition::CONFIRMED],
            self::HEADERS,
        )->assertOk()->assertJsonPath('status', OrderStatusTransition::CONFIRMED);
    }

    public function test_iki_adim_geri_alinamaz(): void
    {
        // Geri alma bir kaçış kapısı, serbest gezinme değil. `hazir`dan
        // `onaylandi`ya atlamak, `hazirlaniyor` adımını hiç yaşanmamış
        // gösterir ve üretim süresi ölçümünü bozar.
        $order = $this->orderInStatus(OrderStatusTransition::READY);

        $this->asKitchen()->postJson(
            "/api/kitchen/orders/{$order->order_id}/status",
            ['status' => OrderStatusTransition::CONFIRMED],
            self::HEADERS,
        )->assertStatus(422)->assertJsonPath('error.code', 'INVALID_TRANSITION');
    }

    public function test_pencere_dolunca_geri_alinamaz(): void
    {
        $order = $this->orderInStatus(OrderStatusTransition::PREPARING);

        // Durum değişimini pencerenin dışına taşı.
        $order->forceFill([
            'status_updated_at' => now()->subSeconds(
                OrderStatusTransition::UNDO_WINDOW_SECONDS + 60,
            ),
        ])->saveQuietly();

        $this->asKitchen()->postJson(
            "/api/kitchen/orders/{$order->order_id}/status",
            ['status' => OrderStatusTransition::CONFIRMED],
            self::HEADERS,
        )->assertStatus(422);
    }

    public function test_yeni_durumuna_geri_donulemez(): void
    {
        // Mutfak fişi `onaylandi`da basıldı; `yeni`ye dönmek basılı fişi
        // geçersiz kılardı ve kâğıt geri alınamaz.
        $order = $this->orderInStatus(OrderStatusTransition::CONFIRMED);

        $this->asKitchen()->postJson(
            "/api/kitchen/orders/{$order->order_id}/status",
            ['status' => OrderStatusTransition::NEW],
            self::HEADERS,
        )->assertStatus(422);
    }

    public function test_terminal_durumdan_geri_donulemez(): void
    {
        // İptal cari hesaba ters kayıt yazıyor; geri alması muhasebe
        // düzeltmesi olur ve bu ekranın işi değil.
        $order = $this->orderInStatus(OrderStatusTransition::CANCELLED);

        $this->asKitchen()->postJson(
            "/api/kitchen/orders/{$order->order_id}/status",
            ['status' => OrderStatusTransition::READY],
            self::HEADERS,
        )->assertStatus(422);
    }

    // ── Sunucudan yönetilen kasa ayarları ─────────────────────────────────

    public function test_dokunulmamis_ayarlar_null_doner(): void
    {
        // `null` "yönetici dokunmadı" demek; kasa kendi varsayılanını
        // kullanır. Sunucu varsayılanı dayatsaydı, yanlış bir yazıcı yolu
        // fiş basımını durdururdu.
        $settings = $this->asKitchen()->postJson('/api/kitchen/health', [
            'printer_ok' => true,
            'print_queue_pending' => 0,
            'print_queue_failed' => 0,
        ], self::HEADERS)->json('settings');

        foreach (['poll_seconds', 'sound_enabled', 'printer_device_path',
            'warning_after_minutes', 'late_after_minutes', 'printer_code_page',
            'health_seconds', 'connection_alarm_seconds', 'alarm_silenceable',
            'volume_percent', 'audio_sink', 'tts_enabled', 'tts_rate_percent',
            'alarm_repeat_seconds', 'alarm_max_repeats', 'touch_mode'] as $alan) {
            $this->assertArrayHasKey($alan, $settings);
            $this->assertNull($settings[$alan], "$alan dokunulmamışken null olmalı.");
        }
    }

    public function test_ses_ayarlari_kasaya_gider(): void
    {
        // K-09: sahada "ses çalmıyor" arızası, seviyenin ve çıkışın
        // uzaktan denenememesi yüzünden günlerce sürdü.
        $device = $this->pairedDevice();

        app(KitchenDeviceSettings::class)->update($device['model'], [
            'volume_percent' => 45,
            'audio_sink' => 'alsa_output.analog-stereo',
            'tts_enabled' => true,
            'tts_rate_percent' => 120,
            'alarm_repeat_seconds' => 15,
            'alarm_max_repeats' => 6,
            'touch_mode' => true,
        ]);

        $settings = $this->withToken($device['token'])->postJson('/api/kitchen/health', [
            'printer_ok' => true,
            'print_queue_pending' => 0,
            'print_queue_failed' => 0,
        ], self::HEADERS)->json('settings');

        $this->assertSame(45, $settings['volume_percent']);
        $this->assertSame('alsa_output.analog-stereo', $settings['audio_sink']);
        $this->assertTrue($settings['tts_enabled']);
        $this->assertSame(120, $settings['tts_rate_percent']);
        $this->assertSame(15, $settings['alarm_repeat_seconds']);
        $this->assertSame(6, $settings['alarm_max_repeats']);
        $this->assertTrue($settings['touch_mode']);
    }

    public function test_bos_ses_cikisi_varsayilana_dondurur(): void
    {
        // `null` bu alanda da "dokunulmadı" demek; yöneticinin seçimini
        // geri almasının tek yolu boş dize. Boş dize `null`'a düşseydi
        // seçilen çıkış hiç geri alınamazdı.
        $device = $this->pairedDevice();
        $settings = app(KitchenDeviceSettings::class);

        $settings->update($device['model'], ['audio_sink' => 'hdmi-0']);
        $device['model']->refresh();
        $this->assertSame('hdmi-0', $device['model']->audio_sink);

        $settings->update($device['model'], ['audio_sink' => '']);
        $device['model']->refresh();
        $this->assertSame('', $device['model']->audio_sink);
    }

    public function test_ses_seviyesi_sinir_disina_tasamaz(): void
    {
        $device = $this->pairedDevice();

        app(KitchenDeviceSettings::class)->update($device['model'], [
            'volume_percent' => 900,
            'tts_rate_percent' => 5,
            'alarm_repeat_seconds' => 9999,
        ]);
        $device['model']->refresh();

        $this->assertSame(100, $device['model']->volume_percent);
        $this->assertSame(
            KitchenDeviceSettings::MIN_TTS_RATE_PERCENT,
            $device['model']->tts_rate_percent,
        );
        $this->assertSame(
            KitchenDeviceSettings::MAX_ALARM_REPEAT_SECONDS,
            $device['model']->alarm_repeat_seconds,
        );
    }

    public function test_yoneticinin_yazdigi_ayar_kasaya_gider(): void
    {
        $device = $this->pairedDevice();

        app(KitchenDeviceSettings::class)->update($device['model'], [
            'poll_seconds' => 8,
            'sound_enabled' => false,
            'alarm_silenceable' => false,
        ]);

        $settings = $this->withToken($device['token'])->postJson('/api/kitchen/health', [
            'printer_ok' => true,
            'print_queue_pending' => 0,
            'print_queue_failed' => 0,
        ], self::HEADERS)->json('settings');

        $this->assertSame(8, $settings['poll_seconds']);
        $this->assertFalse($settings['sound_enabled']);
        $this->assertFalse($settings['alarm_silenceable']);
        $this->assertNotNull($settings['updated_at']);
    }

    public function test_sinir_disi_ayar_kirpilir(): void
    {
        $device = $this->pairedDevice();

        app(KitchenDeviceSettings::class)->update($device['model'], [
            'poll_seconds' => 999,
            'printer_code_page' => 9999,
        ]);
        $device['model']->refresh();

        $this->assertSame(KitchenDeviceSettings::MAX_POLL_SECONDS, $device['model']->poll_seconds);
        $this->assertSame(255, $device['model']->printer_code_page);
    }

    public function test_geciken_esigi_uyari_esiginden_kucuk_olamaz(): void
    {
        // Küçük olsaydı kart hiç kırmızıya dönmezdi: uyarı eşiği zaten
        // geçilmiş olur ve geciken siparişler sarı kalırdı.
        $device = $this->pairedDevice();

        app(KitchenDeviceSettings::class)->update($device['model'], [
            'warning_after_minutes' => 20,
            'late_after_minutes' => 5,
        ]);
        $device['model']->refresh();

        $this->assertSame(20, $device['model']->late_after_minutes);
    }

    // ── Komut kanalı ──────────────────────────────────────────────────────

    public function test_komut_saglik_yanitiyla_teslim_edilir(): void
    {
        $device = $this->pairedDevice();
        KitchenCommand::create([
            'device_id' => $device['model']->id,
            'command' => KitchenCommand::TEST_RECEIPT,
        ]);

        $commands = $this->withToken($device['token'])->postJson('/api/kitchen/health', [
            'printer_ok' => true,
            'print_queue_pending' => 0,
            'print_queue_failed' => 0,
        ], self::HEADERS)->json('commands');

        $this->assertCount(1, $commands);
        $this->assertSame(KitchenCommand::TEST_RECEIPT, $commands[0]['command']);
    }

    public function test_teslim_edilen_komut_tekrar_gonderilmez(): void
    {
        // Tekrar gönderilseydi "test fişi bas" her dakika bir kâğıt harcardı.
        $device = $this->pairedDevice();
        KitchenCommand::create([
            'device_id' => $device['model']->id,
            'command' => KitchenCommand::TEST_RECEIPT,
        ]);

        $health = fn(): array => $this->withToken($device['token'])->postJson(
            '/api/kitchen/health',
            ['printer_ok' => true, 'print_queue_pending' => 0, 'print_queue_failed' => 0],
            self::HEADERS,
        )->json('commands');

        $this->assertCount(1, $health());
        $this->assertCount(0, $health());
    }

    public function test_komut_sonucu_kaydedilir(): void
    {
        $device = $this->pairedDevice();
        $command = KitchenCommand::create([
            'device_id' => $device['model']->id,
            'command' => KitchenCommand::REPRINT,
            'payload' => ['order_id' => 42, 'type' => 'mutfak'],
        ]);

        $this->withToken($device['token'])->postJson('/api/kitchen/health', [
            'printer_ok' => true,
            'print_queue_pending' => 0,
            'print_queue_failed' => 0,
            'command_results' => [
                ['id' => $command->id, 'ok' => false, 'message' => 'Sipariş bulunamadı'],
            ],
        ], self::HEADERS)->assertOk();

        $command->refresh();

        $this->assertFalse($command->succeeded);
        $this->assertSame('Sipariş bulunamadı', $command->result);
        $this->assertNotNull($command->executed_at);
    }

    public function test_kasa_baskasinin_komutunu_kapatamaz(): void
    {
        $other = $this->pairedDevice();
        $command = KitchenCommand::create([
            'device_id' => $other['model']->id,
            'command' => KitchenCommand::TEST_RECEIPT,
        ]);

        // Farklı bir cihaz o kimliği bildirse bile satıra dokunulmamalı.
        $this->asKitchen()->postJson('/api/kitchen/health', [
            'printer_ok' => true,
            'print_queue_pending' => 0,
            'print_queue_failed' => 0,
            'command_results' => [['id' => $command->id, 'ok' => true]],
        ], self::HEADERS)->assertOk();

        $this->assertNull($command->refresh()->executed_at);
    }

    // ── Yoğunluk şalteri ──────────────────────────────────────────────────

    public function test_vitrin_varsayilan_olarak_yogun_degildir(): void
    {
        $location = $this->getJson('/api/locations', self::HEADERS)->json('data.0');

        $this->assertFalse($location['busy']);
        $this->assertNotEmpty($location['busy_message']);
    }

    public function test_mutfak_yogunlugu_acar_musteri_gorur(): void
    {
        $this->asKitchen()
            ->postJson('/api/kitchen/busy', ['busy' => true], self::HEADERS)
            ->assertOk()
            ->assertJsonPath('busy', true);

        $this->assertTrue(
            $this->getJson('/api/locations', self::HEADERS)->json('data.0.busy'),
        );
    }

    public function test_yogunkken_siparis_YINE_DE_alinir(): void
    {
        // Bu testin varlık sebebi: yoğunluk bir uyarıdır, kapı değil.
        // Birinin bunu "sipariş almayı durdur" diye yorumlayıp cirosu
        // kesmesini engelliyor. Kapatma şalteri `ordering_enabled`.
        $this->asKitchen()->postJson('/api/kitchen/busy', ['busy' => true], self::HEADERS);

        $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 2]],
            'delivery_type' => 'pickup',
            'payment_method' => 'cash',
        ], self::HEADERS)->assertCreated();
    }

    public function test_musteri_yogunlugu_degistiremez(): void
    {
        $this->asCustomer()
            ->postJson('/api/kitchen/busy', ['busy' => true], self::HEADERS)
            ->assertForbidden();
    }

    public function test_yogunluk_degeri_dogrulanir(): void
    {
        $this->asKitchen()
            ->postJson('/api/kitchen/busy', ['busy' => 'belki'], self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED');
    }

    public function test_menu_uc_kategori_on_iki_urun_doner(): void
    {
        $data = $this->getJson('/api/locations/'.$this->locationId().'/menu', self::HEADERS)
            ->assertOk()
            ->json('data');

        $this->assertCount(3, $data);
        $this->assertSame(12, array_sum(array_map(
            static fn(array $c): int => count($c['items']),
            $data,
        )));
    }

    public function test_gorseli_olmayan_urunun_image_url_alani_null_doner(): void
    {
        // Deneme menüsünde görsel yok. Alanın VAR OLMASI ve `null` olması
        // sözleşme gereği; alanı hiç göndermemek istemcide tip hatası olur.
        $items = collect($this->getJson('/api/locations/'.$this->locationId().'/menu', self::HEADERS)
            ->json('data'))->flatMap(static fn(array $c): array => $c['items']);

        foreach ($items as $item) {
            $this->assertArrayHasKey('image_url', $item);
            $this->assertNull($item['image_url']);
        }
    }

    public function test_tukenmis_urun_listede_kalir_ama_isaretlenir(): void
    {
        $items = collect($this->getJson('/api/locations/'.$this->locationId().'/menu', self::HEADERS)
            ->json('data'))->flatMap(static fn(array $c): array => $c['items']);

        $sold = $items->firstWhere('name', 'Izgara Köfte');

        $this->assertNotNull($sold, 'Tükenmiş ürün listeden düşmemeli (docs/03 §3)');
        $this->assertFalse($sold['is_available']);
    }

    public function test_olmayan_vitrin_404_doner(): void
    {
        $this->getJson('/api/locations/9999/menu', self::HEADERS)
            ->assertNotFound()
            ->assertJsonPath('error.code', 'NOT_FOUND');
    }

    // ── Kimlik ────────────────────────────────────────────────────────────

    public function test_kvkk_onaysiz_kayit_reddedilir(): void
    {
        $this->postJson('/api/auth/register', $this->registerPayload(['kvkk_accepted' => false]), self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED')
            ->assertJsonStructure(['error' => ['details' => ['kvkk_accepted']]]);
    }

    public function test_kayit_ve_giris_token_uretir(): void
    {
        $this->postJson('/api/auth/register', $this->registerPayload(), self::HEADERS)
            ->assertCreated()
            ->assertJsonStructure(['token', 'customer' => ['id', 'first_name']]);

        $this->postJson('/api/auth/login', [
            'email' => 'test@ornek.com',
            'password' => 'parola123',
        ], self::HEADERS)->assertOk()->assertJsonStructure(['token']);
    }

    public function test_yanlis_sifre_kullanici_varligini_sizdirmaz(): void
    {
        $this->postJson('/api/auth/register', $this->registerPayload(), self::HEADERS);

        $varOlan = $this->postJson('/api/auth/login', [
            'email' => 'test@ornek.com', 'password' => 'yanlis',
        ], self::HEADERS);

        $olmayan = $this->postJson('/api/auth/login', [
            'email' => 'yok@ornek.com', 'password' => 'yanlis',
        ], self::HEADERS);

        // İki yanıt ayırt edilemez olmalı: aksi halde hangi e-postaların
        // kayıtlı olduğu numaralandırılabilir.
        $this->assertSame($varOlan->json('error'), $olmayan->json('error'));
    }

    public function test_me_sozlesme_alanlarini_doner_ve_group_icermez(): void
    {
        $json = $this->asCustomer()->getJson('/api/auth/me', self::HEADERS)
            ->assertOk()
            ->json();

        $this->assertSame(
            [
                'id', 'first_name', 'last_name', 'email', 'telephone',
                'default_location_id', 'account_type', 'can_order',
                'company_name', 'contact_person',
            ],
            array_keys($json),
        );
        // `group` alanı öğrenci kanalıyla birlikte kaldırıldı (docs/00 §4).
        $this->assertArrayNotHasKey('group', $json);
    }

    // ── Profil ve parola ──────────────────────────────────────────────────

    public function test_profil_guncellenir(): void
    {
        $this->asCustomer()->patchJson('/api/auth/me', [
            'first_name' => 'Yeni',
            'telephone' => '5559998877',
        ], self::HEADERS)
            ->assertOk()
            ->assertJsonPath('first_name', 'Yeni')
            ->assertJsonPath('telephone', '5559998877');
    }

    public function test_eposta_degistirilemez(): void
    {
        // E-posta giriş kimliği. Değiştirmek yeni adrese onay bağlantısı
        // ister; o olmadan hesabı başkasının e-postasına taşımanın yolu
        // olurdu. Sessizce yok sayılıyor.
        $before = $this->asCustomer()->getJson('/api/auth/me', self::HEADERS)->json('email');

        $this->asCustomer()
            ->patchJson('/api/auth/me', ['email' => 'kacak@ornek.com'], self::HEADERS)
            ->assertOk()
            ->assertJsonPath('email', $before);
    }

    public function test_yanlis_mevcut_parolayla_degistirilemez(): void
    {
        // Token'ı çalınmış bir oturumun hesabı tamamen ele geçirmesini
        // engelleyen tek kontrol bu.
        $this->asCustomer()->postJson('/api/auth/password', [
            'current_password' => 'yanlis',
            'password' => 'yeniparola9',
        ], self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED');
    }

    public function test_parola_degisince_eski_tokenlar_olur(): void
    {
        $token = $this->postJson('/api/auth/register', $this->registerPayload([
            'email' => 'parola@ornek.com',
            'telephone' => '5551112233',
        ]), self::HEADERS)->json('token');

        $this->withToken($token)->postJson('/api/auth/password', [
            'current_password' => 'parola123',
            'password' => 'yeniparola9',
        ], self::HEADERS)->assertOk()->assertJsonStructure(['token']);

        // Parola değiştirmenin amacı "başkası giremesin"dir; eski
        // oturumları açık bırakmak o amacı boşa çıkarır.
        $this->withToken($token)->getJson('/api/auth/me', self::HEADERS)
            ->assertUnauthorized();
    }

    public function test_yeni_parolayla_giris_yapilir(): void
    {
        $token = $this->postJson('/api/auth/register', $this->registerPayload([
            'email' => 'parola2@ornek.com',
            'telephone' => '5551112244',
        ]), self::HEADERS)->json('token');

        $this->withToken($token)->postJson('/api/auth/password', [
            'current_password' => 'parola123',
            'password' => 'yeniparola9',
        ], self::HEADERS);

        $this->postJson('/api/auth/login', [
            'email' => 'parola2@ornek.com',
            'password' => 'yeniparola9',
        ], self::HEADERS)->assertOk();
    }

    // ── Adres defteri ─────────────────────────────────────────────────────

    public function test_adres_defteri_bos_baslar(): void
    {
        $this->asCustomer()->getJson('/api/addresses', self::HEADERS)
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    public function test_ilk_adres_kendiliginden_varsayilan_olur(): void
    {
        // Tek adresi olan müşteriye ayrıca "varsayılan yap" dedirtmek
        // anlamsız; ödeme ekranı seçili bir adres bulamazdı.
        $this->asCustomer()
            ->postJson('/api/addresses', $this->addressPayload(), self::HEADERS)
            ->assertCreated()
            ->assertJsonPath('is_default', true)
            ->assertJsonPath('label', 'Ofis');
    }

    public function test_varsayilan_tek_olur(): void
    {
        $first = $this->asCustomer()
            ->postJson('/api/addresses', $this->addressPayload(), self::HEADERS)
            ->json('id');

        $second = $this->asCustomer()->postJson('/api/addresses', $this->addressPayload([
            'label' => 'Ev',
            'is_default' => true,
        ]), self::HEADERS)->json('id');

        $byId = collect($this->asCustomer()->getJson('/api/addresses', self::HEADERS)->json('data'))
            ->keyBy('id');

        $this->assertTrue($byId[$second]['is_default']);
        $this->assertFalse($byId[$first]['is_default'], 'İki adres birden varsayılan kalamaz.');
    }

    public function test_baskasinin_adresi_404_doner(): void
    {
        $id = $this->asCustomer()
            ->postJson('/api/addresses', $this->addressPayload(), self::HEADERS)
            ->json('id');

        // 403 dönmek o kimliğin var olduğunu doğrular ve numara taramaya
        // davet eder — sipariş uçlarıyla aynı kural (docs/03 §5).
        $this->withToken($this->otherCustomerToken())
            ->patchJson('/api/addresses/'.$id, $this->addressPayload(), self::HEADERS)
            ->assertNotFound();
    }

    public function test_tokensiz_adres_listesi_401(): void
    {
        $this->getJson('/api/addresses', self::HEADERS)->assertUnauthorized();
    }

    public function test_defter_degisince_gecmis_siparisin_adresi_DEGISMEZ(): void
    {
        // Bu testin varlık sebebi: siparişi kayıtlı adrese BAĞLAMAK
        // cazip ve yanlış. Bağlansaydı müşteri adresini düzelttiğinde
        // teslim edilmiş siparişlerin nereye gittiği de değişirdi.
        $this->asCustomer()->postJson('/api/addresses', $this->addressPayload(), self::HEADERS);

        $order = $this->placeOrder();
        $before = $this->asCustomer()
            ->getJson('/api/orders/'.$order['id'], self::HEADERS)
            ->json('address.line1');

        $id = $this->asCustomer()->getJson('/api/addresses', self::HEADERS)->json('data.0.id');
        $this->asCustomer()->patchJson('/api/addresses/'.$id, $this->addressPayload([
            'line1' => 'Bambaşka Sokak No:99',
        ]), self::HEADERS)->assertOk();

        $this->assertSame(
            $before,
            $this->asCustomer()->getJson('/api/orders/'.$order['id'], self::HEADERS)->json('address.line1'),
        );
    }

    public function test_siparis_adresleri_deftere_sizmaz(): void
    {
        // Her sipariş kendi adres satırını açar. Bunlar deftere karışsaydı
        // kırk sipariş veren müşteri kırk satır görürdü.
        $this->placeOrder();
        $this->placeOrder();

        $this->asCustomer()->getJson('/api/addresses', self::HEADERS)
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    public function test_varsayilan_silinince_bosta_kalmaz(): void
    {
        $first = $this->asCustomer()
            ->postJson('/api/addresses', $this->addressPayload(), self::HEADERS)
            ->json('id');
        $this->asCustomer()->postJson('/api/addresses', $this->addressPayload(['label' => 'Ev']), self::HEADERS);

        $this->asCustomer()->deleteJson('/api/addresses/'.$first, [], self::HEADERS)
            ->assertNoContent();

        $rest = $this->asCustomer()->getJson('/api/addresses', self::HEADERS)->json('data');

        $this->assertCount(1, $rest);
        $this->assertTrue($rest[0]['is_default'], 'Varsayılan silinince biri devralmalı.');
    }

    public function test_adres_dogrulanir(): void
    {
        $this->asCustomer()
            ->postJson('/api/addresses', ['label' => 'Eksik'], self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED');
    }

    // ── Kapsam ayrımı (docs/10 S5) ────────────────────────────────────────

    public function test_tokensiz_istek_401_doner(): void
    {
        $this->getJson('/api/orders', self::HEADERS)
            ->assertUnauthorized()
            ->assertJsonPath('error.code', 'UNAUTHENTICATED');
    }

    public function test_musteri_tokeni_mutfak_uclarina_giremez(): void
    {
        $this->asCustomer()->getJson('/api/kitchen/orders', self::HEADERS)
            ->assertForbidden()
            ->assertJsonPath('error.code', 'FORBIDDEN');
    }

    public function test_mutfak_tokeni_musteri_uclarina_giremez(): void
    {
        $this->asKitchen()->getJson('/api/orders', self::HEADERS)
            ->assertForbidden()
            ->assertJsonPath('error.code', 'FORBIDDEN');
    }

    public function test_iptal_edilmis_cihaz_device_revoked_doner(): void
    {
        $device = $this->pairedDevice();
        $token = $device['token'];
        $device['model']->revoke();

        // Sözleşme (`docs/openapi.yaml`) bu durumda `403 DEVICE_REVOKED`
        // der ve KDS tam olarak bu kodu görünce eşleme ekranına döner
        // (docs/05 §7 adım 5). `UNAUTHENTICATED` beklemek testi kendi
        // sözleşmesiyle çelişik hâle getiriyordu.
        $this->withToken($token)->getJson('/api/kitchen/orders', self::HEADERS)
            ->assertForbidden()
            ->assertJsonPath('error.code', 'DEVICE_REVOKED');
    }

    public function test_baskasinin_siparisi_404_doner_403_degil(): void
    {
        $order = $this->placeOrder();

        // İkinci müşteri
        $this->postJson('/api/auth/register', $this->registerPayload([
            'email' => 'baskasi@ornek.com',
        ]), self::HEADERS);
        $token = $this->postJson('/api/auth/login', [
            'email' => 'baskasi@ornek.com', 'password' => 'parola123',
        ], self::HEADERS)->json('token');

        $this->withToken($token)->getJson('/api/orders/'.$order['id'], self::HEADERS)
            ->assertNotFound()
            ->assertJsonPath('error.code', 'NOT_FOUND');
    }

    // ── Sipariş oluşturma ─────────────────────────────────────────────────

    public function test_tutar_sunucuda_hesaplanir(): void
    {
        $order = $this->placeOrder(quantity: 2);

        // Ara toplam yalnızca DETAY yanıtında var: `POST /orders`
        // sözleşmede `OrderCreated` döner ve o şema kalem dökümü
        // taşımaz (docs/openapi.yaml).
        $detay = $this->asCustomer()
            ->getJson('/api/orders/'.$order['id'], self::HEADERS)
            ->assertOk()->json();

        // Tavuk Sote 18500 × 2 = 37000 ara toplam.
        // Toplam ara toplam DEĞİLDİR: adrese gönderimde teslimat ücreti
        // eklenir. Sabit 37000 beklemek, teslimat ücreti eklendiğinde
        // testi kırdı; doğru kural toplamın parçalarından türemesidir.
        $this->assertSame(37000, $detay['subtotal']);
        $this->assertSame(
            $detay['subtotal'] + $detay['delivery_fee'],
            $detay['total'],
        );
    }

    public function test_istemcinin_gonderdigi_tutar_yok_sayilir(): void
    {
        $response = $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 2]],
            'delivery_type' => 'pickup',
            'payment_method' => 'cash',
            'total' => 1, // uydurma
            'subtotal' => 1,
        ], self::HEADERS)->assertCreated();

        $this->assertSame(37000, $response->json('total'));
    }

    public function test_tukenmis_urun_siparise_eklenemez(): void
    {
        $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->menuId('Izgara Köfte'), 'quantity' => 2]],
            'delivery_type' => 'pickup',
            'payment_method' => 'cash',
        ], self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'ITEM_UNAVAILABLE');
    }

    /**
     * Vitrinin sunmadığı bir yöntem reddedilmelidir. Örnek olarak
     * `online` kullanılamaz — E-06 ile açıldı; sözleşmede hiç olmayan bir
     * değer seçiyoruz ki test, açılan/kapanan yöntemlere göre bayatlamasın.
     */
    public function test_tanimsiz_odeme_yontemi_reddedilir(): void
    {
        $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 2]],
            'delivery_type' => 'pickup',
            'payment_method' => 'kripto',
        ], self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED');
    }

    public function test_adressiz_adrese_gonderim_reddedilir(): void
    {
        $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 2]],
            'delivery_type' => 'delivery',
            'payment_method' => 'cash',
        ], self::HEADERS)->assertStatus(422);
    }

    public function test_asgari_tutar_altinda_siparis_reddedilir(): void
    {
        $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->menuId('Ayran'), 'quantity' => 1]], // 3000 < 25000
            'delivery_type' => 'pickup',
            'payment_method' => 'cash',
        ], self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED');
    }

    public function test_siparis_yanitinda_kanal_alanlari_yok(): void
    {
        $order = $this->placeOrder();

        $this->assertArrayNotHasKey('channel', $order);
        $this->assertArrayNotHasKey('pickup_code', $order);
    }

    public function test_gel_al_siparisinde_teslimat_ucreti_yok(): void
    {
        $order = $this->placeOrder(deliveryType: 'pickup');

        $detail = $this->asCustomer()->getJson('/api/orders/'.$order['id'], self::HEADERS)->json();

        $this->assertSame(0, $detail['delivery_fee']);
        $this->assertNull($detail['address']);
        $this->assertSame('pickup', $detail['delivery_type']);
    }

    // ── Durum geçişleri (docs/10 S6) ──────────────────────────────────────

    public function test_adim_atlamak_reddedilir(): void
    {
        $order = $this->placeOrder();

        $this->asKitchen()->postJson(
            '/api/kitchen/orders/'.$order['id'].'/status',
            ['status' => OrderStatusTransition::READY],
            self::HEADERS,
        )
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'INVALID_TRANSITION')
            ->assertJsonPath('error.details.from', 'yeni')
            ->assertJsonPath('error.details.to', 'hazir');
    }

    public function test_gel_al_siparisi_yola_cikarilamaz(): void
    {
        $order = $this->placeOrder(deliveryType: 'pickup');
        $this->advance($order['id'], ['onaylandi', 'hazirlaniyor', 'hazir']);

        $this->asKitchen()->postJson(
            '/api/kitchen/orders/'.$order['id'].'/status',
            ['status' => OrderStatusTransition::ON_THE_WAY],
            self::HEADERS,
        )->assertStatus(422)->assertJsonPath('error.code', 'INVALID_TRANSITION');
    }

    public function test_adrese_gonderim_kurye_adimini_atlayamaz(): void
    {
        $order = $this->placeOrder(deliveryType: 'delivery');
        $this->advance($order['id'], ['onaylandi', 'hazirlaniyor', 'hazir']);

        $this->asKitchen()->postJson(
            '/api/kitchen/orders/'.$order['id'].'/status',
            ['status' => OrderStatusTransition::DELIVERED],
            self::HEADERS,
        )->assertStatus(422)->assertJsonPath('error.code', 'INVALID_TRANSITION');
    }

    public function test_terminal_durumdan_cikilamaz(): void
    {
        $order = $this->placeOrder(deliveryType: 'pickup');
        $this->advance($order['id'], ['onaylandi', 'hazirlaniyor', 'hazir', 'teslim_edildi']);

        $this->asKitchen()->postJson(
            '/api/kitchen/orders/'.$order['id'].'/status',
            ['status' => OrderStatusTransition::CANCELLED],
            self::HEADERS,
        )->assertStatus(422)->assertJsonPath('error.code', 'INVALID_TRANSITION');
    }

    public function test_musteri_hazirlanan_siparisi_iptal_edemez(): void
    {
        $order = $this->placeOrder();
        $this->advance($order['id'], ['onaylandi', 'hazirlaniyor']);

        $this->asCustomer()->postJson('/api/orders/'.$order['id'].'/cancel', [], self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'INVALID_TRANSITION');
    }

    public function test_musteri_yeni_siparisi_iptal_edebilir(): void
    {
        $order = $this->placeOrder();

        $this->asCustomer()->postJson('/api/orders/'.$order['id'].'/cancel', [], self::HEADERS)
            ->assertOk()
            ->assertJsonPath('status', 'iptal');
    }

    // ── Mutfak ────────────────────────────────────────────────────────────

    public function test_mutfak_listesi_fiyat_ve_adres_icermez(): void
    {
        $this->placeOrder();

        $data = $this->asKitchen()->getJson('/api/kitchen/orders', self::HEADERS)
            ->assertOk()
            ->json('data');

        foreach ($data as $order) {
            $this->assertArrayNotHasKey('total', $order);
            $this->assertArrayNotHasKey('address', $order);
            $this->assertArrayNotHasKey('telephone', $order);
            foreach ($order['items'] as $item) {
                $this->assertArrayNotHasKey('unit_price', $item);
            }
        }
    }

    public function test_customer_label_yalnizca_bas_harf_icerir(): void
    {
        $this->placeOrder();

        $label = $this->asKitchen()->getJson('/api/kitchen/orders', self::HEADERS)
            ->json('data.0.customer_label');

        $this->assertSame('Test M.', $label);
    }

    public function test_tamamlanan_siparis_mutfak_listesinde_gorunmez(): void
    {
        $order = $this->placeOrder(deliveryType: 'pickup');
        $this->advance($order['id'], ['onaylandi', 'hazirlaniyor', 'hazir', 'teslim_edildi']);

        $ids = array_column(
            $this->asKitchen()->getJson('/api/kitchen/orders', self::HEADERS)->json('data'),
            'id',
        );

        $this->assertNotContains($order['id'], $ids);
    }

    public function test_artimli_cekme_since_ile_bos_doner(): void
    {
        $this->placeOrder();

        $first = $this->asKitchen()->getJson('/api/kitchen/orders', self::HEADERS)->json();
        $this->assertCount(1, $first['data']);

        $second = $this->asKitchen()
            ->getJson('/api/kitchen/orders?since='.urlencode($first['server_time']), self::HEADERS)
            ->json();

        $this->assertCount(0, $second['data'], 'Değişiklik yokken since boş dönmeli');
        $this->assertSame($first['max_id'], $second['max_id'], 'max_id geriye kaymamalı');
    }

    public function test_mutfak_fisi_fiyat_icermez_musteri_fisi_icerir(): void
    {
        $order = $this->placeOrder();

        $mutfak = $this->asKitchen()
            ->getJson('/api/kitchen/orders/'.$order['id'].'/receipt?type=mutfak', self::HEADERS)
            ->assertOk()->json();
        $this->assertArrayNotHasKey('total', $mutfak);
        $this->assertSame('mutfak', $mutfak['type']);

        $musteri = $this->asKitchen()
            ->getJson('/api/kitchen/orders/'.$order['id'].'/receipt?type=musteri', self::HEADERS)
            ->assertOk()->json();
        $this->assertSame($order['total'], $musteri['total']);
    }

    /**
     * Müşteri fişindeki QR bağlantıları — K-18 / K-19.
     *
     * Bağlantıları SUNUCU üretiyor: KDS ne site adresini ne de siparişin
     * ödeme hash'ini biliyor, bilmesi de gerekmiyor.
     */
    public function test_musteri_fisi_takip_ve_odeme_baglantisi_tasir(): void
    {
        config(['app.frontend_url' => 'https://ornek.test']);

        $order = $this->placeOrder();

        $musteri = $this->asKitchen()
            ->getJson('/api/kitchen/orders/'.$order['id'].'/receipt?type=musteri', self::HEADERS)
            ->assertOk()->json();

        /*
         * ADRES `/takip/` — `/siparis/` DEĞİL (K-20).
         *
         * Eski bağlantı `/siparis/{id}` idi ve o sayfa oturum istiyor:
         * fişteki kareyi okutan müşteri sipariş durumunu değil GİRİŞ
         * EKRANINI görüyordu. Kâğıda basılan bir QR giriş isteyemez.
         */
        $this->assertStringStartsWith(
            'https://ornek.test/takip/'.$order['id'].'?',
            $musteri['track_url'],
        );

        // İmza ve son geçerlilik URL'de olmalı; ikisi de yetkinin kendisi.
        parse_str((string) parse_url($musteri['track_url'], PHP_URL_QUERY), $query);
        $this->assertArrayHasKey('e', $query);
        $this->assertArrayHasKey('s', $query);
        $this->assertNotSame('', $query['s']);
        $this->assertGreaterThan(time(), (int) $query['e']);

        // Sipariş ödenmemiş (kapıda ödeme) — ödeme QR'ı basılmalı ve
        // dönüşte müşteriyi kendi takip sayfasına götürmeli.
        $this->assertNotNull($musteri['pay_url']);
        $this->assertStringContainsString('/odeme-simulasyon/', $musteri['pay_url']);
        $this->assertStringContainsString(
            rawurlencode($musteri['track_url']),
            $musteri['pay_url'],
        );
    }

    /**
     * Müşteri fişi K-20'den beri KURYENİN DE FİŞİ.
     *
     * Ayrı kurye fişi otomatik basılmıyor; kuryenin üç sorusunun cevabı
     * (kime, nereye, ne kadar tahsil edilecek) bu fişte olmak zorunda.
     * Eksik kalsaydı kurye kapıda adresi ya da tutarı bilmeden dururdu.
     */
    public function test_musteri_fisi_kurye_alanlarini_tasir(): void
    {
        $order = $this->placeOrder();

        $musteri = $this->asKitchen()
            ->getJson('/api/kitchen/orders/'.$order['id'].'/receipt?type=musteri', self::HEADERS)
            ->assertOk()->json();

        $this->assertNotNull($musteri['customer_phone'], 'kurye kapıda arayacak');
        $this->assertNotNull($musteri['address'], 'kurye nereye gideceğini bilmeli');
        $this->assertArrayHasKey('customer_name', $musteri);
        $this->assertArrayHasKey('deliver_url', $musteri);

        // Ödenmemiş sipariş: tamamı kapıda tahsil edilecek.
        $this->assertSame($musteri['total'], $musteri['collect_amount']);
    }

    /** Ödenmiş siparişte tahsilat sıfır — kurye kapıda para istemez. */
    public function test_odenmis_siparisin_musteri_fisinde_tahsilat_sifirdir(): void
    {
        $order = $this->placeOrder();

        \Igniter\Cart\Models\Order::where('order_id', $order['id'])
            ->update(['processed' => 1]);

        $musteri = $this->asKitchen()
            ->getJson('/api/kitchen/orders/'.$order['id'].'/receipt?type=musteri', self::HEADERS)
            ->assertOk()->json();

        $this->assertSame(0, $musteri['collect_amount']);
    }

    /**
     * Gel-al fişinde kurye bloğu YOK.
     *
     * Kurye yok; ad, telefon, tahsilat satırı ve teslim QR'ı basmak
     * personeli olmayan bir teslimatı aramaya iterdi.
     */
    public function test_gel_al_fisinde_kurye_bilgisi_ve_teslim_baglantisi_yoktur(): void
    {
        $order = $this->placeOrder(deliveryType: 'pickup');

        $musteri = $this->asKitchen()
            ->getJson('/api/kitchen/orders/'.$order['id'].'/receipt?type=musteri', self::HEADERS)
            ->assertOk()->json();

        $this->assertNull($musteri['address']);
        $this->assertNull($musteri['customer_name']);
        $this->assertNull($musteri['customer_phone']);
        $this->assertNull($musteri['deliver_url']);
        $this->assertSame(0, $musteri['collect_amount']);
    }

    /**
     * Simülasyon kapalıyken ödeme QR'ı basılmaz.
     *
     * `Veykemtu\Payment\Extension` simülasyon rotalarını
     * `SimulatedPos::isAllowed()` yanlışken HİÇ kaydetmiyor; bu kontrol
     * olmadan üretimde ölü bir adrese giden kare basılıyordu.
     */
    public function test_simulasyon_kapaliysa_odeme_baglantisi_null_doner(): void
    {
        config(['app.frontend_url' => 'https://ornek.test', 'app.env' => 'production']);
        putenv('POS_ALLOW_SIMULATION');
        unset($_ENV['POS_ALLOW_SIMULATION'], $_SERVER['POS_ALLOW_SIMULATION']);

        $order = $this->placeOrder();

        $musteri = $this->asKitchen()
            ->getJson('/api/kitchen/orders/'.$order['id'].'/receipt?type=musteri', self::HEADERS)
            ->assertOk()->json();

        $this->assertNull($musteri['pay_url']);
        $this->assertNotNull($musteri['track_url'], 'takip QR\'ı simülasyona bağlı değil');
    }

    /**
     * Mutfak fişi revizyon bandını taşır — `docs/10` S9-13.
     *
     * K-20'ye kadar `revision_no` mutfak fişine HİÇ gitmiyordu: düzenlenen
     * sipariş için yeni kâğıt çıkıyor ama üstünde onu öncekinden ayıran
     * hiçbir şey yazmıyordu.
     */
    public function test_mutfak_fisi_revizyon_bilgisini_tasir(): void
    {
        $order = $this->placeOrder();
        $this->advance((int) $order['id'], ['onaylandi']);

        $this->asKitchen()->postJson(
            '/api/kitchen/orders/'.$order['id'].'/revisions',
            [
                'reason' => 'Müşteri talebi',
                'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 1]],
            ],
            self::HEADERS,
        )->assertOk();

        $mutfak = $this->asKitchen()
            ->getJson('/api/kitchen/orders/'.$order['id'].'/receipt?type=mutfak', self::HEADERS)
            ->assertOk()->json();

        $this->assertSame(1, $mutfak['revision_no']);
        $this->assertNotEmpty($mutfak['revision_summary']);
    }

    /**
     * Revizyon sonrası fiş, ESKİ basımın saatiyle damgalanmamalı.
     *
     * K-20 öncesi `PrintJob` tekilliği `(order_id, type)` idi; revizyon
     * ack'i sessizce yutuluyor ve `printed_at` hep ilk basımı gösteriyordu.
     * Elinde iki kâğıt olan kurye hangisinin yeni olduğunu anlayamıyordu.
     */
    public function test_revizyon_yeni_bir_basim_kaydi_acar(): void
    {
        $order = $this->placeOrder();
        $this->advance((int) $order['id'], ['onaylandi']);

        $this->asKitchen()->postJson(
            '/api/kitchen/print-jobs/'.$order['id'].'/ack',
            ['type' => 'mutfak', 'printed_at' => '2026-08-14T09:00:00Z', 'revision' => 0],
            self::HEADERS,
        )->assertNoContent();

        $this->asKitchen()->postJson(
            '/api/kitchen/orders/'.$order['id'].'/revisions',
            [
                'reason' => 'Müşteri talebi',
                'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 1]],
            ],
            self::HEADERS,
        )->assertOk();

        $mutfak = $this->asKitchen()
            ->getJson('/api/kitchen/orders/'.$order['id'].'/receipt?type=mutfak', self::HEADERS)
            ->assertOk()->json();

        $this->assertNull(
            $mutfak['printed_at'],
            'yeni revizyon henüz basılmadı; eski basımın saati taşınmamalı',
        );
    }

    /** `revision` göndermeyen eski KDS sürümü çalışmaya devam eder. */
    public function test_ack_revizyonsuz_gonderilebilir(): void
    {
        $order = $this->placeOrder();
        $this->advance((int) $order['id'], ['onaylandi']);

        $this->asKitchen()->postJson(
            '/api/kitchen/print-jobs/'.$order['id'].'/ack',
            ['type' => 'mutfak', 'printed_at' => '2026-08-14T09:00:00Z'],
            self::HEADERS,
        )->assertNoContent();

        $mutfak = $this->asKitchen()
            ->getJson('/api/kitchen/orders/'.$order['id'].'/receipt?type=mutfak', self::HEADERS)
            ->assertOk()->json();

        $this->assertNotNull($mutfak['printed_at']);
    }

    /**
     * `FRONTEND_URL` tanımsızsa QR bağlantısı YOK.
     *
     * Çalışmayan bir kare basmak, okutup boş sayfa gören müşteri
     * üretmekten iyi değil — üstelik kâğıt harcıyor. KDS `null` görünce
     * QR'ı hiç çizmiyor.
     */
    public function test_site_adresi_tanimsizsa_takip_baglantisi_null_doner(): void
    {
        config(['app.frontend_url' => '']);

        $order = $this->placeOrder();

        $musteri = $this->asKitchen()
            ->getJson('/api/kitchen/orders/'.$order['id'].'/receipt?type=musteri', self::HEADERS)
            ->assertOk()->json();

        $this->assertNull($musteri['track_url']);
    }

    /**
     * Ödenmiş siparişin fişine ödeme QR'ı BASILMAZ — ikinci kez ödemeye
     * davet etmek olurdu.
     */
    public function test_odenmis_siparisin_fisinde_odeme_baglantisi_yoktur(): void
    {
        config(['app.frontend_url' => 'https://ornek.test']);

        $order = $this->placeOrder();

        \Igniter\Cart\Models\Order::where('order_id', $order['id'])
            ->update(['processed' => 1]);

        $musteri = $this->asKitchen()
            ->getJson('/api/kitchen/orders/'.$order['id'].'/receipt?type=musteri', self::HEADERS)
            ->assertOk()->json();

        $this->assertNull($musteri['pay_url']);
        $this->assertNotNull($musteri['track_url'], 'takip QR\'ı kalmalı');
    }

    public function test_mutfak_fisi_musteri_telefonunu_tasir(): void
    {
        // Kurye kapıda kaldığında arayacağı numara fişte olmalı.
        //
        // KURAL DEĞİŞTİ (12.08.2026, K-14): telefon artık KDS KARTINDA da
        // görünüyor. Eski kural "ekran gün boyu açık duruyor" gerekçesiyle
        // gizliyordu; ama mutfak siparişi düzenlemeden önce müşteriyi
        // ARAMAK zorunda ve numarayı fişten okumak için fiş basmak
        // gerekiyordu. Fiyat ve adres hâlâ gizli — `docs/03` §5.
        $order = $this->placeOrder();

        $mutfak = $this->asKitchen()
            ->getJson('/api/kitchen/orders/'.$order['id'].'/receipt?type=mutfak', self::HEADERS)
            ->assertOk()->json();

        $this->assertArrayHasKey('customer_phone', $mutfak);
        $this->assertSame('5551234567', $mutfak['customer_phone']);

        $kart = $this->asKitchen()
            ->getJson('/api/kitchen/orders', self::HEADERS)
            ->assertOk()->json('data.0');

        $this->assertSame('5551234567', $kart['customer_phone']);

        // Gizlilik daralması TELEFONLA SINIRLI: fiyat ve adres panoda
        // hâlâ yok (ADR-08).
        $this->assertArrayNotHasKey('total', $kart);
        $this->assertArrayNotHasKey('address', $kart);
    }

    public function test_teslim_fisi_tipi_kaldirildi(): void
    {
        $order = $this->placeOrder();

        $this->asKitchen()
            ->getJson('/api/kitchen/orders/'.$order['id'].'/receipt?type=teslim', self::HEADERS)
            ->assertStatus(422);
    }

    public function test_fis_ack_idempotenttir(): void
    {
        $order = $this->placeOrder();
        $body = ['type' => 'mutfak', 'printed_at' => '2026-08-04T11:30:07Z'];

        $this->asKitchen()->postJson('/api/kitchen/print-jobs/'.$order['id'].'/ack', $body, self::HEADERS)
            ->assertNoContent();

        $this->asKitchen()->postJson('/api/kitchen/print-jobs/'.$order['id'].'/ack', [
            'type' => 'mutfak', 'printed_at' => '2026-08-04T12:00:00Z',
        ], self::HEADERS)->assertNoContent();

        $this->assertSame(
            1,
            PrintJob::where('order_id', $order['id'])->where('type', 'mutfak')->count(),
            'Aynı fiş iki kez kaydedilmemeli (docs/10 S4)',
        );
    }

    public function test_uretim_listesi_aktif_siparisleri_toplar(): void
    {
        $order = $this->placeOrder(quantity: 3);
        $this->advance($order['id'], ['onaylandi']);

        $data = $this->asKitchen()->getJson('/api/kitchen/production-list', self::HEADERS)
            ->assertOk()->json('data');

        $this->assertSame('Tavuk Sote', $data[0]['name']);
        $this->assertSame(3, $data[0]['total']);
    }

    public function test_heartbeat_min_surum_doner(): void
    {
        $this->asKitchen()->getJson('/api/kitchen/heartbeat', self::HEADERS)
            ->assertOk()
            ->assertJsonStructure(['server_time', 'min_supported_version']);
    }

    public function test_gecersiz_eslesme_kodu_404_doner(): void
    {
        $this->postJson('/api/kitchen/pair', [
            'pairing_code' => 'AAAA-BBBB',
            'device_name' => 'Sahte',
        ], self::HEADERS)->assertNotFound()->assertJsonPath('error.code', 'NOT_FOUND');
    }

    // ── Sürüm ─────────────────────────────────────────────────────────────

    public function test_surum_ucu_bilinmeyen_uygulamayi_reddeder(): void
    {
        $this->getJson('/api/app-version?app_id=korsan', self::HEADERS)->assertStatus(422);
    }

    public function test_surum_ucu_calisir(): void
    {
        $this->getJson('/api/app-version?app_id=mutfakapp', self::HEADERS)
            ->assertOk()
            ->assertJsonStructure(['app_id', 'latest', 'min_supported']);
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    /** @return array<string, mixed> */
    private function registerPayload(array $overrides = []): array
    {
        return array_merge([
            'first_name' => 'Test',
            'last_name' => 'Müşteri',
            'email' => 'test@ornek.com',
            'telephone' => '5551234567',
            'password' => 'parola123',
            'kvkk_accepted' => true,
        ], $overrides);
    }

    private function locationId(): int
    {
        return (int) $this->getJson('/api/locations', self::HEADERS)->json('data.0.id');
    }

    private function menuId(string $name): int
    {
        $items = collect($this->getJson('/api/locations/'.$this->locationId().'/menu', self::HEADERS)
            ->json('data'))->flatMap(static fn(array $c): array => $c['items']);

        return (int) $items->firstWhere('name', $name)['id'];
    }

    private function asCustomer(): static
    {
        if (ApiCustomer::where('email', 'test@ornek.com')->doesntExist()) {
            $this->postJson('/api/auth/register', $this->registerPayload(), self::HEADERS);
        }

        $token = $this->postJson('/api/auth/login', [
            'email' => 'test@ornek.com', 'password' => 'parola123',
        ], self::HEADERS)->json('token');

        return $this->withToken($token);
    }

    /** @return array{token:string, model:KitchenDevice} */
    private function pairedDevice(): array
    {
        $device = new KitchenDevice;
        $device->name = 'Test Kasası';
        $device->save();
        $code = $device->refreshPairingCode();

        $token = $this->postJson('/api/kitchen/pair', [
            'pairing_code' => $code,
            'device_name' => 'Test Kasası',
        ], self::HEADERS)->json('token');

        return ['token' => $token, 'model' => $device->refresh()];
    }

    private function asKitchen(): static
    {
        return $this->withToken($this->pairedDevice()['token']);
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function addressPayload(array $overrides = []): array
    {
        return array_merge([
            'label' => 'Ofis',
            'line1' => 'Örnek Mah. 12. Sk No:3',
            'district' => 'Selçuklu',
            'city' => 'Konya',
            'note' => 'Zili çalmayın',
        ], $overrides);
    }

    private function otherCustomerToken(): string
    {
        return $this->postJson('/api/auth/register', $this->registerPayload([
            'email' => 'baskasi@ornek.com',
            'telephone' => '5559998877',
        ]), self::HEADERS)->json('token');
    }

    /** @return array<string, mixed> */
    private function placeOrder(int $quantity = 2, string $deliveryType = 'delivery'): array
    {
        $payload = [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => $quantity]],
            'delivery_type' => $deliveryType,
            'payment_method' => 'cash',
        ];

        if ($deliveryType === 'delivery') {
            $payload['address'] = [
                'line1' => 'Örnek Mah. 12. Sk No:3',
                'district' => 'Selçuklu',
                'city' => 'Konya',
            ];
        }

        return $this->asCustomer()->postJson('/api/orders', $payload, self::HEADERS)
            ->assertCreated()
            ->json();
    }

    /**
     * Verilen duruma kadar ilerletilmiş bir sipariş üretir.
     *
     * Ara adımlar gerçek uçtan geçiyor: `status_updated_at` ve
     * `status_history` doğrudan yazılsaydı geri alma penceresi testi
     * gerçekte olmayan bir zaman damgasıyla çalışırdı.
     */
    private function orderInStatus(string $status): Order
    {
        $order = $this->placeOrder();
        $orderId = (int) $order['id'];

        $path = [
            OrderStatusTransition::CONFIRMED => [OrderStatusTransition::CONFIRMED],
            OrderStatusTransition::PREPARING => [
                OrderStatusTransition::CONFIRMED,
                OrderStatusTransition::PREPARING,
            ],
            OrderStatusTransition::READY => [
                OrderStatusTransition::CONFIRMED,
                OrderStatusTransition::PREPARING,
                OrderStatusTransition::READY,
            ],
            OrderStatusTransition::CANCELLED => [OrderStatusTransition::CANCELLED],
        ];

        $this->advance($orderId, $path[$status]);

        return Order::findOrFail($orderId);
    }

    /** @param list<string> $statuses */
    private function advance(int $orderId, array $statuses): void
    {
        foreach ($statuses as $status) {
            $this->asKitchen()->postJson(
                '/api/kitchen/orders/'.$orderId.'/status',
                ['status' => $status],
                self::HEADERS,
            )->assertOk();
        }

        $this->assertNotNull(Order::find($orderId));
    }
}
