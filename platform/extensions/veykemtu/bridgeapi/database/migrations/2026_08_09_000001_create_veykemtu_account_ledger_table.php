<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Cari hesap defteri — append-only (`docs/00 §6 sınırı`).
 *
 * SINIR: Muhasebe yazılımı değiliz; e-Arşiv fatura Faz 3. Bu tablo **fatura
 * kesmez** — yalnızca borç/alacak hareketi tutar, yürüyen bakiye ve ekstre
 * üretir. `AccountPayment` geçidi bugünkü gibi siparişi `pending` bırakır;
 * tahsilat deftere ayrı bir **alacak** satırı olarak girer.
 *
 * APPEND-ONLY: Satır güncellenmez/silinmez (`docs/02 §5 stock_ledger`
 * felsefesi). Güncel bakiye = tüm satırların işaretli toplamı. Bir düzeltme
 * bile yeni bir ters satırdır — geçmiş değişmez, denetlenebilir kalır.
 *
 * `veykemtu_` öneki: tablo bizim. Ad `bld_` değil çünkü çekirdek tablo değil.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('veykemtu_account_ledger', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->unsignedBigInteger('customer_id');

            // borç = müşterinin bize borcu artar; alacak = borcu azalır (tahsilat).
            $table->string('entry_type', 8); // debit | credit

            // Her zaman POZİTİF; yön `entry_type`'ta. Kuruş (int) — Money ile.
            $table->bigInteger('amount_kurus');

            // Hareketin kaynağı: order | subscription | payment | manual | adjustment
            $table->string('source', 16);

            // Kaynağa bağlı referans (ör. order_id). Manuel girişte null.
            $table->string('reference_type', 32)->nullable();
            $table->unsignedBigInteger('reference_id')->nullable();

            $table->string('description', 255)->nullable();

            // İşletme günü (Istanbul). Ekstre bu tarihe göre gruplanır.
            $table->date('effective_date');

            // Manuel/tahsilat girişini yapan admin (varsa).
            $table->unsignedBigInteger('created_by')->nullable();

            $table->timestamp('created_at')->nullable();

            // İDEMPOTENCY: aynı siparişin borcu iki kez yazılamaz. Manuel
            // girişte reference_id null olduğundan MySQL NULL'ları tekil sayar
            // ve elle hareketler bu kısıta takılmaz (bilinçli).
            $table->unique(
                ['source', 'reference_type', 'reference_id', 'entry_type'],
                'veykemtu_ledger_kaynak_essiz',
            );

            $table->index(['customer_id', 'effective_date'], 'veykemtu_ledger_musteri_tarih');
            $table->index(['customer_id', 'id'], 'veykemtu_ledger_musteri_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('veykemtu_account_ledger');
    }
};
