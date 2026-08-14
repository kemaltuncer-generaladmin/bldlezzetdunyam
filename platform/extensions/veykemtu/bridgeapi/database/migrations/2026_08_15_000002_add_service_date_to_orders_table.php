<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `orders.bld_service_date` — siparişin HANGİ GÜN İÇİN olduğu (B-19).
 *
 * DEĞİŞMEZ KURAL: `bld_service_date === DATE(order_date)`, her yazma yolunda.
 *
 * `order_date` bugünkü anlamını koruyor — `OrderFactory` onu zaten istenen
 * teslim gününe yazıyor. Böylece `order_date` üzerinden filtreleyen her sorgu
 * (`KitchenController::orders`, `ProductionListService::today()`,
 * `SubscriptionKitchenPlan`) hiç değişmeden doğru kalıyor. Kuralın bedeli
 * iki yazma yolunda tek satır; kazancı, çalışan sorguların hiçbirini
 * ellememek.
 *
 * NEDEN AYRI KOLON — `order_date` yetmiyor mu:
 *   1. `order_date` bir tarih+saat çifti ve mutfak teslim saatini
 *      düzenlediğinde `OrderEditor` onu YENİDEN YAZIYOR. Siparişin bağlı
 *      olduğu menü günü, bir saat düzenlemesiyle sessizce kayabilirdi.
 *   2. Servis günü bir İŞ ANAHTARI: siparişin hangi günün menüsüne
 *      bağlandığını seçiyor. İndeksli olmalı ve saatten bağımsız durmalı.
 *
 * Göç mevcut satırları `DATE(order_date)` ile dolduruyor — kimse geride
 * kalmıyor, ve backfill'den sonra kolon her satırda dolu.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasColumn('orders', 'bld_service_date')) {
            Schema::table('orders', function (Blueprint $table): void {
                $table->date('bld_service_date')->nullable()->index();
            });
        }

        // Geçmiş siparişler: servis günü zaten `order_date`'ti.
        DB::table('orders')
            ->whereNull('bld_service_date')
            ->update(['bld_service_date' => DB::raw('DATE(order_date)')]);
    }

    public function down(): void
    {
        if (Schema::hasColumn('orders', 'bld_service_date')) {
            Schema::table('orders', function (Blueprint $table): void {
                $table->dropColumn('bld_service_date');
            });
        }
    }
};
