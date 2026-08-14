<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Günün menüsü — `docs/02-veri-modeli.md` §8 (B-19).
 *
 * İLKE: Satılan şey artık sabit bir katalog değil, GÜN GÜN girilen menü.
 * Yönetici takvimden bir güne menü kurar; o gün yalnız o menü —bütün olarak
 * ya da kalem kalem— satılır. `docs/11-yol-haritasi.md` §7.5'te "günün
 * menüsü kaynağı yok" diye ertelenen `menu_mode = daily_menu` aboneliği de
 * kaynağına buradan kavuşuyor.
 *
 * `location_id` BUGÜNDEN tekil anahtarın içinde. Faz 1 tek vitrin ve kolon
 * bugün hiçbir işe yaramıyor; ama sonradan eklemek, o gün tabloda aynı
 * tarihe iki satır varsa BAŞARISIZ OLAN bir göç demek. Bugün bedava, yarın
 * imkânsız.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('veykemtu_daily_menus', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->unsignedBigInteger('location_id')->index();
            $table->date('menu_date');

            $table->string('title', 120)->nullable();
            $table->string('description', 500)->nullable();

            /*
             * Paket fiyatı — menünün BÜTÜN olarak fiyatı, kuruş.
             *
             * `null` = o gün paket satılmıyor, yalnız kalemler tek tek
             * alınabilir. Sıfır ile karıştırılmamalı: sıfır "bedava" demek
             * olurdu ve `LineResolver` onu reddediyor.
             */
            $table->unsignedBigInteger('package_price_kurus')->nullable();

            // false = yalnız paket satılır, kalemler tek tek alınamaz.
            $table->boolean('components_sellable')->default(true);

            /*
             * `draft` | `published`.
             *
             * NEDEN BOOLEAN DEĞİL: `menus.menu_status` bu dersi bir kez verdi
             * (docs/02 §"Mutfak turu tabloları"). Boolean üçüncü bir duruma
             * büyüyemez. Ayrıca yönetici bir ay öncesinden plan giriyor;
             * taslak ayrımı olmasaydı yarım girilmiş bir perşembe,
             * kaydedildiği anda müşteriye görünürdü.
             */
            $table->string('status', 16)->default('draft')->index();
            $table->timestamp('published_at')->nullable();
            $table->unsignedBigInteger('published_by')->nullable();

            $table->string('image_path', 255)->nullable();

            // Panelde kalır, müşteriye GİTMEZ. `description` ile ayrı
            // tutuluyor ki hangisinin herkese açık olduğu akılda tutulacak
            // bir şey olmasın.
            $table->string('internal_note', 255)->nullable();

            $table->unsignedBigInteger('created_by')->nullable();
            $table->timestamps();

            $table->unique(['location_id', 'menu_date'], 'veykemtu_daily_menu_essiz');
            $table->index(['menu_date', 'status'], 'veykemtu_daily_menu_gun_durum');
        });

        Schema::create('veykemtu_daily_menu_items', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->unsignedBigInteger('daily_menu_id')->index();
            // Çekirdek `menus` tablosuna. Yabancı anahtar yok — çekirdek de
            // tüm kısıtları düşürdü (`drop_foreign_key_constraints_on_all_tables`).
            $table->unsignedBigInteger('menu_id')->index();

            // Bir PAKETTE bu kalemden kaç porsiyon var.
            $table->unsignedInteger('quantity')->default(1);

            // Çorba → ana yemek → pilav → tatlı.
            $table->unsignedInteger('sort_order')->default(0);

            /*
             * O güne özel birim fiyat, kuruş. `null` = ürünün kendi fiyatı.
             *
             * YALNIZ TEK TEK SATIŞTA geçerli; paket fiyatını etkilemez.
             * Paket fiyatı bütünün fiyatıdır ve kalemlerin toplamından
             * türetilmez.
             */
            $table->unsignedBigInteger('price_override_kurus')->nullable();

            // Paketin zorunlu parçası mı? Zorunlu bir kalem bugün tükendiyse
            // paket de düşer (docs/02 §8.5).
            $table->boolean('is_required')->default(true);

            // Ekmek, ayran gibi kalemler yalnız pakette olabilir.
            $table->boolean('sellable_alone')->default(true);

            // "Günün Çorbası: Mercimek" — boşsa ürünün kendi adı kullanılır.
            $table->string('label', 120)->nullable();

            $table->unique(['daily_menu_id', 'menu_id'], 'veykemtu_daily_menu_item_essiz');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('veykemtu_daily_menu_items');
        Schema::dropIfExists('veykemtu_daily_menus');
    }
};
