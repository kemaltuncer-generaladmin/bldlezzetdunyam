<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Cari hesap ödeme niyeti (payment intent) — B-14 / W-12.
 *
 * NEDEN AYRI BİR TABLO GEREKTİ: mevcut simülasyon POS'u SİPARİŞE bağlı
 * (`Order::where('hash', ...)`). Müşteri "cari borcumun 2.500 TL'sini
 * ödeyeyim" dediğinde ortada sipariş yok — ödenen şey bir siparişin bedeli
 * değil, birikmiş bakiye.
 *
 * NEDEN DOĞRUDAN DEFTERE YAZMIYORUZ: ödeme sağlayıcısına gidip dönmek
 * gerekiyor ve dönüş güvenilmez. Kullanıcı sekmeyi kapatabilir, sağlayıcı
 * callback'i iki kez gönderebilir, ağ kopabilir. Niyeti önce `pending` olarak
 * yazıp dönüşte `succeeded`'a çevirmek, "ödeme başladı ama bitmedi" durumunu
 * temsil edilebilir kılıyor. Defter append-only ve geri alınamaz olduğu için
 * oraya ancak sonuç kesinleştiğinde yazılır.
 *
 * İDEMPOTENCY iki katmanda:
 *   1. `status` alanı — `pending` olmayan bir niyet ikinci kez işlenmez;
 *   2. defterdeki `(payment, account_payment, id, credit)` tekil indeksi —
 *      1. katman bir yarışta delinse bile ikinci alacak satırı yazılmaz.
 *
 * `hash` dışarıya verilen tek tanımlayıcıdır; `id` sıralı ve tahmin
 * edilebilir olduğu için ödeme adresinde kullanılmaz.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('veykemtu_account_payments', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->unsignedBigInteger('customer_id')->index();

            // Kuruş — `docs/11` §0. Her zaman pozitif.
            $table->unsignedBigInteger('amount_kurus');

            // Niyet oluşturulduğu ANDAKİ bakiye. Denetim için: "2.500 TL
            // ödedim ama borcum 3.000 TL çıktı" tartışmasında, o an ekranda
            // ne yazdığını gösteren tek kayıt bu.
            $table->bigInteger('balance_at_start');

            // pending | succeeded | failed
            $table->string('status', 16)->default('pending')->index();

            // Dışarıya verilen tanımlayıcı.
            $table->string('hash', 64)->unique();

            // Gerçek POS bağlandığında sağlayıcının işlem numarası buraya.
            $table->string('provider_ref', 128)->nullable();
            $table->string('gateway', 32)->nullable();

            $table->timestamp('created_at')->nullable();
            $table->timestamp('settled_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('veykemtu_account_payments');
    }
};
