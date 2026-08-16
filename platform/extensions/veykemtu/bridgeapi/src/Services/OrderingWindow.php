<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Igniter\Local\Models\Location;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Sipariş penceresinin TEK SAHİBİ: "D gününe şu anda sipariş verilebilir mi?"
 *
 * İş kararı 2 ve 3 (`docs/03-api-sozlesmesi.md` §3, `docs/control/settings.md`
 * §"İki kesim saati vardır"):
 *
 *   1. **Her servis günü kendi sabah kesim saatinde kapanır.** Kesim artık
 *      "bugüne sipariş verme saati" değil, GÜNÜN KENDİ kapanış anıdır.
 *   2. Gelecek günler kesimden etkilenmez — tanımı gereği: 22 Ağustos'un
 *      08:00'i, 20 Ağustos'ta her zaman gelecektedir.
 *   3. En fazla `max_lookahead_days` gün ileriye sipariş alınır.
 *   4. **Hafta sonu menü yok ama satış kanalı AÇIK**: cumartesi günü
 *      pazartesiye sipariş verilebilir. Bu yüzden burada haftanın gününe
 *      bakan hiçbir KAPI yoktur; `isServiceDay()` yalnız görüntüleme içindir.
 *
 * KURAL BİRLEŞİNCE SADELEŞTİ. Eski kod iki yerde (`LocationGate` ve
 * `DailyMenuService`) "yalnız bugünse kesime bak" diye bir özel durum
 * taşıyordu. Kesim güne bağlanınca o özel durum KAYBOLDU: gelecek bir günün
 * kesimi zaten geçmiş olamaz, dolayısıyla `isSameDay` denetimine gerek yok.
 * İki kopya tek sahibe indi; ikisinin ayrışması artık mümkün değil.
 *
 * NEDEN AYRI SINIF — `LocationGate` yetmiyor mu: `LocationGate` VİTRİNİ
 * anlatıyor (şalter, ödeme yöntemi, asgari tutar) ve bir servis gününü hiç
 * tanımıyor. Pencere ise her zaman BİR GÜN hakkında konuşur ve o günün kendi
 * kaydından (`veykemtu_daily_menus.cutoff_time`) besleniyor.
 */
class OrderingWindow
{
    /**
     * Menü çıkan haftanın günleri, ISO numaralarıyla (1 Pazartesi .. 7 Pazar).
     *
     * VARSAYIM: sözleşme (`docs/openapi.yaml` → `Location.service_weekdays`)
     * bu listeyi bir alan olarak yayınlıyor ama onu YAZAN bir uç henüz yok —
     * ne `docs/control/settings.md` ne de panel bir anahtar tanımlıyor. Sabit
     * olarak duruyor ki üç istemci haftanın gününü kendi hesaplamasın; ayar
     * hâline gelirse tek okuma noktası burasıdır.
     *
     * **Bu liste bir KAPI DEĞİLDİR.** Hafta sonuna menü yayınlamak serbesttir
     * ve yayınlanmış bir hafta sonu günü normalde satılır; alan yalnız
     * takvimin o hücreyi soluk çizmesi içindir.
     *
     * @var list<int>
     */
    public const array SERVICE_WEEKDAYS = [1, 2, 3, 4, 5];

    /**
     * Vitrinin genel kesim saati, vitrin başına HATIRLANIR.
     *
     * Takvim doksan güne kadar çizilir ve her gün genel saati sorsaydı
     * `location_options` doksan kez okunurdu — `DailyMenuService::calendar()`
     * tam da bunu önlemek için iki toplu sorguya indirilmişti. Hatırlama bu
     * NESNENİN ömrüyle sınırlı; servis paylaşılan bir tekil değil, her
     * çözümlemede yeniden kuruluyor, dolayısıyla ayarı değiştiren bir istek
     * bir sonraki istekte eski değeri görmez.
     *
     * @var array<int, string|null>
     */
    private array $defaultCutoff = [];

    public function __construct(
        private readonly LocationGate $gate,
    ) {}

    /**
     * Servis gününün kesim ANI; kesim tanımlı değilse `null`.
     *
     * Öncelik: güne özel saat → vitrinin genel saati. Sözleşmedeki birleştirme
     * kuralının tamamı budur: `gün.cutoff_time ?? ayar.order_cutoff`.
     *
     * DÖNEN DEĞER MUTLAK BİR ANDIR, saat değil. Sözleşme `cutoff_at` alanını
     * bilerek an olarak veriyor (`docs/03` §3): kesim kuralını üç dilde
     * yeniden hesaplamak (TS `Intl`, Dart'ta sabit UTC+3, PHP'de
     * `Europe/Istanbul`) sapmanın kaynağı. An İstanbul duvar saatinde
     * somutlaştırılır; çağıran isterse UTC'ye çevirip yollar.
     */
    public function cutoffFor(Location $location, Carbon $serviceDate): ?Carbon
    {
        return $this->cutoffFromTime(
            $location,
            $serviceDate,
            $this->dayCutoffTime($location, $serviceDate),
        );
    }

    /**
     * Kesim anı — güne özel saati ÇAĞIRAN veriyor.
     *
     * Takvim gibi toplu okuyan çağıranlar için: günler zaten tek sorguyla
     * çekilmişken her gün için ikinci bir sorgu açmak, doksan günlük bir
     * aralığı doksan sorguya çevirirdi. `$dayCutoff` `null` ise vitrinin
     * genel saati geçerlidir.
     *
     * @param  string|null  $dayCutoff  `HH:mm` ya da `HH:mm:ss` (kolon `time`).
     */
    public function cutoffFromTime(
        Location $location,
        Carbon $serviceDate,
        ?string $dayCutoff,
    ): ?Carbon {
        $time = $this->parseTime($dayCutoff)
            ?? $this->parseTime($this->defaultCutoff($location));

        if ($time === null) {
            return null;
        }

        [$hour, $minute] = $time;

        // Gün bir TAKVİM GÜNÜ, bir an değil: yalnız `Y-m-d` parçası alınıp
        // İstanbul'da yeniden kuruluyor. `setTimezone` ile çevirmek, çağıran
        // UTC gece yarısı verdiğinde günü bir gün geriye kaydırırdı.
        return Carbon::parse($serviceDate->format('Y-m-d'), BusinessTime::ZONE)
            ->setTime($hour, $minute);
    }

    /** Servis gününün kesim saati geçti mi? Kesim yoksa `false`. */
    public function isPastCutoff(Location $location, Carbon $serviceDate): bool
    {
        return $this->hasPassed($this->cutoffFor($location, $serviceDate));
    }

    /**
     * Verilen kesim anı geçti mi? `null` (kesim yok) her zaman `false`.
     *
     * Açıkta duruyor ki toplu okuyan çağıran `cutoffFromTime()` ile birlikte
     * kullanabilsin; karşılaştırmayı kendi yazsaydı "geçti" tanımı ikinci bir
     * yere kopyalanırdı.
     */
    public function hasPassed(?Carbon $cutoff): bool
    {
        return $cutoff !== null && BusinessTime::now()->greaterThan($cutoff);
    }

    /** Sipariş alınabilen en ileri gün (dâhil). */
    public function lastOrderableDate(Location $location): Carbon
    {
        return BusinessTime::now()
            ->startOfDay()
            ->addDays($this->gate->maxLookaheadDays($location));
    }

    /**
     * Bu gün için sipariş penceresi açık mı? Değilse gerekçesiyle patlar.
     *
     * SIRA ÖNEMLİ, `DailyMenuService::verdict()` ile aynı: en kalıcı sebep
     * önce söylenir. Geçmiş bir güne "kesim saati doldu" demek, müşteriyi
     * yarın tekrar denemeye çağırırdı.
     *
     * Sebep kodları (`error.details.reason`) sözleşmedeki
     * `DailyMenu.unavailable_reason` değerleriyle AYNI: istemci aynı sebebi
     * takvimde ve sipariş hatasında aynı adla görür.
     *
     * @throws ApiException
     */
    public function assertWithinWindow(Location $location, Carbon $serviceDate): void
    {
        $date = $serviceDate->copy()->startOfDay();
        $today = BusinessTime::now()->startOfDay();

        if ($date->lessThan($today)) {
            throw ApiException::validationFailed(
                'Geçmiş bir güne sipariş verilemez.',
                [
                    'service_date' => $date->toDateString(),
                    'reason' => DailyMenuService::REASON_PAST,
                ],
            );
        }

        if ($date->greaterThan($this->lastOrderableDate($location))) {
            throw ApiException::validationFailed(
                'Bu tarih için henüz sipariş alınmıyor.',
                [
                    'service_date' => $date->toDateString(),
                    'reason' => DailyMenuService::REASON_TOO_FAR,
                ],
            );
        }

        $cutoff = $this->cutoffFor($location, $date);

        if ($cutoff !== null && $this->hasPassed($cutoff)) {
            // Kesimi geçebilen tek gün bugündür (gelecek günün kesimi
            // gelecektedir), o yüzden cümle "bugün" diyebiliyor.
            throw ApiException::locationClosed(
                'Bugünün sipariş kabul saati ('
                    .$cutoff->format('H:i')
                    .') doldu. Yarın için sipariş verebilirsiniz.',
            );
        }
    }

    /**
     * O gün menü çıkıyor mu? YALNIZ GÖRÜNTÜLEME — sipariş kapısı değil.
     *
     * Takvim `weekend` alanını bundan üretiyor; adı "weekend" ama anlamı
     * "servis yok" (`docs/openapi.yaml` → `MenuCalendarDay.weekend`).
     */
    public function isServiceDay(Carbon $date): bool
    {
        return in_array($date->isoWeekday(), self::SERVICE_WEEKDAYS, true);
    }

    /**
     * Güne özel kesim saati; girilmemişse `null`.
     *
     * Menünün DURUMUNA bakılmıyor: taslak bir gün de kendi saatini taşır ve
     * yayınlandığı anda o saat geçerli olmalı. Yayın durumu ayrı bir kapı
     * (`DailyMenuService::verdict()` → `not_published`) ve iki kapıyı tek
     * sorguya karıştırmak, yayınlanınca saatin sessizce değişmesi olurdu.
     */
    /** Vitrinin genel kesim saati — vitrin başına bir kez okunur. */
    private function defaultCutoff(Location $location): ?string
    {
        $id = (int) $location->location_id;

        if (!array_key_exists($id, $this->defaultCutoff)) {
            $this->defaultCutoff[$id] = $this->gate->orderCutoff($location);
        }

        return $this->defaultCutoff[$id];
    }

    private function dayCutoffTime(Location $location, Carbon $serviceDate): ?string
    {
        $value = DB::table('veykemtu_daily_menus')
            ->where('location_id', $location->location_id)
            ->whereDate('menu_date', $serviceDate->toDateString())
            ->value('cutoff_time');

        return is_string($value) && trim($value) !== '' ? $value : null;
    }

    /**
     * `HH:mm` ya da `HH:mm:ss` → `[saat, dakika]`; tanınmayan değer `null`.
     *
     * `time` kolonu sürücüye göre `08:00:00`, ayar ise `08:00` döner. Bozuk
     * bir değer BURADA elenip bir üst kaynağa düşüyor: patlamak, bir yazım
     * hatası yüzünden bütün satışı durdurmak olurdu.
     *
     * @return array{0:int, 1:int}|null
     */
    private function parseTime(?string $value): ?array
    {
        if ($value === null) {
            return null;
        }

        $matches = [];

        if (preg_match('/^([01]\d|2[0-3]):([0-5]\d)(:[0-5]\d)?$/', trim($value), $matches) !== 1) {
            return null;
        }

        return [(int) $matches[1], (int) $matches[2]];
    }
}
