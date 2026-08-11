<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Igniter\Cart\Models\Order;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Models\ClosedDay;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Mutfağın abonelik üretim planı — `docs/05-mutfakapp.md` §15 (K-15).
 *
 * NEDEN AYRI SERVİS: KDS'in abonelik ekranı üç ayrı soruya cevap veriyor
 * ve üçü de farklı yerlerden geliyor:
 *
 *   1. **Ne pişecek?** Üretilmiş siparişlerin ürün bazında toplamı.
 *   2. **Nereye, kaçta?** Teslimat noktası ve saat kırılımı.
 *   3. **Ne EKSİK?** — en önemlisi ve en kolay atlanan. Duraklatılmış
 *      abonelik, istisna girilmiş gün, kapalı gün ve **henüz üretim
 *      koşmamış yarın**. Bunlar görünmezse mutfak sabah "bugün az
 *      sipariş var" der, oysa üretim hiç çalışmamıştır.
 *
 * Üçüncüsü olmadan ekran, olmayan bir şeyin yokluğunu gösteremez.
 */
class SubscriptionKitchenPlan
{
    public function __construct(
        private readonly OrderPresenter $presenter,
    ) {}

    /**
     * Bir günün planı.
     *
     * @return array<string, mixed>
     */
    public function forDate(Carbon $date): array
    {
        $orders = $this->ordersOn($date);

        return [
            'date' => $date->toDateString(),
            'orders' => $orders,
            'totals' => $this->totals($date),
            'warnings' => $this->warnings($date, $orders),
        ];
    }

    /**
     * Abonelikten doğan, o günün aktif siparişleri.
     *
     * Teslimat saatine göre sıralı: mutfak sabah listeye baktığında
     * "önce hangisi çıkacak" sorusunun cevabını görmeli.
     *
     * @return list<array<string, mixed>>
     */
    private function ordersOn(Carbon $date): array
    {
        $terminal = $this->terminalStatusIds();

        return Order::query()
            ->whereNotNull('bld_subscription_id')
            ->whereNotIn('status_id', $terminal)
            ->whereDate('order_date', $date->toDateString())
            ->orderBy('order_time')
            ->orderBy('order_id')
            ->get()
            ->map(function (Order $order): array {
                $row = $this->presenter->kitchen($order);

                // Abonelik ekranına özgü ekler. `KitchenOrder` şemasına
                // GİRMİYOR: pano kartının bunlara ihtiyacı yok ve her
                // yoklamada taşımak boşuna bant genişliği.
                $row['delivery_time'] = $order->order_time !== null
                    ? substr((string) $order->order_time, 0, 5)
                    : null;
                $row['subscription_label'] = $this->labelFor($order);

                return $row;
            })
            ->all();
    }

    /**
     * Ürün bazında toplam — mutfağın sabah baktığı tek şey.
     *
     * SQL ile toplanıyor, PHP'de değil: 40 siparişlik bir günde satırları
     * çekip toplamak, veritabanının zaten yaptığı işi tekrar etmek olurdu.
     *
     * @return list<array{name:string, quantity:int}>
     */
    private function totals(Carbon $date): array
    {
        $terminal = $this->terminalStatusIds();

        return DB::table('order_menus')
            ->join('orders', 'orders.order_id', '=', 'order_menus.order_id')
            ->whereNotNull('orders.bld_subscription_id')
            ->whereNotIn('orders.status_id', $terminal)
            ->whereDate('orders.order_date', $date->toDateString())
            ->groupBy('order_menus.name')
            ->orderByDesc(DB::raw('SUM(order_menus.quantity)'))
            ->get([
                'order_menus.name',
                DB::raw('SUM(order_menus.quantity) AS quantity'),
            ])
            ->map(static fn($row): array => [
                'name' => (string) $row->name,
                'quantity' => (int) $row->quantity,
            ])
            ->all();
    }

    /**
     * O gün için uyarılar — "ne EKSİK" sorusunun cevabı.
     *
     * @param  list<array<string, mixed>>  $orders
     * @return list<array{kind:string, message:string}>
     */
    private function warnings(Carbon $date, array $orders): array
    {
        $warnings = [];
        $dateString = $date->toDateString();

        if (ClosedDay::where('closed_on', $dateString)->exists()) {
            $warnings[] = [
                'kind' => 'closed_day',
                'message' => 'Bu gün kapalı gün olarak işaretli; abonelik üretilmez.',
            ];
        }

        // ÜRETİM KOŞMADI MI? En sinsi durum: sipariş yok ama olması
        // gerekiyor. Mutfak "bugün abonelik yok" sanıp hazırlık yapmıyor,
        // akşam 22:00'deki cron çalışmamış oluyor.
        $expected = $this->expectedSubscriptionCount($date);
        if ($expected > 0 && $orders === []) {
            $warnings[] = [
                'kind' => 'not_generated',
                'message' => "Bu gün için {$expected} abonelik bekleniyor ama "
                    .'hiç sipariş üretilmemiş. `veykemtu:abonelik-uret` '
                    .'çalışmamış olabilir.',
            ];
        }

        foreach ($this->pausedOn($date) as $label) {
            $warnings[] = [
                'kind' => 'paused',
                'message' => "{$label} — abonelik bu tarihte duraklatılmış.",
            ];
        }

        foreach ($this->exceptionsOn($date) as $note) {
            $warnings[] = ['kind' => 'exception', 'message' => $note];
        }

        return $warnings;
    }

    /**
     * O gün çalışması beklenen abonelik sayısı.
     *
     * `runsOnDate()` modelin kendi kuralı; burada yeniden yazmıyoruz —
     * iki ayrı kural, iki ayrı cevap demek olurdu.
     */
    private function expectedSubscriptionCount(Carbon $date): int
    {
        return Subscription::query()
            ->where('status', Subscription::STATUS_ACTIVE)
            ->get()
            ->filter(fn(Subscription $s): bool => $s->runsOnDate($date))
            ->count();
    }

    /** @return list<string> */
    private function pausedOn(Carbon $date): array
    {
        $dateString = $date->toDateString();

        return DB::table('veykemtu_subscription_pauses')
            ->join(
                'veykemtu_subscriptions',
                'veykemtu_subscriptions.id',
                '=',
                'veykemtu_subscription_pauses.subscription_id',
            )
            ->whereDate('veykemtu_subscription_pauses.start_date', '<=', $dateString)
            ->whereDate('veykemtu_subscription_pauses.end_date', '>=', $dateString)
            ->pluck('veykemtu_subscriptions.id')
            ->map(static fn($id): string => 'Abonelik #'.$id)
            ->all();
    }

    /** @return list<string> */
    private function exceptionsOn(Carbon $date): array
    {
        return DB::table('veykemtu_subscription_exceptions')
            ->whereDate('service_date', $date->toDateString())
            ->get()
            ->map(static function ($row): string {
                $id = (int) $row->subscription_id;

                return (bool) $row->skip
                    ? "Abonelik #{$id} — bugün atlanıyor (istisna)."
                    : "Abonelik #{$id} — adet {$row->quantity_override} "
                        .'olarak değiştirilmiş (istisna).';
            })
            ->all();
    }

    private function labelFor(Order $order): ?string
    {
        $name = trim(($order->first_name ?? '').' '.($order->last_name ?? ''));

        return $name === '' ? null : $name;
    }

    /** @return list<int> */
    private function terminalStatusIds(): array
    {
        return DB::table('statuses')
            ->whereIn('status_code', [
                OrderStatusTransition::DELIVERED,
                OrderStatusTransition::CANCELLED,
            ])
            ->pluck('status_id')
            ->map(intval(...))
            ->all();
    }

    /**
     * Bugün + yarın + haftanın kalanı.
     *
     * HAFTA İSTEĞE BAĞLI: her yoklamada yedi günü hesaplamak, mutfağın
     * bakmadığı altı gün için boşuna sorgu demek. Ekran sekmeye
     * dokunduğunda istiyor.
     *
     * @return array<string, mixed>
     */
    public function plan(string $range): array
    {
        $today = BusinessTime::now()->startOfDay();

        $days = match ($range) {
            'week' => array_map(
                fn(int $offset): array => $this->forDate($today->copy()->addDays($offset)),
                range(0, 6),
            ),
            'tomorrow' => [$this->forDate($today->copy()->addDay())],
            default => [
                $this->forDate($today),
                $this->forDate($today->copy()->addDay()),
            ],
        };

        return [
            'days' => $days,
            'server_time' => Carbon::now()->utc()->toIso8601ZuluString(),
        ];
    }
}
