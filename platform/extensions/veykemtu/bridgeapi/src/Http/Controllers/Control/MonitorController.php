<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Control;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Throwable;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ControlAudit;
use Veykemtu\BridgeApi\Models\ErrorEvent;
use Veykemtu\BridgeApi\Models\KitchenDevice;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Kontrol Merkezi — hata olayları ve kasa sağlığı (`docs/control/monitor.md`).
 *
 * Dört bileşenden (KDS kasası, müşteri uygulaması, site, sunucu) gelen
 * olayların tek havuzu. "Bir şey çalışmıyor" şikâyeti geldiğinde bakılacak
 * ilk ekran.
 *
 * BU ALAN KASALARI YÖNETMEZ, yalnız sağlığını OKUR. Ayar, komut ve eşleme
 * `control/kds/*` ailesindedir. Ayrı bir uç olmasının sebebi yetki: izleme
 * ekranı `bld_monitor.view` ile açılıyor ve o yetkiyi taşıyan kişinin cihaz
 * ayarlarını görmesi gerekmiyor. Aynı uca iki yetkiyle bakmak, yetkilerin
 * anlamını silerdi.
 *
 * YENİ DEPOLAMA AÇILMADI: cihaz sağlığı `veykemtu_kitchen_devices`
 * sütunlarından türetiliyor, olaylar `Models\ErrorEvent`'ten okunuyor.
 * Olayları BİLEŞENLER yazıyor (`ErrorEvent::record()`); bu denetleyici
 * yalnız okur ve çözer.
 *
 * ── SÖZLEŞME ADI ↔ TABLO ADI EŞLEMESİ ────────────────────────────────────
 * `docs/control/monitor.md` `veykemtu_monitor_events` ve `code` /
 * `occurrence_count` / `device_id` alanlarını tarif ediyor; toplayıcıyı
 * yazan kulvar tabloyu `veykemtu_error_events` adıyla ve `type` /
 * `occurrences` sütunlarıyla açtı. Eşleme BU SINIFTA, tek yerde yapılıyor:
 * yayınlanmış alan adlarını değiştirmek Kontrol Merkezi ekranını kırardı,
 * başka bir kulvarın tablosunu yeniden adlandırmak ise kulvar dışıdır.
 * `device_id` ve `app_version` sütun olarak YOK; ikisi de `context`
 * içinden okunuyor. `resolve_note` için sütun yok — gerekçe denetim izinde
 * (`monitor.resolve` satırının `reason`'ı) kalıcıdır ve rapora düşülmüştür.
 */
class MonitorController extends ControlController
{
    /**
     * Varsayılan seviye süzgeci — `info` HARİÇ.
     *
     * Bilgi seviyesindeki olaylar sayıca en kalabalık olanlardır ve listeyi
     * doldurup gerçek hataları görünmez kılarlar. İstenirse `level=info` ile
     * açıkça çağrılır.
     */
    private const array DEFAULT_LEVELS = [
        ErrorEvent::LEVEL_WARNING,
        ErrorEvent::LEVEL_ERROR,
        ErrorEvent::LEVEL_CRITICAL,
    ];

    /** `since` verilmezse bakılan pencere. */
    private const int DEFAULT_WINDOW_DAYS = 7;

    /** Kuyruğun "akmıyor" sayıldığı eşik — gösterge panelindeki uyarıyla aynı. */
    public const int STALE_QUEUE_MINUTES = 15;

    // ── GET /events ───────────────────────────────────────────────────────

    public function events(Request $request): JsonResponse
    {
        $request->validate([
            'source' => ['sometimes', 'string', 'max:200'],
            'level' => ['sometimes', 'string', 'max:100'],
            'code' => ['sometimes', 'string', 'max:120'],
            'device_id' => ['sometimes', 'integer'],
            'since' => ['sometimes', 'string', 'max:40'],
            'resolved' => ['sometimes', 'string', 'max:8'],
            'q' => ['sometimes', 'string', 'max:200'],
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ]);

        $page = max(1, (int) $request->query('page', '1'));
        $perPage = min(100, max(1, (int) $request->query('per_page', '25')));

        $query = $this->filtered($request);
        $total = (int) $query->clone()->count();

        $rows = $query->clone()
            // "En son ne oldu" en sık sorulan soru.
            ->orderByDesc('last_seen_at')
            ->orderByDesc('id')
            ->forPage($page, $perPage)
            ->get();

        $devices = $this->deviceNames($rows);

        return $this->json([
            // `context` LİSTEDE DÖNMEZ: sekiz kilobaytlık bağlam
            // nesnelerini yirmi beş satır için taşımak, ekranın hiç
            // göstermediği veriyi yollamak olurdu.
            'data' => $rows->map(fn(ErrorEvent $row): array => $this->eventRow($row, $devices, false))
                ->values()->all(),
            'meta' => [
                'page' => $page,
                'per_page' => $perPage,
                'total' => $total,
                'last_page' => max(1, (int) ceil($total / $perPage)),
                /*
                 * SÜZGEÇTEN BAĞIMSIZ. Panel bunu sekme rozetlerinde
                 * kullanıyor; süzgece göre değişen bir rozet, "error
                 * sekmesinde 2 yazıyor ama açtığımda boş" gibi bir çelişki
                 * üretirdi.
                 */
                'open_counts' => $this->openCounts(),
            ],
            'server_time' => $this->serverTime(),
        ]);
    }

    // ── GET /events/{id} ──────────────────────────────────────────────────

    public function showEvent(int $event): JsonResponse
    {
        $row = $this->findEvent($event);

        /** @var Collection<int, ErrorEvent> $single */
        $single = new Collection([$row]);

        $data = $this->eventRow($row, $this->deviceNames($single), true);

        /*
         * `related` BLOĞU CİHAZIN ŞU ANKİ SAĞLIĞIDIR. Olay 05:12'de
         * kaydedildi, yönetici 09:00'da bakıyor ve asıl merak ettiği "hâlâ
         * bozuk mu" sorusu. Ayrı bir cihaz çağrısı yapmak, ekranın iki
         * isteği sıraya koyması demekti.
         */
        $data['related'] = $this->relatedHealth($this->deviceIdOf($row));

        return $this->json([
            'data' => $data,
            'server_time' => $this->serverTime(),
        ]);
    }

    // ── POST /events/{id}/resolve ─────────────────────────────────────────

    public function resolveEvent(Request $request, int $event): JsonResponse
    {
        $row = $this->findEvent($event);

        $request->validate([
            'note' => ['sometimes', 'nullable', 'string', 'max:500'],
        ]);

        if ($row->resolved_at !== null) {
            // İKİNCİ BİR ÇÖZÜM NOTU, İLKİNİ GİZLERDİ. Olay yeniden
            // açıldıysa `resolved_at` zaten `null` olur ve bu kapı açılır.
            throw new ApiException(
                'CONFLICT',
                'Bu olay zaten çözüldü olarak işaretlenmiş.',
                409,
                ['conflict' => 'already_resolved', 'resolved_at' => self::ts($row->resolved_at)],
            );
        }

        $note = trim((string) $request->input('note', ''));

        return $this->write(
            $request,
            'monitor.resolve',
            ControlAudit::TARGET_MONITOR_EVENT,
            (int) $row->id,
            [
                'code' => $row->type,
                'source' => (string) $row->source,
                'level' => (string) $row->level,
                'device_id' => $this->deviceIdOf($row),
                'occurrence_count' => (int) $row->occurrences,
                /*
                 * ÇÖZÜM NOTU BURADA KALICIDIR. `veykemtu_error_events` bir
                 * `resolve_note` sütunu taşımıyor (tabloyu başka bir kulvar
                 * açtı) ve sütun eklemek kulvar dışı olurdu; not denetim
                 * satırında duruyor ve `GET /audit?target_type=monitor_event`
                 * ile okunabiliyor.
                 */
                'note' => $note === '' ? null : $note,
            ],
            static fn(array $intent): array => [
                'action' => 'monitor.resolve',
                'id' => (int) $row->id,
                'code' => $row->type,
                'resolve_note' => self::composeNote($intent['reason'], $note),
            ],
            function (array $intent) use ($row, $note): array {
                $resolvedAt = BusinessTime::forStorage(Carbon::now());

                $row->resolved_at = $resolvedAt;
                $row->resolved_by = mb_substr($intent['actor'], 0, 120);
                $row->save();

                /*
                 * `reason` ZATEN ZORUNLU ve çözüm notu odur; `note` isteğe
                 * bağlı ikinci cümledir. İkisini birleştirmek, ayrı bir
                 * zorunlu alan istemekten iyi: aynı şeyi iki kez yazdıran
                 * bir form, ikisinin çelişmesiyle biter.
                 */
                return [
                    'data' => [
                        'id' => (int) $row->id,
                        'resolved_at' => self::ts($resolvedAt),
                        'resolved_by_actor' => $intent['actor'],
                        'resolve_note' => self::composeNote($intent['reason'], $note),
                    ],
                ];
            },
        );
    }

    // ── GET /devices ──────────────────────────────────────────────────────

    /**
     * Kasa sağlık özeti — `control/kds/devices` ucunun DAR bir yüzü.
     *
     * Ayar, komut ve eşleme bilgisi taşımaz; yalnız "hangi kasa ne durumda"
     * sorusuna cevap verir.
     */
    public function devices(): JsonResponse
    {
        $rows = $this->deviceRows();

        return $this->json([
            'data' => $rows,
            'meta' => $this->deviceTotals($rows),
            'server_time' => $this->serverTime(),
        ]);
    }

    // ── GET /summary ──────────────────────────────────────────────────────

    public function summary(): JsonResponse
    {
        return $this->json([
            'data' => $this->summaryData(),
            'server_time' => $this->serverTime(),
        ]);
    }

    /**
     * İzleme özetinin hesabı — `GET /summary` ve gösterge paneli ORTAK.
     *
     * `DashboardController` bu metodu çağırıyor, hesabı ikinci kez yazmıyor.
     * İki ekranın aynı duruma bakıp farklı sayı göstermesi, hangisine
     * inanılacağını belirsiz kılardı.
     *
     * @return array<string, mixed>
     */
    public function summaryData(): array
    {
        $devices = $this->deviceRows();
        $deviceTotals = $this->deviceTotals($devices);
        $deviceTotals['queue_oldest_age_minutes'] = $this->oldestQueueAge($devices);

        $open = $this->openCounts();

        return [
            'events' => [
                'open' => $open,
                'open_total' => array_sum($open),
                'critical_open' => $open[ErrorEvent::LEVEL_CRITICAL],
                'last_24h' => $this->levelCounts(
                    static fn(Builder $query): Builder => $query
                        ->where('last_seen_at', '>=', BusinessTime::forStorage(Carbon::now()->subDay())),
                ),
                'oldest_open_at' => self::ts($this->oldestOpenAt()),
                'by_source' => $this->openBySource(),
            ],
            'devices' => $deviceTotals,
            'health' => $this->health($deviceTotals, $open),
        ];
    }

    // ── Olay sorguları ────────────────────────────────────────────────────

    private function findEvent(int $id): ErrorEvent
    {
        $row = ErrorEvent::find($id);

        if ($row === null) {
            throw ApiException::notFound('Hata olayı bulunamadı.');
        }

        return $row;
    }

    /** @return Builder<ErrorEvent> */
    private function filtered(Request $request): Builder
    {
        $query = ErrorEvent::query();

        $sources = $this->csv($request, 'source', ErrorEvent::SOURCES);
        if ($sources !== null) {
            $query->whereIn('source', $sources);
        }

        // Varsayılan `info` HARİÇ; açıkça istenirse gelir.
        $levels = $this->csv($request, 'level', ErrorEvent::LEVELS) ?? self::DEFAULT_LEVELS;
        $query->whereIn('level', $levels);

        if ($request->filled('code')) {
            // Sözleşmedeki `code`, tablodaki `type` sütunudur.
            $query->where('type', trim((string) $request->query('code')));
        }

        if ($request->filled('device_id')) {
            $query->where('context->device_id', (int) $request->query('device_id'));
        }

        $since = $request->filled('since')
            ? $this->moment((string) $request->query('since'))
            : Carbon::now()->subDays(self::DEFAULT_WINDOW_DAYS);

        // `last_seen_at` ÜZERİNDEN, `first_seen_at` değil: üç hafta önce
        // başlamış ama bugün hâlâ tekrarlayan bir hata, bugünün sorunudur.
        $query->where('last_seen_at', '>=', BusinessTime::forStorage($since));

        $resolved = (string) $request->query('resolved', 'false');

        if ($resolved === 'false') {
            $query->whereNull('resolved_at');
        } elseif ($resolved === 'true') {
            $query->whereNotNull('resolved_at');
        } elseif ($resolved !== 'all') {
            throw ApiException::validationFailed(
                'Çözüm süzgeci true, false ya da all olmalı.',
                ['field' => 'resolved'],
            );
        }

        if ($request->filled('q')) {
            $term = '%'.str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], trim((string) $request->query('q'))).'%';

            $query->where(function (Builder $inner) use ($term): void {
                $inner->where('message', 'like', $term)->orWhere('type', 'like', $term);
            });
        }

        return $query;
    }

    /**
     * Virgüllü liste süzgeci — tanınmayan değer sessizce elenmez.
     *
     * Elense, yanlış yazılmış bir kaynak adı süzgeci hiç uygulanmamış gibi
     * gösterir ve yönetici filtrelediğini sanarak tam listeye bakardı.
     *
     * @param  list<string>  $allowed
     * @return list<string>|null
     */
    private function csv(Request $request, string $field, array $allowed): ?array
    {
        if (!$request->filled($field)) {
            return null;
        }

        $values = array_values(array_filter(
            array_map(trim(...), explode(',', (string) $request->query($field))),
        ));

        $unknown = array_values(array_diff($values, $allowed));

        if ($unknown !== []) {
            throw ApiException::validationFailed(
                'Tanınmayan süzgeç değeri.',
                ['field' => $field, 'unknown' => $unknown, 'allowed' => $allowed],
            );
        }

        return $values;
    }

    private function moment(string $value): Carbon
    {
        try {
            return Carbon::parse($value)->utc();
        } catch (Throwable) {
            throw ApiException::validationFailed(
                'Zaman damgası ISO 8601 (UTC) biçiminde olmalı.',
                ['field' => 'since'],
            );
        }
    }

    /**
     * Açık olayların seviye dağılımı.
     *
     * @return array<string, int>
     */
    private function openCounts(): array
    {
        return $this->levelCounts(static fn(Builder $query): Builder => $query);
    }

    /**
     * @param  callable(Builder<ErrorEvent>): Builder<ErrorEvent>  $scope
     * @return array<string, int>
     */
    private function levelCounts(callable $scope): array
    {
        $counts = array_fill_keys(ErrorEvent::LEVELS, 0);

        $rows = $scope(ErrorEvent::query()->whereNull('resolved_at'))
            ->groupBy('level')
            ->selectRaw('level, COUNT(*) AS toplam')
            ->pluck('toplam', 'level');

        foreach ($rows as $level => $total) {
            $counts[(string) $level] = (int) $total;
        }

        return $counts;
    }

    /** @return array<string, int> */
    private function openBySource(): array
    {
        $counts = array_fill_keys(ErrorEvent::SOURCES, 0);

        $rows = ErrorEvent::query()
            ->whereNull('resolved_at')
            ->groupBy('source')
            ->selectRaw('source, COUNT(*) AS toplam')
            ->pluck('toplam', 'source');

        foreach ($rows as $source => $total) {
            $counts[(string) $source] = (int) $total;
        }

        return $counts;
    }

    private function oldestOpenAt(): mixed
    {
        // `first_seen_at` HİÇ DEĞİŞMEZ — "bu ne zamandır oluyor" sorusunun
        // cevabı odur, son görülme değil.
        return ErrorEvent::query()->whereNull('resolved_at')->min('first_seen_at');
    }

    /**
     * Açık `critical` olayın kaynağı SUNUCU mu.
     *
     * `health.status = down` kararının ikinci ayağı: sunucunun kendisi
     * bozuksa kasaların çevrimiçi olması bir şey ifade etmez. Sözleşmedeki
     * `platform` kaynağının tablodaki karşılığı `server`.
     */
    private function hasServerCritical(): bool
    {
        return ErrorEvent::query()
            ->whereNull('resolved_at')
            ->where('level', ErrorEvent::LEVEL_CRITICAL)
            ->where('source', ErrorEvent::SOURCE_SERVER)
            ->exists();
    }

    /**
     * Olayın bağlı olduğu kasa — SÜTUN DEĞİL, `context` içinden.
     *
     * Tabloyu açan kulvar `device_id` sütunu koymadı; kasa istemcisi
     * kimliği `context` içinde yolluyor. Okuma tek yerde yapılıyor ki
     * sütun bir gün eklendiğinde değişecek tek satır burası olsun.
     */
    private function deviceIdOf(ErrorEvent $row): ?int
    {
        $context = $row->context ?? [];
        $id = $context['device_id'] ?? null;

        return is_numeric($id) ? (int) $id : null;
    }

    /**
     * @param  Collection<int, ErrorEvent>  $rows
     * @return array<int, string>
     */
    private function deviceNames(Collection $rows): array
    {
        $ids = [];

        foreach ($rows as $row) {
            $id = $this->deviceIdOf($row);

            if ($id !== null) {
                $ids[$id] = true;
            }
        }

        if ($ids === []) {
            return [];
        }

        return KitchenDevice::query()
            ->whereIn('id', array_keys($ids))
            ->pluck('name', 'id')
            ->map(strval(...))
            ->all();
    }

    /**
     * @param  array<int, string>  $deviceNames
     * @return array<string, mixed>
     */
    private function eventRow(ErrorEvent $row, array $deviceNames, bool $withContext): array
    {
        $context = $row->context ?? [];
        $deviceId = $this->deviceIdOf($row);

        $data = [
            'id' => (int) $row->id,
            'source' => (string) $row->source,
            'level' => (string) $row->level,
            // Sözleşmedeki `code` = tablodaki `type`.
            'code' => $row->type,
            'message' => (string) $row->message,
            'device_id' => $deviceId,
            'device_name' => $deviceId === null ? null : ($deviceNames[$deviceId] ?? null),
            'app_version' => isset($context['app_version']) ? (string) $context['app_version'] : null,
            'occurrence_count' => (int) $row->occurrences,
            'first_seen_at' => self::ts($row->first_seen_at),
            'last_seen_at' => self::ts($row->last_seen_at),
            'resolved_at' => self::ts($row->resolved_at),
            'resolved_by_actor' => $row->resolved_by,
            // SÜTUN YOK: çözüm gerekçesi denetim izinde yaşıyor (sınıf
            // başlığındaki eşleme kutusu). `null` dönmek, olmayan bir metni
            // uydurmaktan dürüsttür.
            'resolve_note' => null,
        ];

        if ($withContext) {
            $data['context'] = $context === [] ? null : $context;
            // `stack` yalnız tekil okumada: liste yanıtına sekiz kilobaytlık
            // yığın izleri koymak, ekranın hiç göstermediği veriyi taşırdı.
            $data['stack'] = $row->stack;
        }

        return $data;
    }

    /** @return array<string, mixed>|null */
    private function relatedHealth(?int $deviceId): ?array
    {
        if ($deviceId === null) {
            return null;
        }

        $device = KitchenDevice::find($deviceId);

        if ($device === null) {
            return null;
        }

        return [
            'device_online' => $this->isOnline($device),
            'device_printer_ok' => $device->printer_ok,
            'queue_pending' => (int) ($device->print_queue_pending ?? 0),
            'queue_failed' => (int) ($device->print_queue_failed ?? 0),
        ];
    }

    // ── Cihaz sağlığı ─────────────────────────────────────────────────────

    /** @return list<array<string, mixed>> */
    private function deviceRows(): array
    {
        $now = Carbon::now();
        $openByDevice = $this->openEventCountsByDevice();

        return KitchenDevice::query()
            ->orderBy('id')
            ->get()
            ->map(function (KitchenDevice $device) use ($now, $openByDevice): array {
                $oldest = $device->queue_oldest_at;
                $id = (int) $device->id;

                return [
                    'device_id' => $id,
                    'name' => (string) $device->name,
                    // `online` SUNUCUNUN KARARIDIR. Kontrol Merkezi kendi
                    // saatiyle hesaplasaydı, saati üç dakika kaymış bir
                    // panelde bütün mutfak çevrimdışı görünürdü.
                    'online' => $this->isOnline($device),
                    'last_seen_at' => self::ts($device->last_seen_at),
                    'app_version' => $device->app_version,
                    // ÜÇ DURUMLU: `null` "bilinmiyor" demektir, `false` değil.
                    'printer_ok' => $device->printer_ok,
                    'sound_ok' => $device->sound_ok,
                    'alarm_muted' => $device->alarm_muted,
                    'queue_pending' => (int) ($device->print_queue_pending ?? 0),
                    'queue_failed' => (int) ($device->print_queue_failed ?? 0),
                    'queue_oldest_at' => self::ts($oldest),
                    /*
                     * EN ÇOK İŞE YARAYAN ALAN. "Kuyrukta 4 iş var" ile
                     * "kuyrukta 4 iş var ve en eskisi 41 dakikadır bekliyor"
                     * arasındaki fark, sahaya gitme kararını değiştirir.
                     * İlki yazıcı meşgulse normaldir, ikincisi kuyruğun
                     * akmadığı anlamına gelir.
                     */
                    'queue_oldest_age_minutes' => $oldest === null
                        ? null
                        : max(0, (int) $oldest->diffInMinutes($now, absolute: true)),
                    'last_error' => $device->last_error,
                    'health_reported_at' => self::ts($device->health_reported_at),
                    // İPTAL EDİLMİŞ CİHAZ LİSTEDE KALIR ("o kasa neredeydi"
                    // sorusunun cevabı listede olmalı) ama sayaçlara girmez.
                    'revoked' => $device->isRevoked(),
                    'open_event_count' => $openByDevice[$id] ?? 0,
                ];
            })
            ->values()
            ->all();
    }

    private function isOnline(KitchenDevice $device): bool
    {
        if ($device->isRevoked() || $device->last_seen_at === null) {
            return false;
        }

        return $device->last_seen_at->greaterThanOrEqualTo(
            Carbon::now()->subMinutes(KitchenDevice::ONLINE_THRESHOLD_MINUTES),
        );
    }

    /**
     * Kasa başına açık olay sayısı — TEK SORGU.
     *
     * Cihaz başına ayrı sorgu açmak, on kasalı bir mutfakta on ek sorgu
     * demekti ve bu uç izleme rozetiyle birlikte yoklanıyor.
     *
     * @return array<int, int>
     */
    private function openEventCountsByDevice(): array
    {
        $counts = [];

        $rows = ErrorEvent::query()
            ->whereNull('resolved_at')
            ->whereNotNull('context')
            ->get(['id', 'context']);

        foreach ($rows as $row) {
            $id = $this->deviceIdOf($row);

            if ($id === null) {
                continue;
            }

            $counts[$id] = ($counts[$id] ?? 0) + 1;
        }

        return $counts;
    }

    /**
     * @param  list<array<string, mixed>>  $rows
     * @return array<string, int>
     */
    private function deviceTotals(array $rows): array
    {
        $live = array_values(array_filter($rows, static fn(array $r): bool => $r['revoked'] === false));

        return [
            'total' => count($rows),
            'online' => count(array_filter($live, static fn(array $r): bool => $r['online'] === true)),
            'revoked' => count($rows) - count($live),
            /*
             * `printer_ok === false` SAYILIR, `null` SAYILMAZ. Hiç sağlık
             * bildirmemiş bir kasa arızalı değil, sessizdir; ikisini
             * toplamak yeni kurulan her kasayı arıza sayacına yazardı.
             */
            'printer_fault' => count(array_filter($live, static fn(array $r): bool => $r['printer_ok'] === false)),
            'queue_pending' => (int) array_sum(array_column($live, 'queue_pending')),
            'queue_failed' => (int) array_sum(array_column($live, 'queue_failed')),
        ];
    }

    /** @param  list<array<string, mixed>>  $rows */
    private function oldestQueueAge(array $rows): ?int
    {
        $ages = array_values(array_filter(
            array_map(
                static fn(array $r): ?int => $r['revoked'] === true ? null : $r['queue_oldest_age_minutes'],
                $rows,
            ),
            static fn(?int $age): bool => $age !== null,
        ));

        return $ages === [] ? null : max($ages);
    }

    /**
     * Sistemin TEK CÜMLELİK HÜKMÜ.
     *
     * Hükmü sunucunun vermesi bilinçli: üç ayrı ekranın (izleme, gösterge
     * paneli, KDS yönetimi) aynı duruma bakıp farklı renk göstermesi, hangi
     * ekrana inanılacağını belirsiz kılardı.
     *
     * @param  array<string, int|null>  $devices
     * @param  array<string, int>  $open
     * @return array{status:string, reasons:list<string>}
     */
    private function health(array $devices, array $open): array
    {
        $reasons = [];

        $live = (int) $devices['total'] - (int) $devices['revoked'];
        $online = (int) $devices['online'];

        if ($live === 0) {
            // Hiç kasa TANIMLI DEĞİL. Sözleşme bunu ayrı bir durum olarak
            // saymıyor ama panelin "kasa yok" ile "kasalar kapalı"yı
            // ayırabilmesi gerekiyor; ayrım `reasons` etiketinde.
            $reasons[] = 'no_device_registered';
        } elseif ($online === 0) {
            $reasons[] = 'no_device_online';
        } elseif ($online < $live) {
            $reasons[] = 'device_offline';
        }

        if ((int) $devices['printer_fault'] > 0) {
            $reasons[] = 'printer_fault';
        }

        if ($open[ErrorEvent::LEVEL_CRITICAL] > 0) {
            $reasons[] = 'critical_event_open';
        }

        $serverCritical = $this->hasServerCritical();

        if ($serverCritical) {
            $reasons[] = 'platform_critical_open';
        }

        $status = $reasons === [] ? 'ok' : 'degraded';

        // `down`: hiçbir kasa çevrimiçi değil VEYA açık `critical` olayın
        // kaynağı sunucunun kendisi. İkisinde de satış fiilen duruyor.
        if ($online === 0 || $serverCritical) {
            $status = 'down';
        }

        return ['status' => $status, 'reasons' => $reasons];
    }

    /** `reason` + isteğe bağlı `note`, tek metin. */
    private static function composeNote(string $reason, string $note): string
    {
        return $note === '' ? $reason : $reason."\n".$note;
    }
}
