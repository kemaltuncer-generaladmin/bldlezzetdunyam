<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Mutfak kasaları — docs/02-veri-modeli.md §2.1. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('veykemtu_kitchen_devices', function (Blueprint $table): void {
            $table->id();
            $table->string('name', 64);
            // Tek kullanımlık eşleme kodu; kullanılınca null'a çekilir.
            $table->string('pairing_code', 16)->nullable()->unique();
            $table->timestamp('pairing_expires_at')->nullable();
            $table->timestamp('last_seen_at')->nullable();
            // Dolu ise cihaz iptal edilmiştir → 403 DEVICE_REVOKED.
            $table->timestamp('revoked_at')->nullable();
            $table->timestamps();

            // Admin panelde "5 dakikadan eski" uyarısı bu sütunu tarar.
            $table->index('last_seen_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('veykemtu_kitchen_devices');
    }
};
