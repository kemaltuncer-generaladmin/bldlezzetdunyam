<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Console;

use Illuminate\Console\Command;
use Veykemtu\BridgeApi\Models\SiteContent;
use Veykemtu\BridgeApi\Models\SitePost;
use Veykemtu\BridgeApi\Models\SiteService;
use Veykemtu\BridgeApi\Services\SiteContentRepository;

/**
 * Kurumsal sitenin mevcut içeriğini veritabanına aktarır.
 *
 * ## Neden bu komut var?
 *
 * Site metinleri bugün `website/content/*.ts` dosyalarında duruyor: değiştirmek
 * için geliştirici, derleme ve dağıtım gerekiyor. İçerik tablolarına geçtik ama
 * tablolar boş; yönetici panele girdiğinde sitedeki yazıları değil BOŞ EKRAN
 * görürdü. Sıfırdan yazmasını beklemek, hem yapılmış işi çöpe atmak hem de
 * paneli "doldurulması gereken bir form" hâline getirmek olurdu.
 *
 * Bu komut mevcut içeriği olduğu gibi taşır: yönetici düzenlemeye baştan değil,
 * yayındaki metnin üzerinden başlar.
 *
 * ## Neden varsayılan davranış "ATLA"?
 *
 * Komut idempotent olmak zorunda (dağıtım betiği her sürümde çağırabilir), ama
 * idempotentliğin iki farklı okuması var:
 *
 * - **Her koşuda kaynağa eşitle:** yöneticinin panelde düzelttiği her cümleyi
 *   bir sonraki dağıtımda sessizce geri alır. Sebebi görünmeyen, güveni
 *   yıkan bir veri kaybı.
 * - **Mevcut kaydı atla, yalnızca eksiği ekle:** varsayılan davranışımız. Panel
 *   içeriğin tek kaynağıdır; komut yalnızca ilk doldurma ve sonradan eklenen
 *   kayıtlar için çalışır.
 *
 * Kaynak dosyalar bilinçli olarak güncellendiyse `--force` ile üzerine yazılır;
 * bu, sonucunu bilerek verilen bir karar olmalı.
 *
 * ## Uydurulmuş veri yok
 *
 * `contact` alanları `null`, `certifications` boş aktarılır — gerekçe
 * `SiteContentSeed` başlığında.
 */
class SiteContentImportCommand extends Command
{
    protected $signature = 'veykemtu:siteIceriginiAktar {--force : Mevcut kayıtların üzerine yaz (panel düzenlemeleri kaybolur)}';

    protected $description = 'Kurumsal site içeriğini (marka, kurumsal, sektör, menü, kalite, hizmet, yazı) veritabanına aktarır.';

    public function handle(): int
    {
        $force = (bool) $this->option('force');

        if ($force) {
            $this->components->warn(
                '--force verildi: mevcut kayıtların üzerine yazılacak. '.
                'Panelde yapılmış düzenlemeler kaybolur.',
            );
        }

        $written = 0;
        $skipped = 0;

        $this->importContent($force, $written, $skipped);
        $this->importServices($force, $written, $skipped);
        $this->importPosts($force, $written, $skipped);

        // Paket 60 dakika önbellekte duruyor; temizlemezsek yönetici siteyi
        // yenilediğinde hâlâ boş içerik görür ve komutun çalışmadığını sanır.
        app(SiteContentRepository::class)->forget();

        $this->newLine();
        $this->components->info("Aktarım tamam: {$written} kayıt yazıldı, {$skipped} kayıt atlandı.");

        if ($skipped > 0 && ! $force) {
            $this->components->twoColumnDetail(
                '  atlananlar',
                'Zaten var; panel düzenlemesi ezilmesin diye dokunulmadı. Üzerine yazmak için --force.',
            );
        }

        return self::SUCCESS;
    }

    private function importContent(bool $force, int &$written, int &$skipped): void
    {
        $this->components->info('İçerik anahtarları yazılıyor...');

        foreach (SiteContentSeed::content() as $key => $value) {
            if ($this->exists(SiteContent::query()->whereKey($key)->exists(), $force)) {
                $skipped++;
                $this->components->twoColumnDetail("  {$key}", '<fg=gray>atlandı</>');

                continue;
            }

            SiteContent::query()->updateOrCreate(['key' => $key], ['value' => $value]);
            $written++;

            $this->components->twoColumnDetail("  {$key}", count($value).' alan');
        }
    }

    private function importServices(bool $force, int &$written, int &$skipped): void
    {
        $this->components->info('Hizmetler yazılıyor...');

        foreach (SiteContentSeed::services() as $index => $service) {
            $slug = (string) $service['slug'];

            if ($this->exists(SiteService::query()->where('slug', $slug)->exists(), $force)) {
                $skipped++;
                $this->components->twoColumnDetail("  {$slug}", '<fg=gray>atlandı</>');

                continue;
            }

            // `sort_order` dizideki sıradan üretiliyor: kaynak listede yeri
            // değişen bir hizmetin numarasını elle güncellemek gerekmesin.
            $service['sort_order'] = $index;
            $service['is_published'] = true;

            /*
             * Serbest anlatım alanı (`body_html`) BOŞ bırakılıyor. Kaynak
             * dosyada karşılığı yok ve yapılandırılmış alanlardan (özet, giriş,
             * madde listeleri) HTML üretmek aynı metni sayfada iki kez
             * göstermek olurdu. Yönetici isterse panelden doldurur.
             */
            $service['body_html'] = null;

            $model = SiteService::query()->firstOrNew(['slug' => $slug]);
            $model->fill($service);
            $model->save();
            $written++;

            $this->components->twoColumnDetail("  {$slug}", $service['title']);
        }
    }

    private function importPosts(bool $force, int &$written, int &$skipped): void
    {
        $this->components->info('Bilgi merkezi yazıları yazılıyor...');

        foreach (SiteContentSeed::posts() as $post) {
            $slug = (string) $post['slug'];

            if ($this->exists(SitePost::query()->where('slug', $slug)->exists(), $force)) {
                $skipped++;
                $this->components->twoColumnDetail("  {$slug}", '<fg=gray>atlandı</>');

                continue;
            }

            /** @var list<array<string, mixed>> $blocks */
            $blocks = $post['body'];
            unset($post['body']);

            $post['body_html'] = $this->blocksToHtml($blocks);
            $post['is_published'] = true;

            $model = SitePost::query()->firstOrNew(['slug' => $slug]);
            $model->fill($post);
            $model->save();
            $written++;

            $this->components->twoColumnDetail("  {$slug}", $post['title']);
        }
    }

    /** Kayıt var ve üzerine yazma izni yoksa atlanmalı. */
    private function exists(bool $found, bool $force): bool
    {
        return $found && ! $force;
    }

    /**
     * Tipli blokları HTML'e çevirir.
     *
     * Üretilen etiketler `HtmlSanitizer` izin listesinin İÇİNDEDİR — `<div>`,
     * `<img>` veya `style` yok. Aksi hâlde model kaydederken temizler ve
     * biçimlendirme sessizce düşerdi.
     *
     * `callout` için `<blockquote>` seçildi: izin listesindeki tek "vurgulu
     * blok" etiketi o ve anlamı da (alıntılanmış/öne çıkarılmış not) uyuyor.
     *
     * Metin `htmlspecialchars` ile kaçırılıyor. İçerikte `<` veya `&` geçen bir
     * cümle (örn. "çorba + ana yemek") aksi hâlde etiket parçası sanılıp
     * ayrıştırıcıyı yanıltabilirdi.
     *
     * @param  list<array<string, mixed>>  $blocks
     */
    private function blocksToHtml(array $blocks): string
    {
        $html = '';

        foreach ($blocks as $block) {
            $html .= match ($block['kind']) {
                'paragraph' => '<p>'.$this->escape($block['text']).'</p>',
                // Yazı başlığı sayfada `<h1>`; gövde başlıkları bu yüzden `<h2>`
                // ile başlar, hiyerarşi atlanmaz.
                'heading' => '<h2>'.$this->escape($block['text']).'</h2>',
                'callout' => '<blockquote><p>'.$this->escape($block['text']).'</p></blockquote>',
                'list' => $this->listToHtml($block['items']),
                default => '',
            };
        }

        return $html;
    }

    /** @param  list<string>  $items */
    private function listToHtml(array $items): string
    {
        $rows = array_map(
            fn (string $item): string => '<li>'.$this->escape($item).'</li>',
            $items,
        );

        return '<ul>'.implode('', $rows).'</ul>';
    }

    private function escape(string $text): string
    {
        return htmlspecialchars($text, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    }
}
