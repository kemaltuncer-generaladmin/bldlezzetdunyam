<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * K-12: sipariş revizyonları — mutfağın müşteriyle konuşup yaptığı
 * değişikliğin kaydı.
 *
 * NEDEN AYRI TABLO, NEDEN `orders` ÜZERİNE YAZMAK YETMİYOR: değişikliğin
 * kendisi bir belgedir. "20 mercimek 10'a düştü, sebep: müşteri talebi,
 * 180 TL iade" bilgisi silinirse geriye yalnız 10 mercimeklik bir sipariş
 * kalır ve müşteri "ben 20 istemiştim" dediğinde kimsenin elinde kanıt
 * olmaz. Cari hesap düzeltmesi ve iade de bu kayda bağlanıyor.
 *
 * `before_json` / `after_json` TAM ANLIK GÖRÜNTÜ tutar, fark değil: farkı
 * saklamak, ara bir revizyon silindiğinde ya da şema değiştiğinde geçmişi
 * yeniden kurulamaz hâle getirirdi.
 *
 * `UNIQUE(order_id, revision_no)` — aynı sipariş için iki kez "revizyon 2"
 * yazılamaz; eşzamanlı iki kasa yarışırsa ikincisi hata alır ve yeniden
 * dener, sessizce üzerine yazmaz.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('veykemtu_order_revisions', function (Blueprint $table): void {
            $table->id();
            $table->unsignedBigInteger('order_id')->index();
            $table->unsignedInteger('revision_no');

            $table->string('reason', 160);
            $table->text('note')->nullable();

            // Tam anlık görüntüler (kalemler, teslimat bilgisi, notlar).
            $table->json('before_json');
            $table->json('after_json');

            // Tutarlar kuruş (int) — `Support\Money` ile aynı birim.
            $table->integer('subtotal_before_kurus');
            $table->integer('subtotal_after_kurus');
            $table->integer('total_before_kurus');
            $table->integer('total_after_kurus');

            // İkisi de pozitif; hangisinin dolu olduğu yönü belirler.
            // Tek bir işaretli alan yerine iki alan: "iade" ile "ek
            // tahsilat" muhasebede ayrı kalemler ve raporda ayrı toplanır.
            $table->unsignedInteger('refund_kurus')->default(0);
            $table->unsignedInteger('extra_charge_kurus')->default(0);

            // Kim yaptı: kasa kimliği (mutfak) ya da yönetici kullanıcı.
            $table->unsignedBigInteger('created_by_device_id')->nullable();
            $table->unsignedBigInteger('created_by_staff')->nullable();
            $table->timestamp('created_at')->nullable();

            $table->unique(['order_id', 'revision_no']);
        });

        // İstemcilerin "revize edildi" gösterebilmesi ve fiş tekilliğinin
        // revizyon bazlı olabilmesi için sipariş üzerinde sayaç.
        Schema::table('orders', function (Blueprint $table): void {
            $table->unsignedInteger('bld_revision_no')->default(0);
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table): void {
            $table->dropColumn('bld_revision_no');
        });

        Schema::dropIfExists('veykemtu_order_revisions');
    }
};
