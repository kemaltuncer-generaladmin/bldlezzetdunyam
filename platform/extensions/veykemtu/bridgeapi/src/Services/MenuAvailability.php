<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Igniter\Cart\Models\Menu;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * "Bugün tükendi" işaretlerinin tek kaynağı — `docs/05-mutfakapp.md` §11.
 *
 * İKİ AYRI KAVRAM, İKİ AYRI ALAN:
 *   * `menus.menu_status` — yöneticinin KALICI kararı ("artık satmıyoruz").
 *   * `veykemtu_menu_soldout` — mutfağın GÜNLÜK kararı ("bugünlük bitti").
 *
 * Aynı alanı paylaşsalardı akşam tükenen ürünü sabah yöneticinin elle geri
 * açması gerekirdi; bir sabah unutulduğunda ürün sessizce menüden düşerdi.
 *
 * ABONELİK MUAFTIR. Abonelik siparişleri `OrderFactory::createForSubscription`
 * içinde üretiliyor ve `LocationGate` gibi bu kontrolü de atlıyor: abonelik
 * bir sözleşmedir, günlük stok kararı onu iptal edemez. Mutfak bir abonelik
 * gününü atlamak istiyorsa `veykemtu_subscription_exceptions` kaydı girer —
 * o ayrı ve bilinçli bir karardır.
 */
class MenuAvailability
{
    /**
     * Bugün tükenmiş ürün kimlikleri.
     *
     * @return list<int>
     */
    public function soldOutToday(): array
    {
        return DB::table('veykemtu_menu_soldout')
            ->whereDate('sold_out_on', BusinessTime::now()->toDateString())
            ->pluck('menu_id')
            ->map(intval(...))
            ->all();
    }

    /**
     * Bugün tükenmiş ürünlerin sebepleriyle birlikte listesi.
     *
     * @return array<int, string|null> menu_id => sebep
     */
    public function soldOutReasons(): array
    {
        return DB::table('veykemtu_menu_soldout')
            ->whereDate('sold_out_on', BusinessTime::now()->toDateString())
            ->pluck('reason', 'menu_id')
            ->all();
    }

    public function isSoldOut(int $menuId): bool
    {
        return in_array($menuId, $this->soldOutToday(), true);
    }

    public function reasonFor(int $menuId): ?string
    {
        $reason = $this->soldOutReasons()[$menuId] ?? null;

        return is_string($reason) && trim($reason) !== '' ? trim($reason) : null;
    }

    /**
     * Ürünü bugünlük tükendi işaretler (idempotent).
     *
     * `insertOrIgnore` + `UNIQUE(menu_id, sold_out_on)`: aynı ürüne iki kez
     * basmak ikinci bir satır yazmaz ve ilk sebebi de ezmez. Sebebi
     * değiştirmek isteyen önce açıp tekrar kapatır — nadir bir iş için
     * güncelleme yolu açmak, "kim ne zaman ne yazdı" izini bulanıklaştırırdı.
     */
    public function markSoldOut(
        int $menuId,
        ?string $reason = null,
        ?int $deviceId = null,
        ?int $createdBy = null,
    ): void {
        DB::table('veykemtu_menu_soldout')->insertOrIgnore([
            'menu_id' => $menuId,
            'sold_out_on' => BusinessTime::now()->toDateString(),
            'reason' => $reason === null || trim($reason) === '' ? null : trim($reason),
            'device_id' => $deviceId,
            'created_by' => $createdBy,
            'created_at' => BusinessTime::forStorage(BusinessTime::now()),
        ]);
    }

    /**
     * Bugünkü tükendi işaretini kaldırır.
     *
     * Yalnız BUGÜNÜN satırı siliniyor: geçmiş günlerin kaydı "hangi ürün
     * hangi gün bitti" sorusunun cevabıdır ve silinmemeli.
     */
    public function clearSoldOut(int $menuId): void
    {
        DB::table('veykemtu_menu_soldout')
            ->where('menu_id', $menuId)
            ->whereDate('sold_out_on', BusinessTime::now()->toDateString())
            ->delete();
    }

    /**
     * Mutfak ekranının listelediği ürünler — FİYATSIZ.
     *
     * ADR-08 korunuyor: mutfak kapsamı para görmez. Ürün adı, kategorisi ve
     * bugünkü durumu, "ne bitti" kararını vermeye fazlasıyla yeter.
     *
     * @return list<array<string, mixed>>
     */
    public function kitchenCatalog(): array
    {
        $soldOut = $this->soldOutReasons();

        return Menu::query()
            ->orderBy('menu_name')
            ->get()
            ->map(fn(Menu $menu): array => [
                'menu_id' => (int) $menu->menu_id,
                'name' => (string) $menu->menu_name,
                // Yöneticinin kalıcı kararı ayrı gösteriliyor: mutfak
                // "ben açtım ama görünmüyor" dediğinde sebebi burada.
                'listed' => (bool) $menu->menu_status,
                'sold_out' => array_key_exists((int) $menu->menu_id, $soldOut),
                'sold_out_reason' => $soldOut[(int) $menu->menu_id] ?? null,
            ])
            ->all();
    }
}
