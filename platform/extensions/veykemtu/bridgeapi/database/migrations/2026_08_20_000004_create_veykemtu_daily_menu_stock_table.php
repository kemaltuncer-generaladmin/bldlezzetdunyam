<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Günlük stok tavanı — iş kararı 4 (S2).
 *
 * "Stok: gün toplamı VE ürün bazlı tavan; hangisi önce dolarsa kapatır.
 * Satır yoksa sınırsız." Bu tablo o cümlenin tamamı.
 *
 * KALAN = `capacity - reserved - sold`. Bir gün ya da bir kalem, KENDİ satırı
 * veya GÜN TOPLAMI satırı sıfırlandığında kapanır; "hangisi önce dolarsa"
 * kuralı ikisini birden denetlemekten kendiliğinden çıkar, ayrıca kodlanmış
 * bir öncelik yoktur.
 *
 * SATIR YOKSA SINIRSIZ. Tavan konmamış bir gün için hiçbir satır yazılmaz ve
 * `DailyStock::remaining()` `null` döner. `null` ile `0` asla
 * karıştırılmamalı: `null`'ı sıfır sayan taraf, tavanı hiç konmamış bir günü
 * tükenmiş gösterir (`docs/contract/sales-rules.cases.json` → değişmezler).
 *
 * ─────────────────────────────────────────────────────────────────────────
 * `menu_id = 0` GÜN TOPLAMI SATIRIDIR — `NULL` DEĞİL.
 *
 * MySQL benzersiz indekste NULL'ları birbirinden ayrı sayar: `(1,
 * '2026-08-20', NULL)` iki kez yazılabilir ve kısıt hiçbirini engellemez.
 * Yani NULL nöbetçi, aynı güne iki gün-toplamı satırına izin verir ve tavan
 * SESSİZCE İKİYE KATLANIR — kimse bir hata görmez, yalnız o gün iki katı
 * porsiyon satılır. `menus.menu_id` bir `AUTO_INCREMENT` ve asla 0 olmadığı
 * için 0 nöbetçisi çakışmaz ve tekillik gerçekten uygulanır.
 * ─────────────────────────────────────────────────────────────────────────
 *
 * `location_id` bugünden anahtarın içinde: Faz 1 tek vitrin, ama kolonu
 * sonradan eklemek, o gün tabloda aynı güne iki satır varsa BAŞARISIZ OLAN
 * bir göç demek. Bugün bedava, yarın imkânsız (`veykemtu_daily_menus`
 * göçünde aynı gerekçe).
 *
 * `reserved` ile `sold` AYRI KOLON: abonelikler stoku ÖNCE rezerve eder
 * (iş kuralı 5) ve o porsiyonlar henüz satılmamıştır. Tek kolona
 * toplansaydı "kaç tanesi gerçekten satıldı" sorusunun cevabı kaybolurdu ve
 * abonelik iptalinde neyi geri vereceğimizi bilemezdik.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('veykemtu_daily_menu_stock')) {
            return;
        }

        Schema::create('veykemtu_daily_menu_stock', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->unsignedBigInteger('location_id')->index();
            $table->date('service_date');

            // 0 = gün toplamı satırı (yukarıdaki kutuya bakın), aksi hâlde
            // çekirdek `menus.menu_id`. Yabancı anahtar yok — çekirdek de
            // tüm kısıtları düşürdü.
            $table->unsignedBigInteger('menu_id');

            $table->unsignedInteger('capacity');
            $table->unsignedInteger('reserved')->default(0);
            $table->unsignedInteger('sold')->default(0);

            // Tavanı kim yazdı: Kontrol Merkezi kullanıcısı, panel ya da
            // konsol. Serbest metin, çünkü kaynaklar ayrı tablolarda yaşıyor
            // ve birini ötekinin kimliğiyle karıştırmak yanlış kişiyi suçlar.
            $table->string('updated_by', 120)->nullable();

            $table->timestamps();

            $table->unique(
                ['location_id', 'service_date', 'menu_id'],
                'veykemtu_stok_essiz',
            );

            // Gün bazlı okumalar (katalog, takvim, tükenmiş ürün listesi)
            // vitrin ayırmadan tarihe vuruyor.
            $table->index('service_date', 'veykemtu_stok_gun');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('veykemtu_daily_menu_stock');
    }
};
