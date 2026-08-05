<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Kasa ayarlarının sunucudan yönetilmesi — `docs/05-mutfakapp.md` §8.
 *
 * NEDEN: bugün ses, yoklama aralığı, gecikme eşikleri ve yazıcı yolu
 * kasanın kendi diskinde (`shared_preferences`) yaşıyor. Bir ayarı
 * değiştirmek için mutfağa gidip ekrana dokunmak gerekiyor; iki kasa
 * olsa ikisi ayrı ayrı ayarlanacak ve hangisinin ne ayarda olduğunu
 * kimse bilmeyecek.
 *
 * HEPSİ NULLABLE, ve bu tasarımın merkezi: `null` "yönetici bu ayara
 * dokunmadı, cihaz kendi varsayılanını kullansın" demektir. Sütunlara
 * varsayılan değer koysaydık, göç koştuğu anda her kasa sunucunun
 * varsayılanına zorlanır ve sahada ayarlanmış değerler sessizce
 * ezilirdi.
 *
 * Ayarlar CİHAZ BAŞINA: yazıcı yolu o makinenin donanım gerçeği, iki
 * kasada aynı olmak zorunda değil. Genel bir ayar tablosu, ikinci kasa
 * eklendiği gün bölünmek zorunda kalırdı.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('veykemtu_kitchen_devices', function (Blueprint $table): void {
            $table->unsignedSmallInteger('poll_seconds')->nullable()->after('app_version');
            $table->boolean('sound_enabled')->nullable();
            $table->unsignedSmallInteger('warning_after_minutes')->nullable();
            $table->unsignedSmallInteger('late_after_minutes')->nullable();
            $table->string('printer_device_path', 128)->nullable();
            $table->unsignedTinyInteger('printer_code_page')->nullable();

            // Kasa, ayarların ne zaman değiştiğini bilmek zorunda değil ama
            // yönetici bilmek zorunda: "değiştirdim, kasaya gitti mi?"
            // sorusunun cevabı bu damga ile `health_reported_at`'in
            // karşılaştırılmasıdır.
            $table->timestamp('settings_updated_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('veykemtu_kitchen_devices', function (Blueprint $table): void {
            $table->dropColumn([
                'poll_seconds',
                'sound_enabled',
                'warning_after_minutes',
                'late_after_minutes',
                'printer_device_path',
                'printer_code_page',
                'settings_updated_at',
            ]);
        });
    }
};
