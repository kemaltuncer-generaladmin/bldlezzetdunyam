<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Abonelik dönem ödemesi (30 günlük peşin) — `docs/openapi.yaml` §Ödeme.
 *
 * BU TABLO SIFIRDAN TASARLANMADI. Kaldırılan cari ödeme niyeti tablosunun
 * (`veykemtu_account_payments`) bilinçli devamıdır: yapısı sağlamdı, yalnız
 * amacı kalktı. Devralınan gerekçeler `docs/control/_devralinan-odeme-yapisi.md`
 * dosyasında kod parçalarıyla duruyor. Özet:
 *
 *  1. **Niyet ayrı bir satırdır.** Ödeme sağlayıcısına gidip dönmek gerekiyor
 *     ve dönüş güvenilmez: kullanıcı sekmeyi kapatır, sağlayıcı geri-aramayı
 *     iki kez gönderir, ağ kopar. Niyeti önce `pending` yazıp dönüşte
 *     `succeeded`'a çevirmek, "ödeme başladı ama bitmedi" durumunu **temsil
 *     edilebilir** kılıyor. Aboneliği doğrudan `active` yapmak, yarıda kalan
 *     her denemeyi bedava bir aboneliğe çevirirdi.
 *  2. **Dışa kimlik `hash`.** Sıralı `id` ödeme adresinde görünmez; adres
 *     tahmin edilerek başkasının ödeme sayfası açılamamalı.
 *  3. **İdempotans şemada.** `UNIQUE(subscription_id, period_start)` — dönem
 *     başına TEK niyet. Kodun `if`'i bir yarışta delinse bile ikinci satır
 *     yazılamaz; yinelenen geri-arama ikinci bir `succeeded` üretemez.
 *
 * NEDEN `period_start` + `period_end`, "ay" DEĞİL: dönem 30 GÜNDÜR, takvim
 * ayı değil. Abonelik ayın 17'sinde başlarsa dönemi de 17'sinde biter; takvim
 * ayına yuvarlamak ilk dönemi kısaltır ve müşteriden eksik gün için tam para
 * almış oluruz. Sözleşmedeki `period` alanı (`YYYY-AA`) bu tarihten
 * TÜRETİLİR — sunum biçimi, saklama birimi değil.
 *
 * NEDEN `portions_planned` ve `unit_price_kurus` DE SAKLANIYOR: tutar
 * `porsiyon × birim fiyat` çarpımıdır ve iki çarpan da sonradan değişebilir
 * (yönetici fiyatı günceller, abone gün atlar). Yalnız `amount_kurus`
 * saklansaydı "neden 4.500 TL ödedim" sorusunun cevabı hiçbir yerde
 * olmazdı — tıpkı devralınan yapıdaki `balance_at_start` gibi, bu iki alan
 * da denetim için var.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('veykemtu_subscription_payments', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->unsignedBigInteger('subscription_id')->index();

            // Dönem: 30 gün, iki uç dâhil.
            $table->date('period_start');
            $table->date('period_end');

            // Denetim çarpanları — `amount_kurus = portions_planned × unit_price_kurus`.
            $table->unsignedInteger('portions_planned');
            $table->unsignedBigInteger('unit_price_kurus');

            // Kuruş — `docs/11` §0. Her zaman pozitif.
            $table->unsignedBigInteger('amount_kurus');

            // pending | succeeded | failed | refunded
            $table->string('status', 16)->default('pending')->index();

            // Dışarıya verilen TEK tanımlayıcı; `id` asla URL'de görünmez.
            $table->string('hash', 64)->unique();

            // Gerçek POS bağlandığında sağlayıcının işlem numarası buraya.
            $table->string('gateway', 32)->nullable();
            $table->string('provider_ref', 128)->nullable();

            $table->timestamp('created_at')->nullable();
            $table->timestamp('settled_at')->nullable();

            /*
             * DÖNEM BAŞINA TEK NİYET.
             *
             * Geri dönüp tekrar deneyen abone ikinci bir kayıt bırakamaz;
             * bıraksaydı ikisi de sağlayıcıda ayrı ayrı yaşar ve biri
             * gecikmeli başarıya dönerse aynı dönem iki kez tahsil edilirdi.
             */
            $table->unique(['subscription_id', 'period_start'], 'veykemtu_sub_pay_donem_essiz');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('veykemtu_subscription_payments');
    }
};
