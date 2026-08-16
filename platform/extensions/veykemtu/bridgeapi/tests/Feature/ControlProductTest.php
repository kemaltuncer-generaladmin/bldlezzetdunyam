<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Category;
use Igniter\Cart\Models\Menu;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Testing\TestResponse;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Models\ControlAudit;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Services\ProductImageService;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Kontrol Merkezi — ürün kataloğu (`/api/control/products`).
 *
 * ÜÇ AYRI SORU TEST EDİLİYOR:
 *
 * 1. **Katalog doğru mu?** Süzgeçler, sayfalama, `status` varsayılanının
 *    `all` olması. Varsayılan `active` olsaydı satıştan kaldırılmış ürün
 *    yönetici için "kaybolmuş" görünürdü ve bu, sözleşmenin açıkça
 *    gerekçelendirdiği bir karar.
 *
 * 2. **Yıkıcı işlemler gerçekten yumuşak mı?** Ürün silinmiyor
 *    (`menu_status = 0`), yayındaki bir menünün kalemi kaldırılamıyor,
 *    tükendi işareti yalnız bugüne yazılıyor.
 *
 * 3. **Görsel yükleme kapısı sağlam mı?** Bozuk base64, 5 MB üstü içerik,
 *    görsel olmayan içerik — üçü de KENDİ hatasını vermeli. Uzantıya
 *    güvenmeyip mime'ı içerikten okuduğumuz da burada sabitleniyor;
 *    `.jpg` adlı bir PHP dosyası yüklemenin en bilinen yolu odur.
 *
 * Sır ortamdan okunuyor, test için sabitleniyor (`ControlKdsTest` deseni).
 */
class ControlProductTest extends KitchenTestCase
{
    private const string SECRET = 'test-kontrol-merkezi-sirri';

    private const string ACTOR = 'Ayşe Yönetici';

    private const string REASON = 'Sahada denetim için yapıldı';

    /** 1×1 kırmızı PNG — 69 bayt, geçerli sihirli baytlarla. */
    private const string PNG_BASE64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mP4z8AAAAMBAQD3A0FDAAAAAElFTkSuQmCC';

    protected function setUp(): void
    {
        parent::setUp();

        putenv('BLD_CONTROL_SECRET='.self::SECRET);
        $_ENV['BLD_CONTROL_SECRET'] = self::SECRET;

        /*
         * MEDYA DİSKİ SAHTELENİYOR. Veritabanı her testte işlemle geri
         * alınıyor ama DİSK ALINMIYOR: gerçek diske yazan bir test, yüklenen
         * görselleri ve üretilen küçük resimleri `storage/app/public` altında
         * biriktirir ve bir sonraki koşuma kirli bir dizinle girer. Disk adı
         * çekirdeğin ayarından okunuyor, elle yazılmıyor.
         */
        Storage::fake((string) config('igniter-system.assets.attachment.disk', 'public'));
    }

    // ── 1. Liste ve süzgeçler ─────────────────────────────────────────────

    public function test_liste_sayfalama_meta_dondurur(): void
    {
        $response = $this->signed('GET', '/api/control/products')->assertOk();

        $response->assertJsonPath('meta.page', 1)
            ->assertJsonPath('meta.per_page', 25);

        $this->assertGreaterThan(0, $response->json('meta.total'));
        $this->assertNotNull($response->json('server_time'));
    }

    public function test_IMZASIZ_istek_reddedilir(): void
    {
        $this->getJson('/api/control/products', ['Accept' => 'application/json'])
            ->assertStatus(401)
            ->assertJsonPath('error.code', 'UNAUTHENTICATED');
    }

    public function test_VARSAYILAN_SUZGEC_SATISTAN_KALDIRILMIS_URUNU_DE_GOSTERIR(): void
    {
        // Yönetimin ilk sorusu "bu ürün nerede" ve cevabı "satıştan
        // kaldırılmış". Varsayılan süzgeç onu gizleseydi ürün kaybolmuş
        // görünürdü — sözleşmenin `status: all` varsayılanının sebebi bu.
        $menu = $this->product('Tavuk Sote');
        $menu->menu_status = false;
        $menu->save();

        $ids = $this->menuIdsOf($this->signed('GET', '/api/control/products?per_page=100'));

        $this->assertContains((int) $menu->menu_id, $ids);
    }

    public function test_status_active_suzgeci_kaldirilmis_urunu_gizler(): void
    {
        $menu = $this->product('Tavuk Sote');
        $menu->menu_status = false;
        $menu->save();

        $ids = $this->menuIdsOf(
            $this->signed('GET', '/api/control/products?status=active&per_page=100'),
        );

        $this->assertNotContains((int) $menu->menu_id, $ids);
    }

    public function test_arama_ad_uzerinde_calisir(): void
    {
        $ids = $this->menuIdsOf(
            $this->signed('GET', '/api/control/products?q='.urlencode('Tavuk Sote')),
        );

        $this->assertContains($this->productId('Tavuk Sote'), $ids);
        $this->assertNotContains($this->productId('Ayran'), $ids);
    }

    public function test_kategori_suzgeci_calisir(): void
    {
        $categoryId = (int) DB::table('menu_categories')
            ->where('menu_id', $this->productId('Tavuk Sote'))
            ->value('category_id');

        $ids = $this->menuIdsOf($this->signed(
            'GET',
            '/api/control/products?category_id='.$categoryId.'&per_page=100',
        ));

        $this->assertContains($this->productId('Tavuk Sote'), $ids);
    }

    public function test_sold_out_suzgeci_yalniz_bugun_tukenenleri_verir(): void
    {
        $menuId = $this->productId('Ayran');

        $this->signed(
            'POST',
            '/api/control/products/'.$menuId.'/sold-out',
            $this->intent(),
        )->assertOk();

        $ids = $this->menuIdsOf(
            $this->signed('GET', '/api/control/products?sold_out=true&per_page=100'),
        );

        $this->assertSame([$menuId], $ids);
    }

    public function test_tek_urun_secenekleri_ve_kategori_kimliklerini_tasir(): void
    {
        $menuId = $this->productId('Tavuk Sote');

        $response = $this->signed('GET', '/api/control/products/'.$menuId)->assertOk();

        $response->assertJsonPath('data.menu_id', $menuId)
            ->assertJsonPath('data.name', 'Tavuk Sote')
            ->assertJsonPath('data.is_package_product', false);

        $this->assertIsArray($response->json('data.options'));
        $this->assertNotEmpty($response->json('data.category_ids'));
        // Para TELDE HER ZAMAN KURUŞ; ondalık TL hiçbir yerde gitmez.
        $this->assertIsInt($response->json('data.price_kurus'));
    }

    public function test_OLMAYAN_URUN_sozlesmedeki_404u_verir(): void
    {
        $this->signed('GET', '/api/control/products/999999')
            ->assertStatus(404)
            ->assertJsonPath('error.code', 'NOT_FOUND');
    }

    public function test_PAKET_URUNU_listede_isaretlenir(): void
    {
        // "Günün Menüsü" ürününün kendi fiyatı 0,00'dır ve gerçek fiyat o
        // günün paket fiyatıdır. Panel bu ürünün fiyat alanını düzenlemeye
        // kapatabilmek için işareti okumak zorunda.
        $packageId = $this->productId('Günün Menüsü');

        $this->signed('GET', '/api/control/products/'.$packageId)
            ->assertOk()
            ->assertJsonPath('data.is_package_product', true);
    }

    // ── 2. Yaratma ve güncelleme ──────────────────────────────────────────

    public function test_urun_yaratilir_ve_denetim_satiri_yeni_kimligi_tasir(): void
    {
        $categoryId = (int) Category::query()->value('category_id');

        $response = $this->signed('POST', '/api/control/products', $this->intent([
            'name' => 'Karnıyarık',
            'description' => 'Zeytinyağlı, kıymalı',
            'price_kurus' => 9500,
            'category_ids' => [$categoryId],
        ]))->assertStatus(201);

        $menuId = (int) $response->json('data.menu_id');

        $response->assertJsonPath('ok', true)
            ->assertJsonPath('dry_run', false)
            ->assertJsonPath('data.price_kurus', 9500)
            ->assertJsonPath('data.status', true)
            ->assertJsonPath('data.category_ids', [$categoryId]);

        $audit = ControlAudit::firstOrFail();

        $this->assertSame('product.create', $audit->action);
        $this->assertSame('menu', $audit->target_type);
        // Denetim satırı işlemden ÖNCE açılıyor ve kimlik o an yok; satır
        // yazma uygulandıktan sonra tamamlanmalı, yoksa iz "hangi ürün"
        // sorusunu cevaplamaz.
        $this->assertSame($menuId, (int) $audit->target_id);

        // Kuruş → TL dönüşümü tek geçitten geçmeli.
        $this->assertEqualsWithDelta(95.0, (float) Menu::findOrFail($menuId)->menu_price, 0.001);
    }

    public function test_KURU_PROVA_urun_yaratmaz_ama_denetim_yazar(): void
    {
        $before = Menu::count();

        $this->signed('POST', '/api/control/products', $this->intent([
            'name' => 'Karnıyarık',
            'price_kurus' => 9500,
            'dry_run' => true,
        ]))->assertOk()
            ->assertJsonPath('dry_run', true)
            ->assertJsonPath('would.action', 'product.create')
            ->assertJsonPath('would.name', 'Karnıyarık');

        $this->assertSame($before, Menu::count(), 'Kuru prova ürün yaratmamalı.');
        $this->assertSame(ControlAudit::RESULT_DRY_RUN, ControlAudit::firstOrFail()->result);
    }

    public function test_GEREKCESIZ_YAZMA_reddedilir_ve_iz_birakmaz(): void
    {
        $before = Menu::count();

        $this->signed('POST', '/api/control/products', [
            'actor' => self::ACTOR,
            'name' => 'Karnıyarık',
            'price_kurus' => 9500,
        ])->assertStatus(422)->assertJsonPath('error.code', 'VALIDATION_FAILED');

        $this->assertSame($before, Menu::count());
        // Geçerli bir istek hiç oluşmadı; denetim satırı da olmamalı.
        $this->assertSame(0, ControlAudit::count());
    }

    public function test_urun_guncellenir_ve_kategori_listesi_tam_liste_olarak_esitlenir(): void
    {
        $menuId = $this->productId('Tavuk Sote');
        $hedef = (int) Category::query()->orderByDesc('category_id')->value('category_id');

        $this->signed('PATCH', '/api/control/products/'.$menuId, $this->intent([
            'price_kurus' => 10000,
            'category_ids' => [$hedef],
        ]))->assertOk()
            ->assertJsonPath('data.price_kurus', 10000)
            ->assertJsonPath('data.category_ids', [$hedef]);

        // Fark değil TAM LİSTE: eski bağ kalmamalı.
        $this->assertSame(
            [$hedef],
            DB::table('menu_categories')->where('menu_id', $menuId)
                ->pluck('category_id')->map(intval(...))->all(),
        );
    }

    public function test_PAKET_URUNUNE_FIYAT_YAZILAMAZ(): void
    {
        $packageId = $this->productId('Günün Menüsü');

        $this->signed('PATCH', '/api/control/products/'.$packageId, $this->intent([
            'price_kurus' => 12000,
        ]))->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED')
            ->assertJsonPath('error.details.field', 'price_kurus')
            ->assertJsonPath('error.details.reason', 'package_product');

        $this->assertEqualsWithDelta(
            0.0,
            (float) Menu::findOrFail($packageId)->menu_price,
            0.001,
        );
    }

    public function test_KURU_PROVA_DA_paket_urunu_denetimini_kosar(): void
    {
        // "Kuru prova geçti" diyen bir ekran gerçek gönderimde patlamamalı.
        $packageId = $this->productId('Günün Menüsü');

        $this->signed('PATCH', '/api/control/products/'.$packageId, $this->intent([
            'price_kurus' => 12000,
            'dry_run' => true,
        ]))->assertStatus(422);

        // Ön denetimin başarısızlığı bir YAZMA denemesi değildir; satır
        // `dry_run` kalmalı ki denetim ekranı ikisini karıştırmasın.
        $audit = ControlAudit::firstOrFail();
        $this->assertSame(ControlAudit::RESULT_DRY_RUN, $audit->result);
        $this->assertArrayHasKey('error', $audit->payload_json);
    }

    // ── 3. Yumuşak kaldırma ───────────────────────────────────────────────

    public function test_SILME_SATIRI_SILMEZ_yalniz_kapatir(): void
    {
        $menuId = $this->productId('Ayran');

        $this->signed('DELETE', '/api/control/products/'.$menuId, $this->intent())
            ->assertOk()
            ->assertJsonPath('data.soft_deleted', true)
            ->assertJsonPath('data.status', false);

        $fresh = Menu::find($menuId);

        // Gerçek silme, geçmiş siparişlerin ürün bağını kırar ve "bu sipariş
        // neydi" sorusunu cevapsız bırakırdı.
        $this->assertNotNull($fresh, 'Ürün satırı SİLİNMEMELİ.');
        $this->assertFalse((bool) $fresh->menu_status);
    }

    public function test_YAYINDAKI_MENUDE_KULLANILAN_URUN_kaldirilamaz(): void
    {
        $menuId = $this->productId('Ayran');
        $date = BusinessTime::today();

        $this->publishDailyMenu($menuId, $date);

        $this->signed('DELETE', '/api/control/products/'.$menuId, $this->intent())
            ->assertStatus(409)
            ->assertJsonPath('error.code', 'CONFLICT')
            ->assertJsonPath('error.details.conflict', 'daily_menu')
            ->assertJsonPath('error.details.dates', [$date]);

        $this->assertTrue((bool) Menu::findOrFail($menuId)->menu_status);
    }

    public function test_geri_acmak_status_true_yazmaktir(): void
    {
        $menuId = $this->productId('Ayran');

        $this->signed('DELETE', '/api/control/products/'.$menuId, $this->intent())->assertOk();

        $this->signed('PATCH', '/api/control/products/'.$menuId, $this->intent([
            'status' => true,
        ]))->assertOk()->assertJsonPath('data.status', true);

        $this->assertTrue((bool) Menu::findOrFail($menuId)->menu_status);
    }

    // ── 4. Görsel ─────────────────────────────────────────────────────────

    public function test_gorsel_yuklenir_ve_denetime_BASE64_YAZILMAZ(): void
    {
        $menuId = $this->productId('Tavuk Sote');

        $response = $this->signed(
            'PUT',
            '/api/control/products/'.$menuId.'/image',
            $this->intent(['filename' => 'tavuk-sote.jpg', 'content_base64' => self::PNG_BASE64]),
        )->assertOk();

        $response->assertJsonPath('data.mime', 'image/png')
            ->assertJsonPath('data.bytes', 69);

        $this->assertIsString($response->json('data.image_url'));
        $this->assertNotSame('', $response->json('data.image_url'));
        $this->assertTrue(Menu::findOrFail($menuId)->hasMedia(ProductImageService::MEDIA_TAG));

        // Denetim tablosunu megabaytlık dizelerle doldurmak, izi okunamaz
        // ve tabloyu yönetilemez kılardı.
        $payload = ControlAudit::firstOrFail()->payload_json;

        $this->assertSame('image/png', $payload['mime']);
        $this->assertSame(69, $payload['bytes']);
        $this->assertArrayNotHasKey('content_base64', $payload);
    }

    public function test_KURU_PROVA_gorseli_denetler_ama_diske_yazmaz(): void
    {
        $menuId = $this->productId('Tavuk Sote');

        $this->signed(
            'PUT',
            '/api/control/products/'.$menuId.'/image',
            $this->intent([
                'filename' => 'tavuk-sote.jpg',
                'content_base64' => self::PNG_BASE64,
                'dry_run' => true,
            ]),
        )->assertOk()
            ->assertJsonPath('would.valid', true)
            ->assertJsonPath('would.mime', 'image/png')
            ->assertJsonPath('would.bytes', 69);

        $this->assertFalse(Menu::findOrFail($menuId)->hasMedia(ProductImageService::MEDIA_TAG));
    }

    public function test_BOZUK_BASE64_kendi_hatasini_verir(): void
    {
        $this->signed(
            'PUT',
            '/api/control/products/'.$this->productId('Tavuk Sote').'/image',
            $this->intent(['filename' => 'x.jpg', 'content_base64' => 'bu-base64-degil-!!!']),
        )->assertStatus(422)
            ->assertJsonPath('error.details.field', 'content_base64')
            ->assertJsonPath('error.details.reason', 'invalid_base64');
    }

    public function test_BES_MB_USTU_gorsel_reddedilir(): void
    {
        // Sınır ÇÖZÜLMÜŞ bayt üzerinden; base64 ~%33 şişirdiği için gövde
        // daha büyüktür ve bu bilinçli.
        $tooLarge = base64_encode(str_repeat('A', ProductImageService::MAX_BYTES + 1));

        $this->signed(
            'PUT',
            '/api/control/products/'.$this->productId('Tavuk Sote').'/image',
            $this->intent(['filename' => 'x.jpg', 'content_base64' => $tooLarge]),
        )->assertStatus(422)
            ->assertJsonPath('error.details.reason', 'too_large')
            ->assertJsonPath('error.details.max_bytes', ProductImageService::MAX_BYTES);
    }

    public function test_MIME_UZANTIDAN_DEGIL_ICERIKTEN_okunur(): void
    {
        // `.jpg` adlı görsel olmayan bir dosya, uzantıya güvenen her
        // sistemde kabul edilir. Kabul edilmemeli.
        $response = $this->signed(
            'PUT',
            '/api/control/products/'.$this->productId('Tavuk Sote').'/image',
            $this->intent([
                'filename' => 'zararsiz.jpg',
                'content_base64' => base64_encode("Bu bir görsel değil, düz metin.\n"),
            ]),
        )->assertStatus(422);

        $response->assertJsonPath('error.details.reason', 'invalid_mime');
        $this->assertIsString($response->json('error.details.mime'));
        $this->assertNotSame('image/jpeg', $response->json('error.details.mime'));
    }

    public function test_GORSELI_OLMAYAN_URUNDEN_gorsel_silmek_hata_degildir(): void
    {
        // İşlem sonuç odaklıdır: istenen son hâl zaten geçerli.
        $menuId = $this->productId('Ayran');

        $this->signed('DELETE', '/api/control/products/'.$menuId.'/image', $this->intent())
            ->assertOk()
            ->assertJsonPath('ok', true)
            ->assertJsonPath('data.image_url', null);
    }

    public function test_gorsel_silinir(): void
    {
        $menuId = $this->productId('Tavuk Sote');

        $this->signed(
            'PUT',
            '/api/control/products/'.$menuId.'/image',
            $this->intent(['filename' => 'tavuk.png', 'content_base64' => self::PNG_BASE64]),
        )->assertOk();

        $this->signed('DELETE', '/api/control/products/'.$menuId.'/image', $this->intent())
            ->assertOk()
            ->assertJsonPath('data.image_url', null);

        $this->assertFalse(Menu::findOrFail($menuId)->hasMedia(ProductImageService::MEDIA_TAG));
    }

    // ── 5. Kategoriler ────────────────────────────────────────────────────

    public function test_kategori_listesi_sayfalanmaz_ve_urun_sayisi_tasir(): void
    {
        $response = $this->signed('GET', '/api/control/products/categories')->assertOk();

        // Sayfalanmayan uçlar `page`/`per_page`/`total`/`last_page`
        // dörtlüsünü DÖNDÜRMEZ; boş bir sayfalayıcı çizdirmek yanlış olurdu.
        $this->assertNull($response->json('meta.page'));

        $tavukKategorisi = (int) DB::table('menu_categories')
            ->where('menu_id', $this->productId('Tavuk Sote'))
            ->value('category_id');

        $row = collect($response->json('data'))
            ->firstWhere('category_id', $tavukKategorisi);

        $this->assertNotNull($row, 'Ürünü olan kategori listede bulunmalı.');
        $this->assertArrayHasKey('slug', $row);
        $this->assertGreaterThan(0, $row['menu_count']);
    }

    public function test_kategori_yaratilir_ve_slug_addan_uretilir(): void
    {
        $response = $this->signed('POST', '/api/control/products/categories', $this->intent([
            'name' => 'Tatlı',
            'priority' => 40,
        ]))->assertStatus(201);

        $categoryId = (int) $response->json('data.category_id');

        // Elle slug yazdırmak, sitedeki adresin yönetici yazım hatasına
        // bağlı olması demekti.
        $this->assertNotNull(Category::findOrFail($categoryId)->permalink_slug);
        $this->assertSame(0, $response->json('data.menu_count'));
        $this->assertSame('category', ControlAudit::firstOrFail()->target_type);
    }

    public function test_KATEGORI_KENDI_ALT_DALINA_TASINAMAZ(): void
    {
        $parent = $this->makeCategory('Ana Dal');
        $child = $this->makeCategory('Alt Dal', (int) $parent->category_id);

        // Çekirdek `NestedTree` böyle bir kaydı kabul edip ağacı bozardı;
        // ağaç bozulunca site menüsü boş çizilir ve sebebi görünmez.
        $this->signed(
            'PATCH',
            '/api/control/products/categories/'.$parent->category_id,
            $this->intent(['parent_id' => (int) $child->category_id]),
        )->assertStatus(422)
            ->assertJsonPath('error.details.reason', 'cycle');
    }

    public function test_kategori_kendisinin_altina_tasinamaz(): void
    {
        $category = $this->makeCategory('Tek Dal');

        $this->signed(
            'PATCH',
            '/api/control/products/categories/'.$category->category_id,
            $this->intent(['parent_id' => (int) $category->category_id]),
        )->assertStatus(422)
            ->assertJsonPath('error.details.reason', 'cycle');
    }

    public function test_kategori_gizlenir(): void
    {
        $category = $this->makeCategory('Gizlenecek');

        $this->signed(
            'PATCH',
            '/api/control/products/categories/'.$category->category_id,
            $this->intent(['status' => false]),
        )->assertOk()->assertJsonPath('data.status', false);

        $this->assertFalse((bool) Category::findOrFail($category->category_id)->status);
    }

    // ── 6. Tükendi işareti ────────────────────────────────────────────────

    public function test_tukendi_isareti_bugune_yazilir(): void
    {
        $menuId = $this->productId('Ayran');
        $today = BusinessTime::today();

        $this->signed('POST', '/api/control/products/'.$menuId.'/sold-out', $this->intent([
            'note' => 'Tedarikçi 15:00 sonrası getirecek',
        ]))->assertOk()
            ->assertJsonPath('data.sold_out_today', true)
            ->assertJsonPath('data.sold_out_on', $today)
            ->assertJsonPath('data.sold_out_reason', self::REASON);

        // Gerekçe mutfak ekranındaki "neden yok" sorusunun cevabı olarak
        // sütuna DA yazılır.
        $this->assertSame(self::REASON, DB::table('veykemtu_menu_soldout')
            ->where('menu_id', $menuId)
            ->whereDate('sold_out_on', $today)
            ->value('reason'));

        // `note` yalnız denetim izine gider.
        $this->assertSame(
            'Tedarikçi 15:00 sonrası getirecek',
            ControlAudit::firstOrFail()->payload_json['note'],
        );
    }

    public function test_IKINCI_ISARET_409_VERMEZ_gerekceyi_gunceller(): void
    {
        // İkinci bir gerekçe yazmak isteyen yöneticiyi hata ekranına
        // düşürmek anlamsız.
        $menuId = $this->productId('Ayran');
        $yeni = 'Tavuk tedariki gelmedi, bugünlük kapatıldı';

        $this->signed('POST', '/api/control/products/'.$menuId.'/sold-out', $this->intent())
            ->assertOk();

        $this->signed('POST', '/api/control/products/'.$menuId.'/sold-out', [
            'actor' => self::ACTOR,
            'reason' => $yeni,
        ])->assertOk()->assertJsonPath('data.sold_out_reason', $yeni);

        $this->assertSame(1, DB::table('veykemtu_menu_soldout')
            ->where('menu_id', $menuId)->count());
    }

    public function test_isaret_kaldirilir_ve_ISARET_YOKSA_DA_ok_doner(): void
    {
        $menuId = $this->productId('Ayran');

        // İşaret yokken de sonuç odaklı: istenen son hâl zaten geçerli.
        $this->signed('DELETE', '/api/control/products/'.$menuId.'/sold-out', $this->intent())
            ->assertOk()
            ->assertJsonPath('data.sold_out_today', false);

        $this->signed('POST', '/api/control/products/'.$menuId.'/sold-out', $this->intent())
            ->assertOk();

        $this->signed('DELETE', '/api/control/products/'.$menuId.'/sold-out', $this->intent())
            ->assertOk()
            ->assertJsonPath('data.sold_out_today', false);

        $this->assertSame(0, DB::table('veykemtu_menu_soldout')
            ->where('menu_id', $menuId)
            ->whereDate('sold_out_on', BusinessTime::today())
            ->count());
    }

    public function test_GECMIS_GUNUN_ISARETI_SILINMEZ(): void
    {
        // "Hangi ürün hangi gün bitti" sorusunun cevabı geçmiş satırlardır.
        $menuId = $this->productId('Ayran');

        DB::table('veykemtu_menu_soldout')->insert([
            'menu_id' => $menuId,
            'sold_out_on' => BusinessTime::now()->subDay()->toDateString(),
            'reason' => 'Dün de bitmişti',
            'created_at' => BusinessTime::forStorage(BusinessTime::now()->subDay()),
        ]);

        $this->signed('DELETE', '/api/control/products/'.$menuId.'/sold-out', $this->intent())
            ->assertOk();

        $this->assertSame(1, DB::table('veykemtu_menu_soldout')
            ->where('menu_id', $menuId)->count());
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    /**
     * İmzalı istek — kanonik dize `METOT \n YOL \n ZAMAN \n NONCE \n
     * sha256(ham gövde)`.
     *
     * Sorgu dizesi imzaya GİRMEZ; ara katman `getPathInfo()` okuyor.
     *
     * @param  array<string, mixed>|string|null  $body
     */
    private function signed(
        string $method,
        string $path,
        array|string|null $body = null,
    ): TestResponse {
        $raw = is_array($body) ? (string) json_encode($body, JSON_UNESCAPED_UNICODE) : (string) ($body ?? '');
        $timestamp = time();
        $nonce = bin2hex(random_bytes(12));

        $canonical = implode("\n", [
            strtoupper($method),
            (string) parse_url($path, PHP_URL_PATH),
            (string) $timestamp,
            $nonce,
            hash('sha256', $raw),
        ]);

        return $this->call($method, $path, [], [], [], [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_X_CONTROL_TIMESTAMP' => (string) $timestamp,
            'HTTP_X_CONTROL_NONCE' => $nonce,
            'HTTP_X_CONTROL_SIGNATURE' => 'sha256='.hash_hmac('sha256', $canonical, self::SECRET),
        ], $raw);
    }

    /**
     * @param  array<string, mixed>  $extra
     * @return array<string, mixed>
     */
    private function intent(array $extra = []): array
    {
        return ['actor' => self::ACTOR, 'reason' => self::REASON, ...$extra];
    }

    private function product(string $name): Menu
    {
        return Menu::where('menu_name', $name)->firstOrFail();
    }

    private function productId(string $name): int
    {
        return (int) $this->product($name)->menu_id;
    }

    /** @return list<int> */
    private function menuIdsOf(TestResponse $response): array
    {
        return array_map(
            static fn(array $row): int => (int) $row['menu_id'],
            $response->assertOk()->json('data'),
        );
    }

    private function makeCategory(string $name, ?int $parentId = null): Category
    {
        $category = new Category;
        $category->name = $name;
        $category->parent_id = $parentId;
        $category->priority = 0;
        $category->status = true;
        $category->save();

        return $category->refresh();
    }

    /** Ürünü verilen güne YAYINLANMIŞ bir menüye kalem olarak koyar. */
    private function publishDailyMenu(int $menuId, string $date): void
    {
        $now = BusinessTime::forStorage(BusinessTime::now());

        $dailyMenuId = (int) DB::table('veykemtu_daily_menus')->insertGetId([
            'location_id' => $this->locationId(),
            'menu_date' => $date,
            'status' => DailyMenu::STATUS_PUBLISHED,
            'components_sellable' => true,
            'published_at' => $now,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        DB::table('veykemtu_daily_menu_items')->insert([
            'daily_menu_id' => $dailyMenuId,
            'menu_id' => $menuId,
            'quantity' => 1,
            'sort_order' => 10,
            'is_required' => true,
            'sellable_alone' => true,
        ]);
    }
}
