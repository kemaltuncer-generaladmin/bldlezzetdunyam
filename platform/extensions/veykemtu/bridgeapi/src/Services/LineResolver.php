<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Igniter\Cart\Models\Menu;
use Igniter\Cart\Models\Order;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Exceptions\ApiException;
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
     * @return list<array<string, mixed>>
     *
     * @throws ApiException
     */
    public function resolve(array $items, bool $enforceAvailability = true): array
    {
        $lines = [];

        foreach ($items as $item) {
            $menuId = (int) ($item['menu_id'] ?? 0);
            $quantity = (int) ($item['quantity'] ?? 0);

            $menu = Menu::with('menu_options.menu_option_values.option_value')
                ->where('menu_id', $menuId)
                ->first();

            if ($menu === null) {
                throw ApiException::itemUnavailable('Ürün menüde bulunamadı.', $menuId);
            }

            if ($enforceAvailability) {
                $this->assertAvailable($menu, $menuId);
            }

            if ($quantity < 1) {
                throw ApiException::validationFailed('Adet en az 1 olmalı.', [
                    'menu_id' => $menuId,
                ]);
            }

            $selected = array_map(intval(...), $item['option_value_ids'] ?? []);
            $options = $this->resolveOptions($menu, $selected);

            $unitPrice = Money::toKurus($menu->menu_price)
                + array_sum(array_column($options, 'price_delta'));

            $lines[] = [
                'menu' => $menu,
                'quantity' => $quantity,
                'unit_price' => $unitPrice,
                'line_total' => $unitPrice * $quantity,
                'options' => $options,
                'note' => isset($item['note']) ? (string) $item['note'] : null,
            ];
        }

        return $lines;
    }

    /** @throws ApiException */
    private function assertAvailable(Menu $menu, int $menuId): void
    {
        if ((bool) $menu->menu_status !== true) {
            throw ApiException::itemUnavailable(
                "{$menu->menu_name} şu anda satışta değil.",
                $menuId,
            );
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
                    'name' => (string) ($value->option_value->value ?? ''),
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
            /** @var Menu $menu */
            $menu = $line['menu'];

            $orderMenuId = DB::table('order_menus')->insertGetId([
                'order_id' => $order->order_id,
                'menu_id' => $menu->menu_id,
                'name' => $menu->menu_name,
                'quantity' => $line['quantity'],
                'price' => Money::toDecimal($line['unit_price']),
                'subtotal' => Money::toDecimal($line['line_total']),
                'option_values' => serialize(array_column($line['options'], 'name')),
                'comment' => $line['note'],
            ]);

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
        }
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
