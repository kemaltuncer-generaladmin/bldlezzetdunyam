<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Control;

use Igniter\Admin\Models\Status;
use Igniter\Cart\Models\Order;
use Igniter\Local\Models\Location;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Veykemtu\BridgeApi\Admin\SettingsRepository;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Models\QuoteRequest;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Models\SubscriptionContract;
use Veykemtu\BridgeApi\Models\SubscriptionPayment;
use Veykemtu\BridgeApi\Services\LocationGate;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;
use Veykemtu\BridgeApi\Services\OrderingWindow;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Kontrol Merkezi — açılış özeti (`docs/control/dashboard.md`).
 *
 * TEK İSTEK, ÇÜNKÜ AÇILIŞ EKRANI. On farklı uçtan sayı toplamak, panelin
 * her açılışında on ağır sorgu demekti; sayılar istemcide hesaplansaydı
 * "kaç sipariş aktif" sorusunun cevabı panel sürümüne göre değişirdi.
 *
 * `control/kds/overview` İLE KARIŞTIRILMAMALI (`OverviewController`): o uç
 * KDS YÖNETİMİ ekranının dar özetidir (cihaz, fiş, aktif sipariş) ve
 * olduğu gibi kalır. Bu uç işletmenin tamamına bakar.
 *
 * SAYAÇLAR `COUNT` İLE ALINIR, koleksiyon çekilip PHP'de sayılmaz. Bu uç
 * 30 saniyede bir yoklanıyor; `OverviewController` bugün aktif siparişleri
 * `get()` ile çekiyor ve otuz siparişte sorun değil ama üç yüzde olur.
 *
 * İZLEME BLOKLARI (`devices`, `monitor`) `MonitorController::summaryData()`
 * ÇAĞRILARAK üretiliyor, ikinci kez hesaplanmıyor. İki ekranın aynı duruma
 * bakıp farklı sayı göstermesi, hangisine inanılacağını belirsiz kılardı.
 *
 * ÖNBELLEK AÇILMADI. Sözleşme onu isteğe bağlı bırakıyor; açılsaydı
 * "satışı durdurdum ama panel hâlâ açık gösteriyor" gecikmesi sözleşmenin
 * parçası olurdu. Ölçüm gerektiğinde açılabilir ve o gün yanıt
 * `meta.cached_at` taşımalıdır.
 */
class DashboardController extends ControlController
{
    /** `menu_missing` denetiminin ufku — bugünden itibaren üç servis günü. */
    private const int MENU_HORIZON_DAYS = 3;

    /** `blocked_items` en çok bu kadar kalem taşır. */
    private const int MAX_BLOCKED_ITEMS = 10;

    /** `pending_tasks` en çok bu kadar madde döner. */
    private const int MAX_PENDING_TASKS = 12;

    public function __construct(
        private readonly LocationGate $gate,
        private readonly OrderingWindow $window,
        private readonly SettingsRepository $settings,
        private readonly MonitorController $monitor,
    ) {}

    public function overview(Request $request): JsonResponse
    {
        $request->validate([
            'location_id' => ['sometimes', 'integer'],
            'date' => ['sometimes', 'date_format:Y-m-d'],
        ]);

        $location = $this->location($request);
        $date = $request->filled('date')
            ? Carbon::parse((string) $request->query('date'), BusinessTime::ZONE)->startOfDay()
            // Varsayılan BUGÜN ve bu bir SERVİS GÜNÜDÜR, oluşturma günü
            // değil: "bugün ne pişiyor" sorusu panelin ilk sorusu.
            : BusinessTime::now()->startOfDay();

        $sales = $this->salesBlock($location, $date);
        $orders = $this->ordersBlock($location, $date);
        $capacity = $this->capacityBlock($location, $date);
        $subscriptions = $this->subscriptionsBlock($location, $date);
        $monitor = $this->monitor->summaryData();

        return $this->json([
            'data' => [
                'date' => $date->toDateString(),
                'location_id' => (int) $location->location_id,
                'sales' => $sales,
                'orders' => $orders,
                'capacity' => $capacity,
                'subscriptions' => $subscriptions,
                'devices' => $monitor['devices'],
                'monitor' => [
                    'open_total' => $monitor['events']['open_total'],
                    'critical_open' => $monitor['events']['open']['critical'],
                    'error_open' => $monitor['events']['open']['error'],
                    'warning_open' => $monitor['events']['open']['warning'],
                    'health_status' => $monitor['health']['status'],
                ],
                'pending_tasks' => $this->pendingTasks(
                    $location,
                    $date,
                    $sales,
                    $orders,
                    $capacity,
                    $subscriptions,
                    $monitor,
                ),
            ],
            'server_time' => $this->serverTime(),
        ]);
    }

    // ── sales ─────────────────────────────────────────────────────────────

    /**
     * Satış şalteri ve kesim geri sayımı.
     *
     * `cutoff_at` BİR SONRAKİ kesim anıdır: bugünün kesimi geçtiyse
     * yarınınki. Geri sayımı sunucunun vermesi bilinçli — istemcinin kendi
     * saatini kullanması, saati kaymış bir makinede yanlış bir aciliyet
     * yaratırdı.
     *
     * @return array<string, mixed>
     */
    private function salesBlock(Location $location, Carbon $date): array
    {
        // SIRA ÖNEMLİ: `orderingEnabled()` süresi dolmuş bir durdurmayı
        // okuma anında temizliyor (`SettingsRepository::toControlData`
        // aynı sırayı kullanıyor).
        $enabled = $this->gate->orderingEnabled($location);
        $pausedUntil = $this->gate->pauseEndsAt($location);

        $todayCutoff = $this->window->cutoffFor($location, $date);
        $passedToday = $this->window->hasPassed($todayCutoff);

        [$nextCutoff, $nextDate] = $this->nextCutoff($location, $date, $todayCutoff, $passedToday);

        return [
            'ordering_enabled' => $enabled,
            'paused_until' => $pausedUntil?->utc()->toIso8601ZuluString(),
            'busy' => $this->gate->isBusy($location),
            // Gün içi saat YEREL (Europe/Istanbul), an ise UTC. İkisini
            // karıştırmamak sözleşmenin §6 kuralı.
            'cutoff_time' => $this->gate->orderCutoff($location),
            'cutoff_at' => $nextCutoff?->utc()->toIso8601ZuluString(),
            'cutoff_passed_for_today' => $passedToday,
            'seconds_to_next_cutoff' => $nextCutoff === null
                ? null
                : max(0, (int) Carbon::now()->diffInSeconds($nextCutoff, absolute: false)),
            'next_cutoff_date' => $nextDate?->toDateString(),
        ];
    }

    /**
     * Bir sonraki kesim anı ve ait olduğu servis günü.
     *
     * SERVİS OLMAYAN GÜN ATLANIR (hafta sonu, iş kararı 4). Cuma akşamı
     * "yarının kesimine 12 saat" demek, cumartesi hiç servis olmadığı için
     * yanlış bir aciliyet üretirdi.
     *
     * @return array{0: Carbon|null, 1: Carbon|null}
     */
    private function nextCutoff(
        Location $location,
        Carbon $date,
        ?Carbon $todayCutoff,
        bool $passedToday,
    ): array {
        if ($todayCutoff !== null && !$passedToday && $this->window->isServiceDay($date)) {
            return [$todayCutoff, $date->copy()];
        }

        // On dört gün yeter: haftalık döngüde servis günü olmayan en uzun
        // aralık iki gündür; sınır yalnız sonsuz döngüyü kesiyor.
        for ($i = 1; $i <= 14; $i++) {
            $candidate = $date->copy()->addDays($i);

            if (!$this->window->isServiceDay($candidate)) {
                continue;
            }

            $cutoff = $this->window->cutoffFor($location, $candidate);

            if ($cutoff !== null && !$this->window->hasPassed($cutoff)) {
                return [$cutoff, $candidate];
            }
        }

        // Kesim saati hiç tanımlı değilse `null` döner ve panel geri sayım
        // çizmez. Uydurulmuş bir saat, olmayan bir kurala göre alarm verirdi.
        return [null, null];
    }

    // ── orders ────────────────────────────────────────────────────────────

    /** @return array<string, mixed> */
    private function ordersBlock(Location $location, Carbon $date): array
    {
        $terminal = $this->terminalStatusIds();
        $cancelledId = $this->statusId(OrderStatusTransition::CANCELLED);
        $deliveredId = $this->statusId(OrderStatusTransition::DELIVERED);

        $byStatus = $this->activeByStatus($location, $terminal);
        $businessDayStart = BusinessTime::startOfBusinessDay();

        return [
            'by_status' => $byStatus,
            'active' => array_sum($byStatus),
            'delivered_today' => $deliveredId === null ? 0 : (int) Order::query()
                ->where('location_id', $location->location_id)
                ->where('created_at', '>=', $businessDayStart)
                ->where('status_id', $deliveredId)
                ->count(),
            'cancelled_today' => $cancelledId === null ? 0 : (int) Order::query()
                ->where('location_id', $location->location_id)
                ->where('created_at', '>=', $businessDayStart)
                ->where('status_id', $cancelledId)
                ->count(),
            /*
             * İŞLETME GÜNÜ (Europe/Istanbul) sınırında. UTC gece yarısı
             * kullanılsaydı 00:00–03:00 arası siparişler "dün" sayılırdı ve
             * catering'de gece siparişi olağan.
             */
            'created_today' => (int) Order::query()
                ->where('location_id', $location->location_id)
                ->where('created_at', '>=', $businessDayStart)
                ->count(),
            'late' => $this->lateCount($location, $terminal),
            /*
             * CİRO SERVİS GÜNÜNE GÖRE, oluşturma gününe göre değil:
             * oluşturulma gününü saymak ileri tarihli siparişleri bugünün
             * cirosuna yazardı. Tutar kuruş; `order_total` TastyIgniter'da
             * ondalıklı TL saklıyor ve `Money` dışında hiçbir yerde
             * ondalıklı para telde gitmiyor.
             */
            'revenue_today_kurus' => $this->revenueKurus($location, $date, $cancelledId),
            'unreleased_subscription_orders' => $this->unreleasedSubscriptionOrders($location),
        ];
    }

    /**
     * Aktif siparişlerin durum dağılımı — TERMİNAL KODLAR ANAHTAR DEĞİL.
     *
     * `teslim_edildi` ve `iptal` zaten aktif kümenin dışında ve her
     * seferinde `0` dönerlerdi. Kalan beş kod sipariş yokken bile `0` ile
     * duruyor: istemcinin eksik anahtar için savunma yazmasına gerek
     * kalmasın.
     *
     * @param  list<int>  $terminal
     * @return array<string, int>
     */
    private function activeByStatus(Location $location, array $terminal): array
    {
        $counts = array_fill_keys(
            array_values(array_diff(OrderStatusTransition::CODES, [
                OrderStatusTransition::DELIVERED,
                OrderStatusTransition::CANCELLED,
            ])),
            0,
        );

        $rows = Order::query()
            ->where('orders.location_id', $location->location_id)
            ->whereNotIn('orders.status_id', $terminal)
            ->leftJoin('statuses', 'statuses.status_id', '=', 'orders.status_id')
            ->groupBy('statuses.status_code')
            ->selectRaw('statuses.status_code AS kod, COUNT(*) AS toplam')
            ->pluck('toplam', 'kod');

        foreach ($rows as $code => $total) {
            // KODSUZ DURUM `yeni` SAYILIR — `OrderStatusTransition::codeOf()`
            // ile aynı kural; iki yerde iki farklı cevap çıkmasın.
            $key = ($code === null || $code === '') ? OrderStatusTransition::NEW : (string) $code;

            if (!array_key_exists($key, $counts)) {
                continue;
            }

            $counts[$key] += (int) $total;
        }

        return $counts;
    }

    /**
     * Geciken aktif sipariş sayısı.
     *
     * TANIM: planlanan teslim saati geçmiş ve hâlâ teslim edilmemiş
     * sipariş. "En kısa sürede" siparişler SAYILMAZ — planlanmış bir
     * saatleri yok ve onları saymak için uydurulacak her eşik yanlış bir
     * alarm üretirdi.
     *
     * @param  list<int>  $terminal
     */
    private function lateCount(Location $location, array $terminal): int
    {
        return (int) Order::query()
            ->where('location_id', $location->location_id)
            ->whereNotIn('status_id', $terminal)
            ->where('order_time_is_asap', false)
            ->whereNotNull('order_date')
            ->whereNotNull('order_time')
            // Sunucu saati İstanbul'da; `order_date`/`order_time` de yerel
            // duvar saati saklıyor (`OrderPresenter::requestedAt` aynı
            // varsayımla okuyor).
            ->whereRaw(
                'CONCAT(order_date, " ", order_time) < ?',
                [BusinessTime::now()->format('Y-m-d H:i:s')],
            )
            ->count();
    }

    private function revenueKurus(Location $location, Carbon $date, ?int $cancelledId): int
    {
        $total = (float) Order::query()
            ->where('location_id', $location->location_id)
            ->whereDate('bld_service_date', $date->toDateString())
            ->when($cancelledId !== null, fn($query) => $query->where('status_id', '!=', $cancelledId))
            ->sum('order_total');

        return (int) round($total * 100);
    }

    /**
     * Üretilmiş ama henüz KDS'e düşmemiş abonelik siparişleri.
     *
     * Sütun BAŞKA BİR KULVARDA ekleniyor; yoksa sayı sıfırdır. Olmayan bir
     * sütuna sorgu atmak, gösterge panelinin tamamını `500` ile düşürürdü.
     */
    private function unreleasedSubscriptionOrders(Location $location): int
    {
        if (!Schema::hasColumn('orders', 'bld_released_at')) {
            return 0;
        }

        // GELECEKTE BIRAKILACAK olanlar sayılıyor; `null` "kapı yok, zaten
        // düştü" demektir (`OrderFactory` yalnız geciktirilen siparişlere
        // damga yazıyor) ve onları beklemede göstermek yanlış alarm olurdu.
        return (int) Order::query()
            ->where('location_id', $location->location_id)
            ->whereNotNull('bld_subscription_id')
            ->whereNotNull('bld_released_at')
            ->where('bld_released_at', '>', Carbon::now())
            ->count();
    }

    // ── capacity ──────────────────────────────────────────────────────────

    /**
     * Gün kapasitesi — `menu.md` → `GET /days/{date}/stock` ile aynı hesap.
     *
     * MENÜ YAYINLANMAMIŞSA diğer alanlar `null` döner, SIFIR DEĞİL: menü
     * yoksa kapasite diye bir kavram yok ve sıfır "doldu" anlamına gelirdi.
     *
     * @return array<string, mixed>
     */
    private function capacityBlock(Location $location, Carbon $date): array
    {
        $published = DailyMenu::query()
            ->where('location_id', $location->location_id)
            ->whereDate('menu_date', $date->toDateString())
            ->where('status', DailyMenu::STATUS_PUBLISHED)
            ->exists();

        if (!$published) {
            return [
                'menu_published' => false,
                'capacity_total' => null,
                'sold_total' => null,
                'sold_orders' => null,
                'sold_subscriptions' => null,
                'remaining_total' => null,
                'fill_rate' => null,
                'blocked_items' => [],
            ];
        }

        $rows = DB::table('veykemtu_daily_menu_stock')
            ->where('location_id', $location->location_id)
            ->where('service_date', $date->toDateString())
            ->get(['menu_id', 'capacity', 'reserved', 'sold']);

        $dayRow = $rows->firstWhere('menu_id', 0);

        // `sold` GERÇEK SATIŞ, `reserved` ABONELİK REZERVİ. İki kolonun ayrı
        // durmasının sebebi tam da bu ayrım (`veykemtu_daily_menu_stock`
        // göç yorumunda): tek kolona toplansaydı abonelik iptalinde neyin
        // geri verileceği bilinemezdi.
        $soldOrders = $dayRow === null ? 0 : (int) $dayRow->sold;
        $soldSubs = $dayRow === null ? 0 : (int) $dayRow->reserved;
        $capacity = $dayRow === null ? null : (int) $dayRow->capacity;
        $soldTotal = $soldOrders + $soldSubs;

        $blocked = [];

        foreach ($rows as $row) {
            if ((int) $row->menu_id === 0) {
                continue;
            }

            $used = (int) $row->reserved + (int) $row->sold;

            if ($used < (int) $row->capacity) {
                continue;
            }

            $blocked[] = [
                'menu_id' => (int) $row->menu_id,
                'name' => (string) (DB::table('menus')->where('menu_id', $row->menu_id)->value('menu_name') ?? ''),
                'capacity' => (int) $row->capacity,
                'sold' => $used,
            ];

            if (count($blocked) >= self::MAX_BLOCKED_ITEMS) {
                break;
            }
        }

        return [
            'menu_published' => true,
            // TAVAN KONMAMIŞSA `null` — "sınırsız" demektir, sıfır değil.
            'capacity_total' => $capacity,
            'sold_total' => $soldTotal,
            'sold_orders' => $soldOrders,
            'sold_subscriptions' => $soldSubs,
            'remaining_total' => $capacity === null ? null : max(0, $capacity - $soldTotal),
            'fill_rate' => ($capacity === null || $capacity === 0)
                ? null
                : round($soldTotal / $capacity, 2),
            'blocked_items' => $blocked,
        ];
    }

    // ── subscriptions ─────────────────────────────────────────────────────

    /** @return array<string, mixed> */
    private function subscriptionsBlock(Location $location, Carbon $date): array
    {
        $counts = Subscription::query()
            ->where('location_id', $location->location_id)
            ->groupBy('status')
            ->selectRaw('status, COUNT(*) AS toplam')
            ->pluck('toplam', 'status');

        $block = [
            'active' => (int) ($counts[Subscription::STATUS_ACTIVE] ?? 0),
            'pending' => (int) ($counts[Subscription::STATUS_PENDING] ?? 0),
            'paused' => (int) ($counts[Subscription::STATUS_PAUSED] ?? 0),
            'portions_today' => $this->portionsToday($location, $date),
            'contracts_awaiting_signature' => 0,
            'unpaid_periods' => 0,
            'unpaid_total_kurus' => 0,
            'overdue_periods' => 0,
            'overdue_total_kurus' => 0,
        ];

        /*
         * SÖZLEŞME VE ÖDEME TABLOLARI BAŞKA BİR KULVARDA açılıyor; `hasTable`
         * denetimi kalıyor ki bu uç, göçlerin sırası ne olursa olsun açılsın.
         *
         * İMZA BEKLEYEN = `draft` + `sent`. Sözleşme belgesi "pending"
         * diyor, tablo `draft` ile doğuyor; ikisi aynı hâlin iki adı ve
         * sayılan şey "abone henüz onaylamadı".
         */
        if (Schema::hasTable('veykemtu_subscription_contracts')) {
            $block['contracts_awaiting_signature'] = (int) SubscriptionContract::query()
                ->whereIn('status', [
                    SubscriptionContract::STATUS_DRAFT,
                    SubscriptionContract::STATUS_SENT,
                ])
                ->count();
        }

        if (Schema::hasTable('veykemtu_subscription_payments')) {
            $unpaid = SubscriptionPayment::query()->where('status', SubscriptionPayment::STATUS_PENDING);

            $block['unpaid_periods'] = (int) $unpaid->clone()->count();
            $block['unpaid_total_kurus'] = (int) $unpaid->clone()->sum('amount_kurus');

            /*
             * `overdue` UNPAID'İN ALT KÜMESİDİR, ayrı bir küme değil. Panel
             * ikisini üst üste değil, biri diğerinin içinde gösterir.
             *
             * VADE SÜTUNU YOK. `veykemtu_subscription_payments` bir
             * `due_date` taşımıyor (ödeme dönemin BAŞINDA peşin alınıyor);
             * vade yerine DÖNEM SONU kullanılıyor: dönemi bitmiş ve hâlâ
             * ödenmemiş bir kayıt, gecikmiş borcun kendisidir. Uydurulmuş
             * bir vade, olmayan bir tarihe göre alarm verirdi.
             */
            $overdue = $unpaid->clone()->whereDate('period_end', '<', BusinessTime::today());

            $block['overdue_periods'] = (int) $overdue->clone()->count();
            $block['overdue_total_kurus'] = (int) $overdue->clone()->sum('amount_kurus');
        }

        return $block;
    }

    /** Bugün üretilen abonelik siparişlerinin toplam adedi. */
    private function portionsToday(Location $location, Carbon $date): int
    {
        return (int) DB::table('orders')
            ->join('order_menus', 'order_menus.order_id', '=', 'orders.order_id')
            ->where('orders.location_id', $location->location_id)
            ->whereNotNull('orders.bld_subscription_id')
            ->whereDate('orders.bld_service_date', $date->toDateString())
            ->sum('order_menus.quantity');
    }

    // ── pending_tasks ─────────────────────────────────────────────────────

    /**
     * Yöneticinin BUGÜN yapması gereken işler.
     *
     * Gösterge panelinin asıl değeri burada: sayılar durumu anlatır, bu
     * liste eylemi söyler.
     *
     * MADDELER VAR OLAN SAYAÇLARDAN TÜRETİLİR, her madde için ayrı sorgu
     * açılmaz — tek istisna menü ufku ve teklif talebi, ikisi de tek
     * sorguluk.
     *
     * `link` KONTROL MERKEZİ'NİN KENDİ YOLUDUR, BLD API yolu değil. Sunucu
     * bu yolları biliyor çünkü sözleşme onları donduruyor; panelin kod
     * eşleştirmesi yazması, yeni bir madde eklendiğinde tıklanamayan bir
     * satır üretirdi.
     *
     * @param  array<string, mixed>  $sales
     * @param  array<string, mixed>  $orders
     * @param  array<string, mixed>  $capacity
     * @param  array<string, mixed>  $subscriptions
     * @param  array<string, mixed>  $monitor
     * @return list<array<string, mixed>>
     */
    private function pendingTasks(
        Location $location,
        Carbon $date,
        array $sales,
        array $orders,
        array $capacity,
        array $subscriptions,
        array $monitor,
    ): array {
        $tasks = [];

        if ($sales['ordering_enabled'] === false) {
            $tasks[] = $this->task(
                'ordering_paused',
                'critical',
                'Satış durdurulmuş',
                $sales['paused_until'] === null
                    ? 'Sipariş alımı süresiz olarak kapalı.'
                    : 'Sipariş alımı kapalı; planlanan açılış '
                        .Carbon::parse((string) $sales['paused_until'])
                            ->setTimezone(BusinessTime::ZONE)->format('d.m.Y H:i').'.',
                1,
                '/settings/sales',
            );
        }

        foreach ($this->missingMenuDays($location, $date) as $missing) {
            $tasks[] = $this->task(
                'menu_missing',
                'critical',
                'Yaklaşan güne menü girilmemiş',
                $missing['detail'],
                1,
                '/menu/days/'.$missing['date'],
            );
        }

        $devices = $monitor['devices'];

        if ((int) $devices['total'] - (int) $devices['revoked'] > 0 && (int) $devices['online'] === 0) {
            $tasks[] = $this->task(
                'no_device_online',
                'critical',
                'Hiçbir kasa çevrimiçi değil',
                'Mutfakta açık kasa yok; siparişler ekrana düşmüyor.',
                1,
                '/monitor/devices',
            );
        }

        if ((int) $monitor['events']['open']['critical'] > 0) {
            $count = (int) $monitor['events']['open']['critical'];
            $tasks[] = $this->task(
                'critical_event_open',
                'critical',
                'Açık kritik hata',
                $count.' kritik hata olayı çözülmemiş durumda.',
                $count,
                '/monitor/events?level=critical',
            );
        }

        foreach ($this->draftMenuDays($location, $date) as $draft) {
            $tasks[] = $this->task(
                'menu_draft',
                'warning',
                'Yayınlanmamış taslak menü',
                $draft['detail'],
                1,
                '/menu/days/'.$draft['date'],
            );
        }

        if ($capacity['capacity_total'] !== null
            && $capacity['remaining_total'] !== null
            && (int) $capacity['remaining_total'] === 0
        ) {
            $tasks[] = $this->task(
                'capacity_full',
                'warning',
                'Gün kapasitesi doldu',
                'Bugünün '.$capacity['capacity_total'].' porsiyonluk tavanı doldu, yeni sipariş alınamıyor.',
                1,
                '/menu/days/'.$date->toDateString(),
            );
        }

        if ((int) $devices['printer_fault'] > 0) {
            $count = (int) $devices['printer_fault'];
            $tasks[] = $this->task(
                'printer_fault',
                'warning',
                'Yazıcı arızası',
                $count.' kasa yazıcıya ulaşamıyor, kuyrukta '.((int) $devices['queue_pending']).' iş var.',
                $count,
                '/monitor/devices',
            );
        }

        $oldest = $devices['queue_oldest_age_minutes'] ?? null;

        if (is_int($oldest) && $oldest > MonitorController::STALE_QUEUE_MINUTES) {
            $tasks[] = $this->task(
                'print_queue_stale',
                'warning',
                'Fiş kuyruğu akmıyor',
                'Kuyruktaki en eski iş '.$oldest.' dakikadır bekliyor.',
                1,
                '/monitor/devices',
            );
        }

        if ((int) $orders['late'] > 0) {
            $count = (int) $orders['late'];
            $tasks[] = $this->task(
                'late_orders',
                'warning',
                'Geciken sipariş',
                $count.' siparişin planlanan teslim saati geçti.',
                $count,
                '/orders?status=hazir,yolda',
            );
        }

        $newQuotes = (int) QuoteRequest::query()->where('status', QuoteRequest::STATUS_NEW)->count();

        if ($newQuotes > 0) {
            $tasks[] = $this->task(
                'quote_requests_new',
                'warning',
                'Cevaplanmamış teklif talebi',
                $newQuotes.' talep "yeni" durumunda bekliyor.',
                $newQuotes,
                '/subscriptions/requests?status=yeni',
            );
        }

        if ((int) $subscriptions['contracts_awaiting_signature'] > 0) {
            $count = (int) $subscriptions['contracts_awaiting_signature'];
            $tasks[] = $this->task(
                'contracts_awaiting',
                'warning',
                'İmza bekleyen sözleşme',
                $count.' abonelik sözleşmesi hâlâ imzalanmadı.',
                $count,
                '/subscriptions/contracts',
            );
        }

        if ((int) $subscriptions['overdue_periods'] > 0) {
            $count = (int) $subscriptions['overdue_periods'];
            $tasks[] = $this->task(
                'payments_overdue',
                'warning',
                'Vadesi geçmiş dönem borcu',
                $count.' dönem ödemesinin vadesi geçti.',
                $count,
                '/subscriptions/payments?status=pending',
            );
        }

        if ((int) $subscriptions['pending'] > 0) {
            $count = (int) $subscriptions['pending'];
            $tasks[] = $this->task(
                'subscriptions_pending',
                'warning',
                'Fiyatlandırılmayı bekleyen abonelik',
                $count.' abonelik talebi henüz etkinleştirilmedi.',
                $count,
                '/subscriptions?status=pending',
            );
        }

        if ((int) $orders['unreleased_subscription_orders'] > 0) {
            $count = (int) $orders['unreleased_subscription_orders'];
            $tasks[] = $this->task(
                'unreleased_orders',
                'info',
                'KDS\'e düşmemiş abonelik siparişi',
                $count.' abonelik siparişi henüz mutfak ekranına bırakılmadı.',
                $count,
                '/subscriptions?tab=orders',
            );
        }

        // SIRA: critical → warning → info. Grup içinde ekleme sırası
        // korunuyor; `usort` kararsız olabildiği için ağırlık anahtarıyla
        // sıralanıyor ve eşitlikte sıra numarası ayırıyor.
        $weights = ['critical' => 0, 'warning' => 1, 'info' => 2];
        $indexed = [];

        foreach ($tasks as $i => $task) {
            $indexed[] = [$weights[$task['level']] ?? 3, $i, $task];
        }

        usort($indexed, static fn(array $a, array $b): int => [$a[0], $a[1]] <=> [$b[0], $b[1]]);

        return array_slice(array_map(static fn(array $row): array => $row[2], $indexed), 0, self::MAX_PENDING_TASKS);
    }

    /**
     * Kesim saati yaklaşan ama menüsü yayınlanmamış servis günleri.
     *
     * HAFTA SONU DENETİME GİRMEZ (iş kararı 4: cumartesi ve pazar servis
     * yok). Girseydi her cuma sahte bir kritik uyarı doğardı.
     *
     * @return list<array{date:string, detail:string}>
     */
    private function missingMenuDays(Location $location, Carbon $date): array
    {
        return $this->menuGapDays($location, $date, published: true);
    }

    /**
     * Taslak hâlde bekleyen, servis günü yaklaşan menüler.
     *
     * @return list<array{date:string, detail:string}>
     */
    private function draftMenuDays(Location $location, Carbon $date): array
    {
        return $this->menuGapDays($location, $date, published: false);
    }

    /**
     * @return list<array{date:string, detail:string}>
     */
    private function menuGapDays(Location $location, Carbon $date, bool $published): array
    {
        $days = [];

        for ($i = 0; $i <= self::MENU_HORIZON_DAYS; $i++) {
            $candidate = $date->copy()->addDays($i);

            if (!$this->window->isServiceDay($candidate)) {
                continue;
            }

            $days[] = $candidate;
        }

        if ($days === []) {
            return [];
        }

        $menus = DailyMenu::query()
            ->where('location_id', $location->location_id)
            ->whereIn('menu_date', array_map(static fn(Carbon $d): string => $d->toDateString(), $days))
            ->get()
            ->keyBy(static fn(DailyMenu $menu): string => Carbon::parse($menu->menu_date)->toDateString());

        $out = [];

        foreach ($days as $day) {
            $key = $day->toDateString();
            $menu = $menus->get($key);

            if ($published) {
                // "Menü yok" ile "taslak var" AYNI MADDE DEĞİL: ilki
                // sıfırdan girmeyi, ikincisi yalnız yayınlamayı gerektirir.
                if ($menu !== null) {
                    continue;
                }
            } elseif ($menu === null || $menu->isPublished()) {
                continue;
            }

            $cutoff = $this->window->cutoffFor($location, $day);
            $remaining = $cutoff === null
                ? null
                : (int) Carbon::now()->diffInHours($cutoff, absolute: false);

            $detail = $day->format('d.m.Y').' için '
                .($published ? 'menü girilmemiş' : 'menü taslak hâlde').'.';

            if ($remaining !== null && $remaining >= 0) {
                $detail .= ' Kesim saatine '.$remaining.' saat kaldı.';
            }

            $out[] = ['date' => $key, 'detail' => $detail];
        }

        return $out;
    }

    /**
     * @return array<string, mixed>
     */
    private function task(
        string $code,
        string $level,
        string $title,
        string $detail,
        int $count,
        string $link,
    ): array {
        return [
            'code' => $code,
            'level' => $level,
            'title' => $title,
            // METİN TÜRKÇE VE DOĞRUDAN GÖSTERİLEBİLİR. Panel kendi
            // cümlesini kurmaz: aynı durumun iki ekranda iki farklı
            // cümleyle anlatılması, telefonda konuşan iki kişinin farklı şey
            // söylemesi demektir.
            'detail' => $detail,
            'count' => $count,
            'link' => $link,
        ];
    }

    // ── Ortak ─────────────────────────────────────────────────────────────

    /**
     * Vitrin — `SettingsRepository::location()` İLE AYNI ÇÖZÜMLEME.
     *
     * Burada `orderBy('location_id')->first()` yazılmıştı ve SESSİZ BİR
     * AYRIŞMA üretiyordu: satış ayarları etkin + varsayılan vitrini
     * seçerken gösterge paneli en küçük kimlikli vitrini seçiyordu. İki
     * ekran farklı vitrine bakınca "satışı durdurdum ama panel açık
     * gösteriyor" gibi, sebebi hiçbir yerde görünmeyen bir arıza çıkıyordu.
     * Çözümleme tek yerde kalmalı.
     */
    private function location(Request $request): Location
    {
        if ($request->filled('location_id')) {
            $location = Location::find((int) $request->query('location_id'));

            if ($location === null) {
                throw ApiException::notFound('Vitrin bulunamadı.');
            }

            return $location;
        }

        $location = $this->settings->location();

        if ($location === null) {
            throw ApiException::notFound('Tanımlı vitrin yok.');
        }

        return $location;
    }

    private function statusId(string $code): ?int
    {
        $id = Status::query()->where('status_code', $code)->value('status_id');

        return $id === null ? null : (int) $id;
    }
}
