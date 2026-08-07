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
use Veykemtu\BridgeApi\Models\AccountLedgerEntry;
use Veykemtu\BridgeApi\Models\ApiCustomer;
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
 * Tüm yazma işi tek transaction içindedir: yarım kalmış bir sipariş
 * (kalemleri olmayan başlık, toplamı olmayan kalem) mutfağa düşer ve
 * telafisi elle olur.
 */
class OrderFactory
{
    public function __construct(
        private readonly LocationGate $gate,
        private readonly OrderStatusTransition $transitions,
        private readonly AccountLedger $ledger,
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
            ? $this->gate->deliveryFee($location)
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

            // Cari hesap ödemesinde sipariş borcu deftere düşer. Aynı
            // transaction içinde: sipariş rollback olursa borç da yazılmaz.
            // `account` geçidi tahsilat YAPMAZ (sipariş `pending` kalır);
            // tahsilat sonra ayrı bir alacak hareketi olarak girilir.
            if ($paymentMethod === 'account') {
                $this->ledger->record(
                    customerId: (int) $customer->customer_id,
                    type: AccountLedgerEntry::TYPE_DEBIT,
                    amountKurus: $subtotal + $deliveryFee,
                    source: AccountLedgerEntry::SOURCE_ORDER,
                    referenceType: 'order',
                    referenceId: (int) $order->order_id,
                    description: 'Sipariş #'.$order->order_id,
                    effectiveDate: $when,
                );
            }

            return $order->refresh();
        });
    }

    /**
     * Abonelikten o günün siparişini üretir.
     *
     * Müşteri `create()` yolundan AYRI metot: `LocationGate` kapıları (kesim
     * saati, asgari tutar, şalter) UYGULANMAZ — bu bir sözleşme siparişidir,
     * vitrin siparişi değil. Fiyat menü LİSTE fiyatından değil, aboneliğin
     * ANLAŞMALI fiyatından gelir ve o günkü değeriyle siparişe KOPYALANIR;
     * sonraki menü zammı üretilmiş siparişi bozmaz. `account` ödeme modunda
     * cari borç aynı transaction içinde düşer.
     */
    public function createForSubscription(
        Subscription $subscription,
        ?SubscriptionDeliveryPoint $point,
        Carbon $serviceDate,
    ): Order {
        $lines = $this->resolveSubscriptionLines($subscription, $serviceDate);
        // Fiyat porsiyon başınadır: toplam = porsiyon × anlaşmalı porsiyon
        // fiyatı (yemekler bileşen olduğundan satır fiyatları 0'dır).
        $subtotal = max(1, $subscription->quantityForDate($serviceDate))
            * (int) $subscription->agreed_unit_price_kurus;

        $deliveryType = $subscription->delivery_type === 'delivery'
            ? Order::DELIVERY
            : Order::COLLECTION;
        // Anlaşmalı fiyat teslimatı kapsar; abonelik siparişinde ekstra
        // teslimat ücreti alınmaz.
        $paymentMethod = $subscription->payment_mode === Subscription::PAYMENT_ACCOUNT
            ? 'account'
            : 'cash';

        return DB::transaction(function () use (
            $subscription, $point, $serviceDate, $lines, $subtotal, $deliveryType, $paymentMethod,
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
            $order->order_time_is_asap = false;
            $order->total_items = array_sum(array_column($lines, 'quantity'));
            $order->order_total = Money::toDecimal($subtotal);
            $order->payment = $paymentMethod;
            $order->comment = $point?->note;
            $order->cart = serialize([]);
            $order->bld_subscription_id = $subscription->id;
            $order->status_id = $this->transitions->statusByCode(
                OrderStatusTransition::NEW,
            )->status_id;
            $order->save();

            $this->storeLines($order, $lines);
            $this->storeTotals($order, $subtotal, 0);
            $order->updateOrderStatus($order->status_id, ['notify' => false]);

            if ($paymentMethod === 'account') {
                $this->ledger->record(
                    customerId: (int) $customer->customer_id,
                    type: AccountLedgerEntry::TYPE_DEBIT,
                    amountKurus: $subtotal,
                    source: AccountLedgerEntry::SOURCE_ORDER,
                    referenceType: 'order',
                    referenceId: (int) $order->order_id,
                    description: 'Abonelik siparişi #'.$order->order_id,
                    effectiveDate: $serviceDate,
                );
            }

            return $order->refresh();
        });
    }

    /**
     * Abonelik satırlarını menüye karşı çözüp ANLAŞMALI fiyatla fiyatlandırır.
     *
     * Tek satırlı abonelikte tek-günlük adet istisnası uygulanır (o gün 20
     * yerine 12). Çok satırlı (varyantlı) abonelikte satır adetleri sabittir.
     *
     * @return list<array{menu:Menu, quantity:int, unit_price:int, line_total:int, options:list<array<string,mixed>>, note:string|null}>
     */
    private function resolveSubscriptionLines(Subscription $subscription, Carbon $serviceDate): array
    {
        if ($subscription->menu_mode !== Subscription::MENU_FIXED_LIST) {
            throw ApiException::validationFailed(
                'Bu abonelik menü modu henüz desteklenmiyor.',
                ['menu_mode' => $subscription->menu_mode],
            );
        }

        $subLines = $subscription->lines;
        if ($subLines->isEmpty()) {
            throw ApiException::validationFailed(
                'Abonelikte ürün satırı yok.',
                ['subscription_id' => $subscription->id],
            );
        }

        if ($subscription->agreed_unit_price_kurus === null) {
            throw ApiException::validationFailed(
                'Anlaşmalı fiyat tanımlı değil.',
                ['subscription_id' => $subscription->id],
            );
        }

        // Porsiyon = o günkü kişi sayısı (istisna override ?? default_quantity).
        // Menü satırları her PORSİYONUN bileşenidir; mutfağa düşen adet
        // porsiyon × satır adedidir (ör. 3 porsiyon, menüde 1 çorba → 3 çorba).
        // Fiyat porsiyon başınadır ve toplam ayrıca hesaplanır
        // (createForSubscription), bu yüzden satır fiyatı 0'dır — yemekler
        // sabit menü porsiyonunun bileşeni, ayrı ücretlendirilmez.
        $portions = max(1, $subscription->quantityForDate($serviceDate));

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
        $model->save();

        return (int) $model->address_id;
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
