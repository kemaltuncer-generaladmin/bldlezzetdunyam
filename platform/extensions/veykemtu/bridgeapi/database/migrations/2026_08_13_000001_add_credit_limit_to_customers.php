<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Cari hesap borç limiti — B-14.
 *
 * Bugüne kadar `payment_method: account` seçen her kurumsal müşteri sınırsız
 * borçlanabiliyordu: defter borcu yazıyor, hiçbir yerde "yeter" diyen bir
 * eşik yoktu. Tahsilat gecikirse zarar sessizce büyür ve ilk fark edildiği
 * yer ay-sonu özeti olurdu.
 *
 * VARSAYILAN 0 VE BU BİLİNÇLİ: yeni açılan kurumsal hesap cari hesabı
 * KAPALI başlar. Site üzerinden kurumsal kayıt otomatik onaylanıyor
 * (sipariş verebilir), ama veresiye ayrı bir güven kararıdır ve yöneticinin
 * elini gerektirir. Limitsiz açmak isteyen `NULL` yazar.
 *
 * ÜÇ DURUM, İKİ DEĞİL:
 *   0     → cari hesap kapalı, `account` ödeme yöntemi hiç görünmez
 *   n > 0 → borç n kuruşu aşamaz
 *   NULL  → sınırsız (eski davranış; bilerek seçilmeli)
 *
 * MEVCUT MÜŞTERİLER `NULL` ALIR, 0 DEĞİL. Bugün cariyle çalışan bir müşteriye
 * göç sırasında 0 yazmak, ertesi sabah sipariş veremeyen bir kurumsal hesap
 * demekti. Göç kimseyi kırmaz; sıkılaştırma yöneticinin kararıdır.
 *
 * ADR-09 ADDITIVE + `bld_` öneki: tablo çekirdeğin.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customers', function (Blueprint $table): void {
            // Kuruş — `docs/11` §0 değişmezi: para her yerde int kuruş.
            // `unsignedBigInteger` değil `unsignedInteger`: 42 milyon TL'lik
            // bir veresiye limiti bu iş için anlamsız, dar tip yanlış girişi
            // veritabanı seviyesinde yakalar.
            $table->unsignedInteger('bld_credit_limit_kurus')->nullable();
        });

        // Mevcut satırlar zaten NULL (nullable, default yok) — "sınırsız"
        // anlamına gelir ve eski davranışı korur. Açıkça yazmıyoruz ki
        // "hiçbir şey yapılmadı" ile "bilerek NULL bırakıldı" ayrımı
        // kaybolmasın; ayrım bu yorumda.
    }

    public function down(): void
    {
        Schema::table('customers', function (Blueprint $table): void {
            $table->dropColumn('bld_credit_limit_kurus');
        });
    }
};
