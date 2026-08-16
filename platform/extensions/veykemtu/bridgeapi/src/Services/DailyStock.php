<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use DateTimeInterface;
use Igniter\Cart\Models\Menu;
use Igniter\Cart\Models\Order;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\DailyMenuStock;
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
        // `DateTimeInterface` sorulur, `Carbon` değil: bu dosya Carbon'u import
        // ETMİYOR ve import edilmemiş bir sınıfa karşı `instanceof` PHP'de
        // sessizce false döner — her tarih `trim()`'e düşüp TypeError üretirdi.
        // Arayüz sorulduğunda Carbon, Illuminate\Support\Carbon ve düz DateTime
        // birlikte karşılanıyor.
        return $date instanceof DateTimeInterface
            ? $date->format('Y-m-d')
            : substr(trim($date), 0, 10);
    }
}
