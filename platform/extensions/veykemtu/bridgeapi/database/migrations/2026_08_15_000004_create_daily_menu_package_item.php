<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;

/**
 * BİLEREK BOŞ — "Günün Menüsü" paket ürünü göçte YARATILMIYOR.
 *
 * İlk sürümde bu göç ürünü ve `location_options` kaydını kendisi yazıyordu.
 * Çalışmadı ve sebebi öğreticiydi: göç `migrate:fresh` sırasında, vitrin
 * kaydı daha AÇILMADAN önce koşuyor. `Location::pluck('location_id')` boş
 * dönüyor, hiçbir vitrine bağlanmıyor ve ayar anahtarı hiç yazılmıyordu.
 * Testlerde tablolar oluşuyor ama ürün ortada olmuyordu.
 *
 * Ders: GÖÇ ŞEMA KURAR, VERİ TOHUMLAMAZ. Verinin sırası vardır ve göçlerin
 * sırası o sırayı bilmez.
 *
 * Ürün artık `php artisan veykemtu:setup` içinde açılıyor
 * (`SetupCommand::seedDailyMenuPackage`): vitrin orada zaten var, komut
 * idempotent ve tekrar koşulabilir.
 *
 * Dosya SİLİNMİYOR: göç adı `migrations` tablosuna yazıldığı ortamlar var
 * ve kaydı olan bir göçün dosyasını kaldırmak, `igniter:down` çalıştıran
 * kurulumda "class not found" verir.
 */
return new class extends Migration
{
    public function up(): void {}

    public function down(): void {}
};
