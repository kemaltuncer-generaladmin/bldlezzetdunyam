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
use Veykemtu\BridgeApi\Models\KitchenCommand;
use Veykemtu\BridgeApi\Models\KitchenDevice;
use Veykemtu\BridgeApi\Models\PrintJob;
use Igniter\Local\Models\Location;
use Veykemtu\BridgeApi\Services\KitchenDeviceSettings;
use Veykemtu\BridgeApi\Services\LocationGate;
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
            // `boolean` KURALI KULLANILMAZ — sahada KDS'i kör eden hata buydu.
            //
            // Laravel'in `boolean` kuralı yalnızca `1`, `0`, `"1"`, `"0"` ve
            // gerçek boolean kabul eder; `"true"` dizgesini REDDEDER. Sorgu
            // dizesinde ise boolean ancak metin olarak ifade edilebilir ve
            // OpenAPI'nin standart serileştirmesi `?include_completed=true`
            // üretir. Sonuç: KDS'in artımlı yoklaması HER ÇAĞRIDA 422 aldı,
            // ekran tam listeye düşüp geri geldi ve bağlantı göstergesi
            // sürekli yanıp söndü.
            //
            // `$request->boolean()` bu değerlerin hepsini doğru okur;
            // doğrulama yalnızca anlamsız girdiyi eliyor.
            'include_completed' => ['sometimes', Rule::in(['1', '0', 'true', 'false'])],
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
            // Gelen değer UTC'dir; `updated_at` depolama zaman diliminde
            // saklanır. Dönüştürmeden karşılaştırmak, saat farkı kadar
            // geçmişteki her siparişi "yeni güncellenmiş" gösterir ve
            // artımlı polling'i tamamen etkisiz kılar.
            $query->where('updated_at', '>', BusinessTime::forStorage(
                Carbon::parse((string) $request->query('since')),
            ));
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
            BusinessTime::forStorage(Carbon::parse($data['printed_at'])),
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

    /**
     * Kasa sağlık bildirimi — `docs/03-api-sozlesmesi.md` §Mutfak.
     *
     * ÇİFT YÖNLÜ, ve bu bilinçli: cihaz kendi bilebileceğini (yazıcı,
     * kuyruk, sürüm) bildirir; sunucu cihazın bilemeyeceğini (bugünkü
     * toplam sipariş) döndürür. Ekrandaki sağlık paneli bunların ikisini
     * birden gösteriyor ve iki ayrı çağrı yapmasının anlamı yok.
     *
     * Bugünkü sayıyı cihazın kendisi hesaplayamaz: mutfak listesi
     * yalnızca AKTİF siparişleri taşır, teslim edilenler düşer. Vardiya
     * boyunca kaç sipariş geçtiğini yalnızca sunucu bilir.
     *
     * Bildirilen değerler DOĞRULANMAZ, yalnızca kaydedilir. Yazıcının
     * gerçekten çalıştığını sunucudan anlamanın yolu yok; cihazın
     * beyanına güveniyoruz ve zaman damgasıyla birlikte saklıyoruz ki
     * bayat veri taze sanılmasın.
     */
    public function health(
        Request $request,
        KitchenDeviceSettings $settings,
    ): JsonResponse {
        $data = $request->validate([
            'printer_ok' => ['required', 'boolean'],
            'print_queue_pending' => ['required', 'integer', 'min:0', 'max:100000'],
            'print_queue_failed' => ['required', 'integer', 'min:0', 'max:100000'],
            'app_version' => ['sometimes', 'string', 'max:32'],
            // Bir önceki turda teslim edilen komutların sonuçları.
            'command_results' => ['sometimes', 'array', 'max:50'],
            'command_results.*.id' => ['required', 'integer'],
            'command_results.*.ok' => ['required', 'boolean'],
            'command_results.*.message' => ['sometimes', 'nullable', 'string', 'max:255'],
        ]);

        $device = $request->user();

        if (!$device instanceof KitchenDevice) {
            throw ApiException::unauthenticated();
        }

        // `saveQuietly` + `withoutTimestamps`: sağlık dakikada bir gelir,
        // `updated_at`'i kirletip model olaylarını tetiklemesine gerek yok.
        $this->recordCommandResults($device, $data['command_results'] ?? []);

        KitchenDevice::withoutTimestamps(fn() => $device->forceFill([
            'health_reported_at' => Carbon::now(),
            'printer_ok' => (bool) $data['printer_ok'],
            'print_queue_pending' => (int) $data['print_queue_pending'],
            'print_queue_failed' => (int) $data['print_queue_failed'],
            'app_version' => $data['app_version'] ?? $device->app_version,
        ])->saveQuietly());

        return $this->json([
            'server_time' => Carbon::now()->utc()->toIso8601ZuluString(),
            'orders_today' => $this->ordersToday(),
            'orders_active' => $this->activeOrderCount(),
            // Ayarlar SAĞLIK YANITINDA dönüyor, ayrı bir uçta değil:
            // kasa zaten dakikada bir buraya geliyor ve ikinci bir
            // yoklama döngüsü kurmanın anlamı yok. Dokunulmamış alanlar
            // `null` gelir; kasa o alanda kendi derleme varsayılanını
            // kullanır.
            'settings' => $settings->forDevice($device),
            // Bekleyen komutlar. Kasa bunları çalıştırıp sonuçlarını bir
            // sonraki bildirimde `command_results` ile geri gönderir.
            'commands' => $this->takeCommands($device),
        ]);
    }

    /**
     * Kasanın bildirdiği komut sonuçlarını kaydeder.
     *
     * Sonucu gelen komut bir daha gönderilmez. Kasa başka bir cihazın
     * komut kimliğini bildirse bile o satıra dokunulmaz — kimlik sorgusu
     * cihazla sınırlı.
     *
     * @param  array<int, array<string, mixed>>  $results
     */
    private function recordCommandResults(KitchenDevice $device, array $results): void
    {
        foreach ($results as $result) {
            KitchenCommand::query()
                ->where('device_id', $device->id)
                ->where('id', (int) $result['id'])
                ->whereNull('executed_at')
                ->update([
                    'executed_at' => Carbon::now(),
                    'succeeded' => (bool) $result['ok'],
                    'result' => isset($result['message'])
                        ? mb_substr((string) $result['message'], 0, 255)
                        : null,
                ]);
        }
    }

    /**
     * Bekleyen komutları döndürür ve teslim edilmiş işaretler.
     *
     * @return list<array<string, mixed>>
     */
    private function takeCommands(KitchenDevice $device): array
    {
        $commands = KitchenCommand::pendingFor($device->id)->limit(20)->get();

        if ($commands->isEmpty()) {
            return [];
        }

        KitchenCommand::query()
            ->whereIn('id', $commands->pluck('id'))
            ->update(['delivered_at' => Carbon::now()]);

        return $commands
            ->map(static fn(KitchenCommand $c): array => [
                'id' => (int) $c->id,
                'command' => (string) $c->command,
                'payload' => $c->payload ?? [],
            ])
            ->all();
    }

    /**
     * Bugün oluşturulan sipariş sayısı — iptaller HARİÇ.
     *
     * Gün sınırı Europe/Istanbul'a göre: sunucu UTC tutuyor ve gece
     * yarısından sonraki üç saatlik siparişler "dün" görünürdü
     * (`docs/03` §1.3).
     */
    private function ordersToday(): int
    {
        $cancelled = \Igniter\Admin\Models\Status::query()
            ->where('status_code', OrderStatusTransition::CANCELLED)
            ->value('status_id');

        return Order::query()
            ->where('created_at', '>=', BusinessTime::startOfBusinessDay())
            ->when($cancelled !== null, fn($q) => $q->where('status_id', '!=', $cancelled))
            ->count();
    }

    /** Mutfak ekranında kart olarak duran sipariş sayısı. */
    private function activeOrderCount(): int
    {
        return Order::query()
            ->whereNotIn('status_id', $this->terminalStatusIds())
            ->count();
    }

    /**
     * Yoğunluk şalteri — mutfaktaki tek tuş.
     *
     * Sipariş almayı DURDURMAZ. Açıkken müşteri arayüzlerinde "hazırlanması
     * uzun sürebilir" uyarısı çıkar, admin panelde de görünür. Siparişi
     * gerçekten kesmek `ordering_enabled` şalteridir ve yöneticinindir —
     * mutfak personeli tek tuşla cirosu kapatabilmemeli.
     *
     * Durum vitrine yazılır, cihaza değil: iki kasa olsa ikisi de aynı
     * şeyi göstermeli ve müşteri tarafı zaten vitrini okuyor.
     */
    public function setBusy(Request $request, LocationGate $gate): JsonResponse
    {
        $data = $request->validate(['busy' => ['required', 'boolean']]);

        $location = Location::query()
            ->where('location_status', true)
            ->orderByDesc('is_default')
            ->first();

        if ($location === null) {
            throw ApiException::notFound('Vitrin bulunamadı.');
        }

        $gate->setBusy($location, (bool) $data['busy']);

        return $this->json([
            'busy' => $gate->isBusy($location),
            'busy_message' => $gate->busyMessage($location),
            'server_time' => Carbon::now()->utc()->toIso8601ZuluString(),
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
