<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\HasApiTokens;

/**
 * Mutfak kasası — `docs/02-veri-modeli.md` §2.1.
 *
 * KDS'in kullanıcı hesabı yoktur (ADR-08). Admin panelden üretilen tek
 * kullanımlık kodla eşleşir ve `kitchen` kapsamlı, iptal edilebilir bir
 * token alır. Kasa çalınır/el değiştirirse tek tıkla iptal edilir.
 *
 * @property int $id
 * @property string $name
 * @property string|null $pairing_code
 * @property Carbon|null $pairing_expires_at
 * @property Carbon|null $last_seen_at
 * @property Carbon|null $revoked_at
 */
class KitchenDevice extends Model
{
    use HasApiTokens;

    /** Kapsam adı — bu token fiyat, müşteri verisi ve rapor uçlarına erişemez. */
    public const string SCOPE = 'kitchen';

    /** Eşleme kodu bu süre sonra geçersizdir (docs/04 §4.1). */
    public const int PAIRING_TTL_MINUTES = 10;

    protected $table = 'veykemtu_kitchen_devices';

    protected $guarded = [];

    protected $casts = [
        'pairing_expires_at' => 'datetime',
        'last_seen_at' => 'datetime',
        'revoked_at' => 'datetime',
    ];

    public function printJobs(): HasMany
    {
        return $this->hasMany(PrintJob::class, 'device_id');
    }

    public function isRevoked(): bool
    {
        return $this->revoked_at !== null;
    }

    /**
     * Yeni bir tek kullanımlık eşleme kodu üretir.
     *
     * Biçim `XXXX-XXXX` (sözleşme: `^[A-Z0-9]{4}-[A-Z0-9]{4}$`). Karıştırılması
     * kolay karakterler (0/O, 1/I) alfabede yoktur — kod mutfakta elle,
     * çoğu zaman kötü ışıkta giriliyor.
     */
    public static function generatePairingCode(): string
    {
        $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        $pick = static fn(): string => substr($alphabet, random_int(0, strlen($alphabet) - 1), 1);

        $chunk = static fn(): string => implode('', array_map($pick, range(1, 4)));

        return $chunk().'-'.$chunk();
    }

    /**
     * Kod hâlâ kullanılabilir mi?
     *
     * Kullanılmış kod `null`'a çekilir; süresi dolmuş kod reddedilir.
     */
    public function pairingCodeIsUsable(): bool
    {
        return $this->pairing_code !== null
            && $this->pairing_expires_at !== null
            && $this->pairing_expires_at->isFuture()
            && !$this->isRevoked();
    }

    /**
     * Eşleme kodunu tüketip yeni bir `kitchen` kapsamlı token verir.
     *
     * Eski token'lar silinir: bir cihaz aynı anda tek token taşır, böylece
     * "eşlemeyi sıfırla" gerçekten sıfırlar.
     */
    public function issueToken(): string
    {
        $this->tokens()->delete();

        $token = $this->createToken('kds', [self::SCOPE]);

        $this->pairing_code = null;
        $this->pairing_expires_at = null;
        $this->last_seen_at = Carbon::now();
        $this->save();

        return $token->plainTextToken;
    }

    /**
     * Admin panelden yeni bir eşleme kodu ister.
     *
     * Kod düz metin saklanır — tek kullanımlık, 10 dakika ömürlü ve yalnızca
     * admin panelini görebilen yönetici okuyabilir. Hash'lemek yöneticinin
     * kodu ekranda görmesini imkânsız kılardı.
     */
    public function refreshPairingCode(): string
    {
        $this->pairing_code = self::generatePairingCode();
        $this->pairing_expires_at = Carbon::now()->addMinutes(self::PAIRING_TTL_MINUTES);
        $this->save();

        return $this->pairing_code;
    }

    public function touchLastSeen(): void
    {
        // `updated_at`'i kirletmemek için doğrudan güncelleme: her heartbeat
        // 60 saniyede bir gelir, model olaylarını tetiklemesine gerek yok.
        static::withoutTimestamps(fn() => $this->forceFill([
            'last_seen_at' => Carbon::now(),
        ])->saveQuietly());
    }

    /**
     * Cihazı iptal eder.
     *
     * TOKEN SATIRI KASTEN SİLİNMEZ. Silindiğinde `findToken()` null döner
     * ve istek `401 UNAUTHENTICATED` ile biter; sözleşmenin ve KDS'in
     * beklediği `403 DEVICE_REVOKED` dalına hiç ulaşılmaz. Sonuç: yönetici
     * bir kasayı iptal ettiğinde mutfak ekranı "eşleme iptal edildi" yerine
     * genel bir oturum hatası gösteriyordu (docs/05 §7 adım 5).
     *
     * Token'ı bırakmak erişim açık bırakmaz: her mutfak ucu `bld.auth`
     * middleware'inden geçer ve orada `isRevoked()` kontrolü var.
     */
    public function revoke(): void
    {
        $this->revoked_at = Carbon::now();
        $this->save();
    }
}
