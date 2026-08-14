<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * K-22: olay bazlı ses ayarı + zenginleştirilmiş telemetri.
 *
 * İKİ AYRI İŞ, TEK GÖÇ — ikisi de aynı tabloya dokunuyor ve aynı turda
 * yazıldı; iki ayrı göç dosyası sahada iki ayrı `ALTER TABLE` demek olurdu.
 *
 * ── 1. `disabled_sound_events` ────────────────────────────────────────
 *
 * Kasadaki ayarlar ekranında beş sesli uyarı TEK TEK kapatılabiliyor
 * (`KdsSoundEvent`, anahtar `kds_sound_<ad>_enabled`). Bugüne kadar sunucu
 * bunu ne görebiliyor ne değiştirebiliyordu: "yazıcı uyarısı sürekli çalıyor"
 * çağrısına verilebilecek tek cevap mutfağa gitmekti.
 *
 * BİÇİM: virgülle ayrılmış olay adları, `KdsSoundEvent` enum adlarıyla
 * birebir — `newOrder,lateOrder,printerError,subscriptionReminder,bbdOrder`.
 * Ayrı bir tablo ya da JSON sütunu değil, çünkü liste en fazla beş elemanlı
 * ve sabit; tek satırlık bir metin hem okunabilir hem de mevcut 23 ayarla
 * aynı "tek sütun = tek ayar" kalıbını bozmuyor. 160 karakter, beş adın
 * toplam uzunluğunun kat kat üstünde.
 *
 * ÜÇ HÂL VAR VE ÜÇÜ DE FARKLI:
 *   * `null`        = yönetici dokunmadı → kasa KENDİ listesini korur.
 *   * `''` boş dize = "hiçbiri kapalı olmasın" → kasa hepsini açar.
 *   * dolu metin    = tam olarak bu olaylar kapalı olsun.
 *
 * Boş dizenin ayrı bir emir olması `audio_sink`'teki istisnanın aynısıdır:
 * `null` zaten "dokunmadı"ya ayrılmış durumda, dolayısıyla yöneticinin
 * "hepsini geri aç" diyebilmesinin başka yolu yok. Sütun bu yüzden
 * `nullable` VE boş dize kabul ediyor.
 *
 * `connectionLost` BU LİSTEDE DURAMAZ (`KdsSoundEvent::canBeDisabled`).
 * Bağlantı koptuğunda ekran son bilinen listeyi gösterir ve DOĞRU görünür;
 * tek uyarıyı kapatmak mutfağı kör bırakır. Sunucu listede görürse SESSİZCE
 * eler — hata vermez, çünkü yöneticinin bir yazım hatası yüzünden diğer dört
 * ayarın da uygulanmaması mutfağı hiç kimsenin istemediği bir yerde bırakır.
 *
 * ── 2. Telemetri (5 sütun) ────────────────────────────────────────────
 *
 * Bugünkü sağlık bildirimi "kuyrukta 3 iş var" diyor. "Kuyrukta 3 iş var ve
 * en eskisi 40 dakikadır bekliyor" ise bambaşka bir cümle: ilki yazıcının
 * sırayı yetiştiremediğini, ikincisi kâğıdın bittiğini ve kimsenin fark
 * etmediğini anlatır. Aradaki fark sahaya gitme kararını değiştirir.
 *
 * HEPSİ `nullable` VE ZORUNLU DEĞİL. Sahadaki kasalar bu alanları göndermeyen
 * bir sürümde ve öyle kalabilirler; sunucu eksik alana `null` yazar,
 * doğrulama patlamaz (sözleşme EKLEMELİ — `docs/03` §1.4).
 *
 * `alarm_muted` ÜÇ HÂLLİ: `null` "kasa bildirmedi", `false` "ses çalıyor",
 * `true` "ses çıkmıyor". `printer_ok` ile aynı gerekçe — "bilinmiyor" ile
 * "arızalı" karıştırılırsa yeni kurulan her kasa için olmayan bir arıza
 * aratılır.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('veykemtu_kitchen_devices', function (Blueprint $table): void {
            // ── Yönetilen ayar ────────────────────────────────────────
            //
            // Kilit politikasının sonuna ekleniyor: diğer 23 ayarla aynı
            // yoldan (sağlık yanıtı) iniyor ve aynı "boş = dokunmadı"
            // kuralına tabi.
            $table->string('disabled_sound_events', 160)->nullable()->after('lock_message');

            // ── Telemetri ─────────────────────────────────────────────
            //
            // Mevcut sağlık sütunlarının (`app_version`) yanına değil sona
            // ekleniyor; `after()` zinciriyle araya girmek, kilit
            // sütunlarının sırasını bozmadan mümkün değil ve sütun sırası
            // hiçbir şeyi etkilemiyor.

            // Son yazıcı/ağ hatasının METNİ. Sayaç değil metin: "3 hata
            // var" yöneticiye ne yapacağını söylemez, "No such file or
            // directory: /dev/thermal0" söyler.
            $table->string('last_error', 255)->nullable();

            // Alarm gerçekten duyuluyor mu? Ses ayarı "açık" görünürken
            // oynatıcı bulunamadığı için sessiz kalan bir kasa, sahada
            // yaşandı (bkz. `alarm_player.dart` başlığı) ve panelde hiç
            // görünmüyordu.
            $table->boolean('alarm_muted')->nullable();

            // Neden sessiz? "Ses yok" tek başına eyleme çevrilemez;
            // "pw-play bulunamadı" çevrilir.
            $table->string('alarm_mute_reason', 120)->nullable();

            // Kuyrukta bekleyen EN ESKİ işin zamanı. Sayının yanındaki bu
            // damga, "yoğunluk" ile "tıkanma" arasındaki farkı tek bakışta
            // verir.
            $table->timestamp('queue_oldest_at')->nullable();

            // Ses altsisteminin sağlığı. `alarm_muted`'dan ayrı: yönetici
            // sesi kapattıysa alarm susturulmuştur ama altsistem SAĞLAMDIR.
            // İkisini tek alanda birleştirmek, kapalı bir hoparlörü arıza
            // gibi göstermek olurdu.
            $table->boolean('sound_ok')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('veykemtu_kitchen_devices', function (Blueprint $table): void {
            $table->dropColumn([
                'disabled_sound_events',
                'last_error',
                'alarm_muted',
                'alarm_mute_reason',
                'queue_oldest_at',
                'sound_ok',
            ]);
        });
    }
};
