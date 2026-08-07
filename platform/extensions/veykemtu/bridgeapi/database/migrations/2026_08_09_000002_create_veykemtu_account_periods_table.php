<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Cari ay-sonu kapanış özeti (denetim anlık görüntüsü).
 *
 * Bakiye her zaman defterden runtime hesaplanır; bu tablo ay sonunda dönemi
 * "dondurur" — açılış/borç/alacak/kapanış tek satırda. Fatura DEĞİLDİR
 * (e-Arşiv Faz 3); ekstre ve ay-sonu mutabakatı için özet veridir.
 *
 * İdempotent: `UNIQUE(customer_id, period)` — ay-sonu işi iki kez koşarsa
 * dönem satırı güncellenir, çoğalmaz.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('veykemtu_account_periods', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->unsignedBigInteger('customer_id');
            $table->string('period', 7); // YYYY-MM
            $table->bigInteger('opening_kurus')->default(0);
            $table->bigInteger('debit_total_kurus')->default(0);
            $table->bigInteger('credit_total_kurus')->default(0);
            $table->bigInteger('closing_kurus')->default(0);
            $table->timestamp('generated_at')->nullable();

            $table->unique(['customer_id', 'period'], 'veykemtu_period_essiz');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('veykemtu_account_periods');
    }
};
