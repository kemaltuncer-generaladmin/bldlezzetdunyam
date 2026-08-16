<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Illuminate\Support\Carbon;
use Illuminate\Testing\TestResponse;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Models\KitchenCommand;

/**
 * Komut teslimatının SINIRLARI — `K-23`.
 *
 * SAHADAKİ BELİRTİ: mutfak ekranı her on dakikada bir test fişi
 * basıyordu. Sunucu tarafındaki sebep tek cümleyle şuydu: sonucu
 * gelmemiş bir komutun yeniden teslim edilmesinin BİR SONU YOKTU.
 * `pendingFor()` `executed_at IS NULL` olan her satırı on dakikalık
 * pencerede geri veriyor, `takeCommands()` de `delivered_at`'i yeniden
 * damgalayıp saati sıfırlıyordu.
 *
 * Buradaki testler o sonu ölçüyor ve YALNIZ ONU: `ControlKdsTest` komut
 * kanalının çalıştığını zaten kanıtlıyor, bu dosya çalışmayı ne zaman
 * BIRAKTIĞINI kanıtlıyor.
 */
class KitchenCommandTest extends KitchenTestCase
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

    protected function tearDown(): void
    {
        // Zaman yolculuğu yapan testler sızdırmasın: sabit saat başka bir
        // testte "sipariş bugün girilmedi" gibi anlaşılmaz düşüşler yapar.
        Carbon::setTestNow();

        parent::tearDown();
    }

    // ── 1. Deneme sayacı ──────────────────────────────────────────────────

    public function test_ONAYLANMAYAN_KOMUT_UC_KEZ_teslim_edilir_dorduncude_edilmez(): void
    {
        // DÖNGÜNÜN KENDİSİ. Sayaç yokken bu döngünün duracağı bir yer
        // yoktu; kasa sonucu bildiremediği sürece fiş sonsuza kadar
        // basılıyordu.
        $paired = $this->pairedDevice();

        // `expires_at` BİLEREK BOŞ: bu test YALNIZ sayacı ölçüyor. Otuz
        // dakikalık varsayılan süre bırakılsaydı dördüncü atım zaten
        // süreden düşerdi ve sayacın çalışıp çalışmadığı görünmezdi.
        $row = $this->queueRaw($paired['model']->id, KitchenCommand::TEST_RECEIPT);

        $start = Carbon::now();

        foreach ([0, 11, 22] as $deneme => $dakika) {
            Carbon::setTestNow($start->copy()->addMinutes($dakika));

            $commands = $this->health($paired['token']);

            $this->assertCount(1, $commands, sprintf(
                '%d. deneme teslim edilmeliydi.',
                $deneme + 1,
            ));
            $this->assertSame((int) $row->id, $commands[0]['id']);
        }

        Carbon::setTestNow($start->copy()->addMinutes(33));

        $this->assertSame([], $this->health($paired['token']));

        // KESİN SONUCA BAĞLANMALI: yalnız kuyruktan düşürmek yetmez,
        // satır `executed_at`'i boş kaldığı sürece Kontrol Merkezi'nde
        // sonsuza kadar "uçuşta" görünürdü.
        $row->refresh();

        $this->assertSame(KitchenCommand::MAX_ATTEMPTS, (int) $row->attempts);
        $this->assertNotNull($row->executed_at);
        $this->assertFalse((bool) $row->succeeded);
        $this->assertSame('Kasaya ulaşmadı (3 deneme)', $row->result);
    }

    public function test_ONAYLANAN_KOMUT_asla_yeniden_teslim_edilmez(): void
    {
        $paired = $this->pairedDevice();
        $row = $this->queueRaw($paired['model']->id, KitchenCommand::TEST_RECEIPT);

        $start = Carbon::now();
        $commands = $this->health($paired['token']);

        $this->assertCount(1, $commands);

        $this->health($paired['token'], [[
            'id' => $commands[0]['id'],
            'ok' => true,
            'message' => 'Test fişi basıldı',
        ]]);

        // Yeniden teslim penceresinin çok ötesine geçiyoruz.
        Carbon::setTestNow($start->copy()->addMinutes(45));

        $this->assertSame([], $this->health($paired['token']));

        $row->refresh();

        $this->assertTrue((bool) $row->succeeded);
        $this->assertSame('Test fişi basıldı', $row->result);
        $this->assertSame(1, (int) $row->attempts);
    }

    // ── 2. Son kullanma ───────────────────────────────────────────────────

    public function test_SURESI_GECMIS_KOMUT_hic_teslim_edilmez_ve_kapatilir(): void
    {
        // `attempts` ULAŞILABİLEN kasayı sınırlıyor, bu damga
        // ULAŞILAMAYANI: hafta sonu kapalı kalan bir kasada sayaç hâlâ
        // sıfırdır ve pazartesi açıldığında cuma akşamından kalma bir test
        // fişi basılırdı.
        $paired = $this->pairedDevice();

        $row = $this->queueRaw(
            $paired['model']->id,
            KitchenCommand::TEST_RECEIPT,
            expiresAt: Carbon::now()->subMinute(),
        );

        $this->assertSame([], $this->health($paired['token']));

        $row->refresh();

        $this->assertSame(0, (int) $row->attempts, 'Hiç teslim edilmemeliydi.');
        $this->assertNotNull($row->executed_at);
        $this->assertFalse((bool) $row->succeeded);
        $this->assertSame('Süresi doldu, kasaya ulaşmadı', $row->result);
    }

    public function test_KOMUT_SON_KULLANMA_DAMGASIYLA_kuyruga_girer(): void
    {
        // `restart`, `update` ve `unpair` yapısal olarak sonuçlarının
        // dönmemesini garanti ediyor (`restart` iki saniye sonra
        // `exit(0)`, `unpair` token'ı siliyor). Onları kesin sonuca
        // bağlayan tek şey bu damga; kuyruğa damgasız girselerdi
        // panelde sonsuza kadar "uçuşta" kalırlardı.
        $device = $this->pairedDevice()['model'];

        $this->sendCommand($device->id, KitchenCommand::RESTART)->assertOk();

        $row = KitchenCommand::query()->where('device_id', $device->id)->firstOrFail();

        $this->assertNotNull($row->expires_at);
        $this->assertEqualsWithDelta(
            KitchenCommand::DEFAULT_TTL_MINUTES,
            Carbon::now()->diffInMinutes($row->expires_at, absolute: true),
            1.0,
        );
    }

    // ── 3. Yinelenen komut ────────────────────────────────────────────────

    public function test_IKI_DAKIKA_ICINDE_AYNI_KOMUT_tek_satir_acar(): void
    {
        // Yönetici "olmadı" deyip aynı düğmeye ikinci kez bastığında iki
        // bağımsız komut açılıyordu ve her biri kendi yeniden teslim
        // döngüsünü kuruyordu: mutfak iki, üç, dört test fişi görüyordu.
        $device = $this->pairedDevice()['model'];

        $first = $this->sendCommand($device->id, KitchenCommand::TEST_RECEIPT)
            ->assertOk()
            ->assertJsonPath('deduped', false);

        $second = $this->sendCommand($device->id, KitchenCommand::TEST_RECEIPT)
            ->assertOk()
            ->assertJsonPath('deduped', true);

        $this->assertSame(
            1,
            KitchenCommand::query()->where('device_id', $device->id)->count(),
        );

        // AYNI SATIR geri dönmeli: "gönderildi" yazan ama başka bir
        // kimlik veren bir yanıt, panelin iki komutu takip ettiğini
        // sanmasına yol açardı.
        $this->assertSame(
            $first->json('command.id'),
            $second->json('command.id'),
        );
    }

    public function test_TESLIM_EDILDIKTEN_SONRA_ayni_komut_yeniden_gonderilebilir(): void
    {
        // Yinelenme koruması yalnız KUYRUKTA BEKLEYEN komut içindir.
        // Fiş basıldıktan sonra "bir tane daha" demek meşru bir istek ve
        // korumanın onu yutması, düğmeyi bozuk gösterirdi.
        $paired = $this->pairedDevice();

        $this->sendCommand($paired['model']->id, KitchenCommand::TEST_RECEIPT)->assertOk();
        $this->assertCount(1, $this->health($paired['token']));

        $this->sendCommand($paired['model']->id, KitchenCommand::TEST_RECEIPT)
            ->assertOk()
            ->assertJsonPath('deduped', false);

        $this->assertSame(
            2,
            KitchenCommand::query()->where('device_id', $paired['model']->id)->count(),
        );
    }

    public function test_REPRINT_YINELENME_KORUMASININ_DISINDA(): void
    {
        // AYNI FİŞİ İKİNCİ KEZ BASMAK bu düğmenin TEK VARLIK SEBEBİ.
        // Yinelenme koruması buraya uygulansaydı mutfak "fiş yırtıldı,
        // tekrar bas" dediğinde hiçbir şey olmazdı.
        $device = $this->pairedDevice()['model'];
        $payload = ['order_id' => 42, 'type' => 'mutfak'];

        $this->sendCommand($device->id, KitchenCommand::REPRINT, $payload)
            ->assertOk()
            ->assertJsonPath('deduped', false);

        $this->sendCommand($device->id, KitchenCommand::REPRINT, $payload)
            ->assertOk()
            ->assertJsonPath('deduped', false);

        $this->assertSame(
            2,
            KitchenCommand::query()->where('device_id', $device->id)->count(),
        );

        $this->assertNull(
            KitchenCommand::dedupeKeyFor(KitchenCommand::REPRINT, $payload),
            'Yeniden basım anahtar taşımamalı; taşısaydı tekil dizin ikinciyi düşürürdü.',
        );
    }

    public function test_IKI_FARKLI_KASAYA_ayni_komut_gonderilebilir(): void
    {
        // Anahtar komut adı ile yükten türüyor, yani iki kasada AYNI
        // çıkıyor. Tekil dizin cihaz kapsamlı olmasaydı ikinci mutfak
        // test fişi basamazdı.
        $first = $this->pairedDevice()['model'];

        $second = $this->pairedDevice()['model'];

        $this->sendCommand($first->id, KitchenCommand::TEST_RECEIPT)
            ->assertOk()
            ->assertJsonPath('deduped', false);

        $this->sendCommand($second->id, KitchenCommand::TEST_RECEIPT)
            ->assertOk()
            ->assertJsonPath('deduped', false);

        $this->assertSame(2, KitchenCommand::query()->count());
    }

    public function test_PENCERE_KAPANDIKTAN_SONRA_ikinci_komut_acilir(): void
    {
        // Çevrimdışı bir kasada bekleyen eski satır, tekil dizin yüzünden
        // yeni komutu veritabanı hatasıyla düşürebilirdi. Anahtar iki
        // dakikalık pencereyi korur, satırın ömrünü DEĞİL.
        $device = $this->pairedDevice()['model'];
        $start = Carbon::now();

        $this->sendCommand($device->id, KitchenCommand::TEST_RECEIPT)->assertOk();

        Carbon::setTestNow($start->copy()->addMinutes(3));

        $this->sendCommand($device->id, KitchenCommand::TEST_RECEIPT)
            ->assertOk()
            ->assertJsonPath('deduped', false);

        $this->assertSame(
            2,
            KitchenCommand::query()->where('device_id', $device->id)->count(),
        );
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    /**
     * Doğrudan satır açar — kontrol ucunun varsayılanlarını atlayarak.
     *
     * Sayaç ve son kullanma testleri başlangıç durumunu kendisi kurmak
     * zorunda; uçtan geçmek `expires_at`'i her seferinde otuz dakika
     * ileriye alır ve iki mekanizma birbirine karışırdı.
     */
    private function queueRaw(
        int $deviceId,
        string $command,
        ?Carbon $expiresAt = null,
    ): KitchenCommand {
        return KitchenCommand::create([
            'device_id' => $deviceId,
            'command' => $command,
            'payload' => null,
            'expires_at' => $expiresAt,
            'created_at' => Carbon::now(),
            'updated_at' => Carbon::now(),
        ]);
    }

    /**
     * Bir sağlık atımı; dönen komut listesini verir.
     *
     * @param  list<array<string, mixed>>  $results
     * @return list<array<string, mixed>>
     */
    private function health(string $token, array $results = []): array
    {
        return $this->withToken($token)->postJson('/api/kitchen/health', [
            'printer_ok' => true,
            'print_queue_pending' => 0,
            'print_queue_failed' => 0,
            ...($results === [] ? [] : ['command_results' => $results]),
        ], self::HEADERS)->assertOk()->json('commands');
    }

    /** @param array<string, mixed>|null $payload */
    private function sendCommand(int $deviceId, string $command, ?array $payload = null): TestResponse
    {
        return $this->signed(
            'POST',
            '/api/control/kds/devices/'.$deviceId.'/commands',
            [
                'actor' => self::ACTOR,
                'reason' => self::REASON,
                'command' => $command,
                ...($payload === null ? [] : ['payload' => $payload]),
            ],
        );
    }

    /**
     * İmzalı Kontrol Merkezi isteği (`ControlKdsTest` ile aynı kanon).
     *
     * @param  array<string, mixed>  $body
     */
    private function signed(string $method, string $path, array $body = []): TestResponse
    {
        $raw = (string) json_encode($body, JSON_UNESCAPED_UNICODE);

        // ZAMAN DAMGASI GERÇEK SAATTEN. Testler `Carbon::setTestNow()` ile
        // ileri gidiyor ama imza penceresini doğrulayan katman sistem
        // saatine bakıyor; sabit saatten damga vurmak istekleri pencere
        // dışına atardı.
        $timestamp = time();
        $nonce = bin2hex(random_bytes(12));

        $canonical = implode("\n", [
            strtoupper($method),
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
}
