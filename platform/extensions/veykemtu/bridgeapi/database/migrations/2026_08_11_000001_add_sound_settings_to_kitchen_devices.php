<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * K-09/K-10: ses ve dokunmatik ayarları — `docs/05-mutfakapp.md` §8.
 *
 * NEDEN SUNUCUDA: kasa mutfakta, yönetici ofiste. "Ses çalmıyor" çağrısı
 * geldiğinde seviyeyi, çıkışı ve anonsu yerinde gitmeden denemek gerekiyor.
 * Ayarların tek kaynağı zaten sunucu (`KitchenDeviceSettings`); bu göç
 * yalnızca aynı kalıba yeni alanlar ekliyor.
 *
 * HEPSİ `nullable` — `null` "yönetici dokunmadı" demektir ve kasa kendi
 * derleme varsayılanını kullanır. Varsayılan dayatmak, tek bir ayarı
 * değiştiren yöneticinin diğerlerini farkında olmadan sıfırlaması olurdu.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('veykemtu_kitchen_devices', function (Blueprint $table): void {
            $table->unsignedTinyInteger('volume_percent')->nullable()->after('sound_enabled');
            $table->string('audio_sink')->nullable()->after('volume_percent');
            $table->boolean('tts_enabled')->nullable()->after('audio_sink');
            $table->unsignedSmallInteger('tts_rate_percent')->nullable()->after('tts_enabled');
            $table->unsignedSmallInteger('alarm_repeat_seconds')->nullable()->after('tts_rate_percent');
            $table->unsignedSmallInteger('alarm_max_repeats')->nullable()->after('alarm_repeat_seconds');
            $table->boolean('touch_mode')->nullable()->after('alarm_max_repeats');
        });
    }

    public function down(): void
    {
        Schema::table('veykemtu_kitchen_devices', function (Blueprint $table): void {
            $table->dropColumn([
                'volume_percent',
                'audio_sink',
                'tts_enabled',
                'tts_rate_percent',
                'alarm_repeat_seconds',
                'alarm_max_repeats',
                'touch_mode',
            ]);
        });
    }
};
