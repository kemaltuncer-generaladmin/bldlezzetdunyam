<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Admin panelden kasaya gönderilen tek seferlik komut.
 *
 * AYAR DEĞİL, KOMUT. Bir ayar "şu andan itibaren böyle olsun" der ve
 * kalıcıdır; komut "şunu bir kez yap" der ve tüketilir. "Test fişi bas"
 * bir ayar olsaydı, sonsuza kadar açık kalıp her yoklamada fiş bastırırdı.
 *
 * TESLİMAT SAĞLIK YANITIYLA olur; ayrı bir yoklama döngüsü kurmuyoruz.
 * Komutun ne kadar sürede varacağı `health_seconds` ayarına bağlıdır ve
 * yönetici bunu panelden kısaltabilir.
 *
 * @property int $id
 * @property int $device_id
 * @property string $command
 * @property array<string, mixed>|null $payload
 * @property Carbon|null $delivered_at
 * @property Carbon|null $executed_at
 * @property bool|null $succeeded
 * @property string|null $result
 * @property int $attempts
 * @property Carbon|null $expires_at
 * @property string|null $dedupe_key
 */
class KitchenCommand extends Model
{
    /** Test fişi bas — yazıcının ve kod sayfasının doğrulaması. */
    public const string TEST_RECEIPT = 'test_receipt';

    /** Bir siparişin fişini yeniden bas. `payload.order_id` ve `payload.type`. */
    public const string REPRINT = 'reprint';

    /** Basılamamış işleri kuyruktan düşür. */
    public const string CLEAR_FAILED = 'clear_failed';

    /** Çalan yeni sipariş alarmını sustur. */
    public const string SILENCE_ALARM = 'silence_alarm';

    /** Uygulamayı yeniden başlat; systemd geri getirir. */
    public const string RESTART = 'restart';

    /**
     * Yeni sürümü indir ve kur (K-22).
     *
     * `GET /api/app-version?app_id=mutfakapp` → `download_url` → `.deb`.
     * Kurulum ADIM ADIM DOĞRULANIR ve herhangi bir adım düşerse kasa ESKİ
     * SÜRÜMDE ÇALIŞMAYA DEVAM EDER; komut gerekçesiyle başarısız döner.
     * "Yarısı kurulmuş" bir kasa, hiç güncellenmemiş bir kasadan çok daha
     * kötüdür: mutfak sabaha açılmayan bir ekranla uyanır.
     */
    public const string UPDATE = 'update';

    /**
     * Cihaz token'ını sil; kasa eşleme ekranına döner (K-22).
     *
     * `revoke` İLE AYNI ŞEY DEĞİL: `revoke` sunucu tarafında kapıyı kapatır
     * ve kasa bunu ancak bir sonraki isteğinde `403` olarak öğrenir; bu
     * komut kasanın kendi tarafındaki eşlemeyi bırakmasını sağlar. Kasa
     * değiştirilirken ya da bir makine başka bir mutfağa taşınırken
     * gereken şey budur.
     */
    public const string UNPAIR = 'unpair';

    /**
     * Kuyruktaki BEKLEYEN işleri de düşür (K-22).
     *
     * `CLEAR_FAILED` yalnız hata almış işleri düşürür (`attempts > 0`) ve
     * bilinçli olarak öyle: yazıcı sırayı yetiştiremediği için bekleyen
     * sağlam fişler çöpe atılmamalı. Ama kâğıt bittiğinde ve yönetici
     * "bu vardiyanın fişlerini boş ver, baştan başla" dediğinde bekleyeni
     * de düşürecek bir kapı gerekiyor. AYRI KOMUT olmasının sebebi:
     * ikisini tek düğmede birleştirmek, yıkıcı olanı kazara çalıştırırdı.
     */
    public const string CLEAR_QUEUE = 'clear_queue';

    /** @var list<string> */
    public const array ALL = [
        self::TEST_RECEIPT,
        self::REPRINT,
        self::CLEAR_FAILED,
        self::SILENCE_ALARM,
        self::RESTART,
        self::UPDATE,
        self::UNPAIR,
        self::CLEAR_QUEUE,
    ];

    /**
     * Geri alınamayan / mutfağı durdurabilen komutlar.
     *
     * Kontrol Merkezi bunları `bld_kds.devices` izninin arkasına koyuyor
     * (`restart` ile aynı kapı). Liste BURADA duruyor ki panel ile sunucu
     * aynı tanımı paylaşsın; iki ayrı liste, ilk ayrıştıklarında sessizce
     * yanlış davranır.
     *
     * @var list<string>
     */
    public const array DESTRUCTIVE = [
        self::RESTART,
        self::UPDATE,
        self::UNPAIR,
        self::CLEAR_QUEUE,
        self::CLEAR_FAILED,
    ];

    /**
     * Teslim edilmiş ama sonucu gelmemiş komut bu süre sonra unutulur.
     *
     * Kasa komutu alıp çöktüyse sonucu hiç gelmez; komut sonsuza kadar
     * "yolda" görünürdü ve yönetici tekrar göndermeye çekinirdi.
     */
    public const int STALE_AFTER_MINUTES = 10;

    /**
     * Bir komut en fazla bu kadar kez teslim edilir (`K-23`).
     *
     * SAHADAKİ HATA: sayaç yoktu ve [STALE_AFTER_MINUTES] her turda
     * `delivered_at`'i yeniden damgalıyordu, yani onaylanmayan bir komut
     * SONSUZA KADAR on dakikada bir yeniden teslim ediliyordu. Mutfak
     * ekranı bunu her on dakikada bir test fişi olarak görüyordu.
     *
     * Üç: bir kez ağ, bir kez kasa, bir kez şans. Dördüncüsü artık
     * "geçici bir aksaklık" değil, bir arıza — ve arıza panelde
     * görünmeli, kâğıt harcamamalı.
     */
    public const int MAX_ATTEMPTS = 3;

    /**
     * Komut bu süre sonra anlamını yitirir.
     *
     * [MAX_ATTEMPTS] ULAŞILABİLEN kasayı sınırlar, bu damga ULAŞILAMAYANI:
     * hafta sonu kapalı kalan bir kasada `attempts` hâlâ sıfırdır ve
     * pazartesi açıldığında cuma akşamından kalma bir test fişi basılırdı.
     * `restart`, `update` ve `unpair` ise yapısal olarak sonuçlarının
     * dönmemesini garanti ediyor (`restart` iki saniye sonra `exit(0)`,
     * `unpair` token'ı siliyor — ikisi de bir sonraki sağlık atımından
     * çok önce); onları kesin sonuca bağlayan tek şey bu damga.
     */
    public const int DEFAULT_TTL_MINUTES = 30;

    /**
     * Yinelenen komut penceresi.
     *
     * Yönetici "olmadı" deyip aynı düğmeye ikinci kez bastığında iki
     * bağımsız komut açılıyordu. Pencere KISA: iki dakikadan sonra basılan
     * düğme artık sabırsızlık değil, bilinçli bir tekrar isteğidir.
     */
    public const int DEDUPE_WINDOW_MINUTES = 2;

    /**
     * Yinelenmesi anlamsız olan komutlar.
     *
     * Hepsi idempotent: iki kez susturmak bir kez susturmakla aynı, iki
     * kez yeniden başlatmak bir kez yeniden başlatmakla aynı.
     *
     * [REPRINT] BİLEREK DIŞARIDA. Aynı fişi ikinci kez basmak o düğmenin
     * TEK VARLIK SEBEBİ; yinelenme koruması onu kırardı ve mutfak "fiş
     * yırtıldı, tekrar bas" dediğinde hiçbir şey olmazdı.
     *
     * @var list<string>
     */
    public const array DEDUPED = [
        self::TEST_RECEIPT,
        self::SILENCE_ALARM,
        self::CLEAR_FAILED,
        self::CLEAR_QUEUE,
        self::RESTART,
        self::UPDATE,
        self::UNPAIR,
    ];

    protected $table = 'veykemtu_kitchen_commands';

    protected $guarded = [];

    /**
     * DAMGALAR AÇIK OLMALI — TastyIgniter'ın modeli `false` ile geliyor.
     *
     * `Igniter\Flame\Database\Model` `public $timestamps = false;`
     * tanımlıyor ve alt sınıf bunu devralıyor. Göç `timestamps()` ile
     * sütunları açsa bile hiçbir zaman yazılmıyorlardı: sahada tüm
     * satırların `created_at`'i NULL çıktı ("bu kasa ne zaman eklendi?"
     * sorusunun cevabı yoktu).
     */
    public $timestamps = true;

    protected $casts = [
        'payload' => 'array',
        'delivered_at' => 'datetime',
        'executed_at' => 'datetime',
        'expires_at' => 'datetime',
        'succeeded' => 'boolean',
        'attempts' => 'integer',
    ];

    public function device(): BelongsTo
    {
        return $this->belongsTo(KitchenDevice::class, 'device_id');
    }

    /**
     * Kasaya gönderilmeyi bekleyen komutlar.
     *
     * Teslim edilmiş ama sonucu gelmemiş ESKİ komutlar yeniden gönderilir:
     * kasa komutu alıp çökmüş olabilir. Tekrar göndermek "test fişi"nde
     * fazladan bir kâğıt, "yeniden başlat"ta zararsız; komutun hiç
     * çalışmaması ise sessiz bir başarısızlık.
     *
     * AMA SONSUZA KADAR DEĞİL. Bu cümle `K-23`'e kadar eksikti ve
     * eksikliği mutfağa on dakikada bir test fişi olarak yansıdı:
     * [MAX_ATTEMPTS] denemeden ve [DEFAULT_TTL_MINUTES] dakikadan sonra
     * "tekrar dene" artık bir kurtarma değil, bir arıza.
     *
     * @return \Illuminate\Database\Eloquent\Builder<KitchenCommand>
     */
    public static function pendingFor(int $deviceId)
    {
        $now = Carbon::now();
        $stale = $now->copy()->subMinutes(self::STALE_AFTER_MINUTES);

        return static::query()
            ->where('device_id', $deviceId)
            ->whereNull('executed_at')
            ->where('attempts', '<', self::MAX_ATTEMPTS)
            ->where(fn($q) => $q
                ->whereNull('expires_at')
                ->orWhere('expires_at', '>', $now))
            ->where(fn($q) => $q
                ->whereNull('delivered_at')
                ->orWhere('delivered_at', '<', $stale))
            ->orderBy('id');
    }

    /**
     * Tükenmiş ve süresi geçmiş komutları KESİN SONUCA bağlar.
     *
     * Yalnız `pendingFor()`'dan düşürmek yetmezdi: satır `executed_at`'i
     * boş kaldığı sürece Kontrol Merkezi'nde sonsuza kadar "uçuşta"
     * görünürdü ve yönetici hiç dönmeyecek bir cevabı beklerdi. Bir
     * komutun iki dürüst sonu var — çalıştı ya da çalışmadı; "belki"
     * bir sonuç değil.
     *
     * UÇUŞTA OLAN SATIRA DOKUNULMAZ (`delivered_at` taze ise). `update`
     * komutu dakikalarca sürebiliyor; son denemesini yeni almış bir
     * kasayı başarısız ilan etmek, tam da başarıyla kurulan bir sürümü
     * panelde "ulaşmadı" göstermek olurdu.
     */
    public static function sweepStale(int $deviceId): void
    {
        $now = Carbon::now();
        $stale = $now->copy()->subMinutes(self::STALE_AFTER_MINUTES);

        $base = static fn() => static::query()
            ->where('device_id', $deviceId)
            ->whereNull('executed_at')
            ->where(fn($q) => $q
                ->whereNull('delivered_at')
                ->orWhere('delivered_at', '<', $stale));

        // İKİ AYRI GEREKÇE, İKİ AYRI CÜMLE. Tek bir metinle kapatmak
        // ("Kasaya ulaşmadı") hiç teslim edilmemiş bir komut için "3
        // deneme" yazardı; yönetici olmayan üç denemenin kaydını arardı.
        $base()
            ->where('attempts', '>=', self::MAX_ATTEMPTS)
            ->update(self::finalFailure(
                'Kasaya ulaşmadı ('.self::MAX_ATTEMPTS.' deneme)',
                $now,
            ));

        $base()
            ->whereNotNull('expires_at')
            ->where('expires_at', '<=', $now)
            ->update(self::finalFailure('Süresi doldu, kasaya ulaşmadı', $now));
    }

    /**
     * Kuyruğa alır; aynı komut zaten bekliyorsa ONU döndürür.
     *
     * `deduped` bayrağı çağırana geri veriliyor çünkü fark kullanıcıya
     * söylenmeli: "gönderildi" yazan bir ekran, ikinci basışta hiçbir şey
     * olmadığını gizler ve yönetici üçüncü kez basar.
     *
     * @param  array<string, mixed>|null  $payload
     * @return array{command: KitchenCommand, deduped: bool}
     */
    public static function queueFor(int $deviceId, string $command, ?array $payload): array
    {
        $now = Carbon::now();
        $key = self::dedupeKeyFor($command, $payload);

        if ($key !== null) {
            $existing = static::query()
                ->where('device_id', $deviceId)
                ->where('dedupe_key', $key)
                ->whereNull('delivered_at')
                ->where('created_at', '>=', $now->copy()->subMinutes(self::DEDUPE_WINDOW_MINUTES))
                ->orderByDesc('id')
                ->first();

            if ($existing instanceof self) {
                return ['command' => $existing, 'deduped' => true];
            }

            // PENCERE KAPANDIYSA ANAHTAR BIRAKILIR. `UNIQUE(device_id,
            // dedupe_key)` aksi hâlde çevrimdışı bir kasada bekleyen eski
            // satır yüzünden yeni komutu veritabanı hatasıyla düşürürdü.
            // Anahtar iki dakikalık pencereyi korur, satırın ömrünü değil.
            static::query()
                ->where('device_id', $deviceId)
                ->where('dedupe_key', $key)
                ->update(['dedupe_key' => null, 'updated_at' => $now]);
        }

        $row = static::create([
            'device_id' => $deviceId,
            'command' => $command,
            'payload' => $payload,
            'dedupe_key' => $key,
            'expires_at' => $now->copy()->addMinutes(self::DEFAULT_TTL_MINUTES),
            // DAMGA ELLE VURULUYOR: `Igniter\Flame\Database\Model` zaman
            // damgalarını varsayılan olarak kapalı tutuyor ve yinelenme
            // penceresi `created_at`'e bakıyor — boş kalırsa pencere hiç
            // çalışmazdı.
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        return ['command' => $row, 'deduped' => false];
    }

    /**
     * Yinelenme anahtarı; yinelenmesi meşru komutlarda `null`.
     *
     * Yük de anahtara giriyor: iki farklı siparişin komutu aynı sayılmaz.
     * Bugün yük taşıyan tek komut [REPRINT] ve o zaten listede değil, ama
     * anahtarı komut adına indirgemek bir sonraki yüklü komutta sessizce
     * yanlış davranırdı.
     *
     * @param  array<string, mixed>|null  $payload
     */
    public static function dedupeKeyFor(string $command, ?array $payload): ?string
    {
        if (!in_array($command, self::DEDUPED, true)) {
            return null;
        }

        return sha1($command.'|'.json_encode($payload));
    }

    /**
     * Süpürmenin yazdığı sütunlar.
     *
     * `dedupe_key` DE BIRAKILIYOR: kapanmış bir satırın anahtarı tekil
     * dizini tutmaya devam etseydi, yönetici aynı komutu bir daha hiç
     * gönderemezdi.
     *
     * @return array<string, mixed>
     */
    private static function finalFailure(string $result, Carbon $now): array
    {
        return [
            'executed_at' => $now,
            'succeeded' => false,
            'result' => $result,
            'dedupe_key' => null,
            'updated_at' => $now,
        ];
    }
}
