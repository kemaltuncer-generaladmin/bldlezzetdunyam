<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Admin;

use DateTimeInterface;
use Illuminate\Support\Carbon;
use Veykemtu\BridgeApi\Models\KitchenCommand;
use Veykemtu\BridgeApi\Models\KitchenDevice;

/**
 * Mutfak kasası ekranlarının okuma tarafı: ham sütunları yöneticinin
 * anlayacağı duruma çevirir.
 *
 * AYRI SINIF, ÇÜNKÜ BU İŞ KURALIDIR, ÇİZİM DEĞİL. "Kasa çevrimiçi mi",
 * "yazıcı arızalı mı yoksa hiç haber vermedi mi", "gönderdiğim komut
 * kasaya ulaştı mı" sorularının cevabı üç ayrı sütunun ve bir eşiğin
 * birleşiminden çıkıyor. Blade şablonunun içine gömülseydi test
 * edilemezdi; bir denetleyicinin içinde dursaydı liste sütunları ile
 * düzenleme ekranı iki ayrı yanıt üretirdi.
 *
 * Metotlar STATİK: sınıfın hiçbir bağımlılığı ve durumu yok, girdisi
 * yalnızca modelin kendisi (`LiraField` ile aynı desen).
 */
final class KitchenDevicePanel
{
    // Bağlantı durumları.
    public const string CONNECTION_REVOKED = 'revoked';

    public const string CONNECTION_NEVER = 'never';

    public const string CONNECTION_ONLINE = 'online';

    public const string CONNECTION_OFFLINE = 'offline';

    // Yazıcı durumları — ÜÇ HÂL. `null` "bilinmiyor", `false` "arızalı".
    public const string PRINTER_UNKNOWN = 'unknown';

    public const string PRINTER_OK = 'ok';

    public const string PRINTER_FAULT = 'fault';

    // Ayarların kasaya ulaşıp ulaşmadığı.
    public const string SYNC_UNTOUCHED = 'untouched';

    public const string SYNC_UNVERIFIED = 'unverified';

    public const string SYNC_APPLIED = 'applied';

    public const string SYNC_PENDING = 'pending';

    // Komut durumları.
    public const string COMMAND_QUEUED = 'queued';

    public const string COMMAND_DELIVERED = 'delivered';

    public const string COMMAND_RETRYING = 'retrying';

    public const string COMMAND_SUCCEEDED = 'succeeded';

    public const string COMMAND_FAILED = 'failed';

    /**
     * Kasa sağlık bildirimini varsayılan olarak bu sıklıkta gönderir.
     *
     * `health_seconds` boşken kasanın kendi derleme varsayılanı geçerlidir
     * (`docs/05-mutfakapp.md` §8) ve bu değer odur. Yalnızca "komut ne
     * zaman varır" tahminini yazmak için kullanılıyor; bir ayar değil.
     */
    public const int DEFAULT_HEALTH_SECONDS = 60;

    private function __construct() {}

    /**
     * @return array{state: string, label: string, css: string}
     */
    public static function connection(KitchenDevice $device): array
    {
        if ($device->isRevoked()) {
            return self::badge(self::CONNECTION_REVOKED, 'kds.state_revoked', 'danger');
        }

        if ($device->last_seen_at === null) {
            return self::badge(self::CONNECTION_NEVER, 'kds.state_never', 'secondary');
        }

        $online = $device->last_seen_at->greaterThanOrEqualTo(
            Carbon::now()->subMinutes(KitchenDevice::ONLINE_THRESHOLD_MINUTES),
        );

        return $online
            ? self::badge(self::CONNECTION_ONLINE, 'kds.state_online', 'success')
            : self::badge(self::CONNECTION_OFFLINE, 'kds.state_offline', 'danger');
    }

    /**
     * Yazıcı durumu — "bilinmiyor" ile "arızalı" AYRI RENKTEDİR.
     *
     * İkisini aynı göstermek, hiç sağlık bildirimi göndermemiş yeni bir
     * kasa için yöneticiyi var olmayan bir yazıcı arızası aramaya
     * gönderirdi.
     *
     * @return array{state: string, label: string, css: string}
     */
    public static function printer(KitchenDevice $device): array
    {
        return match ($device->printer_ok) {
            null => self::badge(self::PRINTER_UNKNOWN, 'kds.printer_unknown', 'secondary'),
            true => self::badge(self::PRINTER_OK, 'kds.printer_ok', 'success'),
            false => self::badge(self::PRINTER_FAULT, 'kds.printer_fault', 'danger'),
        };
    }

    /**
     * "Değiştirdiğim ayar kasaya gitti mi?"
     *
     * Cevap `settings_updated_at` ile `health_reported_at`'in
     * karşılaştırmasıdır: kasa ayarları yalnızca sağlık bildiriminin
     * yanıtında alır, dolayısıyla değişiklikten SONRA gelen bir bildirim
     * "aldı" demektir.
     *
     * @return array{state: string, label: string, css: string}
     */
    public static function settingsSync(KitchenDevice $device): array
    {
        if ($device->settings_updated_at === null) {
            return self::badge(self::SYNC_UNTOUCHED, 'kds.sync_untouched', 'secondary');
        }

        if ($device->health_reported_at === null) {
            return self::badge(self::SYNC_UNVERIFIED, 'kds.sync_unverified', 'warning');
        }

        return $device->health_reported_at->greaterThanOrEqualTo($device->settings_updated_at)
            ? self::badge(self::SYNC_APPLIED, 'kds.sync_applied', 'success')
            : self::badge(self::SYNC_PENDING, 'kds.sync_pending', 'warning');
    }

    /**
     * Komutun nerede olduğu.
     *
     * DÖRT AYRI HÂL, çünkü yöneticinin vereceği karar her birinde farklı:
     * "gönderildi" beklemeyi, "teslim edildi" biraz daha beklemeyi,
     * "yeniden denenecek" hiçbir şey yapmamayı, "çalıştırılamadı" ise
     * mutfağa gitmeyi gerektirir.
     *
     * @return array{state: string, label: string, css: string}
     */
    public static function commandState(KitchenCommand $command): array
    {
        if ($command->executed_at !== null) {
            return $command->succeeded === true
                ? self::badge(self::COMMAND_SUCCEEDED, 'kds.command_succeeded', 'success')
                : self::badge(self::COMMAND_FAILED, 'kds.command_failed', 'danger');
        }

        if ($command->delivered_at === null) {
            return self::badge(self::COMMAND_QUEUED, 'kds.command_queued', 'secondary');
        }

        $stale = Carbon::now()->subMinutes(KitchenCommand::STALE_AFTER_MINUTES);

        return $command->delivered_at->lessThan($stale)
            ? self::badge(self::COMMAND_RETRYING, 'kds.command_retrying', 'warning')
            : self::badge(self::COMMAND_DELIVERED, 'kds.command_delivered', 'info');
    }

    /** Komut kodunun Türkçe adı; bilinmeyen kod ham hâliyle döner. */
    public static function commandLabel(string $command): string
    {
        return in_array($command, KitchenCommand::ALL, true)
            ? self::lang('kds.command_'.$command)
            : $command;
    }

    /**
     * Bir komutun kasaya en geç ne kadar sonra varacağı (saniye).
     *
     * Teslimat sağlık bildirimine binmiş durumda; dolayısıyla üst sınır
     * bildirim aralığının kendisidir.
     */
    public static function commandArrivalSeconds(KitchenDevice $device): int
    {
        return $device->health_seconds ?? self::DEFAULT_HEALTH_SECONDS;
    }

    /**
     * "3 dakika önce" — Türkçe göreli zaman.
     *
     * Carbon'un kendi çevirisi kullanılıyor: panelin dili `en` olduğu için
     * `diffForHumans()` doğrudan çağrılsa "3 minutes ago" yazardı.
     *
     * METİN DE KABUL EDİLİR, ve bu şart: `Igniter\Flame\Database\Model`
     * zaman damgalarını varsayılan olarak kapalı tutuyor
     * (`$timestamps = false`), bu yüzden `KitchenCommand::$created_at`
     * modelden Carbon değil düz METİN olarak geliyor. Yalnızca Carbon
     * kabul eden bir imza, komut geçmişini ilk satırda ölümcül tip
     * hatasıyla düşürürdü.
     */
    public static function since(DateTimeInterface|string|null $moment): ?string
    {
        if ($moment === null || $moment === '') {
            return null;
        }

        $carbon = $moment instanceof DateTimeInterface
            ? Carbon::instance($moment)
            : Carbon::parse($moment);

        return $carbon->locale('tr')->diffForHumans();
    }

    /** Eşleme kodu ekranda gösterilebilir mi, ne kadar ömrü kaldı? */
    public static function pairingCodeMinutesLeft(KitchenDevice $device): ?int
    {
        if (!$device->pairingCodeIsUsable() || $device->pairing_expires_at === null) {
            return null;
        }

        // Yukarı yuvarlanır: "0 dakika kaldı" yazan bir kod hâlâ çalışıyor
        // olabilir ve yönetici onu geçersiz sanıp yenisini üretirdi.
        return max(1, (int) ceil(Carbon::now()->diffInSeconds($device->pairing_expires_at) / 60));
    }

    /**
     * @return array{state: string, label: string, css: string}
     */
    private static function badge(string $state, string $key, string $css): array
    {
        return ['state' => $state, 'label' => self::lang($key), 'css' => $css];
    }

    private static function lang(string $key): string
    {
        return (string) lang('veykemtu.bridgeapi::default.'.$key);
    }
}
