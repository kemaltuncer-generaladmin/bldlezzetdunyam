<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Kasa sağlık bildirimi — `docs/03-api-sozlesmesi.md` §Mutfak.
 *
 * NEDEN: bugün sunucunun kasa hakkında bildiği tek şey `last_seen_at`.
 * "Kasa ayakta" ile "kasa çalışıyor" aynı şey değil: yazıcının kâğıdı
 * bitmiş, kuyrukta on basılmamış fiş birikmiş ve uygulama hâlâ düzenli
 * yoklama yapıyor olabilir. Mutfakta kimse fark etmezse siparişler
 * fişsiz hazırlanır.
 *
 * Bu sütunlar cihazın KENDİ bildirdiği durumdur; sunucu bunları
 * doğrulayamaz, yalnızca kaydeder ve gösterir.
 *
 * `last_seen_at`'ten AYRI bir zaman damgası tutuyoruz: sipariş yoklaması
 * ile sağlık bildirimi farklı sıklıkta. Tek damga olsaydı, sağlık
 * bildirimi hiç gelmese bile cihaz "az önce görüldü" görünürdü ve
 * bayat sağlık verisi taze sanılırdı.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('veykemtu_kitchen_devices', function (Blueprint $table): void {
            $table->timestamp('health_reported_at')->nullable()->after('last_seen_at');

            // `null` = cihaz hiç bildirmedi. `false` = bildirdi ve yazıcı
            // erişilemez durumda. İkisi ayrı şeydir ve arayüzde ayrı
            // gösterilmeli — "bilinmiyor" ile "arızalı" karıştırılmamalı.
            $table->boolean('printer_ok')->nullable()->after('health_reported_at');

            $table->unsignedInteger('print_queue_pending')->nullable();
            $table->unsignedInteger('print_queue_failed')->nullable();
            $table->string('app_version', 32)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('veykemtu_kitchen_devices', function (Blueprint $table): void {
            $table->dropColumn([
                'health_reported_at',
                'printer_ok',
                'print_queue_pending',
                'print_queue_failed',
                'app_version',
            ]);
        });
    }
};
