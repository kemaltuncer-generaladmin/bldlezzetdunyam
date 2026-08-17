<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use DateTimeInterface;
use Igniter\Cart\Models\Menu;
use Igniter\Cart\Models\Order;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ClosedDay;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Models\DailyMenuStock;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Günlük porsiyon tavanının tek sahibi — iş kuralı 4 (S2).
 *
 * İKİ TAVAN, TEK MEKANİZMA: gün toplamı (`menu_id = 0`) ve ürün bazlı tavan
 * aynı tablonun satırlarıdır. Bir sipariş ikisinden de düşer; hangisi önce
 * dolarsa satışı o kapatır. Ayrıca kodlanmış bir öncelik yok — kural,
 * "ikisini birden düş" cümlesinden kendiliğinden çıkıyor.
 *
 * SATIR YOKSA SINIRSIZ: tavan konmamış bir gün/kalem için tabloda hiçbir
 * satır olmaz, `remaining()` `null` döner ve düşüm sessizce geçer. `null`
 * ile `0` asla karıştırılmaz (`docs/contract/sales-rules.cases.json`).
 *
 * ─────────────────────────────────────────────────────────────────────────
 * DÜŞÜMÜN TEK DOĞRU İLKELİ — TEK KOŞULLU `UPDATE`
 *
 *   UPDATE veykemtu_daily_menu_stock SET sold = sold + :qty
 *    WHERE location_id=:loc AND service_date=:d AND menu_id=:m
 *      AND capacity - reserved - sold >= :qty
 *
 * Etkilenen satır sayısı 1 değilse düşüm OLMAMIŞTIR. InnoDB `WHERE`'e uyan
 * satırı işlem sonuna kadar kilitler; son porsiyon için yarışan iki alıcıdan
 * ikincisi ya bekler ve koşulu artık sağlamaz, ya hiç eşleşmez.
 *
 * `SELECT` sonra `UPDATE` YOK. `lockForUpdate()` YOK. PHP'de oku-değiştir-yaz
 * YOK. Üçünün de arasında bir kayıp-güncelleme penceresi var ve o pencere
 * "son porsiyonu iki müşteriye birden sattık" demek. Eloquent'in `save()`'i
 * de aynı sebeple kullanılmaz.
 *
 * `CAST(... AS SIGNED)` KOZMETİK DEĞİL: kolonlar `UNSIGNED` ve personel
 * telefonda tavanı bilerek aşabiliyor (`allowOvershoot`). Aşım sonrası
 * `capacity - reserved - sold` eksiye düşer; MySQL imzasız çıkarmada eksi
 * sonucu bir HATA sayar (`BIGINT UNSIGNED value is out of range`) ve o
 * günün bütün satışı 500 döner. İşaretli çevrim bu tuzağı kapatıyor.
 *
 * ÇOKLU SATIR DÜŞÜMÜ HER ZAMAN `menu_id ASC` SIRASINDA. Sırasız düşüm
 * InnoDB'de kilitlenme (deadlock) üretir; belirtisi yoğun saatte aralıklı
 * 500'dür ve hata ayıklamanın en kötü zamanıdır. Sıralama `normalize()`
 * içinde, tek yerde.
 * ─────────────────────────────────────────────────────────────────────────
 */
class DailyStock
{
    /** Gün toplamı satırının `menu_id` nöbetçisi. */
    public const int DAY_TOTAL = DailyMenuStock::DAY_TOTAL;

    private const string TABLE = 'veykemtu_daily_menu_stock';

    /**
     * O gün/kalem için kalan porsiyon — `null` SINIRSIZ.
     *
     * `$menuId` verilmezse günün TOPLAM tavanı okunur.
     */
    public function remaining(
        int $locationId,
        DateTimeInterface|string $date,
        int $menuId = self::DAY_TOTAL,
    ): ?int {
        $row = DB::table(self::TABLE)
            ->where('location_id', $locationId)
            ->where('service_date', self::dateKey($date))
            ->where('menu_id', $menuId)
            ->first(['capacity', 'reserved', 'sold']);

        if ($row === null) {
            return null;
        }

        return self::freeOf($row);
    }

    /**
     * O günün bütün tavanları — `menu_id => kalan`.
     *
     * Katalog yanıtı bir günde onlarca kalem çiziyor; her biri için ayrı
     * `remaining()` çağırmak onlarca sorgu demekti (`soldOutReasons()`
     * aynı dersi bir kez verdi). Gün toplamı `DAY_TOTAL` anahtarındadır.
     *
     * @return array<int, int>
     */
    public function remainingMap(int $locationId, DateTimeInterface|string $date): array
    {
        $map = [];

        foreach (
            DB::table(self::TABLE)
                ->where('location_id', $locationId)
                ->where('service_date', self::dateKey($date))
                ->get(['menu_id', 'capacity', 'reserved', 'sold']) as $row
        ) {
            $map[(int) $row->menu_id] = self::freeOf($row);
        }

        return $map;
    }

    /**
     * Vitrin bilinmiyorken o ürünün EN DAR kalanı — `null` sınırsız.
     *
     * `MenuAvailability` gibi vitrin taşımayan çağrı yerleri için. İki
     * vitrinden biri tükenmişse dar olan söylenir: "satılabilir mi"
     * sorusuna iyimser cevap vermek, satılamayacak bir ürünü satışta
     * göstermek olurdu. Faz 1'de tek vitrin var ve iki davranış aynı.
     */
    public function tightestRemaining(int $menuId, DateTimeInterface|string $date): ?int
    {
        $rows = DB::table(self::TABLE)
            ->where('service_date', self::dateKey($date))
            ->where('menu_id', $menuId)
            ->get(['capacity', 'reserved', 'sold']);

        if ($rows->isEmpty()) {
            return null;
        }

        return (int) $rows->map(static fn(object $row): int => self::freeOf($row))->min();
    }

    /**
     * O gün tavanı dolmuş ÜRÜN kimlikleri.
     *
     * Gün toplamı satırı listeye GİRMEZ: o bir ürün değil, günün kendisi.
     * Günün kapanması `DailyMenuService::verdict()` üzerinden
     * `unavailable_reason: sold_out` olarak söylenir; ürün listesine 0
     * kimliğini karıştırmak, olmayan bir ürünü tükenmiş göstermek olurdu.
     *
     * @return list<int>
     */
    public function soldOutOn(DateTimeInterface|string $date): array
    {
        return DB::table(self::TABLE)
            ->where('service_date', self::dateKey($date))
            ->where('menu_id', '<>', self::DAY_TOTAL)
            ->whereRaw(
                'CAST(capacity AS SIGNED) - CAST(reserved AS SIGNED) - CAST(sold AS SIGNED) <= 0',
            )
            ->pluck('menu_id')
            ->map(intval(...))
            ->all();
    }

    /**
     * Satışı düşer — tavanı aşan istek reddedilir.
     *
     * @param  array<int, int>  $menuIdToQty  `menu_id => porsiyon` (0 = gün toplamı)
     * @param  bool  $allowOvershoot  `true` ise tavan DENETLENMEZ, düşüm her
     *   hâlde yapılır. Sipariş revizyonunda gerekiyor: personel müşteriyle
     *   telefonda konuşup adedi artırırken, o gün tavan dolduğu için
     *   düzenlemenin tamamen reddedilmesi saçma olurdu — kararı insan verdi.
     *   Aşım çağırana döner ve kayda geçer.
     * @return array<int, int> `menu_id => tavanı aşan porsiyon` (aşım yoksa boş)
     *
     * @throws ApiException tavan yetmiyorsa (`ITEM_UNAVAILABLE`)
     */
    public function take(
        int $locationId,
        DateTimeInterface|string $date,
        array $menuIdToQty,
        bool $allowOvershoot = false,
    ): array {
        return $this->increase('sold', $locationId, $date, $menuIdToQty, $allowOvershoot);
    }

    /**
     * Satışı geri verir (iptal, adet azaltma).
     *
     * `GREATEST(sold - qty, 0)`: eksiye düşmek, geri verilenden fazlasını
     * geri vermek demek olurdu ve bir sonraki gün tavanı sessizce büyürdü.
     *
     * @param  array<int, int>  $menuIdToQty
     */
    public function release(int $locationId, DateTimeInterface|string $date, array $menuIdToQty): void
    {
        $this->decrease('sold', $locationId, $date, $menuIdToQty);
    }

    /**
     * Porsiyonu satmadan AYIRIR — abonelikler için (iş kuralı 5).
     *
     * Abone sabah siparişini garanti eder, tek seferlik satış artandan
     * yürür. Tersi olsaydı bir günü aboneler için ayırmak elle iş olurdu
     * (`docs/openapi.yaml` → `DailyMenuPackage.remaining_portions`).
     *
     * @param  array<int, int>  $menuIdToQty
     * @return array<int, int>
     *
     * @throws ApiException
     */
    public function reserve(
        int $locationId,
        DateTimeInterface|string $date,
        array $menuIdToQty,
        bool $allowOvershoot = false,
    ): array {
        return $this->increase('reserved', $locationId, $date, $menuIdToQty, $allowOvershoot);
    }

    /**
     * Rezervasyonu bırakır.
     *
     * Abonelik siparişi gerçekten üretildiğinde çağrılır — rezerve edilen
     * porsiyon `take()` ile satışa geçer. Abonelik durdurulduğunda da
     * çağrılır ve o hâlde porsiyon herkese açılır.
     *
     * @param  array<int, int>  $menuIdToQty
     */
    public function unreserve(int $locationId, DateTimeInterface|string $date, array $menuIdToQty): void
    {
        $this->decrease('reserved', $locationId, $date, $menuIdToQty);
    }

    /**
     * Rezerve porsiyonu SATIŞA çevirir — abonelik siparişi doğduğu an.
     *
     * TEK İFADE, TEK SATIR KİLİDİ. `reserved` azalırken `sold` aynı
     * `UPDATE` içinde artıyor. `unreserve()` sonra `take()` yazılsaydı
     * ikisinin arasında bir pencere açılırdı ve o pencerede porsiyon
     * HERKESE AÇIK görünürdü: serbest satış tam o anda kapasiteyi kapar,
     * abonenin sözleşmeyle garanti ettiği porsiyon başkasına satılırdı.
     *
     * TAVAN DENETLENMEZ ve bu bilinçli — `take()`'in koşullu `UPDATE`'i
     * burada YANLIŞ olurdu: porsiyon zaten rezerve edilmişken
     * `capacity - reserved - sold >= n` sorsaydık kendi rezervasyonumuz
     * kendimize engel olurdu.
     *
     * `GREATEST(..., 0)`: rezervasyon eksik kalmış olabilir (uzlaştırma
     * henüz koşmadı, sipariş panelden elle üretildi). O hâlde `reserved`
     * sıfırda durur ama satış YİNE DE kaydedilir — mutfağa düşmüş bir
     * siparişi satılmamış saymak, tavanın kendisinden daha büyük bir yalan.
     *
     * @param  array<int, int>  $menuIdToQty
     */
    public function sellReserved(
        int $locationId,
        DateTimeInterface|string $date,
        array $menuIdToQty,
    ): void {
        $day = self::dateKey($date);
        $now = BusinessTime::forStorage(BusinessTime::now())->toDateTimeString();

        foreach (self::normalize($menuIdToQty) as $menuId => $quantity) {
            DB::update(
                'UPDATE '.self::TABLE
                    .' SET reserved = GREATEST(CAST(reserved AS SIGNED) - ?, 0),'
                    .' sold = sold + ?, updated_at = ?'
                    .' WHERE location_id = ? AND service_date = ? AND menu_id = ?',
                [$quantity, $quantity, $now, $locationId, $day, $menuId],
            );
        }
    }

    /**
     * ─────────────────────────────────────────────────────────────────────
     * REZERVASYON İLERİYE DÖNÜK HESAPLANIR — bu bölümün tamamının sebebi.
     *
     * D+5'in serbest satışı, D+5'in abonelik siparişi doğmadan ÇOK ÖNCE
     * açılıyor (gece işi yalnız ertesi günü üretiyor). Rezervasyon da bu
     * yüzden sipariş üretimine bağlanamaz: bağlansaydı D+5'in kapasitesi
     * beş gün boyunca boşmuş gibi görünür, serbest satış aboneye ayrılmış
     * porsiyonları satar ve arıza ancak üretim gecesi — satış kapandıktan
     * sonra — ortaya çıkardı.
     *
     * BU YÜZDEN SIFIRDAN HESAP, ARTIMLI DÜZELTME DEĞİL. Aşağıdaki
     * [syncReservedWindow] `reserved`'ı pencerenin her günü için baştan
     * kurar; artımlı kancalar (aktifleştirme, duraklatma, gün atlama, menü
     * yayınlama) yalnız TEK BİR GÜNÜ aynı hesapla yeniden kurar
     * ([syncReservedFor]). Sonuç: her artımlı hata en geç 24 saat içinde
     * kendini onarır. Tersi — artımlı toplama/çıkarma — kaçırılan tek bir
     * kancada sessiz aşırı satış demek.
     *
     * ÜRETİLMİŞ GÜN YENİDEN REZERVE EDİLMEZ. `veykemtu_subscription_runs`
     * satırı olan (abonelik × teslimat noktası × gün) üçlüsünün porsiyonu
     * artık `sold`; onu bir de rezerve saymak, aynı porsiyonu kapasiteden
     * iki kez düşerdi.
     * ─────────────────────────────────────────────────────────────────────
     *
     * Pencerenin tamamı için `reserved`'ı sıfırdan kurar; sapmaları döner.
     *
     * @param  bool  $apply  `false` ise hiçbir şey yazılmaz (kuru koşum).
     * @return list<array{service_date: string, menu_id: int, from: int, to: int}>
     */
    public function syncReservedWindow(
        int $locationId,
        Carbon $from,
        Carbon $to,
        bool $apply = true,
    ): array {
        $first = $from->copy()->startOfDay();
        $last = $to->copy()->startOfDay();

        if ($last->lt($first)) {
            return [];
        }

        $subscriptions = Subscription::query()
            ->active()
            ->where('location_id', $locationId)
            ->with(['lines', 'delivery_points', 'pauses', 'exceptions'])
            ->get();

        $closed = $this->closedDaysBetween($first, $last);
        $runs = $this->runCountsBetween($subscriptions, $first, $last);

        $deviations = [];

        for ($cursor = $first->copy(); $cursor->lte($last); $cursor->addDay()) {
            // Kapalı gün (tatil) üretim yapmaz — `SubscriptionGenerateCommand`
            // ile AYNI tabloyu okuyoruz, yani tek kaynak. Rezervasyon
            // bırakmak, tatilde kimseye satılamayacak porsiyonları kilitli
            // tutmak olurdu.
            $expected = in_array($cursor->toDateString(), $closed, true)
                ? []
                : $this->expectedReservedOn($locationId, $cursor, $subscriptions, $runs);

            foreach ($this->writeReserved($locationId, $cursor, $expected, $apply) as $deviation) {
                $deviations[] = $deviation;
            }
        }

        return $deviations;
    }

    /**
     * Tek bir günün rezervasyonunu sıfırdan kurar.
     *
     * ARTIMLI KANCALARIN TEK GİRİŞİ. Aktifleştirme, duraklatma, devam,
     * iptal, gün atlama ve menü yayınlama hepsi bunu çağırır: hepsi "şu
     * günün rezervasyonu artık başka" diyor ve o günü yeniden hesaplamak,
     * her biri için ayrı bir delta aritmetiği yazmaktan hem kısa hem de
     * yanılmaz. Gecelik uzlaştırmayla AYNI kod yolu olduğu için ikisinin
     * ayrışması da mümkün değil.
     *
     * @return list<array{service_date: string, menu_id: int, from: int, to: int}>
     */
    public function syncReservedFor(int $locationId, Carbon $date, bool $apply = true): array
    {
        return $this->syncReservedWindow($locationId, $date, $date, $apply);
    }

    /**
     * Bir aboneliğin BİR teslimat noktası için, bir gündeki stok talebi.
     *
     * [demandOf]'un İLERİYE DÖNÜK İKİZİ: o, yazılmış sipariş satırlarını
     * okur; bu, henüz doğmamış siparişin ne yazacağını önden söyler.
     * İKİSİ AYNI SONUCU VERMEK ZORUNDA — ayrışırlarsa rezerve edilenden
     * başka bir miktar satışa çevrilir, iptalde de başka bir miktar geri
     * verilir ve fark her gün birikir. Bu yüzden gün toplamı kuralı
     * birebir kopyalanmıştır: `component` OLMAYAN her satır gün toplamına
     * da yazar.
     *
     * @return array<int, int>
     */
    public function subscriptionDemand(Subscription $subscription, Carbon $date): array
    {
        $day = $subscription->menu_mode === Subscription::MENU_DAILY
            ? DailyMenu::findPublished((int) $subscription->location_id, $date)
            : null;

        return $this->demandFor($subscription, $date, $day);
    }

    /**
     * O gün, o vitrinde beklenen rezervasyon — `menu_id => porsiyon`.
     *
     * @param  Collection<int, Subscription>  $subscriptions
     * @param  array<string, int>  $runs  `abonelik|gün => üretilmiş nokta sayısı`
     * @return array<int, int>
     */
    private function expectedReservedOn(
        int $locationId,
        Carbon $date,
        Collection $subscriptions,
        array $runs,
    ): array {
        $expected = [];
        $day = null;
        $dayLoaded = false;

        foreach ($subscriptions as $subscription) {
            if (!$subscription->runsOnDate($date)) {
                continue;
            }

            // Teslimat noktası başına BİR sipariş doğuyor ve her biri
            // porsiyonun tamamını istiyor (`OrderFactory` nokta adedini
            // porsiyona çevirmiyor). Üretilmiş noktalar düşülür: onların
            // porsiyonu artık `sold`.
            $targets = max(1, $subscription->delivery_points->count())
                - ($runs[$subscription->id.'|'.$date->toDateString()] ?? 0);

            if ($targets < 1) {
                continue;
            }

            if (!$dayLoaded && $subscription->menu_mode === Subscription::MENU_DAILY) {
                // Gün başına TEK okuma: menü bütün abonelikler için aynı.
                $day = DailyMenu::findPublished($locationId, $date);
                $dayLoaded = true;
            }

            foreach ($this->demandFor($subscription, $date, $day) as $menuId => $quantity) {
                $expected[$menuId] = ($expected[$menuId] ?? 0) + $quantity * $targets;
            }
        }

        return $expected;
    }

    /**
     * @param  DailyMenu|null  $day  `daily_menu` modunda o günün YAYINLANMIŞ menüsü
     * @return array<int, int>
     */
    private function demandFor(Subscription $subscription, Carbon $date, ?DailyMenu $day): array
    {
        $portions = max(1, $subscription->quantityForDate($date));

        if ($subscription->menu_mode !== Subscription::MENU_DAILY) {
            return $this->fixedListDemand($subscription, $portions);
        }

        /*
         * MENÜ YAYINLANMAMIŞSA REZERVASYON YOK — ve bu güvenli.
         *
         * Neyin pişeceği bilinmiyor, sipariş de üretilemiyor. Uydurma bir
         * gün toplamı rezervasyonu yazmak, [demandOf] ile ayrışmak demekti.
         * Aşırı satış riski de yok: yayınlanmamış bir güne serbest satış
         * zaten kapalı (`DailyMenuService` → `not_published`). Menü
         * yayınlandığı an o günün rezervasyonu yeniden kurulur
         * ([syncReservedFor]) ve en geç gecelik uzlaştırmada oturur.
         */
        if ($day === null) {
            return [];
        }

        $demand = [self::DAY_TOTAL => $portions];

        // Paket ÜST satırı gerçek bir `menu_id` taşıyor ("Günün Menüsü"
        // ürünü) ve tavanı ona da konabilir; sipariş satırı yazıldığında
        // [demandOf] onu sayacağı için rezervasyon da saymak zorunda.
        $packageMenuId = $day->packageMenuId();

        if ($packageMenuId !== null) {
            $demand[$packageMenuId] = ($demand[$packageMenuId] ?? 0) + $portions;
        }

        foreach ($day->items as $item) {
            // Seçmeli kalem pakete girmiyor (`OrderFactory::dailyMenuLines`).
            if (!$item->is_required) {
                continue;
            }

            $menuId = (int) $item->menu_id;

            if ($menuId < 1) {
                continue;
            }

            $demand[$menuId] = ($demand[$menuId] ?? 0)
                + $portions * max(1, (int) $item->quantity);
        }

        return $demand;
    }

    /**
     * `fixed_list` — aboneliğin kendi satırları.
     *
     * GÜN TOPLAMINA HER SATIR YAZAR: bu modda paket üst satırı yok, yani
     * satırların hiçbiri `component` değil ve [demandOf] hepsini gün
     * toplamına sayıyor. "Porsiyon başına bir kez saysak" daha doğru
     * görünürdü ama iki hesap ayrışır, iptalde rezervden fazlası geri
     * verilirdi. Doğrusu tek yerde düzeltilir: [demandOf].
     *
     * @return array<int, int>
     */
    private function fixedListDemand(Subscription $subscription, int $portions): array
    {
        $demand = [];

        foreach ($subscription->lines as $line) {
            $menuId = (int) $line->menu_id;

            if ($menuId < 1) {
                continue;
            }

            $quantity = $portions * max(1, (int) $line->quantity);

            $demand[$menuId] = ($demand[$menuId] ?? 0) + $quantity;
            $demand[self::DAY_TOTAL] = ($demand[self::DAY_TOTAL] ?? 0) + $quantity;
        }

        return $demand;
    }

    /**
     * Beklenen değeri satırlara yazar; değişenleri döner.
     *
     * MUTLAK YAZIM, ARTIŞ DEĞİL (`SET reserved = ?`). Hesap sıfırdan
     * yapıldığı için doğru değer elimizde; `+=` yazmak, uzlaştırmayı iki
     * kez koşturan bir operatörün rezervasyonu ikiye katlaması demekti.
     *
     * BEKLENEN SATIR YOKSA HİÇBİR ŞEY YAZILMAZ: tavansız gün/kalem
     * SINIRSIZ demek (sınıf başlığı), ve olmayan bir tavana rezervasyon
     * yazmak `remaining()`'in `null` sözleşmesini bozardı.
     *
     * @param  array<int, int>  $expected
     * @return list<array{service_date: string, menu_id: int, from: int, to: int}>
     */
    private function writeReserved(
        int $locationId,
        Carbon $date,
        array $expected,
        bool $apply,
    ): array {
        $day = $date->toDateString();
        $now = BusinessTime::forStorage(BusinessTime::now())->toDateTimeString();
        $changes = [];

        $rows = DB::table(self::TABLE)
            ->where('location_id', $locationId)
            ->where('service_date', $day)
            // `menu_id ASC` — çoklu satır güncellemesinde kilitlenme
            // önlemi; `normalize()` ile aynı gerekçe.
            ->orderBy('menu_id')
            ->get(['menu_id', 'reserved']);

        foreach ($rows as $row) {
            $menuId = (int) $row->menu_id;
            $current = (int) $row->reserved;
            $target = $expected[$menuId] ?? 0;

            if ($current === $target) {
                continue;
            }

            $changes[] = [
                'service_date' => $day,
                'menu_id' => $menuId,
                'from' => $current,
                'to' => $target,
            ];

            if ($apply) {
                DB::update(
                    'UPDATE '.self::TABLE.' SET reserved = ?, updated_at = ?'
                        .' WHERE location_id = ? AND service_date = ? AND menu_id = ?',
                    [$target, $now, $locationId, $day, $menuId],
                );
            }
        }

        return $changes;
    }

    /**
     * Aralıktaki kapalı günler — tek sorgu.
     *
     * @return list<string>
     */
    private function closedDaysBetween(Carbon $first, Carbon $last): array
    {
        return ClosedDay::query()
            ->whereBetween('closed_on', [$first->toDateString(), $last->toDateString()])
            ->pluck('closed_on')
            ->map(static fn(mixed $value): string => substr((string) $value, 0, 10))
            ->all();
    }

    /**
     * Üretilmiş (abonelik × gün) sayaçları — tek sorgu.
     *
     * Gün gün sorsaydık on dört günlük pencere on dört sorgu ederdi;
     * `remainingMap()` aynı dersi bir kez vermişti.
     *
     * @param  Collection<int, Subscription>  $subscriptions
     * @return array<string, int>  `abonelik|gün => üretilmiş nokta sayısı`
     */
    private function runCountsBetween(Collection $subscriptions, Carbon $first, Carbon $last): array
    {
        if ($subscriptions->isEmpty()) {
            return [];
        }

        $counts = [];

        $rows = DB::table('veykemtu_subscription_runs')
            ->whereIn('subscription_id', $subscriptions->modelKeys())
            ->whereBetween('service_date', [$first->toDateString(), $last->toDateString()])
            ->get(['subscription_id', 'service_date']);

        foreach ($rows as $row) {
            $key = $row->subscription_id.'|'.substr((string) $row->service_date, 0, 10);
            $counts[$key] = ($counts[$key] ?? 0) + 1;
        }

        return $counts;
    }

    /**
     * Kayıtlı bir siparişin stok talebi — `LineResolver::stockDemand()`'in
     * veritabanı satırlarından okunan ikizi.
     *
     * İki ayrı okuma olmak zorunda: sipariş oluşurken talep ÇÖZÜLMÜŞ
     * satırlardan (`LineResolver`), iptal ve revizyonda ise YAZILMIŞ
     * satırlardan çıkar — o anda elimizde istemci kalemleri yok.
     *
     * KURAL İKİSİNDE DE AYNI: her satır kendi `menu_id`'sinden düşer;
     * BİLEŞEN satırları gün toplamına dokunmaz, çünkü ait oldukları paket
     * satırı zaten günün porsiyonunu saymıştır. Bileşenler de sayılsaydı
     * dört kalemlik bir menü, gün tavanından beş porsiyon yerdi.
     *
     * @return array<int, int>
     */
    public function demandOf(Order $order): array
    {
        $demand = [];

        $rows = DB::table('order_menus')
            ->where('order_id', $order->order_id)
            ->get(['menu_id', 'quantity', 'bld_line_role']);

        foreach ($rows as $row) {
            $menuId = (int) $row->menu_id;
            $quantity = (int) $row->quantity;

            if ($menuId < 1 || $quantity < 1) {
                continue;
            }

            $demand[$menuId] = ($demand[$menuId] ?? 0) + $quantity;

            if ($row->bld_line_role !== 'component') {
                $demand[self::DAY_TOTAL] = ($demand[self::DAY_TOTAL] ?? 0) + $quantity;
            }
        }

        return $demand;
    }

    /**
     * İptal edilen siparişin porsiyonlarını stoka geri verir — BİR KEZ.
     *
     * ÇİFT KREDİ KORUMASI ATOMİK: `bld_stock_released_at` yalnız `NULL`
     * iken yazılıyor ve etkilenen satır sayısı 1 değilse hiçbir şey
     * yapılmıyor. Önce okuyup sonra yazsaydık, aynı anda gelen iki iptal
     * (çift tıklama, KDS'in yeniden denemesi, panelle mutfağın çakışması)
     * ikisi de "henüz geri verilmemiş" görür ve porsiyonlar iki kez geri
     * verilirdi — o gün tavanın üstünde satış açılır ve kimse bir hata
     * görmez.
     *
     * @return bool bu çağrı gerçekten geri verdiyse `true`
     */
    public function releaseOrder(Order $order): bool
    {
        $date = $order->bld_service_date ?? $order->order_date;

        if ($date === null) {
            // Servis günü olmayan sipariş stoktan hiç düşmemiştir; işareti
            // koymak da yanlış olur (bir gün kolon dolarsa geri verilecek).
            return false;
        }

        $claimed = DB::table('orders')
            ->where('order_id', $order->order_id)
            ->whereNull('bld_stock_released_at')
            ->update([
                'bld_stock_released_at' => BusinessTime::forStorage(BusinessTime::now()),
            ]);

        if ($claimed !== 1) {
            return false;
        }

        $this->release((int) $order->location_id, $date, $this->demandOf($order));

        return true;
    }

    /**
     * @param  array<int, int>  $menuIdToQty
     * @return array<int, int>
     *
     * @throws ApiException
     */
    private function increase(
        string $column,
        int $locationId,
        DateTimeInterface|string $date,
        array $menuIdToQty,
        bool $allowOvershoot,
    ): array {
        $day = self::dateKey($date);
        $now = BusinessTime::forStorage(BusinessTime::now())->toDateTimeString();
        $overshoot = [];

        foreach (self::normalize($menuIdToQty) as $menuId => $quantity) {
            if ($allowOvershoot) {
                // Aşım TAVAN DENETLENMEDEN önce ölçülüyor; tek amacı kayda
                // geçmek. Yarışa karşı bir güvencesi yok ve olması da
                // gerekmiyor: bu yol zaten "insan bilerek aşıyor" yolu.
                $free = $this->remaining($locationId, $day, $menuId);

                if ($free !== null && $free < $quantity) {
                    $overshoot[$menuId] = $quantity - $free;
                }
            }

            $sql = 'UPDATE '.self::TABLE
                .' SET '.$column.' = '.$column.' + ?, updated_at = ?'
                .' WHERE location_id = ? AND service_date = ? AND menu_id = ?';
            $bindings = [$quantity, $now, $locationId, $day, $menuId];

            if (!$allowOvershoot) {
                $sql .= ' AND CAST(capacity AS SIGNED) - CAST(reserved AS SIGNED)'
                    .' - CAST(sold AS SIGNED) >= ?';
                $bindings[] = $quantity;
            }

            if (DB::update($sql, $bindings) === 1) {
                continue;
            }

            // Etkilenen satır yok: ya tavan yetmedi ya da tavan hiç konmamış.
            // İkisini ayırmanın tek yolu satırın varlığına bakmak; bu sorgu
            // yalnızca BAŞARISIZ yolda koşuyor.
            if (!$this->hasRow($locationId, $day, $menuId)) {
                continue;
            }

            throw ApiException::itemUnavailable($this->soldOutMessage($menuId), $menuId);
        }

        return $overshoot;
    }

    /** @param  array<int, int>  $menuIdToQty */
    private function decrease(
        string $column,
        int $locationId,
        DateTimeInterface|string $date,
        array $menuIdToQty,
    ): void {
        $day = self::dateKey($date);
        $now = BusinessTime::forStorage(BusinessTime::now())->toDateTimeString();

        foreach (self::normalize($menuIdToQty) as $menuId => $quantity) {
            DB::update(
                'UPDATE '.self::TABLE
                    .' SET '.$column.' = GREATEST(CAST('.$column.' AS SIGNED) - ?, 0),'
                    .' updated_at = ?'
                    .' WHERE location_id = ? AND service_date = ? AND menu_id = ?',
                [$quantity, $now, $locationId, $day, $menuId],
            );
        }
    }

    private function hasRow(int $locationId, string $date, int $menuId): bool
    {
        return DB::table(self::TABLE)
            ->where('location_id', $locationId)
            ->where('service_date', $date)
            ->where('menu_id', $menuId)
            ->exists();
    }

    /** Müşteriye gösterilecek Türkçe sebep. */
    private function soldOutMessage(int $menuId): string
    {
        if ($menuId === self::DAY_TOTAL) {
            return 'Bu gün için ayrılan porsiyonlar tükendi. Başka bir gün seçebilirsiniz.';
        }

        $name = Menu::query()->where('menu_id', $menuId)->value('menu_name');

        return is_string($name) && $name !== ''
            ? "{$name} için kalan porsiyon yok."
            : 'Seçilen üründen kalan porsiyon yok.';
    }

    /**
     * Talebi temizler, toplar ve `menu_id ASC` sıralar.
     *
     * SIRALAMA BURADA, TEK YERDE: sırasız çoklu düşüm InnoDB'de kilitlenme
     * üretir ve belirtisi yoğun saatte aralıklı 500'dür. Her çağrı yerinde
     * ayrı ayrı sıralamak, bir gün birinde unutulması demekti.
     *
     * @param  array<int, int>  $menuIdToQty
     * @return array<int, int>
     */
    private static function normalize(array $menuIdToQty): array
    {
        $demand = [];

        foreach ($menuIdToQty as $menuId => $quantity) {
            $menuId = (int) $menuId;
            $quantity = (int) $quantity;

            if ($menuId < 0 || $quantity < 1) {
                continue;
            }

            $demand[$menuId] = ($demand[$menuId] ?? 0) + $quantity;
        }

        ksort($demand);

        return $demand;
    }

    private static function freeOf(object $row): int
    {
        // Çıkarma PHP'de yapılıyor: aşım sonrası eksi sonuç MySQL'de imzasız
        // taşma hatasıdır, PHP'de yalnız bir eksi sayı.
        return max(0, (int) $row->capacity - (int) $row->reserved - (int) $row->sold);
    }

    private static function dateKey(DateTimeInterface|string $date): string
    {
        // `DateTimeInterface` sorulur, `Carbon` DEĞİL — ve bu, dosya artık
        // Carbon'u import ediyor olsa da değişmedi. Import edilmemiş bir
        // sınıfa karşı `instanceof` PHP'de sessizce false döner (her tarih
        // `trim()`'e düşüp TypeError üretirdi); dahası ortalıkta İKİ Carbon
        // var (`Carbon\Carbon` ve `Illuminate\Support\Carbon`) ve somut
        // sınıfı sormak, hangisinin geldiğine bağlı bir kırılganlık olurdu.
        // Arayüz sorulduğunda ikisi de düz `DateTime` ile birlikte karşılanır.
        return $date instanceof DateTimeInterface
            ? $date->format('Y-m-d')
            : substr(trim($date), 0, 10);
    }
}
