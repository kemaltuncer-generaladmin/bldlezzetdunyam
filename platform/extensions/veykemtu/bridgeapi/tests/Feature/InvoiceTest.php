<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Menu;
use Igniter\Cart\Models\Order;
use Igniter\Local\Models\Location;
use Illuminate\Routing\Middleware\ThrottleRequests;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Models\DailyMenuItem;
use Veykemtu\BridgeApi\Models\Invoice;
use Veykemtu\BridgeApi\Models\InvoiceCounter;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Services\InvoiceService;
use Veykemtu\BridgeApi\Services\LocationGate;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Fatura belgesi — numaralandırma, donmuş içerik, A4 çizim (B2).
 *
 * BU PAKETİN KİLİTLEDİĞİ DÖRT ŞEY:
 *
 *  1. **Numara boşluksuz ve benzersiz.** Sayaç tablosu satır kilidiyle
 *     ayırıyor; `MAX(sequence)+1` olsaydı eşzamanlı iki kesim aynı sayıyı
 *     alır ve tekil indeks yazdır düğmesini 500'e çevirirdi.
 *  2. **Sıra yıl başında sıfırlanır** ve yıl İŞLETME takviminden okunur.
 *  3. **İçerik donar.** Sipariş sonradan düzenlense bile basılmış belge
 *     aynı kâğıdı üretir; müşterinin elindeki kopya "yanlış" olamaz.
 *  4. **Belge iptal edilir, silinmez.** İptal numarayı serbest bırakmaz ve
 *     kâğıdın üstüne çapraz "İPTAL" filigranı düşer.
 *
 * SERVİS GÜNÜ HEP İLERİ BİR HAFTA İÇİ (`DailyStockTest` ile aynı gerekçe):
 * bugüne sipariş vermek testi kesim saatine bağlar ve öğleden sonraki
 * koşumda arıza faturayla hiç ilgili olmaz.
 */
class InvoiceTest extends KitchenTestCase
{
    /** Anlaşmalı porsiyon fiyatı (kuruş) — 150,00 TL. */
    private const int AGREED_PRICE = 15000;

    protected function setUp(): void
    {
        parent::setUp();

        $gate = app(LocationGate::class);
        $gate->setDailyMenuEnabled($this->location(), true);

        // Asgari sepet tutarı bu pakette ölçülen şey değil; `veykemtu:setup`
        // 250,00 TL yazıyor ve tek porsiyonluk siparişlerin hiçbiri geçmezdi.
        $gate->setMinOrderTotal($this->location(), 0);

        // Numaralandırma testleri onlarca sipariş açıyor; `bld-order` kovası
        // müşteri başına 20/saat ve ölçtüğümüz şey o değil.
        $this->withoutMiddleware(ThrottleRequests::class);
    }

    // ── Numaralandırma ──────────────────────────────────────────────────

    /**
     * İlk kesim `BLD-<yıl>-000001`, ikincisi `...000002`.
     *
     * Biçimin kendisi sözleşmede (`docs/control/invoices.md`): altı hane,
     * sıfır dolgulu. Dolgusuz bir sıra, listede alfabetik sıralandığında
     * 10'u 2'nin önüne koyardı.
     */
    public function test_ilk_kesim_bir_numaradan_baslar(): void
    {
        $yil = BusinessTime::now()->year;

        $ilk = $this->issueOrderInvoice();
        $ikinci = $this->issueOrderInvoice();

        $this->assertSame("BLD-{$yil}-000001", $ilk->invoice_no);
        $this->assertSame("BLD-{$yil}-000002", $ikinci->invoice_no);
        $this->assertSame(1, $ilk->sequence);
        $this->assertSame(2, $ikinci->sequence);
        $this->assertSame(Invoice::STATUS_ISSUED, $ilk->status);
        $this->assertSame(Invoice::TYPE_ORDER, $ilk->type);
    }

    /**
     * ON KESİM → ON FARKLI, BOŞLUKSUZ NUMARA, İSTİSNA YOK.
     *
     * NE KANITLIYOR: sayaç her çağrıda tam bir artıyor, tekil indeks hiç
     * devreye girmiyor ve seride delik kalmıyor. Sayaç yerine
     * `MAX(sequence)+1` kullanılsaydı bu testin kendisi (tek bağlantı,
     * sıralı) yine geçerdi — asıl güvence sonraki testte.
     *
     * NE KANITLAMIYOR — dürüstlük payı: PHPUnit tek süreçte ve tek
     * bağlantıda koşuyor (`RefreshDatabase` her testi bir işleme sarıyor),
     * yani işletim sistemi düzeyinde gerçek eşzamanlılık kurulamıyor.
     * Eşzamanlılık güvencesi `SELECT ... FOR UPDATE`'in kendisidir
     * (`InvoiceCounter::allocate`); burada onun gözlenebilir yüzü
     * kilitleniyor.
     */
    public function test_on_kesim_bosluksuz_ve_benzersiz_numara_uretir(): void
    {
        $yil = BusinessTime::now()->year;
        $numaralar = [];

        for ($i = 1; $i <= 10; $i++) {
            $invoice = $this->issueOrderInvoice();
            $numaralar[] = $invoice->invoice_no;

            $this->assertSame($i, $invoice->sequence, "kesim {$i}");
        }

        $this->assertCount(10, array_unique($numaralar));
        $this->assertSame("BLD-{$yil}-000001", $numaralar[0]);
        $this->assertSame("BLD-{$yil}-000010", $numaralar[9]);

        // Seride delik yok: sıralar 1..10 aralığının tamamını dolduruyor.
        $sequences = Invoice::query()->orderBy('sequence')->pluck('sequence')->all();
        $this->assertSame(range(1, 10), array_map(intval(...), $sequences));
    }

    /**
     * SAYAÇ `MAX(sequence)+1` DEĞİL — asıl kanıt bu.
     *
     * Belge tablosundaki en büyük sıra elle geriye çekiliyor. `MAX+1`
     * kullanan bir üretici bir sonraki kesimde AYNI numarayı yeniden
     * verirdi; sayaç tablosu kendi ilerlemesini hatırladığı için vermez.
     *
     * Aynı şey iptal için de geçerli: iptal edilen numara serbest kalmaz.
     */
    public function test_numara_en_buyuk_siradan_turetilmez(): void
    {
        $yil = BusinessTime::now()->year;

        $this->issueOrderInvoice();
        $ikinci = $this->issueOrderInvoice();
        $this->issueOrderInvoice();

        // Ortadaki belgenin sırası tablodan siliniyor (üretimde `DELETE`
        // yok; burada yalnız `MAX+1` senaryosu kuruluyor).
        DB::table('veykemtu_invoices')->where('id', $ikinci->id)->delete();
        $this->assertSame(2, (int) DB::table('veykemtu_invoices')->count());

        $dorduncu = $this->issueOrderInvoice();

        $this->assertSame(4, $dorduncu->sequence);
        $this->assertSame("BLD-{$yil}-000004", $dorduncu->invoice_no);
    }

    /** Sayaç seviyesinde: yeni yıl kendi satırını açar ve 1'den başlar. */
    public function test_sayac_yil_basinda_sifirlanir(): void
    {
        [$a, $numaraA] = InvoiceCounter::allocate(2026);
        [$b, $numaraB] = InvoiceCounter::allocate(2026);
        [$c, $numaraC] = InvoiceCounter::allocate(2027);
        [$d] = InvoiceCounter::allocate(2026);

        $this->assertSame([1, 2, 1, 3], [$a, $b, $c, $d]);
        $this->assertSame('BLD-2026-000001', $numaraA);
        $this->assertSame('BLD-2026-000002', $numaraB);
        $this->assertSame('BLD-2027-000001', $numaraC);
    }

    /**
     * Yıl İŞLETME takviminden okunur, UTC'den değil.
     *
     * İkinci kesim 1 Ocak 01:00 (İstanbul) anında yapılıyor; o an UTC'de
     * hâlâ 31 Aralık 22:00'dir. Yıl UTC'den okunsaydı yeni yılın ilk
     * belgesi eski seriye düşerdi ve ocak ayı boyunca iki yıl aynı sırayı
     * paylaşırdı.
     */
    public function test_yil_donumunde_sira_bire_doner(): void
    {
        $eski = $this->makeOrder();
        $yeni = $this->makeOrder();
        $service = app(InvoiceService::class);

        $this->travelTo(Carbon::parse('2026-12-31 12:00:00', BusinessTime::ZONE));
        $this->assertSame('BLD-2026-000001', $service->issueForOrder($eski, 'test')->invoice_no);

        $this->travelTo(Carbon::parse('2027-01-01 01:00:00', BusinessTime::ZONE));
        $ilkYeniYil = $service->issueForOrder($yeni, 'test');

        $this->travelBack();

        $this->assertSame('BLD-2027-000001', $ilkYeniYil->invoice_no);
        $this->assertSame(1, $ilkYeniYil->sequence);
        $this->assertSame(2027, $ilkYeniYil->year);
    }

    // ── Donmuş içerik ───────────────────────────────────────────────────

    /**
     * SİPARİŞ SONRADAN DEĞİŞİNCE BELGE DEĞİŞMEZ.
     *
     * Sipariş düzenleme (K-12) bu sistemde olağan: personel telefonda adet
     * değiştiriyor. Belge canlı tablodan çizilseydi, müşterinin elindeki
     * kâğıt ile panelden yeniden basılan kopya farklı olurdu — ve hangisinin
     * doğru olduğunu kimse söyleyemezdi.
     */
    public function test_snapshot_siparis_sonradan_degisince_degismez(): void
    {
        $order = $this->makeOrder(quantity: 2);
        $invoice = app(InvoiceService::class)->issueForOrder($order, 'Ayşe Yılmaz');

        $oncekiToplam = $invoice->total_kurus;
        $oncekiSatirlar = $invoice->snapshot()['lines'];
        $this->assertNotSame([], $oncekiSatirlar);

        // Sipariş kalemi ve toplamı elle değiştiriliyor (revizyonun bıraktığı
        // ize eşdeğer).
        DB::table('order_menus')
            ->where('order_id', $order->order_id)
            ->update(['name' => 'Değiştirilmiş Ürün', 'quantity' => 99, 'subtotal' => 999.0]);
        DB::table('order_totals')
            ->where('order_id', $order->order_id)
            ->update(['value' => 999.0]);

        $tazelenmis = Invoice::query()->findOrFail($invoice->id);

        $this->assertSame($oncekiToplam, (int) $tazelenmis->total_kurus);
        // `assertEquals`, `assertSame` DEĞİL: MySQL `json` kolonu anahtar
        // SIRASINI korumuyor (nesne anahtarlarını kendi düzeninde
        // saklıyor). Değerler aynı, dizilim farklı — belgenin donmuşluğu
        // değerlerle ilgili, JSON'un iç sırasıyla değil.
        $this->assertEquals($oncekiSatirlar, $tazelenmis->snapshot()['lines']);

        // Çizim de canlı tabloya bakmıyor.
        $html = app(InvoiceService::class)->html($tazelenmis);
        $this->assertStringNotContainsString('Değiştirilmiş Ürün', $html);
        $this->assertStringContainsString('Tavuk Sote', $html);
    }

    // ── Abonelik dönem belgesi ──────────────────────────────────────────

    /**
     * İKİ GÜN ATLANMIŞ DÖNEMDE TESLİM = PLANLANAN − 2.
     *
     * Abone gün atlayabiliyor ve atlanan porsiyon serbest satışa dönüyor;
     * o günün parasını ödememeli. Belge farkı yazıyor: "planlanan 5,
     * teslim edilen 3, atlanan iki gün". Yalnız toplamı yazan bir belge,
     * müşteriyi telefonla bize sordururdu.
     */
    public function test_abonelik_faturasi_atlanan_gunleri_dusum_yapar(): void
    {
        // DÖNEM SABİT VE GELECEKTEN BAĞIMSIZ: fatura hesabı sipariş
        // penceresine hiç bakmıyor, ama sipariş AÇMAK bakıyor. Siparişler
        // güvenli bir servis gününde açılıp üretim defterine dönemin
        // günleriyle bağlanıyor; ölçülen şey defterin toplamı.
        $donem = ['2026-09-07', '2026-09-11']; // Pazartesi → Cuma
        $gunler = ['2026-09-07', '2026-09-08', '2026-09-09', '2026-09-10', '2026-09-11'];

        $subscription = $this->makeSubscription('2026-09-01');

        // Beş günün üçü teslim edildi, ikisi atlandı.
        foreach (array_slice($gunler, 0, 3) as $gun) {
            $this->linkRun($subscription, $gun, (int) $this->makeOrder()->order_id);
        }

        $preview = app(InvoiceService::class)->previewPeriod($subscription, ...$donem);

        $this->assertSame(5, $preview['planned_portions']);
        $this->assertSame(3, $preview['delivered_portions']);
        $this->assertSame(['2026-09-10', '2026-09-11'], $preview['skipped_days']);
        $this->assertSame(3 * self::AGREED_PRICE, $preview['total_kurus']);

        $invoice = app(InvoiceService::class)->issueForPeriod(
            $subscription,
            $donem[0],
            $donem[1],
            paymentId: 41,
            actor: 'Ayşe Yılmaz',
        );

        $this->assertSame(Invoice::TYPE_SUBSCRIPTION, $invoice->type);
        $this->assertSame(3 * self::AGREED_PRICE, (int) $invoice->total_kurus);
        $this->assertSame(41, (int) $invoice->subscription_payment_id);
        $this->assertSame('2026-09-07', $invoice->period_start->toDateString());

        $document = $invoice->snapshot()['document'];
        $this->assertSame(5, $document['planned_portions']);
        $this->assertSame(3, $document['delivered_portions']);
        $this->assertSame(['2026-09-10', '2026-09-11'], $document['skipped_days']);

        $html = app(InvoiceService::class)->html($invoice);
        $this->assertStringContainsString('Teslim edilen porsiyon', $html);
        $this->assertStringContainsString('10.09.2026', $html);
        $this->assertStringContainsString('450,00', $html);
    }

    /** İptal edilmiş sipariş teslim sayılmaz — olmamış bir hizmet. */
    public function test_iptal_edilen_gun_teslim_sayilmaz(): void
    {
        $subscription = $this->makeSubscription('2026-09-01');

        $teslim = (int) $this->makeOrder()->order_id;
        $iptal = (int) $this->makeOrder()->order_id;

        $this->linkRun($subscription, '2026-09-07', $teslim);
        $this->linkRun($subscription, '2026-09-08', $iptal);
        $this->advance($iptal, ['iptal']);

        $preview = app(InvoiceService::class)
            ->previewPeriod($subscription, '2026-09-07', '2026-09-11');

        $this->assertSame(1, $preview['delivered_portions']);
        $this->assertContains('2026-09-08', $preview['skipped_days']);
    }

    // ── Çizim ───────────────────────────────────────────────────────────

    /**
     * Belge A4 kurallarını ve ZORUNLU İBAREYİ taşır.
     *
     * İbare şablondan kaldırılamaz (`docs/control/invoices.md`): mali değeri
     * olmadığı yazmayan bir kâğıt, resmî fatura sanılır.
     *
     * DIŞ BAĞIMLILIK YOK: panel bu sayfayı gizli bir iframe'de açıp
     * `print()` çağırıyor; dışarıdan kaynak çeken bir sayfa ağ yokken boş
     * basardı.
     */
    public function test_belge_a4_kurallarini_ve_zorunlu_ibareyi_tasir(): void
    {
        $invoice = $this->issueOrderInvoice();
        $html = app(InvoiceService::class)->html($invoice);

        $this->assertStringContainsString('@page { size: A4; margin: 15mm; }', $html);
        $this->assertStringContainsString('@media print', $html);
        $this->assertStringContainsString(InvoiceService::NOTICE, $html);
        $this->assertStringContainsString(InvoiceService::NOTICE_EXTRA, $html);
        $this->assertStringContainsString($invoice->invoice_no, $html);

        // Tek dosya: dışarıdan script/stil/görsel çekilmiyor.
        $this->assertStringNotContainsString('<script', $html);
        $this->assertStringNotContainsString('<link', $html);
        $this->assertStringNotContainsString('<img', $html);
        $this->assertStringNotContainsString('http://', $html);
        $this->assertStringNotContainsString('https://', $html);

        // Para TÜRKÇE biçimde: 9000 kuruş → 90,00.
        $this->assertStringContainsString('90,00', $html);
    }

    /**
     * Paket satırının bileşenleri GİRİNTİLİ basılır — şeffaflık.
     *
     * Müşteri "Günün Menüsü ×2"nin içinde ne olduğunu görmeli. Bileşenler
     * sıfır fiyatlı olduğu için toplam şişmez; mutfak yanıtında paket üst
     * satırı elenirken belgede ikisi de durur, çünkü iki yüzün soruları
     * farklı: mutfak "ne pişecek", müşteri "ne aldım" soruyor.
     */
    public function test_paket_bilesenleri_girintili_basilir(): void
    {
        $date = $this->serviceDay();
        $this->publishDay($date, 12000, [['Tavuk Sote', 9000], ['Mercimek Çorbası', 4000]]);

        $orderId = (int) $this->asCustomer()
            ->order($this->packageMenuId(), 2, $date)
            ->assertCreated()
            ->json('id');

        $invoice = app(InvoiceService::class)
            ->issueForOrder(Order::findOrFail($orderId), 'test');

        $roller = array_column($invoice->snapshot()['lines'], 'role');
        $this->assertSame(['package', 'component', 'component'], $roller);

        $html = app(InvoiceService::class)->html($invoice);
        $this->assertStringContainsString('class="bilesen"', $html);
        $this->assertStringContainsString('Mercimek Çorbası', $html);
        // Paket üst satırı parayı taşır; bileşenler sıfır fiyatlı.
        $this->assertSame(24000, (int) $invoice->subtotal_kurus);
    }

    // ── İptal ───────────────────────────────────────────────────────────

    /**
     * İptal: filigran + gerekçe basılır, numara serbest KALMAZ.
     *
     * Temiz basılabilen bir iptal, elindeki kâğıdın geçerli olduğunu sanan
     * bir müşteri üretirdi. Numaranın geri kullanılması ise seride iki
     * farklı belgeye aynı numarayı verirdi.
     */
    public function test_iptal_filigran_basar_ve_numarayi_serbest_birakmaz(): void
    {
        $yil = BusinessTime::now()->year;
        $service = app(InvoiceService::class);

        $invoice = $this->issueOrderInvoice();
        $gerekce = 'Belgede yanlış kurum unvanı vardı, iptal edilip yenisi kesilecek';

        $iptal = $service->void($invoice, $gerekce);

        $this->assertSame(Invoice::STATUS_VOID, $iptal->status);
        $this->assertNotNull($iptal->void_at);
        $this->assertSame($gerekce, $iptal->void_reason);

        $html = $service->html($iptal);
        $this->assertStringContainsString('İPTAL', $html);
        $this->assertStringContainsString($gerekce, $html);
        // İbare iptal edilmiş belgede de duruyor.
        $this->assertStringContainsString(InvoiceService::NOTICE, $html);

        // Numara geri kullanılmıyor: yerine kesilen belge 2 numarayı alır.
        $yenisi = $this->issueOrderInvoice();
        $this->assertSame("BLD-{$yil}-000002", $yenisi->invoice_no);

        // İptal edilmiş belge "siparişin geçerli belgesi" sayılmaz.
        $this->assertNull($service->issuedForOrder((int) $invoice->order_id));
    }

    /** Aynı belge iki kez iptal edilemez. */
    public function test_iptal_edilmis_belge_yeniden_iptal_edilemez(): void
    {
        $service = app(InvoiceService::class);
        $invoice = $service->void($this->issueOrderInvoice(), 'İlk iptal');

        $this->expectExceptionMessage('Belge zaten iptal edilmiş.');
        $service->void($invoice, 'İkinci iptal');
    }

    /** Fiyatsız (`pending`) abonelik için belge kesilmez — sessiz sıfır yok. */
    public function test_fiyatsiz_abonelik_icin_belge_kesilmez(): void
    {
        $subscription = $this->makeSubscription('2026-09-01');
        $subscription->agreed_unit_price_kurus = null;
        $subscription->save();

        $this->expectExceptionMessage('anlaşılan birim fiyatı yok');
        app(InvoiceService::class)->previewPeriod($subscription, '2026-09-07', '2026-09-11');
    }

    // ── Yardımcılar ─────────────────────────────────────────────────────

    private function issueOrderInvoice(): Invoice
    {
        return app(InvoiceService::class)->issueForOrder($this->makeOrder(), 'Ayşe Yılmaz');
    }

    private function makeOrder(int $quantity = 1): Order
    {
        $date = $this->serviceDay();
        $this->publishDay($date, null, [['Tavuk Sote', 9000]]);

        $orderId = (int) $this->asCustomer()
            ->order($this->menuId('Tavuk Sote'), $quantity, $date)
            ->assertCreated()
            ->json('id');

        return Order::findOrFail($orderId);
    }

    private function makeSubscription(string $startDate): Subscription
    {
        $customer = ApiCustomer::query()->where('email', 'test@ornek.com')->first();

        if ($customer === null) {
            $this->postJson('/api/auth/register', $this->registerPayload(), self::HEADERS);
            $customer = ApiCustomer::query()->where('email', 'test@ornek.com')->firstOrFail();
        }

        return Subscription::create([
            'customer_id' => (int) $customer->customer_id,
            'location_id' => $this->locationId(),
            'status' => Subscription::STATUS_ACTIVE,
            'start_date' => $startDate,
            'service_days' => [1, 2, 3, 4, 5],
            'menu_mode' => Subscription::MENU_DAILY,
            'default_quantity' => 1,
            'agreed_unit_price_kurus' => self::AGREED_PRICE,
            'payment_mode' => Subscription::PAYMENT_PREPAID,
        ]);
    }

    /** Üretim defterine bir gün yazar — o gün gerçekten teslim edildi. */
    private function linkRun(Subscription $subscription, string $serviceDate, int $orderId): void
    {
        DB::table('veykemtu_subscription_runs')->insert([
            'subscription_id' => (int) $subscription->id,
            'delivery_point_id' => 0,
            'service_date' => $serviceDate,
            'order_id' => $orderId,
            'created_at' => BusinessTime::forStorage(BusinessTime::now()),
        ]);
    }

    /** Yarından sonraki ilk hafta içi günü. */
    private function serviceDay(): Carbon
    {
        $date = BusinessTime::now()->addDay()->startOfDay();

        while (in_array($date->dayOfWeekIso, [6, 7], true)) {
            $date->addDay();
        }

        return $date;
    }

    private function order(int $menuId, int $quantity, Carbon $date): TestResponse
    {
        return $this->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $menuId, 'quantity' => $quantity]],
            'delivery_type' => 'pickup',
            'payment_method' => 'cash',
            'service_date' => $date->toDateString(),
        ], self::HEADERS);
    }

    private function location(): Location
    {
        return Location::query()->where('location_id', $this->locationId())->firstOrFail();
    }

    private function packageMenuId(): int
    {
        return (int) DailyMenu::packageMenuIdFor($this->locationId());
    }

    /**
     * O güne menü kurar ve yayınlar — aynı gün ikinci kez çağrılırsa
     * mevcut menüyü döndürür (her sipariş kendi gününü yayınlamak
     * zorunda kalmasın).
     *
     * @param  list<array{0:string, 1:int}>  $items  [ürün adı, ürün fiyatı]
     */
    private function publishDay(Carbon $date, ?int $packagePrice, array $items): DailyMenu
    {
        $mevcut = DailyMenu::query()
            ->where('location_id', $this->locationId())
            ->where('menu_date', $date->toDateString())
            ->first();

        if ($mevcut !== null) {
            return $mevcut;
        }

        $menu = DailyMenu::create([
            'location_id' => $this->locationId(),
            'menu_date' => $date->toDateString(),
            'title' => 'Ev Yemeği Menüsü',
            'package_price_kurus' => $packagePrice,
            'status' => DailyMenu::STATUS_PUBLISHED,
            'published_at' => BusinessTime::forStorage(BusinessTime::now()),
        ]);

        foreach ($items as $index => [$name, $price]) {
            $product = Menu::query()->where('menu_name', $name)->firstOrFail();
            $product->menu_price = $price / 100;
            $product->save();

            DailyMenuItem::create([
                'daily_menu_id' => $menu->id,
                'menu_id' => $product->menu_id,
                'quantity' => 1,
                'sort_order' => $index,
            ]);
        }

        return $menu->refresh();
    }
}
