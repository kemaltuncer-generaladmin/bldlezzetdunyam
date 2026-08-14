<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * K-21: kasa kilit politikası — Kontrol Merkezi'nin kapatabildiği eylemler.
 *
 * NEDEN: bugün kasadaki her düğme herkese açık. Ayarlar ekranı, sunucu
 * adresi, tam ekrandan çıkma, sipariş düzenleme, elle yeniden basma ve
 * satış şalteri — hepsi mutfaktaki dokunmatik ekranın önünden geçen
 * herkesin erişebildiği yerde duruyor. Satış şalteri ciroyu kapatıyor,
 * sunucu adresi ise kasayı tamamen kör edebiliyor.
 *
 * HEPSİ NULLABLE VE VARSAYILANI `null` — BU GÖÇÜN EN ÖNEMLİ KARARI.
 * `null` "yönetici dokunmadı" demektir ve kasanın BUGÜNKÜ davranışı
 * geçerli kalır, yani SERBEST. Sütunlara `false` varsayılanı konsaydı göç
 * koştuğu saniyede sahadaki bütün kasalar kilitlenir, mutfak ayar
 * ekranına giremez ve kimse sebebini anlamazdı; üstelik kilidi açacak
 * arayüz (Kontrol Merkezi) henüz devrede bile olmayabilirdi. `true`
 * varsayılanı da yanlış olurdu: o zaman "yönetici açıkça izin verdi" ile
 * "kimse dokunmadı" ayırt edilemez, ileride varsayılanı sıkılaştırmak
 * imkânsız hâle gelirdi.
 *
 * KİLİT ANCAK YÖNETİCİ AÇIKÇA `false` YAZINCA DOĞAR. Aynı desen mevcut 16
 * yönetilen ayarda da geçerli (`2026_08_05_000003`, `2026_08_11_000001`)
 * ve kasa tarafı bunu zaten biliyor.
 *
 * `lock_message` NEDEN AYRI BİR ALAN: kilitli bir düğmeye basınca kasa
 * bir şey söylemek zorunda. Metin kasaya gömülseydi ("Bu işlem yönetici
 * tarafından kapatılmıştır") mutfak kime başvuracağını bilemezdi;
 * yöneticinin "Kapatıldı — Ahmet Bey'i arayın, 0532..." yazabilmesi
 * gerekiyor. 160 karakter: kasa bunu tek satırlık bir uyarı şeridinde
 * gösteriyor, paragraf değil.
 *
 * Kilitlerin kasa tarafındaki karşılığı `docs/05-mutfakapp.md` §8; düğme
 * GİZLENMEZ, pasifleşir — gizlenen düğme personeli "bozuldu" sanısına
 * iter ve destek çağrısı üretir.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('veykemtu_kitchen_devices', function (Blueprint $table): void {
            // Kasadaki ayarlar ekranının tamamı.
            $table->boolean('allow_settings')->nullable()->after('touch_mode');

            // Sunucu adresi değişimi + eşlemeyi sıfırlama. En yıkıcı olanı:
            // yanlış adres yazılan kasa hiçbir sipariş göremez ve geri
            // dönüş yolu yine aynı ekrandan geçer.
            $table->boolean('allow_server_change')->nullable()->after('allow_settings');

            // Tam ekrandan çıkma / küçültme. Kiosk kipinin tek kaçış kapısı.
            $table->boolean('allow_window_controls')->nullable()->after('allow_server_change');

            // Kasadan sipariş düzenleme (K-12 revizyonu). Para hareketi
            // üretiyor: iade ve ek tahsilat buradan doğuyor.
            $table->boolean('allow_order_edit')->nullable()->after('allow_window_controls');

            // Karttan ya da ayarlardan elle yeniden basma.
            $table->boolean('allow_manual_reprint')->nullable()->after('allow_order_edit');

            // Satış şalteri + "bugün tükendi" işaretleri (K-11). Ciroyu
            // kapatan tuş.
            $table->boolean('allow_sales_control')->nullable()->after('allow_manual_reprint');

            // Kilitli eyleme basınca kasada gösterilecek metin.
            $table->string('lock_message', 160)->nullable()->after('allow_sales_control');
        });
    }

    public function down(): void
    {
        Schema::table('veykemtu_kitchen_devices', function (Blueprint $table): void {
            $table->dropColumn([
                'allow_settings',
                'allow_server_change',
                'allow_window_controls',
                'allow_order_edit',
                'allow_manual_reprint',
                'allow_sales_control',
                'lock_message',
            ]);
        });
    }
};
