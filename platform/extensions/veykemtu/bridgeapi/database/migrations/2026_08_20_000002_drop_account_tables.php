<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Cari hesabı şemadan kaldırır — iş modeli değişti (`docs/00`).
 *
 * **ŞEMA GERİ ALINABİLİR, VERİ GERİ ALINAMAZ.** `down()` üç tabloyu ve
 * kolonu BOŞ olarak geri kurar; içlerindeki tek bir satırı bile geri
 * getirmez. Verinin tek yolu arşiv komutudur:
 *
 *     php artisan veykemtu:cari-arsivle
 *
 * Komut `..._000001_export_account_data_before_drop` göçünden de çağrılır,
 * ama asıl adım operatörün ELLE koşup dizini sunucudan indirmesidir —
 * konteyner dosya sistemi geçicidir (`docs/RUNBOOK.md` §9).
 *
 * Sahibi geri dönüşü olmadığı söylendikten sonra onayladı.
 *
 * DÜŞÜRME SIRASI YUKARIDAN AŞAĞI DEĞİL, BAĞIMLILIKTAN BAĞIMSIZA:
 * ödemeler → dönemler → defter. Aralarında yabancı anahtar kısıtı yok
 * (referanslar mantıksal), ama sıra yine de anlamlı: defter asıl kayıt,
 * diğer ikisi ona bakan tablolar. Asıl kaydı en sona bırakmak, göç
 * ortasında düşerse elde en değerli tablonun kalmasını sağlar.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::dropIfExists('veykemtu_account_payments');
        Schema::dropIfExists('veykemtu_account_periods');
        Schema::dropIfExists('veykemtu_account_ledger');

        if (Schema::hasColumn('customers', 'bld_credit_limit_kurus')) {
            Schema::table('customers', function (Blueprint $table): void {
                $table->dropColumn('bld_credit_limit_kurus');
            });
        }

        /*
         * `payments` SATIRI SİLİNMEZ — tarihsel kayıt.
         *
         * `orders.payment` alanı `payments.code` ile eşleşiyor; satır
         * silinseydi eski cari siparişlerin `Order::$payment_method`
         * ilişkisi `null` döner ve ödeme günlüğü "property on null" ile
         * patardı (gerekçenin tamamı: `OfflinePayment` docblock'u).
         *
         * `Payment::applyGatewayClass()` sınıf yoksa `class_name`'i zaten
         * boşaltıyor ve `listPayments()` o satırları eliyor — yani panelde
         * seçilebilir bir yöntem olarak GÖRÜNMEZ. Buradaki güncelleme
         * bunu VERİTABANINDA kalıcı kılıyor: aksi hâlde admin Ödemeler
         * listesinde sınıfı olmayan, açılmayan bir satır durur.
         *
         * `class_name` NULL DEĞİL BOŞ DİZE: çekirdek kolonu `text NOT NULL`
         * tanımlamış (`2017_06_11_000300_create_payments_and_payment_logs_table`).
         * Bugün `strict => false` olduğu için NULL sessizce boş dizeye
         * çevrilirdi; yarın biri strict moda geçtiğinde aynı satır göçü
         * patlatırdı. Eleme koşulu (`(string) $class_name !== ''`) her iki
         * değerde de aynı sonucu verdiğinden şemaya uyanı yazıyoruz.
         */
        DB::table('payments')
            ->where('code', 'account')
            ->update(['status' => 0, 'class_name' => '']);
    }

    public function down(): void
    {
        // Tablolar ORİJİNAL şemasıyla, BOŞ olarak geri kurulur. İndeksler
        // dahil: geri dönen bir şemanın yarısı, şema değildir.
        Schema::create('veykemtu_account_ledger', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->unsignedBigInteger('customer_id');
            $table->string('entry_type', 8);
            $table->bigInteger('amount_kurus');
            $table->string('source', 16);
            $table->string('reference_type', 32)->nullable();
            $table->unsignedBigInteger('reference_id')->nullable();
            $table->string('description', 255)->nullable();
            $table->date('effective_date');
            $table->unsignedBigInteger('created_by')->nullable();
            $table->timestamp('created_at')->nullable();

            $table->unique(
                ['source', 'reference_type', 'reference_id', 'entry_type'],
                'veykemtu_ledger_kaynak_essiz',
            );
            $table->index(['customer_id', 'effective_date'], 'veykemtu_ledger_musteri_tarih');
            $table->index(['customer_id', 'id'], 'veykemtu_ledger_musteri_id');
        });

        Schema::create('veykemtu_account_periods', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->unsignedBigInteger('customer_id');
            $table->string('period', 7);
            $table->bigInteger('opening_kurus')->default(0);
            $table->bigInteger('debit_total_kurus')->default(0);
            $table->bigInteger('credit_total_kurus')->default(0);
            $table->bigInteger('closing_kurus')->default(0);
            $table->timestamp('generated_at')->nullable();

            $table->unique(['customer_id', 'period'], 'veykemtu_period_essiz');
        });

        Schema::create('veykemtu_account_payments', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->unsignedBigInteger('customer_id')->index();
            $table->unsignedBigInteger('amount_kurus');
            $table->bigInteger('balance_at_start');
            $table->string('status', 16)->default('pending')->index();
            $table->string('hash', 64)->unique();
            $table->string('provider_ref', 128)->nullable();
            $table->string('gateway', 32)->nullable();
            $table->timestamp('created_at')->nullable();
            $table->timestamp('settled_at')->nullable();
        });

        if (!Schema::hasColumn('customers', 'bld_credit_limit_kurus')) {
            Schema::table('customers', function (Blueprint $table): void {
                $table->unsignedInteger('bld_credit_limit_kurus')->nullable();
            });
        }

        /*
         * `payments` SATIRI GERİ AÇILMAZ. `AccountPayment` sınıfı da
         * silindi; satırı `status = 1` yapmak, sınıfı olmayan bir ödeme
         * yöntemini panelde etkin göstermek olurdu. Geri alma şemayı
         * kurtarır, kaldırılan kodu değil.
         */
    }
};
