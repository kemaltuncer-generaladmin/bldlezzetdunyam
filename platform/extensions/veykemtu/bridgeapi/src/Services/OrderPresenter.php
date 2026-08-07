<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Igniter\Cart\Models\Order;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\BridgeApi\Support\Money;

/**
 * Sipariş nesnelerini sözleşme biçimine çevirir — `docs/openapi.yaml`.
 *
 * NEDEN AYRI SINIF: aynı sipariş üç farklı yüzde farklı görünür —
 * müşteri (fiyatlı, adresli), mutfak (fiyatsız, adressiz), fiş. Bu ayrımı
 * denetleyicilere dağıtmak, bir gün mutfak yanıtına fiyat sızdırmanın en
 * kolay yoludur. Kapsam sınırı tek dosyada durur ve denetlenebilir.
 */
class OrderPresenter
{
    public function __construct(private readonly OrderStatusTransition $transitions) {}

    /** @return array<string, mixed> */
    public function created(Order $order): array
    {
        return [
            'id' => (int) $order->order_id,
            'order_number' => $this->number($order),
            'status' => $this->transitions->codeOf($order),
            'total' => Money::toKurus($order->order_total),
            'currency' => 'TRY',
            'payment' => $this->payment($order),
            'created_at' => $this->ts($order->created_at),
        ];
    }

    /** @return array<string, mixed> */
    public function summary(Order $order): array
    {
        return [
            'id' => (int) $order->order_id,
            'order_number' => $this->number($order),
            'status' => $this->transitions->codeOf($order),
            'total' => Money::toKurus($order->order_total),
            'currency' => 'TRY',
            'item_count' => (int) $order->total_items,
            'created_at' => $this->ts($order->created_at),
        ];
    }

    /** @return array<string, mixed> */
    public function detail(Order $order): array
    {
        $totals = $this->totals($order);
        $isDelivery = $order->order_type === Order::DELIVERY;

        return [
            'id' => (int) $order->order_id,
            'order_number' => $this->number($order),
            'status' => $this->transitions->codeOf($order),
            'items' => $this->pricedItems($order),
            'subtotal' => $totals['subtotal'],
            'delivery_fee' => $totals['delivery'],
            'total' => $totals['total'],
            'currency' => 'TRY',
            'delivery_type' => $this->deliveryType($order),
            'address' => $isDelivery ? $this->address($order) : null,
            'requested_at' => $this->requestedAt($order),
            'customer_note' => $order->comment !== null ? (string) $order->comment : null,
            'payment' => $this->payment($order),
            'status_history' => $this->statusHistory($order),
            'created_at' => $this->ts($order->created_at),
        ];
    }

    /**
     * Mutfak görünümü — fiyat, telefon, adres, e-posta **yoktur**.
     *
     * @return array<string, mixed>
     */
    public function kitchen(Order $order): array
    {
        return [
            'id' => (int) $order->order_id,
            'order_number' => $this->number($order),
            'status' => $this->transitions->codeOf($order),
            'requested_at' => $this->requestedAt($order),
            'delivery_type' => $this->deliveryType($order),
            'customer_label' => $this->customerLabel($order),
            'items' => $this->kitchenItems($order),
            'customer_note' => $order->comment !== null ? (string) $order->comment : null,
            'created_at' => $this->ts($order->created_at),
            'updated_at' => $this->ts($order->updated_at),
        ];
    }

    public function number(Order $order): string
    {
        return 'S-'.$order->order_id;
    }

    /** Sözleşmedeki `pickup`; TastyIgniter içeride `collection` saklar. */
    public function deliveryType(Order $order): string
    {
        return $order->order_type === Order::DELIVERY ? 'delivery' : 'pickup';
    }

    /** @return array{subtotal:int, delivery:int, total:int} */
    public function totals(Order $order): array
    {
        $rows = DB::table('order_totals')
            ->where('order_id', $order->order_id)
            ->pluck('value', 'code');

        $subtotal = $rows->has('subtotal')
            ? Money::toKurus($rows['subtotal'])
            : Money::toKurus($order->order_total);

        $delivery = $rows->has('delivery') ? Money::toKurus($rows['delivery']) : 0;

        $total = $rows->has('order_total')
            ? Money::toKurus($rows['order_total'])
            : Money::toKurus($order->order_total);

        return ['subtotal' => $subtotal, 'delivery' => $delivery, 'total' => $total];
    }

    /** @return list<array<string, mixed>> */
    public function pricedItems(Order $order): array
    {
        return DB::table('order_menus')
            ->where('order_id', $order->order_id)
            ->orderBy('order_menu_id')
            ->get()
            ->map(fn(object $row): array => [
                'menu_id' => (int) $row->menu_id,
                'name' => (string) $row->name,
                'quantity' => (int) $row->quantity,
                'options' => $this->optionNames($row->option_values),
                'note' => $row->comment !== null ? (string) $row->comment : null,
                'unit_price' => Money::toKurus($row->price),
                'line_total' => Money::toKurus($row->subtotal),
            ])
            ->all();
    }

    /** @return list<array<string, mixed>> */
    public function kitchenItems(Order $order): array
    {
        return DB::table('order_menus')
            ->where('order_id', $order->order_id)
            ->orderBy('order_menu_id')
            ->get()
            ->map(fn(object $row): array => [
                'name' => (string) $row->name,
                'quantity' => (int) $row->quantity,
                'options' => $this->optionNames($row->option_values),
                'note' => $row->comment !== null ? (string) $row->comment : null,
            ])
            ->all();
    }

    /** @return array<string, mixed>|null */
    public function address(Order $order): ?array
    {
        if ($order->address_id === null) {
            return null;
        }

        $row = DB::table('addresses')->where('address_id', $order->address_id)->first();
        if ($row === null) {
            return null;
        }

        return [
            'line1' => (string) $row->address_1,
            'district' => (string) ($row->state ?? ''),
            'city' => (string) ($row->city ?? ''),
            'note' => $row->address_2 !== null && $row->address_2 !== ''
                ? (string) $row->address_2
                : null,

            // Çift olarak veriliyor: yarısı dolu bir koordinat haritada
            // gösterilemez ama istemci "var" sanıp iğneyi yanlış yere koyar.
            'latitude' => $row->bld_latitude !== null && $row->bld_longitude !== null
                ? (float) $row->bld_latitude
                : null,
            'longitude' => $row->bld_latitude !== null && $row->bld_longitude !== null
                ? (float) $row->bld_longitude
                : null,
        ];
    }

    /** @return array<string, mixed> */
    public function payment(Order $order): array
    {
        $method = (string) ($order->payment ?? 'cash');
        $odendi = (bool) $order->processed;

        return array_filter([
            'method' => $method,
            'status' => $odendi ? 'paid' : 'pending',
            'redirect_url' => $this->redirectUrl($order, $method, $odendi),
        ], static fn($value): bool => $value !== null);
    }

    /**
     * Online ödemede sağlayıcının ödeme sayfası.
     *
     * Faz 1'de bu adres **simülasyon** sayfasıdır; gerçek tahsilat yapmaz
     * (`veykemtu/payment`). Kuveyt Türk entegrasyonu geldiğinde yalnızca
     * bu metodun ürettiği adres değişir — sözleşme ve istemciler aynı kalır.
     *
     * Ödenmiş siparişte `null` döner: istemci kullanıcıyı ikinci kez ödeme
     * sayfasına göndermemeli.
     */
    private function redirectUrl(Order $order, string $method, bool $odendi): ?string
    {
        if ($method !== 'online' || $odendi) {
            return null;
        }

        $hash = (string) ($order->hash ?? '');
        if ($hash === '') {
            return null;
        }

        return rtrim((string) config('app.url'), '/').'/odeme-simulasyon/'.$hash;
    }

    /** @return list<array<string, mixed>> */
    public function statusHistory(Order $order): array
    {
        return DB::table('status_history')
            ->join('statuses', 'statuses.status_id', '=', 'status_history.status_id')
            ->where('status_history.object_id', $order->order_id)
            ->where('status_history.object_type', 'orders')
            ->whereNotNull('statuses.status_code')
            ->orderBy('status_history.status_history_id')
            ->get(['statuses.status_code', 'status_history.created_at'])
            ->map(fn(object $row): array => [
                'status' => (string) $row->status_code,
                'at' => $this->ts($row->created_at),
            ])
            ->all();
    }

    /**
     * Ad + soyad baş harfi. Telefon, adres, e-posta asla dönmez.
     */
    public function customerLabel(Order $order): ?string
    {
        $first = trim((string) ($order->first_name ?? ''));
        $last = trim((string) ($order->last_name ?? ''));

        if ($first === '') {
            return null;
        }

        return $last === '' ? $first : $first.' '.mb_substr($last, 0, 1).'.';
    }

    public function requestedAt(Order $order): ?string
    {
        // ASAP siparişte "istenen zaman" yoktur; sipariş anı zaten created_at.
        if ((bool) $order->order_time_is_asap) {
            return null;
        }

        $date = $order->order_date;
        $time = $order->order_time;

        if ($date === null || $time === null) {
            return null;
        }

        // order_date/order_time işletme duvar saatidir; API UTC döner.
        return Carbon::parse(
            Carbon::parse($date)->toDateString().' '.Carbon::parse($time)->format('H:i:s'),
            BusinessTime::ZONE,
        )->utc()->toIso8601ZuluString();
    }

    /** @return list<string> */
    private function optionNames(mixed $serialized): array
    {
        if (!is_string($serialized) || $serialized === '') {
            return [];
        }

        $decoded = @unserialize($serialized, ['allowed_classes' => false]);

        if (!is_array($decoded)) {
            return [];
        }

        return array_values(array_map(strval(...), $decoded));
    }

    private function ts(mixed $value): ?string
    {
        return $value === null ? null : Carbon::parse($value)->utc()->toIso8601ZuluString();
    }
}
