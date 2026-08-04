<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Fiş basım denetimi — docs/02-veri-modeli.md §2.2. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('veykemtu_print_jobs', function (Blueprint $table): void {
            $table->id();
            $table->unsignedBigInteger('order_id');
            $table->string('type', 16);
            $table->timestamp('printed_at')->nullable();
            $table->unsignedBigInteger('device_id')->nullable();
            $table->timestamps();

            // İdempotentliğin veritabanı düzeyindeki güvencesi: uygulama
            // katmanı hata yapsa bile aynı fiş iki kez kaydedilemez.
            $table->unique(['order_id', 'type']);
            $table->index('device_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('veykemtu_print_jobs');
    }
};
