<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers;

use Igniter\Cart\Models\Menu;
use Igniter\Local\Models\Location;
use Igniter\Main\Classes\MediaLibrary;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Throwable;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Services\DailyMenuService;
use Veykemtu\BridgeApi\Services\DailyStock;
use Veykemtu\BridgeApi\Services\EtaService;
use Veykemtu\BridgeApi\Services\LocationGate;
use Veykemtu\BridgeApi\Services\MenuAvailability;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\BridgeApi\Support\Money;

/**
 * Katalog uçları — `docs/openapi.yaml` §Katalog. Kimlik gerektirmez.
 *
 * Web sitesi bunları SSR sırasında çağırır; hızlı ve token'sız olmaları
 * SEO gereksinimidir (`docs/06-website.md` §2).
 */
class CatalogController extends ApiController
{
    /**
     * Ürün görseli adreslerinin istek ömürlü belleği (`menu_id => adres`).
     *
     * `getThumb()` ucuz değil: küçük resmin diskte olup olmadığına bakıyor,
     * yoksa üretip yazıyor. Aynı ürün ise bir yanıtta birden fazla kez
     * soruluyor — kalem listesinde bir kez, ızgara görsellerinde bir kez,
     * paketin içindekilerde bir kez daha. Aynı soruya aynı yanıtta üç kez
     * disk erişimiyle cevap vermenin sebebi yok.
     *
     * @var array<int, string|null>
     */
    private array $imageUrls = [];

    public function __construct(
        private readonly LocationGate $gate,
        private readonly EtaService $eta,
        private readonly MenuAvailability $availability,
        private readonly DailyMenuService $dailyMenus,
        private readonly DailyStock $stock,
    ) {}

    /**
     * Faz 1'de tek vitrin döner ama biçim **dizidir**.
     *
     * Tek nesne döndürmek bugün daha basit olurdu; ileride ikinci bir vitrin
     * eklendiğinde tüm istemcileri kırardı (ADR-09: alan tipi değişemez).
     */
    public function locations(): JsonResponse
    {
        $locations = Location::query()
            ->where('location_status', true)
            ->orderByDesc('is_default')
            ->get()
            ->map(fn(Location $location): array => $this->locationPayload($location))
            ->all();

        return $this->json(['data' => $locations]);
    }

    public function menu(int $location): JsonResponse
    {
        $this->activeLocation($location);

        // Bağıntı adları kurulu sürümden doğrulandı (B-02): MenuItemOption'ın
        // değerleri `menu_option_values`'tır, `option_values` değil.
        $items = Menu::query()
            ->with([
                'categories',
                'allergens',
                'menu_options.option',
                'menu_options.menu_option_values.option_value',
            ])
            ->get();

        // Kategoriye göre grupla. Kategorisiz ürün menüde görünmez —
        // vitrinde yeri olmayan ürün istemciye gönderilmemeli.
        $grouped = [];
        foreach ($items as $item) {
            foreach ($item->categories as $category) {
                $grouped[$category->category_id]['category'] = $category;
                $grouped[$category->category_id]['items'][] = $item;
            }
        }

        uasort(
            $grouped,
            static fn(array $a, array $b): int
                => ($a['category']->priority ?? 0) <=> ($b['category']->priority ?? 0),
        );

        // Tükendi listesi BİR KEZ okunuyor: her ürün için ayrı sorgu,
        // 80 kalemlik bir menüde 80 sorgu demekti.
        $soldOutReasons = $this->availability->soldOutReasons();

        $data = [];
        foreach ($grouped as $entry) {
            $data[] = [
                'id' => (int) $entry['category']->category_id,
                'name' => (string) $entry['category']->name,
                'sort' => (int) ($entry['category']->priority ?? 0),
                'items' => array_map(
                    fn(Menu $menu): array
                        => $this->menuItemPayload($menu, $soldOutReasons),
                    $entry['items'],
                ),
            ];
        }

        return $this->json(['data' => $data]);
    }

    /**
     * Günün menüsü — `GET /locations/{id}/daily-menu?date=` (B-19).
     *
     * Menü olmayan gün de **200** döner: boş gün bir hata değil, bir
     * cevaptır. 404 istemcileri gereksiz hata ekranına sokardı.
     */
    public function dailyMenu(Request $request, int $location): JsonResponse
    {
        $model = $this->activeLocation($location);

        $date = $this->dailyMenus->resolveServiceDate(
            $request->query('date') !== null ? (string) $request->query('date') : null,
            null,
        );

        $verdict = $this->dailyMenus->verdict($model, $date);
        $menu = $verdict['menu'];

        if ($menu === null) {
            return $this->json([
                'data' => [
                    'id' => null,
                    'date' => $date->toDateString(),
                    'title' => null,
                    'description' => null,
                    'image_url' => null,
                    // Menüsü olmayan günde dizilecek görsel de yok; boş dizi
                    // dönüyor ki istemci alanın varlığına bakmak zorunda
                    // kalmasın (`docs/openapi.yaml` → `DailyMenu.image_urls`).
                    'image_urls' => [],
                    'package' => null,
                    'items_total' => null,
                    // Menü yoksa tavan da yok: `null` SINIRSIZ demek ve
                    // burada "bilinmiyor" anlamına geliyor. `0` yazmak
                    // "tükendi" derdi ve sebep o değil.
                    'remaining_portions' => null,
                    'currency' => 'TRY',
                    'closed' => $verdict['closed'],
                    'is_orderable' => false,
                    'unavailable_reason' => $verdict['reason'],
                    'items' => [],
                ],
            ]);
        }

        // Tükenme YALNIZ bugün için okunur — mutfak gelecek salı köftenin
        // biteceğini bilemez (`docs/03` §3).
        $soldOutReasons = $date->isSameDay(BusinessTime::now())
            ? $this->availability->soldOutReasons()
            : [];

        /*
         * STOK TAVANI, TÜKENME İŞARETİNDEN FARKLI OLARAK HER GÜN İÇİN OKUNUR.
         *
         * "Bugün tükendi" mutfağın o güne dair kararı ve yalnız bugün
         * anlamlı; tavan ise bir PLAN — yönetici gelecek salı için 40
         * porsiyon girer ve müşteri o günü de dolmuş görebilmeli.
         *
         * Tek sorguda okunuyor: bir menüde onlarca kalem var ve her biri
         * için ayrı `remaining()` çağırmak onlarca sorgu demekti
         * (`soldOutReasons` aynı dersi bir kez verdi).
         */
        $remaining = $this->stock->remainingMap((int) $model->location_id, $date);

        $items = [];
        $imageUrls = [];

        foreach ($menu->items as $dayItem) {
            $product = $dayItem->menu;

            if ($product === null) {
                continue;
            }

            $payload = $this->menuItemPayload(
                $product,
                $soldOutReasons,
                $remaining[(int) $product->menu_id] ?? null,
            );
            // O güne fiyat istisnası girilmişse geçerli olan odur; müşteri
            // gördüğü fiyatla ödeyeceği fiyatı ayrı hesaplamaz.
            $payload['price'] = $dayItem->effectiveUnitPriceKurus();
            $payload['name'] = $dayItem->displayName();

            $items[] = $payload;

            /*
             * 2×2 IZGARANIN GÖRSELLERİ — İLK DÖRT KALEM, YÖNETİCİNİN SIRASI.
             *
             * Dizilim İSTEMCİDE yapılıyor (iş kuralı 6); sunucunun işi
             * yalnız adresleri sırayla vermek. Görseli olmayan kalem diziye
             * GİRMEZ ve boş yer de tutulmaz: `null` bir hücreyi üç
             * uygulamanın üçü de kendi yer tutucusuyla doldurur ve aynı gün
             * üç ayrı görünürdü (`docs/openapi.yaml` → `image_urls`).
             */
            if (count($imageUrls) < 4) {
                $itemImage = $this->imageUrl($product);

                if ($itemImage !== null) {
                    $imageUrls[] = $itemImage;
                }
            }
        }

        return $this->json([
            'data' => [
                'id' => (int) $menu->id,
                'date' => $menu->menu_date->toDateString(),
                'title' => $menu->title,
                'description' => $menu->description,
                // Yöneticinin o güne elle yüklediği kapak. Buraya kadar
                // sabit `null` dönüyordu ve `veykemtu_daily_menus.image_path`
                // hiç okunmuyordu: yüklenen kapak hiçbir istemcide
                // görünmüyordu.
                'image_url' => $this->mediaUrl($menu->image_path),
                'image_urls' => $imageUrls,
                'package' => $this->packagePayload(
                    $model,
                    $menu,
                    $soldOutReasons,
                    $remaining,
                ),
                'items_total' => $menu->itemsTotalKurus(),
                // Günün TOPLAM tavanı (`menu_id = 0` satırı). `null`
                // sınırsız, `0` tükendi — ikisi asla karıştırılmamalı.
                'remaining_portions' => $remaining[DailyStock::DAY_TOTAL] ?? null,
                'currency' => 'TRY',
                'closed' => $verdict['closed'],
                'is_orderable' => $verdict['orderable'],
                'unavailable_reason' => $verdict['reason'],
                'items' => $items,
            ],
        ]);
    }

    /**
     * Menü takvimi — gün seçiciyi çizmek için.
     */
    public function menuCalendar(Request $request, int $location): JsonResponse
    {
        $model = $this->activeLocation($location);

        $from = $request->query('from') !== null
            ? $this->dailyMenus->resolveServiceDate((string) $request->query('from'), null)
            : BusinessTime::now()->startOfDay();

        $to = $request->query('to') !== null
            ? $this->dailyMenus->resolveServiceDate((string) $request->query('to'), null)
            : $from->copy()->addDays(30);

        return $this->json([
            'data' => $this->dailyMenus->calendar($model, $from, $to),
        ]);
    }

    /**
     * Paket bölümü — `null` ise o gün paket satılmıyor.
     *
     * @param  array<int, string|null>  $soldOutReasons
     * @param  array<int, int>  $remaining  `menu_id => kalan porsiyon`
     * @return array<string, mixed>|null
     */
    private function packagePayload(
        Location $location,
        DailyMenu $menu,
        array $soldOutReasons,
        array $remaining = [],
    ): ?array {
        if (!$menu->sellsPackage()) {
            return null;
        }

        $packageMenuId = $this->gate->dailyPackageMenuId($location);

        if ($packageMenuId === null) {
            // Paket ürünü yapılandırılmamış — fiyat girilmiş olsa bile
            // sipariş edilemez. Sessizce fiyatlı göstermek, sepete
            // eklenemeyen bir kart üretirdi.
            return null;
        }

        $components = [];
        $soldOutReason = null;

        foreach ($menu->items as $dayItem) {
            if (!$dayItem->is_required) {
                continue;
            }

            $product = $dayItem->menu;

            if ($product === null) {
                continue;
            }

            $productId = (int) $product->menu_id;

            // ZORUNLU BİR KALEM TÜKENDİYSE PAKET DE DÜŞER: ana yemeği
            // olmayan bir menüyü satmak, bir telefon özrünü kırka çevirir.
            if (array_key_exists($productId, $soldOutReasons)) {
                $soldOutReason = $soldOutReasons[$productId]
                    ?? "{$product->menu_name} bugünlük tükendi.";
            }

            $components[] = [
                'menu_id' => $productId,
                'name' => $dayItem->displayName(),
                'quantity' => max(1, (int) $dayItem->quantity),
                'image_url' => $this->imageUrl($product),
                'allergens' => $product->allergens
                    ->map(static fn($ingredient): string => (string) $ingredient->name)
                    ->values()
                    ->all(),
            ];
        }

        if ($components === []) {
            return null;
        }

        if (array_key_exists($packageMenuId, $soldOutReasons)) {
            $soldOutReason ??= $soldOutReasons[$packageMenuId] ?? 'Günün menüsü bugünlük tükendi.';
        }

        return [
            'menu_id' => $packageMenuId,
            'name' => $menu->title ?? 'Günün Menüsü',
            'price' => (int) $menu->package_price_kurus,
            'currency' => 'TRY',
            'is_available' => $soldOutReason === null,
            'sold_out_reason' => $soldOutReason,
            /*
             * PAKETİN KENDİ TAVANI — gün toplamıyla birlikte değerlendirilir
             * ve sepete eklenebilecek azami adet ikisinin `min()`'idir
             * (`docs/contract/sales-rules.cases.json`). Burada bilerek
             * `min()` alınmıyor: iki tavanı tek sayıya ezmek, istemcinin
             * "hangisi doldu" cümlesini kuramaması demek olurdu.
             *
             * Aboneliklerin rezervasyonu bu sayıdan zaten düşülmüştür —
             * `reserved` kolonu kalanın içinde.
             */
            'remaining_portions' => $remaining[$packageMenuId] ?? null,
            'components' => $components,
        ];
    }

    /** @throws ApiException */
    private function activeLocation(int $location): Location
    {
        $model = Location::query()
            ->where('location_id', $location)
            ->where('location_status', true)
            ->first();

        if ($model === null) {
            throw ApiException::notFound('Vitrin bulunamadı.');
        }

        return $model;
    }

    /** @return array<string, mixed> */
    private function locationPayload(Location $location): array
    {
        return [
            'id' => (int) $location->location_id,
            'name' => (string) $location->location_name,
            'slug' => (string) ($location->permalink_slug ?? ''),
            'is_open' => $this->gate->isOpen($location),
            'ordering_enabled' => $this->gate->orderingEnabled($location),
            // Durdurma sebebi ve süresi additive: müşteri "neden" ve
            // "ne zaman" sorularının cevabını görsün diye (K-11).
            'ordering_pause_reason' => $this->gate->pauseReason($location),
            'ordering_resumes_at' => $this->gate->pauseEndsAt($location)
                ?->toIso8601ZuluString(),
            'order_cutoff' => $this->gate->orderCutoff($location),
            /*
             * Satış günün menüsü üzerinden mi yürüyor? (B-19)
             *
             * Sunucu tarafı şalter: istemciler bu akışa geçmeden önce ileriye
             * menü girilmiş olmalı ve geri dönmek üç uygulamayı birden
             * yeniden yayınlamayı gerektirmemeli.
             */
            'daily_menu_enabled' => $this->gate->dailyMenuEnabled($location),
            'max_lookahead_days' => $this->gate->maxLookaheadDays($location),
            'min_order_total' => $this->gate->minOrderTotal($location),
            'delivery_fee' => $this->gate->deliveryFee($location),
            'payment_methods' => $this->gate->paymentMethods($location),
            // Yoğunluk siparişi ENGELLEMEZ; istemci yalnızca uyarı gösterir.
            // Metin sunucudan gelir: değişince üç uygulamayı birden
            // yayınlamak gerekmesin.
            'busy' => $this->gate->isBusy($location),
            'busy_message' => $this->gate->busyMessage($location),
            /*
             * Teslim süresi tahmini. Müşteri teslim saatini seçebiliyordu ama
             * ne kadar sürdüğünü bilmeden seçiyordu; sonuç gerçekçi olmayan
             * saatler ve "geç kaldınız" şikâyetiydi — oysa gecikme yok,
             * beklenti baştan yanlış kurulmuştu.
             *
             * İki teslim türü ayrı: gel-al'da yol süresi yok.
             */
            'eta' => [
                'delivery' => $this->eta->estimate($location, 'delivery'),
                'pickup' => $this->eta->estimate($location, 'pickup'),
            ],
        ];
    }

    /** @return array<string, mixed> */
    /**
     * Ürün görselinin mutlak adresi, yoksa `null`.
     *
     * Görsel admin panelden yüklenir (Menüler → ürün → Görsel) ve
     * TastyIgniter'ın kendi medya kitaplığında durur; ayrı bir yükleme
     * mekanizması YAZMIYORUZ. Buradaki iş yalnızca onu sözleşmedeki
     * alana bağlamak.
     *
     * TEK BOYUT ÜRETİYORUZ. İstemciye boyut seçtirmek, her istemcinin
     * kendi ölçüsünü isteyip diskte onlarca küçük resim biriktirmesi
     * demekti; 800×600 hem menü kartına hem ürün sayfasına yetiyor.
     * Küçük resim ilk istekte üretilip diske yazılır, sonrakiler dosyadan
     * gelir.
     */
    private function imageUrl(Menu $menu): ?string
    {
        $menuId = (int) $menu->menu_id;

        if (array_key_exists($menuId, $this->imageUrls)) {
            return $this->imageUrls[$menuId];
        }

        $thumb = $menu->getThumb(['width' => 800, 'height' => 600]);

        if ($thumb === null || $thumb === '') {
            return $this->imageUrls[$menuId] = null;
        }

        // Medya diski `APP_URL` tabanlı mutlak adres üretir. Yine de
        // göreli gelirse mutlaklaştırıyoruz: istemcilerin biri Flutter,
        // göreli adresi çözecek bir sayfa bağlamı yok.
        $absolute = str_starts_with($thumb, 'http://') || str_starts_with($thumb, 'https://');

        return $this->imageUrls[$menuId] = $absolute ? $thumb : url($thumb);
    }

    /**
     * Menü/gün görselinin mutlak adresi — `veykemtu_daily_menus.image_path`.
     *
     * `Menu::getThumb()` gibi bir bağıntı yok: bu yol yöneticinin medya
     * kitaplığından seçtiği bir dosyadır ve kitaplığın kendi küçültücüsünden
     * geçiriliyor (aynı 800×600, `imageUrl()` ile aynı gerekçe).
     *
     * HATA YUTULUYOR VE `null` DÖNÜYOR: geçersiz ya da silinmiş bir yol
     * `MediaLibrary` içinden `ApplicationException` fırlatıyor. Kapak
     * görselinin bozuk olması, o günün menüsünün hiç açılamaması demek
     * olmamalı — kapak eksik görünsün, menü satılsın.
     */
    private function mediaUrl(?string $path): ?string
    {
        $path = trim((string) $path);

        if ($path === '') {
            return null;
        }

        if (str_starts_with($path, 'http://') || str_starts_with($path, 'https://')) {
            return $path;
        }

        try {
            // Çekirdek `MediaLibrary`'yi konteynerde tekil tutuyor ve
            // `initialize()`'ı orada çağırıyor (`Main\ServiceProvider`);
            // `new` ile kurulan bir örnek yapılandırmasız kalırdı.
            $thumb = resolve(MediaLibrary::class)->getMediaThumb($path, [
                'width' => 800,
                'height' => 600,
            ]);
        } catch (Throwable) {
            return null;
        }

        if ($thumb === '') {
            return null;
        }

        return str_starts_with($thumb, 'http://') || str_starts_with($thumb, 'https://')
            ? $thumb
            : url($thumb);
    }

    /**
     * @param  array<int, string|null>  $soldOutReasons  menu_id => sebep
     * @param  int|null  $remainingPortions  Bu kalemden o servis günü için
     *   kalan porsiyon. `null` SINIRSIZ — `0` ile karıştırılmamalı.
     *   Katalog ucunda (`/locations/{id}/menu`) her zaman `null`: stok
     *   **güne** bağlıdır, ürüne değil (`docs/openapi.yaml` → `MenuItem`).
     */
    private function menuItemPayload(
        Menu $menu,
        array $soldOutReasons = [],
        ?int $remainingPortions = null,
    ): array {
        $soldOut = array_key_exists((int) $menu->menu_id, $soldOutReasons);
        $soldOutReason = $soldOut ? $soldOutReasons[(int) $menu->menu_id] : null;

        $options = [];
        foreach ($menu->menu_options as $menuOption) {
            $option = $menuOption->option;
            if ($option === null) {
                continue;
            }

            $values = [];
            foreach ($menuOption->menu_option_values as $menuOptionValue) {
                $values[] = [
                    'id' => (int) $menuOptionValue->menu_option_value_id,
                    'name' => (string) ($menuOptionValue->option_value->value ?? ''),
                    'price_delta' => Money::toKurus($menuOptionValue->price ?? 0),
                ];
            }

            $options[] = [
                'id' => (int) $menuOption->menu_option_id,
                'name' => (string) $option->option_name,
                'type' => (string) $option->display_type,
                'required' => (bool) $menuOption->is_required,
                'values' => $values,
            ];
        }

        return [
            'id' => (int) $menu->menu_id,
            'name' => (string) $menu->menu_name,
            'description' => $menu->menu_description !== null
                ? (string) $menu->menu_description
                : null,
            'price' => Money::toKurus($menu->menu_price),
            'currency' => 'TRY',
            'image_url' => $this->imageUrl($menu),
            // Satışta olmayan ürün listede KALIR, soluk gösterilir (docs/03 §3).
            //
            // İki sebep tek alana düşüyor: yöneticinin kalıcı kararı
            // (`menu_status`) ve mutfağın günlük kararı (`sold_out`).
            // İstemci ikisini ayırt etmek zorunda değil — kullanıcı için
            // sonuç aynı: sipariş edilemez. Ama SEBEP ayrı alanda, çünkü
            // "bugünlük tükendi" ile "artık satmıyoruz" farklı beklenti
            // yaratır.
            'is_available' => (bool) $menu->menu_status && !$soldOut,
            'sold_out_today' => $soldOut,
            'sold_out_reason' => $soldOutReason,
            'remaining_portions' => $remainingPortions,
            'allergens' => $menu->allergens
                ->map(static fn($ingredient): string => (string) $ingredient->name)
                ->values()
                ->all(),
            'options' => $options,
        ];
    }
}
