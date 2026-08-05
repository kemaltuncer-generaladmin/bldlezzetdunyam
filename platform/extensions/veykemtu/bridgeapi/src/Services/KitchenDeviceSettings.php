<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Veykemtu\BridgeApi\Models\KitchenDevice;

/**
 * Kasa ayarlarının tek kaynağı — `docs/05-mutfakapp.md` §8.
 *
 * Yönetici admin panelden değiştirir, kasa sağlık bildiriminin yanıtında
 * alır ve uygular. Kasadaki ayar ekranı bu değerleri **yalnızca gösterir**.
 *
 * NEDEN TEK KAYNAK ŞART: iki taraf da yazabilseydi, yönetici paneli
 * değiştirdiği anda kasa kendi değerini geri yazar, kasa değiştirdiği anda
 * sunucu üzerine yazardı. Hangisinin kazandığı zamanlamaya bağlı olurdu ve
 * "değiştirdim ama olmadı" şikâyeti hiç çözülemezdi.
 *
 * `null` ALANLAR "yönetici dokunmadı" demektir; o alanda kasa kendi
 * derleme varsayılanını kullanır. Sunucu varsayılanı dayatmıyoruz, çünkü
 * yazıcı yolu gibi değerler makineye özgü ve yanlış bir varsayılan
 * fiş basımını durdurur.
 */
class KitchenDeviceSettings
{
    /** Sözleşmedeki sınırlar — `docs/openapi.yaml` `KitchenSettings`. */
    public const int MIN_POLL_SECONDS = 2;

    public const int MAX_POLL_SECONDS = 60;

    public const int MIN_THRESHOLD_MINUTES = 1;

    public const int MAX_THRESHOLD_MINUTES = 480;

    /**
     * Cihazın ayarları. Dokunulmamış alanlar `null` döner.
     *
     * @return array<string, mixed>
     */
    public function forDevice(KitchenDevice $device): array
    {
        return [
            'poll_seconds' => $device->poll_seconds,
            'sound_enabled' => $device->sound_enabled,
            'warning_after_minutes' => $device->warning_after_minutes,
            'late_after_minutes' => $device->late_after_minutes,
            'printer_device_path' => $device->printer_device_path,
            'printer_code_page' => $device->printer_code_page,
            'health_seconds' => $device->health_seconds,
            'connection_alarm_seconds' => $device->connection_alarm_seconds,
            'alarm_silenceable' => $device->alarm_silenceable,
            'updated_at' => $device->settings_updated_at?->utc()->toIso8601ZuluString(),
        ];
    }

    /**
     * Ayarları yazar. Yalnızca verilen anahtarlar değişir.
     *
     * @param  array<string, mixed>  $values
     */
    public function update(KitchenDevice $device, array $values): void
    {
        $alanlar = [
            'poll_seconds',
            'sound_enabled',
            'warning_after_minutes',
            'late_after_minutes',
            'printer_device_path',
            'printer_code_page',
            'health_seconds',
            'connection_alarm_seconds',
            'alarm_silenceable',
        ];

        $degisti = false;

        foreach ($alanlar as $alan) {
            if (!array_key_exists($alan, $values)) {
                continue;
            }

            $device->{$alan} = $this->normalize($alan, $values[$alan]);
            $degisti = true;
        }

        if (!$degisti) {
            return;
        }

        // GECİKME EŞİKLERİ SIRALI OLMALI. "Uyarı 20 dk, geciken 10 dk"
        // yazılabilseydi kart hiç kırmızıya dönmezdi — uyarı eşiği zaten
        // geçilmiş olurdu ve geciken siparişler sarı kalırdı.
        if ($device->warning_after_minutes !== null
            && $device->late_after_minutes !== null
            && $device->late_after_minutes < $device->warning_after_minutes) {
            $device->late_after_minutes = $device->warning_after_minutes;
        }

        $device->settings_updated_at = now();
        $device->save();
    }

    private function normalize(string $field, mixed $value): mixed
    {
        if ($value === null || $value === '') {
            return null;
        }

        return match ($field) {
            'poll_seconds' => max(
                self::MIN_POLL_SECONDS,
                min(self::MAX_POLL_SECONDS, (int) $value),
            ),
            'warning_after_minutes', 'late_after_minutes' => max(
                self::MIN_THRESHOLD_MINUTES,
                min(self::MAX_THRESHOLD_MINUTES, (int) $value),
            ),
            // Kod sayfası 0-255 arası bir ESC/POS argümanı; sahada
            // doğrulanan değer 29 ve yanlışı tüm Türkçe harfleri boşluk
            // bastırır (docs/05 §5.2).
            'printer_code_page' => max(0, min(255, (int) $value)),
            'sound_enabled', 'alarm_silenceable' => (bool) $value,
            // Sağlık bildirimi komutları da taşıyor; 10 saniyenin altına
            // inmek sunucuyu boşuna yorar, 300'ün üstünde komut "gitmedi"
            // gibi görünür.
            'health_seconds' => max(10, min(300, (int) $value)),
            'connection_alarm_seconds' => max(10, min(600, (int) $value)),
            'printer_device_path' => trim((string) $value),
            default => $value,
        };
    }
}
