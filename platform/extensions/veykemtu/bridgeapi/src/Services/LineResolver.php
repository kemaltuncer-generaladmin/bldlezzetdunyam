<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Igniter\Cart\Models\Menu;
use Igniter\Cart\Models\Order;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\BridgeApi\Support\Money;

/**
 * Sipariş satırlarının tek sahibi — fiyatlama, seçenek doğrulama, yazma.
 *
 * NEDEN AYRI SERVİS (K-12): bu mantık `OrderFactory` içindeydi ve yalnız
 * sipariş **oluştururken** çalışıyordu. Sipariş düzenleme (`OrderEditor`)
 * aynı hesabı yapmak zorunda; kopyalansaydı iki yerde iki farklı fiyat
 * mantığı doğar ve "sepette şu yazıyordu" tartışması çözümsüz kalırdı.
 *
 * ÜÇ KIRILGAN AYRINTI BURADA TOPLANDI — ikisi sahada hataya yol açmıştı:
 *
 *   1. `order_menus.option_values` PHP `serialize()` biçiminde ve yalnız
 *      seçenek ADLARINI tutuyor; `order_menu_options` ise ayrı bir tablo
 *      ve satır adedini TEKRAR taşıyor. İkisi elle senkron tutulmak
 *      zorunda.
 *   2. `order_totals` tablosunda `(order_id, code)` üzerinde tekillik
 *      YOK. Eski `storeTotals()` yalnız `insert` yapıyordu; ikinci kez
 *      çağrılsa sipariş iki "Ara Toplam" satırı taşırdı. Bu yüzden
 *      [rewriteTotals] önce siler.
 *   3. Para birimi: telde kuruş (int), veritabanında ondalık TL. Tek
 *      dönüşüm noktası `Support\Money`.
 */
class LineResolver
{
    public function __construct(
        private readonly MenuAvailability $availability,
    ) {}

    /**
     * İstemci kalemlerini fiyatlı satırlara çevirir.
     *
     * @param  array<int, array{menu_id:int, quantity:int, option_value_ids?:list<int>, note?:string|null}>  $items
     * @param  bool  $enforceAvailability  `false` ise "satışta değil" ve
     *   "bugün tükendi" kontrolleri atlanır. Mutfak düzenlemesinde
     *   gerekiyor: personel müşteriyle telefonda konuşup **adedi azaltmak**
     *   isterken, o üründe stok bittiği için düzenlemenin tamamen
     *   reddedilmesi saçma olurdu — kalem zaten siparişte.
     * @param  DailyMenu|null  $day  O siparişin bağlı olduğu günün menüsü
     *   (B-19). `null` ise günün menüsü rejimi devre dışı: eski davranış
     *   birebir korunur ve mevcut çağrı yerlerinin hiçbiri değişmez.
     * @param  bool  $enforceMembership  `false` ise "yalnız o günün
     *   menüsündeki ürünler satılır" kuralı uygulanmaz. Mutfak düzenlemesi
     *   bunu kapatıyor: satır zaten siparişte ve menü o gün değişmiş
     *   olabilir; adet düşürmeyi menü üyeliğine takmak anlamsız olurdu.
     *   Paket fiyatlaması yine de `$day` üzerinden yapılır.
     * @return list<array<string, mixed>>
     *
     * @throws ApiException
     */
    public function resolve(
        array $items,
        bool $enforceAvailability = true,
        ?DailyMenu $day = null,
        bool $enforceMembership = true,
    ): array {
        $lines = [];

        /*
         * "Bugün tükendi" YALNIZ BUGÜN İÇİN anlamlıdır — mutfak gelecek salı
         * köftenin biteceğini bilemez (`MenuAvailability` zaten yalnız
         * bugünün satırlarını okuyor). Servis günü ileri bir tarihse tükenme
         * denetimi hiç yapılmaz; yapılsaydı bugün biten bir yemek yüzünden
         * gelecek haftanın menüsü satılamazdı.
         */
        $servesToday = $day === null
            || $day->menu_date->isSameDay(BusinessTime::now());

        $packageMenuId = $day?->packageMenuId();

        foreach ($items as $item) {
            $menuId = (int) ($item['menu_id'] ?? 0);
            $quantity = (int) ($item['quantity'] ?? 0);

            if ($quantity < 1) {
                throw ApiException::validationFailed('Adet en az 1 olmalı.', [
                    'menu_id' => $menuId,
                ]);
            }

            if ($packageMenuId !== null && $menuId === $packageMenuId) {
                $lines[] = $this->resolvePackageLine(
                    $day,
                    $menuId,
                    $quantity,
                    isset($item['note']) ? (string) $item['note'] : null,
                    $enforceAvailability && $servesToday,
                );

                continue;
            }

            $menu = Menu::with('menu_options.menu_option_values.option_value')
                ->where('menu_id', $menuId)
                ->first();

            if ($menu === null) {
                throw ApiException::itemUnavailable('Ürün menüde bulunamadı.', $menuId);
            }

            /*
             * PAKET ÜRÜNÜ, GÜN ÇÖZÜLMEDEN ASLA FİYATLANDIRILMAZ.
             *
             * Kaydın `menu_price` değeri 0,00 — gerçek fiyat o günün paket
             * fiyatı. Buraya düşmesine izin verseydik günün menüsü sıfır
             * liraya satılırdı; buradaki en pahalı sessiz arıza bu olurdu ve
             * kendi testi var.
             */
            if (DailyMenu::isPackageProduct($menuId)) {
                throw ApiException::itemUnavailable(
                    'Günün menüsü paketi bu sipariş için çözülemedi.',
                    $menuId,
                );
            }

            if ($enforceAvailability) {
                $this->assertAvailable($menu, $menuId, $servesToday);
            }

            if ($day !== null && $enforceMembership) {
                $this->assertInDailyMenu($day, $menuId, $menu);
            }

            $selected = array_map(intval(...), $item['option_value_ids'] ?? []);
            $options = $this->resolveOptions($menu, $selected);

            // O güne fiyat istisnası girilmişse o geçerli; yoksa ürünün
            // kendi fiyatı. Seçenek farkları her iki hâlde de eklenir.
            $basePrice = $day?->itemFor($menuId)?->effectiveUnitPriceKurus()
                ?? Money::toKurus($menu->menu_price);

            $unitPrice = $basePrice + array_sum(array_column($options, 'price_delta'));

            $lines[] = [
                'menu' => $menu,
                'quantity' => $quantity,
                'unit_price' => $unitPrice,
                'line_total' => $unitPrice * $quantity,
                'options' => $options,
                'note' => isset($item['note']) ? (string) $item['note'] : null,
                'daily_menu_id' => $day?->id,
            ];
        }

        return $lines;
    }

    /**
     * Paket satırı + sıfır fiyatlı bileşen satırları.
     *
     * Parayı paket satırı taşır; bileşenler mutfağa "ne pişecek" bilgisini
     * verir ve `ProductionListService` içinde GERÇEK `menu_id`'leriyle
     * toplanır. Gerekçe ve reddedilen alternatifler:
     * `docs/03-api-sozlesmesi.md` §4.
     *
     * @return array<string, mixed>
     *
     * @throws ApiException
     */
    private function resolvePackageLine(
        DailyMenu $day,
        int $packageMenuId,
        int $quantity,
        ?string $note,
        bool $checkSoldOut,
    ): array {
        if (!$day->sellsPackage()) {
            throw ApiException::itemUnavailable(
                'Bu gün menü paketi olarak satılmıyor; ürünleri tek tek seçebilirsiniz.',
                $packageMenuId,
            );
        }

        $package = Menu::query()->where('menu_id', $packageMenuId)->first();

        if ($package === null) {
            throw ApiException::itemUnavailable('Günün menüsü ürünü bulunamadı.', $packageMenuId);
        }

        if ($checkSoldOut && $this->availability->isSoldOut($packageMenuId)) {
            throw ApiException::itemUnavailable('Günün menüsü bugünlük tükendi.', $packageMenuId);
        }

        $components = [];

        foreach ($day->items as $dayItem) {
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

            /*
             * ZORUNLU BİR KALEM TÜKENDİYSE PAKET DE DÜŞER. Ana yemeği
             * olmayan bir menüyü satmak, bir telefon özrünü kırka çevirir.
             */
            if ($checkSoldOut && $this->availability->isSoldOut((int) $menu->menu_id)) {
                $reason = $this->availability->reasonFor((int) $menu->menu_id);

                throw ApiException::itemUnavailable(
                    "Günün menüsü bugünlük verilemiyor: {$menu->menu_name} tükendi."
                        .($reason !== null ? ' '.$reason : ''),
                    $packageMenuId,
                );
            }

            $componentQuantity = $quantity * max(1, (int) $dayItem->quantity);

            $components[] = [
                'menu' => $menu,
                'name' => $dayItem->displayName(),
                'quantity' => $componentQuantity,
                // SIFIR, BİLEREK: parayı paket satırı taşıyor. Aynı kalıp
                // abonelikte de kullanılıyor (`resolveSubscriptionLines`).
                'unit_price' => 0,
                'line_total' => 0,
                'options' => [],
                'note' => null,
            ];
        }

        if ($components === []) {
            throw ApiException::itemUnavailable(
                'Günün menüsünde ürün tanımlı değil.',
                $packageMenuId,
            );
        }

        $unitPrice = (int) $day->package_price_kurus;

        return [
            'menu' => $package,
            // Fişte ve sipariş detayında o günün başlığı görünür; ürünün
            // kalıcı adı ("Günün Menüsü") tek başına hangi gün olduğunu
            // söylemez.
            'name' => $day->orderLineName(),
            'quantity' => $quantity,
            'unit_price' => $unitPrice,
            'line_total' => $unitPrice * $quantity,
            'options' => [],
            'note' => $note,
            'role' => 'package',
            'daily_menu_id' => (int) $day->id,
            'components' => $components,
        ];
    }

    /**
     * Ürün o günün menüsünde ve tek tek satılabilir mi?
     *
     * @throws ApiException
     */
    private function assertInDailyMenu(DailyMenu $day, int $menuId, Menu $menu): void
    {
        $human = $day->menu_date->locale('tr')->isoFormat('D MMMM');
        $dayItem = $day->itemFor($menuId);

        if ($dayItem === null) {
            throw ApiException::itemUnavailable(
                "{$menu->menu_name}, {$human} menüsünde yok.",
                $menuId,
            );
        }

        if (!$day->components_sellable) {
            throw ApiException::itemUnavailable(
                "{$human} menüsü yalnız bütün olarak satılıyor.",
                $menuId,
            );
        }

        if (!$dayItem->sellable_alone) {
            throw ApiException::itemUnavailable(
                "{$menu->menu_name} yalnız menünün içinde veriliyor, tek başına satılmıyor.",
                $menuId,
            );
        }
    }


    /**
     * @param  bool  $checkSoldOut  Servis günü bugün değilse `false`.
     *   "Bugün tükendi" yalnız bugün için anlamlı; ileri tarihli bir
     *   siparişi bugünkü stok kararıyla reddetmek, gelecek haftanın
     *   menüsünü bugün biten bir yemek yüzünden satılamaz kılardı.
     *
     * @throws ApiException
     */
    private function assertAvailable(Menu $menu, int $menuId, bool $checkSoldOut = true): void
    {
        if ((bool) $menu->menu_status !== true) {
            throw ApiException::itemUnavailable(
                "{$menu->menu_name} şu anda satışta değil.",
                $menuId,
            );
        }

        if (!$checkSoldOut) {
            return;
        }

        // MUTFAĞIN GÜNLÜK KARARI (K-11). Yöneticinin kalıcı kararından
        // ayrı: gün dönümünde kendiliğinden kalkar.
        if ($this->availability->isSoldOut($menuId)) {
            $reason = $this->availability->reasonFor($menuId);

            throw ApiException::itemUnavailable(
                "{$menu->menu_name} bugünlük tükendi."
                    .($reason !== null ? ' '.$reason : ''),
                $menuId,
            );
        }
    }

    /**
     * Seçilen seçenek değerlerini doğrular.
     *
     * Bilinmeyen bir değer kimliği sessizce yok sayılmaz: istemci ile sunucu
     * menüsü ayrışmış demektir ve tutar da ayrışır. Kullanıcı "sepette 410 TL
     * yazıyordu" derken haklı olur.
     *
     * @param  list<int>  $selected
     * @return list<array{id:int, name:string, price_delta:int, menu_option_id:int}>
     *
     * @throws ApiException
     */
    public function resolveOptions(Menu $menu, array $selected): array
    {
        if ($selected === []) {
            return [];
        }

        $available = [];
        foreach ($menu->menu_options as $menuOption) {
            foreach ($menuOption->menu_option_values as $value) {
                $available[(int) $value->menu_option_value_id] = [
                    'id' => (int) $value->menu_option_value_id,
                    /*
                     * `->name`, `->option_value->value` DEĞİL.
                     *
                     * `menu_option_values` tablosunun sütunu `name`;
                     * `value` diye bir alan hiç yok. Eloquent tanımsız
                     * özniteliğe `null` dönüyor, `?? ''` de onu boş
                     * dizgeye çeviriyordu — yani HER seçenek adı boş
                     * kaydediliyordu. Fiyat farkı doğru işlendiği için
                     * toplam tutuyor, ama fişte ve sipariş detayında
                     * seçeneğin adı hiç görünmüyordu: mutfak "Bol
                     * porsiyon" yazan bir satır yerine boş bir parantez
                     * görüyor ve normal porsiyon çıkarıyor.
                     *
                     * `MenuItemOptionValue::getNameAttribute()` zaten
                     * `option_value->name`'e düşüyor; kısa yol o.
                     */
                    'name' => (string) ($value->name ?? ''),
                    'price_delta' => Money::toKurus($value->price ?? 0),
                    'menu_option_id' => (int) $menuOption->menu_option_id,
                ];
            }
        }

        $resolved = [];
        foreach ($selected as $valueId) {
            if (!isset($available[$valueId])) {
                throw ApiException::validationFailed(
                    'Seçilen ürün seçeneği geçersiz. Menüyü yenileyip tekrar deneyin.',
                    ['option_value_id' => $valueId, 'menu_id' => (int) $menu->menu_id],
                );
            }
            $resolved[] = $available[$valueId];
        }

        return $resolved;
    }

    /**
     * Satırları yazar. [$replace] doğruysa önceki satırlar SİLİNİR.
     *
     * Düzenlemede "farkı bul, sadece değişeni güncelle" yolu seçilmedi:
     * bir kalemin adedi, notu ve seçenekleri aynı anda değişebiliyor ve
     * kısmi güncelleme `order_menu_options` ile `option_values` arasında
     * sessiz tutarsızlık üretiyordu. Sil-yeniden yaz, tek işlem içinde
     * ve her zaman tutarlı.
     *
     * @param  list<array<string, mixed>>  $lines
     */
    public function writeLines(Order $order, array $lines, bool $replace = false): void
    {
        if ($replace) {
            DB::table('order_menu_options')->where('order_id', $order->order_id)->delete();
            DB::table('order_menus')->where('order_id', $order->order_id)->delete();
        }

        foreach ($lines as $line) {
            $orderMenuId = $this->insertLine($order, $line);

            foreach ($line['options'] as $option) {
                DB::table('order_menu_options')->insert([
                    'order_id' => $order->order_id,
                    'order_menu_id' => $orderMenuId,
                    'menu_option_id' => $option['menu_option_id'],
                    'menu_option_value_id' => $option['id'],
                    'order_option_name' => $option['name'],
                    'order_option_price' => Money::toDecimal($option['price_delta']),
                    'quantity' => $line['quantity'],
                ]);
            }

            /*
             * MENÜ PAKETİNİN BİLEŞENLERİ (B-19).
             *
             * Paket satırının hemen ardından, sıfır fiyatla ve
             * `bld_parent_line_id` ile bağlanarak yazılır. Parayı üst satır
             * taşır; bu satırlar mutfağa "ne pişecek" bilgisini verir ve
             * `ProductionListService` içinde GERÇEK `menu_id`'leriyle
             * toplanır — mutfağın şeridinde "40 Günün Menüsü" değil
             * "40 tavuk sote" yazması bu satırlar sayesinde.
             */
            foreach ($line['components'] ?? [] as $component) {
                $this->insertLine(
                    $order,
                    $component + [
                        'role' => 'component',
                        'daily_menu_id' => $line['daily_menu_id'] ?? null,
                        'parent_line_id' => $orderMenuId,
                    ],
                );
            }
        }
    }

    /**
     * Tek bir `order_menus` satırı yazar ve kimliğini döner.
     *
     * @param  array<string, mixed>  $line
     */
    private function insertLine(Order $order, array $line): int
    {
        /** @var Menu $menu */
        $menu = $line['menu'];

        return DB::table('order_menus')->insertGetId([
            'order_id' => $order->order_id,
            'menu_id' => $menu->menu_id,
            // Satır kendi adını taşıyabilir: menü paketinde o günün başlığı,
            // günün menüsü kaleminde yöneticinin verdiği etiket ("Günün
            // Çorbası: Mercimek"). Yoksa ürünün adı.
            'name' => $line['name'] ?? $menu->menu_name,
            'quantity' => $line['quantity'],
            'price' => Money::toDecimal($line['unit_price']),
            'subtotal' => Money::toDecimal($line['line_total']),
            'option_values' => serialize(array_column($line['options'], 'name')),
            'comment' => $line['note'],
            'bld_line_role' => $line['role'] ?? null,
            'bld_daily_menu_id' => $line['daily_menu_id'] ?? null,
            'bld_parent_line_id' => $line['parent_line_id'] ?? null,
        ]);
    }

    /**
     * Toplam satırlarını yeniden yazar.
     *
     * ÖNCE SİLER: `order_totals` tablosunda `(order_id, code)` tekilliği
     * yok. Yalnız `insert` yapan eski sürüm ikinci kez çağrılsa sipariş
     * iki "Ara Toplam" satırı taşır ve admin panelde toplam iki katı
     * görünürdü.
     */
    public function rewriteTotals(Order $order, int $subtotal, int $deliveryFee): void
    {
        DB::table('order_totals')->where('order_id', $order->order_id)->delete();

        $rows = [
            ['code' => 'subtotal', 'title' => 'Ara Toplam', 'value' => $subtotal, 'priority' => 0, 'summable' => false],
        ];

        if ($deliveryFee > 0) {
            $rows[] = ['code' => 'delivery', 'title' => 'Teslimat', 'value' => $deliveryFee, 'priority' => 100, 'summable' => true];
        }

        $rows[] = ['code' => 'order_total', 'title' => 'Toplam', 'value' => $subtotal + $deliveryFee, 'priority' => 999, 'summable' => false];

        foreach ($rows as $row) {
            DB::table('order_totals')->insert([
                'order_id' => $order->order_id,
                'code' => $row['code'],
                'title' => $row['title'],
                'value' => Money::toDecimal($row['value']),
                'priority' => $row['priority'],
                'is_summable' => $row['summable'],
            ]);
        }
    }
}
