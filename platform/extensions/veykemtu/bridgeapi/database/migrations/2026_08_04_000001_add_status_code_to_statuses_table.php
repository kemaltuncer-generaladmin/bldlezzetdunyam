<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * `statuses` tablosuna makine okunur durum kodu ekler.
 *
 * NEDEN GEREKLİ: TastyIgniter'ın `statuses` tablosunda kod alanı yoktur —
 * yalnızca `status_id` (tamsayı) ve `status_name` (görünen ad) vardır.
 * Sözleşmemiz (`docs/openapi.yaml` `OrderStatus`) ise sabit yedi kod tanımlar:
 * yeni, onaylandi, hazirlaniyor, hazir, yolda, teslim_edildi, iptal.
 *
 * Bu kolon olmadan API'nin durumu koda çevirmesi ya kırılgan ad eşleşmesine
 * ya da koddan kopabilecek bir id haritasına bağlı kalırdı. Yönetici admin
 * panelde "Hazırlanıyor" görürken API "hazirlaniyor" döner.
 *
 * ADR-02 ihlali DEĞİLDİR: çekirdeğin dosyalarına dokunulmaz, yalnızca kendi
 * migration'ımız mevcut tabloya eklemeli bir kolon açar.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('statuses', function (Blueprint $table): void {
            $table->string('status_code', 32)->nullable()->after('status_name');
            // Kod benzersizdir ama NULL serbesttir: TastyIgniter'ın kendi
            // rezervasyon durumları (status_for='reservation') kodsuz kalır.
            $table->unique('status_code');
        });
    }

    public function down(): void
    {
        Schema::table('statuses', function (Blueprint $table): void {
            $table->dropUnique(['status_code']);
            $table->dropColumn('status_code');
        });
    }
};
