<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Igniter\Cart\Models\Menu;
use Igniter\Cart\Models\Order;
use Igniter\Local\Models\Location;
use Igniter\User\Models\Address;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Models\SubscriptionDeliveryPoint;
use Veykemtu\BridgeApi\Support\Money;

/**
 * Sipariş oluşturma — `docs/openapi.yaml` `createOrder`.
 *
 * **Tutar sunucuda hesaplanır.** İstemcinin gönderdiği hiçbir fiyat alanı
 * okunmaz; sözleşmede böyle bir alan da yoktur (`docs/10-test-kabul.md` S6
 * adım 5). İstemcinin gösterdiği tutarla sunucunun hesabı ayrışırsa doğru
 * olan sunucununkidir.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * TEK İSTİSNA — ANLAŞMALI SEPET TUTARI (`$agreedTotalKurus`)
 *
 * Yukarıdaki kural MÜŞTERİNİN kendi kendine sipariş vermesi içindir ve orada
 * hiç gevşemez: `adminContext: false` iken fiyat alanı gönderilirse metot
 * PATLAR (aşağıdaki kapı). Panelden telefonla girilen siparişte ise fiyatı
 * belirleyen sunucu değil, müşteriyle telefonda pazarlık eden insandır —
 * personel "size 400 lira" der ve sistemin katalogdan 480 yazması tam olarak
 * "istemcinin gösterdiği tutarla sunucunun hesabı ayrıştı" hâlinin kendisi
 * olurdu, sadece ters yönde.
 *
 * DESEN ABONELİKTEN GELİYOR ve birebir aynıdır (`createForSubscription`):
 * para SEPET DÜZEYİNDE durur, kalemler `unit_price => 0, line_total => 0`
 * yazılır. Kalemlerde de fiyat bırakmak, sipariş toplamı ile satır
 * toplamlarının çeliştiği bir kayıt üretirdi; faturayı da mutfak ekranını da
 * besleyen tablolar bunlar ve ikisi birbirini tutmalı.
 * ─────────────────────────────────────────────────────────────────────────
 *
 * Tüm yazma işi tek transaction içindedir: yarım kalmış bir sipariş
 * (kalemleri olmayan başlık, toplamı olmayan kalem) mutfağa düşer ve
 * telafisi elle olur.
 */
class OrderFactory
{
    public function __construct(
        private readonly LocationGate $gate,
        private readonly OrderStatusTransition $transitions,
        private readonly LineResolver $lines,
        private readonly DailyMenuService $dailyMenus,
        private readonly OrderingWindow $window,
        private readonly DailyStock $stock,
    ) {}

    /**
     * @param  array<int, array{menu_id:int, quantity:int, option_value_ids?:list<int>, note?:string|null}>  $items
     * @param  bool  $adminContext  Panelden telefonla giriliyorsa `true` (B-13).
     * @param  string|null  $serviceDate  Siparişin hangi gün için olduğu,
     *   `YYYY-AA-GG` (B-19). Verilmezse `requested_at`'in işletme günü, o da
     *   yoksa bugün.
     * @param  int|null  $agreedTotalKurus  Müşteriye telefonda söylenen
     *   ANLAŞMALI SEPET TUTARI, kuruş. Verilirse kalem toplamının yerine geçer
     *   ve kalemler fiyatsız yazılır (sınıf docblock'u). YALNIZ
     *   `$adminContext === true` iken kabul edilir.
     */
    public function create(
        ApiCustomer $customer,
        Location $location,
        string $deliveryType,
        array $items,
        ?array $address,
        ?Carbon $requestedAt,
        string $paymentMethod,
        ?string $customerNote,
        bool $adminContext = false,
        ?int $subscriptionId = null,
        ?string $serviceDate = null,
        ?int $agreedTotalKurus = null,
    ): Order {
        /*
         * FİYAT KAPISI EN BAŞTA — HİÇBİR İŞ YAPILMADAN ÖNCE.
         *
         * Vitrin yolunda (`adminContext: false`) istemciden gelen bir tutarı
         * kabul etmek, müşterinin kendi siparişinin fiyatını yazması demekti.
         * Uç bugün bu alanı yalnız panel yolunda tanıyor; kapı yine de burada
         * duruyor çünkü sözleşmeyi koruyan yer metodun kendisi olmalı — ileride
         * açılacak ikinci bir çağıran, uçtaki doğrulamayı görmeden bu metodu
         * çağırabilir.
         */
        if ($agreedTotalKurus !== null && !$adminContext) {
            throw ApiException::validationFailed(
                'Anlaşmalı sepet tutarı yalnız panelden girilen siparişte kabul edilir.',
                ['agreed_total_kurus' => 'Vitrin siparişinde fiyat sunucuda hesaplanır.'],
            );
        }

        if ($agreedTotalKurus !== null && $agreedTotalKurus < 1) {
            // SIFIR DA REDDEDİLİR: "bedava" bir sipariş bir fiyat kararı değil,
            // boş bırakılmış bir kutunun sessizce sıfıra düşmesidir. Gerçekten
            // ikram edilen sipariş bugün de sistemde yok; olacaksa ayrı ve
            // görünür bir karardır.
            throw ApiException::validationFailed(
                'Anlaşmalı sepet tutarı sıfırdan büyük olmalı.',
                ['agreed_total_kurus' => (string) $agreedTotalKurus],
            );
        }

        /*
         * SERVİS GÜNÜ EN BAŞTA ÇÖZÜLÜYOR (S1).
         *
         * Eskiden yalnız `bld_daily_menu_enabled` açıkken çözülüyordu; artık
         * sipariş penceresi menü rejiminden bağımsız uygulandığı için gün her
         * yolda gerekli. Tek yerde çözülmesi, aşağıdaki üç kullanımın
         * (pencere, menü, `bld_service_date`) aynı günü görmesinin garantisi.
         */
        $date = $this->dailyMenus->resolveServiceDate($serviceDate, $requestedAt);

        /*
         * VİTRİN KAPILARI PANELDE UYGULANMAZ (B-13).
         *
         * İki kapı var: sipariş alım şalteri (`assertAcceptsOrder`) ve
         * sipariş penceresi (`assertWithinWindow` — geçmiş gün, ileri görüş
         * penceresi, o günün kesim saati). İkisi de MÜŞTERİNİN kendi kendine
         * sipariş vermesini düzenler. Telefonla arayan müşteriye "sipariş
         * alımı kapalı" demek, siparişi zaten kabul etmiş olan yöneticiye
         * kendi sistemini kullandırmamak olurdu — o kararı insan verdi.
         *
         * Asgari sepet tutarı da aynı sebeple atlanıyor: yönetici 200 TL'lik
         * asgariyi bilerek esnetebilir, sistem onu engellemez.
         *
         * ATLANMAYAN — ve neden: ödeme yöntemi. Vitrinde tanımlı olmayan bir
         * yöntemle sipariş, tahsilat tarafında karşılıksız kalır.
         */
        if (!$adminContext) {
            $this->gate->assertAcceptsOrder($location);

            /*
             * PENCERE KOŞULSUZ UYGULANIR — `bld_daily_menu_enabled`
             * KAPALIYKEN DE (S1).
             *
             * DOĞRULANMIŞ AÇIK: şalter kapalıyken aşağıdaki blok hiç
             * koşmuyor, yani `assertOrderable()` da hiç çağrılmıyordu. Kesim
             * denetimi `LocationGate`'ten çıkınca, şalter kapalı bir
             * kurulumda HİÇ KESİM KALMAZDI: gece 03:00'te bugüne sipariş
             * girer, mutfak sabah pişiremeyeceği bir siparişle uyanırdı.
             * Pencere bu yüzden menü rejiminin dışında, siparişin kendi
             * kapısı olarak duruyor.
             */
            $this->window->assertWithinWindow($location, $date);
        }

        $this->gate->assertPaymentMethodAllowed($location, $paymentMethod);

        /*
         * O GÜNÜN MENÜSÜ (B-19).
         *
         * Menü kapıları (yayınlanmış menü var mı, kapalı gün mü) vitrin
         * kapılarıyla aynı yerde: `$adminContext` onları da atlıyor. Gerekçe
         * yukarıdakinin aynısı — telefonu açan yönetici istisnayı insan
         * olarak veriyor. Menü yine de çözülüyor: paket satırının fiyatı
         * ondan geliyor.
         */
        $day = null;

        if ($this->gate->dailyMenuEnabled($location)) {
            $day = $adminContext
                ? $this->dailyMenus->publishedFor($location, $date)
                : $this->dailyMenus->assertOrderable($location, $date);
        }

        $lines = $this->lines->resolve(
            $items,
            enforceAvailability: true,
            day: $day,
            enforceMembership: !$adminContext,
        );
        $subtotal = array_sum(array_column($lines, 'line_total'));

        if ($agreedTotalKurus !== null) {
            /*
             * ANLAŞMALI TUTAR KALEM TOPLAMININ YERİNE GEÇER.
             *
             * Sıra önemli: `assertMeetsMinimum` AŞAĞIDA ve yalnız
             * `!$adminContext` iken koşuyor; anlaşmalı fiyat ise yalnız
             * `$adminContext` iken kabul ediliyor (yukarıdaki kapı). İkisi
             * yapısal olarak birbirini dışlıyor — yani 400 liralık asgariyi
             * 300 liraya kıran bir anlaşma o kapıya HİÇ uğramıyor. Bu bir
             * tesadüf değil, aynı gerekçenin iki yüzü: telefonu açan yönetici
             * asgariyi de fiyatı da bilerek esnetiyor.
             */
            $subtotal = $agreedTotalKurus;
            // Kalemler fiyatsız yazılır; para sepet düzeyinde durur. Aynı
            // desen `createForSubscription()` içinde.
            $lines = self::withoutLinePrices($lines);
        }

        if (!$adminContext) {
            $this->gate->assertMeetsMinimum($location, $subtotal);
        }

        /*
         * TESLİMAT ÜCRETİ ANLAŞMALI TUTARA EKLENMEZ — DÂHİLDİR.
         *
         * Abonelik de böyle yapıyor (`createForSubscription`: `order_total =
         * Money::toDecimal($subtotal)`, `rewriteTotals(..., 0)`) ve iki
         * "anlaşmalı fiyat" kavramının teslimatta farklı davranması ikinci bir
         * doğru kaynak üretirdi.
         *
         * ASIL GEREKÇE BU ALANIN VAR OLMA SEBEBİ: personel telefonda bir sayı
         * söylüyor ve sistemin yazdığı tutar o sayı olmalı. Üstüne 25 lira
         * teslimat eklemek, alanın önlemek için eklendiği sessiz ayrışmayı —
         * "personel bir fiyat söyler, sistem başka tutar yazar" — geri getirir,
         * üstelik her adrese teslim siparişte.
         *
         * KARAR GERİ ALINABİLİR YÖNDEDİR: teslimatı ayrıca almak isteyen
         * personel ücreti anlaşmalı tutara ekleyip yazar (400 yerine 425).
         * Tersi ekranda mümkün değil — eklenen bir ücreti negatif sayı yazarak
         * geri almanın yolu yok.
         *
         * ALAN BOŞKEN BUGÜNKÜ DAVRANIŞ AYNEN KORUNUR: ücret hesaplanır ve
         * eklenir.
         */
        $deliveryFee = ($deliveryType === Order::DELIVERY && $agreedTotalKurus === null)
            ? $this->gate->deliveryFee($location)
            : 0;

        /*
         * SERVİS GÜNÜ — `orders.bld_service_date`.
         *
         * DEĞİŞMEZ KURAL: `bld_service_date === DATE(order_date)`. İki
         * kolonun ayrışmaması, `order_date` üzerinden filtreleyen her mevcut
         * sorgunun (mutfak panosu, üretim listesi, abonelik planı) hiç
         * değişmeden doğru kalmasının tek şartı.
         */
        $serviceDay = $day?->menu_date->copy()->startOfDay() ?? $date;
        // Mutfak kapısı — kanal farkı yok, karar yalnız servis gününe bakar.
        $releaseAt = $this->releaseAtFor($location, $serviceDay);

        return DB::transaction(function () use (
            $customer, $location, $deliveryType, $lines, $address,
            $requestedAt, $paymentMethod, $customerNote, $subtotal, $deliveryFee,
            $subscriptionId, $serviceDay, $adminContext, $releaseAt,
        ): Order {
            $addressId = $deliveryType === Order::DELIVERY
                ? $this->storeAddress($customer, $address)
                : null;

            $requestedLocal = $requestedAt?->copy()->setTimezone(BusinessTime::ZONE);
            $now = BusinessTime::now();

            /*
             * Saat: istenen zaman verildiyse o. Verilmediyse ve servis günü
             * bugünse "şimdi" (bugünkü davranış aynen korunuyor). Verilmediyse
             * ve gün ileriyse öğlen — ileri tarihli bir siparişte "şimdi"nin
             * saatini yazmak, gece 23:40'ta verilen bir cuma siparişini
             * cuma 23:40'a çekerdi. 12:00 abonelik üretiminin de varsayılanı.
             */
            $when = $requestedLocal
                ?? ($serviceDay->isSameDay($now)
                    ? $now
                    : $serviceDay->copy()->setTime(12, 0));

            $order = new Order;
            $order->customer_id = $customer->customer_id;
            $order->first_name = $customer->first_name;
            $order->last_name = $customer->last_name;
            $order->email = $customer->email;
            $order->telephone = $customer->telephone;
            $order->location_id = $location->location_id;
            $order->address_id = $addressId;
            $order->order_type = $deliveryType;
            $order->order_date = $serviceDay->toDateString();
            $order->order_time = $when->format('H:i:s');
            $order->bld_service_date = $serviceDay->toDateString();
            // İleri tarihli sipariş asla "en kısa sürede" değildir.
            $order->order_time_is_asap = $requestedAt === null
                && $serviceDay->isSameDay($now);
            $order->total_items = array_sum(array_column($lines, 'quantity'));
            $order->order_total = Money::toDecimal($subtotal + $deliveryFee);
            $order->payment = $paymentMethod;
            $order->comment = $customerNote;
            // `cart` çekirdeğin sepet serileştirmesi içindir; API siparişinde
            // sepet nesnesi yoktur, boş dizi yazıyoruz (kolon NOT NULL).
            $order->cart = serialize([]);
            // Panelden bir aboneliğe bağlanan sipariş (B-13). Mutfak, abonelik
            // üretim planında bu siparişi de görsün diye işaretleniyor; gece
            // üretimiyle aynı alan kullanılıyor ki KDS iki ayrı kaynak
            // ayırt etmek zorunda kalmasın.
            $order->bld_subscription_id = $subscriptionId;
            // İleri tarihli sipariş servis gününün kesimine kadar bekler;
            // bugüne verilen sipariş damgasız doğar (`releaseAtFor()`).
            $order->bld_released_at = $releaseAt;
            $order->status_id = $this->transitions->statusByCode(
                OrderStatusTransition::NEW,
            )->status_id;
            $order->save();

            $this->lines->writeLines($order, $lines);
            $this->lines->rewriteTotals($order, $subtotal, $deliveryFee);

            /*
             * STOK DÜŞÜMÜ — İŞLEMİN İÇİNDE, SATIRLAR YAZILDIKTAN SONRA (S2).
             *
             * İŞLEMİN İÇİNDE OLMASI TAM İSTENEN: tavan yetmezse
             * `DailyStock::take()` `ITEM_UNAVAILABLE` fırlatır ve
             * `DB::transaction` siparişin TAMAMINI geri alır. Dışarıda
             * yapılsaydı, stoku olmayan bir sipariş kaydı doğar ve mutfağa
             * düşerdi; telafisi elle olurdu.
             *
             * SON ADIM OLMASI DA ÖNEMLİ: düşüm satırı InnoDB'de işlem
             * sonuna kadar kilitli kalıyor. Ne kadar geç kilitlenirse yoğun
             * saatte o kadar az bekleyen olur.
             *
             * `allowOvershoot: $adminContext` — panelden telefonla girilen
             * siparişte tavan denetlenmiyor. Bu metotta zaten kesim saati,
             * asgari tutar ve menü üyeliği aynı gerekçeyle atlanıyor:
             * telefonu açan yönetici "bir porsiyon daha çıkarırız" kararını
             * insan olarak verdi ve sistemin onu ikinci kez sorgulaması işi
             * yapılamaz kılardı. Aşım kayda geçiyor (`sold > capacity`) ve
             * Kontrol Merkezi'nde görünür.
             */
            $this->stock->take(
                (int) $location->location_id,
                $serviceDay,
                $this->lines->stockDemand($lines),
                allowOvershoot: $adminContext,
            );

            // Durum geçmişinin ilk satırı burada doğar; çekirdeğin metodu
            // status_history'yi ve bildirimleri yönetir.
            $order->updateOrderStatus($order->status_id, ['notify' => false]);

            return $order->refresh();
        });
    }

    /**
     * Satır fiyatlarını sıfırlar — para SEPET DÜZEYİNDE durur.
     *
     * Anlaşmalı tutarlı siparişte kalemler `unit_price => 0, line_total => 0`
     * yazılır; `createForSubscription()` yolundaki desenin aynısı. Kalemlerde
     * katalog fiyatı bırakmak, `order_totals.order_total` ile `order_menus`
     * satırlarının toplamının ÇELİŞTİĞİ bir kayıt üretirdi ve o çelişki
     * kâğıda basılırdı: fatura satırları `order_menus`'tan, toplamı
     * `order_totals`'tan okuyor (`InvoiceService::orderLines` ·
     * `OrderPresenter::totals`).
     *
     * SEÇENEK FARKLARI DA SIFIRLANIR. `writeLines()` her seçeneği
     * `order_menu_options.order_option_price` olarak yazıyor; satır sıfırken
     * seçeneğin fiyatlı kalması "ekstra peynir 15 ₺" yazan ama satır toplamı
     * 0 olan bir kalem demekti. Fiyatın tek yeri sepet toplamıdır.
     *
     * ÜRÜN ADI, ADET, NOT, SEÇENEK ADI VE BİLEŞEN YAPISI DOKUNULMADAN KALIR:
     * mutfak ne pişireceğini bunlardan okuyor ve ADR-08 gereği fiyatı zaten
     * hiç görmüyor. Sıfırlanan tek şey paradır.
     *
     * @param  list<array<string, mixed>>  $lines
     * @return list<array<string, mixed>>
     */
    private static function withoutLinePrices(array $lines): array
    {
        $zeroed = [];

        foreach ($lines as $line) {
            $line['unit_price'] = 0;
            $line['line_total'] = 0;

            if (isset($line['options']) && is_array($line['options'])) {
                $line['options'] = array_map(
                    static function (array $option): array {
                        $option['price_delta'] = 0;

                        return $option;
                    },
                    $line['options'],
                );
            }

            // Menü paketinin bileşenleri zaten sıfır fiyatlı doğuyor; yine de
            // aynı süzgeçten geçiyorlar ki "fiyatsız satır" garantisi satır
            // türüne bağlı kalmasın.
            if (isset($line['components']) && is_array($line['components'])) {
                $line['components'] = self::withoutLinePrices($line['components']);
            }

            $zeroed[] = $line;
        }

        return $zeroed;
    }

    /**
     * Abonelikten o günün siparişini üretir.
     *
     * Müşteri `create()` yolundan AYRI metot: vitrin kapıları (satış şalteri,
     * asgari tutar) ve sipariş penceresi (kesim saati, ileri görüş penceresi)
     * UYGULANMAZ — bu bir sözleşme siparişidir,
     * vitrin siparişi değil. Fiyat menü LİSTE fiyatından değil, aboneliğin
     * ANLAŞMALI fiyatından gelir ve o günkü değeriyle siparişe KOPYALANIR;
     * sonraki menü zammı üretilmiş siparişi bozmaz.
     *
     * `menu_mode = daily_menu` aboneliğinde satırlar o günün yayınlanmış
     * menüsünden gelir; menü yoksa metot PATLAR ve çağıran
     * (`SubscriptionGenerateCommand`) hatayı sayar — böylece menü
     * yayınlandıktan sonra komut yeniden koşturulduğunda sipariş doğar.
     *
     * SİPARİŞ MUTFAĞA HEMEN DÜŞMEZ: `bld_released_at` damgası servis gününün
     * KESİM ANINA kurulur. Kural aboneliğe özel değil — `create()` de aynı
     * `releaseAtFor()` metodunu çağırıyor. Gece 22:00'de üretilen yarının
     * siparişi bu yüzden yarın sabah, satış kapandığı anda düşer.
     */
    public function createForSubscription(
        Subscription $subscription,
        ?SubscriptionDeliveryPoint $point,
        Carbon $serviceDate,
    ): Order {
        $lines = $this->resolveSubscriptionLines($subscription, $serviceDate);
        $releaseAt = $this->subscriptionReleaseAt($subscription, $serviceDate);
        // Fiyat porsiyon başınadır: toplam = porsiyon × anlaşmalı porsiyon
        // fiyatı (yemekler bileşen olduğundan satır fiyatları 0'dır).
        $subtotal = max(1, $subscription->quantityForDate($serviceDate))
            * (int) $subscription->agreed_unit_price_kurus;

        $deliveryType = $subscription->delivery_type === 'delivery'
            ? Order::DELIVERY
            : Order::COLLECTION;
        // Anlaşmalı fiyat teslimatı kapsar; abonelik siparişinde ekstra
        // teslimat ücreti alınmaz.
        //
        // ÖDEME YÖNTEMİ SABİT `cash`: cari hesap kaldırıldıktan sonra tek
        // abonelik ödeme modu peşin aylık (`prepaid_monthly`) ve o para
        // sipariş başına değil, sözleşme üzerinden tahsil ediliyor. Sipariş
        // yine de bir ödeme koduna İHTİYAÇ DUYUYOR (`orders.payment` →
        // `payments.code`); `online` yazmak, hiç yapılmamış bir sanal POS
        // tahsilatını ima ederdi.
        $paymentMethod = 'cash';

        return DB::transaction(function () use (
            $subscription, $point, $serviceDate, $lines, $subtotal, $deliveryType,
            $paymentMethod, $releaseAt,
        ): Order {
            /** @var ApiCustomer $customer */
            $customer = $subscription->customer;

            $addressId = ($deliveryType === Order::DELIVERY && $point !== null)
                ? $this->copyPointAddress($subscription, $point)
                : null;

            $time = $subscription->delivery_time_from !== null
                ? substr((string) $subscription->delivery_time_from, 0, 8)
                : '12:00:00';

            $order = new Order;
            $order->customer_id = $customer->customer_id;
            $order->first_name = $customer->first_name;
            $order->last_name = $customer->last_name;
            $order->email = $customer->email;
            $order->telephone = $customer->telephone;
            $order->location_id = $subscription->location_id;
            $order->address_id = $addressId;
            $order->order_type = $deliveryType;
            $order->order_date = $serviceDate->toDateString();
            $order->order_time = $time;
            // `bld_service_date === DATE(order_date)` değişmezi burada da
            // geçerli (B-19). Abonelik zaten servis gününe yazıyordu.
            $order->bld_service_date = $serviceDate->toDateString();
            $order->order_time_is_asap = false;
            $order->total_items = array_sum(array_column($lines, 'quantity'));
            $order->order_total = Money::toDecimal($subtotal);
            $order->payment = $paymentMethod;
            $order->comment = $point?->note;
            $order->cart = serialize([]);
            $order->bld_subscription_id = $subscription->id;
            // Mutfak kapısı. `null` bırakılsaydı gece 22:00'de üretilen kırk
            // kart sabah 05:00'te panoyu doldururdu.
            $order->bld_released_at = $releaseAt;
            $order->status_id = $this->transitions->statusByCode(
                OrderStatusTransition::NEW,
            )->status_id;
            $order->save();

            $this->lines->writeLines($order, $lines);
            $this->lines->rewriteTotals($order, $subtotal, 0);
            $order->updateOrderStatus($order->status_id, ['notify' => false]);

            return $order->refresh();
        });
    }

    /**
     * Abonelik siparişinin vitrinini bulup kapıyı `releaseAtFor()`'a sorar.
     *
     * Vitrin bulunamazsa ANINDA SERBEST (`null`): sipariş üretimini bir
     * kayıt okumasının başarısızlığı yüzünden durdurmak ya da siparişi
     * süresiz görünmez bırakmak, gecikmeli düşmenin çözdüğü sorundan çok
     * daha pahalı olurdu. Kapının şüpheye düştüğü yerde AÇIK kalması,
     * `NULL = SERBEST` değişmeziyle de aynı yönde.
     */
    private function subscriptionReleaseAt(Subscription $subscription, Carbon $serviceDate): ?Carbon
    {
        $location = Location::query()
            ->where('location_id', $subscription->location_id)
            ->first();

        return $location !== null
            ? $this->releaseAtFor($location, $serviceDate)
            : null;
    }

    /**
     * Siparişin mutfağa açılacağı an; `null` = ANINDA serbest.
     *
     * TEK KURAL, HER KANALA AYNI — web, mobil, panel ve gece üretimi bu
     * metottan geçiyor (iş kararı güncellendi, 17.08.2026). Eski
     * model `bld_subscription_release_time` (07:00) adında İKİNCİ bir ayar
     * taşıyordu ve yalnız aboneliğe uygulanıyordu. Kesim saati zaten "o günün
     * satışı kapandı" anını tanımlıyor; ikinci bir ayar iki doğru kaynak
     * demekti ve biri değiştiğinde diğeri sessizce ayrışırdı. Anahtar
     * KALDIRILDI, karar `OrderingWindow::cutoffFor()`'a bağlandı.
     *
     * NEDEN KESİM ANI: sipariş alımı kapandığı an mutfak o günün TAM
     * listesini bir kerede görür. Arkadan sipariş damlamaz, gözden kaçan
     * olmaz — ileri tarihli siparişler tek bir yığın hâlinde açılır.
     *
     * NEDEN BUGÜN İSTİSNA: servis günü bugünse mutfak zaten o günün içinde
     * çalışıyor ve siparişi bekletmenin karşılığı yok. Bugünün kesimi ister
     * ileride olsun (satış saatleri içinde verilen normal sipariş) ister
     * geçmiş (panelden telefonla girilen sipariş), cevap aynı: anında.
     * İki durumun aynı cevabı vermesi sayesinde "satış saatleri içinde mi"
     * diye AYRI bir denetim yok — olsaydı `OrderingWindow` ile ikinci bir
     * kesim tanımı üretirdi.
     *
     * GÜN KARŞILAŞTIRMASI `toDateString()` ÜZERİNDEN. `$serviceDay` çağırana
     * göre UTC de olabilir işletme saati de; `order_date` de aynı dizeden
     * yazılıyor ve mutfak panosu `whereDate('order_date', bugün)` ile
     * süzüyor. Aynı diziden karşılaştırmak, kapının panonun gün tanımıyla
     * ayrışamamasını garanti eder.
     *
     * KESİM YOKSA KAPI DA YOK: `order_cutoff` `null` olabilir ("kesim saati
     * yok") ve o kurulumda sipariş hiç açılmadan sonsuza kadar görünmez
     * kalırdı. Geçmiş bir kesim de aynı şekilde `null` döner — geçmiş bir ana
     * damga atmak, `[since, now]` aralığını tarayan artımlı yoklamanın
     * siparişi hiç görmemesi riskini taşırdı.
     *
     * Dönen an İŞLETME SAATİNDE hesaplanıp `forStorage()` ile veritabanının
     * zaman dilimine çevriliyor (`BusinessTime` docblock'undaki 3 saatlik
     * kayma tuzağı).
     */
    private function releaseAtFor(Location $location, Carbon $serviceDay): ?Carbon
    {
        if ($serviceDay->toDateString() === BusinessTime::today()) {
            return null;
        }

        $cutoff = $this->window->cutoffFor($location, $serviceDay);

        if ($cutoff === null || $this->window->hasPassed($cutoff)) {
            return null;
        }

        return BusinessTime::forStorage($cutoff);
    }

    /**
     * Abonelik satırlarını menüye karşı çözüp ANLAŞMALI fiyatla fiyatlandırır.
     *
     * İKİ MENÜ MODU, TEK FİYAT KURALI. `fixed_list` aboneliğin kendi ürün
     * satırlarını, `daily_menu` o günün yayınlanmış menüsünü kaynak alır;
     * ikisinde de para `agreed_unit_price_kurus` üzerinden, PORSİYON BAŞINA
     * hesaplanır. Anlaşmalı fiyat bu yüzden `daily_menu`'de de ZORUNLU:
     * sözleşme "o gün ne pişerse pişsin porsiyonu şu kadar" der
     * (`docs/11-yol-haritasi.md` §7.5). Fiyatı günün menüsünden almak,
     * mutfak pahalı bir gün girdiğinde faturayı sessizce büyütürdü.
     *
     * @return list<array<string, mixed>>
     */
    private function resolveSubscriptionLines(Subscription $subscription, Carbon $serviceDate): array
    {
        /*
         * FİYAT KONTROLÜ MODDAN ÖNCE: fiyatsız bir abonelik hiçbir modda
         * sipariş üretemez ve sebebi menü kaynağından bağımsız. Aşağıya
         * bırakılsaydı `daily_menu` dalında iki kez tekrarlanırdı.
         */
        if ($subscription->agreed_unit_price_kurus === null) {
            throw ApiException::validationFailed(
                'Anlaşmalı fiyat tanımlı değil.',
                ['subscription_id' => $subscription->id],
            );
        }

        // Porsiyon = o günkü kişi sayısı (istisna override ?? default_quantity).
        $portions = max(1, $subscription->quantityForDate($serviceDate));

        return match ($subscription->menu_mode) {
            Subscription::MENU_DAILY => $this->dailyMenuLines($subscription, $serviceDate, $portions),
            Subscription::MENU_FIXED_LIST => $this->fixedListLines($subscription, $portions),
            default => throw ApiException::validationFailed(
                'Bu abonelik menü modu henüz desteklenmiyor.',
                ['menu_mode' => $subscription->menu_mode],
            ),
        };
    }

    /**
     * `menu_mode = fixed_list` — aboneliğin kendi ürün satırları.
     *
     * @return list<array<string, mixed>>
     */
    private function fixedListLines(Subscription $subscription, int $portions): array
    {
        $subLines = $subscription->lines;
        if ($subLines->isEmpty()) {
            throw ApiException::validationFailed(
                'Abonelikte ürün satırı yok.',
                ['subscription_id' => $subscription->id],
            );
        }

        // Menü satırları her PORSİYONUN bileşenidir; mutfağa düşen adet
        // porsiyon × satır adedidir (ör. 3 porsiyon, menüde 1 çorba → 3 çorba).
        // Fiyat porsiyon başınadır ve toplam ayrıca hesaplanır
        // (createForSubscription), bu yüzden satır fiyatı 0'dır — yemekler
        // sabit menü porsiyonunun bileşeni, ayrı ücretlendirilmez.
        //
        // ABONELİK, `LineResolver::resolve()` KULLANMAZ ve bu bilinçlidir:
        //   * fiyat anlaşmalı (`agreed_unit_price_kurus`), menü fiyatı değil;
        //   * "satışta değil" ve "bugün tükendi" (K-11) kontrolleri
        //     UYGULANMAZ — abonelik bir sözleşmedir, günlük stok kararı onu
        //     iptal edemez. Bir günü atlamak için
        //     `veykemtu_subscription_exceptions` kaydı girilir; o ayrı ve
        //     bilinçli bir karardır.
        $lines = [];
        foreach ($subLines as $subLine) {
            $quantity = $portions * max(1, (int) $subLine->quantity);

            $menu = Menu::where('menu_id', $subLine->menu_id)->first();
            if ($menu === null) {
                throw ApiException::itemUnavailable(
                    'Abonelik ürünü menüde bulunamadı.',
                    (int) $subLine->menu_id,
                );
            }

            $lines[] = [
                'menu' => $menu,
                'quantity' => $quantity,
                'unit_price' => 0,
                'line_total' => 0,
                'options' => [],
                'note' => $subLine->label,
            ];
        }

        if ($lines === []) {
            throw ApiException::validationFailed(
                'Üretilecek satır kalmadı.',
                ['subscription_id' => $subscription->id],
            );
        }

        return $lines;
    }

    /**
     * `menu_mode = daily_menu` — o günün yayınlanmış menüsü (B-19).
     *
     * TEK SEFERLİK SİPARİŞLE AYNI ŞEKİL: fiyatlı bir paket ÜST satırı +
     * sıfır fiyatlı bileşen satırları (`LineResolver::resolvePackageLine`).
     * Şeklin aynı olması kozmetik değil — `ProductionListService`,
     * `SubscriptionKitchenPlan::totals` ve `OrderPresenter::kitchenItems`
     * hepsi `bld_line_role != 'package'` süzgecini kullanıyor. Abonelik
     * bileşenleri üst satırsız yazsaydı süzgeç abonelikte hiçbir şey
     * elemez, mutfak şeridi iki farklı kaynaktan iki farklı şekil görürdü.
     *
     * VİTRİN KAPILARI UYGULANMAZ: `DailyMenuService::assertOrderable`
     * yerine doğrudan `findPublished`. Kesim saati, ileri görüş penceresi
     * ve `bld_daily_menu_enabled` şalteri MÜŞTERİNİN kendi kendine sipariş
     * vermesini düzenler; abonelik bir sözleşmedir ve gece işi zaten
     * yöneticinin girdiği takvime göre koşar. Kapalı gün de burada
     * denetlenmez — `SubscriptionGenerateCommand` onu daha üstte eliyor,
     * iki yerde iki kural olmasın.
     *
     * @return list<array<string, mixed>>
     */
    private function dailyMenuLines(
        Subscription $subscription,
        Carbon $serviceDate,
        int $portions,
    ): array {
        $locationId = (int) $subscription->location_id;
        $day = DailyMenu::findPublished($locationId, $serviceDate);

        /*
         * MENÜ YOKSA SESSİZCE ATLANMAZ, PATLAR.
         *
         * Sessiz atlama `veykemtu_subscription_runs` satırı bırakmadan
         * "üretildi" sayılmaya en yakın davranış olurdu ve mutfak sabah
         * eksik olduğunu ancak yemek saatinde görürdü. Hata satırı
         * bırakmak, menü yayınlanınca komutun yeniden koşturulmasıyla
         * siparişin doğmasını sağlıyor; UNIQUE kısıtı tek sipariş
         * garantisini koruyor.
         */
        if ($day === null) {
            throw ApiException::validationFailed(
                $serviceDate->locale('tr')->isoFormat('D MMMM YYYY')
                    .' için yayınlanmış günün menüsü yok; abonelik siparişi üretilemedi.',
                [
                    'subscription_id' => $subscription->id,
                    'service_date' => $serviceDate->toDateString(),
                    'reason' => DailyMenuService::REASON_NOT_PUBLISHED,
                ],
            );
        }

        $components = [];

        foreach ($day->items as $dayItem) {
            // Seçmeli kalemler pakete girmez — tek seferlik sipariştekiyle
            // aynı kural (`LineResolver::resolvePackageLine`).
            if (!$dayItem->is_required) {
                continue;
            }

            $menu = $dayItem->menu;

            if ($menu === null) {
                throw ApiException::itemUnavailable(
                    'Günün menüsündeki bir ürün bulunamadı.',
                    (int) $dayItem->menu_id,
                );
            }

            $components[] = [
                'menu' => $menu,
                'name' => $dayItem->displayName(),
                'quantity' => $portions * max(1, (int) $dayItem->quantity),
                // SIFIR, BİLEREK: parayı üst satır taşıyor.
                'unit_price' => 0,
                'line_total' => 0,
                'options' => [],
                'note' => null,
            ];
        }

        if ($components === []) {
            throw ApiException::validationFailed(
                $serviceDate->locale('tr')->isoFormat('D MMMM YYYY')
                    .' menüsünde zorunlu ürün yok; abonelik siparişi üretilemedi.',
                [
                    'subscription_id' => $subscription->id,
                    'service_date' => $serviceDate->toDateString(),
                ],
            );
        }

        $packageMenuId = $day->packageMenuId();
        $package = $packageMenuId !== null
            ? Menu::query()->where('menu_id', $packageMenuId)->first()
            : null;

        if ($package === null) {
            throw ApiException::itemUnavailable(
                '"Günün Menüsü" ürünü bu vitrinde tanımlı değil; '
                    .'`veykemtu:setup` koşulmamış olabilir.',
                $packageMenuId ?? 0,
            );
        }

        $unitPrice = (int) $subscription->agreed_unit_price_kurus;

        /*
         * PAKET FİYATI DEĞİL, ANLAŞMALI FİYAT. `$day->sellsPackage()`
         * burada hiç sorulmuyor: o gün vitrinde paket satılmıyor olabilir
         * (yalnız kalemler tek tek satılıyordur) ama abonelinin sözleşmesi
         * yine de bir porsiyonun tamamıdır. Vitrinin o günkü satış kararını
         * sözleşmeye taşımak, bir günün fiyatlandırma tercihinin abonelik
         * üretimini durdurması demek olurdu.
         */
        return [[
            'menu' => $package,
            'name' => $day->orderLineName(),
            'quantity' => $portions,
            'unit_price' => $unitPrice,
            'line_total' => $unitPrice * $portions,
            'options' => [],
            'note' => null,
            'role' => 'package',
            'daily_menu_id' => (int) $day->id,
            'components' => $components,
        ]];
    }

    /**
     * Teslimat noktasının kayıtlı adresini siparişe KOPYALAR (anlık görüntü).
     * Abonelik/adres sonradan değişse üretilmiş siparişin adresi değişmez.
     */
    private function copyPointAddress(Subscription $subscription, SubscriptionDeliveryPoint $point): int
    {
        $saved = Address::where('address_id', $point->address_id)->first();
        if ($saved === null) {
            throw ApiException::validationFailed(
                'Teslimat noktası adresi bulunamadı.',
                ['address_id' => $point->address_id],
            );
        }

        $model = new Address;
        $model->customer_id = $subscription->customer_id;
        $model->address_1 = $saved->address_1;
        $model->address_2 = $saved->address_2;
        $model->city = $saved->city;
        $model->state = $saved->state;
        if ($saved->bld_latitude !== null && $saved->bld_longitude !== null) {
            $model->bld_latitude = $saved->bld_latitude;
            $model->bld_longitude = $saved->bld_longitude;
        }

        // Yapılandırılmış alanlar da kopyalanıyor (B-21). Kopyalanmasaydı
        // abonelik siparişlerinin adresi tek seferlik siparişlerinkinden
        // eksik olurdu ve aynı müşteriye giden iki fiş farklı görünürdü.
        StructuredAddress::copy($model, StructuredAddress::read($saved));

        $model->save();

        return (int) $model->address_id;
    }

    /**
     * Adrese gönderim siparişi için adres defterine satır açar.
     *
     * K-12 refaktörü (`LineResolver` ayrıştırması) bu metodu yanlışlıkla
     * SİLDİ ama 72. satırdaki çağrısı yerinde kaldı: `POST /api/orders`
     * adrese gönderimde ölümcül hatayla 500 dönüyordu. Testlerde 36 test
     * birden bunun üzerine düştü (12.08.2026).
     *
     * @param array<string, mixed>|null $address
     */
    private function storeAddress(ApiCustomer $customer, ?array $address): int
    {
        if ($address === null) {
            throw ApiException::validationFailed('Teslimat adresi zorunludur.', [
                'address' => 'Adrese gönderim için adres girilmeli.',
            ]);
        }

        $model = new Address;
        $model->customer_id = $customer->customer_id;

        /*
         * Yapılandırılmış alanlar (B-21) siparişe de KOPYALANIYOR. Sipariş
         * adresi defterdeki kayda BAĞLANMIYOR; müşteri daire numarasını
         * sonradan düzeltse bile teslim edilmiş siparişin kâğıdı değişmemeli.
         */
        StructuredAddress::copy($model, $address);

        // `line1` müşteri yazdıysa aynen, yazmadıysa parçalardan. İkisi de
        // yoksa adres yok demektir — cümle kurulamadan sipariş geçmemeli.
        $line1 = trim((string) ($address['line1'] ?? ''));
        $line1 = $line1 !== '' ? $line1 : StructuredAddress::lineFor($model);

        if ($line1 === '') {
            throw ApiException::validationFailed('Teslimat adresi zorunludur.', [
                'address' => 'Adrese gönderim için adres girilmeli.',
            ]);
        }

        $model->address_1 = $line1;
        $model->address_2 = $address['note'] ?? null;
        $model->city = (string) ($address['city'] ?? '');
        $model->state = (string) ($address['district'] ?? '');

        // Koordinat siparişin ANLIK GÖRÜNTÜSÜNE yazılıyor, adres defterine
        // bakılarak değil. Müşteri sipariş verdikten sonra kayıtlı adresinin
        // iğnesini taşırsa, mutfaktaki fiş ve kuryenin gideceği nokta
        // değişmemeli; sipariş verildiği andaki yer neredeyse orası kalır.
        //
        // Çift olarak yazılıyor: yarısı dolu bir kayıt haritada gösterilemez.
        $lat = $address['latitude'] ?? null;
        $lng = $address['longitude'] ?? null;
        if ($lat !== null && $lng !== null) {
            $model->bld_latitude = $lat;
            $model->bld_longitude = $lng;
        }

        $model->save();

        return (int) $model->address_id;
    }

}
