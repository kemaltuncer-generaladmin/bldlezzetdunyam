<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * K-13: iade kayıtları.
 *
 * NEDEN `bridgeapi` GÖÇÜNDE, `payment` EKLENTİSİNDE DEĞİL: tablo sipariş
 * revizyonlarına (`veykemtu_order_revisions`) bağlı ve iki eklentiye
 * bölünmüş bir göç sırası, kurulumda hangisinin önce koşacağına bağlı
 * kırılgan bir bağımlılık yaratırdı.
 *
 * `UNIQUE(revision_id)`: bir revizyon en fazla bir iade doğurur. Çift
 * dokunma ya da yeniden deneme, müşteriye iki kez para göndermemeli.
 * `null` revizyon (elle iade) tekilliğe takılmaz — MySQL `NULL`ları
 * benzersiz saymaz ve bu tam olarak istediğimiz davranış.
 *
 * BAŞARISIZ İADE DE SATIR AÇAR: kaydetmemek onu görünmez kılardı.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('veykemtu_payment_refunds', function (Blueprint $table): void {
            $table->id();
            $table->unsignedBigInteger('order_id')->index();
            $table->unsignedBigInteger('revision_id')->nullable()->unique();

            $table->unsignedInteger('amount_kurus');
            $table->string('gateway', 32);

            // pending | succeeded | failed | manual
            $table->string('status', 16)->index();
            $table->string('provider_ref', 128)->nullable();
            $table->text('error')->nullable();
            $table->string('reason', 160)->nullable();

            $table->timestamp('created_at')->nullable();
            $table->timestamp('settled_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('veykemtu_payment_refunds');
    }
};
