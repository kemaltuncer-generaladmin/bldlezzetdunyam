<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * `veykemtu_daily_menus.cutoff_time` — GÜNE ÖZEL kesim saati (S1).
 *
 * İş kararı 3: "her servis günü KENDİ sabah kesim saatinde kapanır". Vitrinin
 * genel kesim saati (`location_options.bld_order_cutoff`) bunun varsayılanı;
 * bu kolon o günü tek tek ezmek içindir. Birleştirme kuralı tektir ve
 * `OrderingWindow::cutoffFor()` içinde yaşar: `gün.cutoff_time ?? ayar`.
 *
 * NULLABLE VE VARSAYILANI `null` — MEVCUT SATIRLAR ETKİLENMEZ. `null`
 * "bu güne özel bir saat girilmedi, genel ayar geçerli" demektir. Kolona
 * genel saatin kopyası yazılsaydı iki doğruluk kaynağı doğardı: yönetici
 * genel saati değiştirdiğinde girilmiş günlerin hiçbiri takip etmezdi.
 *
 * KOLON ADI SÖZLEŞMEDEN: `docs/control/menu.md` → `DailyMenuDay.cutoff_time`
 * "(yeni kolon)" diyor ve Kontrol Merkezi uçları o adı okuyacak.
 *
 * `time` tipi, `datetime` değil: kesim bir SAATTİR, bir an değil. Mutlak an
 * (`cutoff_at`) servis gününün takviminden türetilir — depolamak, gün
 * kaydırıldığında (menü kopyalama) sessizce yanlış bir ana bağlanmak olurdu.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasColumn('veykemtu_daily_menus', 'cutoff_time')) {
            return;
        }

        Schema::table('veykemtu_daily_menus', function (Blueprint $table): void {
            $table->time('cutoff_time')->nullable()->after('status');
        });
    }

    public function down(): void
    {
        if (!Schema::hasColumn('veykemtu_daily_menus', 'cutoff_time')) {
            return;
        }

        Schema::table('veykemtu_daily_menus', function (Blueprint $table): void {
            $table->dropColumn('cutoff_time');
        });
    }
};
