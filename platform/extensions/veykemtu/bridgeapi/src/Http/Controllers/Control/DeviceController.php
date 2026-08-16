<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Control;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Validation\Rule;
use Veykemtu\BridgeApi\Admin\KitchenDevicePanel;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ControlAudit;
use Veykemtu\BridgeApi\Models\KitchenCommand;
use Veykemtu\BridgeApi\Models\KitchenDevice;
use Veykemtu\BridgeApi\Models\PrintJob;
use Veykemtu\BridgeApi\Services\KitchenDeviceSettings;

/**
 * Kontrol Merkezi — kasa yönetimi (`/api/control/kds/devices`).
 *
 * Admin panelindeki `Http\Controllers\Admin\KitchenDevices` ekranının
 * makine okunur karşılığı. DAVRANIŞ BİREBİR AYNI: eşleme kodu
 * `refreshPairingCode()` ile üretilir ve 10 dakika yaşar, iptal
 * `revoke()` ile yapılır ve SATIR SİLİNMEZ, komut kuyruğa girer ve
 * kasanın bir sonraki sağlık bildiriminde teslim edilir.
 *
 * İki yüzey aynı modeli ve aynı servisi çağırıyor; ayrı bir "API sürümü"
 * yazılsaydı ilk davranış farkı sahada yönetici ile Kontrol Merkezi'nin
 * farklı sonuç almasıyla ortaya çıkardı.
 */
class DeviceController extends ControlController
{
    public function __construct(private readonly KitchenDeviceSettings $settings) {}

    public function index(): JsonResponse
    {
        $devices = KitchenDevice::query()->orderBy('id')->get();

        return $this->json([
            'data' => $devices
                ->map(fn(KitchenDevice $device): array => $this->device($device))
                ->all(),
            'server_time' => $this->serverTime(),
        ]);
    }

    /**
     * Yeni kasa + ilk eşleme kodu.
     *
     * Kod kaydın hemen ardından üretiliyor — admin ekranındaki
     * `formAfterCreate` ile aynı gerekçe: "cihazı ekledim ama
     * eşleyemiyorum" diye ikinci bir adım aranmasın.
     */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:64'],
        ]);

        $name = trim((string) $data['name']);

        return $this->write(
            $request,
            'device.create',
            ControlAudit::TARGET_DEVICE,
            null,
            ['name' => $name],
            fn(): array => [
                'action' => 'device.create',
                'name' => $name,
                'pairing_ttl_minutes' => KitchenDevice::PAIRING_TTL_MINUTES,
            ],
            function () use ($name): array {
                $device = new KitchenDevice;
                $device->name = $name;
                $device->save();
                $device->refreshPairingCode();

                return ['device' => $this->device($device, revealPairingCode: true)];
            },
        );
    }

    /** Yalnız ad. Ayarlar ayrı uçtan, kilitler de o ucun içinden yazılır. */
    public function update(Request $request, int $device): JsonResponse
    {
        $model = $this->findDevice($device);

        $data = $request->validate([
            'name' => ['required', 'string', 'max:64'],
        ]);

        $name = trim((string) $data['name']);

        return $this->write(
            $request,
            'device.rename',
            ControlAudit::TARGET_DEVICE,
            (int) $model->id,
            ['from' => (string) $model->name, 'to' => $name],
            fn(): array => [
                'action' => 'device.rename',
                'from' => (string) $model->name,
                'to' => $name,
            ],
            function () use ($model, $name): array {
                $model->name = $name;
                $model->save();

                return ['device' => $this->device($model)];
            },
        );
    }

    /**
     * Yeni eşleme kodu — 10 dakika ömürlü, tek kullanımlık.
     *
     * İPTAL EDİLMİŞ KASAYA KOD ÜRETİLMEZ: `pairingCodeIsUsable()` zaten
     * iptali eleyip kodu geçersiz sayardı, yani üretilen kod sessizce
     * çalışmayan bir kod olurdu. Admin ekranı da aynı noktada duruyor.
     */
    public function pairingCode(Request $request, int $device): JsonResponse
    {
        $model = $this->findDevice($device);

        return $this->write(
            $request,
            'device.pairing_code',
            ControlAudit::TARGET_DEVICE,
            (int) $model->id,
            ['ttl_minutes' => KitchenDevice::PAIRING_TTL_MINUTES],
            function () use ($model): array {
                $this->assertNotRevoked($model);

                return [
                    'action' => 'device.pairing_code',
                    'device_id' => (int) $model->id,
                    'pairing_ttl_minutes' => KitchenDevice::PAIRING_TTL_MINUTES,
                ];
            },
            function () use ($model): array {
                $this->assertNotRevoked($model);
                $model->refreshPairingCode();

                return ['device' => $this->device($model, revealPairingCode: true)];
            },
        );
    }

    /**
     * Kasayı iptal eder. SATIR DA TOKEN DA SİLİNMEZ.
     *
     * Token'ın kasten bırakılmasının gerekçesi `KitchenDevice::revoke()`
     * sınıf yorumunda: silinen token `401 UNAUTHENTICATED` üretir ve
     * KDS'in beklediği `403 DEVICE_REVOKED` dalına hiç ulaşılmaz, yani
     * mutfak "eşleme iptal edildi" yerine genel bir oturum hatası görür.
     *
     * İKİNCİ İPTAL DAMGAYI OYNATMAZ: `revoked_at` "ne zaman iptal
     * edildi" sorusunun cevabı ve denetim değeri ilk damgadadır.
     */
    public function revoke(Request $request, int $device): JsonResponse
    {
        $model = $this->findDevice($device);

        return $this->write(
            $request,
            'device.revoke',
            ControlAudit::TARGET_DEVICE,
            (int) $model->id,
            ['name' => (string) $model->name, 'already_revoked' => $model->isRevoked()],
            fn(): array => [
                'action' => 'device.revoke',
                'device_id' => (int) $model->id,
                'already_revoked' => $model->isRevoked(),
            ],
            function () use ($model): array {
                if (!$model->isRevoked()) {
                    $model->revoke();
                }

                return ['device' => $this->device($model)];
            },
        );
    }

    /**
     * Yönetilen ayarları yazar — KISMİ.
     *
     * AYARLAR `settings` NESNESİNİN ALTINDA, GÖVDENİN KÖKÜNDE DEĞİL.
     * Kökte olsalardı `reason`/`actor`/`dry_run` ile aynı ad alanını
     * paylaşırlardı ve `reason` adında bir ayar eklemek imkânsız hâle
     * gelirdi. Ayrıca `GET /devices` yanıtındaki `device.settings` ile
     * simetrik: okunan biçim ile yazılan biçim aynı.
     *
     * Gönderilmeyen anahtar değişmez, `null` gönderilen anahtar
     * "yönetici dokunmadı"ya geri döner. Sınırların kırpılması ve
     * "geciken ≥ uyarı" kuralı `KitchenDeviceSettings`'te; burada
     * yalnızca tip ve aralık doğrulaması var ki kırpma SESSİZ olmasın.
     */
    public function updateSettings(Request $request, int $device): JsonResponse
    {
        $model = $this->findDevice($device);

        $request->validate([
            'settings' => ['required', 'array'],
            ...$this->settingRules(),
        ]);

        /*
         * GÖNDERİLEN NESNE `validated()`'DAN DEĞİL, GİRDİDEN OKUNUYOR.
         *
         * Laravel iç içe kural tanımlanmış bir dizinin kendisini
         * `validated()` çıktısından düşürüyor ve yalnız kural karşılığı
         * olan alt anahtarları geri veriyor. Sonuç: tamamı tanınmayan
         * anahtarlardan oluşan bir `settings` nesnesi çıktıda HİÇ
         * görünmüyordu ve aşağıdaki "tanınmayan anahtar" denetimi
         * çalışamadan patlıyordu. Doğrulama yine yukarıda yapılıyor;
         * burada okunan şey isteğin ham niyeti.
         */
        /** @var array<string, mixed> $sent */
        $sent = $this->restoreEmptyStrings(
            (array) $request->input('settings', []),
            $request,
        );

        $known = $this->settingKeys($model);
        $provided = array_intersect_key($sent, array_flip($known));

        /*
         * TANINMAYAN ANAHTAR SESSİZCE YUTULMAZ.
         *
         * Bu uç kilit yazıyor: `allow_settngs: false` gibi bir yazım
         * hatası sessizce göz ardı edilseydi, yönetici kilidi koyduğunu
         * sanır ve kasa serbest kalırdı. Yanlış olduğunu ancak birinin o
         * ekrana girmesiyle öğrenirdik.
         */
        $unknown = array_keys(array_diff_key($sent, array_flip($known)));

        if ($unknown !== []) {
            throw ApiException::validationFailed(
                'Tanınmayan ayar anahtarı gönderildi.',
                ['settings' => 'Bilinmeyen anahtarlar: '.implode(', ', $unknown)],
            );
        }

        if ($provided === []) {
            throw ApiException::validationFailed(
                'En az bir ayar gönderilmeli.',
                ['settings' => 'Yönetilen ayar anahtarlarından hiçbiri gövdede yok.'],
            );
        }

        return $this->write(
            $request,
            'device.settings',
            ControlAudit::TARGET_DEVICE,
            (int) $model->id,
            ['keys' => array_keys($provided), 'settings' => $provided],
            fn(): array => [
                'action' => 'device.settings',
                'device_id' => (int) $model->id,
                'settings' => $provided,
            ],
            function () use ($model, $provided): array {
                $this->settings->update($model, $provided);

                return ['device' => $this->device($model->refresh())];
            },
        );
    }

    /** Son 50 komut, üç damgasıyla. */
    public function commands(int $device): JsonResponse
    {
        $model = $this->findDevice($device);

        // LİSTELEMEDEN ÖNCE SÜPÜR. Hiç dönmeyen bir kasanın komutları
        // yalnız sağlık atımında süpürülseydi, o kasa için satır sonsuza
        // kadar "uçuşta" görünürdü — yani tam da kapanmayan bir cevabı
        // beklemek. Yazma bir GET içinde ama karar sunucunun: zaman
        // geçtiği için verilmiş, istek geldiği için değil.
        KitchenCommand::sweepStale((int) $model->id);

        $rows = KitchenCommand::query()
            ->where('device_id', $model->id)
            ->orderByDesc('id')
            ->limit(50)
            ->get()
            ->map(static fn(KitchenCommand $command): array => [
                'id' => (int) $command->id,
                'command' => (string) $command->command,
                'payload' => $command->payload ?? [],
                'created_at' => self::ts($command->created_at),
                // Üç damga, üç ayrı soru: gönderildi mi, kasaya ulaştı mı,
                // çalıştı mı? Tek bir "durum" alanı "kasa aldı ama
                // çalıştıramadı" hâlini anlatamazdı.
                'delivered_at' => self::ts($command->delivered_at),
                'executed_at' => self::ts($command->executed_at),
                'succeeded' => $command->succeeded,
                'result' => $command->result,
                // Kaç kez denendi ve ne zaman vazgeçilecek (`K-23`).
                // Damgalar "ulaştı mı" der, bu ikisi "daha kaç şansı var"
                // der; yönetici sahaya gitme kararını buna bakarak verir.
                'attempts' => (int) $command->attempts,
                'max_attempts' => KitchenCommand::MAX_ATTEMPTS,
                'expires_at' => self::ts($command->expires_at),
            ])
            ->all();

        return $this->json([
            'data' => $rows,
            'server_time' => $this->serverTime(),
        ]);
    }

    /**
     * Kasaya tek seferlik komut kuyruklar.
     *
     * ANINDA DEĞİL: komut kasanın bir sonraki sağlık bildiriminin
     * yanıtına biniyor (`KitchenController::health`). Yanıttaki
     * `arrives_within_seconds` bunu açıkça söylüyor — söylenmezse
     * Kontrol Merkezi'ndeki kullanıcı "olmadı" deyip aynı düğmeye
     * tekrar basar ve iki fiş çıkar.
     */
    public function sendCommand(Request $request, int $device): JsonResponse
    {
        $model = $this->findDevice($device);

        $data = $request->validate([
            'command' => ['required', 'string', Rule::in(KitchenCommand::ALL)],
            'payload' => ['sometimes', 'nullable', 'array'],
            'payload.order_id' => [
                'required_if:command,'.KitchenCommand::REPRINT,
                'integer',
                'min:1',
            ],
            'payload.type' => [
                'required_if:command,'.KitchenCommand::REPRINT,
                'string',
                Rule::in(PrintJob::TYPES),
            ],
        ]);

        $command = (string) $data['command'];
        $payload = $this->commandPayload($command, $data);

        return $this->write(
            $request,
            'device.command',
            ControlAudit::TARGET_DEVICE,
            (int) $model->id,
            ['command' => $command, 'payload' => $payload],
            function () use ($model, $command, $payload): array {
                $this->assertNotRevoked($model);

                return [
                    'action' => 'device.command',
                    'device_id' => (int) $model->id,
                    'command' => $command,
                    'payload' => $payload,
                    'arrives_within_seconds' => KitchenDevicePanel::commandArrivalSeconds($model),
                ];
            },
            function () use ($model, $command, $payload): array {
                $this->assertNotRevoked($model);

                // Süresi geçmiş bir satır, yeni basılan düğmeyi
                // yinelenmiş saymamalı: önce kapananları kapat.
                KitchenCommand::sweepStale((int) $model->id);

                $queued = KitchenCommand::queueFor((int) $model->id, $command, $payload);
                $row = $queued['command'];

                return [
                    'command' => [
                        'id' => (int) $row->id,
                        'command' => $command,
                        'payload' => $payload ?? [],
                        'created_at' => self::ts($row->created_at),
                        'expires_at' => self::ts($row->expires_at),
                    ],
                    /*
                     * YİNELENDİ Mİ? — `K-23` §4.
                     *
                     * Aynı düğmeye iki kez basmak iki bağımsız komut
                     * açıyordu ve her biri kendi on dakikalık yeniden
                     * teslim döngüsünü kuruyordu: mutfak iki, üç, dört
                     * test fişi görüyordu.
                     *
                     * Alan YANITTA DÖNÜYOR, sessizce yutulmuyor: ikinci
                     * basışta hiçbir şey olmadığını gizleyen bir ekran
                     * yöneticiyi üçüncü kez bastırır. `reprint` bu
                     * korumanın dışında — aynı fişi yeniden basmak o
                     * düğmenin tek varlık sebebi.
                     */
                    'deduped' => $queued['deduped'],
                    'arrives_within_seconds' => KitchenDevicePanel::commandArrivalSeconds($model),
                ];
            },
        );
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    /**
     * `ConvertEmptyStringsToNull`'ın yuttuğu BOŞ DİZELERİ geri koyar.
     *
     * NEDEN GEREKLİ — sessiz ve bu uçta anlam bozan bir tuzak:
     *
     * Laravel'in genel `ConvertEmptyStringsToNull` middleware'i (bkz.
     * `app/Http/Kernel.php`) gövdedeki her `""` değerini `null`'a çeviriyor.
     * Bu uçta ikisi AYRI EMİRDİR ve karıştırılamaz:
     *
     *   * `null` = "yönetici bu ayara dokunmadı" → kasa kendi değerini korur,
     *   * `""`   = "seçimimi geri al, varsayılana dön".
     *
     * Boş dizeye anlam yükleyen üç ayar var: `audio_sink` ("varsayılan
     * çıkışa dön"), `lock_message` ("özel metni kaldır") ve K-22 ile gelen
     * `disabled_sound_events` ("hiçbiri kapalı olmasın"). Middleware
     * yüzünden bu üç emir tele hiç çıkmıyordu: yönetici "hepsini aç"
     * dediğinde sunucu "dokunmadı" anlıyor ve KASA ESKİ LİSTESİNİ KORUYORDU.
     * Yani kapatılmış bir uyarıyı Kontrol Merkezi'nden geri açmanın hiçbir
     * yolu yoktu.
     *
     * HAM GÖVDE OKUNUYOR, `$request->json()` DEĞİL: middleware JSON
     * torbasını da temizliyor (`TransformsRequest::clean`). Ham içerik ise
     * isteğin geldiği hâliyle duruyor.
     *
     * DOĞRULAMA YİNE TEMİZLENMİŞ VERİ ÜZERİNDE koşuyor ve bu sorun değil:
     * kurallar `nullable` ve boş dize orada `null` olarak zaten geçiyor;
     * uzunluk sınırları da boş dize için anlamsız. Geri konan tek şey
     * değerin ORİJİNAL hâli.
     *
     * @param  array<string, mixed>  $sent
     * @return array<string, mixed>
     */
    private function restoreEmptyStrings(array $sent, Request $request): array
    {
        $raw = json_decode((string) $request->getContent(), true);

        if (!is_array($raw) || !isset($raw['settings']) || !is_array($raw['settings'])) {
            return $sent;
        }

        foreach ($raw['settings'] as $key => $value) {
            // YALNIZ BOŞ DİZEYE dokunuyoruz. Diğer her değer doğrulanmış
            // ve temizlenmiş hâliyle kalmalı; ham gövdeyi olduğu gibi
            // kullanmak, `TrimStrings` gibi middleware'leri de baypas edip
            // bu ucu diğerlerinden farklı davrandırırdı.
            if (is_string($value) && trim($value) === '' && ($sent[$key] ?? null) === null) {
                $sent[$key] = '';
            }
        }

        return $sent;
    }

    /**
     * Sözleşmedeki `device` nesnesi.
     *
     * EŞLEME KODU YALNIZ İKİ YERDE AÇILIR: kodu üreten uçların
     * yanıtlarında ve listede kod hâlâ KULLANILABİLİRKEN. Kullanılmış ya
     * da süresi dolmuş bir kodu göstermek, yöneticiye çalışmayan bir kod
     * okutur ve "kod yanlış" diye destek çağrısı üretirdi.
     *
     * @return array<string, mixed>
     */
    private function device(KitchenDevice $device, bool $revealPairingCode = false): array
    {
        $usable = $device->pairingCodeIsUsable();

        $settings = $this->settings->forDevice($device);
        // Damga nesnenin kendi alanında (`settings_updated_at`) duruyor;
        // ayarların içinde ikinci kez taşımak sözleşmedeki 23 anahtarlık
        // listeye yazılamayan bir anahtar daha eklerdi.
        unset($settings['updated_at']);

        return [
            'id' => (int) $device->id,
            'name' => (string) $device->name,
            'online' => $this->isOnline($device),
            'last_seen_at' => self::ts($device->last_seen_at),
            'created_at' => self::ts($device->created_at),
            'revoked_at' => self::ts($device->revoked_at),
            'pairing' => [
                'code' => ($usable || $revealPairingCode) ? $device->pairing_code : null,
                'expires_at' => self::ts($device->pairing_expires_at),
                'usable' => $usable,
            ],
            'health' => [
                'reported_at' => self::ts($device->health_reported_at),
                // Üç hâl: `null` "kasa hiç bildirmedi", `false` "arızalı".
                // İkisini birleştirmek, yeni kurulan bir kasa için var
                // olmayan bir yazıcı arızası aratırdı.
                'printer_ok' => $device->printer_ok,
                'print_queue_pending' => $device->print_queue_pending,
                'print_queue_failed' => $device->print_queue_failed,
                'app_version' => $device->app_version,

                /*
                 * ZENGİNLEŞTİRİLMİŞ TELEMETRİ (K-22).
                 *
                 * Sayının yanındaki bu beş alan, "kuyrukta 3 iş var" ile
                 * "kuyrukta 3 iş var ve en eskisi 40 dakikadır bekliyor"
                 * arasındaki farkı verir; ikisi arasındaki fark sahaya
                 * gitme kararını değiştirir.
                 *
                 * Hepsi `null` olabilir ve `null` "kasa bildirmedi"
                 * demektir — eski bir sürümde olan kasa bu alanları hiç
                 * göndermez. Panel bunu "sorun yok" diye GÖSTERMEMELİ.
                 */
                'last_error' => $device->last_error,
                'alarm_muted' => $device->alarm_muted,
                'alarm_mute_reason' => $device->alarm_mute_reason,
                'queue_oldest_at' => self::ts($device->queue_oldest_at),
                'sound_ok' => $device->sound_ok,
            ],
            'settings' => $settings,
            'settings_updated_at' => self::ts($device->settings_updated_at),
            // Cihaz başına tek sorgu: sahada iki-üç kasa var ve listeyi
            // tek sorguya indirmek okunabilirlikten çok şey götürürdü.
            'pending_command_count' => KitchenCommand::pendingFor((int) $device->id)->count(),
        ];
    }

    /**
     * `online` = son görülme eşiğin içinde VE iptal edilmemiş.
     *
     * İptal edilmiş bir kasa dakikalar önce görülmüş olabilir ama artık
     * hiçbir uca giremez; onu "çevrimiçi" göstermek yöneticiye çalışan
     * bir mutfak ekranı olduğunu düşündürürdü.
     */
    private function isOnline(KitchenDevice $device): bool
    {
        if ($device->isRevoked() || $device->last_seen_at === null) {
            return false;
        }

        return $device->last_seen_at->greaterThanOrEqualTo(
            Carbon::now()->subMinutes(KitchenDevice::ONLINE_THRESHOLD_MINUTES),
        );
    }

    /**
     * @param  array<string, mixed>  $data
     * @return array<string, mixed>|null
     */
    private function commandPayload(string $command, array $data): ?array
    {
        if ($command !== KitchenCommand::REPRINT) {
            return null;
        }

        /** @var array<string, mixed> $payload */
        $payload = $data['payload'] ?? [];

        return [
            'order_id' => (int) $payload['order_id'],
            'type' => (string) $payload['type'],
        ];
    }

    /**
     * Yönetilen ayar anahtarları — servisin kendisinden okunur.
     *
     * Elle yazılmış ikinci bir liste, servise yeni bir ayar eklendiği gün
     * sessizce eksik kalır ve o ayar Kontrol Merkezi'nden yazılamaz.
     * Admin ekranı da listeyi aynı yerden alıyor.
     *
     * @return list<string>
     */
    private function settingKeys(KitchenDevice $device): array
    {
        $keys = $this->settings->forDevice($device);
        unset($keys['updated_at']);

        return array_keys($keys);
    }

    /**
     * Sınırlar `KitchenDeviceSettings`'inkileri AYNEN tekrar eder.
     *
     * Servis sınır dışındaki değeri zaten kırpıyor; buradaki kuralların
     * işi kırpmayı önlemek değil GÖRÜNÜR kılmak. Makine istemcisinde
     * sessiz kırpma daha da tehlikeli: Kontrol Merkezi 70 yazıp 60
     * kaydedildiğini fark etmez ve ekranında yanlış değeri gösterir.
     *
     * ANAHTARLAR `settings.` ÖNEKLİ: ayarlar gövdenin kökünde değil,
     * `settings` nesnesinin altında geliyor (gerekçe `updateSettings()`).
     *
     * @return array<string, list<string>>
     */
    private function settingRules(): array
    {
        $rules = [
            'poll_seconds' => ['sometimes', 'nullable', 'integer',
                'min:'.KitchenDeviceSettings::MIN_POLL_SECONDS,
                'max:'.KitchenDeviceSettings::MAX_POLL_SECONDS],
            'sound_enabled' => ['sometimes', 'nullable', 'boolean'],
            'warning_after_minutes' => ['sometimes', 'nullable', 'integer',
                'min:'.KitchenDeviceSettings::MIN_THRESHOLD_MINUTES,
                'max:'.KitchenDeviceSettings::MAX_THRESHOLD_MINUTES],
            'late_after_minutes' => ['sometimes', 'nullable', 'integer',
                'min:'.KitchenDeviceSettings::MIN_THRESHOLD_MINUTES,
                'max:'.KitchenDeviceSettings::MAX_THRESHOLD_MINUTES],
            'printer_device_path' => ['sometimes', 'nullable', 'string', 'max:128'],
            'printer_code_page' => ['sometimes', 'nullable', 'integer', 'min:0', 'max:255'],
            'health_seconds' => ['sometimes', 'nullable', 'integer', 'min:10', 'max:300'],
            'connection_alarm_seconds' => ['sometimes', 'nullable', 'integer', 'min:10', 'max:600'],
            'alarm_silenceable' => ['sometimes', 'nullable', 'boolean'],
            'volume_percent' => ['sometimes', 'nullable', 'integer', 'min:0', 'max:100'],
            // `audio_sink` BOŞ DİZEYİ KORUR: "varsayılan çıkışa dön"
            // demenin tek yolu o; `null` bu alanda da "dokunmadı".
            'audio_sink' => ['sometimes', 'nullable', 'string', 'max:128'],
            'tts_enabled' => ['sometimes', 'nullable', 'boolean'],
            'tts_rate_percent' => ['sometimes', 'nullable', 'integer',
                'min:'.KitchenDeviceSettings::MIN_TTS_RATE_PERCENT,
                'max:'.KitchenDeviceSettings::MAX_TTS_RATE_PERCENT],
            'alarm_repeat_seconds' => ['sometimes', 'nullable', 'integer', 'min:0',
                'max:'.KitchenDeviceSettings::MAX_ALARM_REPEAT_SECONDS],
            'alarm_max_repeats' => ['sometimes', 'nullable', 'integer', 'min:0', 'max:60'],
            'touch_mode' => ['sometimes', 'nullable', 'boolean'],

            /*
             * OLAY BAZLI SESLER (K-22) — `audio_sink` gibi BOŞ DİZEYİ
             * KORUR: burada boş dize "hiçbiri kapalı olmasın" emridir ve
             * `null` "dokunmadı"ya ayrılmış durumda.
             *
             * Kural yalnız TİP ve UZUNLUK bakıyor; içeriği `Rule::in` ile
             * kısıtlamıyoruz. Bilinmeyen ad ve `connectionLost`
             * `KitchenDeviceSettings::normalizeSoundEvents` içinde SESSİZCE
             * eleniyor — bilinçli bir sapma: bu alandaki tek bir yazım
             * hatasının isteği 422'ye düşürmesi, yöneticinin gerçekten
             * kapatmak istediği diğer uyarıların da uygulanmaması demek
             * olurdu ve mutfak sessiz kalırdı. Diğer ayarlarda sessiz
             * kırpma tehlikeli, burada sessiz eleme güvenli tarafta duruyor.
             */
            'disabled_sound_events' => ['sometimes', 'nullable', 'string',
                'max:'.KitchenDeviceSettings::MAX_SOUND_EVENTS_LENGTH],

            // Kilit politikası (K-21). `null` = dokunma = serbest.
            'allow_settings' => ['sometimes', 'nullable', 'boolean'],
            'allow_server_change' => ['sometimes', 'nullable', 'boolean'],
            'allow_window_controls' => ['sometimes', 'nullable', 'boolean'],
            'allow_order_edit' => ['sometimes', 'nullable', 'boolean'],
            'allow_manual_reprint' => ['sometimes', 'nullable', 'boolean'],
            'allow_sales_control' => ['sometimes', 'nullable', 'boolean'],
            'lock_message' => ['sometimes', 'nullable', 'string', 'max:160'],
        ];

        $prefixed = [];

        foreach ($rules as $key => $rule) {
            $prefixed['settings.'.$key] = $rule;
        }

        return $prefixed;
    }

    /** @throws ApiException */
    private function assertNotRevoked(KitchenDevice $device): void
    {
        if ($device->isRevoked()) {
            throw ApiException::validationFailed(
                'Bu kasa iptal edilmiş. Önce yeni bir kasa kaydı açın.',
                ['device_id' => (string) $device->id],
            );
        }
    }

    /** @throws ApiException */
    private function findDevice(int $id): KitchenDevice
    {
        $device = KitchenDevice::find($id);

        if ($device === null) {
            throw ApiException::notFound('Mutfak kasası bulunamadı.');
        }

        return $device;
    }
}
