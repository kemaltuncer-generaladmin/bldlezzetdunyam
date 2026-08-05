<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\User\Facades\AdminAuth;
use Igniter\User\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;
use Veykemtu\BridgeApi\Admin\AdminRegistrar;
use Veykemtu\BridgeApi\Admin\KitchenDevicePanel;
use Veykemtu\BridgeApi\Models\KitchenCommand;
use Veykemtu\BridgeApi\Models\KitchenDevice;
use Veykemtu\BridgeApi\Models\PrintJob;
use Veykemtu\BridgeApi\Services\KitchenDeviceSettings;

/**
 * Mutfak kasaları yönetim ekranı.
 *
 * Testlerin ağırlık merkezi üç yerdedir:
 *
 *  1. **Üç hâlli yazıcı durumu.** `null` (bilinmiyor) ile `false` (arızalı)
 *     aynı gösterilirse yönetici olmayan bir arızayı kovalar; bu ayrım
 *     burada sabitlenir.
 *  2. **Ayarların tek yazarı.** Formdan gelen değerlerin
 *     `KitchenDeviceSettings`'ten geçtiği doğrulanır: sınırlar, "geciken ≥
 *     uyarı" kuralı ve `settings_updated_at` damgası orada uygulanıyor.
 *     Form modele doğrudan yazsaydı hepsi atlanırdı.
 *  3. **Komutun gecikmesi.** Komut kuyruğa girer, anında çalışmaz; ekranın
 *     "gönderildi / teslim edildi / çalıştı" ayrımını doğru yaptığı
 *     doğrulanır.
 */
class AdminKitchenDeviceTest extends TestCase
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

    /**
     * Form parçacığının alan adlarını kuşattığı dizi adı.
     *
     * Çekirdek bunu modelin sınıf adından türetiyor
     * (`Form::initForm` → `str_singular(strip_class_basename($model))`),
     * yani gönderilen alanlar `KitchenDevice[name]` biçimindedir.
     */
    private const string ARRAY_NAME = 'KitchenDevice';

    private const string BASE_URI = '/admin/veykemtu/bridgeapi/kitchen_devices';

    // ── Durum çözümlemesi (veritabanına dokunmaz) ─────────────────────────

    /**
     * Yazıcı ÜÇ HÂLLİDİR: bilinmiyor, hazır, arızalı.
     *
     * "Bilinmiyor" ile "arızalı" aynı renge düşerse, hiç sağlık bildirimi
     * göndermemiş yepyeni bir kasa arızalı görünür.
     */
    public function test_yazici_durumu_uc_hallidir(): void
    {
        $device = new KitchenDevice;

        $device->printer_ok = null;
        $unknown = KitchenDevicePanel::printer($device);

        $device->printer_ok = true;
        $ok = KitchenDevicePanel::printer($device);

        $device->printer_ok = false;
        $fault = KitchenDevicePanel::printer($device);

        $this->assertSame(KitchenDevicePanel::PRINTER_UNKNOWN, $unknown['state']);
        $this->assertSame(KitchenDevicePanel::PRINTER_OK, $ok['state']);
        $this->assertSame(KitchenDevicePanel::PRINTER_FAULT, $fault['state']);

        // Üç durumun rengi de birbirinden farklı olmalı.
        $this->assertCount(3, array_unique([$unknown['css'], $ok['css'], $fault['css']]));
    }

    public function test_baglanti_durumu_esige_gore_belirlenir(): void
    {
        $device = new KitchenDevice;

        $this->assertSame(
            KitchenDevicePanel::CONNECTION_NEVER,
            KitchenDevicePanel::connection($device)['state'],
        );

        $device->last_seen_at = Carbon::now()->subMinute();
        $this->assertSame(
            KitchenDevicePanel::CONNECTION_ONLINE,
            KitchenDevicePanel::connection($device)['state'],
        );

        $device->last_seen_at = Carbon::now()
            ->subMinutes(KitchenDevice::ONLINE_THRESHOLD_MINUTES + 1);
        $this->assertSame(
            KitchenDevicePanel::CONNECTION_OFFLINE,
            KitchenDevicePanel::connection($device)['state'],
        );

        // İptal, çevrimiçilikten önce gelir: iptal edilmiş bir kasa hâlâ
        // istek atıyor olabilir ama artık kullanılmıyordur.
        $device->last_seen_at = Carbon::now();
        $device->revoked_at = Carbon::now();
        $this->assertSame(
            KitchenDevicePanel::CONNECTION_REVOKED,
            KitchenDevicePanel::connection($device)['state'],
        );
    }

    /**
     * "Değiştirdim, kasaya gitti mi?" sorusunun cevabı.
     *
     * Kasa ayarları yalnızca sağlık bildiriminin yanıtında alır; bu yüzden
     * değişiklikten SONRA gelen bir bildirim "aldı" demektir.
     */
    public function test_ayar_senkronu_iki_damganin_karsilastirmasidir(): void
    {
        $device = new KitchenDevice;

        $this->assertSame(
            KitchenDevicePanel::SYNC_UNTOUCHED,
            KitchenDevicePanel::settingsSync($device)['state'],
        );

        $device->settings_updated_at = Carbon::now()->subMinutes(5);
        $this->assertSame(
            KitchenDevicePanel::SYNC_UNVERIFIED,
            KitchenDevicePanel::settingsSync($device)['state'],
        );

        $device->health_reported_at = Carbon::now()->subMinutes(10);
        $this->assertSame(
            KitchenDevicePanel::SYNC_PENDING,
            KitchenDevicePanel::settingsSync($device)['state'],
        );

        $device->health_reported_at = Carbon::now();
        $this->assertSame(
            KitchenDevicePanel::SYNC_APPLIED,
            KitchenDevicePanel::settingsSync($device)['state'],
        );
    }

    public function test_komut_durumlari_ayirt_edilir(): void
    {
        $command = new KitchenCommand;
        $command->command = KitchenCommand::TEST_RECEIPT;

        $this->assertSame(
            KitchenDevicePanel::COMMAND_QUEUED,
            KitchenDevicePanel::commandState($command)['state'],
        );

        $command->delivered_at = Carbon::now();
        $this->assertSame(
            KitchenDevicePanel::COMMAND_DELIVERED,
            KitchenDevicePanel::commandState($command)['state'],
        );

        // Sonucu gelmeyen komut bir süre sonra yeniden gönderilir; ekran
        // bunu "kayboldu" değil "yeniden denenecek" diye göstermeli.
        $command->delivered_at = Carbon::now()
            ->subMinutes(KitchenCommand::STALE_AFTER_MINUTES + 1);
        $this->assertSame(
            KitchenDevicePanel::COMMAND_RETRYING,
            KitchenDevicePanel::commandState($command)['state'],
        );

        $command->executed_at = Carbon::now();
        $command->succeeded = true;
        $this->assertSame(
            KitchenDevicePanel::COMMAND_SUCCEEDED,
            KitchenDevicePanel::commandState($command)['state'],
        );

        $command->succeeded = false;
        $this->assertSame(
            KitchenDevicePanel::COMMAND_FAILED,
            KitchenDevicePanel::commandState($command)['state'],
        );
    }

    /** Beş komutun beşinin de Türkçe bir adı olmalı. */
    public function test_her_komutun_turkce_adi_var(): void
    {
        foreach (KitchenCommand::ALL as $command) {
            $label = KitchenDevicePanel::commandLabel($command);

            $this->assertNotSame($command, $label, "`{$command}` için etiket yok");
            $this->assertStringNotContainsString('veykemtu.bridgeapi::', $label);
        }
    }

    // ── Liste ekranı ──────────────────────────────────────────────────────

    public function test_liste_kasalari_ve_durumlarini_gosterir(): void
    {
        $device = $this->makeDevice('Ana mutfak kasası');
        $device->last_seen_at = Carbon::now();
        $device->health_reported_at = Carbon::now();
        $device->printer_ok = false;
        $device->print_queue_pending = 2;
        $device->print_queue_failed = 1;
        $device->app_version = '1.4.2';
        $device->save();

        $this->actingAsAdmin();

        $this->get(self::BASE_URI)
            ->assertOk()
            ->assertSee('Ana mutfak kasası')
            ->assertSee(lang('veykemtu.bridgeapi::default.kds.printer_fault'))
            ->assertSee(lang('veykemtu.bridgeapi::default.kds.state_online'))
            ->assertSee('1.4.2')
            // Çeviri anahtarı ham hâliyle ekrana düşmemeli.
            ->assertDontSee('veykemtu.bridgeapi::default');
    }

    public function test_liste_giris_yapmadan_acilmaz(): void
    {
        $this->get(self::BASE_URI)->assertRedirect();
    }

    // ── Cihaz ekleme ve eşleme ────────────────────────────────────────────

    /**
     * Ekleme ekranı YALNIZCA adı sorar.
     *
     * Ayarlar burada gösterilseydi yönetici, kasa daha kendi
     * varsayılanlarını hiç bildirmeden dokuz alan doldurmak zorundaymış
     * gibi hissederdi.
     */
    public function test_yeni_kasa_sayfasi_yalnizca_adi_sorar(): void
    {
        $this->actingAsAdmin();

        $this->get(self::BASE_URI.'/create')
            ->assertOk()
            ->assertSee(lang('veykemtu.bridgeapi::default.kds.label_name'))
            ->assertDontSee(lang('veykemtu.bridgeapi::default.kds.label_poll_seconds'))
            ->assertDontSee('veykemtu.bridgeapi::default');
    }

    public function test_yeni_kasa_eklenince_eslesme_kodu_uretilir(): void
    {
        $this->actingAsAdmin();

        $this->post(self::BASE_URI.'/create', [
            '_handler' => 'onSave',
            self::ARRAY_NAME => ['name' => 'İkinci kasa'],
        ])->assertRedirect();

        $device = KitchenDevice::where('name', 'İkinci kasa')->first();

        $this->assertNotNull($device);
        $this->assertTrue($device->pairingCodeIsUsable());
        $this->assertMatchesRegularExpression('/^[A-Z0-9]{4}-[A-Z0-9]{4}$/', (string) $device->pairing_code);
    }

    public function test_duzenleme_sayfasi_kodu_ve_sagligi_gosterir(): void
    {
        $device = $this->makeDevice();
        $code = $device->refreshPairingCode();
        $device->printer_ok = null;
        $device->save();

        $this->actingAsAdmin();

        $this->get(self::BASE_URI.'/edit/'.$device->id)
            ->assertOk()
            ->assertSee($code)
            ->assertSee(lang('veykemtu.bridgeapi::default.kds.printer_unknown'))
            ->assertSee(lang('veykemtu.bridgeapi::default.kds.panel_commands'))
            // Boş alanın "kapalı" değil "dokunulmadı" olduğu YAZILI olmalı.
            ->assertSee(lang('veykemtu.bridgeapi::default.kds.text_untouched'))
            ->assertDontSee('veykemtu.bridgeapi::default');
    }

    public function test_eslesme_kodu_yenilenir(): void
    {
        $device = $this->makeDevice();

        $this->actingAsAdmin();

        $this->post(self::BASE_URI.'/edit/'.$device->id, [
            '_handler' => 'onRefreshPairingCode',
        ])->assertRedirect();

        $this->assertTrue($device->refresh()->pairingCodeIsUsable());
    }

    public function test_kasa_iptal_edilir(): void
    {
        $device = $this->makeDevice();

        $this->actingAsAdmin();

        $this->post(self::BASE_URI.'/edit/'.$device->id, [
            '_handler' => 'onRevokeDevice',
        ])->assertRedirect();

        $this->assertTrue($device->refresh()->isRevoked());
    }

    // ── Ayarlar ───────────────────────────────────────────────────────────

    /**
     * Kaydedilen her ayar servisin okuduğu biçimde geri gelmeli.
     *
     * Servisten okunamayan bir değer, formun modele doğrudan yazdığı ve
     * sınır/damga kurallarını atladığı anlamına gelir.
     */
    public function test_ayarlar_servis_uzerinden_kaydedilir(): void
    {
        $device = $this->makeDevice();

        $this->actingAsAdmin();

        $this->saveSettings($device, [
            'poll_seconds' => 5,
            'health_seconds' => 30,
            'sound_enabled' => 1,
            'alarm_silenceable' => 0,
            'connection_alarm_seconds' => 45,
            'warning_after_minutes' => 10,
            'late_after_minutes' => 20,
            'printer_device_path' => '/dev/usb/lp0',
            'printer_code_page' => 29,
        ])->assertRedirect();

        $settings = resolve(KitchenDeviceSettings::class)->forDevice($device->refresh());

        $this->assertSame(5, $settings['poll_seconds']);
        $this->assertSame(30, $settings['health_seconds']);
        $this->assertTrue($settings['sound_enabled']);
        $this->assertFalse($settings['alarm_silenceable']);
        $this->assertSame(45, $settings['connection_alarm_seconds']);
        $this->assertSame(10, $settings['warning_after_minutes']);
        $this->assertSame(20, $settings['late_after_minutes']);
        $this->assertSame('/dev/usb/lp0', $settings['printer_device_path']);
        $this->assertSame(29, $settings['printer_code_page']);

        // Damga olmadan "kasaya gitti mi?" sorusu cevaplanamaz.
        $this->assertNotNull($settings['updated_at']);
    }

    /**
     * Boş bırakılan alan `null` olmalı, sıfır ya da boş metin değil.
     *
     * `null` "yönetici dokunmadı, kasa kendi varsayılanını kullansın"
     * demektir; 0 ya da "" kasaya geçerli bir ayar gibi görünür ve
     * yoklamayı durdurur veya yazıcı yolunu siler.
     */
    public function test_bos_birakilan_ayar_kasa_varsayilanina_doner(): void
    {
        $device = $this->makeDevice();

        $this->actingAsAdmin();

        $this->saveSettings($device, [
            'poll_seconds' => 5,
            'sound_enabled' => 1,
            'printer_device_path' => '/dev/usb/lp0',
        ]);

        $this->assertSame(5, $device->refresh()->poll_seconds);

        $this->saveSettings($device, [
            'poll_seconds' => null,
            'sound_enabled' => null,
            'printer_device_path' => null,
        ]);

        $device->refresh();

        $this->assertNull($device->poll_seconds);
        $this->assertNull($device->sound_enabled);
        $this->assertNull($device->printer_device_path);
    }

    /**
     * Geciken eşiği uyarı eşiğinin altına yazılamaz.
     *
     * Yazılabilseydi kart hiç kırmızıya dönmezdi: uyarı eşiği zaten
     * geçilmiş olurdu ve geciken siparişler sarı kalırdı.
     */
    public function test_geciken_esigi_uyari_esigine_yukseltilir(): void
    {
        $device = $this->makeDevice();

        $this->actingAsAdmin();

        $this->saveSettings($device, [
            'warning_after_minutes' => 20,
            'late_after_minutes' => 10,
        ]);

        $this->assertSame(20, $device->refresh()->late_after_minutes);
    }

    /**
     * Sınır dışı değer sessizce kırpılmaz, reddedilir.
     *
     * Kırpma servisin son savunmasıdır; formun görevi yöneticiye "70
     * yazdın, 60'a düştü" demeden önce hatayı göstermektir.
     */
    public function test_sinir_disi_yoklama_araligi_kaydedilmez(): void
    {
        $device = $this->makeDevice();

        $this->actingAsAdmin();

        $this->saveSettings($device, [
            'poll_seconds' => KitchenDeviceSettings::MAX_POLL_SECONDS + 40,
        ]);

        $this->assertNull($device->refresh()->poll_seconds);
        $this->assertNull($device->settings_updated_at);
    }

    // ── Komutlar ──────────────────────────────────────────────────────────

    public function test_komut_kuyruga_alinir_ve_hemen_calismaz(): void
    {
        $device = $this->makeDevice();

        $this->actingAsAdmin();

        $this->post(self::BASE_URI.'/edit/'.$device->id, [
            '_handler' => 'onSendCommand',
            'command' => KitchenCommand::TEST_RECEIPT,
        ])->assertRedirect();

        $command = KitchenCommand::where('device_id', $device->id)->first();

        $this->assertNotNull($command);
        $this->assertSame(KitchenCommand::TEST_RECEIPT, $command->command);
        // Teslimat sağlık bildirimiyle olur; kuyruğa girdiği an teslim
        // edilmiş ya da çalışmış sayılmaz.
        $this->assertNull($command->delivered_at);
        $this->assertNull($command->executed_at);
        // Gönderim damgası olmadan komut geçmişi "ne zaman göndermiştim"
        // sorusunu cevaplayamaz; Flame modeli damgaları kapalı tuttuğu için
        // denetleyici elle vuruyor.
        $this->assertNotNull($command->created_at);
    }

    public function test_yeniden_basma_siparis_ve_fis_tipini_tasir(): void
    {
        $device = $this->makeDevice();

        $this->actingAsAdmin();

        $this->post(self::BASE_URI.'/edit/'.$device->id, [
            '_handler' => 'onSendCommand',
            'command' => KitchenCommand::REPRINT,
            'order_id' => 4242,
            'receipt_type' => PrintJob::TYPE_CUSTOMER,
        ])->assertRedirect();

        $command = KitchenCommand::where('device_id', $device->id)->firstOrFail();

        $this->assertSame(KitchenCommand::REPRINT, $command->command);
        $this->assertSame(4242, $command->payload['order_id']);
        $this->assertSame(PrintJob::TYPE_CUSTOMER, $command->payload['type']);
    }

    public function test_siparis_numarasi_olmadan_yeniden_basilamaz(): void
    {
        $device = $this->makeDevice();

        $this->actingAsAdmin();

        $this->postJson(self::BASE_URI.'/edit/'.$device->id, [
            '_handler' => 'onSendCommand',
            'command' => KitchenCommand::REPRINT,
        ])->assertStatus(406);

        $this->assertSame(0, KitchenCommand::where('device_id', $device->id)->count());
    }

    public function test_iptal_edilmis_kasaya_komut_gonderilemez(): void
    {
        $device = $this->makeDevice();
        $device->revoke();

        $this->actingAsAdmin();

        $this->postJson(self::BASE_URI.'/edit/'.$device->id, [
            '_handler' => 'onSendCommand',
            'command' => KitchenCommand::RESTART,
        ])->assertStatus(406);

        $this->assertSame(0, KitchenCommand::where('device_id', $device->id)->count());
    }

    // ── Kayıt tanımları ───────────────────────────────────────────────────

    /**
     * Kasa yetkisi ayar yetkisinden AYRI olmalı.
     *
     * Bu yetkiyi taşıyan kişi kasayı yeniden başlatabilir ve iptal
     * edebilir; fiyat şalterleriyle aynı kutuya konsaydı biri verilmeden
     * diğeri verilemezdi.
     */
    public function test_kasa_yetkisi_ayar_yetkisinden_ayridir(): void
    {
        $permissions = AdminRegistrar::registerPermissions();

        $this->assertArrayHasKey(AdminRegistrar::PERMISSION_DEVICES, $permissions);
        $this->assertNotSame(AdminRegistrar::PERMISSION, AdminRegistrar::PERMISSION_DEVICES);
    }

    public function test_menu_kisayolu_kasa_ekranini_gosterir(): void
    {
        $navigation = AdminRegistrar::registerNavigation();
        $item = $navigation['restaurant']['child']['bld_kitchen_devices'];

        $this->assertSame(admin_url(AdminRegistrar::DEVICES_URI), $item['href']);
        $this->assertSame(AdminRegistrar::PERMISSION_DEVICES, $item['permission']);
    }

    /**
     * Formda servisin bildiği HER ayar için bir alan olmalı.
     *
     * Servise onuncu bir ayar eklendiği gün bu test kırılır; aksi hâlde
     * yeni ayar sessizce yönetilemez kalırdı.
     */
    public function test_form_servisteki_her_ayari_kapsar(): void
    {
        /** @var array{form: array{fields: array<string, mixed>}} $config */
        $config = require dirname(__DIR__, 2).'/resources/models/kitchendevice.php';

        $fieldNames = array_map(
            static fn(string $name): string => explode('@', $name)[0],
            array_keys($config['form']['fields']),
        );

        $settings = resolve(KitchenDeviceSettings::class)->forDevice(new KitchenDevice);
        unset($settings['updated_at']);

        foreach (array_keys($settings) as $setting) {
            $this->assertContains($setting, $fieldNames, "`{$setting}` ayarının form alanı yok");
        }
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    private function makeDevice(string $name = 'Mutfak kasası'): KitchenDevice
    {
        $device = new KitchenDevice;
        $device->name = $name;
        $device->save();

        return $device;
    }

    /**
     * Düzenleme formunu, verilen ayarlar dışındakiler boş olacak şekilde
     * gönderir — tıpkı tarayıcının yaptığı gibi.
     *
     * @param  array<string, mixed>  $settings
     */
    private function saveSettings(KitchenDevice $device, array $settings): TestResponse
    {
        $fields = resolve(KitchenDeviceSettings::class)->forDevice(new KitchenDevice);
        unset($fields['updated_at']);

        $payload = array_merge(
            ['name' => $device->name],
            array_fill_keys(array_keys($fields), null),
            $settings,
        );

        return $this->post(self::BASE_URI.'/edit/'.$device->id, [
            '_handler' => 'onSave',
            self::ARRAY_NAME => $payload,
        ]);
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
