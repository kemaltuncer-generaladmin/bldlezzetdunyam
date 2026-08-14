<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers;

use Igniter\Cart\Models\Menu;
use Igniter\Local\Models\Location;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Services\DailyMenuService;
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
    public function __construct(
        private readonly LocationGate $gate,
        private readonly EtaService $eta,
        private readonly MenuAvailability $availability,
        private readonly DailyMenuService $dailyMenus,
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
                    'package' => null,
                    'items_total' => null,
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

        $items = [];

        foreach ($menu->items as $dayItem) {
            $product = $dayItem->menu;

            if ($product === null) {
                continue;
            }

            $payload = $this->menuItemPayload($product, $soldOutReasons);
            // O güne fiyat istisnası girilmişse geçerli olan odur; müşteri
            // gördüğü fiyatla ödeyeceği fiyatı ayrı hesaplamaz.
            $payload['price'] = $dayItem->effectiveUnitPriceKurus();
            $payload['name'] = $dayItem->displayName();

            $items[] = $payload;
        }

        return $this->json([
            'data' => [
                'id' => (int) $menu->id,
                'date' => $menu->menu_date->toDateString(),
                'title' => $menu->title,
                'description' => $menu->description,
                'image_url' => null,
                'package' => $this->packagePayload($model, $menu, $soldOutReasons),
                'items_total' => $menu->itemsTotalKurus(),
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
     * @return array<string, mixed>|null
     */
    private function packagePayload(
        Location $location,
        DailyMenu $menu,
        array $soldOutReasons,
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
        $thumb = $menu->getThumb(['width' => 800, 'height' => 600]);

        if ($thumb === null || $thumb === '') {
            return null;
        }

        // Medya diski `APP_URL` tabanlı mutlak adres üretir. Yine de
        // göreli gelirse mutlaklaştırıyoruz: istemcilerin biri Flutter,
        // göreli adresi çözecek bir sayfa bağlamı yok.
        return str_starts_with($thumb, 'http://') || str_starts_with($thumb, 'https://')
            ? $thumb
            : url($thumb);
    }

    /**
     * @param  array<int, string|null>  $soldOutReasons  menu_id => sebep
     */
    private function menuItemPayload(Menu $menu, array $soldOutReasons = []): array
    {
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
            'allergens' => $menu->allergens
                ->map(static fn($ingredient): string => (string) $ingredient->name)
                ->values()
                ->all(),
            'options' => $options,
        ];
    }
}
