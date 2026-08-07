<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Console;

use Igniter\Cart\Models\Menu;
use Illuminate\Console\Command;

/**
 * Menü ürünlerine görsel bağlar.
 *
 * ## Neden komut, neden elle yükleme değil?
 *
 * Görselsiz menü, sipariş ekranında on iki gri kutu demek. Yönetici panelden
 * tek tek yükleyebilir ama sıfırdan kurulan her ortam (geliştirme, staging,
 * yeniden kurulan sunucu) yine boş başlar. Komut bu ilk dolguyu tekrarlanabilir
 * kılar; sonrasında görseli değiştirmek panelin işidir.
 *
 * ## Varsayılan davranış: ATLA
 *
 * Zaten görseli olan ürüne dokunulmaz — yöneticinin yüklediği gerçek fotoğrafı
 * bir sonraki dağıtımda stok görselle ezmek, `SiteContentImportCommand` ile
 * aynı gerekçeyle yanlış olurdu. Bilerek geri dönmek için `--force`.
 *
 * ## Bu fotoğraflar BLD'ye ait DEĞİLDİR
 *
 * `resources/gorseller/menu/` altındaki dosyalar Unsplash lisanslı stok
 * fotoğraflardır ve yalnızca yemeğin ne olduğunu göstermek için duruyor;
 * "bizim mutfağımızda çekildi" iddiası taşımazlar. Firma kendi fotoğraflarını
 * çektiğinde panelden değiştirir. Eşleşmenin yanıltıcı olmaması için her dosya
 * gerçekten o yemeğin fotoğrafıdır — benzeri değil.
 */
class MenuImageCommand extends Command
{
    protected $signature = 'veykemtu:menuGorselleri {--force : Görseli olan ürünlerin görselini de değiştir}';

    protected $description = 'Menü ürünlerine başlangıç görsellerini bağlar.';

    /** Ürün adı → `resources/gorseller/menu/` altındaki dosya adı. */
    private const array IMAGES = [
        'Tavuk Sote' => 'tavuk-sote.jpg',
        'Etli Kuru Fasulye' => 'etli-kuru-fasulye.jpg',
        'Fırın Tavuk But' => 'firin-tavuk-but.jpg',
        'Karnıyarık' => 'karniyarik.jpg',
        'Izgara Köfte' => 'izgara-kofte.jpg',
        'Mercimek Çorbası' => 'mercimek-corbasi.jpg',
        'Ezogelin Çorbası' => 'ezogelin-corbasi.jpg',
        'Mevsim Salata' => 'mevsim-salata.jpg',
        'Çoban Salata' => 'coban-salata.jpg',
        'Sütlaç' => 'sutlac.jpg',
        'Kemalpaşa Tatlısı' => 'kemalpasa-tatlisi.jpg',
        'Ayran' => 'ayran.jpg',
    ];

    public function handle(): int
    {
        $force = (bool) $this->option('force');
        $directory = dirname(__DIR__, 2).'/resources/gorseller/menu';

        $attached = 0;
        $skipped = 0;
        $missing = 0;

        foreach (self::IMAGES as $menuName => $fileName) {
            $menu = Menu::where('menu_name', $menuName)->first();

            if ($menu === null) {
                $this->components->twoColumnDetail("  {$menuName}", '<fg=yellow>ürün yok</>');
                $missing++;

                continue;
            }

            if ($menu->hasMedia('thumb') && ! $force) {
                $skipped++;

                continue;
            }

            $path = "{$directory}/{$fileName}";

            if (! is_file($path)) {
                $this->components->twoColumnDetail("  {$menuName}", "<fg=red>dosya yok: {$fileName}</>");
                $missing++;

                continue;
            }

            // Eski görsel önce temizlenir: `thumb` tek görsellik bir etiket,
            // ikinci dosya eklendiğinde hangisinin döneceği sıralamaya kalırdı.
            $menu->clearMediaTag('thumb');
            $menu->newMediaInstance()->addFromFile($path, 'thumb');

            $this->components->twoColumnDetail("  {$menuName}", '<fg=green>görsel bağlandı</>');
            $attached++;
        }

        $this->newLine();
        $this->components->info("{$attached} ürüne görsel bağlandı, {$skipped} ürün atlandı.");

        if ($skipped > 0 && ! $force) {
            $this->components->twoColumnDetail(
                '  atlananlar',
                'Görseli zaten var; panelden yüklenmiş fotoğraf ezilmesin diye dokunulmadı. Değiştirmek için --force.',
            );
        }

        return $missing > 0 ? self::FAILURE : self::SUCCESS;
    }
}
