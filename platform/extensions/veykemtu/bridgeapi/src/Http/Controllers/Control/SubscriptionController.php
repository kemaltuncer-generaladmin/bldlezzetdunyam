<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Control;

use Igniter\Cart\Models\Order;
use Igniter\Local\Models\Location;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\Rule;
use Throwable;
use Veykemtu\BridgeApi\Admin\SettingsRepository;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Models\ClosedDay;
use Veykemtu\BridgeApi\Models\ControlAudit;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Models\Invoice;
use Veykemtu\BridgeApi\Models\QuoteRequest;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Models\SubscriptionContract;
use Veykemtu\BridgeApi\Models\SubscriptionDeliveryPoint;
use Veykemtu\BridgeApi\Models\SubscriptionException;
use Veykemtu\BridgeApi\Models\SubscriptionLine;
use Veykemtu\BridgeApi\Models\SubscriptionPause;
use Veykemtu\BridgeApi\Models\SubscriptionPayment;
use Veykemtu\BridgeApi\Models\SubscriptionRun;
use Veykemtu\BridgeApi\Services\ContractService;
use Veykemtu\BridgeApi\Services\DailyStock;
use Veykemtu\BridgeApi\Services\InvoiceService;
use Veykemtu\BridgeApi\Services\OrderFactory;
use Veykemtu\BridgeApi\Services\OrderingWindow;
use Veykemtu\BridgeApi\Services\OrderPresenter;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;
use Veykemtu\BridgeApi\Services\OtpService;
use Veykemtu\BridgeApi\Services\Sms\SmsException;
use Veykemtu\BridgeApi\Services\SubscriptionLifecycle;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\Payment\Payments\PaymentResult;

/**
 * Kontrol Merkezi — abonelik, talep, sözleşme, ödeme.
 *
 * Sözleşme: `docs/control/subscriptions.md` (donmuş). Dört alt aile tek
 * önekte (`/api/control/subscriptions`) toplanıyor çünkü hepsi aynı
 * ekranın sekmeleri: aboneliğin kendisi, onu doğuran talep, onu geçerli
 * kılan sözleşme ve karşılığında tahsil edilen para.
 *
 * ## Bu sınıf bir KABUKTUR
 *
 * `ControlController::write()` üç şeyi tek yerde yapıyor: aktör + gerekçe
 * doğrulaması, İŞTEN ÖNCE açılan denetim satırı ve kuru prova. Buradaki
 * hiçbir metot o sırayı yeniden yazmaz.
 *
 * İş mantığı da mümkün olan her yerde mevcut sınıflarda kalıyor:
 * `Subscription::runsOnDate()` / `upcomingServiceDays()` (üretim işinin
 * kullandığı metotların ta kendisi), `OrderFactory::createForSubscription()`,
 * `DailyStock` (tavan), `OrderStatusTransition::codeOf()`,
 * `OrderPresenter::number()`.
 *
 * ## Rota sırası ve metot adları SABİT
 *
 * `routes/api.php` sabit parçalı aileleri (`requests`, `contracts`,
 * `payments`, `orders`) `{subscription}`'dan ÖNCE kaydediyor; aksi hâlde
 * "requests" bir abonelik kimliği sanılırdı. Metot adları da o dosyadan
 * gelir — rota ile denetleyici adının ayrışması ne açılışta ne
 * `route:list`'te hata verir, yalnız uç çağrılınca patlar. Yeni bir uç
 * eklenecekse önce rota dosyası, sonra burası.
 *
 * ## İKİ SÖZLÜK, TEK ÇEVİRİ NOKTASI
 *
 * Sözleşme ve ödeme kayıtlarının durum sözlükleri müşteri yüzünde başka
 * (`draft|sent|approved|…`, `pending|succeeded|failed|refunded`), panelde
 * başka (`pending|sent|signed|…`, `pending|paid|void`). İkisi de
 * yayınlanmış birer arayüz ve hangisinin "doğru" olduğunun bir cevabı yok;
 * şart olan tek çeviri noktası bulunması. Sözleşmede o nokta
 * `SubscriptionContract::controlStatus()`, ödemede bu sınıftaki
 * [paymentStatus]. İkinci bir çeviri, aynı kaydı iki ekranda farklı
 * durumda göstermek demektir.
 *
 * ## BİR KOLON HENÜZ YOK
 *
 * `veykemtu_quote_requests.converted_subscription_id` göçü bu kulvarın
 * dışında ve `Schema::hasColumn` ile yoklanıyor: var olmayan bir kolona
 * yazmak 500 üretirdi, oysa eksik olan uç değil göç.
 *
 * SERBEST BIRAKMA KOLONU ARTIK YOKLANMIYOR (17.08.2026). Sözleşme onu
 * `bld_kds_release_at` diye adlandırmıştı; göç `orders.bld_released_at`
 * adıyla geldi (`2026_08_21_000001`) ve `OrderFactory` ile
 * `KitchenController` o adı korumasız kullanıyor. Yoklama olduğu gibi
 * kalsaydı ad ayrışması hiçbir yerde patlamaz, yalnızca serbest bırakma
 * ucu sessizce hiçbir şey yapmaz ve panelde `released_at` her satırda
 * `null` görünürdü — kolon var olduğu hâlde.
 */
class SubscriptionController extends ControlController
{
    /** Sorgu parametresi olarak gelen günün biçimi. */
    private const string DATE_PATTERN = '/^\d{4}-\d{2}-\d{2}$/';

    /** `GET /{id}/calendar` — varsayılan ve tavan pencere. */
    private const int CALENDAR_DEFAULT_DAYS = 30;

    private const int CALENDAR_MAX_DAYS = 92;

    /** Dönem borcu aralığının tavanı (`POST /{id}/payments`). */
    private const int PERIOD_MAX_DAYS = 62;

    /** Sözleşme bağlantısının varsayılan ömrü (gün). */
    private const int CONTRACT_EXPIRES_DEFAULT = 7;

    private const int CONTRACT_EXPIRES_MIN = 1;

    private const int CONTRACT_EXPIRES_MAX = 30;

    /** Panel sözlüğündeki sözleşme durumları (`controlStatus()` çıktısı). */
    private const string CONTRACT_SENT = 'sent';

    private const string CONTRACT_SIGNED = 'signed';

    private const string CONTRACT_CANCELLED = 'cancelled';

    /** Panel sözlüğündeki ödeme durumları — `subscriptions.md` § Ödemeler. */
    private const string PAYMENT_PENDING = 'pending';

    private const string PAYMENT_PAID = 'paid';

    private const string PAYMENT_VOID = 'void';

    /**
     * Siparişin mutfağa açıldığı anı taşıyan kolon (`NULL` = anında).
     *
     * Adı `OrderFactory`, `KitchenController` ve `ProductionListService` ile
     * AYNI olmak zorunda: damgayı fabrika atıyor, kapıyı pano uyguluyor, bu
     * denetleyici yalnız okuyor ve `release` ucunda eziyor. Üç yüzeyden biri
     * başka bir ada baksa kimse hata almaz — sipariş yanlış anda görünür.
     */
    private const string RELEASE_COLUMN = 'bld_released_at';

    /**
     * Şema yoklamalarının istek ömürlü belleği.
     *
     * `Schema::hasTable()` her çağrıda `information_schema`'ya gidiyor;
     * liste ucu satır başına bir kez sorsa panelde yirmi beş gereksiz sorgu
     * olurdu. STATİK DEĞİL: statik bellek testler arasında da yaşar ve
     * göçün ortada değiştiği bir koşumda bayat cevap verirdi.
     *
     * @var array<string, bool>
     */
    private array $schemaCache = [];

    /**
     * Dönem ödemesi → belge kimliği belleği.
     *
     * `payments()` bir aboneliğin bütün dönemlerini döndürüyor ve satır
     * başına bir sorgu, yirmi dönemlik bir abonelikte yirmi gereksiz sorgu
     * demekti. `schemaCache` ile aynı gerekçe: istek ömürlü, statik değil.
     *
     * @var array<int, int|null>
     */
    private array $invoiceIds = [];

    public function __construct(
        private readonly OrderPresenter $presenter,
        private readonly OrderStatusTransition $transitions,
        private readonly OrderFactory $factory,
        private readonly DailyStock $stock,
        // Serbest bırakma anının TEK KAYNAĞI — `LocationGate`'in YERİNE
        // geçti. Gate bu sınıfta yalnız kaldırılmış `subscription_release_time`
        // ayarını okumak için duruyordu; kesim saati vitrin ayarı değil GÜN
        // kaydıdır ve onu yalnız pencere biliyor. Panel "bu sipariş ne zaman
        // mutfağa düşecek" sorusunu buradan cevaplıyor; kendi saatini
        // hesaplasaydı `OrderFactory`'nin attığı damgayla ayrışırdı.
        private readonly OrderingWindow $window,
        // `$contracts` DEĞİL: bu sınıfta `contracts()` adında bir uç metodu
        // var ve aynı adı taşıyan bir özellik, okuyanı her seferinde
        // hangisine baktığını düşünmeye zorlardı.
        private readonly ContractService $contractService,
        private readonly SubscriptionLifecycle $lifecycle,
        /*
         * FATURA BU ALANIN İŞİ DEĞİL AMA BU ALANDAN TETİKLENİYOR (I2).
         *
         * `mark-paid` gövdesindeki `create_invoice` onay kutusu uzun süre
         * HİÇBİR ŞEY YAPMIYORDU: yanıt `invoice_id: null` döndürüyor ve
         * `invoice_not_created` uyarısı bırakıyordu — panel de o uyarıyı
         * göstermediği için yönetici belge kesildiğini sanıyordu. Oysa
         * dönem faturası ucu (`Control\InvoiceController`) ve servisi
         * ZATEN VARDI ve `subscription_payment_id` bağını destekliyordu.
         * Eksik olan tek şey bu satırdı.
         *
         * Belge kesimi yine `InvoiceService` içinde kalıyor; bu sınıf ona
         * yalnız "şu dönemi kes" diyor.
         */
        private readonly InvoiceService $invoices,
    ) {}

    // ── Abonelik ─────────────────────────────────────────────────────────

    /**
     * Abonelik listesi — sayfalı.
     *
     * `unpaid_periods` ve `unpaid_total_kurus` LİSTEDE. Bu ekranın asıl
     * sorusu "kim ödemedi"dir; her satır için ayrı bir ödeme çağrısı yapmak
     * dokuz abonelikte dokuz istek demekti. İkisi de tek toplu sorgudan
     * geliyor, satır başına bir sorgudan değil.
     */
    public function index(Request $request): JsonResponse
    {
        $request->validate([
            'status' => ['sometimes', 'string', 'max:120'],
            'customer_id' => ['sometimes', 'integer', 'min:1'],
            'q' => ['sometimes', 'string', 'max:120'],
            'service_day' => ['sometimes', 'integer', 'between:1,7'],
            'active_on' => ['sometimes', 'string', 'regex:'.self::DATE_PATTERN],
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ]);

        $query = Subscription::query()->with(['delivery_points', 'pauses', 'exceptions', 'customer']);

        if ($request->filled('status')) {
            $statuses = $this->csv((string) $request->query('status'));

            foreach ($statuses as $status) {
                if (!in_array($status, Subscription::STATUSES, true)) {
                    throw ApiException::validationFailed(
                        'Bilinmeyen abonelik durumu: '.$status.'.',
                        ['field' => 'status', 'allowed' => Subscription::STATUSES],
                    );
                }
            }

            $query->whereIn('status', $statuses);
        }

        if ($request->filled('customer_id')) {
            $query->where('customer_id', (int) $request->query('customer_id'));
        }

        if ($request->filled('q')) {
            $query->whereIn('customer_id', $this->customerIdsMatching((string) $request->query('q')));
        }

        if ($request->filled('service_day')) {
            $day = (int) $request->query('service_day');

            /*
             * İKİ BİÇİM BİRDEN SORULUYOR. `service_days` bir JSON dizi ve
             * kaynağına göre `[1,2]` ya da `["1","2"]` olarak yazılmış
             * olabilir (admin formu dizge gönderiyor, API tam sayı).
             * Tek biçim sorgulasaydık süzgeç kayıtların yarısını sessizce
             * atlardı — ve eksik liste, hatalı listeden daha geç fark
             * edilir.
             */
            $query->where(static function ($builder) use ($day): void {
                $builder->whereJsonContains('service_days', $day)
                    ->orWhereJsonContains('service_days', (string) $day);
            });
        }

        if ($request->filled('active_on')) {
            $query->whereIn('id', $this->idsRunningOn(
                $this->parseDate((string) $request->query('active_on'), 'active_on'),
            ));
        }

        $perPage = min(100, max(1, (int) $request->query('per_page', '25')));
        $page = max(1, (int) $request->query('page', '1'));
        $total = (int) $query->toBase()->getCountForPagination();

        $rows = $query->orderByDesc('id')->forPage($page, $perPage)->get();

        $contractStatuses = $this->contractStatusMap($rows->pluck('id')->map(intval(...))->all());
        $unpaid = $this->unpaidMap($rows->pluck('id')->map(intval(...))->all());

        return $this->json([
            'data' => $rows->map(fn(Subscription $s): array => [
                'id' => (int) $s->id,
                'customer_id' => (int) $s->customer_id,
                'customer_label' => $this->customerLabel($s),
                'status' => (string) $s->status,
                'start_date' => $this->dateOf($s->start_date),
                'end_date' => $this->dateOf($s->end_date),
                'service_days' => $this->serviceDays($s),
                'menu_mode' => (string) $s->menu_mode,
                'default_quantity' => (int) $s->default_quantity,
                'agreed_unit_price_kurus' => $this->nullableInt($s->agreed_unit_price_kurus),
                'payment_mode' => (string) $s->payment_mode,
                'delivery_point_count' => $s->delivery_points->count(),
                'contract_status' => $contractStatuses[(int) $s->id] ?? 'none',
                'next_service_date' => $this->nextServiceDate($s),
                'unpaid_periods' => $unpaid[(int) $s->id]['periods'] ?? 0,
                'unpaid_total_kurus' => $unpaid[(int) $s->id]['total_kurus'] ?? 0,
            ])->all(),
            'meta' => [
                'page' => $page,
                'per_page' => $perPage,
                'total' => $total,
                'last_page' => max(1, (int) ceil($total / $perPage)),
            ],
            'server_time' => $this->serverTime(),
        ]);
    }

    public function show(Request $request, string $subscription): JsonResponse
    {
        return $this->json([
            'data' => $this->row($this->find($subscription)),
            'server_time' => $this->serverTime(),
        ]);
    }

    /**
     * Yeni abonelik — HER ZAMAN `pending` doğar.
     *
     * Fiyatı ve sözleşmesi tamamlanmadan üretim yapmamalı; aktifleştirme
     * ayrı bir eylemdir ve ayrı bir denetim satırı bırakır. Bir alanla
     * (`status`) geçilebilseydi, imzasız bir aboneliğin üretime girmesi tek
     * bir yazım hatası uzaklıkta olurdu.
     */
    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'customer_id' => ['required', 'integer', 'exists:customers,customer_id'],
            ...$this->subscriptionRules(''),
        ]);

        $customerId = (int) $request->input('customer_id');
        $body = $request->all();

        $this->assertSubscriptionShape($body, $customerId, '');

        $preview = $this->createPreview($body);

        $response = $this->write(
            $request,
            'subscription.create',
            ControlAudit::TARGET_SUBSCRIPTION,
            null,
            [
                'customer_id' => $customerId,
                'location_id' => (int) $body['location_id'],
                'start_date' => (string) $body['start_date'],
                'service_days' => array_map(intval(...), (array) $body['service_days']),
                'default_quantity' => (int) $body['default_quantity'],
                'agreed_unit_price_kurus' => $this->nullableInt($body['agreed_unit_price_kurus'] ?? null),
            ],
            static fn(): array => ['action' => 'subscription.create', ...$preview],
            fn(): array => ['data' => $this->row($this->persist($customerId, $body))],
        );

        // 201 yalnız gerçekten oluşturulduğunda: kuru provada hiçbir satır
        // yazılmadı ve `201 Created` yalan olurdu.
        return $request->boolean('dry_run') ? $response : $response->setStatusCode(201);
    }

    /**
     * Kural güncelleme — kısmi.
     *
     * `customer_id`, `location_id`, `start_date` ve `status` YAZILAMAZ.
     * Müşteriyi değiştirmek yeni abonelik açmaktır; durum kendi
     * uçlarındadır ve her biri ayrı bir denetim satırı bırakır.
     *
     * ÜRETİLMİŞ SİPARİŞLER ETKİLENMEZ ve yanıt bunu `warnings` ile söyler.
     * Sessiz kalsaydı yönetici yarının adedini değiştirdiğini sanıp
     * mutfağa eski adedi gönderirdi.
     */
    public function update(Request $request, string $subscription): JsonResponse
    {
        $model = $this->find($subscription);

        $this->rejectImmutable($request, ['customer_id', 'location_id', 'start_date', 'status']);

        if ($model->status === Subscription::STATUS_CANCELLED) {
            throw $this->conflict(
                'İptal edilmiş abonelik güncellenemez.',
                ['conflict' => 'cancelled'],
            );
        }

        $request->validate($this->subscriptionRules('', creating: false));

        $body = $request->all();
        $merged = $this->mergedShape($model, $body);

        $this->assertSubscriptionShape($merged, (int) $model->customer_id, '', partial: $body);
        $this->assertPriceStillOpen($model, $body);

        $warnings = $this->generatedOrderWarnings(
            $model,
            'generated_orders_unaffected',
            $this->today(),
        );

        return $this->write(
            $request,
            'subscription.update',
            ControlAudit::TARGET_SUBSCRIPTION,
            (int) $model->id,
            ['fields' => array_keys(array_diff_key($body, array_flip(['actor', 'reason', 'dry_run'])))],
            fn(): array => [
                'action' => 'subscription.update',
                'id' => (int) $model->id,
                'changes' => array_diff_key($body, array_flip(['actor', 'reason', 'dry_run'])),
                'warnings' => $warnings,
            ],
            function () use ($model, $body, $warnings): array {
                DB::transaction(function () use ($model, $body): void {
                    $this->applyBody($model, $body);
                    $model->save();

                    if (array_key_exists('lines', $body)) {
                        $this->syncLines($model, (array) $body['lines']);
                    }
                    if (array_key_exists('delivery_points', $body)) {
                        $this->syncPoints($model, (array) $body['delivery_points']);
                    }
                });

                return [
                    'data' => $this->row($model->fresh(['lines', 'delivery_points', 'pauses', 'exceptions', 'customer'])),
                    'warnings' => $warnings,
                ];
            },
        );
    }

    /**
     * Talebi/duraklamayı aktifleştirir.
     *
     * ÜÇ ÖN DENETİM DE KURU PROVADA KOŞAR (`00-genel.md` §3.1): "kuru prova
     * geçti" diyen bir ekran gerçek gönderimde patlamamalı.
     */
    public function activate(Request $request, string $subscription): JsonResponse
    {
        $model = $this->find($subscription);

        /*
         * KABUL LİSTESİ GENİŞLEDİ (I1).
         *
         * Eskiden yalnız `pending` ve `paused` geçiyordu; oysa sözleşme
         * onaylandığında `ContractService` aboneliği `awaiting_payment`
         * yapıyor. Yani "imzalı sözleşme şart" diyen bu uç, tam da imzayı
         * almış aboneliği 409 ile geri çeviriyordu — akışın en sık
         * yürüdüğü yol tıkalıydı. `STATUSES_BEFORE_ACTIVE` üç ara durumu
         * TEK YERDE sayıyor ki dördüncüsü eklendiğinde burası unutulmasın.
         */
        $this->assertStatusIn($model, [
            ...Subscription::STATUSES_BEFORE_ACTIVE,
            Subscription::STATUS_PAUSED,
        ]);

        if ($model->agreed_unit_price_kurus === null) {
            throw ApiException::validationFailed(
                'Fiyatı girilmemiş abonelik aktifleştirilemez.',
                ['field' => 'agreed_unit_price_kurus'],
            );
        }

        $contract = $this->latestContract((int) $model->id);
        $contractStatus = $contract?->controlStatus() ?? 'none';

        if ($contractStatus !== self::CONTRACT_SIGNED) {
            // İş kararı 9: sözleşme zorunlu. Sözleşmesiz aktifleştirme,
            // hiçbir şeye dayanmayan bir üretim kuralı açardı.
            throw ApiException::validationFailed(
                'Abonelik aktifleştirilemez: imzalı sözleşme yok.',
                ['reason' => 'contract_not_signed', 'contract_status' => $contractStatus],
            );
        }

        $today = $this->today();

        if ($model->end_date !== null && $model->end_date->copy()->startOfDay()->lt($today)) {
            throw ApiException::validationFailed(
                'Bitiş günü geçmişte kalmış bir abonelik aktifleştirilemez.',
                ['field' => 'end_date'],
            );
        }

        return $this->write(
            $request,
            'subscription.activate',
            ControlAudit::TARGET_SUBSCRIPTION,
            (int) $model->id,
            ['from' => (string) $model->status, 'contract_id' => (int) $contract->id],
            fn(): array => [
                'action' => 'subscription.activate',
                'id' => (int) $model->id,
                'status' => Subscription::STATUS_ACTIVE,
                'next_service_date' => $this->nextServiceDate($this->asActive($model)),
            ],
            function () use ($model): array {
                /*
                 * DURUMU DEĞİŞTİREN TEK YER `SubscriptionLifecycle`. Burada
                 * `status = active` yazsaydık, "ödeme almadan aktifleştirme"
                 * kuralı bir yerde daha yaşar ve o kopya güncellenmediği gün
                 * bedava abonelik çıkardı. Elle aktifleştirme para dışı bir
                 * yönetici kararıdır ve kendi olayı vardır.
                 */
                $this->lifecycle->transition(
                    $model,
                    SubscriptionLifecycle::EVENT_MANUAL_ACTIVATION,
                );

                return ['data' => [
                    'id' => (int) $model->id,
                    'status' => (string) $model->status,
                    'next_service_date' => $this->nextServiceDate($model->fresh(['pauses', 'exceptions'])),
                ]];
            },
        );
    }

    /**
     * Aralıklı duraklatma — İPTAL DEĞİL.
     *
     * `end_date` `null` KABUL EDİLMEZ: süresiz duraklatma, iptalin adı
     * konmamış hâlidir ve iki farklı kavramı tek durumda toplardı. Süresiz
     * durdurmak isteyen `cancel` kullanır.
     */
    public function pause(Request $request, string $subscription): JsonResponse
    {
        $model = $this->find($subscription);

        $this->assertStatusIn($model, [Subscription::STATUS_ACTIVE]);

        $request->validate([
            'start_date' => ['required', 'string', 'regex:'.self::DATE_PATTERN],
            'end_date' => ['required', 'string', 'regex:'.self::DATE_PATTERN],
            'pause_reason' => ['sometimes', 'nullable', 'string', 'max:255'],
        ]);

        $start = $this->parseDate((string) $request->input('start_date'), 'start_date');
        $end = $this->parseDate((string) $request->input('end_date'), 'end_date');
        $today = $this->today();

        if ($start->lt($today)) {
            // Geçmiş bir günü duraklatmak üretilmiş siparişi silmez ve
            // yalnız raporu bozar.
            throw ApiException::validationFailed(
                'Duraklatma başlangıcı bugünden geriye alınamaz.',
                ['field' => 'start_date'],
            );
        }

        if ($end->lt($start)) {
            throw ApiException::validationFailed(
                'Duraklatma bitişi başlangıçtan önce olamaz.',
                ['field' => 'end_date'],
            );
        }

        foreach ($model->pauses as $existing) {
            if ($start->lte($existing->end_date->copy()->startOfDay())
                && $end->gte($existing->start_date->copy()->startOfDay())
            ) {
                throw $this->conflict(
                    'Bu aralık mevcut bir duraklamayla çakışıyor.',
                    ['conflict' => 'overlapping_pause', 'pause_id' => (int) $existing->id],
                );
            }
        }

        $reason = $this->trimmedOrNull($request->input('pause_reason'));
        $warnings = $this->generatedOrderWarnings($model, 'generated_orders_in_range', $start, $end);

        /*
         * ═════════════════════════════════════════════════════════════════
         * DURUM YALNIZ PENCERE **BUGÜN** YÜRÜRLÜKTEYSE DEĞİŞİR (I2).
         *
         * Eskiden `status = paused` koşulsuz yazılıyordu. `runsOnDate()` ilk
         * kontrolü `status !== active` olduğu için, YARIN için girilen bir
         * duraklatma BUGÜNÜN üretimini de kesiyordu — ve Kontrol Merkezi
         * panelinin varsayılanı yarındı, yani en sık yapılan hareket en
         * pahalı hatayı üretiyordu. Kimse hata almıyor, mutfak siparişi hiç
         * görmüyor ve eksik yemek ancak teslimatta anlaşılıyordu.
         *
         * Gelecekteki pencere için abonelik `active` KALIR; o günleri
         * `Subscription::pauseCovering()` zaten eliyor. Pencere geldiğinde
         * durumu gece işi ilerletiyor
         * (`SubscriptionGenerateCommand::syncPauseStates()`).
         * ═════════════════════════════════════════════════════════════════
         */
        $effectiveNow = $start->lte($today) && $end->gte($today);
        $nextStatus = $effectiveNow ? Subscription::STATUS_PAUSED : (string) $model->status;

        if (!$effectiveNow) {
            // SESSİZ GEÇİLMEZ: ekranda "duraklatıldı" rozeti beklerken
            // "aktif" görmek, yöneticiye isteğin işlemediğini düşündürür.
            $warnings[] = [
                'code' => 'pause_scheduled',
                'starts_on' => $start->toDateString(),
            ];
        }

        return $this->write(
            $request,
            'subscription.pause',
            ControlAudit::TARGET_SUBSCRIPTION,
            (int) $model->id,
            [
                'start_date' => $start->toDateString(),
                'end_date' => $end->toDateString(),
                'pause_reason' => $reason,
            ],
            fn(): array => [
                'action' => 'subscription.pause',
                'id' => (int) $model->id,
                'status' => $nextStatus,
                'effective_now' => $effectiveNow,
                'pause' => [
                    'start_date' => $start->toDateString(),
                    'end_date' => $end->toDateString(),
                ],
                'warnings' => $warnings,
            ],
            function () use ($model, $start, $end, $reason, $warnings, $nextStatus, $effectiveNow): array {
                $pause = new SubscriptionPause;
                $pause->subscription_id = $model->id;
                $pause->start_date = $start->toDateString();
                $pause->end_date = $end->toDateString();
                $pause->reason = $reason;
                $pause->save();

                if ($effectiveNow) {
                    $model->status = $nextStatus;
                    $model->save();
                }

                return [
                    'data' => [
                        'id' => (int) $model->id,
                        'status' => (string) $model->status,
                        // EKRAN İKİSİNİ AYIRMALI: "şimdi durdu" ile
                        // "ileride duracak" farklı cümlelerdir.
                        'effective_now' => $effectiveNow,
                        'pause' => [
                            'id' => (int) $pause->id,
                            'start_date' => $start->toDateString(),
                            'end_date' => $end->toDateString(),
                        ],
                    ],
                    'warnings' => $warnings,
                ];
            },
        );
    }

    /**
     * Duraklamayı bugün itibarıyla kapatır.
     *
     * SATIR SİLİNMEZ, `end_date` düne çekilir: "ne zaman duraklatıldı, ne
     * zaman devam edildi" sorusunun cevabı kalmalı. Silinseydi geçmişteki
     * boş günlerin sebebi kaybolurdu.
     *
     * ─────────────────────────────────────────────────────────────────────
     * HENÜZ BAŞLAMAMIŞ DURAKLATMA `end_date` İLE KAPATILAMAZ (I2).
     *
     * Yarın başlayacak bir duraklamada `end_date = dün` yazmak
     * `end_date < start_date` olan bir satır bırakıyordu: ekranda
     * "12.09 – 10.09" diye okunuyor ve aralık karşılaştırması ters aralıkta
     * tanımsız davranıyordu. Doğru cevap tarihleri bozmak değil, satırı
     * "yürürlüğe girmeden iptal edildi" diye işaretlemek — `cancelled_at`.
     *
     * BAŞLAMIŞ duraklatma bu yolu KULLANMAZ: o günler gerçekten boş kaldı
     * ve `end_date`'i düne çekmek onu doğru anlatıyor.
     * ─────────────────────────────────────────────────────────────────────
     *
     * ABONELİK `active` DEĞİLKEN DE ÇAĞRILABİLİR: ileri tarihli bir
     * duraklatma girildiğinde durum artık hemen `paused` olmuyor
     * (`pause()`), yani "vazgeçtim" diyen yönetici aboneliği `active`
     * bulacak. Eski kabul listesi orada 409 verirdi ve girdiği duraklatmayı
     * geri alamazdı.
     */
    public function resume(Request $request, string $subscription): JsonResponse
    {
        $model = $this->find($subscription);

        $this->assertStatusIn($model, [
            Subscription::STATUS_PAUSED,
            Subscription::STATUS_ACTIVE,
        ]);

        $today = $this->today();
        $open = $this->openPause($model, $today);

        if ($open === null && $model->status === Subscription::STATUS_ACTIVE) {
            throw $this->conflict(
                'Geri alınacak bir duraklatma yok; abonelik zaten çalışıyor.',
                ['conflict' => 'no_pause', 'status' => (string) $model->status],
            );
        }

        return $this->write(
            $request,
            'subscription.resume',
            ControlAudit::TARGET_SUBSCRIPTION,
            (int) $model->id,
            ['pause_id' => $open !== null ? (int) $open->id : null],
            fn(): array => [
                'action' => 'subscription.resume',
                'id' => (int) $model->id,
                'status' => Subscription::STATUS_ACTIVE,
                'pause_id' => $open !== null ? (int) $open->id : null,
            ],
            function () use ($model, $open, $today): array {
                if ($open !== null) {
                    if ($open->start_date->copy()->startOfDay()->gt($today)) {
                        // HENÜZ BAŞLAMADI: tarihlere dokunulmaz, satır
                        // iptal işaretlenir. `end_date`'i düne çekmek
                        // `end_date < start_date` bırakırdı.
                        $open->cancelled_at = BusinessTime::forStorage(BusinessTime::now());
                    } else {
                        $open->end_date = $today->copy()->subDay()->toDateString();
                    }

                    $open->save();
                }

                $model->status = Subscription::STATUS_ACTIVE;
                $model->save();

                return ['data' => [
                    'id' => (int) $model->id,
                    'status' => Subscription::STATUS_ACTIVE,
                    'next_service_date' => $this->nextServiceDate(
                        $model->fresh(['pauses', 'exceptions']),
                    ),
                ]];
            },
        );
    }

    /**
     * İptal — GERİ DÖNÜŞÜ YOKTUR.
     *
     * Yeniden başlatmak yeni abonelik açmaktır; iptal edilmiş bir kuralı
     * canlandırmak, iptal tarihinden sonraki günlerin hangi kurala tabi
     * olduğunu belirsiz kılardı.
     */
    public function cancel(Request $request, string $subscription): JsonResponse
    {
        $model = $this->find($subscription);

        if ($model->status === Subscription::STATUS_CANCELLED) {
            throw $this->conflict(
                'Abonelik zaten iptal edilmiş.',
                ['conflict' => 'cancelled'],
            );
        }

        $request->validate([
            'effective_date' => ['sometimes', 'nullable', 'string', 'regex:'.self::DATE_PATTERN],
        ]);

        $today = $this->today();

        /*
         * VARSAYIM: `effective_date` gönderilmezse BUGÜN. Sözleşme alanı
         * "ek gövde" diye listeliyor ama zorunlu demiyor; "şimdi iptal et"
         * en sık istenen hâl ve onu 422 ile geri çevirmek panele anlamsız
         * bir zorunlu alan koydururdu.
         */
        $effective = $request->filled('effective_date')
            ? $this->parseDate((string) $request->input('effective_date'), 'effective_date')
            : $today->copy();

        if ($effective->lt($today)) {
            throw ApiException::validationFailed(
                'İptal günü bugünden geriye alınamaz.',
                ['field' => 'effective_date'],
            );
        }

        $warnings = $this->generatedOrderWarnings(
            $model,
            'generated_orders_after_cancel',
            $effective->copy()->addDay(),
        );

        return $this->write(
            $request,
            'subscription.cancel',
            ControlAudit::TARGET_SUBSCRIPTION,
            (int) $model->id,
            ['effective_date' => $effective->toDateString(), 'from' => (string) $model->status],
            fn(): array => [
                'action' => 'subscription.cancel',
                'id' => (int) $model->id,
                'status' => Subscription::STATUS_CANCELLED,
                'effective_date' => $effective->toDateString(),
                'warnings' => $warnings,
            ],
            function () use ($model, $effective, $warnings): array {
                $model->status = Subscription::STATUS_CANCELLED;
                $model->end_date = $effective->toDateString();
                $model->save();

                return [
                    'data' => [
                        'id' => (int) $model->id,
                        'status' => Subscription::STATUS_CANCELLED,
                        'end_date' => $effective->toDateString(),
                    ],
                    'warnings' => $warnings,
                ];
            },
        );
    }

    /**
     * Önümüzdeki servis günleri.
     *
     * KAYNAK `Subscription::upcomingServiceDays()` — üretim işinin
     * kullandığı metodun ta kendisi. Takvim kendi mantığını yazsaydı
     * ekranda görünen günler ile gerçekte üretilenler zamanla ayrışırdı ve
     * bu ayrışmanın fark edileceği yer mutfak olurdu.
     */
    public function calendar(Request $request, string $subscription): JsonResponse
    {
        $model = $this->find($subscription);

        $request->validate([
            'from' => ['sometimes', 'string', 'regex:'.self::DATE_PATTERN],
            'days' => ['sometimes', 'integer', 'min:1', 'max:'.self::CALENDAR_MAX_DAYS],
        ]);

        $from = $request->filled('from')
            ? $this->parseDate((string) $request->query('from'), 'from')
            : $this->today();

        $days = (int) $request->query('days', (string) self::CALENDAR_DEFAULT_DAYS);
        $days = min(self::CALENDAR_MAX_DAYS, max(1, $days));

        $rows = $model->upcomingServiceDays($from, $days);
        $runs = $this->runsByDate($model, $from, $from->copy()->addDays($days));
        $released = $this->releaseTimes(array_filter(array_column($runs, 'order_id')));

        $data = [];

        foreach ($rows as $row) {
            $key = $row['date']->toDateString();
            $exception = $this->exceptionFor($model, $row['date']);
            $run = $runs[$key] ?? null;
            $orderId = $run !== null ? $this->nullableInt($run['order_id']) : null;

            $data[] = [
                'date' => $key,
                'weekday' => $row['date']->dayOfWeekIso,
                'quantity' => $row['quantity'],
                'closed' => $row['closed'],
                'note' => $row['note'],
                'exception' => $exception === null ? null : [
                    'skip' => (bool) $exception->skip,
                    'quantity_override' => $this->nullableInt($exception->quantity_override),
                    'note' => $this->trimmedOrNull($exception->note),
                ],
                'generated' => $orderId !== null,
                'order_id' => $orderId,
                'released_at' => $orderId !== null ? ($released[$orderId] ?? null) : null,
            ];
        }

        return $this->json([
            'data' => $data,
            // SAYFALANMAZ: `page`/`per_page`/`total`/`last_page` dörtlüsü
            // bilerek yok — boş bir sayfalayıcı çizdirmesin (§5).
            'meta' => ['from' => $from->toDateString(), 'days' => $days, 'subscription_id' => (int) $model->id],
            'server_time' => $this->serverTime(),
        ]);
    }

    /**
     * Tek-gün istisnası — kural değişikliği DEĞİL.
     *
     * `(subscription_id, service_date)` tekildir ve aynı gün için ikinci
     * istisna ÜZERİNE YAZILIR, `409` verilmez: yönetici aynı güne iki kez
     * karar verebilir ve son karar geçerlidir. İkisi de denetim izinde
     * görünür, yani "önce 12 dedi sonra atla dedi" okunabilir kalır.
     */
    public function storeException(Request $request, string $subscription): JsonResponse
    {
        $model = $this->find($subscription);

        $request->validate([
            'service_date' => ['required', 'string', 'regex:'.self::DATE_PATTERN],
            'skip' => ['sometimes', 'boolean'],
            'quantity_override' => ['sometimes', 'nullable', 'integer', 'min:1'],
            'note' => ['sometimes', 'nullable', 'string', 'max:255'],
        ]);

        $date = $this->parseDate((string) $request->input('service_date'), 'service_date');
        $skip = $request->boolean('skip');
        $override = $this->nullableInt($request->input('quantity_override'));
        $note = $this->trimmedOrNull($request->input('note'));

        if ($skip && $override !== null) {
            // "Atla ama 12 yap" tutarsız; ikisinden hangisinin kazandığını
            // sonradan okuyan kimse bilemezdi.
            throw ApiException::validationFailed(
                'Atlanan günde adet değişikliği verilemez.',
                ['field' => 'quantity_override'],
            );
        }

        if ($date->lt($this->today())) {
            throw ApiException::validationFailed(
                'Geçmiş bir güne istisna girilemez.',
                ['field' => 'service_date'],
            );
        }

        if (!in_array($date->dayOfWeekIso, $this->serviceDays($model), true)) {
            // Cumartesiye istisna girmek, hiçbir zaman uygulanmayacak bir
            // kayıt yaratırdı.
            throw ApiException::validationFailed(
                'Bu gün aboneliğin servis günlerinden biri değil.',
                ['reason' => 'not_a_service_day', 'weekday' => $date->dayOfWeekIso],
            );
        }

        $run = $this->runFor($model, $date);

        if ($run !== null && $run->order_id !== null) {
            throw $this->conflict(
                'O gün için sipariş zaten üretilmiş; değişiklik revizyonla yapılır.',
                ['conflict' => 'already_generated', 'order_id' => (int) $run->order_id],
            );
        }

        return $this->write(
            $request,
            'subscription.exception.create',
            ControlAudit::TARGET_SUBSCRIPTION,
            (int) $model->id,
            [
                'service_date' => $date->toDateString(),
                'skip' => $skip,
                'quantity_override' => $override,
            ],
            fn(): array => [
                'action' => 'subscription.exception.create',
                'id' => (int) $model->id,
                'service_date' => $date->toDateString(),
                'skip' => $skip,
                'quantity_override' => $override,
                'quantity' => $skip ? 0 : ($override ?? (int) $model->default_quantity),
            ],
            function () use ($model, $date, $skip, $override, $note): array {
                $exception = SubscriptionException::query()
                    ->where('subscription_id', $model->id)
                    ->whereDate('service_date', $date->toDateString())
                    ->first() ?? new SubscriptionException;

                $exception->subscription_id = $model->id;
                $exception->service_date = $date->toDateString();
                $exception->skip = $skip;
                $exception->quantity_override = $override;
                $exception->note = $note;
                $exception->save();

                return ['data' => [
                    'id' => (int) $exception->id,
                    'service_date' => $date->toDateString(),
                    'skip' => $skip,
                    'quantity_override' => $override,
                    'note' => $note,
                ]];
            },
        );
    }

    /**
     * İstisnayı kaldırır — GERÇEK SİLME.
     *
     * İstisna bir belge değil bir kuraldır; iptal edilmiş bir kuralın
     * "iptal edilmiş" hâlini saklamak, üretim sorgularının her seferinde
     * bir bayrak daha kontrol etmesi demekti. Kaydın tarihçesi denetim
     * izindedir.
     */
    public function destroyException(Request $request, string $subscription, string $date): JsonResponse
    {
        $model = $this->find($subscription);
        $day = $this->parseDate($date, 'date');

        $exception = SubscriptionException::query()
            ->where('subscription_id', $model->id)
            ->whereDate('service_date', $day->toDateString())
            ->first();

        if ($exception === null) {
            throw ApiException::notFound('O gün için istisna kaydı yok.');
        }

        return $this->write(
            $request,
            'subscription.exception.delete',
            ControlAudit::TARGET_SUBSCRIPTION,
            (int) $model->id,
            ['service_date' => $day->toDateString(), 'exception_id' => (int) $exception->id],
            fn(): array => [
                'action' => 'subscription.exception.delete',
                'id' => (int) $model->id,
                'service_date' => $day->toDateString(),
                'exception_id' => (int) $exception->id,
            ],
            function () use ($exception, $day): array {
                $exception->delete();

                return ['data' => ['service_date' => $day->toDateString(), 'deleted' => true]];
            },
        );
    }

    /**
     * Üretim defteri — idempotency kaydı.
     *
     * `order_id: null` olan satır, üretimin DENENDİĞİ ama sipariş
     * oluşmadığı anlamına gelir (kapalı gün, menü yayınlanmamış, stok
     * dolu). Satır yine de yazılır ki gece işi ertesi koşuda aynı günü
     * yeniden denemesin ve "neden sipariş yok" sorusunun bir cevabı olsun.
     */
    public function runs(Request $request, string $subscription): JsonResponse
    {
        $model = $this->find($subscription);

        $request->validate([
            'from' => ['sometimes', 'string', 'regex:'.self::DATE_PATTERN],
            'to' => ['sometimes', 'string', 'regex:'.self::DATE_PATTERN],
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ]);

        $query = SubscriptionRun::query()->where('subscription_id', $model->id);

        if ($request->filled('from')) {
            $query->whereDate(
                'service_date',
                '>=',
                $this->parseDate((string) $request->query('from'), 'from')->toDateString(),
            );
        }
        if ($request->filled('to')) {
            $query->whereDate(
                'service_date',
                '<=',
                $this->parseDate((string) $request->query('to'), 'to')->toDateString(),
            );
        }

        $perPage = min(100, max(1, (int) $request->query('per_page', '25')));
        $page = max(1, (int) $request->query('page', '1'));
        $total = (int) $query->toBase()->getCountForPagination();

        $rows = $query->orderByDesc('service_date')->orderByDesc('id')->forPage($page, $perPage)->get();

        $orders = Order::query()
            ->whereIn('order_id', $rows->pluck('order_id')->filter()->all())
            ->get()
            ->keyBy('order_id');

        $released = $this->releaseTimes($rows->pluck('order_id')->filter()->map(intval(...))->all());

        return $this->json([
            'data' => $rows->map(function (SubscriptionRun $run) use ($orders, $released): array {
                $orderId = $this->nullableInt($run->order_id);
                $order = $orderId !== null ? $orders->get($orderId) : null;

                return [
                    'id' => (int) $run->id,
                    'service_date' => $this->dateOf($run->service_date),
                    'delivery_point_id' => (int) $run->delivery_point_id,
                    'order_id' => $orderId,
                    'order_number' => $order !== null ? $this->presenter->number($order) : null,
                    'order_status' => $order !== null ? $this->transitions->codeOf($order) : null,
                    'quantity' => $order !== null ? (int) $order->total_items : null,
                    'released_at' => $orderId !== null ? ($released[$orderId] ?? null) : null,
                    'created_at' => self::ts($run->created_at),
                ];
            })->all(),
            'meta' => [
                'page' => $page,
                'per_page' => $perPage,
                'total' => $total,
                'last_page' => max(1, (int) ceil($total / $perPage)),
            ],
            'server_time' => $this->serverTime(),
        ]);
    }

    /**
     * Belirli bir gün için elle üretim.
     *
     * KURAL GECE İŞİYLE AYNI: `runsOnDate()` süzgeci, nokta başına bir
     * sipariş, `veykemtu_subscription_runs` üzerindeki tekil kısıt ve
     * `OrderFactory::createForSubscription()`. İdempotency güvencesi
     * koddaki `if` değil VERİTABANI KISITIDIR; buradaki ön kontrol onu
     * 500 yerine `409`'a çevirmek içindir.
     *
     * Stok tavanı burada denetleniyor çünkü elle üretim, abonelik
     * rezervasyonunun (iş kararı 6) dışında kalan bir taleptir.
     */
    public function generate(Request $request, string $subscription): JsonResponse
    {
        $model = $this->find($subscription);

        $request->validate([
            'service_date' => ['required', 'string', 'regex:'.self::DATE_PATTERN],
            'release_now' => ['sometimes', 'boolean'],
        ]);

        $date = $this->parseDate((string) $request->input('service_date'), 'service_date');
        $releaseNow = $request->boolean('release_now');
        $today = $this->today();
        $lookahead = SettingsRepository::MAX_LOOKAHEAD_DAYS;

        if ($date->lt($today) || $date->gt($today->copy()->addDays($lookahead))) {
            throw ApiException::validationFailed(
                'Üretim günü bugünden en fazla '.$lookahead.' gün ileri olabilir.',
                ['field' => 'service_date', 'max_lookahead_days' => $lookahead],
            );
        }

        if (!$model->runsOnDate($date)) {
            throw ApiException::validationFailed(
                'Abonelik o gün üretim yapmıyor.',
                ['reason' => 'not_a_service_day', 'weekday' => $date->dayOfWeekIso],
            );
        }

        $existing = $this->runFor($model, $date);

        if ($existing !== null) {
            throw $this->conflict(
                'O gün için üretim defterinde kayıt zaten var.',
                ['conflict' => 'already_generated', 'order_id' => $this->nullableInt($existing->order_id)],
            );
        }

        $quantity = max(1, $model->quantityForDate($date));
        $targets = $this->generationTargets($model);
        $skipReason = $this->generationBlocker($model, $date);

        if ($skipReason === null) {
            $this->assertDayCapacity($model, $date, $quantity * count($targets));
        }

        /*
         * DAMGAYI BU UÇ ATMAZ — `release_now` dışında. Siparişi doğuran
         * `OrderFactory` zaten aynı kuralı uyguluyor; ikinci bir yazma aynı
         * anı iki yerde hesaplamak olurdu ve hesaplar ayrıştığı gün sessizce
         * kazanan buradaki olurdu.
         */
        $forcedReleaseAt = $releaseNow ? BusinessTime::now() : null;

        /*
         * Kuru provanın cevabı. Yazılmış bir satır yok, dolayısıyla okunacak
         * damga da yok: planlanan an aynı kuralla ÖNCEDEN hesaplanıyor.
         * `null` = anında görünür.
         */
        $plannedReleaseAt = $forcedReleaseAt ?? $this->scheduledReleaseAt($model, $date);

        $plan = array_map(static fn(array $t): array => [
            'delivery_point_id' => $t['id'],
            'quantity' => $quantity,
            'release_at' => self::ts($plannedReleaseAt),
        ], $targets);

        return $this->write(
            $request,
            'subscription.generate',
            ControlAudit::TARGET_SUBSCRIPTION,
            (int) $model->id,
            [
                'service_date' => $date->toDateString(),
                'release_now' => $releaseNow,
                'target_count' => count($targets),
            ],
            fn(): array => [
                'action' => 'subscription.generate',
                'service_date' => $date->toDateString(),
                'would_create' => $skipReason === null ? $plan : [],
                'skipped' => $skipReason === null ? [] : $this->skippedPlan($plan, $skipReason),
            ],
            fn(): array => ['data' => $this->runGeneration(
                $model,
                $date,
                $targets,
                $quantity,
                $forcedReleaseAt,
                $skipReason,
            )],
        );
    }

    /**
     * Üretilmiş bir siparişi serbest bırakma saatinden ÖNCE mutfağa açar.
     *
     * Gece 00:12'de üretilen kırk sipariş, sabah 05:00'te işbaşı yapan
     * mutfağın ekranını doldurur ve o an gelen GERÇEK bir siparişi görünmez
     * kılardı; serbest bırakma saati panoyu vardiya başlangıcıyla hizalar.
     * Bu uç o hizayı tek sipariş için bilinçli olarak bozar.
     *
     * ZATEN AÇILMIŞSA `409` DEĞİL `ok: true`: yönetici için sonuç aynı
     * (sipariş mutfakta) ve çift tıklamayı hata olarak göstermek, hiçbir
     * şeyi düzeltmeyen bir uyarı üretirdi.
     */
    public function releaseOrder(Request $request, string $order): JsonResponse
    {
        $model = Order::find((int) $order);

        if ($model === null) {
            throw ApiException::notFound('Sipariş bulunamadı.');
        }

        if ($this->nullableInt($model->bld_subscription_id) === null) {
            throw ApiException::validationFailed(
                'Bu sipariş abonelikten üretilmemiş.',
                ['field' => 'order', 'reason' => 'not_a_subscription_order'],
            );
        }

        $scheduled = $model->getAttribute(self::RELEASE_COLUMN);

        return $this->write(
            $request,
            'subscription.order.release',
            ControlAudit::TARGET_ORDER,
            (int) $model->order_id,
            [
                'subscription_id' => (int) $model->bld_subscription_id,
                'was_scheduled_for' => self::ts($scheduled),
            ],
            fn(): array => [
                'action' => 'subscription.order.release',
                'order_id' => (int) $model->order_id,
                'was_scheduled_for' => self::ts($scheduled),
            ],
            function () use ($model, $scheduled): array {
                $now = BusinessTime::now();

                DB::table('orders')
                    ->where('order_id', $model->order_id)
                    ->update([self::RELEASE_COLUMN => BusinessTime::forStorage($now)]);

                return ['data' => [
                    'order_id' => (int) $model->order_id,
                    'released_at' => $now->utc()->toIso8601ZuluString(),
                    'was_scheduled_for' => self::ts($scheduled),
                ]];
            },
        );
    }

    // ── Talepler ─────────────────────────────────────────────────────────

    /**
     * Teklif formundan gelen talepler — sayfalı, İLETİŞİM BİLGİSİ MASKELİ.
     *
     * Bu uçlar `customers` alanındaki okuma denetimine tabi DEĞİL: kayıtlar
     * müşteri değil, henüz iletişime geçilmemiş adaylar ve liste günde
     * birkaç kez açılan bir iş kuyruğu. Her açılışı denetlemek izi doldurup
     * asıl erişimleri görünmez kılardı. Buna karşılık ad ve iletişim
     * bilgisi listede maskeleniyor — arayacak kişi kaydı zaten açar.
     */
    public function requests(Request $request): JsonResponse
    {
        /*
         * ═════════════════════════════════════════════════════════════════
         * `status` ARTIK VİRGÜLLÜ LİSTE (I4-16).
         *
         * `Rule::in` TEKİLDİ ve Kontrol Merkezi geçidi bu alanı `_csv()` ile
         * gönderiyor. Bugün panel tek değer yolladığı için patlamıyordu; ekrana
         * ikinci bir süzgeç eklendiği gün SESSİZCE 422 verecekti — ve hata
         * "çoklu süzgeç desteklenmiyor" demeyecek, "geçersiz durum" diyecekti.
         * `subscriptions` listesi zaten virgüllü liste kabul ediyor; iki uç
         * arasındaki bu ayrım bir sözleşme tutarsızlığıydı.
         * ═════════════════════════════════════════════════════════════════
         */
        $request->validate([
            'status' => ['sometimes', 'string', 'max:120'],
            'q' => ['sometimes', 'string', 'max:120'],
            'from' => ['sometimes', 'string', 'regex:'.self::DATE_PATTERN],
            'to' => ['sometimes', 'string', 'regex:'.self::DATE_PATTERN],
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ]);

        $query = QuoteRequest::query();

        if ($request->filled('status')) {
            $statuses = $this->csv((string) $request->query('status'));

            foreach ($statuses as $status) {
                if (!in_array($status, QuoteRequest::STATUSES, true)) {
                    throw ApiException::validationFailed(
                        'Bilinmeyen talep durumu: '.$status.'.',
                        ['field' => 'status', 'allowed' => QuoteRequest::STATUSES],
                    );
                }
            }

            $query->whereIn('status', $statuses);
        }

        if ($request->filled('q')) {
            $like = '%'.trim((string) $request->query('q')).'%';
            $query->where(static function ($builder) use ($like): void {
                $builder->where('full_name', 'like', $like)
                    ->orWhere('organization', 'like', $like)
                    ->orWhere('telephone', 'like', $like)
                    ->orWhere('email', 'like', $like);
            });
        }

        if ($request->filled('from')) {
            $query->whereDate(
                'created_at',
                '>=',
                $this->parseDate((string) $request->query('from'), 'from')->toDateString(),
            );
        }
        if ($request->filled('to')) {
            $query->whereDate(
                'created_at',
                '<=',
                $this->parseDate((string) $request->query('to'), 'to')->toDateString(),
            );
        }

        $perPage = min(100, max(1, (int) $request->query('per_page', '25')));
        $page = max(1, (int) $request->query('page', '1'));
        $total = (int) $query->toBase()->getCountForPagination();

        $rows = $query->newestFirst()->forPage($page, $perPage)->get();

        return $this->json([
            'data' => $rows->map(fn(QuoteRequest $r): array => [
                'id' => (int) $r->id,
                'full_name' => $this->maskName((string) $r->full_name),
                'organization' => $this->trimmedOrNull($r->organization),
                'telephone' => $this->maskPhone($r->telephone),
                'email' => $this->maskEmail($r->email),
                'service_type' => $this->trimmedOrNull($r->service_type),
                'headcount' => $this->nullableInt($r->headcount),
                'frequency' => $this->trimmedOrNull($r->frequency),
                'start_date' => $this->dateOf($r->start_date),
                'location' => $this->trimmedOrNull($r->location),
                'status' => (string) $r->status,
                'converted_subscription_id' => $this->convertedIdOf($r),
                'created_at' => self::ts($r->created_at),
            ])->all(),
            'meta' => [
                'page' => $page,
                'per_page' => $perPage,
                'total' => $total,
                'last_page' => max(1, (int) ceil($total / $perPage)),
            ],
            'server_time' => $this->serverTime(),
        ]);
    }

    /** Tek talep — MASKESİZ. Arayacak kişi tam numarayı burada görür. */
    public function showRequest(Request $request, string $request_id): JsonResponse
    {
        $row = QuoteRequest::find((int) $request_id);

        if ($row === null) {
            throw ApiException::notFound('Talep bulunamadı.');
        }

        return $this->json([
            'data' => [
                'id' => (int) $row->id,
                'full_name' => (string) $row->full_name,
                'organization' => $this->trimmedOrNull($row->organization),
                'telephone' => $this->trimmedOrNull($row->telephone),
                'email' => $this->trimmedOrNull($row->email),
                'service_type' => $this->trimmedOrNull($row->service_type),
                'headcount' => $this->nullableInt($row->headcount),
                'frequency' => $this->trimmedOrNull($row->frequency),
                'start_date' => $this->dateOf($row->start_date),
                'location' => $this->trimmedOrNull($row->location),
                'menu_preference' => $this->trimmedOrNull($row->menu_preference),
                'kitchen_note' => $this->trimmedOrNull($row->kitchen_note),
                'message' => $this->trimmedOrNull($row->message),
                // Onaysız kayıt hiç oluşmaz; alan her zaman dolu.
                'kvkk_accepted_at' => self::ts($row->kvkk_accepted_at),
                'submitted_at' => self::ts($row->submitted_at),
                'status' => (string) $row->status,
                'admin_note' => $this->trimmedOrNull($row->admin_note),
                'converted_subscription_id' => $this->convertedIdOf($row),
                'created_at' => self::ts($row->created_at),
                'updated_at' => self::ts($row->updated_at),
            ],
            'server_time' => $this->serverTime(),
        ]);
    }

    /**
     * Durum ve iç not.
     *
     * TALEBİN KENDİSİ DEĞİŞTİRİLEMEZ (ziyaretçinin yazdığı alanlar): bir
     * kaydın içeriğini düzeltebilen bir panel, o kaydın delil değerini yok
     * eder.
     */
    public function updateRequest(Request $request, string $request_id): JsonResponse
    {
        $row = QuoteRequest::find((int) $request_id);

        if ($row === null) {
            throw ApiException::notFound('Talep bulunamadı.');
        }

        $request->validate([
            'status' => ['sometimes', Rule::in(QuoteRequest::STATUSES)],
            'admin_note' => ['sometimes', 'nullable', 'string', 'max:2000'],
        ]);

        $status = $request->filled('status') ? (string) $request->input('status') : null;
        $note = $request->has('admin_note') ? $this->trimmedOrNull($request->input('admin_note')) : null;
        $noteGiven = $request->has('admin_note');

        return $this->write(
            $request,
            'subscription.request.update',
            ControlAudit::TARGET_QUOTE_REQUEST,
            (int) $row->id,
            [
                'status' => $status,
                'from' => (string) $row->status,
                // Notun METNİ yazılmıyor, yalnız yazıldığı: iç not
                // müşteriyle yapılan görüşmeyi taşıyor ve denetim izini
                // ikinci bir kişisel veri deposuna çevirmemeli.
                'admin_note_set' => $noteGiven,
            ],
            fn(): array => [
                'action' => 'subscription.request.update',
                'id' => (int) $row->id,
                'status' => $status ?? (string) $row->status,
            ],
            function () use ($row, $status, $note, $noteGiven): array {
                if ($status !== null) {
                    $row->status = $status;
                }
                if ($noteGiven) {
                    $row->admin_note = $note;
                }
                $row->save();

                return ['data' => [
                    'id' => (int) $row->id,
                    'status' => (string) $row->status,
                    'admin_note' => $this->trimmedOrNull($row->admin_note),
                ]];
            },
        );
    }

    /**
     * Talebi aboneliğe çevirir.
     *
     * TALEP SİLİNMEZ: `status = kapandi` olur ve `converted_subscription_id`
     * dolar. `customer_id` ZORUNLUDUR ve bu uç MÜŞTERİ YARATMAZ — hesap
     * açmak parola ve e-posta doğrulaması gerektirir, ikisi de bu
     * sözleşmenin dışındadır.
     *
     * Abonelik yine `pending` doğar: sözleşme imzalanmadan aktifleşmez.
     */
    public function convertRequest(Request $request, string $request_id): JsonResponse
    {
        $row = QuoteRequest::find((int) $request_id);

        if ($row === null) {
            throw ApiException::notFound('Talep bulunamadı.');
        }

        $converted = $this->convertedIdOf($row);

        if ($converted !== null) {
            throw $this->conflict(
                'Talep zaten bir aboneliğe çevrilmiş.',
                ['conflict' => 'already_converted', 'subscription_id' => $converted],
            );
        }

        $request->validate([
            'customer_id' => ['required', 'integer', 'exists:customers,customer_id'],
            'subscription' => ['required', 'array'],
            ...$this->subscriptionRules('subscription.'),
        ]);

        $customerId = (int) $request->input('customer_id');
        $body = (array) $request->input('subscription');

        $this->assertSubscriptionShape($body, $customerId, 'subscription.');

        $preview = $this->createPreview($body, $customerId);

        return $this->write(
            $request,
            'subscription.request.convert',
            ControlAudit::TARGET_QUOTE_REQUEST,
            (int) $row->id,
            ['customer_id' => $customerId, 'start_date' => (string) $body['start_date']],
            static fn(): array => [
                'action' => 'subscription.request.convert',
                'request_id' => (int) $row->id,
                'request_status' => 'kapandi',
                ...$preview,
            ],
            function () use ($row, $customerId, $body): array {
                $model = DB::transaction(function () use ($row, $customerId, $body): Subscription {
                    $created = $this->persist($customerId, $body);

                    $row->status = 'kapandi';

                    if ($this->hasColumn('veykemtu_quote_requests', 'converted_subscription_id')) {
                        $row->converted_subscription_id = $created->id;
                    }

                    $row->save();

                    return $created;
                });

                return ['data' => [
                    'request_id' => (int) $row->id,
                    'request_status' => (string) $row->status,
                    'subscription' => ['id' => (int) $model->id, 'status' => (string) $model->status],
                ]];
            },
        );
    }

    // ── Sözleşmeler ──────────────────────────────────────────────────────

    /**
     * Aboneliğin sözleşmeleri.
     *
     * `token_hash` VE `body_html` DÖNMEZ. Belirteç dönerse imzalı bağlantı
     * denetim ekranından okunabilir hâle gelirdi; metin ise kilobaytlarca
     * HTML ve panel listesinde işi yok — sözleşmenin ne söylediği
     * `terms_snapshot`'ta duruyor.
     */
    public function contracts(Request $request, string $subscription): JsonResponse
    {
        $model = $this->find($subscription);

        $rows = SubscriptionContract::query()
            ->where('subscription_id', $model->id)
            ->orderByDesc('id')
            ->get();

        return $this->json([
            'data' => $rows->map(fn(SubscriptionContract $c): array => $this->contractRow($c))->all(),
            'server_time' => $this->serverTime(),
        ]);
    }

    /**
     * Sözleşme oluşturur ve imzalı bağlantıyı gönderir.
     *
     * METİN, KOŞULLAR VE BAĞLANTI `ContractService`'İN İŞİ. Bu uç yalnız
     * kabuk: açık sözleşme var mı, gerekçe ve aktör alındı mı, kuru prova
     * mı. Metni burada kurmak, müşteri yüzündeki onay akışının okuduğu
     * belgeyle panelin ürettiği belgeyi ayırırdı.
     *
     * AYNI ANDA İKİ AÇIK SÖZLEŞME OLAMAZ (`draft`/`sent`): iki geçerli
     * bağlantı, hangisinin imzalandığını belirsiz kılardı. Önce iptal
     * edilir.
     */
    public function storeContract(Request $request, string $subscription): JsonResponse
    {
        $model = $this->find($subscription);

        $request->validate([
            'phone' => ['sometimes', 'nullable', 'string', 'max:32'],
            'expires_in_days' => [
                'sometimes', 'integer',
                'min:'.self::CONTRACT_EXPIRES_MIN, 'max:'.self::CONTRACT_EXPIRES_MAX,
            ],
            'send_sms' => ['sometimes', 'boolean'],
            'term_days' => ['sometimes', 'integer', 'min:1', 'max:365'],
        ]);

        $open = $this->openContract((int) $model->id);

        if ($open !== null) {
            throw $this->conflict(
                'Bu abonelikte açık bir sözleşme zaten var.',
                ['conflict' => 'open_contract', 'contract_id' => (int) $open->id],
            );
        }

        $phone = $this->contractPhone($model, $request->input('phone'));
        $this->assertContractable($model, $phone);

        $days = (int) $request->input('expires_in_days', self::CONTRACT_EXPIRES_DEFAULT);
        $termDays = $this->nullableInt($request->input('term_days'));
        $sendSms = $request->boolean('send_sms', true);

        return $this->write(
            $request,
            'subscription.contract.create',
            ControlAudit::TARGET_SUBSCRIPTION_CONTRACT,
            null,
            [
                'subscription_id' => (int) $model->id,
                'sent_to_phone' => $phone,
                'expires_in_days' => $days,
                'send_sms' => $sendSms,
                'agreed_unit_price_kurus' => $this->nullableInt($model->agreed_unit_price_kurus),
                // BAĞLANTI VE BELİRTEÇ YÜKE YAZILMAZ: denetim ekranından
                // okunabilen bir imza bağlantısı, imzanın kendisi kadar
                // değerlidir.
            ],
            fn(): array => [
                'action' => 'subscription.contract.create',
                'subscription_id' => (int) $model->id,
                'sent_to_phone' => $phone,
                'expires_in_days' => $days,
                'send_sms' => $sendSms,
                'agreed_unit_price_kurus' => $this->nullableInt($model->agreed_unit_price_kurus),
            ],
            function (array $intent) use ($model, $phone, $days, $termDays, $sendSms): array {
                $contract = $this->contractService->create(
                    $model,
                    $phone,
                    $days,
                    $intent['actor'],
                    $termDays,
                );

                $smsSent = $sendSms && $this->deliverContract($contract);

                return ['data' => [
                    'id' => (int) $contract->id,
                    'status' => $contract->controlStatus(),
                    'sent_to_phone' => $phone,
                    'expires_at' => self::ts($contract->expires_at),
                    /*
                     * BAĞLANTI YALNIZ GİTMEDİYSE DÖNER. SMS ulaştıysa link
                     * zaten müşterinin telefonunda ve panelde de göstermek
                     * onu ikinci bir yerde sızdırılabilir kılardı. Gitmediyse
                     * (elden iletme ya da sağlayıcı arızası) yöneticinin
                     * elinde başka bir yol kalmaz.
                     */
                    'sign_url' => $smsSent ? null : $this->contractService->signUrl($contract),
                    'sms_sent' => $smsSent,
                ]];
            },
        );
    }

    public function showContract(Request $request, string $contract): JsonResponse
    {
        return $this->json([
            'data' => $this->contractRow($this->findContract($contract)),
            'server_time' => $this->serverTime(),
        ]);
    }

    /**
     * Bağlantıyı yeniden gönderir.
     *
     * SÜREYE DOKUNULMAZSA BELİRTEÇ DE DEĞİŞMEZ. Belirteç `{id}-{bitiş}-{imza}`
     * biçiminde türetiliyor ve imza bitiş anını da kapsıyor; süreyi
     * tazelemek eski SMS'i öldürür. Bu yüzden `expires_in_days`
     * GÖNDERİLMEDİKÇE süre korunuyor — müşterinin elindeki eski bağlantının
     * çalışmaya devam etmesi, "hangi linke tıklayacağım" sorusunu ortadan
     * kaldırıyor.
     */
    public function resendContract(Request $request, string $contract): JsonResponse
    {
        $row = $this->findContract($contract);
        $status = $row->controlStatus();

        if (in_array($status, [self::CONTRACT_SIGNED, self::CONTRACT_CANCELLED], true)) {
            throw $this->conflict(
                'Bu sözleşmenin bağlantısı yeniden gönderilemez.',
                ['conflict' => $status, 'contract_id' => (int) $row->id],
            );
        }

        $request->validate([
            'expires_in_days' => [
                'sometimes', 'integer',
                'min:'.self::CONTRACT_EXPIRES_MIN, 'max:'.self::CONTRACT_EXPIRES_MAX,
            ],
        ]);

        $days = $request->filled('expires_in_days') ? (int) $request->input('expires_in_days') : null;

        return $this->write(
            $request,
            'subscription.contract.resend',
            ControlAudit::TARGET_SUBSCRIPTION_CONTRACT,
            (int) $row->id,
            [
                'subscription_id' => (int) $row->subscription_id,
                'sent_to_phone' => $row->sent_to_phone,
                'expires_in_days' => $days,
            ],
            fn(): array => [
                'action' => 'subscription.contract.resend',
                'contract_id' => (int) $row->id,
                'expires_in_days' => $days,
                'renews_link' => $days !== null || $row->isExpired(),
            ],
            function () use ($row, $days): array {
                $renew = $days;

                if ($row->isExpired()) {
                    /*
                     * SÜRESİ DOLMUŞ BAĞLANTI ÖNCE TAZELENİR. `resend()`
                     * kapısı `isApprovable()` istiyor ve süresi dolmuş kayıt
                     * oradan geçemez; oysa alan sözleşmesi yalnız `signed`
                     * ve `cancelled` için `409` istiyor. Süresi dolmuş bir
                     * bağlantıyı yeniden göndermek tam da bu ucun işi.
                     */
                    $this->contractService->issueLink(
                        $row,
                        $days ?? self::CONTRACT_EXPIRES_DEFAULT,
                    );
                    $renew = null;
                }

                $sent = $this->deliverContract($row, $renew);

                return ['data' => [
                    'id' => (int) $row->id,
                    'status' => $row->controlStatus(),
                    'sent_to_phone' => $this->trimmedOrNull($row->sent_to_phone),
                    'expires_at' => self::ts($row->expires_at),
                    'sign_url' => $sent ? null : $this->contractService->signUrl($row),
                    'sms_sent' => $sent,
                ]];
            },
        );
    }

    /**
     * Sözleşmeyi iptal eder.
     *
     * `signed` TERMİNALDİR. İmzalanmış bir sözleşmeyi iptal edilmiş
     * göstermek, imzanın kendisini geçersiz kılmaktır; yeni koşullar yeni
     * bir sözleşme gerektirir.
     */
    public function cancelContract(Request $request, string $contract): JsonResponse
    {
        $row = $this->findContract($contract);
        $status = $row->controlStatus();

        if ($status === self::CONTRACT_SIGNED) {
            throw $this->conflict(
                'İmzalanmış sözleşme iptal edilemez; yeni bir sözleşme oluşturun.',
                ['conflict' => 'signed', 'contract_id' => (int) $row->id],
            );
        }

        if ($status === self::CONTRACT_CANCELLED) {
            throw $this->conflict(
                'Sözleşme zaten iptal edilmiş.',
                ['conflict' => 'cancelled', 'contract_id' => (int) $row->id],
            );
        }

        return $this->write(
            $request,
            'subscription.contract.cancel',
            ControlAudit::TARGET_SUBSCRIPTION_CONTRACT,
            (int) $row->id,
            ['subscription_id' => (int) $row->subscription_id, 'from' => $status],
            fn(): array => [
                'action' => 'subscription.contract.cancel',
                'contract_id' => (int) $row->id,
                'status' => self::CONTRACT_CANCELLED,
            ],
            function (array $intent) use ($row): array {
                $this->contractService->cancel($row, mb_substr($intent['reason'], 0, 255));

                return ['data' => $this->contractRow($row->refresh())];
            },
        );
    }

    // ── Ödemeler ─────────────────────────────────────────────────────────

    /**
     * Dönem ödemeleri — SAYFALANMAZ.
     *
     * Bir aboneliğin dönem sayısı sınırlıdır ve ekran hepsini tek tablo
     * olarak çizer. `overdue` SUNUCUDA hesaplanıyor: istemcide
     * hesaplansaydı saati kaymış bir panelde borç bir gün erken kırmızıya
     * dönerdi.
     */
    public function payments(Request $request, string $subscription): JsonResponse
    {
        $model = $this->find($subscription);

        /*
         * `status` VİRGÜLLÜ LİSTE KABUL EDER (I4-16) — `requests()` ile aynı
         * gerekçe: Kontrol Merkezi geçidi bu alanı `_csv()` ile gönderiyor ve
         * `Rule::in` tekil kaldığı sürece ikinci bir süzgeç eklendiği gün
         * sessizce 422 çıkardı.
         */
        $request->validate([
            'status' => ['sometimes', 'string', 'max:60'],
            'from' => ['sometimes', 'string', 'regex:'.self::DATE_PATTERN],
            'to' => ['sometimes', 'string', 'regex:'.self::DATE_PATTERN],
        ]);

        $query = SubscriptionPayment::query()->where('subscription_id', $model->id);

        if ($request->filled('status')) {
            $panel = $this->csv((string) $request->query('status'));
            $raw = [];

            foreach ($panel as $value) {
                if (!in_array($value, [
                    self::PAYMENT_PENDING, self::PAYMENT_PAID, self::PAYMENT_VOID,
                ], true)) {
                    throw ApiException::validationFailed(
                        'Bilinmeyen ödeme durumu: '.$value.'.',
                        [
                            'field' => 'status',
                            'allowed' => [
                                self::PAYMENT_PENDING, self::PAYMENT_PAID, self::PAYMENT_VOID,
                            ],
                        ],
                    );
                }

                // ÇEVİRİ TEK YERDE (`rawPaymentStatuses`): panel sözlüğü
                // `pending|paid|void`, kayıt sözlüğü
                // `pending|succeeded|failed|refunded`.
                $raw = [...$raw, ...$this->rawPaymentStatuses($value)];
            }

            $query->whereIn('status', array_values(array_unique($raw)));
        }
        if ($request->filled('from')) {
            $query->whereDate(
                'period_start',
                '>=',
                $this->parseDate((string) $request->query('from'), 'from')->toDateString(),
            );
        }
        if ($request->filled('to')) {
            $query->whereDate(
                'period_end',
                '<=',
                $this->parseDate((string) $request->query('to'), 'to')->toDateString(),
            );
        }

        $rows = $query->orderByDesc('period_start')->orderByDesc('id')->get();
        $data = $rows->map(fn(SubscriptionPayment $p): array => $this->paymentRow($p))->all();

        $sum = static fn(callable $filter): int => array_sum(array_map(
            static fn(array $r): int => $r['amount_kurus'],
            array_filter($data, $filter),
        ));

        return $this->json([
            'data' => $data,
            'meta' => [
                'total_kurus' => $sum(static fn(array $r): bool => $r['status'] !== self::PAYMENT_VOID),
                'paid_kurus' => $sum(static fn(array $r): bool => $r['status'] === self::PAYMENT_PAID),
                'pending_kurus' => $sum(static fn(array $r): bool => $r['status'] === self::PAYMENT_PENDING),
                'overdue_kurus' => $sum(static fn(array $r): bool => $r['overdue']),
            ],
            'server_time' => $this->serverTime(),
        ]);
    }

    /**
     * Dönem borcu oluşturur.
     *
     * TUTAR SUNUCUDA HESAPLANIR (`SubscriptionLifecycle::quote()`): dönemde
     * kaç porsiyon üretileceği gün kuralından, duraklamalardan ve
     * istisnalardan çıkar. Elle tutar yazmak serbest ama varsayılan
     * hesaplanmış olmalı — yönetici her ay çarpma yapmamalı ve
     * `amount_source` "bu tutar nereden geldi" sorusunun cevabıdır.
     *
     * KURU PROVA HESABI GERÇEKTEN YAPAR: yöneticinin borcu yazmadan önce
     * görmesi gereken tam olarak budur.
     *
     * SÖZLEŞMEDEKİ `period_end` VE `due_date` TÜRETİLİR, YAZILMAZ. Dönem
     * 30 gün sabit (`SubscriptionPayment::PERIOD_DAYS`) ve model peşin:
     * ödeme dönem başlamadan alınır, yani son ödeme günü dönemin ilk
     * günüdür. İkisi arasında bir fark, ödenmemiş bir dönemin üretim
     * yapmasına izin verilen bir pencere demek olurdu. Gönderilen farklı
     * değerler sessizce yutulmuyor, `warnings` ile söyleniyor.
     */
    public function storePayment(Request $request, string $subscription): JsonResponse
    {
        $model = $this->find($subscription);

        $request->validate([
            'period_start' => ['sometimes', 'string', 'regex:'.self::DATE_PATTERN],
            'period_end' => ['sometimes', 'nullable', 'string', 'regex:'.self::DATE_PATTERN],
            'amount_kurus' => ['sometimes', 'nullable', 'integer', 'min:0'],
            'due_date' => ['sometimes', 'nullable', 'string', 'regex:'.self::DATE_PATTERN],
            'note' => ['sometimes', 'nullable', 'string', 'max:255'],
        ]);

        $start = $request->filled('period_start')
            ? $this->parseDate((string) $request->input('period_start'), 'period_start')
            : $this->lifecycle->nextPeriodStart($model);

        $quote = $this->lifecycle->quote($model, $start);

        /*
         * ═════════════════════════════════════════════════════════════════
         * `period_end` ARTIK SAYGI GÖRÜYOR (I2).
         *
         * Eskiden gönderilen değer yok sayılıp `period_end_derived` uyarısı
         * dönüyordu; yani sözleşmede yayınlanmış bir alan her yazmada
         * sessizce çöpe gidiyordu. Dönem 30 GÜN varsayılanıdır, DAYATMASI
         * değil: sözleşmesi 15'inde başlayan bir kurumun ilk dönemi kısa
         * olur ve o dönemi 30 güne yuvarlamak müşteriden fazla gün için
         * para istemek olurdu.
         *
         * PORSİYON VE TUTAR YENİDEN HESAPLANIR: dönem kısaldıysa daha az
         * gün üretilir. Uzunluğu değiştirip tutarı eski bırakmak, ödenen
         * gün sayısı ile üretilen sipariş sayısını ayrıştırırdı.
         * ═════════════════════════════════════════════════════════════════
         */
        if ($request->filled('period_end')) {
            $end = $this->parseDate((string) $request->input('period_end'), 'period_end');

            if ($end->lt($quote['start'])) {
                throw ApiException::validationFailed(
                    'Dönem bitişi başlangıcından önce olamaz.',
                    ['field' => 'period_end', 'period_start' => $quote['start']->toDateString()],
                );
            }

            $quote = $this->lifecycle->quoteRange($model, $quote['start'], $end);
        }

        if ($quote['portions'] < 1) {
            throw ApiException::validationFailed(
                'Bu dönemde servis günü yok; ödenecek bir tutar oluşmuyor.',
                ['field' => 'period_start', 'period_start' => $quote['start']->toDateString()],
            );
        }

        $exists = SubscriptionPayment::query()
            ->where('subscription_id', $model->id)
            ->whereDate('period_start', $quote['start']->toDateString())
            ->first();

        if ($exists !== null) {
            throw $this->conflict(
                'Bu dönem için borç kaydı zaten var.',
                ['conflict' => 'period', 'payment_id' => (int) $exists->id],
            );
        }

        $manual = $this->nullableInt($request->input('amount_kurus'));
        $amount = $manual ?? $quote['amount'];
        $source = $manual !== null ? 'manual' : 'calculated';
        $orderCount = $this->generatedOrderCount($model, $quote['start'], $quote['end']);

        /*
         * SON ÖDEME GÜNÜ ARTIK GÖNDERİLEBİLİYOR (I2) — kolonu var.
         *
         * VARSAYILAN DEĞİŞMEDİ: alan gelmezse dönemin ilk günü yazılır,
         * yani 30 günlük peşin tahsilat kuralı. Değişen tek şey, sözleşmeli
         * müşterinin farklı bir ödeme günü olabilmesi; türetilmiş tarih onu
         * her dönem başında haksız yere "gecikmiş" gösteriyordu.
         */
        $due = $request->filled('due_date')
            ? $this->parseDate((string) $request->input('due_date'), 'due_date')
            : $quote['start']->copy();

        $note = $this->trimmedOrNull($request->input('note'));
        $warnings = $this->periodWarnings($request, $quote, $due);

        $summary = [
            'period_start' => $quote['start']->toDateString(),
            'period_end' => $quote['end']->toDateString(),
            'amount_kurus' => $amount,
            'amount_source' => $source,
            'portions_planned' => $quote['portions'],
            'unit_price_kurus' => $quote['unit_price'],
            'order_count' => $orderCount,
            'due_date' => $due->toDateString(),
            'note' => $note,
        ];

        return $this->write(
            $request,
            'subscription.payment.create',
            ControlAudit::TARGET_SUBSCRIPTION_PAYMENT,
            null,
            ['subscription_id' => (int) $model->id, ...$summary],
            fn(): array => [
                'action' => 'subscription.payment.create',
                'subscription_id' => (int) $model->id,
                ...$summary,
                'warnings' => $warnings,
            ],
            function () use ($model, $quote, $amount, $summary, $warnings, $due, $note): array {
                $payment = new SubscriptionPayment;
                $payment->subscription_id = (int) $model->id;
                $payment->period_start = $quote['start']->toDateString();
                $payment->period_end = $quote['end']->toDateString();
                $payment->portions_planned = $quote['portions'];
                $payment->unit_price_kurus = $quote['unit_price'];
                $payment->amount_kurus = $amount;
                $payment->status = SubscriptionPayment::STATUS_PENDING;

                // KOLON VARSA YAZILIR: göç uygulanmamış bir kurulumda
                // `Unknown column` ile borç açılışını düşürmek, eksik bir
                // alandan çok daha pahalı olurdu.
                if ($this->hasColumn('veykemtu_subscription_payments', 'due_date')) {
                    $payment->due_date = $due->toDateString();
                }

                if ($this->hasColumn('veykemtu_subscription_payments', 'note')) {
                    $payment->note = $note;
                }
                /*
                 * ADRES TAHMİN EDİLEMEZ OLMALI: ödeme sayfasının yolu bu
                 * özeti taşıyor ve sıralı bir kimlik olsaydı bağlantıyı
                 * eline geçiren komşu numaraları deneyerek başkasının ödeme
                 * ekranını açardı. Müşteri yüzündeki uçla aynı üretim.
                 */
                $payment->hash = bin2hex(random_bytes(16));
                $payment->created_at = BusinessTime::forStorage(BusinessTime::now());
                $payment->save();

                return [
                    'data' => [
                        'id' => (int) $payment->id,
                        ...$summary,
                        'status' => self::PAYMENT_PENDING,
                    ],
                    'warnings' => $warnings,
                ];
            },
        );
    }

    /**
     * Tahsil edildi işaretler.
     *
     * MUTABAKAT `SubscriptionLifecycle::settle()`'DA. Durumu değiştiren tek
     * yer orası ve aboneliği `active` yapan geçiş de orada: burada
     * `status = paid` yazsaydık, "ödeme alındı ama abonelik hâlâ pending"
     * hâli ancak mutfakta fark edilirdi. Çift geri-arama koruması da o
     * metodun içinde ve panelin elle işaretlemesi aynı korumadan geçiyor —
     * yani panel ile sağlayıcı aynı dönemi iki kez tahsil edemez.
     *
     * ÖDEMEYİ GERİ ALMAK İÇİN UÇ YOKTUR. Yanlış işaretlenen bir tahsilat
     * yeni bir dönem kaydıyla düzeltilir; para defterinde silme yoktur.
     */
    public function markPaymentPaid(Request $request, string $payment): JsonResponse
    {
        $row = $this->findPayment($payment);

        $request->validate([
            'method' => ['required', Rule::in(['online', 'cash'])],
            'paid_at' => ['sometimes', 'nullable', 'date'],
            'reference' => ['sometimes', 'nullable', 'string', 'max:120'],
            'create_invoice' => ['sometimes', 'boolean'],
        ]);

        if (!$row->isPending()) {
            // İkinci kez tahsil işaretlemek tutarı iki kez saydırırdı.
            throw $this->conflict(
                'Bu dönem borcu tahsil edilebilir durumda değil.',
                [
                    'conflict' => $this->paymentStatus((string) $row->status),
                    'payment_id' => (int) $row->id,
                    'provider_status' => (string) $row->status,
                ],
            );
        }

        $now = BusinessTime::now();
        $paidAt = $request->filled('paid_at')
            ? Carbon::parse((string) $request->input('paid_at'))
            : $now->copy();

        if ($paidAt->gt($now)) {
            throw ApiException::validationFailed(
                'Tahsilat anı gelecekte olamaz.',
                ['field' => 'paid_at'],
            );
        }

        $method = (string) $request->input('method');
        $reference = $this->trimmedOrNull($request->input('reference'));
        $wantsInvoice = $request->boolean('create_invoice');
        $backdated = $request->filled('paid_at');

        return $this->write(
            $request,
            'subscription.payment.paid',
            ControlAudit::TARGET_SUBSCRIPTION_PAYMENT,
            (int) $row->id,
            [
                'subscription_id' => (int) $row->subscription_id,
                'amount_kurus' => (int) $row->amount_kurus,
                'method' => $method,
                'create_invoice' => $wantsInvoice,
            ],
            fn(): array => [
                'action' => 'subscription.payment.paid',
                'payment_id' => (int) $row->id,
                'status' => self::PAYMENT_PAID,
                'method' => $method,
                'paid_at' => $paidAt->utc()->toIso8601ZuluString(),
                'create_invoice' => $wantsInvoice,
            ],
            function (array $intent) use ($row, $method, $paidAt, $backdated, $reference, $wantsInvoice): array {
                $settled = $this->lifecycle->settle($row, PaymentResult::succeeded(
                    // `gateway` SAĞLAYICI ADIDIR ve elle tahsilatta
                    // sağlayıcı yoktur; yöntemin kendisi yazılıyor ki
                    // "havaleyle mi geldi, POS'tan mı" sorusu kayıttan
                    // okunabilsin.
                    $method,
                    (string) $row->hash,
                    $reference ?? 'Kontrol Merkezi · '.$intent['actor'],
                ));

                if (!$settled) {
                    throw $this->conflict(
                        'Dönem borcu bu çağrıdan önce kapanmış.',
                        ['conflict' => 'paid', 'payment_id' => (int) $row->id],
                    );
                }

                /*
                 * `settle()` mutabakat anını ŞİMDİ yazıyor; geriye dönük bir
                 * tahsilat (dün gelen havale) ancak sonradan düzeltilebilir.
                 * Geçişi ve çift-koruma mantığını bozmamak için sıra bu:
                 * önce mutabakat, sonra yalnız zaman damgası.
                 */
                if ($backdated) {
                    $row->settled_at = BusinessTime::forStorage($paidAt);
                    $row->save();
                }

                $data = [
                    'id' => (int) $row->id,
                    'status' => self::PAYMENT_PAID,
                    'method' => $method,
                    'paid_at' => self::ts($row->settled_at),
                    'reference' => $this->trimmedOrNull($row->provider_ref),
                    'invoice_id' => null,
                    'invoice_no' => null,
                ];

                $warnings = [];

                if ($wantsInvoice) {
                    /*
                     * ═════════════════════════════════════════════════════
                     * ONAY KUTUSU ARTIK BİR ŞEY YAPIYOR (I2).
                     *
                     * Buraya kadar `create_invoice: true` yalnızca
                     * `invoice_not_created` uyarısı üretiyordu — ve panel o
                     * uyarıyı hiç göstermediği için yönetici belge
                     * kesildiğini sanıyordu. Oysa dönem faturası servisi
                     * (`InvoiceService::issueForPeriod`) vardı ve zaten
                     * `subscription_payment_id` bağını destekliyordu.
                     *
                     * BELGE KESİMİ TAHSİLATI DÜŞÜREMEZ. Fatura üretimi
                     * kendi doğrulamalarını taşıyor ("bu dönemde teslim
                     * edilmiş porsiyon yok", "aynı dönemin belgesi zaten
                     * var") ve bunlardan biri patlarsa PARA HAREKETİ GERİ
                     * ALINMAMALI: tahsilat gerçekten yapıldı. Hata bir
                     * uyarıya çevriliyor ve belge sonradan `invoices`
                     * ekranından kesiliyor.
                     * ═════════════════════════════════════════════════════
                     */
                    $invoice = $this->issuePeriodInvoice($row, $intent['actor'], $warnings);

                    if ($invoice !== null) {
                        $data['invoice_id'] = (int) $invoice->id;
                        $data['invoice_no'] = (string) $invoice->invoice_no;
                    }
                }

                /*
                 * UYARI ÜST DÜZEYDE DÖNER, `data` İÇİNDE DEĞİL (I3).
                 *
                 * Kontrol Merkezi geçidi uyarıları YALNIZ üst düzey
                 * `warnings` anahtarından okuyor (`sb.warnings_of()`);
                 * `data` içine gömülen uyarı hiçbir ekranda görünmüyordu.
                 * Yani "belge kesilmedi" bilgisi tam da göründüğü sanılan
                 * yerde kayboluyordu.
                 */
                return $warnings === []
                    ? ['data' => $data]
                    : ['data' => $data, 'warnings' => $warnings];
            },
        );
    }

    // ── Abonelik gövdesi: doğrulama ve yazma ─────────────────────────────

    /**
     * Abonelik gövdesinin kuralları — `POST /` ve `POST /requests/{id}/convert`
     * ikisi de buradan besleniyor.
     *
     * İKİ YERDE İKİ AYRI LİSTE, birinde unutulan bir sınır demekti: talep
     * dönüşümü aynı gövdeyi `subscription.` öneki altında taşıyor ve
     * sözleşme "aynı doğrulamalardan geçer" diyor.
     *
     * @param  bool  $creating  `false` ise bütün alanlar isteğe bağlı (PATCH)
     * @return array<string, list<string>>
     */
    private function subscriptionRules(string $p, bool $creating = true): array
    {
        $req = $creating ? 'required' : 'sometimes';

        return [
            $p.'location_id' => [$req, 'integer', 'exists:locations,location_id'],
            $p.'start_date' => [$req, 'date_format:Y-m-d'],
            $p.'end_date' => ['sometimes', 'nullable', 'date_format:Y-m-d'],
            $p.'delivery_type' => [$req, Rule::in(['delivery', 'pickup'])],
            $p.'delivery_time_from' => ['sometimes', 'nullable', 'regex:/^\d{2}:\d{2}$/'],
            $p.'delivery_time_to' => ['sometimes', 'nullable', 'regex:/^\d{2}:\d{2}$/'],
            $p.'service_days' => [$req, 'array', 'min:1', 'max:7'],
            $p.'service_days.*' => ['integer', 'between:1,7', 'distinct'],
            $p.'menu_mode' => ['sometimes', Rule::in([Subscription::MENU_FIXED_LIST, Subscription::MENU_DAILY])],
            $p.'default_quantity' => [$req, 'integer', 'min:1'],
            $p.'agreed_unit_price_kurus' => ['sometimes', 'nullable', 'integer', 'min:0'],
            // DEĞER DENETİMİ AYRI: sözleşme `payment_mode` hatasının
            // `details` şeklini (`allowed` listesi) sabitliyor ve
            // `Rule::in` o şekli üretemez.
            $p.'payment_mode' => ['sometimes', 'string', 'max:32'],
            $p.'lines' => ['sometimes', 'array'],
            $p.'lines.*.id' => ['sometimes', 'integer', 'min:1'],
            $p.'lines.*.menu_id' => ['required', 'integer', 'exists:menus,menu_id'],
            $p.'lines.*.quantity' => ['sometimes', 'integer', 'min:1'],
            $p.'lines.*.agreed_unit_price_kurus' => ['sometimes', 'nullable', 'integer', 'min:0'],
            $p.'lines.*.label' => ['sometimes', 'nullable', 'string', 'max:120'],
            $p.'delivery_points' => ['sometimes', 'array'],
            $p.'delivery_points.*.id' => ['sometimes', 'integer', 'min:1'],
            $p.'delivery_points.*.address_id' => ['required', 'integer', 'min:1'],
            $p.'delivery_points.*.quantity' => ['sometimes', 'nullable', 'integer', 'min:1'],
            $p.'delivery_points.*.note' => ['sometimes', 'nullable', 'string', 'max:255'],
        ];
    }

    /**
     * Alanlar arası kurallar — tek tek doğrulanamayanlar.
     *
     * @param  array<string, mixed>  $body     tam (birleştirilmiş) gövde
     * @param  array<string, mixed>|null  $partial  PATCH'te gerçekten gönderilen alanlar
     *
     * @throws ApiException
     */
    private function assertSubscriptionShape(
        array $body,
        int $customerId,
        string $field,
        ?array $partial = null,
    ): void {
        $sent = static fn(string $key): bool => $partial === null || array_key_exists($key, $partial);

        if (array_key_exists('payment_mode', $body) && $body['payment_mode'] !== null) {
            if ((string) $body['payment_mode'] !== Subscription::PAYMENT_PREPAID) {
                // Cari hesap kalktı (iş kararı 1); `account` artık bir ödeme
                // yöntemi değil. Sabit ve kolon duruyor, değişen yalnız
                // kabul edilen değer kümesi.
                throw ApiException::validationFailed(
                    'Geçersiz ödeme modu.',
                    ['field' => $field.'payment_mode', 'allowed' => [Subscription::PAYMENT_PREPAID]],
                );
            }
        }

        $menuMode = (string) ($body['menu_mode'] ?? Subscription::MENU_DAILY);
        $lines = (array) ($body['lines'] ?? []);

        if ($menuMode === Subscription::MENU_FIXED_LIST && $lines === []) {
            // Sabit liste seçip liste vermemek, hiçbir şey üretmeyen bir
            // kural yaratırdı.
            throw ApiException::validationFailed(
                'Sabit liste seçilen abonelikte en az bir kalem olmalı.',
                ['field' => $field.'lines'],
            );
        }

        if ($menuMode === Subscription::MENU_DAILY && $lines !== []) {
            throw ApiException::validationFailed(
                'Günün menüsü seçilen abonelikte kalem listesi gönderilemez.',
                ['field' => $field.'lines'],
            );
        }

        $points = (array) ($body['delivery_points'] ?? []);

        if ((string) ($body['delivery_type'] ?? 'delivery') === 'delivery'
            && $points === []
            && $sent('delivery_points')
        ) {
            throw ApiException::validationFailed(
                'Teslimatlı abonelikte en az bir teslimat noktası olmalı.',
                ['field' => $field.'delivery_points'],
            );
        }

        if ($points !== []) {
            $owned = DB::table('addresses')
                ->where('customer_id', $customerId)
                ->pluck('address_id')
                ->map(intval(...))
                ->all();

            foreach (array_values($points) as $index => $point) {
                if (!in_array((int) ($point['address_id'] ?? 0), $owned, true)) {
                    throw ApiException::validationFailed(
                        'Teslimat adresi müşterinin adres defterinde yok.',
                        ['field' => $field.'delivery_points.'.$index.'.address_id'],
                    );
                }
            }
        }

        if (isset($body['start_date'], $body['end_date']) && $body['end_date'] !== null) {
            $start = Carbon::parse((string) $body['start_date'])->startOfDay();
            $end = Carbon::parse((string) $body['end_date'])->startOfDay();

            if ($end->lte($start)) {
                throw ApiException::validationFailed(
                    'Bitiş günü başlangıçtan sonra olmalı.',
                    ['field' => $field.'end_date'],
                );
            }
        }
    }

    /**
     * Sözleşme gönderildikten sonra FİYAT DEĞİŞMEZ.
     *
     * Gönderilen sözleşme metni anlaşılan porsiyon fiyatını taşıyor;
     * fiyatı sonradan değiştirmek, müşterinin okuduğu belge ile sistemdeki
     * kuralı sessizce ayırırdı. Koşullar değiştiyse yol bellidir ve
     * sözleşmenin kendi ucundadır: sözleşmeyi iptal et, yenisini oluştur.
     *
     * @param  array<string, mixed>  $body
     *
     * @throws ApiException
     */
    private function assertPriceStillOpen(Subscription $model, array $body): void
    {
        if (!array_key_exists('agreed_unit_price_kurus', $body)) {
            return;
        }

        $new = $this->nullableInt($body['agreed_unit_price_kurus']);

        if ($new === $this->nullableInt($model->agreed_unit_price_kurus)) {
            return;
        }

        $contract = $this->latestContract((int) $model->id);

        if ($contract === null) {
            return;
        }

        $status = $contract->controlStatus();

        if (in_array($status, [self::CONTRACT_SENT, self::CONTRACT_SIGNED], true)) {
            throw $this->conflict(
                'Sözleşme gönderildikten sonra porsiyon fiyatı değiştirilemez; '
                    .'sözleşmeyi iptal edip yenisini oluşturun.',
                ['conflict' => 'contract_'.$status, 'contract_id' => (int) $contract->id],
            );
        }
    }

    /**
     * Kuru provanın `would` gövdesi.
     *
     * `first_service_dates` KURU PROVANIN ASIL FAYDASI: yönetici kuralın
     * gerçekten hangi günleri ürettiğini kaydetmeden görür. Kapalı günler
     * eleniyor, çünkü üretim işi de eliyor — burada göstermek yanlış bir
     * söz vermek olurdu.
     *
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    private function createPreview(array $body, ?int $customerId = null): array
    {
        $days = array_map(intval(...), (array) $body['service_days']);
        $start = Carbon::parse((string) $body['start_date'])->startOfDay();
        $quantity = (int) $body['default_quantity'];
        $price = $this->nullableInt($body['agreed_unit_price_kurus'] ?? null);

        $dates = [];
        $monthly = 0;
        $cursor = $start->copy();

        for ($i = 0; $i < 30; $i++, $cursor->addDay()) {
            if (!in_array($cursor->dayOfWeekIso, $days, true) || ClosedDay::isClosed($cursor)) {
                continue;
            }

            $monthly++;

            if (count($dates) < 3) {
                $dates[] = $cursor->toDateString();
            }
        }

        return [
            /*
             * MÜŞTERİ KİMLİĞİ DIŞARIDAN DA GELEBİLİR (I3).
             *
             * `convertRequest()` gövdesinde `customer_id` `subscription`
             * bloğunun DIŞINDA duruyor; burada yalnız blok içine bakmak
             * kuru provanın `customer_id: 0` döndürmesi demekti — yönetici
             * de aboneliğin hangi müşteriye açılacağını göremeden
             * onaylıyordu.
             */
            'customer_id' => $customerId ?? (int) ($body['customer_id'] ?? 0),
            'service_days' => $days,
            'first_service_dates' => $dates,
            'monthly_estimate_kurus' => $monthly * $quantity * ($price ?? 0),
        ];
    }

    /**
     * Aboneliği ve alt kayıtlarını yazar — HER ZAMAN `pending`.
     *
     * @param  array<string, mixed>  $body
     */
    private function persist(int $customerId, array $body): Subscription
    {
        return DB::transaction(function () use ($customerId, $body): Subscription {
            $model = new Subscription;
            $model->customer_id = $customerId;
            $model->location_id = (int) $body['location_id'];
            $model->status = Subscription::STATUS_PENDING;
            $model->start_date = (string) $body['start_date'];
            $model->payment_mode = Subscription::PAYMENT_PREPAID;
            $model->menu_mode = (string) ($body['menu_mode'] ?? Subscription::MENU_DAILY);

            $this->applyBody($model, $body);
            $model->save();

            $this->syncLines($model, (array) ($body['lines'] ?? []));
            $this->syncPoints($model, (array) ($body['delivery_points'] ?? []));

            return $model->fresh(['lines', 'delivery_points', 'pauses', 'exceptions', 'customer']);
        });
    }

    /**
     * Gövdedeki YAZILABİLİR skaler alanları modele taşır.
     *
     * `customer_id`, `location_id`, `start_date` ve `status` bilerek yok:
     * ikisi yalnız oluşturmada yazılıyor, durumun kendi uçları var.
     *
     * @param  array<string, mixed>  $body
     */
    private function applyBody(Subscription $model, array $body): void
    {
        if (array_key_exists('end_date', $body)) {
            $model->end_date = $body['end_date'] === null ? null : (string) $body['end_date'];
        }
        if (array_key_exists('delivery_type', $body)) {
            $model->delivery_type = (string) $body['delivery_type'];
        }
        if (array_key_exists('delivery_time_from', $body)) {
            $model->delivery_time_from = $this->timeOrNull($body['delivery_time_from']);
        }
        if (array_key_exists('delivery_time_to', $body)) {
            $model->delivery_time_to = $this->timeOrNull($body['delivery_time_to']);
        }
        if (array_key_exists('service_days', $body)) {
            $model->service_days = array_values(array_map(intval(...), (array) $body['service_days']));
        }
        if (array_key_exists('menu_mode', $body)) {
            $model->menu_mode = (string) $body['menu_mode'];
        }
        if (array_key_exists('default_quantity', $body)) {
            $model->default_quantity = (int) $body['default_quantity'];
        }
        if (array_key_exists('agreed_unit_price_kurus', $body)) {
            $model->agreed_unit_price_kurus = $this->nullableInt($body['agreed_unit_price_kurus']);
        }
    }

    /**
     * `lines` TAM LİSTEDİR: `id` taşıyan satır güncellenir, taşımayan
     * eklenir, listede olmayan silinir (menü kalemlerindeki desenin aynısı).
     *
     * @param  list<array<string, mixed>>  $lines
     */
    private function syncLines(Subscription $model, array $lines): void
    {
        $keep = [];

        foreach ($lines as $line) {
            $row = isset($line['id'])
                ? SubscriptionLine::query()
                    ->where('subscription_id', $model->id)
                    ->where('id', (int) $line['id'])
                    ->first() ?? new SubscriptionLine
                : new SubscriptionLine;

            $row->subscription_id = $model->id;
            $row->menu_id = (int) $line['menu_id'];
            $row->quantity = (int) ($line['quantity'] ?? 1);
            $row->agreed_unit_price_kurus = $this->nullableInt($line['agreed_unit_price_kurus'] ?? null);
            $row->label = $this->trimmedOrNull($line['label'] ?? null);
            $row->save();

            $keep[] = (int) $row->id;
        }

        SubscriptionLine::query()
            ->where('subscription_id', $model->id)
            ->when($keep !== [], static fn($q) => $q->whereNotIn('id', $keep))
            ->delete();
    }

    /** @param  list<array<string, mixed>>  $points */
    private function syncPoints(Subscription $model, array $points): void
    {
        $keep = [];

        foreach ($points as $point) {
            $row = isset($point['id'])
                ? SubscriptionDeliveryPoint::query()
                    ->where('subscription_id', $model->id)
                    ->where('id', (int) $point['id'])
                    ->first() ?? new SubscriptionDeliveryPoint
                : new SubscriptionDeliveryPoint;

            $row->subscription_id = $model->id;
            $row->address_id = (int) $point['address_id'];
            $row->quantity = $this->nullableInt($point['quantity'] ?? null);
            $row->note = $this->trimmedOrNull($point['note'] ?? null);
            $row->save();

            $keep[] = (int) $row->id;
        }

        SubscriptionDeliveryPoint::query()
            ->where('subscription_id', $model->id)
            ->when($keep !== [], static fn($q) => $q->whereNotIn('id', $keep))
            ->delete();
    }

    /**
     * PATCH gövdesini mevcut kayıtla birleştirir.
     *
     * Alanlar arası kurallar (`menu_mode` ↔ `lines`, `delivery_type` ↔
     * `delivery_points`) YALNIZ GELEN ALANLARA bakarak denetlenemez:
     * `menu_mode: fixed_list` gönderip `lines` göndermeyen bir istek, tek
     * başına bakıldığında kusursuz görünür ama sonuçta hiçbir şey üretmeyen
     * bir kural bırakır.
     *
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    private function mergedShape(Subscription $model, array $body): array
    {
        return [
            'menu_mode' => $body['menu_mode'] ?? (string) $model->menu_mode,
            'delivery_type' => $body['delivery_type'] ?? (string) $model->delivery_type,
            'lines' => $body['lines'] ?? $model->lines->map(static fn(SubscriptionLine $l): array => [
                'id' => (int) $l->id,
                'menu_id' => (int) $l->menu_id,
            ])->all(),
            'delivery_points' => $body['delivery_points']
                ?? $model->delivery_points->map(static fn(SubscriptionDeliveryPoint $p): array => [
                    'id' => (int) $p->id,
                    'address_id' => (int) $p->address_id,
                ])->all(),
            'payment_mode' => $body['payment_mode'] ?? null,
            'start_date' => $this->dateOf($model->start_date),
            'end_date' => array_key_exists('end_date', $body)
                ? $body['end_date']
                : $this->dateOf($model->end_date),
        ];
    }

    // ── Üretim ───────────────────────────────────────────────────────────

    /**
     * Üretim hedefleri — nokta başına bir sipariş.
     *
     * Nokta yoksa TEK ve NOKTASIZ üretim (`delivery_point_id = 0`). Sıfır
     * kullanılıyor çünkü MySQL `NULL`'ları tekil saymaz ve idempotency
     * kısıtı bozulurdu; aynı gerekçe göç dosyasında da yazılı.
     *
     * @return list<array{id: int, point: SubscriptionDeliveryPoint|null}>
     */
    private function generationTargets(Subscription $model): array
    {
        $points = $model->delivery_points->all();

        if ($points === []) {
            return [['id' => 0, 'point' => null]];
        }

        return array_map(
            static fn(SubscriptionDeliveryPoint $p): array => ['id' => (int) $p->id, 'point' => $p],
            array_values($points),
        );
    }

    /**
     * Üretimi engelleyen sebep (varsa) — gece işiyle AYNI iki kapı.
     *
     * Kapalı gün ve yayınlanmamış günün menüsü `422` DEĞİL `skipped`
     * üretiyor: ikisi de bir doğrulama hatası değil, o günün gerçeği. Uç
     * 422 dönseydi yönetici "isteğim hatalı" sanır, oysa yapması gereken
     * menüyü yayınlamak.
     */
    private function generationBlocker(Subscription $model, Carbon $date): ?string
    {
        if (ClosedDay::isClosed($date)) {
            return 'closed_day';
        }

        if ($model->menu_mode === Subscription::MENU_DAILY
            && DailyMenu::findPublished((int) $model->location_id, $date) === null
        ) {
            return 'daily_menu_not_published';
        }

        return null;
    }

    /**
     * O günün TOPLAM tavanı yetiyor mu?
     *
     * Abonelikler stoku ÖNCE rezerve eder (iş kararı 6); elle üretim o
     * rezervasyonun dışında kalan bir taleptir ve tavana takılabilir.
     * Yönetici tavanı yükseltir ya da üretimi bilinçli olarak ertesi güne
     * bırakır.
     *
     * @throws ApiException
     */
    private function assertDayCapacity(Subscription $model, Carbon $date, int $requested): void
    {
        $free = $this->stock->remaining((int) $model->location_id, $date, DailyStock::DAY_TOTAL);

        if ($free === null || $requested <= $free) {
            return;
        }

        /*
         * `capacity`/`sold` AYRINTISI İÇİN SATIR OKUNUYOR. Kararı
         * `DailyStock::remaining()` veriyor (tek kaynak); satır yalnız
         * sözleşmenin şart koştuğu `details` alanlarını doldurmak için
         * okunuyor — kararı burada yeniden hesaplamak, tavan mantığının
         * ikinci bir kopyasını doğururdu.
         */
        $row = DB::table('veykemtu_daily_menu_stock')
            ->where('location_id', $model->location_id)
            ->where('service_date', $date->toDateString())
            ->where('menu_id', DailyStock::DAY_TOTAL)
            ->first(['capacity', 'reserved', 'sold']);

        throw new ApiException('STOCK_EXCEEDED', 'O günün porsiyon tavanı dolu.', 422, [
            'scope' => 'day',
            'capacity' => $row !== null ? (int) $row->capacity : null,
            'sold' => $row !== null ? (int) $row->sold : 0,
            'reserved' => $row !== null ? (int) $row->reserved : 0,
            'requested' => $requested,
        ]);
    }

    /**
     * Siparişleri üretir ve defteri yazar.
     *
     * KURAL `SubscriptionGenerateCommand` İLE AYNI: nokta başına bir
     * sipariş, tek işlemde sipariş + defter satırı, hata tek hedefi düşürür
     * ve diğerlerini durdurmaz.
     *
     * @param  list<array{id: int, point: SubscriptionDeliveryPoint|null}>  $targets
     * @param  Carbon|null  $forcedReleaseAt  yalnız `release_now` ile dolu
     * @return array<string, mixed>
     */
    private function runGeneration(
        Subscription $model,
        Carbon $date,
        array $targets,
        int $quantity,
        ?Carbon $forcedReleaseAt,
        ?string $blocker,
    ): array {
        $created = [];
        $skipped = [];

        foreach ($targets as $target) {
            if ($blocker !== null) {
                $skipped[] = [
                    'delivery_point_id' => $target['id'],
                    'reason' => $blocker,
                ];

                continue;
            }

            try {
                $created[] = DB::transaction(function () use ($model, $target, $date, $forcedReleaseAt, $quantity): array {
                    $order = $this->factory->createForSubscription($model, $target['point'], $date);

                    /*
                     * DAMGAYI FABRİKA ATTI. Burada yalnız yönetici "şimdi
                     * aç" dediyse eziliyor; aksi hâlde aynı anı ikinci kez
                     * hesaplayıp üstüne yazmak olurdu ve iki hesap
                     * ayrıştığı gün kazanan sessizce bu satır olurdu.
                     */
                    if ($forcedReleaseAt !== null) {
                        DB::table('orders')
                            ->where('order_id', $order->order_id)
                            ->update([self::RELEASE_COLUMN => BusinessTime::forStorage($forcedReleaseAt)]);
                    }

                    $runId = (int) DB::table('veykemtu_subscription_runs')->insertGetId([
                        'subscription_id' => $model->id,
                        'delivery_point_id' => $target['id'],
                        'service_date' => $date->toDateString(),
                        'order_id' => $order->order_id,
                        'created_at' => BusinessTime::forStorage(BusinessTime::now()),
                    ]);

                    return [
                        'run_id' => $runId,
                        'order_id' => (int) $order->order_id,
                        'order_number' => $this->presenter->number($order),
                        'delivery_point_id' => $target['id'],
                        'quantity' => $quantity,
                        // SATIRIN KENDİSİNDEN okunuyor, tahminden değil:
                        // yönetici yanıtta siparişin GERÇEK damgasını görür.
                        'release_at' => self::ts(
                            DB::table('orders')
                                ->where('order_id', $order->order_id)
                                ->value(self::RELEASE_COLUMN),
                        ),
                    ];
                });
            } catch (ApiException $e) {
                throw $e;
            } catch (Throwable $e) {
                $skipped[] = [
                    'delivery_point_id' => $target['id'],
                    'reason' => 'generation_failed',
                    'message' => mb_substr($e->getMessage(), 0, 200),
                ];
            }
        }

        return ['service_date' => $date->toDateString(), 'created' => $created, 'skipped' => $skipped];
    }

    /**
     * @param  list<array<string, mixed>>  $plan
     * @return list<array<string, mixed>>
     */
    private function skippedPlan(array $plan, string $reason): array
    {
        return array_map(
            static fn(array $row): array => [
                'delivery_point_id' => $row['delivery_point_id'],
                'reason' => $reason,
            ],
            $plan,
        );
    }

    /**
     * Siparişin KDS'e düşeceği an; `null` = ANINDA (damgasız).
     *
     * KURAL `OrderFactory::releaseAtFor()` İLE AYNI OLMAK ZORUNDA, çünkü
     * damgayı gerçekte o atıyor; bu metot yalnız kuru provada ve panelde
     * "ne zaman düşecek" sorusunu ÖNCEDEN cevaplıyor. Eski hâli ayrı bir
     * `subscription_release_time` ayarına (07:00) bakıyordu; ayar
     * 17.08.2026'da kaldırıldı ama `method_exists` koruması yüzünden metot
     * hata vermeden sözleşme varsayılanına düşüyordu — yani panel her
     * siparişi 07:00 diye gösterirken mutfak onu kesim anında görüyordu.
     *
     * Üç kapı, üçü de `OrderingWindow` tanımıyla:
     *  1. Servis günü BUGÜNSE damga yok — mutfak zaten o günün içinde.
     *  2. Kesim tanımsızsa (`order_cutoff` `null` ve güne özel saat yok)
     *     damga yok; aksi hâlde sipariş hiç açılmadan görünmez kalırdı.
     *  3. Kesim GEÇMİŞSE damga yok: geçmiş bir ana damga atmak,
     *     `[since, now]` aralığını tarayan artımlı yoklamanın siparişi hiç
     *     görmemesi riskini taşırdı.
     *
     * Dönen an İŞLETME SAATİNDEDİR; veritabanına yazan taraf `forStorage()`
     * uygular.
     */
    private function scheduledReleaseAt(Subscription $model, Carbon $date): ?Carbon
    {
        if ($date->toDateString() === BusinessTime::today()) {
            return null;
        }

        $location = Location::find((int) $model->location_id);

        if ($location === null) {
            return null;
        }

        $cutoff = $this->window->cutoffFor($location, $date);

        return $this->window->hasPassed($cutoff) ? null : $cutoff;
    }

    // ── Sözleşme yardımcıları ────────────────────────────────────────────

    /**
     * Bağlantıyı SMS ile yollar.
     *
     * GÖNDERİM HATASI İSTEĞİ DÜŞÜRMEZ. Sözleşme kaydı zaten yazıldı ve
     * bağlantı `resend` ile yeniden gönderilebilir; sağlayıcı arızasında
     * `500` dönmek yöneticiyi kaydı baştan oluşturmaya zorlar, o da
     * `open_contract` çakışmasına takılırdı. Sonuç `sms_sent` alanında
     * dürüstçe söyleniyor ve gitmeyen bağlantı yanıtta veriliyor.
     *
     * @param  int|null  $renewDays  verilirse süre tazelenir (eski bağlantı ölür)
     */
    private function deliverContract(SubscriptionContract $contract, ?int $renewDays = null): bool
    {
        try {
            if ($renewDays !== null) {
                $this->contractService->resend($contract, $renewDays);
            } else {
                $this->contractService->send($contract);
            }

            return true;
        } catch (SmsException) {
            return false;
        }
    }

    /**
     * Sözleşmenin gideceği numara — gövdede yoksa müşterinin kayıtlısı.
     */
    private function contractPhone(Subscription $model, mixed $given): string
    {
        $phone = OtpService::normalize((string) ($given ?? ''));

        if ($phone !== '') {
            return $phone;
        }

        return OtpService::normalize((string) ($model->customer->telephone ?? ''));
    }

    /**
     * Sözleşme açılabilir mi?
     *
     * `ContractService::create()` AYNI İKİ KAPIYI yazmadan önce uyguluyor;
     * burada tekrarlanmasının tek sebebi KURU PROVANIN DA TAKILMASI
     * gerektiği (`00-genel.md` §3.1) — "kuru prova geçti" diyen bir ekran
     * gerçek gönderimde patlamamalı.
     *
     * @throws ApiException
     */
    private function assertContractable(Subscription $model, string $phone): void
    {
        if ($model->agreed_unit_price_kurus === null || (int) $model->agreed_unit_price_kurus <= 0) {
            // Fiyatsız bir metni imzalatmak, müşteriye tutarı boş bir belge
            // onaylatmak olurdu.
            throw ApiException::validationFailed(
                'Sözleşme için önce porsiyon fiyatı belirlenmeli.',
                ['field' => 'agreed_unit_price_kurus'],
            );
        }

        if (strlen($phone) !== 10) {
            throw ApiException::validationFailed(
                'Sözleşmenin gönderileceği telefon numarası bulunamadı.',
                ['field' => 'phone'],
            );
        }
    }

    /** @return array<string, mixed> */
    private function contractRow(SubscriptionContract $c): array
    {
        return [
            'id' => (int) $c->id,
            'subscription_id' => (int) $c->subscription_id,
            // Panel sözlüğüne çeviri TEK NOKTADA: `controlStatus()`.
            'status' => $c->controlStatus(),
            'sent_to_phone' => $this->trimmedOrNull($c->sent_to_phone),
            'sent_at' => self::ts($c->sent_at),
            'expires_at' => self::ts($c->expires_at),
            // Panelde "imza", kayıtta `approved_at` — aynı an.
            'signed_at' => self::ts($c->approved_at),
            'otp_verified_at' => self::ts($c->otp_verified_at),
            'cancelled_at' => self::ts($c->cancelled_at),
            'cancel_reason' => $this->trimmedOrNull($c->cancel_reason),
            'terms_snapshot' => $this->decodeJson($c->terms_json),
            'created_at' => self::ts($c->created_at),
            // `token_hash`, `body_html` ve `sign_url` BİLEREK YOK.
        ];
    }

    /**
     * Aynı anda yalnız bir tane olabilen açık sözleşme.
     *
     * SÜRESİ DOLMUŞ BAĞLANTI "AÇIK" SAYILMAZ: sayılsaydı yönetici yeni
     * sözleşme oluşturamadan önce ölü bir kaydı elle iptal etmek zorunda
     * kalırdı.
     */
    private function openContract(int $subscriptionId): ?SubscriptionContract
    {
        return SubscriptionContract::query()
            ->where('subscription_id', $subscriptionId)
            ->whereIn('status', [
                SubscriptionContract::STATUS_DRAFT,
                SubscriptionContract::STATUS_SENT,
            ])
            ->orderByDesc('id')
            ->get()
            ->first(static fn(SubscriptionContract $c): bool => !$c->isExpired());
    }

    /** Onaylı olan varsa o, yoksa en son oluşturulan. */
    private function latestContract(int $subscriptionId): ?SubscriptionContract
    {
        $approved = SubscriptionContract::query()
            ->where('subscription_id', $subscriptionId)
            ->where('status', SubscriptionContract::STATUS_APPROVED)
            ->orderByDesc('id')
            ->first();

        return $approved ?? SubscriptionContract::query()
            ->where('subscription_id', $subscriptionId)
            ->orderByDesc('id')
            ->first();
    }

    /**
     * Liste ekranı için abonelik → sözleşme durumu haritası.
     *
     * TEK SORGU: satır başına sorsaydık yirmi beş abonelikte yirmi beş
     * sorgu olurdu (`soldOutReasons()` aynı dersi bir kez verdi).
     *
     * @param  list<int>  $ids
     * @return array<int, string>
     */
    private function contractStatusMap(array $ids): array
    {
        if ($ids === []) {
            return [];
        }

        $map = [];

        foreach (
            SubscriptionContract::query()
                ->whereIn('subscription_id', $ids)
                ->orderBy('id')
                ->get() as $contract
        ) {
            $key = (int) $contract->subscription_id;

            // İmzalı sözleşme diğer hepsini yener: ekranın sorduğu soru
            // "bu aboneliğin geçerli bir imzası var mı".
            if (($map[$key] ?? null) === self::CONTRACT_SIGNED) {
                continue;
            }

            $map[$key] = $contract->controlStatus();
        }

        return $map;
    }

    private function findContract(string $id): SubscriptionContract
    {
        $row = SubscriptionContract::query()->find((int) $id);

        if ($row === null) {
            throw ApiException::notFound('Sözleşme bulunamadı.');
        }

        return $row;
    }

    // ── Ödeme yardımcıları ───────────────────────────────────────────────

    /** @return array<string, mixed> */
    private function paymentRow(SubscriptionPayment $p): array
    {
        $status = $this->paymentStatus((string) $p->status);
        /*
         * SON ÖDEME GÜNÜ = DÖNEMİN İLK GÜNÜ. Model 30 günlük PEŞİN tahsilat
         * (iş kararı 3) ve ayrı bir `due_date` sütunu yok; ikisi arasında
         * bir fark, ödenmemiş bir dönemin üretim yapmasına izin verilen bir
         * pencere demek olurdu.
         */
        /*
         * KOLON VARSA ONDAN, YOKSA DÖNEM BAŞINDAN. Geriye dönük doldurma
         * göçte yapıldı; `?? period_start` yalnız göç uygulanmamış kurulum
         * için duruyor ve o kurulumda eski davranışı birebir sürdürüyor.
         */
        $due = Carbon::parse(
            $p->due_date !== null
                ? $p->due_date->toDateString()
                : $p->period_start->toDateString(),
        )->startOfDay();
        $today = $this->today();
        $overdue = $status === self::PAYMENT_PENDING && $due->lt($today);

        return [
            'id' => (int) $p->id,
            'period_start' => $p->period_start->toDateString(),
            'period_end' => $p->period_end->toDateString(),
            'amount_kurus' => (int) $p->amount_kurus,
            'due_date' => $due->toDateString(),
            'status' => $status,
            // Ham sözlük de dönüyor: sağlayıcı reddi (`failed`) ile iade
            // (`refunded`) panelde aynı kutuya düşüyor ve ikisini ayırmak
            // isteyen ekranın bir yeri olmalı.
            'provider_status' => (string) $p->status,
            'method' => $this->trimmedOrNull($p->gateway),
            'paid_at' => self::ts($p->settled_at),
            'reference' => $this->trimmedOrNull($p->provider_ref),
            'note' => $this->trimmedOrNull($p->note ?? null),
            /*
             * BAĞ FATURA TARAFINDA: `veykemtu_invoices.subscription_payment_id`.
             * Ödeme tablosuna ikinci bir kolon açmak, aynı ilişkiyi iki
             * yerde tutmak ve biri güncellenmediğinde "belgesi var ama
             * görünmüyor" hâli üretmek olurdu.
             */
            'invoice_id' => $this->invoiceIdOf((int) $p->id),
            'overdue' => $overdue,
            'overdue_days' => $overdue ? (int) $due->diffInDays($today) : 0,
            'portions_planned' => (int) $p->portions_planned,
            'unit_price_kurus' => (int) $p->unit_price_kurus,
        ];
    }

    /**
     * Ödeme kaydının panel sözlüğündeki karşılığı.
     *
     * Kayıt `pending|succeeded|failed|refunded` tutuyor (müşteri yüzündeki
     * ödeme akışının sözlüğü), panel `pending|paid|void` bekliyor. ÇEVİRİ
     * TEK YERDE — sözleşmede `SubscriptionContract::controlStatus()` ile
     * aynı gerekçe. `failed` ve `refunded` ikisi de `void`: panelin ikisine
     * de yapacağı şey aynı (yeni bir dönem kaydı açmak) ve ayrımı isteyen
     * ekran `provider_status`'a bakar.
     */
    private function paymentStatus(string $raw): string
    {
        return match ($raw) {
            SubscriptionPayment::STATUS_SUCCEEDED => self::PAYMENT_PAID,
            SubscriptionPayment::STATUS_PENDING => self::PAYMENT_PENDING,
            default => self::PAYMENT_VOID,
        };
    }

    /**
     * Panel süzgecinin ham karşılıkları.
     *
     * @return list<string>
     */
    private function rawPaymentStatuses(string $panel): array
    {
        return match ($panel) {
            self::PAYMENT_PAID => [SubscriptionPayment::STATUS_SUCCEEDED],
            self::PAYMENT_PENDING => [SubscriptionPayment::STATUS_PENDING],
            default => [
                SubscriptionPayment::STATUS_FAILED,
                SubscriptionPayment::STATUS_REFUNDED,
            ],
        };
    }

    /**
     * Gönderilen ama türetilen alanlar için uyarı.
     *
     * SESSİZCE YUTMAK EN KÖTÜSÜ OLURDU: yönetici `due_date` yazıp
     * kaydettiğinde onun tutulduğunu sanır ve gecikmeyi yanlış günden
     * sayardı.
     *
     * @param  array{start: Carbon, end: Carbon, portions: int, unit_price: int, amount: int}  $quote
     * @return list<array<string, mixed>>
     */
    private function periodWarnings(Request $request, array $quote, Carbon $due): array
    {
        $warnings = [];

        /*
         * UYARILAR ARTIK YALNIZ GERÇEKTEN TÜRETİLDİĞİNDE ÇIKIYOR (I2).
         *
         * Üç alan da (`period_end`, `due_date`, `note`) sunucuda karşılık
         * bulduğu için normal yolda hiçbir uyarı doğmuyor. Uyarılar
         * SİLİNMEDİ çünkü göç uygulanmamış bir kurulumda kolonlar hâlâ
         * yok olabilir — ve orada "yazdım sandım" hâli en pahalısı.
         */
        if ((string) $request->input('period_end', '') !== ''
            && (string) $request->input('period_end') !== $quote['end']->toDateString()
        ) {
            $warnings[] = [
                'code' => 'period_end_derived',
                'period_end' => $quote['end']->toDateString(),
            ];
        }

        if ($request->filled('due_date')
            && !$this->hasColumn('veykemtu_subscription_payments', 'due_date')
        ) {
            $warnings[] = [
                'code' => 'due_date_derived',
                'due_date' => $quote['start']->toDateString(),
            ];
        }

        if ($request->filled('note')
            && !$this->hasColumn('veykemtu_subscription_payments', 'note')
        ) {
            $warnings[] = ['code' => 'note_not_stored'];
        }

        unset($due);

        return $warnings;
    }

    /**
     * Dönemde gerçekten üretilmiş (ve iptal edilmemiş) sipariş sayısı.
     *
     * TUTARI BELİRLEMİYOR, YANINDA DURUYOR: tutar plana göre hesaplanıyor
     * (`quote()`), bu sayı ise gerçekleşene bakıyor. İkisinin ayrışması
     * yöneticinin görmesi gereken bir şey — plan yirmi gün derken on beş
     * sipariş üretilmişse arada atlanmış bir gün vardır.
     */
    private function generatedOrderCount(Subscription $model, Carbon $start, Carbon $end): int
    {
        $cancelled = $this->transitions->statusByCode(OrderStatusTransition::CANCELLED);

        return (int) Order::query()
            ->where('bld_subscription_id', $model->id)
            ->whereDate('bld_service_date', '>=', $start->toDateString())
            ->whereDate('bld_service_date', '<=', $end->toDateString())
            ->where('status_id', '<>', $cancelled->status_id)
            ->count();
    }

    /**
     * Liste ekranındaki "kim ödemedi" sütunları — TEK SORGU.
     *
     * @param  list<int>  $ids
     * @return array<int, array{periods: int, total_kurus: int}>
     */
    private function unpaidMap(array $ids): array
    {
        if ($ids === []) {
            return [];
        }

        $map = [];

        foreach (
            SubscriptionPayment::query()
                ->whereIn('subscription_id', $ids)
                ->where('status', SubscriptionPayment::STATUS_PENDING)
                ->get(['subscription_id', 'amount_kurus']) as $row
        ) {
            $key = (int) $row->subscription_id;
            $map[$key] ??= ['periods' => 0, 'total_kurus' => 0];
            $map[$key]['periods']++;
            $map[$key]['total_kurus'] += (int) $row->amount_kurus;
        }

        return $map;
    }

    /**
     * Tahsil edilen dönemin faturasını keser — I2.
     *
     * `null` DÖNMEK BAŞARISIZLIK DEĞİL, "kesilmedi" demektir ve sebebi
     * `$warnings` içine yazılır. Belge kesimi tahsilatı DÜŞÜREMEZ: para
     * gerçekten alındı ve bir doğrulama hatası ("bu dönemde teslim edilmiş
     * porsiyon yok") yüzünden işlemi geri sarmak, yöneticiye ödemeyi
     * ikinci kez işaretletirdi.
     *
     * AYNI DÖNEMİN BELGESİ VARSA YENİSİ KESİLMEZ ve bu bir hata değil:
     * belge zaten elde. `existing_invoice_id` ile birlikte döner ki ekran
     * "zaten kesilmiş" diyebilsin.
     *
     * @param  list<array<string, mixed>>  $warnings
     */
    private function issuePeriodInvoice(SubscriptionPayment $payment, string $actor,
                                        array &$warnings): ?Invoice
    {
        $subscription = Subscription::query()
            ->with(['pauses', 'exceptions', 'delivery_points'])
            ->find((int) $payment->subscription_id);

        if ($subscription === null) {
            $warnings[] = ['code' => 'invoice_not_created', 'reason' => 'subscription_missing'];

            return null;
        }

        $from = $payment->period_start->toDateString();
        $to = $payment->period_end->toDateString();

        $existing = $this->invoices->issuedForPeriod((int) $subscription->id, $from, $to);

        if ($existing !== null) {
            $warnings[] = [
                'code' => 'invoice_already_issued',
                'invoice_id' => (int) $existing->id,
                'invoice_no' => (string) $existing->invoice_no,
            ];

            return $existing;
        }

        try {
            return $this->invoices->issueForPeriod($subscription, $from, $to,
                (int) $payment->id, $actor);
        } catch (Throwable $e) {
            $warnings[] = [
                'code' => 'invoice_not_created',
                'reason' => mb_strimwidth($e->getMessage(), 0, 200, '…', 'UTF-8'),
            ];

            return null;
        }
    }

    /**
     * Bu dönem ödemesine bağlı GEÇERLİ belgenin kimliği.
     *
     * İptal edilmiş belge sayılmaz (`issued()`): iptal edilmiş bir belgeyi
     * "faturası var" diye göstermek, yöneticinin ikinci belgeyi hiç
     * kesmemesi demekti.
     */
    private function invoiceIdOf(int $paymentId): ?int
    {
        return $this->invoiceIds[$paymentId] ??= $this->nullableInt(
            Invoice::query()
                ->issued()
                ->where('subscription_payment_id', $paymentId)
                ->orderByDesc('id')
                ->value('id'),
        );
    }

    private function findPayment(string $id): SubscriptionPayment
    {
        $row = SubscriptionPayment::query()->find((int) $id);

        if ($row === null) {
            throw ApiException::notFound('Dönem ödemesi bulunamadı.');
        }

        return $row;
    }

    // ── Ortak yardımcılar ────────────────────────────────────────────────

    private function find(string $id): Subscription
    {
        $model = Subscription::query()
            ->with(['lines', 'delivery_points', 'pauses', 'exceptions', 'customer'])
            ->find((int) $id);

        if ($model === null) {
            throw ApiException::notFound('Abonelik bulunamadı.');
        }

        return $model;
    }

    /** @return array<string, mixed> */
    private function row(Subscription $s): array
    {
        $contract = $this->latestContract((int) $s->id);
        $unpaid = $this->unpaidMap([(int) $s->id])[(int) $s->id]
            ?? ['periods' => 0, 'total_kurus' => 0];

        return [
            'id' => (int) $s->id,
            'customer_id' => (int) $s->customer_id,
            'customer_label' => $this->customerLabel($s),
            'location_id' => (int) $s->location_id,
            'status' => (string) $s->status,
            'start_date' => $this->dateOf($s->start_date),
            'end_date' => $this->dateOf($s->end_date),
            'delivery_type' => (string) $s->delivery_type,
            'delivery_time_from' => self::hhmm($s->delivery_time_from),
            'delivery_time_to' => self::hhmm($s->delivery_time_to),
            'service_days' => $this->serviceDays($s),
            'menu_mode' => (string) $s->menu_mode,
            'default_quantity' => (int) $s->default_quantity,
            'agreed_unit_price_kurus' => $this->nullableInt($s->agreed_unit_price_kurus),
            'payment_mode' => (string) $s->payment_mode,
            'lines' => $s->lines->map(fn(SubscriptionLine $l): array => [
                'id' => (int) $l->id,
                'menu_id' => $this->nullableInt($l->menu_id),
                'quantity' => (int) $l->quantity,
                'agreed_unit_price_kurus' => $this->nullableInt($l->agreed_unit_price_kurus),
                'label' => $this->trimmedOrNull($l->label),
            ])->all(),
            'delivery_points' => $s->delivery_points->map(fn(SubscriptionDeliveryPoint $p): array => [
                'id' => (int) $p->id,
                'address_id' => (int) $p->address_id,
                'quantity' => $this->nullableInt($p->quantity),
                'note' => $this->trimmedOrNull($p->note),
            ])->all(),
            'pauses' => $s->pauses->map(fn(SubscriptionPause $p): array => [
                'id' => (int) $p->id,
                'start_date' => $this->dateOf($p->start_date),
                'end_date' => $this->dateOf($p->end_date),
                'reason' => $this->trimmedOrNull($p->reason),
            ])->all(),
            'exceptions' => $s->exceptions->map(fn(SubscriptionException $e): array => [
                'id' => (int) $e->id,
                'service_date' => $this->dateOf($e->service_date),
                'skip' => (bool) $e->skip,
                'quantity_override' => $this->nullableInt($e->quantity_override),
                'note' => $this->trimmedOrNull($e->note),
            ])->all(),
            'contract' => $contract !== null ? $this->contractRow($contract) : null,
            /*
             * ÖDENMEMİŞ DÖNEM TEKİL YANITTA DA VAR (I3).
             *
             * İki alan yalnız LİSTE ucunda dönüyordu; abonelik çekmecesi
             * tekil `GET /{id}` okuduğu için "ödenmemiş dönem" kutusu
             * DAİMA 0 gösteriyordu. Yani borcu olan aboneliği listede
             * görüp detayına giren yönetici, borcun kaybolduğunu
             * sanıyordu. `unpaidMap()` tek satır için de çalışıyor;
             * ikinci bir sorgu yazmaya gerek yok.
             */
            'unpaid_periods' => $unpaid['periods'],
            'unpaid_total_kurus' => $unpaid['total_kurus'],
            'created_at' => self::ts($s->created_at),
            'updated_at' => self::ts($s->updated_at),
        ];
    }

    /**
     * Kurum adı, yoksa ad soyad.
     *
     * Abone çoğunlukla bir kurum ve listede aranan da kurum adıdır; kişi
     * adı yalnız bireysel abonelerde anlamlı.
     */
    private function customerLabel(Subscription $s): string
    {
        $customer = $s->customer;

        if ($customer === null) {
            return '#'.$s->customer_id;
        }

        $org = trim((string) ($customer->bld_org_name ?? ''));

        if ($org !== '') {
            return $org;
        }

        $name = trim(($customer->first_name ?? '').' '.($customer->last_name ?? ''));

        return $name !== '' ? $name : '#'.$s->customer_id;
    }

    /** @return list<int> */
    private function serviceDays(Subscription $s): array
    {
        return array_values(array_map(intval(...), (array) ($s->service_days ?? [])));
    }

    /**
     * Bugünden sonraki ilk üretim günü — yoksa `null`.
     *
     * Pencere takvimin tavanıyla aynı (92 gün): daha uzun bir tarama, iki
     * ay boyunca duraklatılmış bir abonelikte otuz gün daha dolaşmak
     * demekti ve cevap zaten "yakın zamanda yok".
     */
    private function nextServiceDate(Subscription $s): ?string
    {
        $days = $s->upcomingServiceDays($this->today(), self::CALENDAR_MAX_DAYS);

        foreach ($days as $day) {
            if (!$day['closed']) {
                return $day['date']->toDateString();
            }
        }

        return null;
    }

    /**
     * Kuru provada "aktifleşseydi ne olurdu" sorusunun cevabı.
     *
     * Kopya üzerinde çalışıyor: `runsOnDate()` `status === active` şartı
     * arıyor ve gerçek modeli değiştirmek, kuru provanın hiçbir şeyi
     * değiştirmemesi kuralını bozardı.
     */
    private function asActive(Subscription $model): Subscription
    {
        $copy = clone $model;
        $copy->status = Subscription::STATUS_ACTIVE;

        return $copy;
    }

    /** @return list<int> */
    private function idsRunningOn(Carbon $date): array
    {
        $candidates = Subscription::query()
            ->active()
            ->with(['pauses', 'exceptions'])
            ->whereDate('start_date', '<=', $date->toDateString())
            ->where(static function ($q) use ($date): void {
                $q->whereNull('end_date')->orWhereDate('end_date', '>=', $date->toDateString());
            })
            ->get();

        /*
         * SQL SÜZGECİ KABAYDI, SON SÖZ `runsOnDate()`'İN. Duraklamalar ve
         * tek-gün istisnaları ilişkili tablolarda ve onları SQL'e çevirmek,
         * üretim işinin kullandığı kuralın ikinci bir kopyasını yazmak
         * olurdu — ve iki kopya zamanla ayrışır.
         */
        return $candidates
            ->filter(static fn(Subscription $s): bool => $s->runsOnDate($date))
            ->pluck('id')
            ->map(intval(...))
            ->values()
            ->all();
    }

    /**
     * Üretilmiş siparişleri uyarı olarak listeler.
     *
     * Kural değişikliği ÜRETİLMİŞ SİPARİŞİ ETKİLEMEZ ve bunu söylemeyen bir
     * yanıt, yöneticiye yapmadığı bir değişikliği yaptığını düşündürürdü.
     * Siparişleri otomatik iptal etmiyoruz: kırk porsiyonluk bir iptal
     * insan kararıdır ve yolu `orders.md` → `POST /{order}/cancel`.
     *
     * @return list<array<string, mixed>>
     */
    private function generatedOrderWarnings(
        Subscription $model,
        string $code,
        Carbon $from,
        ?Carbon $to = null,
    ): array {
        $query = SubscriptionRun::query()
            ->where('subscription_id', $model->id)
            ->whereNotNull('order_id')
            ->whereDate('service_date', '>=', $from->toDateString());

        if ($to !== null) {
            $query->whereDate('service_date', '<=', $to->toDateString());
        }

        $rows = $query->orderBy('service_date')->get();

        if ($rows->isEmpty()) {
            return [];
        }

        return [[
            'code' => $code,
            'dates' => $rows->map(fn(SubscriptionRun $r): string => $this->dateOf($r->service_date))->all(),
            'order_ids' => $rows->map(static fn(SubscriptionRun $r): int => (int) $r->order_id)->all(),
        ]];
    }

    /** @return array<string, array{order_id: int|null}> */
    private function runsByDate(Subscription $model, Carbon $from, Carbon $to): array
    {
        $map = [];

        foreach (
            SubscriptionRun::query()
                ->where('subscription_id', $model->id)
                ->whereDate('service_date', '>=', $from->toDateString())
                ->whereDate('service_date', '<=', $to->toDateString())
                ->orderBy('id')
                ->get() as $run
        ) {
            $key = $this->dateOf($run->service_date);

            // ÇOK NOKTALI ABONELİKTE GÜNDE BİRDEN ÇOK SATIR olur; takvim
            // hücresi tek sipariş gösteriyor ve siparişi OLAN satır
            // kazanır. Boş satırın kazandığı bir hücre, üretilmiş bir günü
            // "üretilmedi" diye gösterirdi.
            if (isset($map[$key]) && $map[$key]['order_id'] !== null) {
                continue;
            }

            $map[$key] = ['order_id' => $this->nullableInt($run->order_id)];
        }

        return $map;
    }

    private function runFor(Subscription $model, Carbon $date): ?SubscriptionRun
    {
        return SubscriptionRun::query()
            ->where('subscription_id', $model->id)
            ->whereDate('service_date', $date->toDateString())
            ->orderByDesc('order_id')
            ->first();
    }

    private function exceptionFor(Subscription $model, Carbon $date): ?SubscriptionException
    {
        return $model->exceptions->first(
            static fn(SubscriptionException $e): bool => $e->service_date->isSameDay($date),
        );
    }

    /**
     * Bugün ya da sonrasını kapsayan, İPTAL EDİLMEMİŞ en son duraklatma.
     *
     * `cancelled_at` süzgeci olmasaydı bir kez geri alınmış duraklatma
     * `resume()` tarafından ikinci kez bulunur ve "geri alınacak duraklatma
     * yok" kapısı hiç kapanmazdı.
     */
    private function openPause(Subscription $model, Carbon $today): ?SubscriptionPause
    {
        return $model->pauses
            ->filter(static fn(SubscriptionPause $p): bool => $p->cancelled_at === null
                && $p->end_date->copy()->startOfDay()->gte($today))
            ->sortByDesc('id')
            ->first();
    }

    /**
     * Sipariş kimliği → KDS'e düşme anı.
     *
     * @param  list<int>  $orderIds
     * @return array<int, string|null>
     */
    private function releaseTimes(array $orderIds): array
    {
        if ($orderIds === []) {
            return [];
        }

        $map = [];

        foreach (
            DB::table('orders')
                ->whereIn('order_id', $orderIds)
                ->get(['order_id', self::RELEASE_COLUMN]) as $row
        ) {
            $map[(int) $row->order_id] = self::ts($row->{self::RELEASE_COLUMN} ?? null);
        }

        return $map;
    }

    /**
     * Talebin çevrildiği abonelik.
     *
     * Kolon (`veykemtu_quote_requests.converted_subscription_id`) BU
     * KULVARIN DIŞINDA açılıyor; gelene kadar alan `null` dönüyor ve
     * "zaten çevrilmiş" çakışması kurulamıyor. Sözleşme alanı yayınlıyor,
     * bu yüzden yanıttan çıkarılmadı — eksik olan veri, alanın kendisi
     * değil.
     */
    private function convertedIdOf(QuoteRequest $row): ?int
    {
        return $this->hasColumn('veykemtu_quote_requests', 'converted_subscription_id')
            ? $this->nullableInt($row->converted_subscription_id ?? null)
            : null;
    }

    private function hasColumn(string $table, string $column): bool
    {
        return $this->schemaCache['c:'.$table.'.'.$column]
            ??= Schema::hasTable($table) && Schema::hasColumn($table, $column);
    }

    /**
     * @param  list<string>  $allowed
     *
     * @throws ApiException
     */
    private function assertStatusIn(Subscription $model, array $allowed): void
    {
        if (in_array((string) $model->status, $allowed, true)) {
            return;
        }

        throw $this->conflict(
            'Abonelik bu durumdayken bu eylem yapılamaz.',
            ['conflict' => 'status', 'status' => (string) $model->status, 'allowed' => $allowed],
        );
    }

    /**
     * @param  list<string>  $fields
     *
     * @throws ApiException
     */
    private function rejectImmutable(Request $request, array $fields): void
    {
        foreach ($fields as $field) {
            if ($request->has($field)) {
                throw ApiException::validationFailed(
                    'Bu alan güncellenemez: '.$field.'.',
                    ['field' => $field],
                );
            }
        }
    }

    /** @param array<string, mixed> $details */
    private function conflict(string $message, array $details): ApiException
    {
        // `CONFLICT` bilinçli olarak geniş: "zaten var", "durum uygun
        // değil", "bağlı kayıt var" ve "aradan değişti" hâllerinde ekranın
        // yapacağı şey aynı — tazele ve tekrar sor. Ayrımı
        // `details.conflict` taşır.
        return new ApiException('CONFLICT', $message, 409, $details);
    }

    /**
     * İşletme günü — SAAT DİLİMİ TAŞIMAYAN bir gün çıpası.
     *
     * `BusinessTime::now()->startOfDay()` DEĞİL ve fark üç saat değil, bir
     * gün. O çağrı Europe/Istanbul gece yarısını üretiyor; `start_date`,
     * `service_date`, `period_start` gibi `date` sütunları ise PHP'nin
     * varsayılan diliminde (UTC) gece yarısı olarak çözülüyor. İkisini
     * karşılaştırmak aynı takvim gününü "geçmişte" sayıyordu:
     *
     *   * takvim aboneliğin İLK servis gününü hiç göstermiyordu
     *     (`runsOnDate()` `start_date`'i geleceğe atıyordu),
     *   * `generate` penceresi yedi gün yerine altı gün açılıyordu,
     *   * gecikme bir gün eksik sayılıyordu (`overdue_days`).
     *
     * Dizeden kurulan `Carbon` her iki tarafı da aynı dilime düşürüyor.
     * Aynı ders `SubscriptionLifecycle::nextPeriodStart()` içinde de
     * yazılı; oradaki gerekçe birebir buraya da geçerli.
     */
    private function today(): Carbon
    {
        return Carbon::parse(BusinessTime::today())->startOfDay();
    }

    private function parseDate(string $value, string $field): Carbon
    {
        try {
            $date = Carbon::createFromFormat('Y-m-d', $value);
        } catch (Throwable) {
            $date = null;
        }

        if ($date === null || $date->format('Y-m-d') !== $value) {
            throw ApiException::validationFailed(
                'Tarih YYYY-AA-GG biçiminde olmalı.',
                ['field' => $field],
            );
        }

        return $date->startOfDay();
    }

    /** @return list<string> */
    private function csv(string $value): array
    {
        return array_values(array_filter(
            array_map(trim(...), explode(',', $value)),
            static fn(string $part): bool => $part !== '',
        ));
    }

    /** @return list<int> */
    private function customerIdsMatching(string $term): array
    {
        $like = '%'.trim($term).'%';

        return ApiCustomer::query()
            ->where(static function ($q) use ($like): void {
                $q->where('bld_org_name', 'like', $like)
                    ->orWhere('first_name', 'like', $like)
                    ->orWhere('last_name', 'like', $like)
                    ->orWhere('telephone', 'like', $like);
            })
            ->pluck('customer_id')
            ->map(intval(...))
            ->all();
    }

    /** `time` kolonu `08:00:00` döner; sözleşme `HH:mm` istiyor (§6). */
    private static function hhmm(mixed $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $text = $value instanceof Carbon ? $value->format('H:i') : trim((string) $value);

        return $text === '' ? null : mb_substr($text, 0, 5);
    }

    private function timeOrNull(mixed $value): ?string
    {
        $text = $value === null ? '' : trim((string) $value);

        return $text === '' ? null : $text.':00';
    }

    private function dateOf(mixed $value): ?string
    {
        return $value === null ? null : Carbon::parse($value)->toDateString();
    }

    private function trimmedOrNull(mixed $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $text = trim((string) $value);

        return $text === '' ? null : $text;
    }

    private function nullableInt(mixed $value): ?int
    {
        return $value === null || $value === '' ? null : (int) $value;
    }

    /** @return array<string, mixed>|null */
    private function decodeJson(mixed $value): ?array
    {
        if ($value === null) {
            return null;
        }

        if (is_array($value)) {
            return $value;
        }

        $decoded = json_decode((string) $value, true);

        return is_array($decoded) ? $decoded : null;
    }

    /**
     * Soyadın yalnız baş harfi — liste ekranı için.
     *
     * Talep listesi bir iş kuyruğu ve orada tam ad görmenin bir faydası
     * yok; arayacak kişi kaydı zaten açar ve orada her şey maskesizdir.
     */
    private function maskName(string $name): string
    {
        $parts = preg_split('/\s+/u', trim($name)) ?: [];

        if (count($parts) < 2) {
            return trim($name);
        }

        $last = (string) array_pop($parts);

        return implode(' ', $parts).' '.mb_substr($last, 0, 1).'.';
    }

    /** İlk 3 ve son 3 hane; ortası yıldız. */
    private function maskPhone(mixed $phone): ?string
    {
        $text = $this->trimmedOrNull($phone);

        if ($text === null) {
            return null;
        }

        $digits = OtpService::normalize($text);

        if (strlen($digits) < 7) {
            return str_repeat('*', mb_strlen($text));
        }

        return substr($digits, 0, 3).str_repeat('*', strlen($digits) - 6).substr($digits, -3);
    }

    /** İlk harf + alan adı. */
    private function maskEmail(mixed $email): ?string
    {
        $text = $this->trimmedOrNull($email);

        if ($text === null) {
            return null;
        }

        $at = strrpos($text, '@');

        if ($at === false || $at === 0) {
            return str_repeat('*', mb_strlen($text));
        }

        return mb_substr($text, 0, 1).'***'.substr($text, $at);
    }
}
