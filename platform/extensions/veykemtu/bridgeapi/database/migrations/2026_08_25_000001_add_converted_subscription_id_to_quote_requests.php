<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * `veykemtu_quote_requests.converted_subscription_id` — I1.
 *
 * ═════════════════════════════════════════════════════════════════════════
 * BUGÜN AYNI TALEP İKİ KEZ ABONELİĞE ÇEVRİLEBİLİYOR.
 *
 * `SubscriptionController::convertRequest()` çakışma kapısını kuruyor ve
 * Kontrol Merkezi ekranı da "ikinci kez çevirmek sunucuda reddedilir"
 * yazıyor. İkisi de bu kolonu okuyor; kolon olmadığı için `convertedIdOf()`
 * HER ZAMAN `null` döndürüyor, kapı hiç kapanmıyor ve iki kez basılan bir
 * düğme aynı müşteriye iki abonelik açıyor. İkinci abonelik ayrı bir kural
 * olarak üretim yapmaya başlıyor: mutfak aynı adrese iki kez yemek
 * gönderiyor ve fark, fatura kesilirken görülüyor.
 *
 * Kapıyı koda yazmak yetmiyordu; kapının DAYANDIĞI VERİ eksikti.
 * ═════════════════════════════════════════════════════════════════════════
 *
 * ─────────────────────────────────────────────────────────────────────────
 * NEDEN YABANCI ANAHTAR YOK.
 *
 * Abonelik satırı silinmiyor (iptal ediliyor), yani "ölü referans" riski
 * pratikte yok. Buna karşılık bir yabancı anahtar, talep tablosunu abonelik
 * tablosunun ömrüne zincirler ve `veykemtu_subscriptions` üzerinde ileride
 * yapılacak her yeniden adlandırma/taşıma işini iki tabloya yayardı. Aynı
 * gerekçe `veykemtu_sms_log.subscription_id` ve `orders.bld_subscription_id`
 * için de geçerli ve depoda tutarlı bir seçim.
 * ─────────────────────────────────────────────────────────────────────────
 *
 * BENZERSİZ İNDEKS BİLİNÇLİ OLARAK **YOK**. Kapı "bu TALEP zaten
 * çevrilmiş mi" diye sorar, "bu ABONELİK bir talepten mi doğdu" diye değil.
 * Benzersizlik abonelik tarafını kilitlerdi ve iki farklı talebi tek bir
 * aboneliğe bağlamak (birleştirme) ileride istenebilecek, bugün
 * yasaklanmasına gerek olmayan bir şey. Tekillik zaten `id` birincil
 * anahtarında: bir talep satırının tek bir `converted_subscription_id`'si
 * olabilir.
 *
 * NULL = "henüz çevrilmedi". Sıfır nöbetçi DEĞİL: `0` geçerli bir abonelik
 * kimliği gibi görünür ve `convertedIdOf()` onu "çevrilmiş" sayıp bütün
 * talepleri kilitlerdi.
 */
return new class extends Migration
{
    private const string TABLE = 'veykemtu_quote_requests';

    private const string COLUMN = 'converted_subscription_id';

    public function up(): void
    {
        if (!Schema::hasTable(self::TABLE) || Schema::hasColumn(self::TABLE, self::COLUMN)) {
            return;
        }

        Schema::table(self::TABLE, function (Blueprint $table): void {
            $table->unsignedBigInteger(self::COLUMN)->nullable()->after('id');

            // İNDEKS SORGU İÇİN DEĞİL, KAPI İÇİN. `convertRequest()` her
            // dönüşümde "bu abonelik zaten bir talepten mi doğdu" diye de
            // bakabilsin ve liste ekranı çevrilmiş talepleri süzebilsin.
            $table->index(self::COLUMN, 'veykemtu_talep_abonelik');
        });
    }

    public function down(): void
    {
        if (!Schema::hasTable(self::TABLE) || !Schema::hasColumn(self::TABLE, self::COLUMN)) {
            return;
        }

        Schema::table(self::TABLE, function (Blueprint $table): void {
            $table->dropIndex('veykemtu_talep_abonelik');
            $table->dropColumn(self::COLUMN);
        });
    }
};
