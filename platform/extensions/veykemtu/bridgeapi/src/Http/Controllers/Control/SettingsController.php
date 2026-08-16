<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Control;

use Igniter\Local\Models\Location;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Veykemtu\BridgeApi\Admin\SettingsRepository;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ClosedDay;
use Veykemtu\BridgeApi\Models\ControlAudit;
use Veykemtu\BridgeApi\Services\LocationGate;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Kontrol Merkezi — satış ayarları (`docs/control/settings.md`).
 *
 * DEĞERLERİN TEK KAYNAĞI `LocationGate`'tir ve bu denetleyici oraya
 * DOĞRUDAN gitmez: çeviri `Admin\SettingsRepository` üzerinden yapılır,
 * yani admin panelin "BLD Ayarları" sayfasıyla aynı yoldan. İkinci bir
 * çeviri katmanı yazmak, `location_options` için ikinci bir doğruluk
 * kaynağı açmak olurdu; bir gün panel kuruşa yuvarlarken uç yuvarlamaz ve
 * aynı ayar iki yüzeyde farklı görünürdü.
 *
 * YOĞUNLUK YARIŞI KORUNUYOR. Mutfak kasası da `bld_busy`'yi çeviriyor.
 * Form yüzündeki çözüm `busy_snapshot` gizli alanıydı; burada karşılığı
 * iki katmanlı: `PUT /sales` KISMİ yazar (gönderilmeyen alan değişmez) ve
 * gönderilen değer kayıttakiyle aynıysa `SettingsRepository::planControl()`
 * onu hiç yazmaz. Gerekçenin tamamı `SettingsRepository::applyControl()`
 * sınıf içi yorumundadır.
 *
 * `ordering_enabled` BU UÇTAN YAZILAMAZ ve bu bilinçlidir: şalteri
 * gerekçesiz ve süresiz çevirmek, durdurmanın en sık hatasını (açmayı
 * unutmak) üretirdi. Durdurmanın kendi ucu var ve süre alıyor.
 */
class SettingsController extends ControlController
{
    /** `HH:mm` — gün içi saatler yerel (Europe/Istanbul), an değil. */
    private const string TIME_PATTERN = '/^([01]\d|2[0-3]):[0-5]\d$/';

    /** `YYYY-MM-DD`. */
    private const string DATE_PATTERN = '/^\d{4}-\d{2}-\d{2}$/';

    /**
     * Durdurmanın azami süresi.
     *
     * Daha uzunu "süreli" değil kapanıştır ve `until: null` ile ifade
     * edilmelidir. Sınır olmasaydı yanlışlıkla girilen bir yıl, dükkânı
     * kimsenin fark etmediği bir süre kapalı tutardı.
     */
    private const int MAX_PAUSE_DAYS = 30;

    /** Kapalı gün listesinin varsayılan penceresi. */
    private const int CLOSED_DAY_WINDOW_DAYS = 365;

    public function __construct(private readonly SettingsRepository $settings) {}

    // ── Satış ayarları ────────────────────────────────────────────────────

    public function sales(Request $request): JsonResponse
    {
        $location = $this->location($request);

        return $this->json([
            'data' => $this->settings->toControlData($location),
            'meta' => [
                'available_payment_methods' => LocationGate::ALL_PAYMENT_METHODS,
                'defaults' => $this->settings->controlDefaults(),
            ],
            'server_time' => $this->serverTime(),
        ]);
    }

    /**
     * Ayarları KISMİ yazar — gönderilmeyen alan değişmez.
     *
     * `PUT` adı seçildi çünkü niyet "ayar tablosunun bu alanları şu hâle
     * gelsin"dir. `PATCH` ile davranış farkı yok; tek metot tanımlamak,
     * ikisini farklı sanan bir istemci yazılmasını önlüyor.
     */
    public function updateSales(Request $request): JsonResponse
    {
        $location = $this->location($request);

        $this->rejectReadOnlyFields($request);
        $this->rejectPendingFields($request);

        $request->validate([
            // `nullable` = "kesim saati yok"; biçim tutmuyorsa 422.
            'order_cutoff' => ['sometimes', 'nullable', 'string', 'regex:'.self::TIME_PATTERN],
            // `null` KABUL EDİLMEZ: abonelik siparişlerinin KDS'e hiç
            // düşmediği bir yapılandırma, mutfağın sabah boş ekrana
            // bakması demektir.
            'subscription_release_time' => ['sometimes', 'required', 'string', 'regex:'.self::TIME_PATTERN],
            // Sıfır GEÇERLİ ("yalnız bugüne sipariş"); tavan iş kararı 3.
            'max_lookahead_days' => ['sometimes', 'integer', 'min:0', 'max:'.SettingsRepository::MAX_LOOKAHEAD_DAYS],
            'min_order_total_kurus' => ['sometimes', 'integer', 'min:0'],
            'delivery_fee_kurus' => ['sometimes', 'integer', 'min:0'],
            // Boş liste, hiçbir ödeme yöntemi olmayan bir satış kanalı
            // demekti — sipariş girilemez ve sebebi ekranda görünmezdi.
            'payment_methods' => ['sometimes', 'array', 'min:1'],
            'payment_methods.*' => ['string', 'distinct', Rule::in(LocationGate::ALL_PAYMENT_METHODS)],
            'busy' => ['sometimes', 'boolean'],
            // Boş dize ya da `null` varsayılana döner.
            'busy_message' => ['sometimes', 'nullable', 'string', 'max:500'],
            /*
             * DAKİKA ALANLARINDA ARALIK DIŞI REDDEDİLİR, DÜZELTİLMEZ.
             * `LocationGate::positiveMinutes()` aralık dışını sessizce
             * varsayılana çeviriyor; bu uç 422 veriyor. Sessizce düzeltilen
             * bir ayar, yöneticinin girdiğini sandığı değerle çalışmadığını
             * hiç öğrenmemesi demektir.
             */
            'prep_minutes' => ['sometimes', 'integer', 'min:1', 'max:480'],
            'delivery_minutes' => ['sometimes', 'integer', 'min:1', 'max:480'],
            'busy_extra_minutes' => ['sometimes', 'integer', 'min:1', 'max:480'],
            'daily_menu_enabled' => ['sometimes', 'boolean'],
            'auto_invoice' => ['sometimes', 'boolean'],
        ]);

        // PLAN BİR KEZ ÇIKARILIYOR ve hem kuru prova hem gerçek yazma onu
        // kullanıyor: "kuru prova geçti ama gönderim başka şey yaptı" hâli
        // böylece oluşamaz.
        $changes = $this->settings->planControl($location, $request->all());

        return $this->write(
            $request,
            'settings.sales',
            ControlAudit::TARGET_SETTINGS,
            (int) $location->location_id,
            // `location_options` GEÇMİŞ TUTMAZ. "Kesim saati ne zaman
            // değişti ve kim değiştirdi" sorusunun cevabı yalnızca bu
            // satırda bulunur.
            ['changes' => $changes],
            static fn(): array => [
                'action' => 'settings.sales',
                'changes' => $changes,
            ],
            function () use ($location, $changes): array {
                $this->settings->applyControl($location, $changes);

                return [
                    'data' => $this->settings->toControlData($location),
                    // Yalnız GERÇEKTEN değişenler. Aynı değeri yeniden
                    // yazmak listede görünmez ve denetim izine
                    // "değişiklik yok" olarak düşer.
                    'changed' => array_column($changes, 'field'),
                ];
            },
        );
    }

    // ── Satış şalteri ─────────────────────────────────────────────────────

    /**
     * Satışı durdurur.
     *
     * `busy` İLE KARIŞTIRILMAMALI: `busy` yalnız uyarır, bu satışı
     * gerçekten keser. Süre dolduğunda satış KENDİLİĞİNDEN açılır — arka
     * planda bir iş yok, `LocationGate::orderingEnabled()` okuma anında
     * karşılaştırıyor. Zamanlayıcıya bağlamak, zamanlayıcının çalışmadığı
     * her durumda dükkânın kapalı kalması olurdu.
     */
    public function pause(Request $request): JsonResponse
    {
        $location = $this->location($request);

        $data = $request->validate([
            'until' => ['sometimes', 'nullable', 'date'],
            /*
             * `customer_message` MÜŞTERİYE GÖSTERİLİR, `reason` GÖSTERİLMEZ.
             * İkisinin ayrı olması bilinçli: "buzdolabı arızası" cümlesi
             * denetim izi içindir, müşteriye söylenecek şey değildir.
             */
            'customer_message' => ['sometimes', 'nullable', 'string', 'max:300'],
        ]);

        $until = $this->pauseDeadline($data['until'] ?? null);
        $message = isset($data['customer_message']) && trim((string) $data['customer_message']) !== ''
            ? trim((string) $data['customer_message'])
            : null;

        return $this->write(
            $request,
            'settings.ordering.pause',
            ControlAudit::TARGET_SETTINGS,
            (int) $location->location_id,
            [
                'until' => $until?->toIso8601ZuluString(),
                'has_customer_message' => $message !== null,
            ],
            static fn(): array => [
                'action' => 'settings.ordering.pause',
                'ordering_enabled' => false,
                'paused_until' => $until?->toIso8601ZuluString(),
                'pause_reason' => $message,
            ],
            function () use ($location, $until, $message): array {
                // ZATEN DURDURULMUŞSA ÜZERİNE YAZILIR, 409 VERİLMEZ:
                // süreyi uzatmak olağan bir eylemdir.
                $this->settings->pauseOrdering($location, $until, $message);

                return ['data' => $this->orderingState($location)];
            },
        );
    }

    /** Satışı açar; durdurma izlerini temizler. Zaten açıksa da `ok`. */
    public function resume(Request $request): JsonResponse
    {
        $location = $this->location($request);

        return $this->write(
            $request,
            'settings.ordering.resume',
            ControlAudit::TARGET_SETTINGS,
            (int) $location->location_id,
            [],
            static fn(): array => [
                'action' => 'settings.ordering.resume',
                'ordering_enabled' => true,
            ],
            function () use ($location): array {
                $this->settings->resumeOrdering($location);

                return ['data' => $this->orderingState($location)];
            },
        );
    }

    // ── Kapalı günler ─────────────────────────────────────────────────────

    /**
     * Resmî tatil ve planlı kapanışlar. **Global** — vitrin ayrımı yok.
     *
     * Varsayılan pencere bugünden itibaren bir yıl. Geçmiş kapalı günleri
     * varsayılan olarak döndürmek, listeyi her yıl biraz daha uzatırdı.
     */
    public function closedDays(Request $request): JsonResponse
    {
        $request->validate([
            'from' => ['sometimes', 'string', 'regex:'.self::DATE_PATTERN],
            'to' => ['sometimes', 'string', 'regex:'.self::DATE_PATTERN],
        ]);

        $from = $request->filled('from')
            ? $this->parseDate((string) $request->query('from'), 'from')
            : BusinessTime::now()->startOfDay();

        $to = $request->filled('to')
            ? $this->parseDate((string) $request->query('to'), 'to')
            : $from->copy()->addDays(self::CLOSED_DAY_WINDOW_DAYS);

        if ($to->lessThan($from)) {
            throw ApiException::validationFailed(
                'Bitiş günü başlangıçtan önce olamaz.',
                ['field' => 'to'],
            );
        }

        $rows = ClosedDay::query()
            ->whereDate('closed_on', '>=', $from->toDateString())
            ->whereDate('closed_on', '<=', $to->toDateString())
            ->orderBy('closed_on')
            ->get()
            ->map(static fn(ClosedDay $day): array => [
                'id' => (int) $day->id,
                'date' => Carbon::parse($day->closed_on)->toDateString(),
                'description' => $day->description !== null ? (string) $day->description : null,
            ])
            ->all();

        return $this->json([
            'data' => $rows,
            // SAYFALAMA YOK: bir yılda en çok birkaç düzine gün olur.
            // `meta` yalnız pencereyi taşıyor; `page`/`per_page`/`total`
            // dörtlüsü bilerek yok, boş bir sayfalayıcı çizdirmesin.
            'meta' => ['from' => $from->toDateString(), 'to' => $to->toDateString()],
            'server_time' => $this->serverTime(),
        ]);
    }

    public function storeClosedDay(Request $request): JsonResponse
    {
        $data = $request->validate([
            'date' => ['required', 'string', 'regex:'.self::DATE_PATTERN],
            // Kolon sınırı 160; taşan metin kırpılmaz, 422 alır.
            'description' => ['sometimes', 'nullable', 'string', 'max:160'],
        ]);

        $date = $this->parseDate((string) $data['date'], 'date');
        $description = isset($data['description']) && trim((string) $data['description']) !== ''
            ? trim((string) $data['description'])
            : null;

        if (ClosedDay::whereDate('closed_on', $date->toDateString())->exists()) {
            throw new ApiException(
                'CONFLICT',
                'Bu gün zaten kapalı olarak işaretli.',
                409,
                ['conflict' => 'date', 'date' => $date->toDateString()],
            );
        }

        /*
         * GEÇMİŞ TARİH KABUL EDİLİR. Yönetici geçmiş bir günü sonradan
         * kapalı işaretleyebilmeli (rapor tutarlılığı). O güne sipariş
         * girilmişse engel çıkmaz, yalnız `warnings` taşır: engellemek,
         * olmuş bir şeyi kayda geçirmeyi imkânsız kılardı.
         */
        $warnings = $this->closedDayWarnings($date);

        return $this->write(
            $request,
            'settings.closed_day.create',
            ControlAudit::TARGET_CLOSED_DAY,
            null,
            ['date' => $date->toDateString(), 'description' => $description],
            static fn(): array => [
                'action' => 'settings.closed_day.create',
                'date' => $date->toDateString(),
                'description' => $description,
                'warnings' => $warnings,
            ],
            function () use ($date, $description, $warnings): array {
                $day = new ClosedDay;
                $day->closed_on = $date->toDateString();
                $day->description = $description;
                $day->save();

                return [
                    'data' => [
                        'id' => (int) $day->id,
                        'date' => $date->toDateString(),
                        'description' => $description,
                    ],
                    'warnings' => $warnings,
                ];
            },
        );
    }

    /**
     * Kapalı günü kaldırır.
     *
     * YOL PARÇASI TARİHTİR, KİMLİK DEĞİL: `closed_on` tekil ve yönetici
     * takvimden bir güne tıklıyor.
     *
     * SİLME GERÇEK SİLMEDİR. Kapalı gün bir belge değil bir kuraldır;
     * iptal edilmiş bir kuralın "iptal edilmiş" hâlini saklamak, üretim
     * sorgularının her seferinde bir bayrak daha kontrol etmesi demekti.
     * Kaydın tarihçesi denetim izindedir.
     */
    public function destroyClosedDay(Request $request, string $date): JsonResponse
    {
        $day = ClosedDay::query()
            ->whereDate('closed_on', $this->parseDate($date, 'date')->toDateString())
            ->first();

        // "ZATEN ÖYLE" HOŞGÖRÜSÜ YOK: var olmayan bir tatili silmeye
        // çalışan yönetici muhtemelen yanlış tarihe bakıyor ve bunu
        // bilmeli.
        if ($day === null) {
            throw ApiException::notFound('Bu gün kapalı olarak işaretli değil.');
        }

        $dateString = Carbon::parse($day->closed_on)->toDateString();
        $id = (int) $day->id;

        return $this->write(
            $request,
            'settings.closed_day.delete',
            ControlAudit::TARGET_CLOSED_DAY,
            $id,
            ['date' => $dateString],
            static fn(): array => [
                'action' => 'settings.closed_day.delete',
                'date' => $dateString,
                'deleted' => true,
            ],
            static function () use ($day, $dateString): array {
                $day->delete();

                return ['data' => ['deleted' => true, 'date' => $dateString]];
            },
        );
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    /**
     * İsteğin hedeflediği vitrin.
     *
     * `location_id` verilmezse varsayılan vitrin — `SettingsRepository`
     * ile AYNI seçim (`is_default` önce). Ayrı bir sıra kullanmak, aynı
     * ayarı iki yüzeyin farklı vitrinlerde düzenlemesi olurdu.
     *
     * @throws ApiException
     */
    private function location(Request $request): Location
    {
        $id = $request->input('location_id', $request->query('location_id'));

        if ($id === null || $id === '') {
            $location = $this->settings->location();

            if ($location === null) {
                throw ApiException::serverError(
                    'Etkin bir vitrin tanımlı değil. `php artisan veykemtu:setup` çalıştırılmalı.',
                );
            }

            return $location;
        }

        $location = Location::query()->where('location_id', (int) $id)->first();

        if ($location === null) {
            throw ApiException::notFound('Vitrin bulunamadı.');
        }

        return $location;
    }

    /**
     * Yazılamaz alanlar gönderildiğinde 422.
     *
     * SESSİZCE YOK SAYMAK YERİNE REDDEDİLİYOR: `is_open` çalışma
     * saatlerinden türüyor ve `daily_package_menu_id`'yi göç yazıyor —
     * yanlış bir kimlik günün menüsünü sıfır liraya sattırır. Yok sayılan
     * bir alan, panelde "kaydettim ama olmadı" sorusunu doğururdu.
     *
     * @throws ApiException
     */
    private function rejectReadOnlyFields(Request $request): void
    {
        $readOnly = [
            'is_open' => 'Bu alan çalışma saatlerinden türetilir, yazılamaz.',
            'daily_package_menu_id' => 'Paket ürün kimliğini göç yazar, panelden değiştirilemez.',
            'ordering_enabled' => 'Satış şalteri bu uçtan çevrilemez; /ordering/pause ve /ordering/resume kullanılır.',
            'paused_until' => 'Durdurma süresi yalnız /ordering/pause ucundan yazılır.',
            'pause_reason' => 'Durdurma mesajı yalnız /ordering/pause ucundan yazılır.',
        ];

        foreach ($readOnly as $field => $message) {
            if ($request->exists($field)) {
                throw ApiException::validationFailed($message, ['field' => $field]);
            }
        }
    }

    /**
     * Sunucu tarafı henüz hazır olmayan alanlara yazma denemesi → 422.
     *
     * Gerekçe `SettingsRepository::pendingGateFields()` içindedir: yazmayı
     * sessizce yutmak, yöneticinin kaydettiğini sandığı bir ayarın hiç
     * uygulanmaması demekti.
     *
     * @throws ApiException
     */
    private function rejectPendingFields(Request $request): void
    {
        foreach ($this->settings->pendingGateFields() as $field) {
            if ($request->exists($field)) {
                throw ApiException::validationFailed(
                    'Bu ayar sunucu tarafında henüz etkin değil.',
                    ['field' => $field],
                );
            }
        }
    }

    /**
     * Durdurma bitiş anı — `null` = süresiz (elle açılana kadar).
     *
     * @throws ApiException
     */
    private function pauseDeadline(mixed $value): ?Carbon
    {
        if ($value === null || (is_string($value) && trim($value) === '')) {
            return null;
        }

        try {
            $until = Carbon::parse((string) $value)->utc();
        } catch (\Throwable) {
            throw ApiException::validationFailed(
                'Durdurma bitişi ISO 8601 biçiminde olmalı.',
                ['field' => 'until'],
            );
        }

        if ($until->isPast()) {
            throw ApiException::validationFailed(
                'Durdurma bitişi geçmişte olamaz.',
                ['field' => 'until'],
            );
        }

        if ($until->greaterThan(Carbon::now()->utc()->addDays(self::MAX_PAUSE_DAYS))) {
            throw ApiException::validationFailed(
                self::MAX_PAUSE_DAYS.' günden uzun bir durdurma süreli değil kapanıştır;'
                .' süresiz durdurma için `until` boş bırakılır.',
                ['field' => 'until'],
            );
        }

        return $until;
    }

    /** @throws ApiException */
    private function parseDate(string $value, string $field): Carbon
    {
        $text = trim($value);

        try {
            $parsed = Carbon::createFromFormat('Y-m-d', $text, BusinessTime::ZONE);
        } catch (\Throwable) {
            $parsed = false;
        }

        /*
         * TAŞMA DENETİMİ — `DailyMenuService::resolveServiceDate()` ile aynı
         * gerekçe: `createFromFormat('Y-m-d', '2026-02-31')` istisna
         * fırlatmaz, 3 Mart döner. Sessizce başka bir günü kapatmak, biçim
         * hatası vermekten çok daha kötü.
         */
        if (!$parsed instanceof Carbon || $parsed->format('Y-m-d') !== $text) {
            throw ApiException::validationFailed(
                'Tarih YYYY-AA-GG biçiminde ve geçerli bir gün olmalı.',
                ['field' => $field],
            );
        }

        return $parsed->startOfDay();
    }

    /**
     * O güne ait sipariş varsa uyarı üretir — engel değil.
     *
     * @return list<string>
     */
    private function closedDayWarnings(Carbon $date): array
    {
        $count = (int) DB::table('orders')
            ->whereDate('bld_service_date', $date->toDateString())
            ->count();

        if ($count === 0) {
            return [];
        }

        return [
            'Bu güne ait '.$count.' sipariş var; kapalı işaretlemek onları iptal etmez.',
        ];
    }

    /** @return array<string, mixed> */
    private function orderingState(Location $location): array
    {
        $data = $this->settings->toControlData($location);

        return [
            'ordering_enabled' => $data['ordering_enabled'],
            'paused_until' => $data['paused_until'],
            'pause_reason' => $data['pause_reason'],
        ];
    }
}
