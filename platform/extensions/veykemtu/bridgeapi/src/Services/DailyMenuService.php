<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Igniter\Local\Models\Location;
use Illuminate\Support\Carbon;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ClosedDay;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Günün menüsünün tek sahibi — çözme, satılabilirlik kararı, takvim.
 *
 * "Bu güne sipariş verilebilir mi" sorusunun cevabı YALNIZ BURADA verilir.
 * Katalog ucu, takvim ucu ve sipariş oluşturma aynı metodu çağırır; üç ayrı
 * yerde üç ayrı kural yazılsaydı müşteri takvimde açık gördüğü bir güne
 * sipariş verip 422 alırdı ve sebebini anlamazdı.
 *
 * `docs/02-veri-modeli.md` §8, `docs/03-api-sozlesmesi.md` §3.
 */
class DailyMenuService
{
    /** Takvim ucunun kabul ettiği azami aralık. */
    public const int MAX_CALENDAR_DAYS = 92;

    // Sözleşmedeki `DailyMenu.unavailable_reason` değerleri.
    public const string REASON_CLOSED = 'closed_day';

    public const string REASON_NOT_PUBLISHED = 'not_published';

    public const string REASON_CUTOFF = 'cutoff_passed';

    public const string REASON_PAST = 'past';

    public const string REASON_TOO_FAR = 'too_far';

    public function __construct(
        private readonly LocationGate $gate,
    ) {}

    /**
     * Servis gününü çözer.
     *
     * Öncelik: açıkça verilen `service_date` → `requested_at`'in işletme
     * günü → bugün. İkisi birden verilmişse GÜNLERİ AYNI OLMAK ZORUNDA:
     * "cuma menüsünü perşembe 12:00'ye" gibi bir sipariş mutfağın
     * karşılayamayacağı bir şey ve sessizce birini seçmek, hangisini
     * seçtiğimize göre ya yanlış gün pişer ya yanlış saatte gider.
     *
     * @throws ApiException
     */
    public function resolveServiceDate(?string $serviceDate, ?Carbon $requestedAt): Carbon
    {
        $fromRequested = $requestedAt?->copy()->setTimezone(BusinessTime::ZONE)->startOfDay();

        if ($serviceDate === null || trim($serviceDate) === '') {
            return $fromRequested ?? BusinessTime::now()->startOfDay();
        }

        $text = trim($serviceDate);

        try {
            $parsed = Carbon::createFromFormat('Y-m-d', $text, BusinessTime::ZONE);
        } catch (\Throwable) {
            $parsed = false;
        }

        /*
         * TAŞMA DENETİMİ. `createFromFormat('Y-m-d', '2026-02-31')` istisna
         * fırlatmaz, 3 Mart döner. Sessizce başka bir güne sipariş almak,
         * biçim hatası vermekten çok daha kötü: müşteri seçtiğini sanır,
         * yemek başka gün pişer. Geri yazıp karşılaştırmak bunu kapatıyor.
         */
        if (!$parsed instanceof Carbon || $parsed->format('Y-m-d') !== $text) {
            throw ApiException::validationFailed(
                'Servis günü YYYY-AA-GG biçiminde ve geçerli bir tarih olmalı.',
                ['service_date' => $serviceDate],
            );
        }

        $parsed = $parsed->startOfDay();

        if ($fromRequested !== null && !$parsed->isSameDay($fromRequested)) {
            throw ApiException::validationFailed(
                'İstenen teslim zamanı, seçilen servis gününe ait değil.',
                [
                    'service_date' => $parsed->toDateString(),
                    'requested_at' => $fromRequested->toDateString(),
                ],
            );
        }

        return $parsed;
    }

    public function publishedFor(Location $location, Carbon $date): ?DailyMenu
    {
        return DailyMenu::findPublished((int) $location->location_id, $date);
    }

    /**
     * Bir günün satılabilirlik kararı.
     *
     * @return array{menu: DailyMenu|null, closed: bool, closed_note: string|null,
     *               orderable: bool, reason: string|null}
     */
    public function verdict(Location $location, Carbon $date): array
    {
        $date = $date->copy()->startOfDay();
        $today = BusinessTime::now()->startOfDay();

        $closedRow = ClosedDay::query()
            ->whereDate('closed_on', $date->toDateString())
            ->first();

        $menu = $this->publishedFor($location, $date);

        // SIRA ÖNEMLİ: en dıştaki, en kalıcı sebep önce söylenir. Kapalı bir
        // güne "menü yayınlanmamış" demek, yöneticiyi olmayan bir işi
        // yapmaya yönlendirirdi.
        $reason = match (true) {
            $date->lessThan($today) => self::REASON_PAST,

            $date->greaterThan(
                $today->copy()->addDays($this->gate->maxLookaheadDays($location)),
            ) => self::REASON_TOO_FAR,

            /*
             * KAPALI GÜN HER ZAMAN KAZANIR — menü girilmiş olsa bile.
             *
             * Abonelik üretimi ve `Subscription::upcomingServiceDays()` zaten
             * bu tabloya bakıyor; "açık mıyız" sorusunun ikinci bir kaynağı
             * bir gün ilkiyle çelişir ve çeliştiği gün bayram sabahıdır.
             */
            $closedRow !== null => self::REASON_CLOSED,

            $menu === null => self::REASON_NOT_PUBLISHED,

            // Kesim saati YALNIZ gün bugünse geçerli — yarına verilen sipariş
            // bugünün kesim saatinden etkilenmez (`LocationGate` de böyle
            // davranıyor, iki yerde aynı kural).
            $date->isSameDay($today) && $this->cutoffPassed($location) => self::REASON_CUTOFF,

            default => null,
        };

        return [
            'menu' => $menu,
            'closed' => $closedRow !== null,
            'closed_note' => $closedRow?->description,
            'orderable' => $reason === null,
            'reason' => $reason,
        ];
    }

    /**
     * Sipariş için günü doğrular ve menüyü döner.
     *
     * @throws ApiException
     */
    public function assertOrderable(Location $location, Carbon $date): DailyMenu
    {
        $verdict = $this->verdict($location, $date);

        if ($verdict['orderable'] && $verdict['menu'] instanceof DailyMenu) {
            return $verdict['menu'];
        }

        $human = $date->locale('tr')->isoFormat('D MMMM YYYY');

        throw match ($verdict['reason']) {
            self::REASON_CLOSED => ApiException::locationClosed(
                $verdict['closed_note'] !== null
                    ? "{$human} kapalıyız: {$verdict['closed_note']}"
                    : "{$human} kapalıyız.",
            ),
            self::REASON_CUTOFF => ApiException::locationClosed(
                'Bugünün sipariş kabul saati doldu. Yarın için sipariş verebilirsiniz.',
            ),
            self::REASON_PAST => ApiException::validationFailed(
                'Geçmiş bir güne sipariş verilemez.',
                ['service_date' => $date->toDateString(), 'reason' => self::REASON_PAST],
            ),
            self::REASON_TOO_FAR => ApiException::validationFailed(
                'Bu tarih için henüz sipariş alınmıyor.',
                ['service_date' => $date->toDateString(), 'reason' => self::REASON_TOO_FAR],
            ),
            default => ApiException::validationFailed(
                "{$human} için menü yayınlanmadı.",
                ['service_date' => $date->toDateString(), 'reason' => self::REASON_NOT_PUBLISHED],
            ),
        };
    }

    /**
     * Aralıktaki günler — gün seçiciyi çizmek için.
     *
     * YALNIZ menüsü olan ya da kapalı olan günler döner. Doksan günlük boş
     * bir dizi, istemciye "her gün bir şey var" izlenimi verip her günü ayrı
     * sorgulatırdı.
     *
     * @return list<array<string, mixed>>
     *
     * @throws ApiException
     */
    public function calendar(Location $location, Carbon $from, Carbon $to): array
    {
        $from = $from->copy()->startOfDay();
        $to = $to->copy()->startOfDay();

        if ($to->lessThan($from)) {
            throw ApiException::validationFailed(
                'Bitiş günü başlangıçtan önce olamaz.',
                ['from' => $from->toDateString(), 'to' => $to->toDateString()],
            );
        }

        if ($from->diffInDays($to) + 1 > self::MAX_CALENDAR_DAYS) {
            throw ApiException::validationFailed(
                'Takvim aralığı en fazla '.self::MAX_CALENDAR_DAYS.' gün olabilir.',
                ['from' => $from->toDateString(), 'to' => $to->toDateString()],
            );
        }

        // İki toplu sorgu, gün başına sorgu değil: 92 günlük bir aralık
        // aksi hâlde 184 sorgu ederdi.
        $menus = DailyMenu::query()
            ->where('location_id', $location->location_id)
            ->where('status', DailyMenu::STATUS_PUBLISHED)
            ->whereBetween('menu_date', [$from->toDateString(), $to->toDateString()])
            ->get()
            ->keyBy(fn(DailyMenu $menu): string => $menu->menu_date->toDateString());

        $closed = ClosedDay::query()
            ->whereBetween('closed_on', [$from->toDateString(), $to->toDateString()])
            ->get()
            ->keyBy(fn(ClosedDay $day): string => $day->closed_on->toDateString());

        $today = BusinessTime::now()->startOfDay();
        $lastOrderable = $today->copy()->addDays($this->gate->maxLookaheadDays($location));
        $cutoffPassed = $this->cutoffPassed($location);

        $days = [];

        for ($cursor = $from->copy(); $cursor->lessThanOrEqualTo($to); $cursor->addDay()) {
            $key = $cursor->toDateString();
            $menu = $menus->get($key);
            $closedRow = $closed->get($key);

            if ($menu === null && $closedRow === null) {
                continue;
            }

            $orderable = $menu !== null
                && $closedRow === null
                && $cursor->greaterThanOrEqualTo($today)
                && $cursor->lessThanOrEqualTo($lastOrderable)
                && !($cursor->isSameDay($today) && $cutoffPassed);

            $days[] = [
                'date' => $key,
                'has_menu' => $menu !== null,
                'closed' => $closedRow !== null,
                'is_orderable' => $orderable,
                'title' => $menu?->title,
                'package_price' => $menu?->sellsPackage() === true
                    ? (int) $menu->package_price_kurus
                    : null,
                'note' => $closedRow?->description,
            ];
        }

        return $days;
    }

    /** Bugünün kesim saati geçti mi? */
    private function cutoffPassed(Location $location): bool
    {
        $cutoff = $this->gate->orderCutoff($location);

        if ($cutoff === null) {
            return false;
        }

        [$hour, $minute] = array_map(intval(...), explode(':', $cutoff));
        $now = BusinessTime::now();

        return $now->greaterThan($now->copy()->setTime($hour, $minute));
    }
}
