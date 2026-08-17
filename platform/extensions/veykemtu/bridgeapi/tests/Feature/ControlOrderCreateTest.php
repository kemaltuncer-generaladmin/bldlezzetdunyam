<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Order;
use Igniter\Local\Models\Location;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Models\ControlAudit;
use Veykemtu\BridgeApi\Services\InvoiceService;
use Veykemtu\BridgeApi\Services\LocationGate;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\BridgeApi\Support\Money;

/**
 * `POST /api/control/orders` — telefonla alınan siparişin elle girilmesi.
 *
 * Bu uç, kapatılan admin panelindeki `Admin\PhoneOrders` ekranının yerine
 * geçiyor ve tek istekte ÜÇ geri alınamaz şey yapıyor: müşteri kaydı açıyor,
 * sipariş yaratıyor ve siparişi mutfağa gönderiyor. Testler o üçünü ayrı ayrı
 * çiviliyor, çünkü her birinin sessiz bir arıza biçimi var:
 *
 *  1. **Sipariş `onaylandi` doğar.** `yeni` kalsaydı mutfağa hiç düşmezdi ve
 *     tek belirtisi aç kalan bir müşteri olurdu.
 *  2. **Aynı telefon ikinci müşteriyi açmaz.** Panelden devralınan hâlde bu
 *     arama yoktu; ikinci çağrı tekil e-posta kısıtına çarpardı.
 *  3. **Serbest bırakma tek yerden karar veriliyor.** Bugüne girilen sipariş
 *     kesim geçmiş olsa bile anında düşer; ileri tarihli olan o günün kesim
 *     anına damgalanır. İkisi için ayrı dal yazmak, kesim ayarı
 *     değiştiğinde birinin sessizce ayrışması demekti.
 *  4. **Anlaşmalı sepet tutarı yazılan tutarın ta kendisidir** (7. bölüm).
 *     Personelin telefonda söylediği sayı ile siparişe düşen sayı arasındaki
 *     her sessiz fark — katalogdan hesap, üstüne eklenen teslimat ücreti,
 *     sıfıra düşen boş kutu — ancak müşteri başka bir tutar duyduğunda fark
 *     edilir.
 *
 * Sır ortamdan okunuyor; test için sabitleniyor (`ControlPanelTest` deseni).
 */
class ControlOrderCreateTest extends KitchenTestCase
{
    private const string SECRET = 'test-kontrol-merkezi-sirri';

    private const string ACTOR = 'Ayşe Yönetici';

    private const string PATH = '/api/control/orders';

    /** Vitrinin genel kesim saati; `veykemtu:setup` bir saat yazmıyor. */
    private const string CUTOFF = '08:00';

    /** Kesimden SONRAKİ bir an — bugüne girilen sipariş buradan açılıyor. */
    private const string AFTER_CUTOFF = '2026-09-08 10:00';

    private const string TODAY = '2026-09-08';

    private const string TOMORROW = '2026-09-09';

    protected function setUp(): void
    {
        parent::setUp();

        putenv('BLD_CONTROL_SECRET='.self::SECRET);
        $_ENV['BLD_CONTROL_SECRET'] = self::SECRET;
    }

    protected function tearDown(): void
    {
        // Donmuş saat sızarsa sonraki test paketleri sebepsiz kırılır.
        Carbon::setTestNow();

        parent::tearDown();
    }

    // ── 1. Mutlu yol ──────────────────────────────────────────────────────

    public function test_KAYITLI_MUSTERIYLE_siparis_ONAYLANDI_dogar_ve_mutfaga_duser(): void
    {
        $customer = $this->customer();
        $menuId = $this->menuId('Tavuk Sote');

        $response = $this->signed('POST', self::PATH, [
            'actor' => self::ACTOR,
            'customer_id' => (int) $customer->customer_id,
            'service_date' => BusinessTime::today(),
            'delivery_type' => 'pickup',
            'payment_method' => 'cash',
            'items' => [['menu_id' => $menuId, 'quantity' => 3]],
            'customer_note' => 'Telefonla alındı',
        ])->assertStatus(201);

        $response->assertJsonPath('ok', true)
            ->assertJsonPath('dry_run', false)
            ->assertJsonPath('customer.id', (int) $customer->customer_id)
            ->assertJsonPath('customer.created', false)
            ->assertJsonPath('data.status', OrderStatusTransition::CONFIRMED)
            ->assertJsonPath('warnings', []);

        $orderId = (int) $response->json('data.id');
        $order = Order::findOrFail($orderId);

        $this->assertSame(
            OrderStatusTransition::CONFIRMED,
            resolve(OrderStatusTransition::class)->codeOf($order),
            'Telefon siparişi doğrudan onaylandı doğmalı — yoksa mutfağa düşmez.',
        );

        // FİYAT SUNUCUDA: gövde hiçbir tutar taşımıyor, toplam yine dolu.
        $this->assertGreaterThan(0, (int) $response->json('data.total_kurus'));

        // Sunucu tarafında "fiş basılacak" demenin tek göstergesi, siparişin
        // kasanın yokladığı listede görünmesi.
        $this->assertContains($orderId, $this->kitchenOrderIds());
    }

    // ── 2. Müşteri çözümlemesi ────────────────────────────────────────────

    public function test_YENI_MUSTERI_yer_tutucu_eposta_ile_acilir(): void
    {
        $response = $this->signed('POST', self::PATH, $this->body([
            'customer' => ['name' => 'Acme Gıda', 'phone' => '5321234567'],
        ]))->assertStatus(201);

        $response->assertJsonPath('customer.created', true);

        $customer = ApiCustomer::query()->findOrFail((int) $response->json('customer.id'));

        // `customers.email` çekirdekte zorunlu ve TEKİL; telefonla arayanın
        // e-postası çoğu zaman yok. `invalid.` alan adı RFC 6761 ile ayrıldı.
        $this->assertSame('tel-5321234567@bld.invalid', $customer->email);
        $this->assertSame('5321234567', $customer->telephone);
        $this->assertSame('Acme Gıda', $customer->bld_org_name);
        $this->assertSame('corporate', $customer->bld_account_type);
    }

    public function test_AYNI_TELEFONLA_IKINCI_SIPARIS_ikinci_musteri_yaratmaz(): void
    {
        $before = ApiCustomer::query()->count();

        $first = $this->signed('POST', self::PATH, $this->body([
            'customer' => ['name' => 'Acme Gıda', 'phone' => '5321234567'],
        ]))->assertStatus(201);

        // İKİNCİ ÇAĞRI TELEFONU BAŞKA BİÇİMDE YAZIYOR — personel bir gün
        // sıfırla, ertesi gün sıfırsız yazıyor. Yer tutucu adres ULUSAL
        // biçimden türediği için ikisi aynı kayda düşmeli; ham rakamlar
        // kullanılsaydı ikinci bir müşteri açılırdı.
        $second = $this->signed('POST', self::PATH, $this->body([
            'customer' => ['name' => 'Acme Gıda A.Ş.', 'phone' => '0532 123 45 67'],
        ]))->assertStatus(201);

        // ÜÇÜNCÜ ÇAĞRI ÜLKE KODUYLA. Kırpma uzunluğa bağlı: 12 hanenin
        // başındaki "90" atılıyor, on haneli bir numaranın ilk hanesi değil.
        $third = $this->signed('POST', self::PATH, $this->body([
            'customer' => ['name' => 'Acme', 'phone' => '+90 532 123 45 67'],
        ]))->assertStatus(201);

        $this->assertSame(
            (int) $first->json('customer.id'),
            (int) $second->json('customer.id'),
            'Aynı telefon aynı müşteriye düşmeli.',
        );
        $this->assertSame(
            (int) $first->json('customer.id'),
            (int) $third->json('customer.id'),
            'Ülke kodlu yazım da aynı müşteriye düşmeli.',
        );
        $this->assertFalse($second->json('customer.created'));
        $this->assertFalse($third->json('customer.created'));
        $this->assertSame(
            $before + 1,
            ApiCustomer::query()->count(),
            'Sonraki çağrılar ikinci müşteri yaratmamalı.',
        );

        // İki ayrı sipariş yine de doğdu: tekrarlanmayan şey müşteri kaydı.
        $this->assertNotSame((int) $first->json('data.id'), (int) $second->json('data.id'));
    }

    // ── 3. Serbest bırakma ────────────────────────────────────────────────

    public function test_KESIM_GECMIS_BUGUNE_siparis_ANINDA_mutfakta_gorunur(): void
    {
        $body = $this->body(['service_date' => self::TODAY]);
        $this->withCutoff();
        $this->freeze(self::AFTER_CUTOFF);

        $orderId = (int) $this->signed('POST', self::PATH, $body)
            ->assertStatus(201)
            ->json('data.id');

        // BUGÜNÜN KESİMİ GEÇMİŞ OLSA BİLE DAMGA YOK: mutfak zaten o günün
        // içinde çalışıyor ve siparişi bekletmenin karşılığı yok. Damga
        // konsaydı sipariş sonsuza kadar görünmez kalırdı.
        $this->assertNull(
            $this->releasedAt($orderId),
            'Bugüne girilen sipariş damgasız doğmalı.',
        );

        $this->assertContains($orderId, $this->kitchenOrderIds());
    }

    public function test_ILERI_TARIHLI_siparis_KESIM_ANINA_damgalanir(): void
    {
        $body = $this->body(['service_date' => self::TOMORROW]);
        $this->withCutoff();
        $this->freeze(self::AFTER_CUTOFF);

        $orderId = (int) $this->signed('POST', self::PATH, $body)
            ->assertStatus(201)
            ->json('data.id');

        // Damganın kendisi doğrulanıyor: kolon boş kalsaydı sipariş bugün
        // panoda görünürdü ve "listede yok" testi başka bir sebeple
        // (mesela yanlış gün) yeşil kalabilirdi.
        $this->assertSame(
            $this->storedMoment(self::TOMORROW.' '.self::CUTOFF),
            $this->releasedAt($orderId),
            'İleri tarihli sipariş servis gününün kesim anına damgalanmalı.',
        );

        $this->assertNotContains($orderId, $this->kitchenOrderIds());
    }

    // ── 4. Stok ───────────────────────────────────────────────────────────

    public function test_STOK_TAVANI_ASILABILIR_ve_asim_kayda_gecer(): void
    {
        $menuId = $this->menuId('Tavuk Sote');
        $day = BusinessTime::today();

        $this->setCapacity($menuId, $day, capacity: 2);

        // TAVAN 2, SİPARİŞ 5. Personel "bir porsiyon daha çıkarırız" kararını
        // insan olarak verdi; sistemin onu ikinci kez sorgulaması işi
        // yapılamaz kılardı (`allowOvershoot: true`).
        $this->signed('POST', self::PATH, $this->body([
            'items' => [['menu_id' => $menuId, 'quantity' => 5]],
        ]))->assertStatus(201);

        $row = DB::table('veykemtu_daily_menu_stock')
            ->where('location_id', $this->locationId())
            ->where('service_date', $day)
            ->where('menu_id', $menuId)
            ->first();

        $this->assertNotNull($row);
        // AŞIM KAYDA GEÇİYOR: `sold > capacity`. Kontrol Merkezi bunu
        // gösterebilsin diye satır bastırılmıyor.
        $this->assertSame(5, (int) $row->sold);
        $this->assertSame(2, (int) $row->capacity);
    }

    // ── 5. Doğrulama ──────────────────────────────────────────────────────

    public function test_ACCOUNT_odeme_yontemi_reddedilir(): void
    {
        // `account` cari hesapla birlikte iş modelinden çıktı; kabul edilseydi
        // sipariş tahsilat tarafında karşılıksız kalırdı.
        $this->signed('POST', self::PATH, $this->body(['payment_method' => 'account']))
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED');

        $this->assertSame(0, Order::query()->count());
        $this->assertSame(0, ControlAudit::query()->count());
    }

    public function test_BILINMEYEN_MUSTERI_ve_URUNSUZ_siparis_reddedilir(): void
    {
        $this->signed('POST', self::PATH, $this->body(['customer_id' => 999999]))
            ->assertStatus(422);

        $this->signed('POST', self::PATH, $this->body(['items' => []]))
            ->assertStatus(422);

        // Müşterisiz VE `customer` nesnesiz istek de geçmemeli.
        $body = $this->body();
        unset($body['customer_id']);
        $this->signed('POST', self::PATH, $body)->assertStatus(422);

        $this->assertSame(0, Order::query()->count());
    }

    public function test_TESLIMATTA_ADRES_zorunlu(): void
    {
        $this->signed('POST', self::PATH, $this->body(['delivery_type' => 'delivery']))
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED');

        $this->signed('POST', self::PATH, $this->body([
            'delivery_type' => 'delivery',
            'address' => [
                'line1' => 'Örnek Mah. 12. Sk No:3',
                'district' => 'Selçuklu',
                'city' => 'Konya',
            ],
        ]))->assertStatus(201);
    }

    // ── 6. Kabuk: gerekçe, aktör, kuru prova, denetim ─────────────────────

    public function test_GEREKCE_ZORUNLU_DEGIL_ama_AKTOR_zorunlu(): void
    {
        // GEREKÇE SEYRELDİ, İZ SEYRELMEDİ. Telefon siparişi rutin bir kayıt
        // akışı; personele müşteriyle konuşurken on karakter yazdırmak,
        // sınırın kaçındığı metinleri ("asdasd") üretirdi.
        $this->signed('POST', self::PATH, $this->body())->assertStatus(201);

        $audit = ControlAudit::query()->firstOrFail();
        $this->assertSame('', $audit->reason);

        $body = $this->body();
        unset($body['actor']);

        $this->signed('POST', self::PATH, $body)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED');

        // Aktörsüz istek geçerli bir istek hiç olmadı: ikinci denetim satırı
        // açılmamalı ve ikinci sipariş doğmamalı.
        $this->assertSame(1, ControlAudit::query()->count());
        $this->assertSame(1, Order::query()->count());
    }

    public function test_KURU_PROVA_siparis_yazmaz_ama_denetim_birakir(): void
    {
        $response = $this->signed('POST', self::PATH, $this->body([
            'dry_run' => true,
            'customer' => ['name' => 'Acme Gıda', 'phone' => '5321234567'],
        ]))->assertOk();

        // 201 YALNIZ GERÇEKTEN YAZILDIĞINDA: kuru provada hiçbir satır
        // oluşmadı ve `201 Created` yalan olurdu.
        $response->assertJsonPath('dry_run', true)
            ->assertJsonPath('would.action', 'order.create')
            ->assertJsonPath('would.would_create_customer', true)
            ->assertJsonPath('would.item_count', 1);

        $this->assertSame(0, Order::query()->count());
        $this->assertSame(
            ControlAudit::RESULT_DRY_RUN,
            ControlAudit::query()->firstOrFail()->result,
        );
        $this->assertNull(ControlAudit::query()->firstOrFail()->target_id);
    }

    public function test_DENETIM_SATIRI_acilir_ve_siparis_kimligini_tasir(): void
    {
        $orderId = (int) $this->signed('POST', self::PATH, $this->body())
            ->assertStatus(201)
            ->json('data.id');

        $audit = ControlAudit::query()->firstOrFail();

        $this->assertSame('order.create', $audit->action);
        $this->assertSame(ControlAudit::TARGET_ORDER, $audit->target_type);
        $this->assertSame(ControlAudit::RESULT_APPLIED, $audit->result);
        $this->assertSame(self::ACTOR, $audit->actor);
        // "Kim hangi siparişi açtı" sorusunun cevabı izin kendisinde durmalı;
        // kimlik satır açıldıktan sonra yazılıyor çünkü o an sipariş yoktu.
        $this->assertSame($orderId, (int) $audit->target_id);
    }

    // ── 7. Anlaşmalı sepet tutarı (`agreed_total_kurus`) ──────────────────
    //
    // Personel müşteriyle telefonda bir fiyatta anlaşıyor ve o fiyat sepetin
    // TAMAMI içindir — kalem başına değil. Desen abonelikten geliyor
    // (`agreed_unit_price_kurus` → porsiyon başına): para sepet düzeyinde
    // durur, kalemler fiyatsız yazılır.
    //
    // BU BÖLÜMÜN ÇİVİLEDİĞİ ŞEY, ALANIN VAR OLMA SEBEBİ: personelin söylediği
    // sayı ile siparişe yazılan sayı AYNI olmalı. Aradaki her sessiz fark
    // (katalogdan hesap, üstüne eklenen teslimat ücreti, sıfıra düşen boş kutu)
    // ancak müşteri farklı bir tutar duyduğunda fark edilir.

    /** Telefonda anlaşılan sepet tutarı — 400,00 TL. */
    private const int AGREED_TOTAL = 40000;

    public function test_ANLASMALI_TUTAR_siparise_yazilir_ve_KALEMLER_FIYATSIZ_kalir(): void
    {
        $response = $this->signed('POST', self::PATH, $this->body([
            'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 3]],
            'agreed_total_kurus' => self::AGREED_TOTAL,
        ]))->assertStatus(201);

        $response->assertJsonPath('data.total_kurus', self::AGREED_TOTAL)
            ->assertJsonPath('data.subtotal_kurus', self::AGREED_TOTAL)
            ->assertJsonPath('data.delivery_fee_kurus', 0);

        $orderId = (int) $response->json('data.id');

        $this->assertSame(
            self::AGREED_TOTAL,
            Money::toKurus(Order::findOrFail($orderId)->order_total),
            'orders.order_total anlaşmalı tutarı taşımalı.',
        );

        /*
         * KALEMLER FİYATSIZ. Katalog fiyatı kalsaydı sipariş toplamı satır
         * toplamlarıyla çelişirdi ve çelişki kâğıda basılırdı: fatura
         * satırlarını `order_menus`tan, toplamı `order_totals`tan okuyor.
         */
        $lines = DB::table('order_menus')->where('order_id', $orderId)->get();
        $this->assertNotEmpty($lines);

        foreach ($lines as $line) {
            $this->assertSame(0, Money::toKurus($line->price));
            $this->assertSame(0, Money::toKurus($line->subtotal));
        }

        // ADET DOKUNULMADAN KALIR: mutfak ne pişireceğini buradan okuyor ve
        // ADR-08 gereği fiyatı zaten hiç görmüyor. Sıfırlanan tek şey para.
        $this->assertSame(3, (int) $lines->first()->quantity);

        // Admin paneli ve fatura toplamı `order_totals`tan okuyor; o tablo da
        // aynı sayıyı söylemeli.
        $totals = DB::table('order_totals')->where('order_id', $orderId)
            ->pluck('value', 'code');

        $this->assertSame(self::AGREED_TOTAL, Money::toKurus($totals['subtotal']));
        $this->assertSame(self::AGREED_TOTAL, Money::toKurus($totals['order_total']));
    }

    public function test_ALAN_GONDERILMEZSE_bugunku_davranis_AYNEN_korunur(): void
    {
        // GERİLEME TESTİ. Yeni alanın en pahalı arıza biçimi, hiç
        // kullanılmadığında bir şeyi değiştirmesi olurdu: bugüne kadar açılmış
        // her sipariş katalogdan hesaplanıyor ve öyle kalmalı.
        $orderId = (int) $this->signed('POST', self::PATH, $this->body([
            'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 3]],
        ]))->assertStatus(201)->json('data.id');

        $lines = DB::table('order_menus')->where('order_id', $orderId)->get();
        $lineSum = 0;

        foreach ($lines as $line) {
            $this->assertGreaterThan(
                0,
                Money::toKurus($line->price),
                'Alan yokken kalem fiyatı katalogdan gelmeli.',
            );
            $lineSum += Money::toKurus($line->subtotal);
        }

        $this->assertGreaterThan(0, $lineSum);
        $this->assertSame(
            $lineSum,
            Money::toKurus(Order::findOrFail($orderId)->order_total),
            'Gel-al siparişte toplam, kalem toplamlarının tam kendisi olmalı.',
        );
    }

    public function test_NULL_gonderilmesi_alanin_HIC_GONDERILMEMESIYLE_aynidir(): void
    {
        // Panel kutuyu boş bırakınca `null` gönderebilir. `(int) null` sıfır
        // üretir ve boş bir kutu sessizce "bedava sipariş"e dönerdi.
        $orderId = (int) $this->signed('POST', self::PATH, $this->body([
            'agreed_total_kurus' => null,
        ]))->assertStatus(201)->json('data.id');

        $this->assertGreaterThan(0, Money::toKurus(Order::findOrFail($orderId)->order_total));
    }

    public function test_TESLIMAT_UCRETI_anlasmali_tutara_EKLENMEZ_dahildir(): void
    {
        $fee = 2500;   // 25,00 TL
        resolve(LocationGate::class)->setDeliveryFee($this->location(), $fee);

        $address = [
            'line1' => 'Örnek Mah. 12. Sk No:3',
            'district' => 'Selçuklu',
            'city' => 'Konya',
        ];

        // (1) ALAN YOKKEN ÜCRET EKLENİR — bugünkü davranış, aynen duruyor.
        $plain = $this->signed('POST', self::PATH, $this->body([
            'delivery_type' => 'delivery',
            'address' => $address,
        ]))->assertStatus(201);

        $this->assertSame($fee, (int) $plain->json('data.delivery_fee_kurus'));

        /*
         * (2) ANLAŞMALI TUTAR VARKEN EKLENMEZ. Personel telefonda "400 lira"
         * dedi; sistem 425 yazsaydı alanın önlemek için eklendiği sessiz
         * ayrışma her adrese teslim siparişte geri gelirdi. Teslimatı ayrıca
         * almak isteyen personel 425 yazar — karar geri alınabilir yöndedir.
         */
        $agreed = $this->signed('POST', self::PATH, $this->body([
            'delivery_type' => 'delivery',
            'address' => $address,
            'agreed_total_kurus' => self::AGREED_TOTAL,
        ]))->assertStatus(201);

        $agreed->assertJsonPath('data.total_kurus', self::AGREED_TOTAL)
            ->assertJsonPath('data.delivery_fee_kurus', 0);

        $this->assertFalse(
            DB::table('order_totals')
                ->where('order_id', (int) $agreed->json('data.id'))
                ->where('code', 'delivery')
                ->exists(),
            'Anlaşmalı tutarlı siparişte teslimat satırı hiç yazılmamalı.',
        );
    }

    public function test_ASGARI_SEPET_TUTARI_anlasmali_fiyati_ENGELLEMEZ(): void
    {
        // Asgari 250,00 TL, anlaşma 100,00 TL. `adminContext: true` asgariyi
        // zaten atlıyor; anlaşmalı fiyat da yalnız o bağlamda kabul edildiği
        // için kapıya HİÇ uğramıyor. İkisi yapısal olarak birbirini dışlıyor.
        resolve(LocationGate::class)->setMinOrderTotal($this->location(), 25000);

        $this->signed('POST', self::PATH, $this->body([
            'agreed_total_kurus' => 10000,
        ]))->assertStatus(201)->assertJsonPath('data.total_kurus', 10000);
    }

    public function test_SIFIR_NEGATIF_ve_SAYI_OLMAYAN_tutar_reddedilir(): void
    {
        // SIFIR DA HATA: "bedava" bir sipariş bir fiyat kararı değil, boş
        // bırakılmış bir kutunun sessizce sıfıra düşmesidir.
        foreach ([0, -1, '400,00', 40000.5] as $value) {
            $this->signed('POST', self::PATH, $this->body([
                'agreed_total_kurus' => $value,
            ]))->assertStatus(422)->assertJsonPath('error.code', 'VALIDATION_FAILED');
        }

        $this->assertSame(0, Order::query()->count());
    }

    public function test_ANLASMALI_TUTAR_denetim_izine_yazilir(): void
    {
        $this->signed('POST', self::PATH, $this->body([
            'agreed_total_kurus' => self::AGREED_TOTAL,
        ]))->assertStatus(201);

        $payload = ControlAudit::query()->firstOrFail()->payload_json ?? [];

        // Katalogdan sapan tutar izde durmazsa sapma ancak muhasebede fark
        // edilir ve o noktada "kim söyledi" sorusunun cevabı kalmaz.
        $this->assertSame(self::AGREED_TOTAL, (int) ($payload['agreed_total_kurus'] ?? 0));
    }

    public function test_KURU_PROVA_anlasmali_tutari_yansitir_ama_siparis_yazmaz(): void
    {
        $this->signed('POST', self::PATH, $this->body([
            'dry_run' => true,
            'agreed_total_kurus' => self::AGREED_TOTAL,
        ]))->assertOk()
            ->assertJsonPath('dry_run', true)
            ->assertJsonPath('would.agreed_total_kurus', self::AGREED_TOTAL);

        $this->assertSame(0, Order::query()->count());
    }

    public function test_FATURA_anlasmali_tutari_yazar_satirlar_SIFIR_kalir(): void
    {
        $orderId = (int) $this->signed('POST', self::PATH, $this->body([
            'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 3]],
            'agreed_total_kurus' => self::AGREED_TOTAL,
        ]))->assertStatus(201)->json('data.id');

        $order = Order::findOrFail($orderId);
        $service = app(InvoiceService::class);
        $preview = $service->previewOrder($order);

        /*
         * FATURA BOZULMUYOR ve sebebi yapısal: toplamı `OrderPresenter::totals`
         * veriyor ve o da `order_totals` tablosunu okuyor — satır fiyatlarını
         * DEĞİL. Sıfır fiyatlı kalemler bu yüzden faturayı sıfırlamıyor.
         */
        $this->assertSame(self::AGREED_TOTAL, $preview['subtotal_kurus']);
        $this->assertSame(self::AGREED_TOTAL, $preview['total_kurus']);
        $this->assertSame(0, $preview['delivery_kurus']);

        // Kâğıtta kalemler DÖKÜM olarak durur, para tek satırda — abonelik
        // dönem faturasının bugünkü hâliyle aynı şekil.
        foreach ($preview['lines'] as $line) {
            $this->assertSame(0, (int) $line['unit_price_kurus']);
            $this->assertSame(0, (int) $line['line_total_kurus']);
        }

        $invoice = $service->issueForOrder($order, self::ACTOR);

        $this->assertSame(self::AGREED_TOTAL, (int) $invoice->total_kurus);
        $this->assertSame(0, (int) $invoice->delivery_kurus);
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    /**
     * Geçerli bir gövde; `actor` ve kayıtlı müşteri dâhil.
     *
     * @param  array<string, mixed>  $extra
     * @return array<string, mixed>
     */
    private function body(array $extra = []): array
    {
        $base = [
            'actor' => self::ACTOR,
            'service_date' => BusinessTime::today(),
            'delivery_type' => 'pickup',
            'payment_method' => 'cash',
            'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 2]],
        ];

        // KAYITLI MÜŞTERİ YALNIZ `customer` VERİLMEDİĞİNDE EKLENİYOR. Uç
        // ikisinden birini bekliyor; kimlik de gönderilseydi yeni kayıt hiç
        // açılmaz ve "yeni müşteri" testleri sessizce yanlış şeyi ölçerdi.
        if (!array_key_exists('customer', $extra)) {
            $base['customer_id'] = (int) $this->customer()->customer_id;
        }

        return [...$base, ...$extra];
    }

    private function customer(): ApiCustomer
    {
        $existing = ApiCustomer::query()->where('email', 'test@ornek.com')->first();

        if ($existing instanceof ApiCustomer) {
            return $existing;
        }

        $this->postJson('/api/auth/register', $this->registerPayload(), self::HEADERS)
            ->assertSuccessful();

        return ApiCustomer::query()->where('email', 'test@ornek.com')->firstOrFail();
    }

    /**
     * Vitrine kesim saati yazar.
     *
     * `bld_order_cutoff` varsayılanı `null` ("kesim saati yok") ve o kurulumda
     * kapı hiç kurulmaz — serbest bırakma testlerinin ölçtüğü şey tam da
     * kapının kendisi.
     */
    private function withCutoff(): void
    {
        resolve(LocationGate::class)->setOrderCutoff($this->location(), self::CUTOFF);
    }

    private function freeze(string $moment): void
    {
        Carbon::setTestNow(Carbon::parse($moment, BusinessTime::ZONE));
    }

    /** İşletme saatini veritabanı biçimine çevirir (`Y-m-d H:i:s`). */
    private function storedMoment(string $moment): string
    {
        return BusinessTime::forStorage(Carbon::parse($moment, BusinessTime::ZONE))
            ->format('Y-m-d H:i:s');
    }

    private function releasedAt(int $orderId): ?string
    {
        $value = DB::table('orders')->where('order_id', $orderId)->value('bld_released_at');

        return $value === null ? null : (string) $value;
    }

    /** @return list<int> */
    private function kitchenOrderIds(): array
    {
        return array_map(intval(...), array_column(
            (array) $this->asKitchen()->getJson('/api/kitchen/orders', self::HEADERS)
                ->assertOk()
                ->json('data'),
            'id',
        ));
    }

    private function setCapacity(int $menuId, string $day, int $capacity): void
    {
        DB::table('veykemtu_daily_menu_stock')->insert([
            'location_id' => $this->locationId(),
            'service_date' => $day,
            'menu_id' => $menuId,
            'capacity' => $capacity,
            'reserved' => 0,
            'sold' => 0,
            'updated_by' => 'test',
            'created_at' => BusinessTime::forStorage(BusinessTime::now()),
            'updated_at' => BusinessTime::forStorage(BusinessTime::now()),
        ]);
    }

    private function location(): Location
    {
        return Location::query()->where('location_id', $this->locationId())->firstOrFail();
    }

    /**
     * İmzalı istek — `ControlPanelTest::signed()` ile aynı kanonik dize.
     *
     * @param  array<string, mixed>|string|null  $body
     */
    private function signed(
        string $method,
        string $path,
        array|string|null $body = null,
    ): TestResponse {
        $raw = is_array($body) ? (string) json_encode($body, JSON_UNESCAPED_UNICODE) : (string) ($body ?? '');
        // İmza penceresi `time()` okuyor, `Carbon::now()` değil: donmuş saat
        // imzayı bozmuyor (`VerifyControlSignature`).
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
}
