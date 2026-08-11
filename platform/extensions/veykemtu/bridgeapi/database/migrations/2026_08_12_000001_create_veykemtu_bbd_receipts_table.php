<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * K-16: BBD Store siparişleri — **yalnız ses ve fiş**.
 *
 * KESİN SINIR: bu satırlar `orders` tablosuna girmez, KDS panosunda
 * görünmez, üretim listesine / vardiya istatistiğine / `orders_today`
 * sayacına / cari hesaba karışmaz. BBD ayrı bir sunucudaki ayrı bir
 * proje; tek bağ mutfaktaki hoparlör ve termal yazıcı.
 *
 * NEDEN `orders`'a YAZILMIYOR: BBD'nin ürünleri BLD menüsünde yok,
 * fiyatları BLD'nin fiyat listesinde değil ve müşterisi BLD müşterisi
 * değil. Zorla `orders`'a sokmak, ciro raporunu, üretim listesini ve
 * cari hesabı bir gecede yanlış yapardı.
 *
 * `external_id` UNIQUE: tekilleştirmenin tamamı buna dayanıyor. BBD ağ
 * hatasında aynı siparişi tekrar gönderiyor ve ikinci fiş basılmamalı.
 *
 * `payload_json` ham gövdeyi olduğu gibi tutar: fiş içeriği ondan
 * üretiliyor ve bir alan eksik çıktığında "BBD ne göndermişti" sorusunun
 * cevabı burada.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('veykemtu_bbd_receipts', function (Blueprint $table): void {
            $table->id();
            $table->string('external_id', 128)->unique();
            $table->string('order_number', 64)->nullable();

            $table->json('payload_json');

            $table->timestamp('received_at')->nullable();

            // Kasa fişi bastığında işaretlenir. `null` = kuyrukta bekliyor.
            $table->timestamp('printed_at')->nullable();

            $table->index(['printed_at', 'id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('veykemtu_bbd_receipts');
    }
};
