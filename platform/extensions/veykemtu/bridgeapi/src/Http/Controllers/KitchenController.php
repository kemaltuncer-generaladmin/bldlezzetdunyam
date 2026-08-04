<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers;

use Igniter\Cart\Models\Order;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Validation\Rule;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\KitchenDevice;
use Veykemtu\BridgeApi\Models\PrintJob;
use Veykemtu\BridgeApi\Services\OrderPresenter;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;
use Veykemtu\BridgeApi\Services\ProductionListService;
use Veykemtu\BridgeApi\Services\ReceiptBuilder;

/**
 * KDS uçları — `docs/openapi.yaml` §Mutfak.
 *
 * Tümü `kitchen` kapsamı gerektirir. Bu uçlar fiyat, müşteri iletişim
 * bilgisi ve rapor **döndürmez**; tek istisna müşteri fişindeki teslimat
 * adresidir (ADR-08, `docs/10-test-kabul.md` S5).
 */
class KitchenController extends ApiController
{
    public function __construct(
        private readonly OrderPresenter $presenter,
        private readonly OrderStatusTransition $transitions,
        private readonly ReceiptBuilder $receipts,
        private readonly ProductionListService $production,
    ) {}

    /**
     * Cihaz eşleme — kimlik gerektirmez, tek kullanımlık kod ile.
     */
    public function pair(Request $request): JsonResponse
    {
        $data = $request->validate([
            'pairing_code' => ['required', 'string', 'max:16'],
            'device_name' => ['required', 'string', 'max:64'],
        ]);

        $device = KitchenDevice::where('pairing_code', strtoupper(trim($data['pairing_code'])))
            ->first();

        // Kodun yanlış olması ile süresinin dolması aynı yanıtı verir:
        // saldırgana hangi kodların var olduğunu söylememek için.
        if ($device === null || !$device->pairingCodeIsUsable()) {
            throw ApiException::notFound('Eşleme kodu geçersiz veya süresi dolmuş.');
        }

        $device->name = $data['device_name'];
        $token = $device->issueToken();

        return $this->json([
            'device_id' => (int) $device->id,
            'token' => $token,
            'server_time' => Carbon::now()->utc()->toIso8601ZuluString(),
        ]);
    }

    /**
     * Aktif siparişler — artımlı çekme.
     *
     * `since` durum değişimlerini de yakalar (`updated_at` üzerinden);
     * `after` yalnızca yeni siparişleri getirir. KDS `since` kullanmalıdır,
     * yoksa "hazırlanıyor" olan bir siparişin durumu ekranda takılı kalır.
     */
    public function orders(Request $request): JsonResponse
    {
        $request->validate([
            'after' => ['sometimes', 'integer'],
            'since' => ['sometimes', 'date'],
            'include_completed' => ['sometimes', 'boolean'],
        ]);

        $includeCompleted = $request->boolean('include_completed');

        $query = Order::query()->orderBy('order_id');

        if (!$includeCompleted) {
            $query->whereNotIn('status_id', $this->terminalStatusIds());
        }

        // Bugünün siparişleri: mutfak ekranı dünün işini göstermez.
        $query->whereDate('order_date', BusinessTime::now()->toDateString());

        if ($request->filled('after')) {
            $query->where('order_id', '>', (int) $request->query('after'));
        }

        if ($request->filled('since')) {
            $query->where('updated_at', '>', Carbon::parse((string) $request->query('since')));
        }

        $orders = $query->get();

        // max_id daima bugünün TÜM siparişlerinin en büyüğüdür; filtre boş
        // dönse bile istemcinin imleci geriye kaymamalı.
        $maxId = (int) Order::query()
            ->whereDate('order_date', BusinessTime::now()->toDateString())
            ->max('order_id');

        return $this->json([
            'data' => $orders->map(
                fn(Order $order): array => $this->presenter->kitchen($order),
            )->all(),
            'server_time' => Carbon::now()->utc()->toIso8601ZuluString(),
            'max_id' => $maxId,
        ]);
    }

    public function setStatus(Request $request, int $order): JsonResponse
    {
        $data = $request->validate([
            'status' => ['required', 'string', Rule::in(OrderStatusTransition::CODES)],
        ]);

        $model = $this->findOrder($order);
        $updated = $this->transitions->apply($model, $data['status']);

        return $this->json($this->presenter->kitchen($updated));
    }

    /**
     * Fiş verisi. Yazdırma **metnini** sunucu hazırlar, KDS yalnızca
     * ESC/POS'a çevirip basar — ne yazacağına karar istemcide değildir.
     */
    public function receipt(Request $request, int $order): JsonResponse
    {
        $data = $request->validate([
            'type' => ['required', Rule::in(PrintJob::TYPES)],
        ]);

        $model = $this->findOrder($order);

        return $this->json(match ($data['type']) {
            PrintJob::TYPE_KITCHEN => $this->receipts->kitchen($model),
            default => $this->receipts->customer($model),
        });
    }

    /**
     * Fiş basıldı bildirimi. İdempotenttir — KDS ağ hatasında tekrar
     * gönderirse yeni kayıt açılmaz (`docs/10-test-kabul.md` S4).
     */
    public function ackPrint(Request $request, int $order): JsonResponse
    {
        $data = $request->validate([
            'type' => ['required', Rule::in(PrintJob::TYPES)],
            'printed_at' => ['required', 'date'],
        ]);

        $model = $this->findOrder($order);

        /** @var KitchenDevice $device */
        $device = $request->user();

        PrintJob::record(
            (int) $model->order_id,
            $data['type'],
            Carbon::parse($data['printed_at']),
            (int) $device->id,
        );

        return $this->noContent();
    }

    public function productionList(): JsonResponse
    {
        return $this->json([
            'data' => $this->production->today(),
            'as_of' => Carbon::now()->utc()->toIso8601ZuluString(),
        ]);
    }

    /**
     * Canlılık bildirimi.
     *
     * `last_seen_at` güncellemesi `bld.scope` middleware'inde yapılır — her
     * mutfak isteği canlılık kanıtıdır, yalnızca heartbeat değil.
     */
    public function heartbeat(): JsonResponse
    {
        return $this->json([
            'server_time' => Carbon::now()->utc()->toIso8601ZuluString(),
            'min_supported_version' => '1.0.0',
        ]);
    }

    /** @throws ApiException */
    private function findOrder(int $orderId): Order
    {
        $order = Order::where('order_id', $orderId)->first();

        if ($order === null) {
            throw ApiException::notFound('Sipariş bulunamadı.');
        }

        return $order;
    }

    /** @return list<int> */
    private function terminalStatusIds(): array
    {
        return \Igniter\Admin\Models\Status::query()
            ->whereIn('status_code', [
                OrderStatusTransition::DELIVERED,
                OrderStatusTransition::CANCELLED,
            ])
            ->pluck('status_id')
            ->map(intval(...))
            ->all();
    }
}
