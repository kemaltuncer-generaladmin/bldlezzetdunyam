<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Menu;
use Igniter\Flame\Flash\FlashBag;
use Igniter\Flame\Flash\Message;
use Igniter\Local\Models\Location;
use Igniter\User\Facades\AdminAuth;
use Igniter\User\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use ReflectionClass;
use ReflectionMethod;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Http\Controllers\Admin\DailyMenus;
use Veykemtu\BridgeApi\Models\ClosedDay;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Models\DailyMenuItem;
use Veykemtu\BridgeApi\Services\LocationGate;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Aylık menü takvimi ekranı — B-19.
 *
 * Bu ekranın riski, telefon siparişi ekranınınkinden farklı bir cinsten:
 * orada yanlış giren bir sipariş tek bir müşteriyi etkiliyor, burada yanlış
 * giren bir kural BİR AYI birden etkiliyor. Testler o yüzden ekranın üç
 * kuralını tek tek sabitliyor:
 *
 *  1. **Kopya taslak düşer.** Yayında bir haftayı kopyalayan yönetici,
 *     gelecek haftayı da yayına almış olmaz. Aksi hâlde yarım girilmiş
 *     yedi gün, kopyalandığı anda satışa çıkardı.
 *  2. **Kapalı gün ve siparişli gün atlanır ve RAPORLANIR.** İstenenden
 *     azını sessizce yapan bir kopya, reddeden bir kopyadan kötüdür:
 *     yönetici atlanan günü ancak o sabah öğrenir.
 *  3. **Siparişi olan gün kilitlidir.** `OrderEditor` paketi gün satırından
 *     yeniden fiyatlıyor; fiyat değişseydi yalnızca notu düzelten bir
 *     revizyon siparişi sessizce yeniden fiyatlandırır ve cari deftere
 *     uydurma bir iade/ek ücret yazardı — üstelik defter idempotent olduğu
 *     için kendiliğinden düzelmezdi.
 *
 * Ayrıca çekirdeğin işleyici çağırma tuzağı yansımayla kilitleniyor
 * (`test_her_isleyici_baglam_argumaniyla_baslar`).
 */
class AdminDailyMenuTest extends KitchenTestCase
{
    private const string BASE_URI = '/admin/veykemtu/bridgeapi/daily_menus';

    protected function setUp(): void
    {
        parent::setUp();

        /*
         * Sipariş açan testler için iki kapı: günün menüsü şalteri kapalı
         * doğuyor ve `veykemtu:setup` asgari sepeti 250,00 TL yazıyor. Bu
         * paket takvim ekranını sınıyor, o iki kuralı değil.
         */
        $gate = app(LocationGate::class);
        $gate->setDailyMenuEnabled($this->location(), true);
        $gate->setMinOrderTotal($this->location(), 0);
    }

    // ── Erişim ────────────────────────────────────────────────────────────

    public function test_ekran_acilir_ve_ham_ceviri_anahtari_sizmaz(): void
    {
        $this->actingAsAdmin();

        $this->get(self::BASE_URI)
            ->assertOk()
            ->assertSee(lang('veykemtu.bridgeapi::dailymenu.text_title'))
            ->assertSee(lang('veykemtu.bridgeapi::dailymenu.section_copy'))
            ->assertDontSee('veykemtu.bridgeapi::dailymenu');
    }

    /**
     * Izgara DOLU AY ile de çizilir ve gün kutusu üç soruyu birden cevaplar.
     *
     * Boş bir ay ile açılan ekran, hücrenin dolu hâlini —rozetleri, paket
     * fiyatını, kilit işaretini— hiç çalıştırmıyor. Oysa takvimin bütün
     * değeri o hücrede: yönetici otuz bir kutuyu tek tek açmak zorunda
     * kalırsa ızgaranın anlamı kalmaz. Bu test hücrenin dolu yolunu
     * (Blade'in `sprintf` çağrıları dahil) bir kez koşturuyor.
     */
    public function test_izgara_dolu_gunu_fiyat_ve_rozetlerle_cizer(): void
    {
        $this->actingAsAdmin();

        $this->makeDay(BusinessTime::now(), 18000, ['Tavuk Sote'], DailyMenu::STATUS_PUBLISHED);
        $this->makePublishedDayWithOrder(BusinessTime::now()->addDay());

        ClosedDay::create([
            'closed_on' => BusinessTime::now()->addDays(2)->toDateString(),
            'description' => 'Kurban Bayramı',
        ]);

        $this->get(self::BASE_URI)
            ->assertOk()
            ->assertSee('180,00 ₺')
            ->assertSee(lang('veykemtu.bridgeapi::dailymenu.badge_published'))
            ->assertSee(lang('veykemtu.bridgeapi::dailymenu.badge_closed'))
            // Kilit rozeti sayıyı gösterir, durumu okutur: ikisi de olmalı.
            ->assertSee(sprintf(lang('veykemtu.bridgeapi::dailymenu.cell_orders'), 1))
            ->assertSee(lang('veykemtu.bridgeapi::dailymenu.badge_locked'))
            ->assertDontSee('veykemtu.bridgeapi::dailymenu');
    }

    public function test_giris_yapmadan_acilmaz(): void
    {
        $this->get(self::BASE_URI)->assertRedirect();
    }

    /**
     * Menü yetkisi olmayan yönetici ekranı açamaz.
     *
     * Yetkinin SEKİZİNCİ ayrı kutu olmasının bütün anlamı bu: bu ekran
     * şirketin ne satacağına ve hangi fiyata satacağına karar veriyor.
     * Sipariş görüntüleme yetkisiyle aynı kutuya konsaydı, siparişlere
     * bakabilen herkes gelecek ayı yeniden fiyatlandırabilirdi.
     *
     * BEKLENEN KOD 403 DEĞİL 406: çekirdek yetkisiz erişimi `FlashException`
     * ile durduruyor ve o sınıfın varsayılan kodu 406'dır. Kod bizim
     * seçimimiz değil, panelin tamamında geçerli kural (`AdminSiteContentTest`
     * aynı gerekçeyi taşıyor).
     */
    public function test_yetkisiz_yonetici_ekrani_acamaz(): void
    {
        $this->actingAsAdmin(superUser: false);

        $this->get(self::BASE_URI)->assertStatus(406);
    }

    public function test_yetkisiz_yonetici_gun_kaydedemez(): void
    {
        $this->actingAsAdmin(superUser: false);

        $this->post(self::BASE_URI, [
            '_handler' => 'onSaveDay',
            'day_date' => BusinessTime::today(),
            'title' => 'Yetkisiz menü',
        ])->assertStatus(406);

        $this->assertSame(0, DailyMenu::query()->count());
    }

    // ── Gün kaydetme ──────────────────────────────────────────────────────

    /**
     * Gün ve kalemleri GÖNDERİLEN SIRAYLA yazılır.
     *
     * ÜRÜN SEÇİMİ BURADA TESADÜF DEĞİL: demo katalogda "Mercimek Çorbası"nın
     * `menu_id`'si "Tavuk Sote"ninkinden BÜYÜK. Çorba önce gönderiliyor, yani
     * gönderim sırası ile ürün kimliği sırası TERS. Kalemler sırasız okunursa
     * MySQL onları `(daily_menu_id, menu_id)` tekil indeksinden, yani ürün
     * kimliği sırasında getirir ve çorba ana yemeğin altına düşer — testin
     * yakaladığı arıza tam olarak buydu. İki ürünü "daha okunur" diye
     * kimlik sırasına çevirmek, bu kapıyı sessizce açık bırakır.
     */
    public function test_gun_kaydedilir_ve_kalemler_sirasiyla_yazilir(): void
    {
        $this->actingAsAdmin();

        $soup = $this->productId('Mercimek Çorbası');
        $main = $this->productId('Tavuk Sote');

        $this->assertGreaterThan(
            $main,
            $soup,
            'Testin anlamı bu eşitsizliğe dayanıyor: gönderim sırası ile ürün '
            .'kimliği sırası ters olmalı, yoksa sırasız okuma yakalanamaz.',
        );

        $this->post(self::BASE_URI, [
            '_handler' => 'onSaveDay',
            'day_date' => BusinessTime::today(),
            'title' => 'Ev Yemeği Menüsü',
            'description' => 'Çorba, ana yemek ve tatlı.',
            'internal_note' => 'Tavuk tedarikçisi B firması.',
            'package_price' => '180,00',
            'components_sellable' => '1',
            'items' => [
                // İndisler bilerek karışık: sunucu SIRAYA bakmalı, anahtara
                // değil. Tarayıcı da satırları DOM sırasıyla gönderiyor.
                7 => ['menu_id' => $soup, 'quantity' => '1', 'price_override' => '40,00', 'is_required' => '1', 'sellable_alone' => '1', 'label' => 'Günün Çorbası'],
                3 => ['menu_id' => $main, 'quantity' => '2', 'price_override' => '', 'is_required' => '1'],
            ],
        ])->assertRedirect();

        $menu = DailyMenu::query()->with('items')->first();

        $this->assertNotNull($menu);
        $this->assertSame('Ev Yemeği Menüsü', $menu->title);
        $this->assertSame('Tavuk tedarikçisi B firması.', $menu->internal_note);
        $this->assertSame(18000, (int) $menu->package_price_kurus);
        $this->assertTrue((bool) $menu->components_sellable);
        $this->assertCount(2, $menu->items);

        $items = $menu->items->values();

        $this->assertSame($soup, (int) $items[0]->menu_id, 'İlk gönderilen satır ilk sırada olmalı.');
        $this->assertSame(0, (int) $items[0]->sort_order);
        $this->assertSame(4000, (int) $items[0]->price_override_kurus);
        $this->assertSame('Günün Çorbası', $items[0]->label);

        $this->assertSame($main, (int) $items[1]->menu_id);
        $this->assertSame(1, (int) $items[1]->sort_order);
        $this->assertSame(2, (int) $items[1]->quantity);
        $this->assertNull($items[1]->price_override_kurus, 'Boş gün fiyatı sıfır değil, NULL olmalı.');
        $this->assertFalse((bool) $items[1]->sellable_alone, 'İşaretlenmemiş kutu false olmalı.');
    }

    /**
     * YENİ GÜN TASLAK DOĞAR — kopyalamayla aynı gerekçe.
     *
     * Kaydetmek ile satmak aynı harekete bağlansaydı, yarım girilmiş bir
     * perşembe kaydedildiği anda müşteriye görünürdü.
     */
    public function test_yeni_gun_taslak_dogar(): void
    {
        $this->actingAsAdmin();

        $this->post(self::BASE_URI, [
            '_handler' => 'onSaveDay',
            'day_date' => BusinessTime::today(),
            'title' => 'Ev Yemeği Menüsü',
            'package_price' => '180,00',
            'items' => [['menu_id' => $this->productId('Tavuk Sote'), 'quantity' => '1']],
        ])->assertRedirect();

        $this->assertSame(DailyMenu::STATUS_DRAFT, DailyMenu::query()->value('status'));
        $this->assertNull(DailyMenu::query()->value('published_at'));
    }

    /**
     * Sıfır paket fiyatı reddedilir.
     *
     * Boş = "o gün paket satılmıyor", sıfır = "bedava". `LineResolver`
     * sıfırı zaten reddediyor; panel sessizce kabul etseydi yönetici
     * paketi yayına aldığını sanır, müşteri sipariş veremezdi.
     */
    public function test_sifir_paket_fiyati_reddedilir(): void
    {
        $this->actingAsAdmin();

        $this->post(self::BASE_URI, [
            '_handler' => 'onSaveDay',
            'day_date' => BusinessTime::today(),
            'package_price' => '0',
            'items' => [['menu_id' => $this->productId('Tavuk Sote'), 'quantity' => '1']],
        ]);

        $this->assertSame(0, DailyMenu::query()->count());
    }

    public function test_ayni_urun_iki_kez_eklenemez(): void
    {
        $this->actingAsAdmin();

        $main = $this->productId('Tavuk Sote');

        $this->post(self::BASE_URI, [
            '_handler' => 'onSaveDay',
            'day_date' => BusinessTime::today(),
            'package_price' => '180,00',
            'items' => [
                ['menu_id' => $main, 'quantity' => '1'],
                ['menu_id' => $main, 'quantity' => '1'],
            ],
        ]);

        $this->assertSame(0, DailyMenu::query()->count());
        $this->assertSame(0, DailyMenuItem::query()->count());
    }

    /** Paketin kendisi bir kalem olamaz — fiyatı 0,00 olan sonsuz bir kutu. */
    public function test_paket_urunu_kalem_olarak_eklenemez(): void
    {
        $this->actingAsAdmin();

        $this->post(self::BASE_URI, [
            '_handler' => 'onSaveDay',
            'day_date' => BusinessTime::today(),
            'package_price' => '180,00',
            'items' => [['menu_id' => $this->packageMenuId(), 'quantity' => '1']],
        ]);

        $this->assertSame(0, DailyMenu::query()->count());
    }

    // ── Yayına alma ───────────────────────────────────────────────────────

    public function test_yayina_alma_durumu_cevirir(): void
    {
        $this->actingAsAdmin();
        $this->makeDay(BusinessTime::now(), 18000, ['Tavuk Sote']);

        $this->post(self::BASE_URI, [
            '_handler' => 'onPublish',
            'day_date' => BusinessTime::today(),
            'publish_status' => DailyMenu::STATUS_PUBLISHED,
        ])->assertRedirect();

        $menu = DailyMenu::query()->first();

        $this->assertSame(DailyMenu::STATUS_PUBLISHED, $menu->status);
        $this->assertNotNull($menu->published_at);

        // Ve geri: taslağa çekilen gün "bir zamanlar yayındaydı" bilgisini
        // taşımaz — `findPublished()` yalnız `status`'e bakıyor.
        $this->post(self::BASE_URI, [
            '_handler' => 'onPublish',
            'day_date' => BusinessTime::today(),
            'publish_status' => DailyMenu::STATUS_DRAFT,
        ])->assertRedirect();

        $menu = DailyMenu::query()->first();

        $this->assertSame(DailyMenu::STATUS_DRAFT, $menu->status);
        $this->assertNull($menu->published_at);
    }

    public function test_kalemsiz_gun_yayina_alinamaz(): void
    {
        $this->actingAsAdmin();
        $this->makeDay(BusinessTime::now(), 18000, []);

        $this->post(self::BASE_URI, [
            '_handler' => 'onPublish',
            'day_date' => BusinessTime::today(),
            'publish_status' => DailyMenu::STATUS_PUBLISHED,
        ]);

        $this->assertSame(DailyMenu::STATUS_DRAFT, DailyMenu::query()->value('status'));
    }

    /**
     * Ne paket ne kalem satılıyorsa gün yayına alınamaz.
     *
     * Yayına alınsaydı ızgarada "yayında" görünür, müşteride hiçbir şey
     * satılamazdı — belirtisi ancak şikâyetle görülen bir arıza.
     */
    public function test_satilamaz_gun_yayina_alinamaz(): void
    {
        $this->actingAsAdmin();

        $menu = $this->makeDay(BusinessTime::now(), null, ['Tavuk Sote']);
        $menu->components_sellable = false;
        $menu->save();

        $this->post(self::BASE_URI, [
            '_handler' => 'onPublish',
            'day_date' => BusinessTime::today(),
            'publish_status' => DailyMenu::STATUS_PUBLISHED,
        ]);

        $this->assertSame(DailyMenu::STATUS_DRAFT, DailyMenu::query()->value('status'));
    }

    // ── KURAL 1 + 2: kopyalama ────────────────────────────────────────────

    /**
     * KURAL 1 — kopya HER ZAMAN taslak düşer, kaynak yayında olsa bile.
     */
    public function test_hafta_kopyasi_taslak_olarak_duser(): void
    {
        $this->actingAsAdmin();

        $monday = BusinessTime::now()->startOfWeek(Carbon::MONDAY);
        $this->makeDay($monday, 18000, ['Tavuk Sote'], DailyMenu::STATUS_PUBLISHED);

        $this->post(self::BASE_URI, [
            '_handler' => 'onCopyWeek',
            'copy_week_start' => $monday->toDateString(),
        ])->assertRedirect();

        $copy = DailyMenu::query()
            ->whereDate('menu_date', $monday->copy()->addDays(7)->toDateString())
            ->with('items')
            ->first();

        $this->assertNotNull($copy, 'Hafta kopyası hedef güne düşmeli.');
        $this->assertSame(
            DailyMenu::STATUS_DRAFT,
            $copy->status,
            'Kaynak yayında olsa bile kopya TASLAK düşmeli.',
        );
        $this->assertNull($copy->published_at);
        $this->assertSame(18000, (int) $copy->package_price_kurus);
        $this->assertCount(1, $copy->items);
    }

    /**
     * KURAL 2 + 3 — kapalı gün ve siparişli gün atlanır, İKİSİ DE raporlanır.
     *
     * `overwrite` açık: kapalı gün overwrite verilse bile atlanmalı.
     */
    public function test_hafta_kopyasi_kapali_ve_siparisli_gunu_atlar_ve_ikisini_de_raporlar(): void
    {
        $this->actingAsAdmin();

        $monday = BusinessTime::now()->startOfWeek(Carbon::MONDAY);

        // Kaynak hafta: yedi günün de menüsü var.
        for ($offset = 0; $offset < 7; $offset++) {
            $this->makeDay($monday->copy()->addDays($offset), 18000, ['Tavuk Sote']);
        }

        // Hedef haftada iki engel: biri kapalı gün, biri siparişli gün.
        $closedTarget = $monday->copy()->addDays(7);
        ClosedDay::create([
            'closed_on' => $closedTarget->toDateString(),
            'description' => 'Kurban Bayramı',
        ]);

        $orderedTarget = $monday->copy()->addDays(9);
        $this->makePublishedDayWithOrder($orderedTarget);

        $this->post(self::BASE_URI, [
            '_handler' => 'onCopyWeek',
            'copy_week_start' => $monday->toDateString(),
            'copy_overwrite' => '1',
        ])->assertRedirect();

        // Kapalı güne menü YAZILMADI.
        $this->assertNull(
            DailyMenu::query()->whereDate('menu_date', $closedTarget->toDateString())->first(),
            'Kapalı güne overwrite verilse bile menü yazılmamalı.',
        );

        // Siparişli günün paket fiyatı DEĞİŞMEDİ ve yayında kaldı.
        $ordered = DailyMenu::query()
            ->whereDate('menu_date', $orderedTarget->toDateString())
            ->first();

        $this->assertNotNull($ordered);
        $this->assertSame(25000, (int) $ordered->package_price_kurus, 'Siparişli günün fiyatı donmalı.');
        $this->assertSame(DailyMenu::STATUS_PUBLISHED, $ordered->status);

        // Kalan beş gün kopyalandı.
        $copied = DailyMenu::query()
            ->whereBetween('menu_date', [
                $monday->copy()->addDays(7)->toDateString(),
                $monday->copy()->addDays(13)->toDateString(),
            ])
            ->where('status', DailyMenu::STATUS_DRAFT)
            ->count();

        $this->assertSame(5, $copied);

        // VE İKİSİ DE RAPORLANDI. İstenenden azını sessizce yapan bir kopya,
        // reddeden bir kopyadan kötüdür.
        $message = $this->lastFlashMessage();

        $this->assertStringContainsString($closedTarget->format('d.m'), $message);
        $this->assertStringContainsString($orderedTarget->format('d.m'), $message);
        $this->assertStringContainsString('5', $message);
    }

    public function test_kopya_overwrite_yoksa_dolu_hedefi_atlar(): void
    {
        $this->actingAsAdmin();

        $monday = BusinessTime::now()->startOfWeek(Carbon::MONDAY);
        $this->makeDay($monday, 18000, ['Tavuk Sote']);

        $target = $monday->copy()->addDays(7);
        $existing = $this->makeDay($target, 9900, ['Mercimek Çorbası']);

        $this->post(self::BASE_URI, [
            '_handler' => 'onCopyWeek',
            'copy_week_start' => $monday->toDateString(),
        ])->assertRedirect();

        $this->assertSame(
            9900,
            (int) $existing->refresh()->package_price_kurus,
            'Overwrite verilmedikçe dolu hedef gün korunmalı.',
        );
    }

    public function test_gun_secili_gunlere_uygulanir(): void
    {
        $this->actingAsAdmin();

        $source = BusinessTime::now();
        $this->makeDay($source, 18000, ['Tavuk Sote'], DailyMenu::STATUS_PUBLISHED);

        $first = $source->copy()->addDays(3);
        $second = $source->copy()->addDays(4);

        $this->post(self::BASE_URI, [
            '_handler' => 'onCopyDay',
            'source_date' => $source->toDateString(),
            // Kaynağın kendisi hedefler arasında: atlanmalı, kendi üstüne
            // kopyalamak onu taslağa düşürürdü.
            'target_dates' => [
                $source->toDateString(),
                $first->toDateString(),
                $second->toDateString(),
            ],
        ])->assertRedirect();

        foreach ([$first, $second] as $date) {
            $copy = DailyMenu::query()->whereDate('menu_date', $date->toDateString())->first();

            $this->assertNotNull($copy, $date->toDateString().' kopyalanmalı.');
            $this->assertSame(DailyMenu::STATUS_DRAFT, $copy->status);
        }

        $this->assertSame(
            DailyMenu::STATUS_PUBLISHED,
            DailyMenu::query()->whereDate('menu_date', $source->toDateString())->value('status'),
            'Kaynak gün kendi üstüne kopyalanıp taslağa düşmemeli.',
        );
    }

    public function test_menusu_olmayan_kaynak_gun_kopyalanamaz(): void
    {
        $this->actingAsAdmin();

        $source = BusinessTime::now();

        $this->post(self::BASE_URI, [
            '_handler' => 'onCopyDay',
            'source_date' => $source->toDateString(),
            'target_dates' => [$source->copy()->addDay()->toDateString()],
        ]);

        $this->assertSame(0, DailyMenu::query()->count());
    }

    // ── KURAL 3: siparişli gün kilitli ────────────────────────────────────

    public function test_siparisli_gunde_fiyat_ve_kalem_degisikligi_reddedilir(): void
    {
        $this->actingAsAdmin();

        $date = BusinessTime::now()->addDay();
        $menu = $this->makePublishedDayWithOrder($date);

        $this->post(self::BASE_URI, [
            '_handler' => 'onSaveDay',
            'day_date' => $date->toDateString(),
            'title' => 'Değiştirilmeye çalışıldı',
            'package_price' => '10,00',
            'items' => [['menu_id' => $this->productId('Mercimek Çorbası'), 'quantity' => '1']],
        ]);

        $menu = $menu->refresh();

        $this->assertSame(25000, (int) $menu->package_price_kurus, 'Fiyat donmalı.');
        $this->assertNotSame('Değiştirilmeye çalışıldı', $menu->title, 'Kayıt tamamen reddedilmeli.');
        $this->assertSame(
            [$this->productId('Tavuk Sote')],
            $menu->items->pluck('menu_id')->map(intval(...))->all(),
            'Kalemler donmalı.',
        );
    }

    /**
     * Kilitli günde KOZMETİK alanlar düzenlenebilir kalır.
     *
     * Başlık ve açıklama siparişin fiyatını etkilemiyor; sipariş satırındaki
     * ad zaten `orderLineName()` ile kopyalanmış durumda. Onları da dondurmak,
     * bir yazım hatasını düzeltmeyi imkânsız kılardı.
     */
    public function test_siparisli_gunde_kozmetik_alanlar_kaydedilebilir(): void
    {
        $this->actingAsAdmin();

        $date = BusinessTime::now()->addDay();
        $menu = $this->makePublishedDayWithOrder($date);

        $this->post(self::BASE_URI, [
            '_handler' => 'onSaveDay',
            'day_date' => $date->toDateString(),
            'title' => 'Ev Yemeği Menüsü (düzeltildi)',
            'internal_note' => 'Tedarikçi değişti.',
        ])->assertRedirect();

        $menu = $menu->refresh();

        $this->assertSame('Ev Yemeği Menüsü (düzeltildi)', $menu->title);
        $this->assertSame('Tedarikçi değişti.', $menu->internal_note);
        $this->assertSame(25000, (int) $menu->package_price_kurus);
    }

    public function test_siparisli_gunun_yayin_durumu_degistirilemez(): void
    {
        $this->actingAsAdmin();

        $date = BusinessTime::now()->addDay();
        $menu = $this->makePublishedDayWithOrder($date);

        $this->post(self::BASE_URI, [
            '_handler' => 'onPublish',
            'day_date' => $date->toDateString(),
            'publish_status' => DailyMenu::STATUS_DRAFT,
        ]);

        $this->assertSame(
            DailyMenu::STATUS_PUBLISHED,
            $menu->refresh()->status,
            'Siparişli gün taslağa çekilemez — siparişler o günün menüsüne bağlı.',
        );
    }

    /**
     * İPTAL EDİLMİŞ SİPARİŞ GÜNÜ KİLİTLEMEZ.
     *
     * İptal, cari borcu ters kayıtla nötrledi ve durum makinesi iptal
     * edilmiş bir siparişin revizyonuna izin vermiyor — yeniden fiyatlama
     * riski yok. Sayılsaydı tek bir iptal o günü sonsuza kadar kilitlerdi.
     */
    public function test_iptal_edilen_siparis_gunu_kilitlemez(): void
    {
        $this->actingAsAdmin();

        $date = BusinessTime::now()->addDay();
        $menu = $this->makePublishedDayWithOrder($date);

        $order = \Igniter\Cart\Models\Order::query()->latest('order_id')->firstOrFail();
        resolve(OrderStatusTransition::class)->apply($order, OrderStatusTransition::CANCELLED);

        $this->post(self::BASE_URI, [
            '_handler' => 'onSaveDay',
            'day_date' => $date->toDateString(),
            'title' => 'Yeniden fiyatlandı',
            'package_price' => '199,00',
            'items' => [['menu_id' => $this->productId('Tavuk Sote'), 'quantity' => '1']],
        ])->assertRedirect();

        $this->assertSame(19900, (int) $menu->refresh()->package_price_kurus);
    }

    // ── Toplu durum ───────────────────────────────────────────────────────

    public function test_toplu_yayin_siparisli_gunu_atlar_ve_raporlar(): void
    {
        $this->actingAsAdmin();

        /*
         * AY, SİPARİŞLİ GÜNDEN TÜRETİLİYOR — tersi değil.
         *
         * Siparişli gün gelecekte olmak zorunda (geçmiş güne sipariş
         * verilemez), yani `now()+1`. Ay bağımsız seçilseydi ayın son
         * gününde o gün SONRAKİ aya düşer, toplu işlem onu hiç görmez ve
         * test yılda on iki kez, takvim yüzünden kırılırdı.
         */
        $orderedDate = BusinessTime::now()->addDay();
        $month = $orderedDate->copy()->startOfMonth();

        /*
         * Aynı ayda ikinci bir gün — toplu işlemin tek güne bakmadığını
         * göstermek için. Siparişli günle ÇAKIŞMAMALI: aynı güne iki menü
         * yazmak `(location_id, menu_date)` tekil anahtarını ihlal eder ve
         * ayın 1'inde tam da bu olurdu.
         */
        $draftDate = $orderedDate->isSameDay($month)
            ? $month->copy()->addDay()
            : $month->copy();

        $this->makeDay($draftDate, 18000, ['Tavuk Sote']);

        $ordered = $this->makePublishedDayWithOrder($orderedDate);

        $this->post(self::BASE_URI, [
            '_handler' => 'onBulkStatus',
            'month' => $month->format('Y-m'),
            'bulk_status' => DailyMenu::STATUS_DRAFT,
        ])->assertRedirect();

        $this->assertSame(
            DailyMenu::STATUS_PUBLISHED,
            $ordered->refresh()->status,
            'Siparişli gün toplu işlemde de donmalı.',
        );

        $this->assertStringContainsString(
            $orderedDate->format('d.m'),
            $this->lastFlashMessage(),
            'Atlanan gün raporlanmalı.',
        );
    }

    public function test_toplu_yayin_ayin_menulerini_yayina_alir(): void
    {
        $this->actingAsAdmin();

        $month = BusinessTime::now()->startOfMonth();
        $this->makeDay($month->copy()->addDays(4), 18000, ['Tavuk Sote']);
        $this->makeDay($month->copy()->addDays(5), 18000, ['Mercimek Çorbası']);

        $this->post(self::BASE_URI, [
            '_handler' => 'onBulkStatus',
            'month' => $month->format('Y-m'),
            'bulk_status' => DailyMenu::STATUS_PUBLISHED,
        ])->assertRedirect();

        $this->assertSame(
            2,
            DailyMenu::query()->where('status', DailyMenu::STATUS_PUBLISHED)->count(),
        );
    }

    // ── Çekirdek tuzağı ───────────────────────────────────────────────────

    /**
     * ÖLÜMCÜL TUZAĞIN KİLİDİ.
     *
     * Çekirdek `AdminController::processHandlers()` işleyiciyi
     * `[$this->action, ...$this->params]` ile çağırıyor, yani İLK ARGÜMAN
     * HER ZAMAN bağlam adıdır (`index`). Tek parametreli yazılan bir
     * `onXxx(?string $date)` metodu `$date` olarak `"index"` alır, günü
     * bulamaz ve ekran sebebi anlaşılmayan bir 406 döner — B-14'te sahada
     * oldu.
     *
     * Test imzayı yansımayla sabitliyor: yeni bir işleyici eklenirken bu
     * kural unutulursa, arıza sahada değil burada görünür.
     */
    public function test_her_isleyici_baglam_argumaniyla_baslar(): void
    {
        $reflection = new ReflectionClass(DailyMenus::class);

        $handlers = array_filter(
            $reflection->getMethods(ReflectionMethod::IS_PUBLIC),
            static fn(ReflectionMethod $method): bool
                => $method->getDeclaringClass()->getName() === DailyMenus::class
                    && preg_match('/^on[A-Z]/', $method->getName()) === 1,
        );

        $this->assertNotEmpty($handlers, 'Ekranın en az bir AJAX işleyicisi olmalı.');

        foreach ($handlers as $handler) {
            $parameters = $handler->getParameters();

            $this->assertNotEmpty(
                $parameters,
                $handler->getName().' bağlam argümanını almalı.',
            );

            $first = $parameters[0];

            $this->assertSame(
                'context',
                $first->getName(),
                $handler->getName().' ilk argümanı bağlam adıdır; adı `context` olmalı.',
            );
            $this->assertSame(
                'string',
                (string) $first->getType(),
                $handler->getName().' bağlam argümanı `string` olmalı.',
            );
            $this->assertFalse(
                $first->isOptional(),
                $handler->getName().' bağlam argümanı isteğe bağlı olamaz.',
            );
        }
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    private function location(): Location
    {
        return Location::query()->where('location_id', $this->locationId())->firstOrFail();
    }

    private function productId(string $name): int
    {
        return (int) Menu::query()->where('menu_name', $name)->firstOrFail()->menu_id;
    }

    private function packageMenuId(): int
    {
        return (int) DailyMenu::packageMenuIdFor($this->locationId());
    }

    /**
     * Bir güne menü kurar.
     *
     * @param  list<string>  $items  ürün adları
     */
    private function makeDay(
        Carbon $date,
        ?int $packagePriceKurus,
        array $items,
        string $status = DailyMenu::STATUS_DRAFT,
    ): DailyMenu {
        $menu = DailyMenu::create([
            'location_id' => $this->locationId(),
            'menu_date' => $date->toDateString(),
            'title' => 'Ev Yemeği Menüsü',
            'package_price_kurus' => $packagePriceKurus,
            'components_sellable' => true,
            'status' => $status,
            'published_at' => $status === DailyMenu::STATUS_PUBLISHED
                ? BusinessTime::forStorage(BusinessTime::now())
                : null,
        ]);

        foreach ($items as $index => $name) {
            DailyMenuItem::create([
                'daily_menu_id' => $menu->id,
                'menu_id' => $this->productId($name),
                'quantity' => 1,
                'sort_order' => $index,
            ]);
        }

        return $menu->refresh();
    }

    /**
     * O güne yayında bir menü kurar VE gerçek bir sipariş açar.
     *
     * Sipariş `OrderFactory` üzerinden geçiyor (API ucu), doğrudan tabloya
     * yazılmıyor: kilidin dayandığı `orders.bld_service_date` değerini o
     * yazıyor. Elle insert edilseydi test, gerçekte var olmayan bir
     * değişmezi doğrulardı.
     */
    private function makePublishedDayWithOrder(Carbon $date): DailyMenu
    {
        $menu = $this->makeDay($date, 25000, ['Tavuk Sote'], DailyMenu::STATUS_PUBLISHED);

        $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->packageMenuId(), 'quantity' => 1]],
            'delivery_type' => 'pickup',
            'payment_method' => 'cash',
            'service_date' => $date->toDateString(),
        ], self::HEADERS)->assertCreated();

        $this->assertSame(
            1,
            DB::table('orders')->whereDate('bld_service_date', $date->toDateString())->count(),
            'Kilidi kuran değişmez: `orders.bld_service_date` yazılmış olmalı.',
        );

        // Müşteri belirteci sonraki panel isteklerine bulaşmasın — panel
        // oturumla kimlikleniyor ve iki kimliğin aynı istekte durması,
        // bir gün sebebi anlaşılmayan bir hata olurdu.
        $this->withHeaders(['Authorization' => '']);

        return $menu->refresh();
    }

    /**
     * Bu istekte biriken flash mesajlarının metni — kopyalama/toplu işlem
     * raporunu okumak için.
     *
     * OTURUM ANAHTARI TAHMİN EDİLMEZ. Burada önce Laravel dünyasının alışıldık
     * `flash_notification` anahtarı okunuyordu; TastyIgniter'ın kendi torbası
     * ise anahtarı çalışma bağlamına göre seçiyor
     * (`System\ServiceProvider::resolveFlashSessionKey` → panelde
     * `flash_data_admin`, sitede `flash_data_main`). Yanlış anahtar boş dizi
     * döndürüyordu ve testler "rapor hiç yazılmamış" diye kırılıyordu — oysa
     * rapor yazılmıştı, yalnız başka bir kutudaydı. Sabiti kopyalamak yerine
     * torbanın kendisi okunuyor: anahtar değişirse test yine doğru yeri okur.
     */
    private function lastFlashMessage(): string
    {
        /** @var FlashBag $bag */
        $bag = resolve('flash');

        return $bag->messages()
            ->map(static fn(Message $message): string => (string) $message->message)
            ->implode(' | ');
    }

    private function actingAsAdmin(bool $superUser = true): void
    {
        $user = new User;
        $user->fill([
            'name' => 'Test Yönetici',
            'username' => 'testyonetici',
            'email' => 'yonetici@ornek.com',
            'status' => true,
            'super_user' => $superUser,
        ]);
        $user->password = 'parola123';
        $user->is_activated = true;
        $user->activated_at = now();
        $user->save();

        AdminAuth::login($user);
    }
}
