<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * `personal_access_tokens` tablosuna `expires_at` ekler.
 *
 * NEDEN GEREKLİ: tablo, TastyIgniter'ın kurduğu eski bir Sanctum
 * migration'ından geliyor ve bu kolonu içermiyor. Kurulu `laravel/sanctum`
 * 4.3.3 ise her `createToken()` çağrısında `expires_at` yazmaya çalışıyor;
 * kolon yoksa giriş `1054 Unknown column` ile 500 veriyor.
 *
 * Eklemeli migration — çekirdek dosyaya dokunulmuyor, ADR-02 ihlali değil.
 *
 * Değer her zaman NULL kalır: sözleşme token'ları süresiz tanımlıyor
 * (ADR-08 — cihaz token'ı admin panelden iptal edilir, kendiliğinden
 * sona ermez). Kolon yalnızca Sanctum'un beklentisini karşılamak için var.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasColumn('personal_access_tokens', 'expires_at')) {
            return;
        }

        Schema::table('personal_access_tokens', function (Blueprint $table): void {
            $table->timestamp('expires_at')->nullable()->after('last_used_at');
        });
    }

    public function down(): void
    {
        if (!Schema::hasColumn('personal_access_tokens', 'expires_at')) {
            return;
        }

        Schema::table('personal_access_tokens', function (Blueprint $table): void {
            $table->dropColumn('expires_at');
        });
    }
};
