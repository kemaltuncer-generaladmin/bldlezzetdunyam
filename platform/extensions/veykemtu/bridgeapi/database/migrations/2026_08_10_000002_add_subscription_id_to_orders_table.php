<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Sipariş ↔ abonelik bağı — `docs/11-yol-haritasi.md` §7.5.
 *
 * ADR-09 ADDITIVE: çekirdek `orders` tablosuna yalnızca `bld_` önekli, nullable
 * kolon. Abonelikten üretilen sipariş bunu taşır; elle verilen siparişte null.
 * Sözleşmede `subscription_id` olarak açılır (KDS rozeti + istemci gösterimi).
 * Mevcut siparişler null → `is_subscription=false`; hiçbir istemci kırılmaz.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table): void {
            $table->unsignedBigInteger('bld_subscription_id')->nullable()->index();
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table): void {
            $table->dropColumn('bld_subscription_id');
        });
    }
};
