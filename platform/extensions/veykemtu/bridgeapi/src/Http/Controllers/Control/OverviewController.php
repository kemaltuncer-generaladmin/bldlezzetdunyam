<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Control;

use Igniter\Admin\Models\Status;
use Igniter\Cart\Models\Order;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Carbon;
use Veykemtu\BridgeApi\Models\KitchenDevice;
use Veykemtu\BridgeApi\Models\PrintJob;
use Veykemtu\BridgeApi\Services\OrderPresenter;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Kontrol Merkezi paneli açılış özeti (`GET /api/control/kds/overview`).
 *
 * TEK İSTEK, ÇÜNKÜ AÇILIŞ EKRANI. Cihaz listesi, sipariş listesi ve fiş
 * kaydını ayrı ayrı çekip saydırmak, panel her açıldığında üç ağır
 * sorgu demekti; sayılar da istemcide hesaplanırdı ve "kaç sipariş
 * aktif" sorusunun cevabı istemci sürümüne göre değişirdi.
 *
 * BURADAKİ SAYILAR TANIMDIR, TAHMİN DEĞİL — her birinin nereden geldiği
 * aşağıda tek tek yazılı.
 */
class OverviewController extends ControlController
{
    public function __construct(
        private readonly OrderPresenter $presenter,
        private readonly OrderStatusTransition $transitions,
    ) {}

    public function show(): JsonResponse
    {
        $devices = KitchenDevice::query()->get();
        $live = $devices->reject(fn(KitchenDevice $device): bool => $device->isRevoked());

        $onlineSince = Carbon::now()->subMinutes(KitchenDevice::ONLINE_THRESHOLD_MINUTES);

        $active = Order::query()
            ->whereNotIn('status_id', $this->terminalStatusIds())
            ->get();

        return $this->json([
            'devices' => [
                'total' => $devices->count(),
                'online' => $live
                    ->filter(fn(KitchenDevice $device): bool => $device->last_seen_at !== null
                        && $device->last_seen_at->greaterThanOrEqualTo($onlineSince))
                    ->count(),
                'revoked' => $devices->count() - $live->count(),
                // `printer_ok === false` SAYILIR, `null` SAYILMAZ: hiç
                // sağlık bildirmemiş bir kasa arızalı değil, sessizdir.
                // İkisini toplamak, yeni kurulan her kasayı arıza
                // sayacına yazardı.
                'printer_fault' => $live
                    ->filter(static fn(KitchenDevice $device): bool => $device->printer_ok === false)
                    ->count(),
                // Kasanın BEYAN ettiği kuyruk boyu; sunucu doğrulayamaz.
                // Fiş kuyruğu kasanın diskinde, `veykemtu_print_jobs`
                // yalnız denetim kaydı (bkz. `PrintJobController`).
                'queue_pending' => (int) $live->sum(
                    static fn(KitchenDevice $device): int => (int) ($device->print_queue_pending ?? 0),
                ),
                'queue_failed' => (int) $live->sum(
                    static fn(KitchenDevice $device): int => (int) ($device->print_queue_failed ?? 0),
                ),
            ],
            'orders' => [
                'active' => $active->count(),
                'by_status' => $this->byStatus($active),
                'today' => $this->ordersToday(),
                'late' => $this->lateCount($active),
            ],
            'print_jobs' => [
                'today' => PrintJob::query()
                    ->where('printed_at', '>=', BusinessTime::startOfBusinessDay())
                    ->count(),
            ],
            'server_time' => $this->serverTime(),
        ]);
    }

    /**
     * Aktif siparişlerin durum dağılımı — toplamı `orders.active`'e eşittir.
     *
     * TERMINAL KODLAR ANAHTAR OLARAK BULUNMAZ: `teslim_edildi` ve `iptal`
     * zaten aktif kümenin dışında ve her seferinde `0` dönerlerdi.
     * Kalan beş kod ise sipariş yokken bile `0` ile duruyor — istemcinin
     * eksik anahtar için savunma yazmasına gerek kalmasın.
     *
     * @param  Collection<int, Order>  $active
     * @return array<string, int>
     */
    private function byStatus(Collection $active): array
    {
        $counts = array_fill_keys(
            array_values(array_diff(OrderStatusTransition::CODES, [
                OrderStatusTransition::DELIVERED,
                OrderStatusTransition::CANCELLED,
            ])),
            0,
        );

        foreach ($active as $order) {
            // Kod `OrderStatusTransition`'dan okunuyor: kodsuz bir durum
            // (TastyIgniter varsayılanı) orada `yeni` sayılıyor ve iki
            // yerde iki farklı cevap çıkmasın.
            $code = $this->transitions->codeOf($order);
            $counts[$code] = ($counts[$code] ?? 0) + 1;
        }

        return $counts;
    }

    /**
     * Bugün oluşturulan sipariş sayısı — İPTALLER HARİÇ.
     *
     * `KitchenController::ordersToday()` ile aynı tanım (o metot `private`
     * ve o denetleyici K-21 kapsamının dışında). Gün sınırı
     * Europe/Istanbul: UTC gece yarısı kullanılsaydı 00:00–03:00 arası
     * siparişler "dün" sayılırdı ve catering'de gece siparişi olağan.
     */
    private function ordersToday(): int
    {
        $cancelled = Status::query()
            ->where('status_code', OrderStatusTransition::CANCELLED)
            ->value('status_id');

        return Order::query()
            ->where('created_at', '>=', BusinessTime::startOfBusinessDay())
            ->when($cancelled !== null, fn($query) => $query->where('status_id', '!=', $cancelled))
            ->count();
    }

    /**
     * Geciken aktif sipariş sayısı.
     *
     * TANIM: **planlanan teslim saati geçmiş ve hâlâ teslim edilmemiş**
     * sipariş. Sunucunun kendi başına bilebileceği tek dürüst tanım bu.
     *
     * NEDEN KASANIN `late_after_minutes` EŞİĞİ KULLANILMIYOR: o eşik
     * CİHAZ BAŞINA ayarlanıyor ve `null` bırakıldığında kasanın kendi
     * derleme varsayılanı geçerli oluyor — sunucu o varsayılanı bilmiyor.
     * İki kasanın farklı eşiği olduğunda "hangi kasanın gecikmesi" diye
     * bir soru doğardı; oysa Kontrol Merkezi'ndeki sayı işletmenin
     * tamamına ait olmalı.
     *
     * "EN KISA SÜREDE" SİPARİŞLER SAYILMAZ. `order_time_is_asap` olan bir
     * siparişin planlanmış bir saati yoktur (`OrderPresenter::requestedAt`
     * `null` döner); onları saymak için bir bekleme eşiği uydurmak
     * gerekirdi ve uydurulan her eşik yanlış bir alarm üretirdi.
     *
     * @param  Collection<int, Order>  $active
     */
    private function lateCount(Collection $active): int
    {
        $now = Carbon::now();

        return $active
            ->filter(function (Order $order) use ($now): bool {
                $planned = $this->presenter->requestedAt($order);

                return $planned !== null && Carbon::parse($planned)->lessThan($now);
            })
            ->count();
    }
}
