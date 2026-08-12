<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Telefonla giriş kodları — B-18.
 *
 * Kurumsal müşteri her sipariş için şifre hatırlamak zorunda kalmasın diye:
 * telefon yaz, gelen kodu gir, içeri gir. E-posta + şifre yolu kalıyor;
 * bu ikinci bir kapı, tek kapı değil.
 *
 * KOD AÇIK YAZILMAZ. Veritabanı yedeği sızarsa açık kodlar, kısa ömürlü de
 * olsa, aktif giriş anahtarlarıdır. `code_hash` bcrypt: 6 haneli bir kodun
 * uzayı küçük (10^6) ve hızlı bir özet fonksiyonu kaba kuvvetle saniyeler
 * içinde çözülür.
 *
 * SATIRLAR SİLİNMEZ, TÜKETİLİR (`consumed_at`). Silinseydi "bu kod daha önce
 * kullanıldı mı" sorusu yanıtsız kalırdı ve aynı kod tekrar kabul edilirdi.
 *
 * `attempts` KOLONU KABA KUVVETE KARŞI: oran sınırı IP başına çalışıyor
 * (`throttle:bld-auth`), ama saldırgan IP değiştirebilir. Deneme sayacı
 * KODA bağlı olduğu için IP değiştirmek işe yaramıyor.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('veykemtu_otp_codes', function (Blueprint $table): void {
            $table->bigIncrements('id');

            // Normalleştirilmiş 10 hane (başında 0 ve +90 olmadan) — kayıt
            // ucundaki `telephone` ile aynı biçim, yoksa eşleşme tutmaz.
            $table->string('phone', 16)->index();

            $table->string('code_hash', 255);
            $table->timestamp('expires_at');

            // Yanlış deneme sayacı. Eşiğe ulaşan kod ölür; yeni kod istenmeli.
            $table->unsignedTinyInteger('attempts')->default(0);

            $table->timestamp('consumed_at')->nullable();
            $table->timestamp('created_at')->nullable();

            // "Bu telefon için geçerli kod var mı" sorgusu her istekte koşuyor.
            $table->index(['phone', 'consumed_at'], 'veykemtu_otp_telefon_durum');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('veykemtu_otp_codes');
    }
};
