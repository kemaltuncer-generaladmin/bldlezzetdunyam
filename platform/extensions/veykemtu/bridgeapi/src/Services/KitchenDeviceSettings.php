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
    /**
     * Sözleşmedeki sınırlar — `docs/openapi.yaml` `KitchenSettings`.
     *
     * ALT SINIR 2'DEN 3'E ÇIKTI (12.08.2026): 2 saniyelik yoklama saatte
     * 1800 istek demek ve diğer döngülerle birlikte `bld-kitchen`
     * sınırını (2000/saat) aşıyordu. Aşıldığında kasa 429 alıyor ve
     * mutfak sipariş görmüyor. Hesap `Extension::registerRateLimiters`
     * yorumunda.
     */
    public const int MIN_POLL_SECONDS = 3;

    public const int MAX_POLL_SECONDS = 60;

    public const int MIN_THRESHOLD_MINUTES = 1;

    public const int MAX_THRESHOLD_MINUTES = 480;

    /** Alarm tekrarları arası bekleme; 0 = aralıksız (K-09). */
    public const int MAX_ALARM_REPEAT_SECONDS = 120;

    /** Anons hızı yüzdesi; ikilinin varsayılanı 100. */
    public const int MIN_TTS_RATE_PERCENT = 50;

    public const int MAX_TTS_RATE_PERCENT = 200;

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
            'volume_percent' => $device->volume_percent,
            'audio_sink' => $device->audio_sink,
            'tts_enabled' => $device->tts_enabled,
            'tts_rate_percent' => $device->tts_rate_percent,
            'alarm_repeat_seconds' => $device->alarm_repeat_seconds,
            'alarm_max_repeats' => $device->alarm_max_repeats,
            'touch_mode' => $device->touch_mode,

            // ── Kilit politikası (K-21) ────────────────────────────────
            //
            // `null` = "yönetici dokunmadı" = kasanın bugünkü davranışı,
            // yani SERBEST. Kilit ancak açıkça `false` yazılınca doğar;
            // gerekçesi `2026_08_17_000001` göçünde.
            'allow_settings' => $this->readBool($device->allow_settings),
            'allow_server_change' => $this->readBool($device->allow_server_change),
            'allow_window_controls' => $this->readBool($device->allow_window_controls),
            'allow_order_edit' => $this->readBool($device->allow_order_edit),
            'allow_manual_reprint' => $this->readBool($device->allow_manual_reprint),
            'allow_sales_control' => $this->readBool($device->allow_sales_control),
            'lock_message' => $device->lock_message,

            'updated_at' => $device->settings_updated_at?->utc()->toIso8601ZuluString(),
        ];
    }

    /**
     * Kilit alanlarını okurken `tinyint`'i `bool`'a çevirir.
     *
     * NEDEN BURADA, MODELİN `$casts`'INDA DEĞİL: mevcut 16 ayarın
     * dönüşümü modelde tanımlı ve o liste K-21 kapsamının dışında.
     * Dönüşüm olmadan MySQL `1`/`0` döndürür; sözleşme (`docs/openapi.yaml`
     * `KitchenSettings`) bu alanları `boolean | null` olarak ilan ediyor ve
     * kasa tarafı (`kitchen_health.dart`) `bool?` bekliyor — `1` gelen bir
     * alan Dart'ta ayrıştırma hatası verir, yani sessiz bir sapma değil,
     * doğrudan kırılma olurdu.
     */
    private function readBool(mixed $value): ?bool
    {
        return $value === null ? null : (bool) $value;
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
            'volume_percent',
            'audio_sink',
            'tts_enabled',
            'tts_rate_percent',
            'alarm_repeat_seconds',
            'alarm_max_repeats',
            'touch_mode',
            // Kilit politikası (K-21) — diğer ayarlarla aynı yolu izler:
            // yalnız gönderilen anahtar değişir, `null` "dokunmadı"ya döner.
            'allow_settings',
            'allow_server_change',
            'allow_window_controls',
            'allow_order_edit',
            'allow_manual_reprint',
            'allow_sales_control',
            'lock_message',
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
        // ÇIKIŞ CİHAZI İSTİSNA: boş dize "varsayılan çıkışa dön" demek ve
        // korunmalı. Diğer alanlarda `null` ile aynı anlama gelir
        // ("dokunulmadı"), ama burada yöneticinin seçimini geri almasının
        // tek yolu bu — `null` zaten "dokunmadı"ya ayrılmış durumda.
        if ($field === 'audio_sink') {
            return $value === null ? null : trim((string) $value);
        }

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
            'sound_enabled', 'alarm_silenceable', 'tts_enabled', 'touch_mode',
            // Kilitler (K-21). `false` YAZMAK KİLİTLEMEKTİR; alanı boş
            // bırakmak ("dokunmadı") kilidi kaldırır ve kasa bugünkü
            // serbest davranışına döner.
            'allow_settings', 'allow_server_change', 'allow_window_controls',
            'allow_order_edit', 'allow_manual_reprint', 'allow_sales_control' => (bool) $value,
            // Kilitli eyleme basınca gösterilecek metin. Boş dize yukarıda
            // `null`'a düşer — `audio_sink`'in aksine burada "boş metin"
            // diye anlamlı bir değer yok: metin yoksa kasa kendi genel
            // uyarısını gösterir.
            'lock_message' => mb_substr(trim((string) $value), 0, 160),
            // Ses seviyesi hoparlörün kendi seviyesinden AYRI: bu yalnızca
            // uygulamanın akışını kısar (`pw-play --volume`).
            'volume_percent' => max(0, min(100, (int) $value)),
            'tts_rate_percent' => max(
                self::MIN_TTS_RATE_PERCENT,
                min(self::MAX_TTS_RATE_PERCENT, (int) $value),
            ),
            'alarm_repeat_seconds' => max(0, min(self::MAX_ALARM_REPEAT_SECONDS, (int) $value)),
            // 0 = sınırsız tekrar ("onaylayana kadar susmaz" varsayılanı).
            'alarm_max_repeats' => max(0, (int) $value),
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
