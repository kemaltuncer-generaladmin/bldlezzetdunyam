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
        private readonly LineResolver $lines,
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

        $lines = $this->lines->resolve($items);
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

            $this->lines->writeLines($order, $lines);
            $this->lines->rewriteTotals($order, $subtotal, $deliveryFee);

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

            $this->lines->writeLines($order, $lines);
            $this->lines->rewriteTotals($order, $subtotal, 0);
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

}
