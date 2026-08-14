<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * `order_menus` — menü paketi bağı (B-19, additive).
 *
 * Sipariş bir PAKET SATIRI + SIFIR FİYATLI BİLEŞEN SATIRLARI olarak yazılıyor:
 *
 *   Günün Menüsü ×2        role=package    18000 × 2
 *     ↳ Mercimek Çorbası ×2 role=component  0
 *     ↳ Tavuk Sote ×2       role=component  0
 *
 * Parayı paket satırı taşır; bileşenler mutfağa "ne pişecek" bilgisini verir
 * ve `ProductionListService` içinde GERÇEK `menu_id`'leriyle toplanır.
 *
 * Bu kalıp yeni değil: abonelik siparişleri baştan beri böyle yazılıyor
 * (`OrderFactory::resolveSubscriptionLines` bileşenleri `unit_price: 0` ile
 * yazıyor, para `order_totals`'ta). Paket satırının eklenmesi aslında
 * aboneliğin bugün BOZDUĞU bir değişmezi de onarıyor: `sum(order_menus.
 * subtotal)` artık `order_totals.subtotal` ile tutuyor.
 *
 * Gerekçe ve reddedilen alternatifler: `docs/03-api-sozlesmesi.md` §4.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('order_menus', function (Blueprint $table): void {
            if (!Schema::hasColumn('order_menus', 'bld_daily_menu_id')) {
                $table->unsignedBigInteger('bld_daily_menu_id')->nullable()->index();
            }

            if (!Schema::hasColumn('order_menus', 'bld_line_role')) {
                // `package` | `component` | null (sıradan ürün satırı).
                //
                // Null bırakılıyor, `'item'` yazılmıyor: mevcut milyonlarca
                // satırı güncellemek gereksiz ve okuyan taraf zaten
                // `?? 'item'` diyor.
                $table->string('bld_line_role', 16)->nullable();
            }

            if (!Schema::hasColumn('order_menus', 'bld_parent_line_id')) {
                // Bileşen satırının ait olduğu paket satırının
                // `order_menu_id`'si.
                $table->unsignedBigInteger('bld_parent_line_id')->nullable()->index();
            }
        });
    }

    public function down(): void
    {
        Schema::table('order_menus', function (Blueprint $table): void {
            foreach (['bld_daily_menu_id', 'bld_line_role', 'bld_parent_line_id'] as $column) {
                if (Schema::hasColumn('order_menus', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
