<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Order;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Models\ControlAudit;
use Veykemtu\BridgeApi\Models\KitchenCommand;
use Veykemtu\BridgeApi\Models\KitchenDevice;
use Veykemtu\BridgeApi\Services\KitchenDeviceSettings;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;

/**
 * Kontrol Merkezi ↔ BLD köprüsü — K-21.
 *
 * İKİ AYRI SORU TEST EDİLİYOR:
 *
 * 1. **Kapı sağlam mı?** İmza, zaman penceresi, nonce ve yol bağlama.
 *    Bu uçlar cihaz iptal ediyor, ayar itiyor, sipariş revize ediyor —
 *    yani `bbd.signature`'ın aksine tekrar (replay) saldırısı burada
 *    gerçek zarar verir. Kapıya ait testler bilinçli olarak fazla.
 *
 * 2. **Kabuk doğru mu?** Gerekçe zorunlu mu, kuru prova gerçekten hiçbir
 *    şeyi değiştirmiyor mu, denetim satırı her hâlükârda yazılıyor mu,
 *    iptal satırı siliyor mu (SİLMEMELİ), revizyon `orders.updated_at`'i
 *    bumpluyor mu.
 *
 * Sır ortamdan okunuyor; test için sabitleniyor (`BbdBridgeTest` deseni).
 */
class ControlKdsTest extends KitchenTestCase
{
    private const string SECRET = 'test-kontrol-merkezi-sirri';

    private const string ACTOR = 'Ayşe Yönetici';

    private const string REASON = 'Sahada denetim için yapıldı';

    protected function setUp(): void
    {
        parent::setUp();

        putenv('BLD_CONTROL_SECRET='.self::SECRET);
        $_ENV['BLD_CONTROL_SECRET'] = self::SECRET;
    }

    // ── 1. Kapı: imza katmanı ─────────────────────────────────────────────

    public function test_imzali_istek_kabul_edilir(): void
    {
        $this->signed('GET', '/api/control/kds/devices')
            ->assertOk()
            ->assertJsonPath('data', []);
    }

    public function test_IMZASIZ_istek_reddedilir(): void
    {
        $this->getJson('/api/control/kds/devices', ['Accept' => 'application/json'])
            ->assertStatus(401)
            ->assertJsonPath('error.code', 'UNAUTHENTICATED');
    }

    public function test_YANLIS_IMZA_reddedilir(): void
    {
        $this->call('GET', '/api/control/kds/devices', [], [], [], [
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_X_CONTROL_TIMESTAMP' => (string) time(),
            'HTTP_X_CONTROL_NONCE' => bin2hex(random_bytes(12)),
            'HTTP_X_CONTROL_SIGNATURE' => 'sha256='.str_repeat('a', 64),
        ])->assertStatus(401);
    }

    public function test_GOVDE_DEGISTIRILIRSE_imza_tutmaz(): void
    {
        // İmza ham gövde üzerinde; tek karakter değişse doğrulanmamalı.
        $signed = $this->body(['name' => 'Mutfak Kasası']);
        $sent = $this->body(['name' => 'Başka Kasa']);

        $this->signed('POST', '/api/control/kds/devices', $sent, signBody: $signed)
            ->assertStatus(401);

        $this->assertSame(0, KitchenDevice::count());
    }

    public function test_ZAMAN_PENCERESI_disinda_istek_reddedilir(): void
    {
        // Pencere ±300 sn. 400 saniye önce imzalanmış bir istek, imzası
        // kusursuz olsa bile geçmemeli — aksi hâlde ağdan yakalanmış bir
        // istek saatler sonra oynatılabilirdi.
        $this->signed('GET', '/api/control/kds/devices', timestamp: time() - 400)
            ->assertStatus(401);

        $this->signed('GET', '/api/control/kds/devices', timestamp: time() + 400)
            ->assertStatus(401);
    }

    public function test_AYNI_NONCE_IKINCI_KEZ_reddedilir(): void
    {
        // TEKRAR (REPLAY) SALDIRISI. Tek başına zaman penceresi yetmez:
        // pencere içinde aynı isteği ikinci kez oynatmak hâlâ mümkün
        // olurdu ve "cihazı iptal et" isteğinin tekrarı mutfağı sipariş
        // göremez hâle getirirdi.
        $nonce = bin2hex(random_bytes(12));

        $this->signed('GET', '/api/control/kds/devices', nonce: $nonce)->assertOk();
        $this->signed('GET', '/api/control/kds/devices', nonce: $nonce)->assertStatus(401);
    }

    public function test_BASKA_YOL_ICIN_URETILEN_IMZA_yeniden_kullanilamaz(): void
    {
        // Yalnız gövde imzalansaydı, gövdesiz iki farklı uç aynı imzayı
        // paylaşırdı — ki iptal ucunun gövdesi de gövdesiz uçlara benzer.
        $device = $this->makeDevice();

        $this->signed(
            'GET',
            '/api/control/kds/devices',
            signPath: '/api/control/kds/devices/'.$device->id.'/commands',
        )->assertStatus(401);
    }

    public function test_BASKA_METOT_ICIN_URETILEN_IMZA_yeniden_kullanilamaz(): void
    {
        $this->signed('GET', '/api/control/kds/devices', signMethod: 'POST')
            ->assertStatus(401);
    }

    public function test_SIR_TANIMSIZSA_UC_KAPALIDIR(): void
    {
        // Boş sırla imza doğrulamak herkesin geçtiği bir kapıdır.
        putenv('BLD_CONTROL_SECRET');
        unset($_ENV['BLD_CONTROL_SECRET'], $_SERVER['BLD_CONTROL_SECRET']);

        $this->signed('GET', '/api/control/kds/devices')->assertStatus(401);
    }

    public function test_X_APP_ID_BASLIGI_ISTENMEZ(): void
    {
        // Kontrol Merkezi bir müşteri istemcisi değil; ondan `X-App-Id`
        // beklemek anlamsız olurdu. Yardımcı zaten o başlıkları hiç
        // göndermiyor — bu test kuralı sabitliyor.
        $this->signed('GET', '/api/control/kds/overview')->assertOk();
    }

    // ── 2. Gerekçe ve aktör ───────────────────────────────────────────────

    public function test_GEREKCESIZ_YAZMA_reddedilir(): void
    {
        $this->signed('POST', '/api/control/kds/devices', [
            'name' => 'Mutfak Kasası',
            'actor' => self::ACTOR,
        ])->assertStatus(422)->assertJsonPath('error.code', 'VALIDATION_FAILED');

        $this->assertSame(0, KitchenDevice::count());
        $this->assertSame(0, ControlAudit::count());
    }

    public function test_KISA_GEREKCE_reddedilir(): void
    {
        // "ok" yazıp geçmek serbest olsaydı denetim izi, doldurulmuş ama
        // hiçbir şey anlatmayan bir sütuna dönerdi.
        $this->signed('POST', '/api/control/kds/devices', [
            'name' => 'Mutfak Kasası',
            'actor' => self::ACTOR,
            'reason' => 'kisa',
        ])->assertStatus(422);

        $this->assertSame(0, KitchenDevice::count());
    }

    public function test_AKTORSUZ_YAZMA_reddedilir(): void
    {
        $this->signed('POST', '/api/control/kds/devices', [
            'name' => 'Mutfak Kasası',
            'reason' => self::REASON,
        ])->assertStatus(422);
    }

    public function test_yazma_denetim_satiri_birakir(): void
    {
        $this->signed('POST', '/api/control/kds/devices', $this->intent([
            'name' => 'Mutfak Kasası',
        ]))->assertOk();

        $audit = ControlAudit::firstOrFail();

        $this->assertSame(self::ACTOR, $audit->actor);
        $this->assertSame('device.create', $audit->action);
        $this->assertSame(self::REASON, $audit->reason);
        $this->assertSame(ControlAudit::RESULT_APPLIED, $audit->result);
        $this->assertSame('Mutfak Kasası', $audit->payload_json['name']);
    }

    public function test_BASARISIZ_YAZMA_DA_iz_birakir(): void
    {
        // "Denedim ve olmadı" tam da soruşturulması gereken hâl; denetim
        // satırı işlemden ÖNCE açıldığı için yarıda kalan yazma da iz
        // bırakıyor.
        $device = $this->makeDevice();
        $device->revoke();

        $this->signed(
            'POST',
            '/api/control/kds/devices/'.$device->id.'/pairing-code',
            $this->intent(),
        )->assertStatus(422);

        $audit = ControlAudit::firstOrFail();

        $this->assertSame(ControlAudit::RESULT_FAILED, $audit->result);
        $this->assertArrayHasKey('error', $audit->payload_json);
    }

    // ── 3. Kuru prova ─────────────────────────────────────────────────────

    public function test_KURU_PROVA_hicbir_sey_degistirmez_ama_denetim_yazar(): void
    {
        $response = $this->signed('POST', '/api/control/kds/devices', $this->intent([
            'name' => 'Mutfak Kasası',
            'dry_run' => true,
        ]))->assertOk();

        $response->assertJsonPath('ok', true)
            ->assertJsonPath('dry_run', true)
            ->assertJsonPath('would.name', 'Mutfak Kasası');

        $this->assertSame(0, KitchenDevice::count(), 'Kuru prova cihaz yaratmamalı.');

        $audit = ControlAudit::firstOrFail();
        $this->assertSame(ControlAudit::RESULT_DRY_RUN, $audit->result);
    }

    public function test_KURU_PROVA_cihazi_iptal_etmez(): void
    {
        $device = $this->makeDevice();

        $this->signed(
            'POST',
            '/api/control/kds/devices/'.$device->id.'/revoke',
            $this->intent(['dry_run' => true]),
        )->assertOk()->assertJsonPath('dry_run', true);

        $this->assertNull($device->refresh()->revoked_at);
        $this->assertSame(ControlAudit::RESULT_DRY_RUN, ControlAudit::firstOrFail()->result);
    }

    public function test_KURU_PROVA_ayari_yazmaz(): void
    {
        $device = $this->makeDevice();

        $this->signed(
            'PATCH',
            '/api/control/kds/devices/'.$device->id.'/settings',
            $this->intent(['settings' => ['poll_seconds' => 9], 'dry_run' => true]),
        )->assertOk()->assertJsonPath('would.settings.poll_seconds', 9);

        $this->assertNull($device->refresh()->poll_seconds);
        $this->assertNull($device->settings_updated_at);
    }

    public function test_KURU_PROVA_GERCEKTEN_DENETLER(): void
    {
        // Kuru prova yalnız isteği yankılasaydı, "geçti" diyen bir ekran
        // gerçek gönderimde patlardı. Teslim edilmiş sipariş burada da
        // reddediliyor.
        $order = $this->confirmedOrder();
        $this->advance((int) $order->order_id, [
            OrderStatusTransition::PREPARING,
            OrderStatusTransition::READY,
            OrderStatusTransition::ON_THE_WAY,
            OrderStatusTransition::DELIVERED,
        ]);

        $this->signed(
            'POST',
            '/api/control/kds/orders/'.$order->order_id.'/revisions',
            $this->intent([
                'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 1]],
                'dry_run' => true,
            ]),
        )->assertStatus(422);

        // Denetim satırı `dry_run` KALIR: ön denetimin başarısızlığı bir
        // yazma denemesi değildir ve iki hâl karıştırılmamalı.
        $audit = ControlAudit::firstOrFail();
        $this->assertSame(ControlAudit::RESULT_DRY_RUN, $audit->result);
        $this->assertArrayHasKey('error', $audit->payload_json);
    }

    // ── 4. Cihazlar ───────────────────────────────────────────────────────

    public function test_cihaz_yaratilir_ve_esleme_kodu_doner(): void
    {
        $response = $this->signed('POST', '/api/control/kds/devices', $this->intent([
            'name' => 'Mutfak Kasası',
        ]))->assertOk();

        $code = $response->json('device.pairing.code');

        $this->assertMatchesRegularExpression('/^[A-Z0-9]{4}-[A-Z0-9]{4}$/', (string) $code);
        $this->assertTrue($response->json('device.pairing.usable'));
        $this->assertFalse($response->json('device.online'));
        $this->assertSame(1, KitchenDevice::count());
    }

    public function test_kod_uretilen_kasa_gercekten_eslesir(): void
    {
        // Kodun biçimi doğru olabilir ama işe yaramayabilir; tek gerçek
        // sınav kasanın o kodla token alması.
        $code = $this->signed('POST', '/api/control/kds/devices', $this->intent([
            'name' => 'Mutfak Kasası',
        ]))->assertOk()->json('device.pairing.code');

        $this->postJson('/api/kitchen/pair', [
            'pairing_code' => $code,
            'device_name' => 'Mutfak Kasası',
        ], self::HEADERS)->assertOk()->assertJsonStructure(['token']);
    }

    public function test_KULLANILMIS_KOD_LISTEDE_GORUNMEZ(): void
    {
        // Kullanılmış kodu göstermek, yöneticiye çalışmayan bir kod
        // okuturdu.
        $this->pairedDevice();

        $this->signed('GET', '/api/control/kds/devices')
            ->assertOk()
            ->assertJsonPath('data.0.pairing.code', null)
            ->assertJsonPath('data.0.pairing.usable', false);
    }

    public function test_CIHAZ_IPTALI_SATIRI_SILMEZ(): void
    {
        $paired = $this->pairedDevice();
        /** @var KitchenDevice $device */
        $device = $paired['model'];

        $this->signed(
            'POST',
            '/api/control/kds/devices/'.$device->id.'/revoke',
            $this->intent(),
        )->assertOk();

        $fresh = KitchenDevice::find($device->id);

        $this->assertNotNull($fresh, 'İptal, cihaz satırını SİLMEMELİ.');
        $this->assertNotNull($fresh->revoked_at);
        // TOKEN SATIRI DA KASTEN DURUYOR: silinseydi KDS `403
        // DEVICE_REVOKED` yerine genel bir `401` görür ve mutfak
        // "eşleme iptal edildi" mesajını hiç almazdı.
        $this->assertSame(1, $fresh->tokens()->count());
    }

    public function test_iptal_edilen_kasa_mutfak_ucuna_giremez(): void
    {
        $paired = $this->pairedDevice();

        $this->signed(
            'POST',
            '/api/control/kds/devices/'.$paired['model']->id.'/revoke',
            $this->intent(),
        )->assertOk();

        $this->withToken($paired['token'])
            ->getJson('/api/kitchen/orders', self::HEADERS)
            ->assertStatus(403)
            ->assertJsonPath('error.code', 'DEVICE_REVOKED');
    }

    public function test_IKINCI_IPTAL_ilk_damgayi_oynatmaz(): void
    {
        $device = $this->makeDevice();

        $this->signed('POST', '/api/control/kds/devices/'.$device->id.'/revoke', $this->intent())
            ->assertOk();
        $first = $device->refresh()->revoked_at;

        $this->signed('POST', '/api/control/kds/devices/'.$device->id.'/revoke', $this->intent())
            ->assertOk();

        $this->assertEquals($first, $device->refresh()->revoked_at);
    }

    public function test_iptal_edilmis_kasaya_komut_gonderilemez(): void
    {
        $device = $this->makeDevice();
        $device->revoke();

        $this->signed(
            'POST',
            '/api/control/kds/devices/'.$device->id.'/commands',
            $this->intent(['command' => KitchenCommand::TEST_RECEIPT]),
        )->assertStatus(422);

        $this->assertSame(0, KitchenCommand::count());
    }

    public function test_komut_kuyruga_girer_ve_kasa_saglik_yanitiyla_alir(): void
    {
        $paired = $this->pairedDevice();

        $this->signed(
            'POST',
            '/api/control/kds/devices/'.$paired['model']->id.'/commands',
            $this->intent(['command' => KitchenCommand::TEST_RECEIPT]),
        )->assertOk()->assertJsonPath('command.command', KitchenCommand::TEST_RECEIPT);

        $commands = $this->withToken($paired['token'])->postJson('/api/kitchen/health', [
            'printer_ok' => true,
            'print_queue_pending' => 0,
            'print_queue_failed' => 0,
        ], self::HEADERS)->assertOk()->json('commands');

        $this->assertSame(KitchenCommand::TEST_RECEIPT, $commands[0]['command']);
    }

    public function test_reprint_komutu_yuksuz_gonderilemez(): void
    {
        $device = $this->makeDevice();

        $this->signed(
            'POST',
            '/api/control/kds/devices/'.$device->id.'/commands',
            $this->intent(['command' => KitchenCommand::REPRINT]),
        )->assertStatus(422);
    }

    public function test_komut_gecmisi_uc_damgayi_tasir(): void
    {
        $device = $this->makeDevice();

        $this->signed(
            'POST',
            '/api/control/kds/devices/'.$device->id.'/commands',
            $this->intent(['command' => KitchenCommand::SILENCE_ALARM]),
        )->assertOk();

        $this->signed('GET', '/api/control/kds/devices/'.$device->id.'/commands')
            ->assertOk()
            ->assertJsonPath('data.0.command', KitchenCommand::SILENCE_ALARM)
            ->assertJsonPath('data.0.delivered_at', null)
            ->assertJsonPath('data.0.executed_at', null)
            ->assertJsonPath('data.0.succeeded', null);
    }

    public function test_TANIMSIZ_KOMUT_reddedilir(): void
    {
        // `KitchenCommand::ALL` dışına çıkmak, kasanın anlamadığı bir
        // komutu sonsuza kadar kuyrukta bırakırdı.
        $device = $this->makeDevice();

        $this->signed(
            'POST',
            '/api/control/kds/devices/'.$device->id.'/commands',
            $this->intent(['command' => 'format_disk']),
        )->assertStatus(422);
    }

    // ── 4.5 K-22 ile gelen üç komut ───────────────────────────────────────

    /**
     * @return list<array{0: string}>
     */
    public static function yeniKomutlar(): array
    {
        return [
            [KitchenCommand::UPDATE],
            [KitchenCommand::UNPAIR],
            [KitchenCommand::CLEAR_QUEUE],
        ];
    }

    #[DataProvider('yeniKomutlar')]
    public function test_YENI_KOMUTLAR_kuyruga_girer_ve_kasaya_iner(string $komut): void
    {
        $paired = $this->pairedDevice();

        $this->signed(
            'POST',
            '/api/control/kds/devices/'.$paired['model']->id.'/commands',
            $this->intent(['command' => $komut]),
        )->assertOk()->assertJsonPath('command.command', $komut);

        $commands = $this->withToken($paired['token'])->postJson('/api/kitchen/health', [
            'printer_ok' => true,
            'print_queue_pending' => 0,
            'print_queue_failed' => 0,
        ], self::HEADERS)->assertOk()->json('commands');

        $this->assertSame($komut, $commands[0]['command']);
        // Yüksüz komutlar: kasa `payload`'a bakmıyor ve boş dizi bekliyor.
        $this->assertSame([], $commands[0]['payload']);
    }

    public function test_KOMUT_SONUCU_GERI_DONER_ve_komut_bir_daha_gonderilmez(): void
    {
        // Yönetici panelde "çalıştı" ya da "çalıştırılamadı" görmeli;
        // sonucu gelmeyen bir komut için aynı düğmeye tekrar basılır.
        $paired = $this->pairedDevice();

        $this->signed(
            'POST',
            '/api/control/kds/devices/'.$paired['model']->id.'/commands',
            $this->intent(['command' => KitchenCommand::UPDATE]),
        )->assertOk();

        $commands = $this->withToken($paired['token'])->postJson('/api/kitchen/health', [
            'printer_ok' => true,
            'print_queue_pending' => 0,
            'print_queue_failed' => 0,
        ], self::HEADERS)->assertOk()->json('commands');

        $this->withToken($paired['token'])->postJson('/api/kitchen/health', [
            'printer_ok' => true,
            'print_queue_pending' => 0,
            'print_queue_failed' => 0,
            'command_results' => [[
                'id' => $commands[0]['id'],
                'ok' => false,
                'message' => 'Paket açılamadı: bozuk arşiv',
            ]],
        ], self::HEADERS)->assertOk()->assertJsonPath('commands', []);

        $this->signed('GET', '/api/control/kds/devices/'.$paired['model']->id.'/commands')
            ->assertOk()
            ->assertJsonPath('data.0.command', KitchenCommand::UPDATE)
            ->assertJsonPath('data.0.succeeded', false)
            ->assertJsonPath('data.0.result', 'Paket açılamadı: bozuk arşiv');
    }

    public function test_yeni_komutlarin_hepsi_YIKICI_listesinde(): void
    {
        // Kontrol Merkezi bu listeye bakarak `bld_kds.devices` kapısını
        // uyguluyor; liste eksik kalırsa yıkıcı bir komut yetkisiz bir
        // kullanıcıya açılırdı.
        foreach ([KitchenCommand::UPDATE, KitchenCommand::UNPAIR, KitchenCommand::CLEAR_QUEUE] as $komut) {
            $this->assertContains($komut, KitchenCommand::DESTRUCTIVE);
            $this->assertContains($komut, KitchenCommand::ALL);
        }

        // Salt okunur/zararsız olanlar listede OLMAMALI: her komutu yıkıcı
        // saymak kapının anlamını yok eder.
        $this->assertNotContains(KitchenCommand::TEST_RECEIPT, KitchenCommand::DESTRUCTIVE);
        $this->assertNotContains(KitchenCommand::SILENCE_ALARM, KitchenCommand::DESTRUCTIVE);
    }

    // ── 5. Ayarlar ve kilit politikası ────────────────────────────────────

    public function test_ayar_yazinca_settings_updated_at_ilerler(): void
    {
        $device = $this->makeDevice();

        // Geçmişe çekiliyor ki "ilerledi mi" sorusu saniye çözünürlüğünde
        // cevaplanabilsin; `sleep` ile beklemenin gereği yok.
        KitchenDevice::withoutTimestamps(fn() => $device->forceFill([
            'settings_updated_at' => Carbon::now()->subMinutes(5),
        ])->saveQuietly());

        $before = $device->refresh()->settings_updated_at;

        $this->signed(
            'PATCH',
            '/api/control/kds/devices/'.$device->id.'/settings',
            $this->intent(['settings' => ['poll_seconds' => 9]]),
        )->assertOk();

        $after = $device->refresh()->settings_updated_at;

        $this->assertNotNull($after);
        $this->assertTrue(
            $after->greaterThan($before),
            'Ayar yazıldığında damga ilerlemeli; yönetici "kasaya gitti mi" '
            .'sorusunu bu damgayla cevaplıyor.',
        );
        $this->assertSame(9, (int) $device->poll_seconds);
    }

    public function test_ayar_yazimi_KISMIDIR(): void
    {
        $device = $this->makeDevice();

        $this->signed(
            'PATCH',
            '/api/control/kds/devices/'.$device->id.'/settings',
            $this->intent(['settings' => ['poll_seconds' => 9]]),
        )->assertOk();

        $this->signed(
            'PATCH',
            '/api/control/kds/devices/'.$device->id.'/settings',
            $this->intent(['settings' => ['volume_percent' => 40]]),
        )->assertOk();

        $device->refresh();

        $this->assertSame(9, (int) $device->poll_seconds, 'Gönderilmeyen anahtar değişmemeli.');
        $this->assertSame(40, (int) $device->volume_percent);
    }

    public function test_SINIR_DISI_AYAR_sessizce_kirpilmaz(): void
    {
        // Makine istemcisinde sessiz kırpma daha tehlikeli: Kontrol
        // Merkezi 70 yazıp 60 kaydedildiğini fark etmez.
        $device = $this->makeDevice();

        $this->signed(
            'PATCH',
            '/api/control/kds/devices/'.$device->id.'/settings',
            $this->intent([
                'settings' => ['poll_seconds' => KitchenDeviceSettings::MAX_POLL_SECONDS + 1],
            ]),
        )->assertStatus(422);

        $this->assertNull($device->refresh()->poll_seconds);
    }

    public function test_AYARLAR_SETTINGS_NESNESININ_ALTINDA_beklenir(): void
    {
        // Kökte olsalardı `reason`/`actor`/`dry_run` ile aynı ad alanını
        // paylaşırlardı; `reason` adında bir ayar eklenemezdi.
        $device = $this->makeDevice();

        $this->signed(
            'PATCH',
            '/api/control/kds/devices/'.$device->id.'/settings',
            $this->intent(['poll_seconds' => 9]),
        )->assertStatus(422);

        $this->assertNull($device->refresh()->poll_seconds);
    }

    public function test_TANINMAYAN_AYAR_ANAHTARI_sessizce_yutulmaz(): void
    {
        // `allow_settngs` gibi bir yazım hatası sessizce göz ardı
        // edilseydi yönetici kilidi koyduğunu sanır, kasa serbest kalırdı.
        $device = $this->makeDevice();

        $this->signed(
            'PATCH',
            '/api/control/kds/devices/'.$device->id.'/settings',
            $this->intent(['settings' => ['allow_settngs' => false]]),
        )->assertStatus(422);

        $this->assertNull($device->refresh()->allow_settings);
    }

    public function test_bos_ayar_govdesi_reddedilir(): void
    {
        $device = $this->makeDevice();

        $this->signed(
            'PATCH',
            '/api/control/kds/devices/'.$device->id.'/settings',
            $this->intent(['settings' => []]),
        )->assertStatus(422);
    }

    public function test_YENI_KILIT_ALANLARI_BUGUNKU_KASALARI_KILITLEMEZ(): void
    {
        // GÖÇÜN EN ÖNEMLİ DAVRANIŞI. Sütunlara `false` varsayılanı
        // konsaydı göç koştuğu saniyede sahadaki bütün kasalar kilitlenir
        // ve kimse sebebini anlamazdı.
        $paired = $this->pairedDevice();

        $settings = $this->withToken($paired['token'])->postJson('/api/kitchen/health', [
            'printer_ok' => true,
            'print_queue_pending' => 0,
            'print_queue_failed' => 0,
        ], self::HEADERS)->assertOk()->json('settings');

        foreach ([
            'allow_settings', 'allow_server_change', 'allow_window_controls',
            'allow_order_edit', 'allow_manual_reprint', 'allow_sales_control',
            'lock_message',
        ] as $key) {
            $this->assertArrayHasKey($key, $settings);
            $this->assertNull($settings[$key], "{$key} dokunulmamışken null olmalı.");
        }
    }

    public function test_kilit_kasaya_saglik_yanitiyla_gider(): void
    {
        $paired = $this->pairedDevice();

        $this->signed(
            'PATCH',
            '/api/control/kds/devices/'.$paired['model']->id.'/settings',
            $this->intent(['settings' => [
                'allow_settings' => false,
                'allow_sales_control' => false,
                'lock_message' => 'Kapalı — yönetici ile görüşün.',
            ]]),
        )->assertOk();

        $settings = $this->withToken($paired['token'])->postJson('/api/kitchen/health', [
            'printer_ok' => true,
            'print_queue_pending' => 0,
            'print_queue_failed' => 0,
        ], self::HEADERS)->assertOk()->json('settings');

        // BOOLEAN OLARAK GİTMELİ: kasa tarafı `bool?` bekliyor ve `1`
        // gelen bir alan Dart'ta ayrıştırma hatası verirdi.
        $this->assertFalse($settings['allow_settings']);
        $this->assertFalse($settings['allow_sales_control']);
        $this->assertNull($settings['allow_order_edit'], 'Dokunulmayan kilit serbest kalmalı.');
        $this->assertSame('Kapalı — yönetici ile görüşün.', $settings['lock_message']);
    }

    public function test_kilit_null_ile_geri_alinir(): void
    {
        $device = $this->makeDevice();

        $this->signed(
            'PATCH',
            '/api/control/kds/devices/'.$device->id.'/settings',
            $this->intent(['settings' => ['allow_settings' => false]]),
        )->assertOk();

        $this->assertFalse((bool) $device->refresh()->allow_settings);

        $this->signed(
            'PATCH',
            '/api/control/kds/devices/'.$device->id.'/settings',
            $this->intent(['settings' => ['allow_settings' => null]]),
        )->assertOk();

        $this->assertNull($device->refresh()->allow_settings);
    }

    // ── 5.5 Olay bazlı sesler (K-22 §1) ───────────────────────────────────

    /** Kasanın gördüğü ayarları döndürür. */
    private function kasaAyarlari(string $token): array
    {
        return $this->withToken($token)->postJson('/api/kitchen/health', [
            'printer_ok' => true,
            'print_queue_pending' => 0,
            'print_queue_failed' => 0,
        ], self::HEADERS)->assertOk()->json('settings');
    }

    private function sesAyari(KitchenDevice $device, ?string $value): TestResponse
    {
        return $this->signed(
            'PATCH',
            '/api/control/kds/devices/'.$device->id.'/settings',
            $this->intent(['settings' => ['disabled_sound_events' => $value]]),
        );
    }

    public function test_ses_olaylari_DOKUNULMAMISKEN_null_gider(): void
    {
        // `null` = "yönetici dokunmadı" = kasa KENDİ listesini korur.
        // Boş dize gitseydi kasa bütün uyarıları açar ve personelin
        // kapattığı yazıcı uyarısı geri gelirdi.
        $paired = $this->pairedDevice();

        $settings = $this->kasaAyarlari($paired['token']);

        $this->assertArrayHasKey('disabled_sound_events', $settings);
        $this->assertNull($settings['disabled_sound_events']);
    }

    public function test_ses_olaylari_listesi_kasaya_iner(): void
    {
        $paired = $this->pairedDevice();

        $this->sesAyari($paired['model'], 'printerError,bbdOrder')->assertOk();

        $this->assertSame(
            'printerError,bbdOrder',
            $this->kasaAyarlari($paired['token'])['disabled_sound_events'],
        );
    }

    public function test_BOS_DIZE_hepsini_acar_ve_null_ILE_KARISTIRILMAZ(): void
    {
        // `audio_sink` ile aynı istisna: `null` "dokunmadı"ya ayrılmış
        // olduğu için yöneticinin kapattığı uyarıyı geri açmasının başka
        // yolu yok.
        $device = $this->makeDevice();

        $this->sesAyari($device, 'newOrder')->assertOk();
        $this->assertSame('newOrder', $device->refresh()->disabled_sound_events);

        $this->sesAyari($device, '')->assertOk();
        $this->assertSame(
            '',
            $device->refresh()->disabled_sound_events,
            'Boş dize korunmalı: "hepsini aç" emri.',
        );

        $this->sesAyari($device, null)->assertOk();
        $this->assertNull(
            $device->refresh()->disabled_sound_events,
            '`null` "dokunmadı"ya geri döndürmeli.',
        );
    }

    public function test_CONNECTION_LOST_SESSIZCE_ELENIR_digerleri_uygulanir(): void
    {
        // Yöneticinin yazım hatası mutfağı sessiz bırakmamalı: isteği 422
        // ile geri çevirmek, gerçekten kapatılmak istenen uyarıların da
        // uygulanmaması demek olurdu.
        $device = $this->makeDevice();

        $this->sesAyari($device, 'connectionLost,printerError')->assertOk();

        $this->assertSame('printerError', $device->refresh()->disabled_sound_events);
    }

    public function test_connectionLost_TEK_BASINA_gelirse_liste_bosalir(): void
    {
        $device = $this->makeDevice();

        $this->sesAyari($device, KitchenDeviceSettings::UNMUTABLE_SOUND_EVENT)
            ->assertOk();

        $this->assertSame('', $device->refresh()->disabled_sound_events);
    }

    public function test_BILINMEYEN_OLAY_ADI_yok_sayilir(): void
    {
        // Sözleşme eklemeli: Kontrol Merkezi kasadan yeni bir sürümde
        // olabilir ve henüz yayımlanmamış bir olayın adını gönderebilir.
        $device = $this->makeDevice();

        $this->sesAyari($device, 'newOrder,fisBitti,lateOrder')->assertOk();

        $this->assertSame('newOrder,lateOrder', $device->refresh()->disabled_sound_events);
    }

    public function test_ses_olaylari_bosluklu_ve_tekrarli_gelse_de_temizlenir(): void
    {
        $device = $this->makeDevice();

        $this->sesAyari($device, ' lateOrder , newOrder ,lateOrder ')->assertOk();

        // Sıra `SOUND_EVENTS` sırasıdır: aynı ayarı iki kez yazmak sütunu
        // değiştirmemeli, yoksa `settings_updated_at` boş yere ilerler.
        $this->assertSame('newOrder,lateOrder', $device->refresh()->disabled_sound_events);
    }

    // ── 5.6 Zenginleştirilmiş telemetri (K-22 §3) ─────────────────────────

    public function test_ESKI_KASANIN_EKSIK_TELEMETRISI_422_URETMEZ(): void
    {
        // GÖÇÜN EN ÖNEMLİ DAVRANIŞI. Alanlar zorunlu olsaydı, sunucu
        // güncellendiği anda sahadaki tüm kasaların sağlık bildirimi 422'ye
        // düşerdi — yani yönetici, kasaların durumunu görmek için eklediği
        // alan yüzünden hiçbirini göremez hâle gelirdi.
        $paired = $this->pairedDevice();

        $this->withToken($paired['token'])->postJson('/api/kitchen/health', [
            'printer_ok' => true,
            'print_queue_pending' => 2,
            'print_queue_failed' => 0,
        ], self::HEADERS)->assertOk();

        $device = $paired['model']->refresh();

        // "Bildirmedi" ile "sorun yok" AYRI: eksik alan `null` kalmalı,
        // `false` olmamalı.
        $this->assertNull($device->last_error);
        $this->assertNull($device->alarm_muted);
        $this->assertNull($device->alarm_mute_reason);
        $this->assertNull($device->queue_oldest_at);
        $this->assertNull($device->sound_ok);
        $this->assertSame(2, $device->print_queue_pending);
    }

    public function test_telemetri_kaydedilir_ve_kontrol_merkezine_dokulur(): void
    {
        $paired = $this->pairedDevice();

        $this->withToken($paired['token'])->postJson('/api/kitchen/health', [
            'printer_ok' => false,
            'print_queue_pending' => 3,
            'print_queue_failed' => 3,
            'last_error' => '#42 mutfak: /dev/thermal0 yok',
            'alarm_muted' => true,
            'alarm_mute_reason' => 'Ses oynatıcısı bulunamadı',
            'queue_oldest_at' => '2026-08-18T07:30:00Z',
            'sound_ok' => false,
        ], self::HEADERS)->assertOk();

        $health = $this->signed('GET', '/api/control/kds/devices')
            ->assertOk()
            ->json('data.0.health');

        $this->assertSame('#42 mutfak: /dev/thermal0 yok', $health['last_error']);
        // BOOLEAN OLARAK GİTMELİ: `1` gelen bir alanı kasa/panel `bool?`
        // olarak ayrıştıramaz.
        $this->assertTrue($health['alarm_muted']);
        $this->assertFalse($health['sound_ok']);
        $this->assertSame('Ses oynatıcısı bulunamadı', $health['alarm_mute_reason']);
        $this->assertSame('2026-08-18T07:30:00Z', $health['queue_oldest_at']);
    }

    public function test_TELEMETRI_BAYATLAMAZ_bildirilmeyen_alan_null_a_doner(): void
    {
        // `app_version`'dan FARKLI: sürüm bir kimliktir ve korunur, bunlar
        // anlık ölçümdür. Çözülmüş bir arızayı panelde sonsuza kadar
        // kırmızı bırakmak, gerçek bir arıza çıktığında kimsenin bakmaması
        // demek olurdu.
        $paired = $this->pairedDevice();

        $this->withToken($paired['token'])->postJson('/api/kitchen/health', [
            'printer_ok' => false,
            'print_queue_pending' => 1,
            'print_queue_failed' => 1,
            'app_version' => '1.1.0',
            'last_error' => 'kâğıt bitti',
            'queue_oldest_at' => '2026-08-18T07:30:00Z',
        ], self::HEADERS)->assertOk();

        $this->assertSame('kâğıt bitti', $paired['model']->refresh()->last_error);

        $this->withToken($paired['token'])->postJson('/api/kitchen/health', [
            'printer_ok' => true,
            'print_queue_pending' => 0,
            'print_queue_failed' => 0,
        ], self::HEADERS)->assertOk();

        $device = $paired['model']->refresh();

        $this->assertNull($device->last_error);
        $this->assertNull($device->queue_oldest_at);
        $this->assertSame('1.1.0', $device->app_version, 'Sürüm bir kimliktir, korunur.');
    }

    public function test_SINIR_ASAN_TELEMETRI_METNI_reddedilir(): void
    {
        // Sessiz kesme yerine açık hata: MySQL'in sütunu kırpması, panelde
        // yarım bir hata metni göstermek demek olurdu.
        $paired = $this->pairedDevice();

        $this->withToken($paired['token'])->postJson('/api/kitchen/health', [
            'printer_ok' => true,
            'print_queue_pending' => 0,
            'print_queue_failed' => 0,
            'last_error' => str_repeat('x', 300),
        ], self::HEADERS)->assertStatus(422);
    }

    // ── 6. Siparişler ve revizyon ─────────────────────────────────────────

    public function test_REVIZYON_UPDATED_AT_BUMPLAR_ve_kds_gorur(): void
    {
        // KDS'İN DEĞİŞİKLİĞİ GÖRMESİNİN TEK YOLU. Yalnız `order_menus`
        // değişip `orders` dokunulmasaydı, merkezden yapılan düzenleme
        // mutfak ekranına HİÇ düşmez, personel eski adedi hazırlardı.
        $order = $this->confirmedOrder(quantity: 5);
        $since = $order->updated_at->copy();
        sleep(1);

        $this->signed(
            'POST',
            '/api/control/kds/orders/'.$order->order_id.'/revisions',
            $this->intent([
                'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 2]],
            ]),
        )->assertOk()->assertJsonPath('revision.revision_no', 1);

        $this->assertTrue($order->refresh()->updated_at->greaterThan($since));

        $ids = $this->asKitchen()->getJson(
            '/api/kitchen/orders?since='.urlencode($since->toIso8601ZuluString()),
            self::HEADERS,
        )->assertOk()->json('data.*.id');

        $this->assertContains((int) $order->order_id, $ids);
    }

    public function test_revizyon_MERKEZ_DAMGASI_tasir_ve_kasa_kimligi_yazmaz(): void
    {
        $order = $this->confirmedOrder(quantity: 4);

        $this->signed(
            'POST',
            '/api/control/kds/orders/'.$order->order_id.'/revisions',
            $this->intent([
                'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 2]],
            ]),
        )->assertOk();

        $row = DB::table('veykemtu_order_revisions')
            ->where('order_id', $order->order_id)
            ->first();

        $this->assertNull(
            $row->created_by_device_id,
            'Merkezden yapılan revizyon bir kasaya yazılmamalı.',
        );
        $this->assertStringContainsString('Kontrol Merkezi · '.self::ACTOR, (string) $row->note);
    }

    public function test_BOS_KALEM_LISTESI_reddedilir(): void
    {
        // Tümünü kaldırmak "iptal" demek DEĞİL; iptalin kendi durumu ve
        // kendi cari kaydı var.
        $order = $this->confirmedOrder();

        $this->signed(
            'POST',
            '/api/control/kds/orders/'.$order->order_id.'/revisions',
            $this->intent(['items' => []]),
        )->assertStatus(422);

        $this->assertSame(
            0,
            DB::table('veykemtu_order_revisions')->where('order_id', $order->order_id)->count(),
        );
    }

    public function test_durum_gecisi_uygulanir_ve_gerekce_gecmise_yazilir(): void
    {
        $order = $this->confirmedOrder();

        $this->signed(
            'POST',
            '/api/control/kds/orders/'.$order->order_id.'/status',
            $this->intent(['status' => OrderStatusTransition::PREPARING]),
        )->assertOk()->assertJsonPath('order.status', OrderStatusTransition::PREPARING);

        $comment = DB::table('status_history')
            ->where('object_id', $order->order_id)
            ->where('object_type', 'orders')
            ->orderByDesc('status_history_id')
            ->value('comment');

        $this->assertStringContainsString('Kontrol Merkezi · '.self::ACTOR, (string) $comment);
    }

    public function test_GECERSIZ_DURUM_GECISI_reddedilir(): void
    {
        // Kararı sunucu verir; Kontrol Merkezi'ndeki matris yalnız
        // düğmeyi gizlemek için.
        $order = $this->confirmedOrder();

        $this->signed(
            'POST',
            '/api/control/kds/orders/'.$order->order_id.'/status',
            $this->intent(['status' => OrderStatusTransition::DELIVERED]),
        )->assertStatus(422)->assertJsonPath('error.code', 'INVALID_TRANSITION');
    }

    public function test_siparis_listesi_ve_detayi_fiyat_tasimaz(): void
    {
        $order = $this->confirmedOrder();

        $list = $this->signed('GET', '/api/control/kds/orders')->assertOk()->json('data');

        $this->assertCount(1, $list);
        $this->assertArrayNotHasKey('total', $list[0]);

        $detail = $this->signed('GET', '/api/control/kds/orders/'.$order->order_id)
            ->assertOk()
            ->json('data');

        $this->assertSame((int) $order->order_id, $detail['id']);
        $this->assertArrayNotHasKey('total', $detail);
    }

    public function test_olmayan_siparis_404_doner(): void
    {
        $this->signed('GET', '/api/control/kds/orders/999999')
            ->assertStatus(404)
            ->assertJsonPath('error.code', 'NOT_FOUND');
    }

    public function test_urun_secici_fiyat_ve_secenek_kimlikleri_tasir(): void
    {
        // `menu_id` kimsenin ezberinde değil; elle yazılan bir kimlik
        // siparişe başka bir ürün koyar. Seçenek KİMLİKLERİ de şart:
        // `LineResolver` satırı `option_value_ids` ile fiyatlıyor ve
        // yalnız ad gönderilseydi seçenek sessizce düşerdi.
        $items = $this->signed('GET', '/api/control/kds/menu')->assertOk()->json('data');

        $this->assertNotEmpty($items);

        $tavuk = collect($items)->firstWhere('menu_id', $this->menuId('Tavuk Sote'));

        $this->assertNotNull($tavuk);
        $this->assertSame('Tavuk Sote', $tavuk['name']);
        $this->assertIsInt($tavuk['price_kurus']);
        $this->assertGreaterThan(0, $tavuk['price_kurus']);
        $this->assertArrayHasKey('options', $tavuk);

        foreach ($tavuk['options'] as $option) {
            foreach ($option['values'] as $value) {
                $this->assertIsInt($value['id']);
            }
        }
    }

    public function test_urun_secici_TUKENDI_ISARETINI_tasir(): void
    {
        // İşaretsiz bırakmak, mutfağın bugün yapamayacağı bir kalemi
        // siparişe koydururdu.
        $paired = $this->pairedDevice();
        $menuId = $this->menuId('Tavuk Sote');

        $this->withToken($paired['token'])->postJson('/api/kitchen/menu-availability', [
            'menu_id' => $menuId,
            'sold_out' => true,
        ], self::HEADERS)->assertOk();

        $items = $this->signed('GET', '/api/control/kds/menu')->assertOk()->json('data');

        $this->assertTrue(collect($items)->firstWhere('menu_id', $menuId)['sold_out']);
    }

    // ── 7. Fiş denetimi ve özet ───────────────────────────────────────────

    public function test_fis_denetim_kaydi_listelenir(): void
    {
        $order = $this->confirmedOrder();
        $paired = $this->pairedDevice();

        $this->withToken($paired['token'])->postJson(
            '/api/kitchen/print-jobs/'.$order->order_id.'/ack',
            ['type' => 'mutfak', 'printed_at' => Carbon::now()->toIso8601ZuluString()],
            self::HEADERS,
        )->assertNoContent();

        $this->signed('GET', '/api/control/kds/print-jobs')
            ->assertOk()
            ->assertJsonPath('data.0.order_id', (int) $order->order_id)
            ->assertJsonPath('data.0.type', 'mutfak')
            ->assertJsonPath('data.0.revision', 0)
            ->assertJsonPath('data.0.device_name', 'Test Kasası');
    }

    public function test_ozet_cihaz_ve_siparis_sayilarini_verir(): void
    {
        // AYRICA `pairedDevice()` ÇAĞRILMIYOR: `confirmedOrder()` içindeki
        // `advance()` zaten bir kasa eşliyor ve ikincisi sayıyı şişirirdi.
        $order = $this->confirmedOrder();

        $this->signed('GET', '/api/control/kds/overview')
            ->assertOk()
            ->assertJsonPath('devices.total', 1)
            ->assertJsonPath('devices.revoked', 0)
            ->assertJsonPath('devices.printer_fault', 0)
            ->assertJsonPath('orders.active', 1)
            ->assertJsonPath('orders.by_status.'.OrderStatusTransition::CONFIRMED, 1)
            ->assertJsonPath('orders.by_status.'.OrderStatusTransition::NEW, 0)
            ->assertJsonPath('orders.today', 1)
            ->assertJsonPath('print_jobs.today', 0);

        $this->assertNotNull($order->order_id);
    }

    public function test_ozet_IPTAL_EDILEN_KASAYI_cevrimici_saymaz(): void
    {
        // İptal edilmiş kasa dakikalar önce görülmüş olabilir ama artık
        // hiçbir uca giremez; "çevrimiçi" göstermek yöneticiye çalışan bir
        // mutfak ekranı olduğunu düşündürürdü.
        $paired = $this->pairedDevice();
        $paired['model']->revoke();

        $this->signed('GET', '/api/control/kds/overview')
            ->assertOk()
            ->assertJsonPath('devices.total', 1)
            ->assertJsonPath('devices.revoked', 1)
            ->assertJsonPath('devices.online', 0);
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    /**
     * İmzalı istek.
     *
     * `signPath` / `signMethod` / `signBody` yalnız TESTLER İÇİN var:
     * imzanın hangi dört şeye bağlandığını tek tek kırabilmek gerekiyor.
     *
     * @param  array<string, mixed>|string|null  $body
     */
    private function signed(
        string $method,
        string $path,
        array|string|null $body = null,
        ?string $nonce = null,
        ?int $timestamp = null,
        ?string $signPath = null,
        ?string $signMethod = null,
        ?string $signBody = null,
    ): TestResponse {
        $raw = is_array($body) ? $this->body($body) : (string) ($body ?? '');
        $timestamp ??= time();
        $nonce ??= bin2hex(random_bytes(12));

        $canonical = implode("\n", [
            strtoupper($signMethod ?? $method),
            // Sorgu dizesi imzaya GİRMEZ — middleware `getPathInfo()`
            // okuyor ve iki taraf sorgu sırasını tutturamazdı.
            $signPath ?? (string) parse_url($path, PHP_URL_PATH),
            (string) $timestamp,
            $nonce,
            hash('sha256', $signBody ?? $raw),
        ]);

        return $this->call($method, $path, [], [], [], [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_X_CONTROL_TIMESTAMP' => (string) $timestamp,
            'HTTP_X_CONTROL_NONCE' => $nonce,
            'HTTP_X_CONTROL_SIGNATURE' => 'sha256='.hash_hmac('sha256', $canonical, self::SECRET),
        ], $raw);
    }

    /** @param array<string, mixed> $payload */
    private function body(array $payload): string
    {
        return (string) json_encode($payload, JSON_UNESCAPED_UNICODE);
    }

    /**
     * Gövdeye zorunlu `actor` + `reason` alanlarını ekler.
     *
     * @param  array<string, mixed>  $extra
     * @return array<string, mixed>
     */
    private function intent(array $extra = []): array
    {
        return ['actor' => self::ACTOR, 'reason' => self::REASON, ...$extra];
    }

    private function makeDevice(string $name = 'Mutfak Kasası'): KitchenDevice
    {
        $device = new KitchenDevice;
        $device->name = $name;
        $device->save();

        return $device;
    }

    private function confirmedOrder(int $quantity = 2): Order
    {
        $created = $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => $quantity]],
            'delivery_type' => 'delivery',
            'payment_method' => 'cash',
            'address' => [
                'line1' => 'Örnek Mah. 12. Sk No:3',
                'district' => 'Selçuklu',
                'city' => 'Konya',
            ],
        ], self::HEADERS)->assertCreated()->json();

        $this->advance((int) $created['id'], [OrderStatusTransition::CONFIRMED]);

        return Order::findOrFail((int) $created['id']);
    }
}
