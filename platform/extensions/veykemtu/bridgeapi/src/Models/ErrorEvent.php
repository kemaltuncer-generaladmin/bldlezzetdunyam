<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;
use Illuminate\Database\QueryException;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Toplanmış hata olayı — durum monitörünün satırı.
 *
 * BİR SATIR BİR OLAY DEĞİL, BİR HATA TÜRÜDÜR. Aynı çökme yüz kez tekrar
 * ederse satır bir tanedir ve `occurrences` yüzdür. Gerekçenin tamamı göç
 * yorumunda (`2026_08_23_000003`): tek bir çökme döngüsü yoksa tabloyu bir
 * öğleden sonrada okunamaz hâle getirir.
 *
 * ## `record()` NEDEN ELOQUENT KULLANMIYOR
 *
 * "Oku → varsa sayacı artır → kaydet" akışı, okuma ile yazma arasında bir
 * KAYIP GÜNCELLEME penceresi bırakır: aynı anda gelen iki rapor da sayacı
 * 5 okur, ikisi de 6 yazar ve bir tekrar kaybolur. Bu tablo tam olarak
 * "aynı anda çok sayıda tekrar" için var; yarış istisna değil, kural.
 *
 * Bu yüzden artırım TEK bir koşullu `UPDATE`'tir (`occurrences + 1`
 * veritabanında hesaplanır) ve satır yoksa `INSERT` denenir. `INSERT`
 * benzersiz kısıta takılırsa (arada başkası yazdı) `UPDATE` tekrarlanır.
 * Aynı ilke `Services\DailyStock` içinde de uygulanıyor; oradaki gerekçe
 * "son porsiyonu iki müşteriye satmak", buradaki "tekrarı kaybetmek".
 *
 * @property int $id
 * @property string $source
 * @property string $level
 * @property string $fingerprint
 * @property string|null $type
 * @property string $message
 * @property string|null $stack
 * @property array<string, mixed>|null $context
 * @property Carbon|null $occurred_at
 * @property Carbon $first_seen_at
 * @property Carbon $last_seen_at
 * @property int $occurrences
 * @property Carbon|null $resolved_at
 * @property string|null $resolved_by
 */
class ErrorEvent extends Model
{
    /** Sunucunun kendi hatası (PHP tarafı). */
    public const string SOURCE_SERVER = 'server';

    /** Mutfak kasası — `mutfakapp`. */
    public const string SOURCE_KDS = 'kds';

    /** Müşteri uygulaması — `musteriapp`. */
    public const string SOURCE_MOBILE = 'mobile';

    public const string SOURCE_WEBSITE = 'website';

    /** @var list<string> */
    public const array SOURCES = [
        self::SOURCE_SERVER,
        self::SOURCE_KDS,
        self::SOURCE_MOBILE,
        self::SOURCE_WEBSITE,
    ];

    public const string LEVEL_INFO = 'info';

    public const string LEVEL_WARNING = 'warning';

    public const string LEVEL_ERROR = 'error';

    public const string LEVEL_CRITICAL = 'critical';

    /** @var list<string> */
    public const array LEVELS = [
        self::LEVEL_INFO,
        self::LEVEL_WARNING,
        self::LEVEL_ERROR,
        self::LEVEL_CRITICAL,
    ];

    /**
     * Sütun genişlikleri — kesme noktaları.
     *
     * SINIRI AŞAN METİN KESİLİR, REDDEDİLMEZ. Bu ucun başarısızlığı
     * "hatalı istek" değil, KAYBEDİLMİŞ TEŞHİS BİLGİSİdir: sekiz kilobaytı
     * bir karakter aşan yığın izi yüzünden raporu geri çevirmek, çöken
     * istemcinin tek kanıtını çöpe atmak olurdu.
     */
    public const int MESSAGE_LIMIT = 500;

    public const int TYPE_LIMIT = 120;

    /**
     * Yığın izi tavanı.
     *
     * Sekiz bin karakter, Flutter'ın uzun izlerini de alan ama tek bir
     * döngüye giren istemcinin diski doldurmasını engelleyen orta yol
     * (`docs/openapi.yaml` → `ClientErrorReport.stack`).
     */
    public const int STACK_LIMIT = 8000;

    protected $table = 'veykemtu_error_events';

    /**
     * `created_at`/`updated_at` YOK — yerlerini `first_seen_at` ve
     * `last_seen_at` tutuyor. İkisi aynı şey değil: `created_at` satırın
     * yazıldığı andır, `first_seen_at` hatanın İLK GÖRÜLDÜĞÜ andır ve
     * toplanan bir satırda ikincisi sorulan sorudur.
     */
    public $timestamps = false;

    protected $guarded = [];

    protected $casts = [
        'context' => 'array',
        'occurred_at' => 'datetime',
        'first_seen_at' => 'datetime',
        'last_seen_at' => 'datetime',
        'occurrences' => 'integer',
        'resolved_at' => 'datetime',
    ];

    /**
     * Bir hatayı kaydeder ya da var olan satıra ekler.
     *
     * `$discriminator` parmak izine giren ek anahtar: aynı metni üreten ama
     * FARKLI kaynaklardan gelen hataları ayırır (iki ayrı kasanın aynı
     * yazıcı hatası, iki ayrı olaydır — birini çözmek ötekini çözmez).
     * Boş bırakılırsa yalnız kaynak, tür ve mesaj birleştirir.
     *
     * @param array<string, mixed>|null $context
     */
    public static function record(
        string $source,
        string $level,
        ?string $type,
        string $message,
        ?string $stack = null,
        ?array $context = null,
        ?Carbon $occurredAt = null,
        string $discriminator = '',
    ): string {
        $fingerprint = self::fingerprint($source, $type, $message, $discriminator);
        $now = BusinessTime::forStorage(Carbon::now());

        /*
         * TEKRARDA GÜNCELLENEN ALANLAR — hepsi "en son ne oldu"yu taşır.
         *
         * `message` ve `stack` de tazeleniyor: rakamları silinmiş parmak
         * izi "Sipariş 8421 basılamadı" ile "Sipariş 8422 basılamadı"yı
         * aynı sayıyor ve yöneticinin görmesi gereken, en son hangi
         * siparişte olduğudur.
         *
         * `resolved_at` SIFIRLANIR: çözülmüş sanılan bir hatanın tekrarı,
         * yepyeni bir hatadan daha önemlidir (`docs/control/monitor.md`
         * §Tekilleştirme). Kapalı kalsaydı olay varsayılan süzgeçte
         * görünmez olur ve arıza devam ederken panel temiz görünürdü.
         */
        $touch = [
            'level' => $level,
            'type' => self::clamp($type, self::TYPE_LIMIT),
            'message' => (string) self::clamp($message, self::MESSAGE_LIMIT),
            'stack' => self::clamp($stack, self::STACK_LIMIT),
            'context' => $context === null ? null : json_encode($context, JSON_UNESCAPED_UNICODE),
            'occurred_at' => $occurredAt,
            'last_seen_at' => $now,
            'resolved_at' => null,
            'resolved_by' => null,
        ];

        if (self::bump($fingerprint, $touch) > 0) {
            return $fingerprint;
        }

        try {
            DB::table((new self)->getTable())->insert($touch + [
                'fingerprint' => $fingerprint,
                'source' => $source,
                'first_seen_at' => $now,
                'occurrences' => 1,
            ]);
        } catch (QueryException) {
            // Yarış: iki istek aynı anda "satır yok" gördü, biri yazdı.
            // Kısıt ikinciyi durdurdu; onun tekrarı SAYILMALI, yutulmamalı.
            self::bump($fingerprint, $touch);
        }

        return $fingerprint;
    }

    /**
     * Var olan satırın sayacını artırır; satır yoksa 0 döner.
     *
     * `occurrences + 1` VERİTABANINDA hesaplanıyor — PHP'de okunup geri
     * yazılsaydı eşzamanlı iki tekrardan biri kaybolurdu.
     *
     * @param array<string, mixed> $touch
     */
    private static function bump(string $fingerprint, array $touch): int
    {
        return DB::table((new self)->getTable())
            ->where('fingerprint', $fingerprint)
            ->update($touch + ['occurrences' => DB::raw('occurrences + 1')]);
    }

    /**
     * Toplama anahtarı.
     *
     * RAKAMLAR SİLİNİR: "Sipariş 8421 basılamadı" ile "Sipariş 8422
     * basılamadı" tek hatanın iki tekrarıdır. Silinmeseydi her sipariş
     * kendi satırını açar ve tekilleştirme hiçbir işe yaramazdı — tam da
     * kaçınmak istediğimiz milyon satırlık tablo doğardı. Aynı gerekçe
     * `docs/control/monitor.md` §Tekilleştirme'de ve istemci tarafındaki
     * `packages/core/lib/src/error_fingerprint.dart` içinde de yazılı.
     *
     * Boşluk dizileri tek boşluğa iniyor: aynı yığın izi sürümden sürüme
     * farklı girintileniyor ve girinti farkı iki ayrı olay üretirdi.
     */
    public static function fingerprint(
        string $source,
        ?string $type,
        string $message,
        string $discriminator = '',
    ): string {
        $key = implode('|', [
            $source,
            self::normalize((string) $type),
            $discriminator,
            self::normalize($message),
        ]);

        return sha1(preg_replace('/[0-9]/', '', $key) ?? $key);
    }

    private static function normalize(string $value): string
    {
        return trim((string) preg_replace('/\s+/u', ' ', $value));
    }

    /** Sınırı aşan metni keser; boş kalanı `null` yapar. */
    private static function clamp(?string $value, int $limit): ?string
    {
        if ($value === null) {
            return null;
        }

        $trimmed = trim($value);

        return $trimmed === '' ? null : mb_substr($trimmed, 0, $limit);
    }
}
