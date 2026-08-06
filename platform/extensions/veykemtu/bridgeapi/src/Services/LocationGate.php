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
 * | `busy` | **mutfak**, tek tuşla | Sipariş ALINIR, sadece gecikme uyarısı çıkar |
 *
 * Üçünü ayrı tutmak, "bugün yoğunuz, sipariş almayı durdur" ile "çalışma
 * saatimiz bitti"yi karıştırmamak içindir; ikincisi yarın kendiliğinden
 * geri açılır, birincisi açılmaz.
 *
 * `busy` bunlardan **ayrıdır ve siparişi ENGELLEMEZ**. Mutfak yoğunken
 * kapıyı kapatmak yerine müşteriyi uyarmak istiyoruz: sipariş girer, ekranda
 * "hazırlanması uzun sürebilir" yazar. Sipariş almayı gerçekten durdurmak
 * `ordering_enabled` şalteridir ve o yöneticinindir — mutfak personeli tek
 * tuşla cirosu kapatamamalı.
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

    private const string KEY_DELIVERY_FEE = 'bld_delivery_fee';

    private const string KEY_BUSY = 'bld_busy';

    private const string KEY_BUSY_MESSAGE = 'bld_busy_message';

    // ── Teslimat süresi tahmini ────────────────────────────────────────────
    private const string KEY_PREP_MINUTES = 'bld_prep_minutes';

    private const string KEY_DELIVERY_MINUTES = 'bld_delivery_minutes';

    private const string KEY_BUSY_EXTRA_MINUTES = 'bld_busy_extra_minutes';

    /** Yönetici kendi metnini yazmadıysa gösterilecek uyarı. */
    public const string DEFAULT_BUSY_MESSAGE =
        'Mutfağımız şu anda yoğun. Siparişiniz alınır ancak hazırlanması '
        .'normalden uzun sürebilir.';

    /** Sözleşmedeki ödeme yöntemleri — `docs/openapi.yaml` `PaymentMethod`. */
    public const array ALL_PAYMENT_METHODS = ['online', 'cash', 'account'];

    /**
     * Güvenli varsayılan: yalnızca sistem dışı tahsilat.
     *
     * `online` bu listeye **otomatik eklenmez** — `veykemtu:setup` yalnızca
     * çalışan bir ödeme geçidi varsa ekler. Çalışmayan bir yöntemi listeye
     * koymak, müşteriye tıklayınca hiçbir şey olmayan bir düğme göstermektir.
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

    /**
     * Adrese gönderim ücreti (kuruş). Gel-al siparişte uygulanmaz.
     *
     * Sözleşmede `Location.delivery_fee` olarak açılır: istemci kullanıcıya
     * toplamı onaydan ÖNCE gösterebilsin diye. Bağlayıcı olan yine sunucunun
     * sipariş anındaki hesabıdır.
     */
    public function deliveryFee(Location $location): int
    {
        return (int) $this->option($location, self::KEY_DELIVERY_FEE, 0);
    }

    /**
     * Mutfağın bir siparişi hazırlaması için öngörülen dakika.
     *
     * Bu değer yalnızca BAŞLANGIÇ NOKTASI. Yeterli sayıda tamamlanmış sipariş
     * biriktiğinde `EtaService` gerçek ölçümü kullanıyor — çünkü elle girilen
     * süre iyimser olmaya meyilli ve kimse onu güncellemeyi hatırlamıyor.
     */
    public function prepMinutes(Location $location): int
    {
        return $this->positiveMinutes($this->option($location, self::KEY_PREP_MINUTES, null), 40);
    }

    public function setPrepMinutes(Location $location, int $minutes): void
    {
        $this->setOption($location, self::KEY_PREP_MINUTES, $this->positiveMinutes($minutes, 40));
    }

    /** Hazır siparişin adrese ulaşması için öngörülen dakika. Gel-al'da uygulanmaz. */
    public function deliveryMinutes(Location $location): int
    {
        return $this->positiveMinutes($this->option($location, self::KEY_DELIVERY_MINUTES, null), 20);
    }

    public function setDeliveryMinutes(Location $location, int $minutes): void
    {
        $this->setOption($location, self::KEY_DELIVERY_MINUTES, $this->positiveMinutes($minutes, 20));
    }

    /**
     * Mutfak "yoğunuz" dediğinde tahmine eklenen dakika.
     *
     * Yoğunluk anahtarı zaten var ama şimdiye kadar yalnızca uyarı metni
     * gösteriyordu. Süreyi de uzatmazsak müşteri yoğun saatte gerçekçi
     * olmayan bir teslim saati görüyor ve gecikme şikâyeti doğuyor.
     */
    public function busyExtraMinutes(Location $location): int
    {
        return $this->positiveMinutes(
            $this->option($location, self::KEY_BUSY_EXTRA_MINUTES, null),
            15,
        );
    }

    public function setBusyExtraMinutes(Location $location, int $minutes): void
    {
        $this->setOption($location, self::KEY_BUSY_EXTRA_MINUTES, $this->positiveMinutes($minutes, 15));
    }

    /**
     * Dakika alanlarının ortak temizliği.
     *
     * Üst sınır var: elle girilen 100000 gibi bir değer müşteriye "yaklaşık
     * 69 gün" yazdırırdı. Sıfır ve negatif de anlamsız — o durumda varsayılana
     * dönülüyor, çünkü "0 dakikada teslim" sözü verilmemeli.
     */
    private function positiveMinutes(mixed $value, int $default): int
    {
        $minutes = (int) $value;

        if ($minutes <= 0) {
            return $default;
        }

        return min($minutes, 480);
    }

    /**
     * Mutfak yoğun mu?
     *
     * Mutfak ekranındaki tek tuşla açılıp kapanır. Sipariş akışını
     * DEĞİŞTİRMEZ — yalnızca istemcilere uyarı gösterme sinyalidir.
     */
    public function isBusy(Location $location): bool
    {
        return (bool) $this->option($location, self::KEY_BUSY, false);
    }

    public function setBusy(Location $location, bool $busy): void
    {
        $this->setOption($location, self::KEY_BUSY, $busy);
    }

    /**
     * Yoğunluk uyarısının metni.
     *
     * Yönetici admin panelden değiştirebilir; boş bırakırsa varsayılan
     * kullanılır. İstemcilerin kendi metnini gömmesini İSTEMİYORUZ: metin
     * değişince üç uygulamayı birden yayınlamak gerekirdi.
     */
    public function busyMessage(Location $location): string
    {
        $value = $this->option($location, self::KEY_BUSY_MESSAGE, null);

        return is_string($value) && trim($value) !== ''
            ? trim($value)
            : self::DEFAULT_BUSY_MESSAGE;
    }

    public function setBusyMessage(Location $location, ?string $message): void
    {
        $this->setOption($location, self::KEY_BUSY_MESSAGE, $message);
    }

    /** `HH:mm` ya da `null` (kesim saati yok). */
    public function setOrderCutoff(Location $location, ?string $cutoff): void
    {
        $this->setOption($location, self::KEY_CUTOFF, $cutoff);
    }

    /** Kuruş. TL kabul etmiyoruz — dönüşümü çağıran yapar, tek yerde. */
    public function setMinOrderTotal(Location $location, int $kurus): void
    {
        $this->setOption($location, self::KEY_MIN_TOTAL, max(0, $kurus));
    }

    /** Kuruş. */
    public function setDeliveryFee(Location $location, int $kurus): void
    {
        $this->setOption($location, self::KEY_DELIVERY_FEE, max(0, $kurus));
    }

    /**
     * Açık ödeme yöntemleri.
     *
     * Sözleşmede olmayan değerler SESSİZCE ELENİR, hata atmayız: yönetici
     * panelinden gelen bir yazım hatası yüzünden kaydetmeyi reddetmek,
     * kullanıcıyı çıkmaza sokar. Boş liste de kabul edilmez — hiçbir ödeme
     * yöntemi olmayan vitrin sipariş alamaz ve sebebi görünmez olurdu.
     *
     * @param  list<string>  $methods
     */
    public function setPaymentMethods(Location $location, array $methods): void
    {
        $temiz = array_values(array_intersect(
            array_map(strval(...), $methods),
            self::ALL_PAYMENT_METHODS,
        ));

        $this->setOption(
            $location,
            self::KEY_PAYMENTS,
            $temiz === [] ? self::DEFAULT_PAYMENT_METHODS : $temiz,
        );
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

    /**
     * Kurulum yardımcısı — `veykemtu:setup` çağırır.
     *
     * @param  list<string>  $paymentMethods
     */
    public function seedDefaults(
        Location $location,
        int $minOrderTotalKurus,
        ?array $paymentMethods = null,
    ): void {
        $this->setOption($location, self::KEY_ORDERING, true);
        $this->setOption($location, self::KEY_MIN_TOTAL, $minOrderTotalKurus);
        $this->setOption(
            $location,
            self::KEY_PAYMENTS,
            $paymentMethods ?? self::DEFAULT_PAYMENT_METHODS,
        );
        // Teslimat ücreti mock ile AYNI (40,00 TL) — E-01'de "sözleşme mi
        // bozuk, veri mi farklı" sorusunu doğurmasın. Bölge bazlı
        // ücretlendirme BILINMEYENLER #10'da açık soru.
        $this->setOption($location, self::KEY_DELIVERY_FEE, 4000);
    }
}
