<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * `orders.bld_released_at` — siparişin mutfağa AÇILDIĞI an (iş kararı 7).
 *
 * Abonelik siparişleri gece 22:00'de üretiliyor ama KDS'e 07:00'de düşmeli.
 * Gecikme olmasaydı sabah 05:00'te işbaşı yapan mutfak, ekranı kırk abonelik
 * kartıyla dolu bulur ve o an gelen GERÇEK bir siparişi göremezdi. Serbest
 * bırakma saati panoyu vardiya başlangıcıyla hizalar.
 *
 * **NULL = SERBEST.** Göçten önceki her satır ve bundan sonraki her vitrin
 * siparişi `null` kalır; hiçbiri etkilenmez. Varsayılanı "beklet" yapmak,
 * tek bir kolon eklemesiyle bütün panoyu karartmak olurdu.
 *
 * NEDEN BOOLEAN DEĞİL AN: kapı "şimdi"ye göre kendiliğinden açılıyor, hiçbir
 * arka plan işi bayrak çevirmiyor. Bir cron'a bağlansaydı, cron'un koşmadığı
 * her sabah mutfak boş ekrana bakardı. Ayrıca "ne zaman açılacak" sorusunu
 * yalnız bir an cevaplayabilir; panelde saatin kendisi gösteriliyor.
 *
 * İNDEKSLİ: mutfak panosu her yoklamada (birkaç saniyede bir) bu kolona
 * bakıyor.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasColumn('orders', 'bld_released_at')) {
            return;
        }

        Schema::table('orders', function (Blueprint $table): void {
            $table->timestamp('bld_released_at')->nullable()->index();
        });
    }

    public function down(): void
    {
        if (!Schema::hasColumn('orders', 'bld_released_at')) {
            return;
        }

        Schema::table('orders', function (Blueprint $table): void {
            // İndeks kolonla birlikte düşer; adını ayrıca vermek, göçün
            // MySQL dışı bir sürücüde adlandırma farkıyla patlaması demekti.
            $table->dropColumn('bld_released_at');
        });
    }
};
