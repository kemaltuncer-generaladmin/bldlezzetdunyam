<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * K-11: "bugün tükendi" işaretleri.
 *
 * NEDEN `menus.menu_status` KULLANILMIYOR: o alan yöneticinin KALICI
 * kararıdır ("bu ürün artık satılmıyor"). Mutfağın kararı günlüktür
 * ("bugünlük bitti"). Aynı alanı paylaşsalardı, akşam tükenen bir ürünü
 * ertesi sabah yöneticinin elle geri açması gerekirdi ve bir sabah
 * unutulduğunda ürün sessizce menüden düşerdi.
 *
 * `sold_out_on` bir TARİH — saat değil. Gün dönümünde kayıt kendiliğinden
 * geçersizleşiyor; temizleyecek bir cron yok, dolayısıyla cron durduğunda
 * ürünlerin kapalı kalması gibi bir arıza da yok. Eski satırlar bir işe
 * yaramaz ama kayıt olarak durur: "hangi ürün hangi gün bitti" sorusunun
 * cevabıdır.
 *
 * `UNIQUE(menu_id, sold_out_on)`: aynı ürün aynı gün iki kez
 * işaretlenemez; `insertOrIgnore` ile idempotent yazılır.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('veykemtu_menu_soldout', function (Blueprint $table): void {
            $table->id();
            $table->unsignedBigInteger('menu_id')->index();
            $table->date('sold_out_on');
            $table->string('reason', 160)->nullable();

            // Kim işaretledi: kasa kimliği (mutfak) ya da yönetici kullanıcı.
            // İkisi ayrı sütun çünkü ayrı tablolara bakıyorlar ve birini
            // diğerinin kimliğiyle karıştırmak yanlış kişiyi suçlar.
            $table->unsignedBigInteger('device_id')->nullable();
            $table->unsignedBigInteger('created_by')->nullable();
            $table->timestamp('created_at')->nullable();

            $table->unique(['menu_id', 'sold_out_on']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('veykemtu_menu_soldout');
    }
};
