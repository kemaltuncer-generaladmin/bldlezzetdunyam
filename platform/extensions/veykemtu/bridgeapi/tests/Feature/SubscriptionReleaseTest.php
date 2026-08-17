<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Menu;
use Igniter\Cart\Models\Order;
use Igniter\Local\Models\Location;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Models\SubscriptionLine;
use Veykemtu\BridgeApi\Services\LocationGate;
use Veykemtu\BridgeApi\Services\OrderFactory;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Siparişin mutfağa düştüğü an = SERVİS GÜNÜNÜN KESİM ANI.
 *
 * KURAL DEĞİŞTİ (17.08.2026). Eski model `bld_subscription_release_time`
 * (07:00) adında ayrı bir ayar taşıyordu ve yalnız abonelik siparişlerine
 * uygulanıyordu. Ayar KALDIRILDI; karar artık tek kaynaktan,
 * `OrderingWindow::cutoffFor()`'dan geliyor ve kanal ayrımı yok — web, mobil,
 * panel ve gece üretimi aynı yoldan geçiyor.
 *
 * NEDEN KESİM ANI: sipariş alımı kapandığı an mutfak o günün TAM listesini bir
 * kerede görür. Ön siparişler damla damla düşseydi vardiya, sabah baktığı
 * listenin tamamlandığını hiçbir zaman bilemez, arkadan gelen kartı kaçırırdı.
 *
 * BU PAKETİN KİLİTLEDİĞİ DÖRT ŞEY:
 *
 *  1. **İleri tarihli sipariş kesime kadar kapalı.** Yarına verilen sipariş
 *     bugün panoda yok; damga yarının kesim anı.
 *  2. **`since=` kör noktası.** Sipariş kesim anında `updated_at` DEĞİŞMEDEN
 *     görünür hale geliyor. Artımlı yoklama yapan KDS — yani sahadaki tek
 *     KDS — onu `updated_at > since` ile HİÇ göremez. `bld_released_at`
 *     aralığı bu yüzden ayrıca taranıyor ve sipariş **tam bir kez**
 *     yayınlanıyor. Bir kereden az olması siparişin kaybolması, fazla olması
 *     kartın ekranda tekrar tekrar "yeni" diye yanıp sönmesi demek.
 *  3. **Bugün istisna.** Servis günü bugünse damga atılmıyor: satış saatleri
 *     içinde verilen sipariş de, kesimden sonra panelden telefonla girilen
 *     sipariş de anında görünüyor. Geçmiş bir ana damgalanmış sipariş,
 *     imleçle taranan aralığın gerisinde kalıp hiç yayınlanmayabilirdi.
 *  4. **Asimetri bilerek var.** `subscription-orders` ve `subscription-plan`
 *     kapıyı yok sayar: onlar PLANLAMA görünümü ve mutfak yarınki yükü üretim
 *     koştuğu anda, 22:00'de görmelidir.
 *
 * `NULL = SERBEST`: bugüne verilen her sipariş ve göç öncesi her satır
 * damgasızdır. Sabit günler bilerek seçildi — 2026-09-07 pazartesi (üretim
 * gecesi / sipariş günü), 2026-09-08 salı (servis günü).
 */
class SubscriptionReleaseTest extends KitchenTestCase
{
    /** Üretimin koştuğu / ön siparişin verildiği gece. */
    private const string GENERATION_NIGHT = '2026-09-07 22:00';

    /** Servis günü. */
    private const string SERVICE_DAY = '2026-09-08';

    /** Vitrinin genel kesim saati; `veykemtu:setup` bir saat yazmıyor. */
    private const string CUTOFF = '08:00';

    /** Anlaşmalı porsiyon fiyatı (kuruş) — 150,00 TL. */
    private const int AGREED_PRICE = 15000;

    protected function setUp(): void
    {
        parent::setUp();

        $gate = app(LocationGate::class);

        // `veykemtu:setup` asgari sepeti 250,00 TL yazıyor. Bu paket serbest
        // bırakma kapısını sınıyor, asgari tutar kuralını değil.
        $gate->setMinOrderTotal($this->location(), 0);

        // KESİM SAATİ ARTIK KURULUMUN PARÇASI. `bld_order_cutoff` varsayılanı
        // `null` ("kesim saati yok") ve o kurulumda kapı hiç kurulmaz —
        // testlerin ölçtüğü şey tam da kapının kendisi.
        $gate->setOrderCutoff($this->location(), self::CUTOFF);
    }

    protected function tearDown(): void
    {
        // Donmuş saat sızarsa sonraki test paketleri sebepsiz kırılır.
        Carbon::setTestNow();

        parent::tearDown();
    }

    // ── Kapı ────────────────────────────────────────────────────────────

    /**
     * Yarına verilen sipariş BUGÜN panoda yok, damgası yarının kesim anı.
     *
     * Damganın kendisi de doğrulanıyor: kolon boş kalsaydı sipariş zaten
     * görünürdü ve "liste boş" testi başka bir sebeple (mesela yanlış gün)
     * yeşil kalabilirdi.
     */
    public function test_yarina_verilen_siparis_BUGUN_panoda_GORUNMEZ(): void
    {
        $orderId = $this->placePreOrder();

        $this->assertSame(
            $this->storedMoment(self::SERVICE_DAY.' '.self::CUTOFF),
            $this->releasedAt($orderId),
            'Damga servis gününün kesim anına kurulmalı.',
        );

        // Hâlâ sipariş gecesi: pano yalnız bugünü gösterir, sipariş yarına.
        $this->assertSame([], $this->kitchenOrders()->json('data'));

        // Servis günü geldi ama kesim gelmedi.
        $this->freeze(self::SERVICE_DAY.' 07:58');
        $this->assertSame([], $this->kitchenOrders()->json('data'));
    }

    /** Kesim geçince tam yenilemede (imleçsiz) görünür. */
    public function test_kesim_gecince_panoda_GORUNUR(): void
    {
        $orderId = $this->placePreOrder();

        $this->freeze(self::SERVICE_DAY.' 08:01');

        $this->assertSame([$orderId], $this->idsOf($this->kitchenOrders()));
    }

    /**
     * Gece üretilen abonelik siparişi de aynı kapıdan geçer.
     *
     * Kural aboneliğe ÖZEL DEĞİL: `OrderFactory` iki yolda da aynı
     * `releaseAtFor()` metodunu çağırıyor. Bu test o birleşmeyi tutuyor —
     * abonelik yolu kendi saatine geri dönerse burada kırılır.
     */
    public function test_abonelik_siparisi_de_KESIM_ANINDA_duser(): void
    {
        $order = $this->generateSubscriptionOrder();

        $this->assertSame(
            $this->storedMoment(self::SERVICE_DAY.' '.self::CUTOFF),
            $this->releasedAt((int) $order->order_id),
        );

        $this->freeze(self::SERVICE_DAY.' 07:59');
        $this->assertSame([], $this->kitchenOrders()->json('data'));

        $this->freeze(self::SERVICE_DAY.' 08:01');
        $this->assertSame(
            [(int) $order->order_id],
            $this->idsOf($this->kitchenOrders()),
        );
    }

    /**
     * Güne özel kesim saati genel ayarı EZER — damga da onu izler.
     *
     * `OrderingWindow` birleştirme kuralı `gün.cutoff_time ?? ayar.order_cutoff`
     * ve kapı o kuralı yeniden yazmıyor, çağırıyor. Ayrışsalardı mutfak,
     * satışın kapandığı andan başka bir saatte liste alırdı.
     */
    public function test_gune_ozel_kesim_saati_damgayi_BELIRLER(): void
    {
        $this->publishDay(self::SERVICE_DAY, cutoff: '10:30');

        $orderId = $this->placePreOrder();

        $this->assertSame(
            $this->storedMoment(self::SERVICE_DAY.' 10:30'),
            $this->releasedAt($orderId),
        );

        $this->freeze(self::SERVICE_DAY.' 10:29');
        $this->assertSame([], $this->kitchenOrders()->json('data'));

        $this->freeze(self::SERVICE_DAY.' 10:31');
        $this->assertSame([$orderId], $this->idsOf($this->kitchenOrders()));
    }

    /**
     * Kesim saati hiç tanımlı değilse kapı da yoktur.
     *
     * Damga atılsaydı hangi ana atılırdı? "Kesim yok" kurulumunda sipariş
     * sonsuza kadar görünmez kalırdı — kapının şüphede AÇIK kalması gerekiyor.
     */
    public function test_kesim_saati_yoksa_damga_ATILMAZ(): void
    {
        app(LocationGate::class)->setOrderCutoff($this->location(), null);

        $orderId = $this->placePreOrder();

        $this->assertNull($this->releasedAt($orderId));

        // Servis günü gelince gün süzgeci onu zaten getiriyor.
        $this->freeze(self::SERVICE_DAY.' 00:05');
        $this->assertSame([$orderId], $this->idsOf($this->kitchenOrders()));
    }

    // ── `since=` kör noktası ────────────────────────────────────────────

    /**
     * ASIL KİLİT BURADA.
     *
     * Sipariş kesim anında `updated_at` DEĞİŞMEDEN görünür hale geliyor;
     * artımlı yoklama yapan KDS onu `updated_at > since` ile hiç görmez.
     * `07:58` imleciyle yapılan ilk yoklama siparişi getirmeli, imleç
     * ilerledikten sonraki yoklama ise getirmemeli — bir kez, tam bir kez.
     */
    public function test_serbest_birakma_aninda_TAM_BIR_KEZ_yayinlanir(): void
    {
        $orderId = $this->placePreOrder();

        // Sipariş dün gece verildi: `updated_at` imlecin gerisinde ve yayının
        // tek sebebi `bld_released_at` olmalı.
        $this->assertTrue(
            Carbon::parse((string) Order::findOrFail($orderId)->updated_at)
                ->lessThan($this->storedCarbon(self::SERVICE_DAY.' 07:58')),
            'Kurulum bozuk: sipariş imleçten sonra güncellenmiş görünüyor.',
        );

        $this->freeze(self::SERVICE_DAY.' 08:01');

        $first = $this->kitchenOrders(['since' => $this->isoMoment(self::SERVICE_DAY.' 07:58')]);
        $this->assertSame([$orderId], $this->idsOf($first));

        // İSTEMCİNİN GERÇEK DAVRANIŞI: imleç yanıttaki `server_time` olur.
        $cursor = (string) $first->json('server_time');

        $this->freeze(self::SERVICE_DAY.' 08:02');

        $this->assertSame(
            [],
            $this->idsOf($this->kitchenOrders(['since' => $cursor])),
            'İlerletilmiş imleçle sipariş İKİNCİ KEZ yayınlanmamalı.',
        );

        // Yoklama devam ediyor; sipariş bir daha hiç gelmemeli.
        $this->freeze(self::SERVICE_DAY.' 08:03');

        $this->assertSame(
            [],
            $this->idsOf($this->kitchenOrders(['since' => $this->isoMoment(self::SERVICE_DAY.' 08:02')])),
        );
    }

    /**
     * İmleç kesim anından ÖNCEYSE sipariş hâlâ görünmez.
     *
     * Aralık iki uçtan kapalı: `[since, now]`. Üst uç olmasaydı 07:50
     * imleciyle 07:55'te yapılan bir yoklama, henüz açılmamış siparişi
     * getirirdi — kapının hiç olmaması demekti.
     */
    public function test_kesimden_once_yapilan_artimli_yoklama_GETIRMEZ(): void
    {
        $this->placePreOrder();

        $this->freeze(self::SERVICE_DAY.' 07:55');

        $this->assertSame(
            [],
            $this->idsOf($this->kitchenOrders(['since' => $this->isoMoment(self::SERVICE_DAY.' 07:50')])),
        );
    }

    // ── Bugün istisnası: `NULL = serbest` ───────────────────────────────

    /**
     * Bugüne satış saatleri içinde verilen sipariş damgasız doğar.
     *
     * Mutfak zaten o günün içinde çalışıyor; siparişi bugünün kesimine kadar
     * bekletmek, telefonu açan kişinin gördüğü siparişi ekrana getirmemek
     * olurdu.
     */
    public function test_bugune_satis_saatleri_icinde_verilen_siparis_HEMEN_gorunur(): void
    {
        // Kesim 08:00; 07:30'da satış hâlâ açık.
        $this->freeze(self::SERVICE_DAY.' 07:30');

        $orderId = $this->placeWalkInOrder();

        $this->assertNull(
            $this->releasedAt($orderId),
            'Bugünün siparişine serbest bırakma damgası atılmamalı.',
        );

        $this->assertSame([$orderId], $this->idsOf($this->kitchenOrders()));
    }

    /**
     * Kesimden SONRA panelden telefonla girilen bugünkü sipariş de anında.
     *
     * Vitrin kapıları panelde uygulanmıyor (`adminContext`), yani bu sipariş
     * gerçekten doğuyor. Damga "bugün 08:00"a atılsaydı geçmiş bir ana
     * yazılırdı: sipariş, `[since, now]` aralığını tarayan artımlı yoklamanın
     * gerisinde kalır ve hiç yayınlanmayabilirdi.
     */
    public function test_kesimden_sonra_panelden_girilen_bugunki_siparis_HEMEN_gorunur(): void
    {
        $this->freeze(self::SERVICE_DAY.' 11:00');

        $orderId = $this->placePhoneOrder();

        $this->assertNull(
            $this->releasedAt($orderId),
            'Geçmiş bir ana damgalanıp görünmez kalmamalı.',
        );

        $this->assertSame([$orderId], $this->idsOf($this->kitchenOrders()));

        // Artımlı yoklama da görmeli: burada yayının sebebi `updated_at`.
        $this->freeze(self::SERVICE_DAY.' 11:01');
        $this->assertSame(
            [$orderId],
            $this->idsOf($this->kitchenOrders(['since' => $this->isoMoment(self::SERVICE_DAY.' 10:59')])),
        );
    }

    // ── Üretim listesi kapıya UYAR ──────────────────────────────────────

    /**
     * Şerit panoyla aynı gerçeği göstermeli.
     *
     * Ayrışsaydı mutfak, panoda karşılığı olmayan bir yemeği pişirmeye
     * başlardı: ekranda hiç sipariş yokken şeritte "20 Tavuk Sote".
     *
     * SİPARİŞ ÖNCE ONAYLANIYOR: şerit yalnız `onaylandi` + `hazirlaniyor`
     * siparişleri sayıyor, yani `yeni` durumdaki bir sipariş zaten görünmezdi
     * ve test kapıyı değil durum süzgecini doğrulamış olurdu. Sabaha karşı
     * onaylanmış bir abonelik siparişi gerçek bir durum ve kapının tuttuğu
     * tam olarak o.
     */
    public function test_uretim_listesi_kapiya_UYAR(): void
    {
        $order = $this->generateSubscriptionOrder();
        $this->advance((int) $order->order_id, [OrderStatusTransition::CONFIRMED]);

        $this->freeze(self::SERVICE_DAY.' 07:58');
        $this->assertSame([], $this->productionList());

        $this->freeze(self::SERVICE_DAY.' 08:01');
        $totals = collect($this->productionList())->pluck('total', 'name')->all();

        // 20 porsiyon × menüde 1 Tavuk Sote.
        $this->assertSame(20, $totals['Tavuk Sote'] ?? null);
    }

    // ── Planlama görünümü kapıyı BİLEREK yok sayar ──────────────────────

    /**
     * Mutfak yarınki yükü üretim koştuğu anda görmeli.
     *
     * Kapı buraya da konsaydı ekran var oluş sebebini kaybederdi: 22:05'te
     * "yarın abonelik yok" der, mutfak hazırlığa hiç başlamazdı.
     */
    public function test_abonelik_plani_2205_te_yarini_GOSTERIR(): void
    {
        $order = $this->generateSubscriptionOrder();

        $this->freeze('2026-09-07 22:05');

        $days = collect(
            $this->asKitchen()
                ->getJson('/api/kitchen/subscription-plan', self::HEADERS)
                ->assertOk()
                ->json('days'),
        );

        $tomorrow = $days->firstWhere('date', self::SERVICE_DAY);

        $this->assertNotNull($tomorrow, 'Plan yarını içermeli.');
        $this->assertSame(
            [(int) $order->order_id],
            array_column($tomorrow['orders'], 'id'),
        );
        // "Üretim koşmamış" uyarısı da çıkmamalı: sipariş var, yalnız
        // panoya düşmesi bekliyor.
        $this->assertSame([], $tomorrow['warnings']);
    }

    /** `subscription-orders` de planlama görünümüdür; kapıyı yok sayar. */
    public function test_abonelik_siparisleri_ucu_kapiyi_YOK_SAYAR(): void
    {
        $order = $this->generateSubscriptionOrder();

        $this->freeze('2026-09-07 22:05');

        $this->asKitchen()
            ->getJson('/api/kitchen/subscription-orders', self::HEADERS)
            ->assertOk()
            ->assertJsonPath('tomorrow.0.id', (int) $order->order_id);
    }

    // ── Kaldırılan ayar ─────────────────────────────────────────────────

    /**
     * `bld_subscription_release_time` bir daha DOĞMASIN.
     *
     * Erişimci geri gelirse ikinci bir doğru kaynak da geri gelir: kesimi
     * 09:00'a çekip düşme saatini 07:00'de unutan yönetici, mutfağa satış hâlâ
     * açıkken eksik bir listeyi tam diye gösterirdi. `SettingsRepository` ve
     * `SubscriptionController` erişimciyi `method_exists` ile arıyor, yani
     * geri gelen bir metot sessizce devreye girerdi — bu test o sessizliği
     * kırıyor.
     */
    public function test_serbest_birakma_saati_ayari_ARTIK_YOK(): void
    {
        $gate = app(LocationGate::class);

        $this->assertFalse(
            method_exists($gate, 'subscriptionReleaseTime'),
            'Serbest bırakma saati ayarı kaldırıldı; kesim saati tek kaynak.',
        );
        $this->assertFalse(method_exists($gate, 'setSubscriptionReleaseTime'));

        $this->assertSame(
            0,
            DB::table('location_options')
                ->where('item', 'bld_subscription_release_time')
                ->count(),
            'Kaldırılan anahtar hiçbir yoldan yazılmamalı.',
        );
    }

    // ── Yardımcılar ─────────────────────────────────────────────────────

    /** İşletme saatiyle "şimdi"yi dondurur. */
    private function freeze(string $moment): void
    {
        Carbon::setTestNow(Carbon::parse($moment, BusinessTime::ZONE));
    }

    /** İşletme saatini veritabanı biçimine çevirir (`Y-m-d H:i:s`). */
    private function storedMoment(string $moment): string
    {
        return $this->storedCarbon($moment)->format('Y-m-d H:i:s');
    }

    private function storedCarbon(string $moment): Carbon
    {
        return BusinessTime::forStorage(Carbon::parse($moment, BusinessTime::ZONE));
    }

    /** İşletme saatini istemcinin göndereceği biçime çevirir (ISO 8601 UTC). */
    private function isoMoment(string $moment): string
    {
        return Carbon::parse($moment, BusinessTime::ZONE)->utc()->toIso8601ZuluString();
    }

    /**
     * Sipariş gecesinde yarına verilen vitrin ön siparişi; kimliğini döner.
     *
     * Zaman sipariş gecesine donduruluyor ve öyle BIRAKILIYOR: testlerin çoğu
     * "damga geleceğe kuruldu mu" diye soruyor ve cevabı ancak sipariş
     * gerçekten geçmişte doğduysa anlamlı.
     */
    private function placePreOrder(): int
    {
        $this->freeze(self::GENERATION_NIGHT);

        return (int) $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 2]],
            'delivery_type' => Order::COLLECTION,
            'payment_method' => 'cash',
            'service_date' => self::SERVICE_DAY,
        ], self::HEADERS)->assertCreated()->json('id');
    }

    /** Şu an dondurulmuş güne verilen sıradan vitrin siparişi. */
    private function placeWalkInOrder(): int
    {
        return (int) $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 2]],
            'delivery_type' => Order::COLLECTION,
            'payment_method' => 'cash',
        ], self::HEADERS)->assertCreated()->json('id');
    }

    /**
     * Panelden telefonla girilen bugünkü sipariş.
     *
     * `OrderFactory` DOĞRUDAN çağrılıyor: panelin kendi ekranı bu paketin
     * konusu değil ve `adminContext: true` bayrağı — kesim saatini atlatan
     * tek şey — orada da aynı metoda gidiyor.
     */
    private function placePhoneOrder(): int
    {
        $order = app(OrderFactory::class)->create(
            customer: $this->corporateCustomer(),
            location: $this->location(),
            deliveryType: Order::COLLECTION,
            items: [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 2]],
            address: null,
            requestedAt: null,
            paymentMethod: 'cash',
            customerNote: null,
            adminContext: true,
        );

        return (int) $order->order_id;
    }

    /**
     * Gece üretimini koşturup o günün tek abonelik siparişini döner.
     *
     * Zaman üretim gecesine donduruluyor: komut "yarın"ı kendi hesaplasa da
     * damga servis gününe kurulmalı ve testin geri kalanı o damgayı sınıyor.
     */
    private function generateSubscriptionOrder(): Order
    {
        $this->freeze(self::GENERATION_NIGHT);

        $subscription = $this->fixedListSubscription(portions: 20);

        $this->artisan('veykemtu:abonelik-uret', ['--date' => self::SERVICE_DAY])
            ->assertSuccessful();

        return Order::query()
            ->where('bld_subscription_id', $subscription->id)
            ->firstOrFail();
    }

    /**
     * Güne özel kesim saati taşıyan yayınlanmış bir gün.
     *
     * Menü kalemi yazılmıyor: `OrderingWindow::cutoffFor()` yalnız
     * `cutoff_time` kolonunu okuyor ve `bld_daily_menu_enabled` kapalı
     * olduğundan sipariş yolu günün içeriğine hiç bakmıyor.
     */
    private function publishDay(string $date, string $cutoff): void
    {
        DB::table('veykemtu_daily_menus')->insert([
            'location_id' => $this->locationId(),
            'menu_date' => $date,
            'status' => 'published',
            'cutoff_time' => $cutoff,
            'created_at' => BusinessTime::forStorage(BusinessTime::now()),
            'updated_at' => BusinessTime::forStorage(BusinessTime::now()),
        ]);
    }

    /**
     * Sabit listeli abonelik — tek kalem, günün menüsüne bağımlı değil.
     *
     * `fixed_list` bilerek seçildi: bu paket serbest bırakma kapısını
     * sınıyor, menü çözümlemesini değil. `daily_menu` modu her testte bir
     * menü yayınlamayı gerektirir ve arıza yüzeyini büyütürdü.
     */
    private function fixedListSubscription(int $portions): Subscription
    {
        $subscription = new Subscription;
        $subscription->customer_id = $this->corporateCustomer()->customer_id;
        $subscription->location_id = $this->locationId();
        $subscription->status = Subscription::STATUS_ACTIVE;
        $subscription->start_date = '2026-08-01';
        $subscription->end_date = null;
        $subscription->delivery_type = 'pickup';
        $subscription->service_days = [1, 2, 3, 4, 5, 6, 7];
        $subscription->menu_mode = Subscription::MENU_FIXED_LIST;
        $subscription->default_quantity = $portions;
        $subscription->agreed_unit_price_kurus = self::AGREED_PRICE;
        $subscription->payment_mode = Subscription::PAYMENT_PREPAID;
        $subscription->save();

        $line = new SubscriptionLine;
        $line->subscription_id = $subscription->id;
        $line->menu_id = (int) Menu::query()->where('menu_name', 'Tavuk Sote')->firstOrFail()->menu_id;
        $line->quantity = 1;
        $line->label = 'Standart';
        $line->save();

        return $subscription->refresh();
    }

    private function corporateCustomer(): ApiCustomer
    {
        $customer = ApiCustomer::query()->where('email', 'test@ornek.com')->first();

        if ($customer === null) {
            $this->postJson('/api/auth/register', $this->registerPayload(), self::HEADERS);
            $customer = ApiCustomer::query()->where('email', 'test@ornek.com')->firstOrFail();
        }

        // Abonelik yalnız KURUMSAL hesaplarda açılır (`docs/00` B2B kararı).
        $customer->bld_account_type = 'corporate';
        $customer->bld_org_name = 'Test Kurumu';
        $customer->save();

        return $customer;
    }

    /** @param  array<string, string>  $query */
    private function kitchenOrders(array $query = []): TestResponse
    {
        $url = '/api/kitchen/orders'.($query === [] ? '' : '?'.http_build_query($query));

        return $this->asKitchen()->getJson($url, self::HEADERS)->assertOk();
    }

    /** @return list<int> */
    private function idsOf(TestResponse $response): array
    {
        return array_map(intval(...), array_column((array) $response->json('data'), 'id'));
    }

    /** @return list<array{menu_id:int, name:string, total:int}> */
    private function productionList(): array
    {
        return (array) $this->asKitchen()
            ->getJson('/api/kitchen/production-list', self::HEADERS)
            ->assertOk()
            ->json('data');
    }

    /**
     * Damganın HAM veritabanı değeri.
     *
     * Eloquent üzerinden okumak, kolon bir tarih olarak cast edilmediği için
     * sürücüye göre değişen bir tip döndürürdü; testin sorusu "hangi an
     * yazıldı" ve cevabı satırın kendisinde.
     */
    private function releasedAt(int $orderId): ?string
    {
        $value = DB::table('orders')
            ->where('order_id', $orderId)
            ->value('bld_released_at');

        return $value === null ? null : (string) $value;
    }

    private function location(): Location
    {
        return Location::query()->where('location_id', $this->locationId())->firstOrFail();
    }
}
