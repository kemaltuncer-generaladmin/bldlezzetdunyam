<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Console;

use Igniter\Cart\Models\Category;
use Igniter\Cart\Models\Menu;
use Igniter\Local\Models\Location;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Support\Money;

/**
 * Geliştirme menüsü — `infra/mock/src/seed.js` ile **aynı** veri.
 *
 * NEDEN AYNI VERİ: `E-01` entegrasyon gününde istemciler mock'tan gerçek
 * backend'e geçecek. Veri kümesi farklıysa, o gün bulunan her hata için
 * "sözleşme mi bozuk, yoksa veri mi farklı" sorusuyla vakit kaybedilir.
 * Aynı 3 kategori, aynı 12 ürün, aynı fiyatlar, aynı tükenmiş ürün.
 *
 * İdempotenttir. Üretimde çalıştırılmaz — gerçek menü admin panelden girilir.
 */
class DemoMenuCommand extends Command
{
    protected $signature = 'veykemtu:demo-menu {--fresh : Önce mevcut demo ürünleri sil}';

    protected $description = 'Mock ile aynı geliştirme menüsünü yükler (3 kategori, 12 ürün).';

    /** Fiyatlar kuruş cinsindendir — mock ile birebir. */
    private const array CATEGORIES = [
        ['name' => 'Ana Yemekler', 'priority' => 1, 'items' => [
            ['name' => 'Tavuk Sote', 'desc' => 'Pilav ile servis edilir', 'price' => 18500, 'available' => true],
            ['name' => 'Etli Kuru Fasulye', 'desc' => 'Pirinç pilavı ve turşu ile', 'price' => 19500, 'available' => true],
            ['name' => 'Fırın Tavuk But', 'desc' => 'Sebzeli, fırında', 'price' => 21000, 'available' => true],
            ['name' => 'Karnıyarık', 'desc' => 'Kıymalı patlıcan, pilav ile', 'price' => 20000, 'available' => true],
            // Bilinçli olarak tükenmiş: istemciler soluk gösterimi ve
            // ITEM_UNAVAILABLE hatasını gerçek backend'de de deneyebilsin.
            ['name' => 'Izgara Köfte', 'desc' => 'Közlenmiş biber ve pilav ile', 'price' => 24500, 'available' => false],
        ]],
        ['name' => 'Çorbalar ve Salatalar', 'priority' => 2, 'items' => [
            ['name' => 'Mercimek Çorbası', 'desc' => 'Limon ve kruton ile', 'price' => 8500, 'available' => true],
            ['name' => 'Ezogelin Çorbası', 'desc' => 'Naneli tereyağı ile', 'price' => 8500, 'available' => true],
            ['name' => 'Mevsim Salata', 'desc' => 'Zeytinyağlı, mevsim yeşillikleri', 'price' => 9500, 'available' => true],
            ['name' => 'Çoban Salata', 'desc' => 'Domates, salatalık, biber', 'price' => 8000, 'available' => true],
        ]],
        ['name' => 'Tatlılar ve İçecekler', 'priority' => 3, 'items' => [
            ['name' => 'Sütlaç', 'desc' => 'Fırında, tarçınlı', 'price' => 7500, 'available' => true],
            ['name' => 'Kemalpaşa Tatlısı', 'desc' => 'Şerbetli, kaymak ile', 'price' => 9000, 'available' => true],
            ['name' => 'Ayran', 'desc' => '300 ml', 'price' => 3000, 'available' => true],
        ]],
    ];

    public function handle(): int
    {
        $location = Location::where('permalink_slug', 'catering')->first();

        if ($location === null) {
            $this->components->error('Vitrin yok. Önce `php artisan veykemtu:setup` çalıştırın.');

            return self::FAILURE;
        }

        if ($this->option('fresh')) {
            $this->purge();
        }

        $categoryCount = 0;
        $itemCount = 0;

        foreach (self::CATEGORIES as $definition) {
            $category = Category::firstOrNew(['name' => $definition['name']]);
            $category->name = $definition['name'];
            $category->priority = $definition['priority'];
            $category->status = true;
            $category->save();
            $categoryCount++;

            foreach ($definition['items'] as $index => $item) {
                $menu = Menu::firstOrNew(['menu_name' => $item['name']]);
                $menu->menu_name = $item['name'];
                $menu->menu_description = $item['desc'];
                $menu->menu_price = Money::toDecimal($item['price']);
                $menu->menu_status = $item['available'];
                $menu->minimum_qty = 1;
                $menu->menu_priority = $index;
                $menu->save();
                $itemCount++;

                // Kategori bağı (many-to-many).
                DB::table('menu_categories')->updateOrInsert([
                    'menu_id' => $menu->menu_id,
                    'category_id' => $category->category_id,
                ]);

                // Ürünü vitrine bağla; bağlanmayan ürün menüde görünmez.
                DB::table('locationables')->updateOrInsert([
                    'location_id' => $location->location_id,
                    'locationable_id' => $menu->menu_id,
                    'locationable_type' => 'menus',
                ], ['options' => null]);
            }

            DB::table('locationables')->updateOrInsert([
                'location_id' => $location->location_id,
                'locationable_id' => $category->category_id,
                'locationable_type' => 'categories',
            ], ['options' => null]);
        }

        $this->components->info("{$categoryCount} kategori, {$itemCount} ürün yüklendi.");
        $this->components->warn('Bu komut GELİŞTİRME içindir. Üretimde menü admin panelden girilir.');

        return self::SUCCESS;
    }

    private function purge(): void
    {
        $names = [];
        foreach (self::CATEGORIES as $definition) {
            foreach ($definition['items'] as $item) {
                $names[] = $item['name'];
            }
        }

        $ids = Menu::whereIn('menu_name', $names)->pluck('menu_id');
        DB::table('menu_categories')->whereIn('menu_id', $ids)->delete();
        DB::table('locationables')->whereIn('locationable_id', $ids)
            ->where('locationable_type', 'menus')->delete();
        Menu::whereIn('menu_id', $ids)->delete();

        $this->components->warn($ids->count().' demo ürün silindi.');
    }
}
