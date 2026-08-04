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
use Veykemtu\BridgeApi\Support\Money;

/**
 * Sipariş oluşturma — `docs/openapi.yaml` `createOrder`.
 *
 * **Tutar sunucuda hesaplanır.** İstemcinin gönderdiği hiçbir fiyat alanı
 * okunmaz; sözleşmede böyle bir alan da yoktur (`docs/10-test-kabul.md` S6
 * adım 5). İstemcinin gösterdiği tutarla sunucunun hesabı ayrışırsa doğru
 * olan sunucununkidir.
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
    ) {}

    /**
     * @param  array<int, array{menu_id:int, quantity:int, option_value_ids?:list<int>, note?:string|null}>  $items
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
    ): Order {
        $this->gate->assertAcceptsOrder($location, $requestedAt);
        $this->gate->assertPaymentMethodAllowed($location, $paymentMethod);

        $lines = $this->resolveLines($items);
        $subtotal = array_sum(array_column($lines, 'line_total'));

        $this->gate->assertMeetsMinimum($location, $subtotal);

        $deliveryFee = $deliveryType === Order::DELIVERY
            ? $this->deliveryFee($location)
            : 0;

        return DB::transaction(function () use (
            $customer, $location, $deliveryType, $lines, $address,
            $requestedAt, $paymentMethod, $customerNote, $subtotal, $deliveryFee,
        ): Order {
            $addressId = $deliveryType === Order::DELIVERY
                ? $this->storeAddress($customer, $address)
                : null;

            $when = $requestedAt?->copy()->setTimezone(BusinessTime::ZONE)
                ?? BusinessTime::now();

            $order = new Order;
            $order->customer_id = $customer->customer_id;
            $order->first_name = $customer->first_name;
            $order->last_name = $customer->last_name;
            $order->email = $customer->email;
            $order->telephone = $customer->telephone;
            $order->location_id = $location->location_id;
            $order->address_id = $addressId;
            $order->order_type = $deliveryType;
            $order->order_date = $when->toDateString();
            $order->order_time = $when->format('H:i:s');
            $order->order_time_is_asap = $requestedAt === null;
            $order->total_items = array_sum(array_column($lines, 'quantity'));
            $order->order_total = Money::toDecimal($subtotal + $deliveryFee);
            $order->payment = $paymentMethod;
            $order->comment = $customerNote;
            // `cart` çekirdeğin sepet serileştirmesi içindir; API siparişinde
            // sepet nesnesi yoktur, boş dizi yazıyoruz (kolon NOT NULL).
            $order->cart = serialize([]);
            $order->status_id = $this->transitions->statusByCode(
                OrderStatusTransition::NEW,
            )->status_id;
            $order->save();

            $this->storeLines($order, $lines);
            $this->storeTotals($order, $subtotal, $deliveryFee);

            // Durum geçmişinin ilk satırı burada doğar; çekirdeğin metodu
            // status_history'yi ve bildirimleri yönetir.
            $order->updateOrderStatus($order->status_id, ['notify' => false]);

            return $order->refresh();
        });
    }

    /**
     * Kalemleri menüye karşı doğrular ve fiyatlandırır.
     *
     * @param  array<int, array<string, mixed>>  $items
     * @return list<array{menu:Menu, quantity:int, unit_price:int, line_total:int, options:list<array<string,mixed>>, note:string|null}>
     */
    private function resolveLines(array $items): array
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

            if ((bool) $menu->menu_status !== true) {
                throw ApiException::itemUnavailable(
                    "{$menu->menu_name} şu anda satışta değil.",
                    $menuId,
                );
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

    /**
     * Seçilen seçenek değerlerini doğrular.
     *
     * Bilinmeyen bir değer kimliği sessizce yok sayılmaz: istemci ile sunucu
     * menüsü ayrışmış demektir ve tutar da ayrışır. Kullanıcı "sepette 410 TL
     * yazıyordu" derken haklı olur.
     *
     * @param  list<int>  $selected
     * @return list<array{id:int, name:string, price_delta:int}>
     */
    private function resolveOptions(Menu $menu, array $selected): array
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

    /** @param list<array<string, mixed>> $lines */
    private function storeLines(Order $order, array $lines): void
    {
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

    private function storeTotals(Order $order, int $subtotal, int $deliveryFee): void
    {
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

    /**
     * Teslimat ücreti.
     *
     * Faz 1'de vitrin başına sabittir. Bölge/mesafe bazlı ücretlendirme
     * `BILINMEYENLER` #10'da açık soru olarak duruyor; karar gelince yalnızca
     * bu metot değişir.
     */
    private function deliveryFee(Location $location): int
    {
        $configured = DB::table('location_options')
            ->where('location_id', $location->location_id)
            ->where('item', 'bld_delivery_fee')
            ->value('value');

        if ($configured === null) {
            return 0;
        }

        return (int) (json_decode((string) $configured, true) ?? 0);
    }

    /** @param array<string, mixed>|null $address */
    private function storeAddress(ApiCustomer $customer, ?array $address): int
    {
        if ($address === null || blank($address['line1'] ?? null)) {
            throw ApiException::validationFailed('Teslimat adresi zorunludur.', [
                'address' => 'Adrese gönderim için adres girilmeli.',
            ]);
        }

        $model = new Address;
        $model->customer_id = $customer->customer_id;
        $model->address_1 = (string) $address['line1'];
        $model->address_2 = $address['note'] ?? null;
        $model->city = (string) ($address['city'] ?? '');
        $model->state = (string) ($address['district'] ?? '');
        $model->save();

        return (int) $model->address_id;
    }
}
