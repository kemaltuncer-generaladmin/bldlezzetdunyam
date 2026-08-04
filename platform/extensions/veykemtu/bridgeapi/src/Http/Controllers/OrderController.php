<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers;

use Igniter\Cart\Models\Order;
use Igniter\Local\Models\Location;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Validation\Rule;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Services\OrderFactory;
use Veykemtu\BridgeApi\Services\OrderPresenter;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;

/**
 * Müşteri sipariş uçları — `docs/openapi.yaml` §Sipariş.
 *
 * Başkasının siparişi istendiğinde **404** döner, 403 değil: 403 siparişin
 * var olduğunu ele verirdi (`docs/10-test-kabul.md` S5 adım 4).
 */
class OrderController extends ApiController
{
    public function __construct(
        private readonly OrderFactory $factory,
        private readonly OrderPresenter $presenter,
        private readonly OrderStatusTransition $transitions,
    ) {}

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'location_id' => ['required', 'integer'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.menu_id' => ['required', 'integer'],
            'items.*.quantity' => ['required', 'integer', 'min:1', 'max:999'],
            'items.*.option_value_ids' => ['sometimes', 'array'],
            'items.*.option_value_ids.*' => ['integer'],
            'items.*.note' => ['sometimes', 'nullable', 'string', 'max:255'],
            'delivery_type' => ['required', Rule::in([Order::DELIVERY, Order::COLLECTION, 'pickup'])],
            'address' => ['sometimes', 'nullable', 'array'],
            'address.line1' => ['required_if:delivery_type,delivery', 'nullable', 'string', 'max:255'],
            'address.district' => ['required_if:delivery_type,delivery', 'nullable', 'string', 'max:96'],
            'address.city' => ['required_if:delivery_type,delivery', 'nullable', 'string', 'max:96'],
            'address.note' => ['sometimes', 'nullable', 'string', 'max:255'],
            'requested_at' => ['sometimes', 'nullable', 'date'],
            'payment_method' => ['required', Rule::in(['online', 'cash', 'account'])],
            'customer_note' => ['sometimes', 'nullable', 'string', 'max:500'],
        ]);

        $location = Location::where('location_id', $data['location_id'])
            ->where('location_status', true)
            ->first();

        if ($location === null) {
            throw ApiException::notFound('Vitrin bulunamadı.');
        }

        /** @var ApiCustomer $customer */
        $customer = $request->user();

        $order = $this->factory->create(
            customer: $customer,
            location: $location,
            deliveryType: $this->normalizeDeliveryType($data['delivery_type']),
            items: $data['items'],
            address: $data['address'] ?? null,
            requestedAt: isset($data['requested_at']) && $data['requested_at'] !== null
                ? Carbon::parse($data['requested_at'])
                : null,
            paymentMethod: $data['payment_method'],
            customerNote: $data['customer_note'] ?? null,
        );

        return $this->json($this->presenter->created($order), 201);
    }

    public function index(Request $request): JsonResponse
    {
        $perPage = min(100, max(1, (int) $request->query('per_page', '25')));
        $page = max(1, (int) $request->query('page', '1'));

        /** @var ApiCustomer $customer */
        $customer = $request->user();

        $paginator = Order::query()
            ->where('customer_id', $customer->customer_id)
            ->orderByDesc('order_id')
            ->paginate(perPage: $perPage, page: $page);

        return $this->json([
            'data' => array_map(
                fn(Order $order): array => $this->presenter->summary($order),
                $paginator->items(),
            ),
            'meta' => [
                'page' => $paginator->currentPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
                'last_page' => max(1, $paginator->lastPage()),
            ],
        ]);
    }

    public function show(Request $request, int $order): JsonResponse
    {
        return $this->json($this->presenter->detail($this->ownedOrder($request, $order)));
    }

    public function cancel(Request $request, int $order): JsonResponse
    {
        $model = $this->ownedOrder($request, $order);

        if (!$this->transitions->customerCanCancel($model)) {
            throw ApiException::invalidTransition(
                $this->transitions->codeOf($model),
                OrderStatusTransition::CANCELLED,
                'Sipariş bu aşamada iptal edilemez. Bizimle iletişime geçin.',
            );
        }

        $updated = $this->transitions->apply($model, OrderStatusTransition::CANCELLED);

        return $this->json($this->presenter->detail($updated));
    }

    /**
     * Siparişi getirir; başkasınınsa "yok" der.
     *
     * @throws ApiException
     */
    private function ownedOrder(Request $request, int $orderId): Order
    {
        /** @var ApiCustomer $customer */
        $customer = $request->user();

        $order = Order::query()
            ->where('order_id', $orderId)
            ->where('customer_id', $customer->customer_id)
            ->first();

        if ($order === null) {
            throw ApiException::notFound('Sipariş bulunamadı.');
        }

        return $order;
    }

    /**
     * Sözleşmedeki `pickup`, TastyIgniter'da `collection` olarak saklanır.
     *
     * İki isimden hangisinin doğru olduğu tartışması değil bu: sözleşme
     * dışarıya `pickup` sözü verdi, çekirdek içeride `collection` kullanıyor.
     * Çeviri sınırda, tek yerde yapılır (B-02 bulgusu).
     */
    private function normalizeDeliveryType(string $value): string
    {
        return $value === Order::DELIVERY ? Order::DELIVERY : Order::COLLECTION;
    }
}
