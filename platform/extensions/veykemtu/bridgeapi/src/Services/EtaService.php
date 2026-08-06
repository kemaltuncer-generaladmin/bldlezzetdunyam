<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Igniter\Local\Models\Location;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

/**
 * "Yemeğim ne zaman gelir?" sorusunun cevabı.
 *
 * Sipariş akışında müşteri teslim saatini seçebiliyordu ama **ne kadar
 * sürdüğünü bilmeden** seçiyordu. Sonuç: gerçekçi olmayan saatler seçiliyor,
 * mutfak yetiştiremiyor, müşteri "geç kaldınız" diyor. Oysa gecikme yok —
 * baştan yanlış beklenti kurulmuş.
 *
 * ## Neden tek sayı değil, aralık?
 *
 * "45 dakika" demek bir taahhüttür ve 47. dakikada ihlal edilir. "40–55
 * dakika" hem dürüst hem de mutfağa nefes alanı bırakıyor. Yemek sipariş
 * uygulamalarının tamamı bu yüzden aralık gösteriyor.
 *
 * ## Neden ölçüm, elle girilen değer değil?
 *
 * Elle girilen süre iyimser olmaya meyillidir ve kimse onu güncellemeyi
 * hatırlamaz; mutfak hızlanır ya da yavaşlar, panel aynı kalır. Bu yüzden
 * yeterli veri biriktiğinde GERÇEK ölçüm kullanılıyor.
 *
 * Elle girilen değer yine de gerekli: yeni kurulan bir sistemde hiç sipariş
 * yokken de bir cevap verebilmek için.
 */
final class EtaService
{
    /**
     * Ölçüme geçmek için gereken en az tamamlanmış sipariş.
     *
     * Üç siparişin ortalaması, biri çok geciktiğinde tamamen kayıyor.
     * Sekiz, hem erken devreye girecek kadar küçük hem de tek bir aykırı
     * değerin sonucu belirlemesini engelleyecek kadar büyük.
     */
    private const int MIN_SAMPLES = 8;

    /** Ölçüm penceresi. Daha eski veriler mutfağın bugünkü hâlini yansıtmıyor. */
    private const int LOOKBACK_DAYS = 14;

    /**
     * Aykırı değer sınırı (dakika).
     *
     * Ertesi güne sarkan, unutulup elle kapatılan veya test amaçlı açılmış
     * siparişler ortalamayı saatlerce yukarı çekiyor. Bu sınırın üstündeki
     * kayıtlar ölçüme girmiyor.
     */
    private const int OUTLIER_CEILING = 240;

    private const int CACHE_MINUTES = 10;

    public function __construct(private readonly LocationGate $gate) {}

    /**
     * @param  'delivery'|'pickup'  $deliveryType
     * @return array{min_minutes:int, max_minutes:int, source:'measured'|'configured', busy:bool}
     */
    public function estimate(Location $location, string $deliveryType = 'delivery'): array
    {
        $isDelivery = $deliveryType === 'delivery';
        $busy = $this->gate->isBusy($location);

        $measured = $this->measuredMinutes($location, $deliveryType);

        if ($measured !== null) {
            [$min, $max] = $measured;
            $source = 'measured';
        } else {
            $base = $this->gate->prepMinutes($location)
                + ($isDelivery ? $this->gate->deliveryMinutes($location) : 0);

            /*
             * Yapılandırılmış değerden aralık türetilirken alt uç olduğu gibi
             * alınıp üst uca pay ekleniyor. Alt ucu da düşürseydik, mutfağın
             * hiç ulaşamayacağı bir söz vermiş olurduk.
             */
            $min = $base;
            $max = (int) ceil($base * 1.35);
            $source = 'configured';
        }

        if ($busy) {
            $extra = $this->gate->busyExtraMinutes($location);
            $min += $extra;
            $max += $extra;
        }

        // Beş dakikaya yuvarlanıyor: "37–51 dakika" sahte bir kesinlik iddiası.
        return [
            'min_minutes' => $this->roundToFive($min),
            'max_minutes' => max($this->roundToFive($max), $this->roundToFive($min) + 5),
            'source' => $source,
            'busy' => $busy,
        ];
    }

    /**
     * Gerçekleşmiş sürelerden aralık. Yetersiz veri varsa `null`.
     *
     * @param  'delivery'|'pickup'  $deliveryType
     * @return array{0:int, 1:int}|null
     */
    private function measuredMinutes(Location $location, string $deliveryType): ?array
    {
        $key = sprintf('veykemtu.eta.%d.%s', (int) $location->getKey(), $deliveryType);

        /** @var array{0:int,1:int}|null $result */
        $result = Cache::remember(
            $key,
            now()->addMinutes(self::CACHE_MINUTES),
            fn (): ?array => $this->computeMeasured($location, $deliveryType),
        );

        return $result;
    }

    /** @return array{0:int, 1:int}|null */
    private function computeMeasured(Location $location, string $deliveryType): ?array
    {
        /*
         * Gel-al siparişte müşteri "hazır" olduğunda geliyor; teslim zamanı
         * onun elinde. Bu yüzden ölçüm `hazir`'e kadar; adrese teslimde
         * `teslim_edildi`'ye kadar.
         */
        $finalStatus = $deliveryType === 'pickup' ? 'hazir' : 'teslim_edildi';

        $minutes = DB::table('orders')
            ->join('status_history', function ($join): void {
                $join->on('status_history.object_id', '=', 'orders.order_id')
                    ->where('status_history.object_type', '=', 'orders');
            })
            ->join('statuses', 'statuses.status_id', '=', 'status_history.status_id')
            ->where('statuses.status_code', $finalStatus)
            ->where('orders.location_id', $location->getKey())
            ->where('orders.order_type', $deliveryType)
            ->where('status_history.created_at', '>=', now()->subDays(self::LOOKBACK_DAYS))
            ->selectRaw('TIMESTAMPDIFF(MINUTE, orders.created_at, status_history.created_at) AS dk')
            ->pluck('dk')
            ->map(static fn (mixed $value): int => (int) $value)
            ->filter(static fn (int $value): bool => $value > 0 && $value <= self::OUTLIER_CEILING)
            ->sort()
            ->values();

        if ($minutes->count() < self::MIN_SAMPLES) {
            return null;
        }

        /*
         * Ortalama değil YÜZDELİK kullanılıyor. Ortalama, tek bir çok geç
         * siparişle yukarı kayıyor; medyan tipik durumu, 80. yüzdelik ise
         * "kötü ama olağan" durumu gösteriyor. Aralığın alt ucu tipik,
         * üst ucu gerçekçi kötü senaryo.
         */
        return [
            $this->percentile($minutes->all(), 0.5),
            $this->percentile($minutes->all(), 0.8),
        ];
    }

    /** @param  list<int>  $sorted */
    private function percentile(array $sorted, float $ratio): int
    {
        $index = (int) floor($ratio * (count($sorted) - 1));

        return $sorted[$index];
    }

    private function roundToFive(int $minutes): int
    {
        return max(5, (int) (ceil($minutes / 5) * 5));
    }
}
