<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Control;

use Igniter\Cart\Models\Menu;
use Igniter\Local\Models\Location;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Throwable;
use Veykemtu\BridgeApi\Admin\SettingsRepository;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ControlAudit;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Models\DailyMenuItem;
use Veykemtu\BridgeApi\Models\DailyMenuStock;
use Veykemtu\BridgeApi\Models\MenuSoldOut;
use Veykemtu\BridgeApi\Services\DailyMenuService;
use Veykemtu\BridgeApi\Services\LocationGate;
use Veykemtu\BridgeApi\Services\OrderingWindow;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Kontrol Merkezi — günlük menü takvimi (`/api/control/menu/*`).
 *
 * Sözleşme: `docs/control/menu.md` (uç listesi, gövdeler, hata kodları) +
 * `docs/control/00-genel.md` (imza, `actor`/`reason`/`dry_run` kabuğu,
 * hata biçimi). Buradaki hiçbir alan adı uydurulmadı; hepsi o iki
 * dosyadan geliyor.
 *
 * NEDEN `MenuController`'IN İÇİNE YAZILMADI: o denetleyici
 * `/api/control/kds/menu` ucuna, yani sipariş düzenleme ekranının ÜRÜN
 * SEÇİCİSİNE bakıyor ve K-21 ile dondurulmuş bir yüzeyin parçası
 * (`AGENTS.md` §2.3). Bu dosya ise `/api/control/menu` önekindeki on üç
 * ucu taşıyor — ayrı rota ailesi, ayrı hız sınırı kovası
 * (`bld-control-panel`), ayrı sözleşme dosyası. İkisini tek sınıfa
 * koymak, "menu" kelimesinin iki farklı anlamını (katalog ürünü / günün
 * menüsü) aynı yerde toplamak olurdu.
 *
 * BU SINIF İŞ MANTIĞI TAŞIMAZ — kabuktur:
 *   - "bu güne sipariş verilebilir mi", kesim saati, kapalı gün, ileri
 *     görüş penceresi → `DailyMenuService` + `OrderingWindow`,
 *   - porsiyon sayaçları ve tavan aritmetiği → `DailyStock` /
 *     `DailyMenuStock`,
 *   - `actor` + `reason` + `dry_run` + denetim satırı →
 *     `ControlController::write()`.
 *
 * TAVAN NEREDE DURUYOR: `veykemtu_daily_menu_stock` satırlarında
 * (`(location_id, service_date, menu_id)`; `menu_id = 0` gün toplamı).
 * Sözleşme metni tavanları `veykemtu_daily_menus.capacity_total` ve
 * `veykemtu_daily_menu_items.capacity` kolonları olarak anlatıyor; S2 o
 * kolonları yazmadı ve haklı — sayaçlar (`sold`, `reserved`) tavanla aynı
 * satırda durmalı ki düşüm TEK KOŞULLU `UPDATE` ile yapılabilsin. Alan
 * ADLARI sözleşmedeki gibi kalıyor (`capacity_total`, `capacity`), yalnız
 * kaynakları o tablo. Fark rapora yazıldı.
 */
class DailyMenuController extends ControlController
{
    /** `HH:mm` — gün içi saatler yerel (Europe/Istanbul), §6. */
    private const string TIME_PATTERN = '/^([01]\d|2[0-3]):[0-5]\d$/';

    /**
     * Yeni kaleme sıra verilmediğinde eklenen adım.
     *
     * ONAR ARTMAK BİLİNÇLİ: araya kalem sokmak (çorba ile ana yemek
     * arasına salata) bütün listeyi yeniden numaralamayı gerektirmesin.
     */
    private const int SORT_STEP = 10;

    /** Tavan satılanın altına düştüğünde yanıta konan uyarı. */
    private const string WARN_BELOW_SOLD = 'capacity_below_sold';

    /*
     * `DailyStock` BİLEREK ENJEKTE EDİLMİYOR: o servisin bütün yüzeyi
     * DÜŞÜM (`take`/`reserve`/`release`) ve düşümün tek doğru ilkeli
     * koşullu `UPDATE` orada kalmalı. Bu uçlar sayaçlara dokunmuyor,
     * yalnız tavan yazıyor ve okuyor — `DailyMenuStock` sınıf yorumunun
     * "tavanı Kontrol Merkezi yazar, düşüm ASLA bu model üzerinden
     * yapılmaz" cümlesi tam olarak bu ayrımı tarif ediyor.
     */
    public function __construct(
        private readonly DailyMenuService $menus,
        private readonly OrderingWindow $window,
        private readonly LocationGate $gate,
        private readonly SettingsRepository $settings,
    ) {}

    // ── Takvim ve okuma ───────────────────────────────────────────────────

    /**
     * `GET /calendar?from=&to=` — takvim ızgarasının tek isteği.
     *
     * ARALIKTAKİ HER GÜN DÖNER, menüsü olmayanlar dâhil (`id: null`).
     * Eksik günü atlamak, ızgarayı çizen ekranı boşlukları kendi
     * hesaplamaya zorlardı; üstelik "22 Ağustos'a menü girilmemiş" tam da
     * yöneticinin görmesi gereken şey. (Müşteri takvimi
     * `DailyMenuService::calendar()` bunun tersini yapar ve haklıdır:
     * orada boş gün gösterilecek bir şey değil.)
     *
     * GÜN BAŞINA KALEM LİSTESİ DÖNMEZ. Bir aylık görünümde otuz günün
     * kalemlerini taşımak, ekranın hiç göstermediği veriyi yollamak olurdu.
     */
    public function calendar(Request $request): JsonResponse
    {
        $location = $this->location($request);

        $data = $request->validate([
            'from' => ['required', 'string'],
            'to' => ['required', 'string'],
        ]);

        $from = $this->parseDate((string) $data['from'], 'from');
        $to = $this->parseDate((string) $data['to'], 'to');

        if ($to->lessThan($from)) {
            throw ApiException::validationFailed(
                'Bitiş günü başlangıçtan önce olamaz.',
                ['from' => $from->toDateString(), 'to' => $to->toDateString()],
            );
        }

        /*
         * Tavan sözleşmede `DailyMenuService::MAX_CALENDAR_DAYS`'e bağlı ve
         * sayı burada TEKRAR YAZILMIYOR: 92 iki yerde durursa biri
         * değiştiği gün panel ile müşteri takvimi farklı aralıklar kabul
         * eder ve fark ancak doksan üçüncü günde görülür.
         */
        if ($from->diffInDays($to) + 1 > DailyMenuService::MAX_CALENDAR_DAYS) {
            throw ApiException::validationFailed(
                'Takvim aralığı en fazla '.DailyMenuService::MAX_CALENDAR_DAYS.' gün olabilir.',
                ['from' => $from->toDateString(), 'to' => $to->toDateString()],
            );
        }

        // Taslaklar DÂHİL, tek sorgu: müşteri takvimi yalnız yayındakileri
        // görür, yönetici ise düzenleyeceği taslağı görmek zorunda.
        $days = DailyMenu::query()
            ->with('items')
            ->where('location_id', (int) $location->location_id)
            ->whereBetween('menu_date', [$from->toDateString(), $to->toDateString()])
            ->get()
            ->keyBy(static fn(DailyMenu $menu): string => $menu->menu_date->toDateString());

        $totals = $this->dayTotals($location, $from, $to);

        $rows = [];

        for ($cursor = $from->copy(); $cursor->lessThanOrEqualTo($to); $cursor->addDay()) {
            $key = $cursor->toDateString();
            /** @var DailyMenu|null $day */
            $day = $days->get($key);

            /*
             * SATILABİLİRLİK KARARI BURADA HESAPLANMIYOR, SORULUYOR.
             *
             * `verdict()` sebep sırasını (geçmiş → çok ileri → kapalı gün →
             * yayınlanmamış → kesim) tek yerde tutuyor ve o listenin
             * büyüyeceği belli: `DailyStock` sınıf yorumu günün tavanı
             * dolduğunda `verdict()`'in `sold_out` diyeceğini şimdiden
             * yazıyor. Zinciri buraya kopyalasaydık o sebep eklendiği gün
             * panel takvimi onu göstermez, gün "açık" görünür ve müşteri
             * kapalı bir güne sipariş vermeye çalışırdı.
             *
             * BEDELİ GÜN BAŞINA BİRKAÇ SORGU. Kabul edildi: bu uç tek
             * yöneticinin ekranı ve §2 bütçesinde 120 saniyede bir
             * yoklanıyor. Toplu bir `DailyMenuService::controlCalendar()`
             * yazılırsa çağrı tek satırda oraya taşınır.
             */
            $verdict = $this->menus->verdict($location, $cursor);

            $cutoff = $this->window->cutoffFromTime($location, $cursor, $day?->cutoff_time);
            $total = $totals[$key] ?? ['capacity' => null, 'sold' => 0, 'remaining' => null];

            $rows[] = [
                'date' => $key,
                'id' => $day !== null ? (int) $day->id : null,
                'status' => $day?->status,
                'title' => $day?->title,
                'package_price_kurus' => $day?->package_price_kurus !== null
                    ? (int) $day->package_price_kurus
                    : null,
                'item_count' => $day?->items->count() ?? 0,
                'capacity_total' => $total['capacity'],
                'sold_total' => $total['sold'],
                // Sıfır ile `null` KARIŞTIRILMAMALI: sıfır "doldu",
                // `null` "tavan konmamış".
                'remaining_total' => $total['remaining'],
                'cutoff_time' => self::hhmm($cutoff),
                'cutoff_passed' => $this->window->hasPassed($cutoff),
                'closed' => $verdict['closed'],
                'closed_reason' => $verdict['closed_note'],
                'orderable' => $verdict['orderable'],
                // `orderable: true` iken alan null'dır.
                'not_orderable_reason' => $verdict['reason'],
            ];
        }

        return $this->json([
            'data' => $rows,
            'meta' => [
                'from' => $from->toDateString(),
                'to' => $to->toDateString(),
                'location_id' => (int) $location->location_id,
                'default_cutoff_time' => $this->gate->orderCutoff($location),
                'max_lookahead_days' => $this->gate->maxLookaheadDays($location),
            ],
            'server_time' => $this->serverTime(),
        ]);
    }

    /**
     * `GET /days/{date}` — tek günün tam menüsü, TASLAK DÂHİL.
     *
     * Müşteri ucunun aksine `status` süzgeci yok: yönetici düzenleyeceği
     * günü görebilmeli ve taslak zaten onun için var.
     */
    public function show(Request $request, string $date): JsonResponse
    {
        $location = $this->location($request);
        $day = $this->parseDate($date, 'date');

        return $this->json([
            'data' => $this->dayPayload($location, $this->requireDay($location, $day)),
            'server_time' => $this->serverTime(),
        ]);
    }

    // ── Gün yazma ─────────────────────────────────────────────────────────

    /**
     * `POST /days` — yeni gün. HER ZAMAN `draft` doğar.
     *
     * Yayın ayrı bir eylem ve ayrı bir denetim satırı: yarım girilmiş bir
     * perşembe, kaydedildiği anda müşteriye görünmemeli.
     */
    public function store(Request $request): JsonResponse
    {
        $location = $this->location($request);

        $data = $request->validate([
            'date' => ['required', 'string'],
            'title' => ['sometimes', 'nullable', 'string', 'max:120'],
            'description' => ['sometimes', 'nullable', 'string', 'max:500'],
            'internal_note' => ['sometimes', 'nullable', 'string', 'max:255'],
            // Sıfır kabul edilmez: "bedava paket" anlamına gelirdi ve
            // `LineResolver` onu zaten reddediyor.
            'package_price_kurus' => ['sometimes', 'nullable', 'integer', 'min:1'],
            'components_sellable' => ['sometimes', 'boolean'],
            'cutoff_time' => ['sometimes', 'nullable', 'string', 'regex:'.self::TIME_PATTERN],
            'capacity_total' => ['sometimes', 'nullable', 'integer', 'min:0'],
            ...$this->itemRules('items.*.'),
            'items' => ['sometimes', 'array'],
        ]);

        $date = $this->parseDate((string) $data['date'], 'date');

        if ($date->lessThan($this->today())) {
            throw ApiException::validationFailed(
                'Geçmiş bir güne menü kurulamaz.',
                ['field' => 'date', 'date' => $date->toDateString()],
            );
        }

        /** @var list<array<string, mixed>> $items */
        $items = array_values($data['items'] ?? []);
        $exists = $this->findDay($location, $date) instanceof DailyMenu;

        $response = $this->write(
            $request,
            'menu.day.create',
            ControlAudit::TARGET_DAILY_MENU,
            // Gün henüz yok; kimliği `write()` denetim satırını AÇARKEN
            // bilinemiyor (satır bilerek işlemden önce açılıyor). Aynı
            // sınır `device.create`'te de var; `payload_json.date` günü
            // tekil olarak zaten belirliyor.
            null,
            [
                'date' => $date->toDateString(),
                'location_id' => (int) $location->location_id,
                'item_count' => count($items),
            ],
            fn(): array => [
                'action' => 'menu.day.create',
                'date' => $date->toDateString(),
                'location_id' => (int) $location->location_id,
                'item_count' => count($items),
                'package_price_kurus' => $data['package_price_kurus'] ?? null,
                /*
                 * KURU PROVA ÇAKIŞMAYI FIRLATMAZ, RAPORLAR.
                 *
                 * Sözleşmedeki `would` gövdesi bu alanı taşıyor; çakışmada
                 * 409 fırlatılsaydı alan her zaman `false` olurdu, yani
                 * hiçbir şey anlatmayan bir alan. Gerçek gönderim yine
                 * 409 verir (aşağıdaki `$apply`).
                 */
                'conflicts_with_existing' => $exists,
            ],
            function (array $intent) use ($location, $date, $data, $items): array {
                if ($this->findDay($location, $date) instanceof DailyMenu) {
                    throw $this->conflict(
                        'Bu tarihe zaten bir menü kurulmuş. Güncellemek için düzenleyin.',
                        ['conflict' => 'date', 'date' => $date->toDateString()],
                    );
                }

                DB::transaction(function () use ($location, $date, $data, $items, $intent): void {
                    $day = new DailyMenu;
                    $day->location_id = (int) $location->location_id;
                    $day->menu_date = $date->toDateString();
                    $day->status = DailyMenu::STATUS_DRAFT;
                    $day->title = $this->trimmedOrNull($data['title'] ?? null);
                    $day->description = $this->trimmedOrNull($data['description'] ?? null);
                    $day->internal_note = $this->trimmedOrNull($data['internal_note'] ?? null);
                    $day->package_price_kurus = $this->nullableInt($data['package_price_kurus'] ?? null);
                    $day->components_sellable = (bool) ($data['components_sellable'] ?? true);
                    $day->cutoff_time = $this->trimmedOrNull($data['cutoff_time'] ?? null);
                    $day->save();

                    foreach ($items as $index => $row) {
                        $this->fillItem(new DailyMenuItem, $row, [
                            'daily_menu_id' => (int) $day->id,
                            'menu_id' => (int) $row['menu_id'],
                            'sort_order' => (int) ($row['sort_order'] ?? ($index + 1) * self::SORT_STEP),
                        ])->save();

                        if (array_key_exists('capacity', $row)) {
                            $this->writeCapacity(
                                $location,
                                $date,
                                (int) $row['menu_id'],
                                $this->nullableInt($row['capacity']),
                                $intent['actor'],
                            );
                        }
                    }

                    if (array_key_exists('capacity_total', $data)) {
                        $this->writeCapacity(
                            $location,
                            $date,
                            DailyMenuStock::DAY_TOTAL,
                            $this->nullableInt($data['capacity_total']),
                            $intent['actor'],
                        );
                    }
                });

                return ['data' => $this->dayPayload($location, $this->requireDay($location, $date))];
            },
        );

        // 201 yalnız GERÇEKTEN oluşturulduğunda: kuru provada hiçbir kayıt
        // doğmadı ve `Created` demek yanlış olurdu.
        return $request->boolean('dry_run') ? $response : $response->setStatusCode(201);
    }

    /**
     * `PATCH /days/{date}` — KISMİ yazar.
     *
     * Gönderilmeyen alan değişmez, `null` gönderilen alan temizlenir.
     * İkisi ayrı: alanı hiç göndermemek "dokunma", `null` göndermek
     * "boşalt". Bu yüzden `array_key_exists` ile bakılıyor, `?? null` ile
     * değil — `?? null` iki hâli birbirine eşitlerdi.
     */
    public function update(Request $request, string $date): JsonResponse
    {
        $location = $this->location($request);
        $day = $this->parseDate($date, 'date');
        $model = $this->requireDay($location, $day);

        /*
         * `location_id` BU LİSTEDE YOK ve olamaz: her uçta vitrin SEÇİCİSİ
         * olarak kabul ediliyor (sözleşme: "Hepsinde isteğe bağlı
         * `location_id`"). Reddedilseydi çok vitrinli kurulumda gün hiç
         * düzenlenemezdi. Günü taşımak yine mümkün değil — alan yalnız
         * hangi vitrinin okunacağını seçiyor, kaydın kolonuna yazılmıyor.
         */
        $this->rejectImmutable($request, ['date', 'status'], 'Gün');

        $data = $request->validate([
            'title' => ['sometimes', 'nullable', 'string', 'max:120'],
            'description' => ['sometimes', 'nullable', 'string', 'max:500'],
            'internal_note' => ['sometimes', 'nullable', 'string', 'max:255'],
            'package_price_kurus' => ['sometimes', 'nullable', 'integer', 'min:1'],
            'components_sellable' => ['sometimes', 'boolean'],
            'cutoff_time' => ['sometimes', 'nullable', 'string', 'regex:'.self::TIME_PATTERN],
            'capacity_total' => ['sometimes', 'nullable', 'integer', 'min:0'],
            'image_path' => ['sometimes', 'nullable', 'string', 'max:255'],
        ]);

        $changes = $this->dayChanges($data);
        $fields = array_keys($changes);

        if (array_key_exists('capacity_total', $data)) {
            $fields[] = 'capacity_total';
        }

        return $this->write(
            $request,
            'menu.day.update',
            ControlAudit::TARGET_DAILY_MENU,
            (int) $model->id,
            ['date' => $day->toDateString(), 'fields' => $fields],
            function () use ($location, $day, $data, $fields): array {
                $this->assertPriceEditable($location, $day, $data);

                return [
                    'action' => 'menu.day.update',
                    'date' => $day->toDateString(),
                    'fields' => $fields,
                ];
            },
            function (array $intent) use ($location, $day, $model, $data, $changes): array {
                /*
                 * YAYINDAKİ GÜNE PATCH SERBEST — menü yayındayken başlık ya
                 * da açıklama düzeltmek gerçek bir ihtiyaç. Kapalı olan tek
                 * kapı KESİM SAATİ GEÇMİŞ GÜNÜN FİYATI.
                 */
                $this->assertPriceEditable($location, $day, $data);

                DB::transaction(function () use ($location, $day, $model, $data, $changes, $intent): void {
                    foreach ($changes as $column => $value) {
                        $model->{$column} = $value;
                    }

                    $model->save();

                    if (array_key_exists('capacity_total', $data)) {
                        $this->writeCapacity(
                            $location,
                            $day,
                            DailyMenuStock::DAY_TOTAL,
                            $this->nullableInt($data['capacity_total']),
                            $intent['actor'],
                        );
                    }
                });

                return ['data' => $this->dayPayload($location, $this->requireDay($location, $day))];
            },
        );
    }

    /**
     * `DELETE /days/{date}` — yalnız taslak, yalnız siparişsiz.
     *
     * Kalemler birlikte gider: bağımsız bir varlık değil, günün parçası.
     */
    public function destroy(Request $request, string $date): JsonResponse
    {
        $location = $this->location($request);
        $day = $this->parseDate($date, 'date');
        $model = $this->requireDay($location, $day);

        return $this->write(
            $request,
            'menu.day.delete',
            ControlAudit::TARGET_DAILY_MENU,
            (int) $model->id,
            [
                'date' => $day->toDateString(),
                'status' => (string) $model->status,
                'item_count' => $model->items->count(),
            ],
            function () use ($location, $day, $model): array {
                $this->assertDeletable($location, $day, $model);

                return [
                    'action' => 'menu.day.delete',
                    'date' => $day->toDateString(),
                    'item_count' => $model->items->count(),
                ];
            },
            function () use ($location, $day, $model): array {
                $this->assertDeletable($location, $day, $model);

                DB::transaction(function () use ($model): void {
                    DailyMenuItem::query()->where('daily_menu_id', $model->id)->delete();
                    $model->delete();
                });

                /*
                 * STOK SATIRLARI SİLİNMEZ. `veykemtu_daily_menu_stock`
                 * sayaç taşıyor ve o güne abonelik rezervasyonu girmiş
                 * olabilir (`reserved`); satırı silmek rezervasyonu
                 * görünmez kılardı. Menüsüz bir günün tavanı zaten hiçbir
                 * şeyi kapatmıyor.
                 */
                return ['data' => ['deleted' => true, 'date' => $day->toDateString()]];
            },
        );
    }

    // ── Yayın ─────────────────────────────────────────────────────────────

    /**
     * `POST /days/{date}/publish`.
     *
     * ÖN DENETİMLER KURU PROVADA DA KOŞAR (`docs/control/00-genel.md`
     * §3.1): "kuru prova geçti" diyen bir ekran gerçek gönderimde
     * patlamamalı.
     */
    public function publish(Request $request, string $date): JsonResponse
    {
        $location = $this->location($request);
        $day = $this->parseDate($date, 'date');
        $model = $this->requireDay($location, $day);

        return $this->write(
            $request,
            'menu.publish',
            ControlAudit::TARGET_DAILY_MENU,
            (int) $model->id,
            ['date' => $day->toDateString(), 'from' => (string) $model->status],
            function () use ($day, $model): array {
                $this->assertPublishable($model, $day);

                return [
                    'action' => 'menu.publish',
                    'date' => $day->toDateString(),
                    'from' => DailyMenu::STATUS_DRAFT,
                    'to' => DailyMenu::STATUS_PUBLISHED,
                    'item_count' => $model->items->count(),
                ];
            },
            function () use ($location, $day, $model): array {
                $this->assertPublishable($model, $day);

                $model->status = DailyMenu::STATUS_PUBLISHED;
                // `forStorage` şart: Eloquent `datetime` alanını yazarken
                // Carbon'un kendi dilimini, okurken PHP varsayılanını
                // kullanıyor ve arada üç saat kayıyor (`BusinessTime`).
                $model->published_at = BusinessTime::forStorage(BusinessTime::now());
                $model->save();

                /*
                 * YENİDEN YAYINLAMAK SAYAÇLARI SIFIRLAMAZ: burada stok
                 * tablosuna hiç dokunulmuyor. Dokunulsaydı, bir yazım
                 * hatasını düzeltmek için taslağa çekilip yeniden
                 * yayınlanan bir gün, o güne girmiş bütün siparişleri
                 * porsiyon sayımından silerdi.
                 */
                return ['data' => $this->statusPayload($this->requireDay($location, $day))];
            },
        );
    }

    /**
     * `POST /days/{date}/unpublish`.
     *
     * Satılmış bir günü gizlemek, siparişin bağlandığı menüyü müşteriden
     * kaçırmak olurdu — bu yüzden siparişli gün taslağa çekilemez.
     */
    public function unpublish(Request $request, string $date): JsonResponse
    {
        $location = $this->location($request);
        $day = $this->parseDate($date, 'date');
        $model = $this->requireDay($location, $day);

        return $this->write(
            $request,
            'menu.unpublish',
            ControlAudit::TARGET_DAILY_MENU,
            (int) $model->id,
            ['date' => $day->toDateString(), 'from' => (string) $model->status],
            function () use ($location, $day, $model): array {
                $this->assertUnpublishable($location, $day, $model);

                return [
                    'action' => 'menu.unpublish',
                    'date' => $day->toDateString(),
                    'from' => DailyMenu::STATUS_PUBLISHED,
                    'to' => DailyMenu::STATUS_DRAFT,
                    'item_count' => $model->items->count(),
                ];
            },
            function () use ($location, $day, $model): array {
                $this->assertUnpublishable($location, $day, $model);

                $model->status = DailyMenu::STATUS_DRAFT;
                /*
                 * "Bir zamanlar yayındaydı" bilgisi TAŞINMAZ:
                 * `DailyMenu::findPublished()` yalnız `status`'e bakıyor ve
                 * iki ayrı doğruluk kaynağı bir gün çelişir. Kim ne zaman
                 * yayınladı sorusunun cevabı denetim izidir.
                 */
                $model->published_at = null;
                $model->published_by = null;
                $model->save();

                return ['data' => $this->statusPayload($this->requireDay($location, $day))];
            },
        );
    }

    // ── Kalemler ──────────────────────────────────────────────────────────

    /** `POST /days/{date}/items` — kalem ekler. */
    public function storeItem(Request $request, string $date): JsonResponse
    {
        $location = $this->location($request);
        $day = $this->parseDate($date, 'date');
        $model = $this->requireDay($location, $day);

        $data = $request->validate($this->itemRules());
        $menuId = (int) $data['menu_id'];
        $sortOrder = (int) ($data['sort_order'] ?? $this->nextSortOrder($model));

        return $this->write(
            $request,
            'menu.item.create',
            ControlAudit::TARGET_DAILY_MENU,
            (int) $model->id,
            ['date' => $day->toDateString(), 'menu_id' => $menuId],
            function () use ($day, $model, $menuId, $sortOrder): array {
                $this->assertItemAbsent($model, $menuId);

                return [
                    'action' => 'menu.item.create',
                    'date' => $day->toDateString(),
                    'menu_id' => $menuId,
                    'sort_order' => $sortOrder,
                ];
            },
            function (array $intent) use ($location, $day, $model, $menuId, $sortOrder, $data): array {
                $this->assertItemAbsent($model, $menuId);

                DB::transaction(function () use ($location, $day, $model, $menuId, $sortOrder, $data, $intent): void {
                    $this->fillItem(new DailyMenuItem, $data, [
                        'daily_menu_id' => (int) $model->id,
                        'menu_id' => $menuId,
                        // Sıra verilmediyse mevcut en büyük + 10.
                        'sort_order' => $sortOrder,
                    ])->save();

                    if (array_key_exists('capacity', $data)) {
                        $this->writeCapacity(
                            $location,
                            $day,
                            $menuId,
                            $this->nullableInt($data['capacity']),
                            $intent['actor'],
                        );
                    }
                });

                return ['data' => $this->dayPayload($location, $this->requireDay($location, $day))];
            },
        );
    }

    /**
     * `PATCH /days/{date}/items/{item}` — KISMİ.
     *
     * `menu_id` yazılamaz: ürünü değiştirmek kalemi silip yenisini
     * eklemektir ve denetim izinde İKİ AYRI SATIR olarak görünmelidir.
     */
    public function updateItem(Request $request, string $date, int $item): JsonResponse
    {
        $location = $this->location($request);
        $day = $this->parseDate($date, 'date');
        $model = $this->requireDay($location, $day);
        $row = $this->requireItem($model, $item);

        $this->rejectImmutable($request, ['menu_id'], 'Kalem');

        $data = $request->validate([
            'quantity' => ['sometimes', 'integer', 'min:1'],
            'sort_order' => ['sometimes', 'integer', 'min:0'],
            'label' => ['sometimes', 'nullable', 'string', 'max:120'],
            'price_override_kurus' => ['sometimes', 'nullable', 'integer', 'min:0'],
            'is_required' => ['sometimes', 'boolean'],
            'sellable_alone' => ['sometimes', 'boolean'],
            'capacity' => ['sometimes', 'nullable', 'integer', 'min:0'],
        ]);

        return $this->write(
            $request,
            'menu.item.update',
            ControlAudit::TARGET_DAILY_MENU,
            (int) $model->id,
            [
                'date' => $day->toDateString(),
                // Kalem kimliği yükte durur; hedef GÜNDÜR — "17 Ağustos
                // menüsüne ne oldu" sorusu tek `target_id` ile
                // cevaplanabilmeli.
                'item_id' => (int) $row->id,
                'menu_id' => (int) $row->menu_id,
                'fields' => array_keys($data),
            ],
            fn(): array => [
                'action' => 'menu.item.update',
                'date' => $day->toDateString(),
                'item_id' => (int) $row->id,
                'fields' => array_keys($data),
            ],
            function (array $intent) use ($location, $day, $row, $data): array {
                DB::transaction(function () use ($location, $day, $row, $data, $intent): void {
                    $this->fillItem($row, $data)->save();

                    if (array_key_exists('capacity', $data)) {
                        $this->writeCapacity(
                            $location,
                            $day,
                            (int) $row->menu_id,
                            $this->nullableInt($data['capacity']),
                            $intent['actor'],
                        );
                    }
                });

                return ['data' => $this->dayPayload($location, $this->requireDay($location, $day))];
            },
        );
    }

    /**
     * `DELETE /days/{date}/items/{item}`.
     *
     * Yayınlanmış bir günden kalem silmek serbesttir; engel yalnız o
     * kalem O GÜNÜN siparişlerinde geçiyorsa çıkar. Sipariş satırı
     * `order_menus`'ta kendi kopyasını taşıdığı için geçmiş bozulmaz —
     * engel, yöneticinin farkında olmadan "mutfağın bugün pişirdiği bir
     * kalemi" listeden düşürmesini önlemek içindir.
     */
    public function destroyItem(Request $request, string $date, int $item): JsonResponse
    {
        $location = $this->location($request);
        $day = $this->parseDate($date, 'date');
        $model = $this->requireDay($location, $day);
        $row = $this->requireItem($model, $item);

        return $this->write(
            $request,
            'menu.item.delete',
            ControlAudit::TARGET_DAILY_MENU,
            (int) $model->id,
            [
                'date' => $day->toDateString(),
                'item_id' => (int) $row->id,
                'menu_id' => (int) $row->menu_id,
            ],
            function () use ($location, $day, $row): array {
                $this->assertItemUnused($location, $day, $row);

                return [
                    'action' => 'menu.item.delete',
                    'date' => $day->toDateString(),
                    'item_id' => (int) $row->id,
                    'menu_id' => (int) $row->menu_id,
                ];
            },
            function () use ($location, $day, $row): array {
                $this->assertItemUnused($location, $day, $row);
                $row->delete();

                // Stok satırı BIRAKILIYOR: sayaç taşıyor ve kalem yeniden
                // eklenirse tavan da rezervasyon da yerinde durur.
                return ['data' => ['deleted' => true, 'item_id' => (int) $row->id]];
            },
        );
    }

    // ── Stok ──────────────────────────────────────────────────────────────

    /** `GET /days/{date}/stock` — gün ve kalem tavanları, satılanlarla. */
    public function stock(Request $request, string $date): JsonResponse
    {
        $location = $this->location($request);
        $day = $this->parseDate($date, 'date');
        $model = $this->requireDay($location, $day);

        return $this->json([
            'data' => $this->stockPayload($location, $day, $model),
            'server_time' => $this->serverTime(),
        ]);
    }

    /**
     * `PUT /days/{date}/stock` — tavanları BİRLİKTE yazar.
     *
     * KISMİ DEĞİL: gönderilmeyen kalemin tavanı `null`'a düşer. Fark
     * göndermek, iki sekmede açık iki yöneticinin birbirinin tavanını
     * sessizce koruması demekti; buradaki niyet "bugünün tavan tablosu
     * şudur"dur.
     *
     * SAYAÇLAR SIFIRLANMAZ: `writeCapacity()` yalnız `capacity` kolonuna
     * dokunuyor, `sold` ve `reserved` olduğu gibi kalıyor.
     */
    public function setStock(Request $request, string $date): JsonResponse
    {
        $location = $this->location($request);
        $day = $this->parseDate($date, 'date');
        $model = $this->requireDay($location, $day);

        $data = $request->validate([
            'capacity_total' => ['sometimes', 'nullable', 'integer', 'min:0'],
            'items' => ['sometimes', 'array'],
            'items.*.item_id' => ['required', 'integer', 'min:1', 'distinct'],
            // Sıfır GEÇERLİ bir değer: "bugün satılmıyor".
            'items.*.capacity' => ['required', 'nullable', 'integer', 'min:0'],
        ]);

        $capacityTotal = $this->nullableInt($data['capacity_total'] ?? null);
        $byItemId = $this->itemCapacities($model, array_values($data['items'] ?? []));

        return $this->write(
            $request,
            'menu.stock',
            ControlAudit::TARGET_DAILY_MENU,
            (int) $model->id,
            [
                'date' => $day->toDateString(),
                'capacity_total' => $capacityTotal,
                'item_count' => count($byItemId),
            ],
            /*
             * KURU PROVANIN ASIL İŞİ BU: yönetici tavanı yazmadan önce kaç
             * siparişin altında kaldığını görür. `warnings` bu yüzden
             * provada da hesaplanıyor.
             */
            fn(): array => [
                'action' => 'menu.stock',
                ...$this->stockProjection($location, $day, $model, $capacityTotal, $byItemId),
            ],
            function (array $intent) use ($location, $day, $model, $capacityTotal, $byItemId): array {
                DB::transaction(function () use ($location, $day, $model, $capacityTotal, $byItemId, $intent): void {
                    $this->writeCapacity(
                        $location,
                        $day,
                        DailyMenuStock::DAY_TOTAL,
                        $capacityTotal,
                        $intent['actor'],
                    );

                    foreach ($model->items as $item) {
                        $this->writeCapacity(
                            $location,
                            $day,
                            (int) $item->menu_id,
                            $byItemId[(int) $item->id] ?? null,
                            $intent['actor'],
                        );
                    }
                });

                return [
                    'data' => $this->stockProjection($location, $day, $model, $capacityTotal, $byItemId),
                ];
            },
        );
    }

    // ── Kopyalama ─────────────────────────────────────────────────────────

    /**
     * `POST /days/{date}/duplicate` — günü başka güne kopyalar.
     *
     * Haftalık menü kuran yönetici için tek gerçek zaman kazancı budur.
     * Hedef HER ZAMAN taslak doğar, kaynak yayında olsa bile: yedi günü
     * kopyalayan yönetici yedi günü satışa çıkarmış olmamalı.
     *
     * `image_path` ve `internal_note` TAŞINMAZ — ikisi de güne özgü;
     * kopyalamak yanlış fotoğrafı yayınlatırdı. Tavanlar taşınır,
     * SAYAÇLAR taşınmaz: hedef günün `sold`/`reserved` değeri sıfırdan
     * başlar, çünkü o güne henüz kimse sipariş vermedi.
     */
    public function duplicate(Request $request, string $date): JsonResponse
    {
        $location = $this->location($request);
        $sourceDate = $this->parseDate($date, 'date');
        $source = $this->requireDay($location, $sourceDate);

        $data = $request->validate([
            'target_date' => ['required', 'string'],
            'overwrite' => ['sometimes', 'boolean'],
        ]);

        $targetDate = $this->parseDate((string) $data['target_date'], 'target_date');
        $overwrite = (bool) ($data['overwrite'] ?? false);

        if ($targetDate->isSameDay($sourceDate)) {
            throw ApiException::validationFailed(
                'Bir gün kendi üzerine kopyalanamaz.',
                ['field' => 'target_date', 'target_date' => $targetDate->toDateString()],
            );
        }

        /*
         * Geçmişe kopyalamak, `POST /days`'in reddettiği şeyi arka kapıdan
         * yapmaktır. Sözleşme bu kuralı `duplicate` altında ayrıca
         * yazmıyor ama iki uç da aynı şeyi —yeni bir gün— üretiyor.
         */
        if ($targetDate->lessThan($this->today())) {
            throw ApiException::validationFailed(
                'Geçmiş bir güne kopyalanamaz.',
                ['field' => 'target_date', 'target_date' => $targetDate->toDateString()],
            );
        }

        $existing = $this->findDay($location, $targetDate);

        return $this->write(
            $request,
            'menu.duplicate',
            ControlAudit::TARGET_DAILY_MENU,
            // Hedef gün henüz yoksa kimlik yok; denetim sorusu "bu gün
            // nereden geldi" biçiminde sorulduğu için kaynak yükte durur.
            $existing instanceof DailyMenu ? (int) $existing->id : null,
            [
                'source_date' => $sourceDate->toDateString(),
                'target_date' => $targetDate->toDateString(),
                'overwrite' => $overwrite,
            ],
            function () use ($source, $sourceDate, $targetDate, $existing, $overwrite): array {
                $this->assertCopyable($existing, $overwrite, $targetDate);

                return [
                    'action' => 'menu.duplicate',
                    'source_date' => $sourceDate->toDateString(),
                    'target_date' => $targetDate->toDateString(),
                    'item_count' => $source->items->count(),
                    'status' => DailyMenu::STATUS_DRAFT,
                    'overwrites_existing' => $existing instanceof DailyMenu,
                ];
            },
            function (array $intent) use ($location, $source, $sourceDate, $targetDate, $existing, $overwrite): array {
                $this->assertCopyable($existing, $overwrite, $targetDate);

                $target = DB::transaction(
                    fn(): DailyMenu => $this->copyInto($location, $source, $sourceDate, $targetDate, $intent['actor']),
                );

                return [
                    'data' => [
                        'source_date' => $sourceDate->toDateString(),
                        'target_date' => $targetDate->toDateString(),
                        'id' => (int) $target->id,
                        'item_count' => $source->items->count(),
                        'status' => DailyMenu::STATUS_DRAFT,
                    ],
                ];
            },
        );
    }

    // ── Ön denetimler ─────────────────────────────────────────────────────

    /** @throws ApiException */
    private function assertPublishable(DailyMenu $menu, Carbon $date): void
    {
        if ($menu->isPublished()) {
            throw $this->conflict('Bu gün zaten yayında.', [
                'conflict' => 'status',
                'status' => (string) $menu->status,
            ]);
        }

        if ($menu->items->isEmpty()) {
            throw ApiException::validationFailed(
                'Kalemi olmayan bir gün yayınlanamaz.',
                ['date' => $date->toDateString(), 'item_count' => 0],
            );
        }

        /*
         * Paket de kapalı, kalemler de kapalıysa o gün HİÇBİR ŞEY
         * satılamaz. Böyle bir günü yayınlamak, müşteriye açıkken boş
         * duran bir vitrin göstermektir.
         */
        if (!$menu->sellsPackage() && !$menu->components_sellable) {
            throw ApiException::validationFailed(
                'Paket fiyatı yoksa kalemlerin tek tek satışı açık olmalı.',
                ['date' => $date->toDateString(), 'components_sellable' => false],
            );
        }

        $ids = $menu->items->map(static fn(DailyMenuItem $item): int => (int) $item->menu_id)->all();

        $available = Menu::query()
            ->whereIn('menu_id', $ids)
            ->where('menu_status', 1)
            ->pluck('menu_id')
            ->map(intval(...))
            ->all();

        foreach ($ids as $menuId) {
            if (!in_array($menuId, $available, true)) {
                /*
                 * Satıştan kaldırılmış bir ürünü içeren menüyü yayınlamak,
                 * sepete eklenemeyecek bir menü yayınlamaktır: müşteri
                 * görür, seçer, `LineResolver` reddeder.
                 */
                throw ApiException::itemUnavailable(
                    'Menüdeki bir ürün satışta değil; önce ürünü açın ya da kalemi çıkarın.',
                    $menuId,
                );
            }
        }
    }

    /** @throws ApiException */
    private function assertUnpublishable(Location $location, Carbon $date, DailyMenu $menu): void
    {
        if (!$menu->isPublished()) {
            throw $this->conflict('Bu gün zaten taslak.', [
                'conflict' => 'status',
                'status' => (string) $menu->status,
            ]);
        }

        $orders = $this->orderCount($location, $date);

        if ($orders > 0) {
            throw $this->conflict(
                'Bu güne sipariş girmiş; menü taslağa çekilemez.',
                ['conflict' => 'orders', 'order_count' => $orders],
            );
        }
    }

    /** @throws ApiException */
    private function assertDeletable(Location $location, Carbon $date, DailyMenu $menu): void
    {
        if ($menu->isPublished()) {
            throw $this->conflict(
                'Yayındaki bir gün silinemez; önce taslağa çekin.',
                ['conflict' => 'status', 'status' => (string) $menu->status],
            );
        }

        $orders = $this->orderCount($location, $date);

        if ($orders > 0) {
            /*
             * Siparişi olan bir günün menüsünü silmek, siparişin neye
             * karşılık geldiğini kaybetmektir.
             */
            throw $this->conflict(
                'Bu güne sipariş girmiş; menü silinemez.',
                ['conflict' => 'orders', 'order_count' => $orders],
            );
        }
    }

    /** @throws ApiException */
    private function assertItemAbsent(DailyMenu $menu, int $menuId): void
    {
        if ($menu->itemFor($menuId) instanceof DailyMenuItem) {
            /*
             * Tekil indeks (`veykemtu_daily_menu_item_essiz`) zaten
             * engelliyor; burada önden bakmanın sebebi hatayı 409'a
             * çevirmek — veritabanı ihlali 500 olarak görünürdü ve ekran
             * "sunucu hatası" derdi.
             */
            throw $this->conflict('Bu ürün menüde zaten var.', [
                'conflict' => 'menu_id',
                'menu_id' => $menuId,
            ]);
        }
    }

    /** @throws ApiException */
    private function assertItemUnused(Location $location, Carbon $date, DailyMenuItem $item): void
    {
        $orders = $this->itemOrderCount($location, $date, (int) $item->menu_id);

        if ($orders > 0) {
            throw $this->conflict(
                'Bu kalem o günün siparişlerinde kullanılmış; listeden çıkarılamaz.',
                ['conflict' => 'orders', 'order_count' => $orders],
            );
        }
    }

    /** @throws ApiException */
    private function assertCopyable(?DailyMenu $existing, bool $overwrite, Carbon $target): void
    {
        if (!$existing instanceof DailyMenu) {
            return;
        }

        if (!$overwrite) {
            throw $this->conflict(
                'Hedef günde zaten bir menü var. Üzerine yazmak için onaylayın.',
                ['conflict' => 'target_date', 'target_date' => $target->toDateString()],
            );
        }

        if ($existing->isPublished()) {
            throw $this->conflict(
                'Yayındaki bir günün üzerine kopyalanamaz; önce taslağa çekin.',
                ['conflict' => 'status', 'status' => (string) $existing->status],
            );
        }
    }

    /**
     * Kesim saati geçmiş bir günün FİYATI değiştirilemez.
     *
     * O gün için sipariş kapandı ve girmiş siparişler eski fiyattan;
     * fiyatı değiştirmek satılanı değiştirmez, yalnız raporları bozardı.
     * Kapı FİYATA özgü: kesim saati geçmiş bir günün iç notunu düzeltmek
     * ya da başlığındaki yazım hatasını gidermek kimseye zarar vermiyor ve
     * engellenmesi yöneticiyi veritabanına iterdi.
     *
     * "Geçti mi" kararı `OrderingWindow`'da: günün kendi saati, yoksa
     * vitrinin genel saati. Burada tekrar hesaplansaydı panel ile müşteri
     * ucu farklı anlarda kapanırdı.
     *
     * @param  array<string, mixed>  $data
     *
     * @throws ApiException
     */
    private function assertPriceEditable(Location $location, Carbon $date, array $data): void
    {
        if (!array_key_exists('package_price_kurus', $data)) {
            return;
        }

        if ($this->window->isPastCutoff($location, $date)) {
            throw $this->conflict(
                'Bu günün sipariş kabul saati doldu; paket fiyatı artık değiştirilemez.',
                ['conflict' => 'cutoff', 'date' => $date->toDateString()],
            );
        }
    }

    // ── Yazma yardımcıları ────────────────────────────────────────────────

    /**
     * Bir günün/kalemin tavanını yazar. SAYAÇLARA DOKUNMAZ.
     *
     * `null` = tavan yok ve bunun tek ifadesi SATIRI SİLMEKTİR
     * ("satır yoksa sınırsız", `DailyStock`). Bedeli, o satırdaki
     * `sold`/`reserved` sayaçlarının da gitmesi: tavan sonradan yeniden
     * konursa sayım sıfırdan başlar. Alternatifi —tavanı devasa bir sayıya
     * çekmek— "sınırsız" ile "çok yüksek tavan"ı karıştırırdı ve
     * `remaining` alanı `null` yerine anlamsız bir sayı dönerdi. Sınır
     * rapora yazıldı.
     *
     * Düşüm (satış) BURADAN GEÇMEZ: yarış koşulunu kapatan tek koşullu
     * `UPDATE` `DailyStock` içinde ve orada kalmalı.
     */
    private function writeCapacity(
        Location $location,
        Carbon $date,
        int $menuId,
        ?int $capacity,
        string $actor,
    ): void {
        $query = DailyMenuStock::query()
            ->where('location_id', (int) $location->location_id)
            ->whereDate('service_date', $date->toDateString())
            ->where('menu_id', $menuId);

        if ($capacity === null) {
            $query->delete();

            return;
        }

        $row = $query->first();

        if (!$row instanceof DailyMenuStock) {
            $row = new DailyMenuStock;
            $row->location_id = (int) $location->location_id;
            $row->service_date = $date->toDateString();
            $row->menu_id = $menuId;
            $row->reserved = 0;
            $row->sold = 0;
        }

        $row->capacity = $capacity;
        $row->updated_by = mb_substr($actor, 0, 120);
        $row->save();
    }

    /**
     * Kaynağı hedefe kopyalar; hedef varsa üzerine yazar.
     *
     * Kalemler SİL-YENİDEN YAZ ile taşınıyor, diff ile değil: kalem
     * satırlarına dışarıdan hiçbir kayıt işaret etmiyor (sipariş satırı
     * `order_menus.bld_daily_menu_id` ile GÜNE bağlanıyor, kaleme değil),
     * yani diff yalnızca fazladan karmaşıklık ve sıra hatası kaynağı olurdu.
     */
    private function copyInto(
        Location $location,
        DailyMenu $source,
        Carbon $sourceDate,
        Carbon $target,
        string $actor,
    ): DailyMenu {
        $day = $this->findDay($location, $target);

        if (!$day instanceof DailyMenu) {
            $day = new DailyMenu;
            $day->location_id = (int) $location->location_id;
            $day->menu_date = $target->toDateString();
        }

        $day->title = $source->title;
        $day->description = $source->description;
        $day->package_price_kurus = $this->nullableInt($source->package_price_kurus);
        $day->components_sellable = (bool) $source->components_sellable;
        $day->cutoff_time = $source->cutoff_time;

        // Hedef HER ZAMAN taslak; `image_path` ve `internal_note` güne özgü
        // olduğu için hiç dokunulmuyor (hedefte varsa korunur).
        $day->status = DailyMenu::STATUS_DRAFT;
        $day->published_at = null;
        $day->published_by = null;
        $day->save();

        DailyMenuItem::query()->where('daily_menu_id', $day->id)->delete();

        foreach ($source->items as $item) {
            $copy = new DailyMenuItem;
            $copy->daily_menu_id = (int) $day->id;
            $copy->menu_id = (int) $item->menu_id;
            $copy->quantity = max(1, (int) $item->quantity);
            $copy->sort_order = (int) $item->sort_order;
            $copy->label = $item->label;
            $copy->price_override_kurus = $this->nullableInt($item->price_override_kurus);
            $copy->is_required = (bool) $item->is_required;
            $copy->sellable_alone = (bool) $item->sellable_alone;
            $copy->save();
        }

        // TAVANLAR taşınır, SAYAÇLAR taşınmaz: hedef güne henüz kimse
        // sipariş vermedi, `writeCapacity()` yeni satırı sıfır sayaçla açar.
        $sourceCapacities = $this->capacityMap($location, $sourceDate);
        $keep = array_map(
            static fn(DailyMenuItem $item): int => (int) $item->menu_id,
            $source->items->all(),
        );
        $keep[] = DailyMenuStock::DAY_TOTAL;

        foreach ($sourceCapacities as $menuId => $capacity) {
            if (in_array((int) $menuId, $keep, true)) {
                $this->writeCapacity($location, $target, (int) $menuId, $capacity, $actor);
            }
        }

        return $day;
    }

    /**
     * Kalem alanlarını gövdeden yazar — yalnız GÖNDERİLENLERİ.
     *
     * `capacity` BURADA DEĞİL: o alan `veykemtu_daily_menu_items`'ta değil,
     * stok tablosunda yaşıyor ve `writeCapacity()` ile yazılıyor.
     *
     * @param  array<string, mixed>  $data
     * @param  array<string, mixed>  $forced  gövdeden bağımsız alanlar
     */
    private function fillItem(DailyMenuItem $item, array $data, array $forced = []): DailyMenuItem
    {
        foreach ($forced as $column => $value) {
            $item->{$column} = $value;
        }

        if (array_key_exists('quantity', $data)) {
            $item->quantity = max(1, (int) $data['quantity']);
        }

        if (array_key_exists('sort_order', $data) && !array_key_exists('sort_order', $forced)) {
            $item->sort_order = (int) $data['sort_order'];
        }

        if (array_key_exists('label', $data)) {
            $item->label = $this->trimmedOrNull($data['label']);
        }

        if (array_key_exists('price_override_kurus', $data)) {
            $item->price_override_kurus = $this->nullableInt($data['price_override_kurus']);
        }

        if (array_key_exists('is_required', $data)) {
            $item->is_required = (bool) $data['is_required'];
        }

        if (array_key_exists('sellable_alone', $data)) {
            $item->sellable_alone = (bool) $data['sellable_alone'];
        }

        // Varsayılanlar YALNIZ yeni satırda: `PATCH` gönderilmeyen alana
        // dokunmamalı ve `exists` bunu ayırt eden tek işaret.
        if (!$item->exists) {
            $item->quantity ??= 1;
            $item->sort_order ??= 0;
            $item->is_required ??= true;
            $item->sellable_alone ??= true;
        }

        return $item;
    }

    /**
     * `PATCH /days/{date}` gövdesini kolon → değer haritasına çevirir.
     *
     * `array_key_exists` şart: `null` gönderilen alan TEMİZLENİR,
     * gönderilmeyen alan DEĞİŞMEZ. `??` ile yazılsaydı ikisi aynı şey
     * olurdu ve yönetici bir notu asla silemezdi.
     *
     * `capacity_total` burada YOK — kolon değil, stok satırı.
     *
     * @param  array<string, mixed>  $data
     * @return array<string, mixed>
     */
    private function dayChanges(array $data): array
    {
        $changes = [];

        foreach (['title', 'description', 'internal_note', 'image_path'] as $field) {
            if (array_key_exists($field, $data)) {
                $changes[$field] = $this->trimmedOrNull($data[$field]);
            }
        }

        if (array_key_exists('package_price_kurus', $data)) {
            $changes['package_price_kurus'] = $this->nullableInt($data['package_price_kurus']);
        }

        if (array_key_exists('components_sellable', $data)) {
            $changes['components_sellable'] = (bool) $data['components_sellable'];
        }

        if (array_key_exists('cutoff_time', $data)) {
            $changes['cutoff_time'] = $this->trimmedOrNull($data['cutoff_time']);
        }

        return $changes;
    }

    /**
     * `PUT stock` gövdesini kalem kimliği → tavan haritasına çevirir.
     *
     * Listede hiç geçmeyen kalemin tavanı `null`'a düşer; bu ucun "tam
     * liste" olmasının bütün anlamı bu.
     *
     * @param  list<array<string, mixed>>  $rows
     * @return array<int, int|null>
     *
     * @throws ApiException
     */
    private function itemCapacities(DailyMenu $menu, array $rows): array
    {
        $known = $menu->items->map(static fn(DailyMenuItem $item): int => (int) $item->id)->all();
        $capacities = [];

        foreach ($rows as $row) {
            $id = (int) $row['item_id'];

            if (!in_array($id, $known, true)) {
                throw ApiException::validationFailed(
                    'Bu kalem o güne ait değil.',
                    ['field' => 'items.item_id', 'item_id' => $id],
                );
            }

            $capacities[$id] = $this->nullableInt($row['capacity'] ?? null);
        }

        return $capacities;
    }

    private function nextSortOrder(DailyMenu $menu): int
    {
        return (int) $menu->items->max('sort_order') + self::SORT_STEP;
    }

    // ── Okuma yardımcıları ────────────────────────────────────────────────

    /** @return array<string, mixed> */
    private function dayPayload(Location $location, DailyMenu $menu): array
    {
        $date = $menu->menu_date->toDateString();
        $soldOut = $this->soldOutMenuIds($date);
        $capacities = $this->capacityMap($location, $menu->menu_date);

        return [
            'id' => (int) $menu->id,
            'location_id' => (int) $menu->location_id,
            'date' => $date,
            'title' => $menu->title,
            'description' => $menu->description,
            // Müşteriye GİTMEZ; panelin kendi notu.
            'internal_note' => $menu->internal_note,
            'package_price_kurus' => $this->nullableInt($menu->package_price_kurus),
            'components_sellable' => (bool) $menu->components_sellable,
            'status' => (string) $menu->status,
            'cutoff_time' => self::hhmm($menu->cutoff_time),
            'capacity_total' => $capacities[DailyMenuStock::DAY_TOTAL] ?? null,
            'image_path' => $menu->image_path,
            // Kalemlerin tek tek toplamı sunucuda: "paketle şu kadar
            // avantaj" cümlesini kuran istemci çıkarma yapmasın.
            'items_total_kurus' => $menu->itemsTotalKurus(),
            'published_at' => self::ts($menu->published_at),
            'created_at' => self::ts($menu->created_at),
            'updated_at' => self::ts($menu->updated_at),
            /*
             * `published_by` / `created_by` DÖNMEZ: bunlar TastyIgniter
             * yönetici kimlikleri ve Kontrol Merkezi kullanıcılarının
             * BLD'de hesabı yok — anlamsız bir sayı gösterirdi. "Kim
             * yayınladı" sorusunun cevabı denetim izidir.
             */
            'items' => $menu->items
                ->map(fn(DailyMenuItem $item): array => [
                    'id' => (int) $item->id,
                    'menu_id' => (int) $item->menu_id,
                    'name' => $item->displayName(),
                    'label' => $item->label,
                    'quantity' => (int) $item->quantity,
                    'sort_order' => (int) $item->sort_order,
                    'price_override_kurus' => $this->nullableInt($item->price_override_kurus),
                    'unit_price_kurus' => $item->effectiveUnitPriceKurus(),
                    'is_required' => (bool) $item->is_required,
                    'sellable_alone' => (bool) $item->sellable_alone,
                    'capacity' => $capacities[(int) $item->menu_id] ?? null,
                    /*
                     * TAVAN DOLMASI İLE TÜKENME AYRI ŞEYLER. Bu alan
                     * MUTFAĞIN elle koyduğu işaret
                     * (`veykemtu_menu_soldout`); tavan dolması otomatik ve
                     * `GET .../stock` içindeki `full` alanında. Bir ürün
                     * tavanı dolmadan da tükenmiş olabilir — malzeme biter.
                     */
                    'sold_out' => in_array((int) $item->menu_id, $soldOut, true),
                ])
                ->values()
                ->all(),
        ];
    }

    /**
     * `GET /days/{date}/stock` gövdesi.
     *
     * `sold` İKİ BİLEŞENLİ ve ikisi AYRI gösteriliyor: abonelikler stoku
     * önce rezerve ediyor (iş kuralı 5, `veykemtu_daily_menu_stock.reserved`)
     * ve yönetici "34 porsiyon kaldı" dediğinde bunun kaçının aboneliğe
     * ayrıldığını bilmeli.
     *
     * @return array<string, mixed>
     */
    private function stockPayload(Location $location, Carbon $date, DailyMenu $menu): array
    {
        $rows = $this->stockRows($location, $date);
        $soldOut = $this->soldOutMenuIds($date->toDateString());

        $items = [];
        $blocking = [];

        foreach ($menu->items as $item) {
            $menuId = (int) $item->menu_id;
            $row = $rows[$menuId] ?? null;

            $items[] = [
                'item_id' => (int) $item->id,
                'menu_id' => $menuId,
                'name' => $item->displayName(),
                ...$this->counters($row),
                'sold_out' => in_array($menuId, $soldOut, true),
            ];

            if ($row instanceof DailyMenuStock && $row->remaining() === 0) {
                $blocking[] = $menuId;
            }
        }

        $dayRow = $rows[DailyMenuStock::DAY_TOTAL] ?? null;

        return [
            'date' => $date->toDateString(),
            'day' => $this->counters($dayRow),
            'items' => $items,
            'blocking' => [
                'day' => $dayRow instanceof DailyMenuStock && $dayRow->remaining() === 0,
                // Tavanı dolmuş ÜRÜN kimlikleri; gün toplamı listeye girmez.
                'items' => $blocking,
            ],
        ];
    }

    /**
     * `PUT /days/{date}/stock` yanıtı — verilen tavanlarla yeniden hesap.
     *
     * Gerçek yazmadan SONRA da, kuru provada da aynı metot çağrılıyor:
     * uyarıların provada gerçek olması sözleşmenin şartı ve iki ayrı
     * hesap yazmak, provanın yanlış söylemesinin en kısa yolu olurdu.
     *
     * @param  array<int, int|null>  $byItemId
     * @return array<string, mixed>
     */
    private function stockProjection(
        Location $location,
        Carbon $date,
        DailyMenu $menu,
        ?int $capacityTotal,
        array $byItemId,
    ): array {
        $rows = $this->stockRows($location, $date);
        $warnings = [];

        $dayRow = $rows[DailyMenuStock::DAY_TOTAL] ?? null;
        $daySold = $this->soldOf($dayRow);
        $day = $this->projected($capacityTotal, $daySold);

        if ($capacityTotal !== null && $daySold > $capacityTotal) {
            $warnings[] = [
                'code' => self::WARN_BELOW_SOLD,
                // Gün toplamı bir kalem değil; kimlik alanı biçimi bozmadan
                // `null` kalıyor.
                'item_id' => null,
                'capacity' => $capacityTotal,
                'sold' => $daySold,
            ];
        }

        $items = [];

        foreach ($menu->items as $item) {
            $itemId = (int) $item->id;
            $capacity = $byItemId[$itemId] ?? null;
            $sold = $this->soldOf($rows[(int) $item->menu_id] ?? null);

            $items[] = [
                'item_id' => $itemId,
                'menu_id' => (int) $item->menu_id,
                ...$this->projected($capacity, $sold),
            ];

            if ($capacity !== null && $sold > $capacity) {
                $warnings[] = [
                    'code' => self::WARN_BELOW_SOLD,
                    'item_id' => $itemId,
                    'capacity' => $capacity,
                    'sold' => $sold,
                ];
            }
        }

        return [
            'date' => $date->toDateString(),
            'day' => $day,
            'items' => $items,
            /*
             * TAVANI SATILANIN ALTINA ÇEKMEK 409 VERMEZ: gerçek hayatta
             * malzeme biter ve yönetici satışı kapatmak ister. Yanıt bunu
             * susarak değil, uyararak söylüyor.
             */
            'warnings' => $warnings,
        ];
    }

    /**
     * Bir stok satırının sayaç görünümü.
     *
     * @return array<string, mixed>
     */
    private function counters(?DailyMenuStock $row): array
    {
        if (!$row instanceof DailyMenuStock) {
            /*
             * SATIR YOK = TAVAN YOK. `remaining` `null` döner ve sıfırla
             * karıştırılmamalı. Sayaçlar da yok: bu tasarımda `sold`
             * yalnız tavanı olan satırlarda tutuluyor, tavansız bir kalem
             * için "kaç sattık" sorusunun cevabı sipariş tablosundadır.
             */
            return [
                'capacity' => null,
                'sold' => 0,
                'sold_orders' => 0,
                'sold_subscriptions' => 0,
                'remaining' => null,
                'full' => false,
            ];
        }

        $orders = (int) $row->sold;
        $subscriptions = (int) $row->reserved;

        return [
            'capacity' => (int) $row->capacity,
            'sold' => $orders + $subscriptions,
            'sold_orders' => $orders,
            // Abonelik porsiyonu satılmadan AYRILIR (`reserved`), ama
            // yöneticinin gözünde kalandan düşmüştür.
            'sold_subscriptions' => $subscriptions,
            'remaining' => $row->remaining(),
            'full' => $row->remaining() === 0,
        ];
    }

    /**
     * Bir satırın tükettiği porsiyon — satış + abonelik rezervasyonu.
     *
     * İkisi TOPLANIYOR çünkü tavanın karşısında ikisi de yer kaplıyor;
     * ayrıştırılmış hâli `counters()` içinde ayrıca dönüyor.
     */
    private function soldOf(?DailyMenuStock $row): int
    {
        return $row instanceof DailyMenuStock
            ? (int) $row->sold + (int) $row->reserved
            : 0;
    }

    /**
     * Verilen tavanla kalan/dolu/aşım üçlüsü.
     *
     * `remaining` NEGATİFE DÜŞMEZ, `0` olur: ekranda "-2 porsiyon kaldı"
     * anlamsız; gerçek bilgi `oversold` bayrağıdır.
     *
     * @return array<string, mixed>
     */
    private function projected(?int $capacity, int $sold): array
    {
        return [
            'capacity' => $capacity,
            'sold' => $sold,
            'remaining' => $capacity === null ? null : max(0, $capacity - $sold),
            'full' => $capacity !== null && $sold >= $capacity,
            'oversold' => $capacity !== null && $sold > $capacity,
        ];
    }

    /**
     * O günün stok satırları — `menu_id => satır`.
     *
     * @return array<int, DailyMenuStock>
     */
    private function stockRows(Location $location, Carbon $date): array
    {
        $rows = [];

        foreach (
            DailyMenuStock::query()
                ->where('location_id', (int) $location->location_id)
                ->whereDate('service_date', $date->toDateString())
                ->get() as $row
        ) {
            $rows[(int) $row->menu_id] = $row;
        }

        return $rows;
    }

    /**
     * O günün tavanları — `menu_id => capacity`.
     *
     * @return array<int, int>
     */
    private function capacityMap(Location $location, Carbon $date): array
    {
        return array_map(
            static fn(DailyMenuStock $row): int => (int) $row->capacity,
            $this->stockRows($location, $date),
        );
    }

    /**
     * Takvim için gün toplamı satırları — tek sorgu.
     *
     * @return array<string, array{capacity: int|null, sold: int, remaining: int|null}>
     */
    private function dayTotals(Location $location, Carbon $from, Carbon $to): array
    {
        $totals = [];

        foreach (
            DailyMenuStock::query()
                ->where('location_id', (int) $location->location_id)
                ->where('menu_id', DailyMenuStock::DAY_TOTAL)
                ->whereBetween('service_date', [$from->toDateString(), $to->toDateString()])
                ->get() as $row
        ) {
            $totals[$row->service_date->toDateString()] = [
                'capacity' => (int) $row->capacity,
                'sold' => (int) $row->sold + (int) $row->reserved,
                'remaining' => $row->remaining(),
            ];
        }

        return $totals;
    }

    /** @return array<string, mixed> */
    private function statusPayload(DailyMenu $menu): array
    {
        return [
            'date' => $menu->menu_date->toDateString(),
            'status' => (string) $menu->status,
            'published_at' => self::ts($menu->published_at),
        ];
    }

    /** @return list<int> */
    private function soldOutMenuIds(string $date): array
    {
        return MenuSoldOut::query()
            ->whereDate('sold_out_on', $date)
            ->pluck('menu_id')
            ->map(intval(...))
            ->values()
            ->all();
    }

    /**
     * Bir güne verilmiş, İPTAL EDİLMEMİŞ sipariş sayısı.
     *
     * İptal edilenler sayılmıyor: durum makinesi iptal edilmiş bir
     * siparişin revizyonuna izin vermiyor, yani o sipariş üzerinden
     * yeniden fiyatlama riski yok. Sayılsaydı tek bir iptal o günü
     * sonsuza kadar kilitlerdi (admin takvim ekranıyla aynı tanım).
     */
    private function orderCount(Location $location, Carbon $date): int
    {
        return DB::table('orders')
            ->leftJoin('statuses', 'statuses.status_id', '=', 'orders.status_id')
            ->where('orders.location_id', (int) $location->location_id)
            ->whereDate('orders.bld_service_date', $date->toDateString())
            ->where(static function ($query): void {
                $query->whereNull('statuses.status_code')
                    ->orWhere('statuses.status_code', '!=', OrderStatusTransition::CANCELLED);
            })
            ->count();
    }

    /** O günün siparişlerinde bu ürünün geçtiği satır sayısı. */
    private function itemOrderCount(Location $location, Carbon $date, int $menuId): int
    {
        return DB::table('order_menus')
            ->join('orders', 'orders.order_id', '=', 'order_menus.order_id')
            ->leftJoin('statuses', 'statuses.status_id', '=', 'orders.status_id')
            ->where('orders.location_id', (int) $location->location_id)
            ->whereDate('orders.bld_service_date', $date->toDateString())
            ->where('order_menus.menu_id', $menuId)
            ->where(static function ($query): void {
                $query->whereNull('statuses.status_code')
                    ->orWhere('statuses.status_code', '!=', OrderStatusTransition::CANCELLED);
            })
            ->count();
    }

    // ── Ortak yardımcılar ─────────────────────────────────────────────────

    /**
     * İsteğin vitrini.
     *
     * `location_id` bugün hiçbir istemcide dolu gelmiyor (Faz 1 tek
     * vitrin) ama sözleşmede BUGÜNDEN var: sonradan eklemek her istemciyi
     * kırardı.
     *
     * SÖZLEŞMEDEN SAPMA — bilinçli ve rapora yazıldı. `docs/control/menu.md`
     * varsayılan için `Location::getDefault()` diyor; o metot iki şey
     * yapıyor ve ikisi de bu uçlara uymuyor:
     *   1. sonucu SINIF DÜZEYİNDE önbelleğe alıyor (`$defaultModels`),
     *   2. varsayılan işaretli kayıt yoksa ilk kaydı BULUP İŞARETLİYOR —
     *      salt okunur bir `GET /calendar` isteği veritabanına yazardı.
     * `SettingsRepository::location()` aynı satırı döndürüyor (tek vitrin,
     * `is_default` önde) ama ek olarak `location_status` şartı koyuyor ve
     * diğer kontrol denetleyicileri de onu kullanıyor; iki yüzeyin farklı
     * vitrin seçmesi sessiz bir tuzak olurdu.
     */
    private function location(Request $request): Location
    {
        $raw = $request->input('location_id');

        if ($raw !== null && $raw !== '') {
            $model = Location::query()->where('location_id', (int) $raw)->first();

            throw_unless($model instanceof Location, ApiException::notFound('Vitrin bulunamadı.'));

            return $model;
        }

        $default = $this->settings->location();

        throw_unless($default instanceof Location, ApiException::serverError(
            'Etkin bir vitrin tanımlı değil. `php artisan veykemtu:setup` çalıştırılmalı.',
        ));

        return $default;
    }

    private function findDay(Location $location, Carbon $date): ?DailyMenu
    {
        return DailyMenu::query()
            // Sıra bağıntının tanımında (`DailyMenu::$relation`); burada
            // tekrarlanmıyor ki iki doğruluk kaynağı olmasın.
            ->with(['items', 'items.menu'])
            ->where('location_id', (int) $location->location_id)
            ->whereDate('menu_date', $date->toDateString())
            ->first();
    }

    /**
     * Günü bulur; yoksa 404.
     *
     * BOŞ GÖVDE DÖNDÜRÜLMÜYOR: "menü yok" ile "boş menü var" ayırt
     * edilemez hâle gelirdi.
     *
     * @throws ApiException
     */
    private function requireDay(Location $location, Carbon $date): DailyMenu
    {
        $day = $this->findDay($location, $date);

        throw_unless($day instanceof DailyMenu, ApiException::notFound(
            $date->locale('tr')->isoFormat('D MMMM YYYY').' için menü bulunamadı.',
        ));

        return $day;
    }

    /** @throws ApiException */
    private function requireItem(DailyMenu $menu, int $itemId): DailyMenuItem
    {
        foreach ($menu->items as $item) {
            if ((int) $item->id === $itemId) {
                return $item;
            }
        }

        throw ApiException::notFound('Menü kalemi bulunamadı.');
    }

    /**
     * Yol parçasındaki tarihi çözer.
     *
     * TAŞMA DENETİMİ ŞART: `createFromFormat('Y-m-d', '2026-02-31')`
     * istisna fırlatmaz, 3 Mart döner. Rota kalıbı (`\d{4}-\d{2}-\d{2}`)
     * o dizeyi geçirir ve sessizce BAŞKA BİR GÜNÜN menüsü düzenlenirdi.
     *
     * @throws ApiException
     */
    private function parseDate(string $value, string $field): Carbon
    {
        $text = trim($value);

        try {
            $parsed = Carbon::createFromFormat('Y-m-d', $text, BusinessTime::ZONE);
        } catch (Throwable) {
            $parsed = false;
        }

        if (!$parsed instanceof Carbon || $parsed->format('Y-m-d') !== $text) {
            throw ApiException::validationFailed(
                'Tarih YYYY-AA-GG biçiminde ve geçerli bir gün olmalı.',
                ['field' => $field, $field => $value],
            );
        }

        return $parsed->startOfDay();
    }

    /**
     * İşletme günü olarak bugün.
     *
     * `Carbon::now()` DEĞİL: depolama zaman dilimi UTC ve gece
     * 00:00–03:00 arasında "bugün" iki zaman diliminde farklı gündür —
     * o saatlerde kurulan bir menü "geçmişe menü kurulamaz" hatası alırdı.
     */
    private function today(): Carbon
    {
        return BusinessTime::now()->startOfDay();
    }

    /**
     * Yazılamaz alanlar gövdede geçiyorsa 422.
     *
     * SESSİZCE YOK SAYMAK DAHA KÖTÜ: `status` gönderip yayına aldığını
     * sanan bir ekran, günü taslakta bırakır ve fark sabah ortaya çıkar.
     *
     * @param  list<string>  $fields
     *
     * @throws ApiException
     */
    private function rejectImmutable(Request $request, array $fields, string $subject): void
    {
        foreach ($fields as $field) {
            if ($request->has($field)) {
                throw ApiException::validationFailed(
                    $subject.' bu alanı güncelleyemez: '.$field.'.',
                    ['field' => $field],
                );
            }
        }
    }

    /**
     * Kalem gövdesinin doğrulama kuralları.
     *
     * `POST /days` içinde `items.*.` önekiyle, `POST /days/{date}/items`
     * içinde öneksiz kullanılıyor — iki yerde iki ayrı kural listesi,
     * birinde unutulan bir sınır demekti.
     *
     * @return array<string, list<string>>
     */
    private function itemRules(string $prefix = ''): array
    {
        return [
            $prefix.'menu_id' => array_values(array_filter([
                'required', 'integer', 'min:1',
                // Tekrar denetimi yalnız listede anlamlı.
                $prefix === '' ? null : 'distinct',
                'exists:menus,menu_id',
            ])),
            $prefix.'quantity' => ['sometimes', 'integer', 'min:1'],
            $prefix.'sort_order' => ['sometimes', 'integer', 'min:0'],
            $prefix.'label' => ['sometimes', 'nullable', 'string', 'max:120'],
            $prefix.'price_override_kurus' => ['sometimes', 'nullable', 'integer', 'min:0'],
            $prefix.'is_required' => ['sometimes', 'boolean'],
            $prefix.'sellable_alone' => ['sometimes', 'boolean'],
            $prefix.'capacity' => ['sometimes', 'nullable', 'integer', 'min:0'],
        ];
    }

    /** @param array<string, mixed> $details */
    private function conflict(string $message, array $details): ApiException
    {
        // `CONFLICT` bilinçli olarak geniş: "zaten var", "durum uygun
        // değil", "bağlı kayıt var" hâllerinde ekranın yapacağı şey aynı —
        // tazele ve tekrar sor. Ayrımı `details.conflict` taşır.
        return new ApiException('CONFLICT', $message, 409, $details);
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
}
