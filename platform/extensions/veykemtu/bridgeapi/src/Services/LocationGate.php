<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Igniter\Local\Models\Location;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\BridgeApi\Exceptions\ApiException;

/**
 * Vitrinin sipariş alıp alamayacağını belirleyen tek yer.
 *
 * Üç bağımsız şalter vardır (`docs/03-api-sozlesmesi.md` §3):
 *
 * | Alan | Kim yönetir | Ne demek |
 * |---|---|---|
 * | `is_open` | çalışma saatleri (türetilir) | Şu an sipariş saati içinde miyiz |
 * | `ordering_enabled` | yönetici, elle | Ana şalter — kapalıysa saat uygun olsa bile alınmaz |
 * | `order_cutoff` | yönetici | Günlük son sipariş saati |
 *
 * Üçünü ayrı tutmak, "bugün yoğunuz, sipariş almayı durdur" ile "çalışma
 * saatimiz bitti"yi karıştırmamak içindir; ikincisi yarın kendiliğinden
 * geri açılır, birincisi açılmaz.
 *
 * Değerler TastyIgniter'ın kendi `location_options` tablosunda tutulur —
 * kendi tablomuzu açmaya gerek yok ve admin panelde aynı yerde yaşarlar.
 */
class LocationGate
{
    private const string KEY_ORDERING = 'bld_ordering_enabled';

    private const string KEY_CUTOFF = 'bld_order_cutoff';

    private const string KEY_MIN_TOTAL = 'bld_min_order_total';

    private const string KEY_PAYMENTS = 'bld_payment_methods';

    /** Sözleşmedeki ödeme yöntemleri — `docs/openapi.yaml` `PaymentMethod`. */
    public const array ALL_PAYMENT_METHODS = ['online', 'cash', 'account'];

    /**
     * Faz 1 varsayılanı: online kapalı.
     *
     * Sanal POS (Kuveyt Türk) sağlayıcı sözleşmesi tamamlanınca yalnızca bu
     * liste değişir — istemci sürümü değişmez (`docs/03` §4).
     */
    public const array DEFAULT_PAYMENT_METHODS = ['cash', 'account'];

    /** Çalışma saatlerinden türetilir. */
    public function isOpen(Location $location): bool
    {
        // TastyIgniter'ın çalışma takvimi tanımlı değilse vitrin "açık"
        // sayılır: saat tanımlamamış bir işletmeyi kapalı göstermek,
        // kurulumun ilk gününde tüm siparişleri reddederdi.
        try {
            return $location->newWorkingSchedule('opening')->isOpen();
        } catch (\Throwable) {
            return true;
        }
    }

    public function orderingEnabled(Location $location): bool
    {
        return (bool) $this->option($location, self::KEY_ORDERING, true);
    }

    public function setOrderingEnabled(Location $location, bool $enabled): void
    {
        $this->setOption($location, self::KEY_ORDERING, $enabled);
    }

    /** `HH:mm` veya `null`. */
    public function orderCutoff(Location $location): ?string
    {
        $value = $this->option($location, self::KEY_CUTOFF, null);

        return is_string($value) && preg_match('/^([01]\d|2[0-3]):[0-5]\d$/', $value) === 1
            ? $value
            : null;
    }

    public function minOrderTotal(Location $location): int
    {
        return (int) $this->option($location, self::KEY_MIN_TOTAL, 0);
    }

    /** @return list<string> */
    public function paymentMethods(Location $location): array
    {
        $value = $this->option($location, self::KEY_PAYMENTS, self::DEFAULT_PAYMENT_METHODS);

        if (!is_array($value) || $value === []) {
            return self::DEFAULT_PAYMENT_METHODS;
        }

        return array_values(array_intersect(
            array_map(strval(...), $value),
            self::ALL_PAYMENT_METHODS,
        ));
    }

    /**
     * Sipariş kabul edilebilir mi? Edilemiyorsa gerekçesiyle patlar.
     *
     * @throws ApiException
     */
    public function assertAcceptsOrder(Location $location, ?Carbon $requestedAt): void
    {
        if (!$this->orderingEnabled($location)) {
            throw ApiException::locationClosed(
                'Şu anda sipariş alınmıyor. Lütfen daha sonra tekrar deneyin.',
            );
        }

        if (!$this->isOpen($location)) {
            throw ApiException::locationClosed(
                'Çalışma saatlerimiz dışındasınız.',
            );
        }

        $cutoff = $this->orderCutoff($location);
        if ($cutoff === null) {
            return;
        }

        // Kesim saati **istenen teslim gününe** göre değerlendirilir.
        // İstemci saat vermediyse "şimdi" varsayılır.
        $reference = $requestedAt?->copy()->setTimezone(BusinessTime::ZONE)
            ?? BusinessTime::now();

        [$hour, $minute] = array_map(intval(...), explode(':', $cutoff));
        $deadline = $reference->copy()->setTime($hour, $minute);

        // Aynı gün için verilen sipariş, kesim saatini geçtiyse reddedilir.
        // Yarına verilen sipariş bugünün kesim saatinden etkilenmez.
        $now = BusinessTime::now();
        if ($reference->isSameDay($now) && $now->greaterThan($deadline)) {
            throw ApiException::locationClosed(
                "Bugünün sipariş kabul saati ({$cutoff}) doldu. Yarın için sipariş verebilirsiniz.",
            );
        }
    }

    /** @throws ApiException */
    public function assertPaymentMethodAllowed(Location $location, string $method): void
    {
        $allowed = $this->paymentMethods($location);

        if (!in_array($method, $allowed, true)) {
            throw ApiException::validationFailed(
                'Bu ödeme yöntemi şu anda kullanılamıyor.',
                ['payment_method' => 'Geçerli yöntemler: '.implode(', ', $allowed)],
            );
        }
    }

    /** @throws ApiException */
    public function assertMeetsMinimum(Location $location, int $subtotalKurus): void
    {
        $minimum = $this->minOrderTotal($location);

        if ($minimum > 0 && $subtotalKurus < $minimum) {
            throw ApiException::validationFailed(
                'Asgari sipariş tutarının altındasınız.',
                [
                    'min_order_total' => $minimum,
                    'subtotal' => $subtotalKurus,
                ],
            );
        }
    }

    private function option(Location $location, string $key, mixed $default): mixed
    {
        $raw = DB::table('location_options')
            ->where('location_id', $location->location_id)
            ->where('item', $key)
            ->value('value');

        if ($raw === null) {
            return $default;
        }

        $decoded = json_decode((string) $raw, true);

        return $decoded ?? $default;
    }

    private function setOption(Location $location, string $key, mixed $value): void
    {
        DB::table('location_options')->updateOrInsert(
            ['location_id' => $location->location_id, 'item' => $key],
            ['value' => json_encode($value)],
        );
    }

    /** Kurulum yardımcısı — `veykemtu:setup` çağırır. */
    public function seedDefaults(Location $location, int $minOrderTotalKurus): void
    {
        $this->setOption($location, self::KEY_ORDERING, true);
        $this->setOption($location, self::KEY_MIN_TOTAL, $minOrderTotalKurus);
        $this->setOption($location, self::KEY_PAYMENTS, self::DEFAULT_PAYMENT_METHODS);
    }
}
