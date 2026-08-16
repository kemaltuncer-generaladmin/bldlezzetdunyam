<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * `orders.bld_stock_released_at` — stok kredisi BİR KEZ verilir (S2).
 *
 * İptal, siparişin düştüğü porsiyonları stoka geri veriyor
 * (`DailyStock::releaseOrder()`). Bu kolon olmadan ikinci bir iptal çağrısı
 * — çift tıklama, KDS'in yeniden denemesi, panelden ve mutfaktan aynı anda
 * basılan iptal — aynı porsiyonları İKİNCİ KEZ geri verir ve o gün tavanın
 * üstünde satış açılır. Arıza sessizdir: kimse bir hata görmez, yalnız
 * mutfak akşam iki porsiyon fazla sipariş bulur.
 *
 * NEDEN BOOLEAN DEĞİL AN: "ne zaman geri verildi" sorusu iptal sonrası stok
 * tartışmasının ilk sorusu ve boolean onu cevaplayamaz. Bir alanın maliyeti
 * aynı, taşıdığı bilgi fazla.
 *
 * NULLABLE VE GERİYE DOLDURULMUYOR: göçten önceki iptaller stok hiç
 * düşmemiş siparişlerdi, geri verilecek bir şeyleri yok. `null` = "bu
 * siparişin stoku henüz geri verilmedi" ve iptal edilmemiş her sipariş için
 * de doğru olan bu.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasColumn('orders', 'bld_stock_released_at')) {
            return;
        }

        Schema::table('orders', function (Blueprint $table): void {
            $table->timestamp('bld_stock_released_at')->nullable();
        });
    }

    public function down(): void
    {
        if (!Schema::hasColumn('orders', 'bld_stock_released_at')) {
            return;
        }

        Schema::table('orders', function (Blueprint $table): void {
            $table->dropColumn('bld_stock_released_at');
        });
    }
};
