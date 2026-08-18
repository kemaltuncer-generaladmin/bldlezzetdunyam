<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * `veykemtu_subscription_pauses.cancelled_at` — I2.
 *
 * ═════════════════════════════════════════════════════════════════════════
 * BAŞLAMAMIŞ BİR DURAKLATMAYI GERİ ALMANIN YOLU YOKTU.
 *
 * `SubscriptionController::resume()` duraklamayı "bugün itibarıyla"
 * kapatıyor: `end_date = dün`. Satır GELECEKTEYSE (yönetici yarın için
 * duraklatma girdi ve hemen vazgeçti) bu, `end_date < start_date` olan bir
 * satır bırakıyor. Böyle bir satır hiçbir günü kapsamıyor gibi görünse de
 * aralık karşılaştırmaları (`betweenIncluded`) ters aralıkta tanımsız
 * davranır ve ekranda "12.09 – 10.09" diye okunan bir tarih aralığı çıkar.
 *
 * Satır SİLİNEMEZ (geçmişteki boş günlerin sebebi kalmalı) ve tarihleri
 * yeniden yazmak da geçmişi değiştirmek olurdu. Doğru cevap üçüncü bir
 * alan: "bu duraklatma yürürlüğe girmeden iptal edildi".
 * ═════════════════════════════════════════════════════════════════════════
 *
 * NEDEN `boolean` DEĞİL ZAMAN DAMGASI: "iptal edildi mi" sorusunun yanında
 * "ne zaman" sorusu her zaman soruluyor ve bir `boolean`, ikinci soru
 * geldiğinde ikinci bir göç demekti. `NULL` = yürürlükte.
 *
 * BAŞLAMIŞ BİR DURAKLATMA BU KOLONU KULLANMAZ: orada `resume()` yine
 * `end_date`'i düne çeker, çünkü duraklatma GERÇEKTEN yaşandı ve o günler
 * gerçekten boş kaldı. İki durumu tek alana sıkıştırmak, "hiç olmadı" ile
 * "erken bitti"yi aynı şey saymak olurdu.
 */
return new class extends Migration
{
    private const string TABLE = 'veykemtu_subscription_pauses';

    private const string COLUMN = 'cancelled_at';

    public function up(): void
    {
        if (!Schema::hasTable(self::TABLE) || Schema::hasColumn(self::TABLE, self::COLUMN)) {
            return;
        }

        Schema::table(self::TABLE, function (Blueprint $table): void {
            $table->timestamp(self::COLUMN)->nullable();
        });
    }

    public function down(): void
    {
        if (!Schema::hasTable(self::TABLE) || !Schema::hasColumn(self::TABLE, self::COLUMN)) {
            return;
        }

        Schema::table(self::TABLE, function (Blueprint $table): void {
            $table->dropColumn(self::COLUMN);
        });
    }
};
