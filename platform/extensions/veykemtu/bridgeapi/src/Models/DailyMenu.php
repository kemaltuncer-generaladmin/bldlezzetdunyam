<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Admin\LiraField;

/**
 * Bir günün menüsü — `docs/02-veri-modeli.md` §8 (B-19).
 *
 * Satılan şey artık sabit bir katalog değil, gün gün girilen menü. Bu kayıt
 * bir günün "bugün ne var" cevabıdır: bütün olarak (paket fiyatıyla) ya da
 * kalem kalem satılır.
 *
 * TASLAK/YAYIN AYRIMI ZORUNLU: yönetici bir ay öncesinden plan giriyor.
 * Ayrım olmasaydı yarım girilmiş bir perşembe, kaydedildiği anda müşteriye
 * görünür ve pişmeyecek bir yemek satılırdı.
 */
class DailyMenu extends Model
{
    public const string STATUS_DRAFT = 'draft';

    public const string STATUS_PUBLISHED = 'published';

    /** @var list<string> */
    public const array STATUSES = [self::STATUS_DRAFT, self::STATUS_PUBLISHED];

    /** Paket ürünü kimliğinin `location_options` anahtarı (göç yazar). */
    public const string PACKAGE_OPTION_KEY = 'bld_daily_package_menu_id';

    protected $table = 'veykemtu_daily_menus';

    public $timestamps = true;

    protected $guarded = [];

    protected $casts = [
        'location_id' => 'integer',
        'menu_date' => 'date',
        'package_price_kurus' => 'integer',
        'components_sellable' => 'boolean',
        'published_at' => 'datetime',
        'published_by' => 'integer',
        'created_by' => 'integer',
    ];

    /**
     * SIRALAMA BAĞINTININ KENDİSİNDE — çünkü sırasız okuma SESSİZCE YANLIŞ.
     *
     * Buraya önce `'sort' => ['sort_order', 'asc']` yazılmıştı; çekirdek böyle
     * bir anahtar tanımıyor ve sessizce yok sayıyor (tanıdığı anahtar
     * `'order'`, bkz. `Flame\Database\Relations\DefinedConstraints`). Sonra
     * sıralama tek tek okuma yerlerine dağıtıldı ve tam da beklenen şey oldu:
     * [findPublished] sıraladı, panelin gün okumaları sıralamadı.
     *
     * SIRASIZ OKUMANIN GÖRÜNMEYEN YÜZÜ: `veykemtu_daily_menu_items` üzerinde
     * `(daily_menu_id, menu_id)` tekil indeksi var ve MySQL kalemleri o
     * indeksten, yani MENÜ KİMLİĞİ SIRASINDA getiriyor. Ekleme sırası gibi
     * görünen şey aslında ürün kimliği sırası: çorba, ana yemekten sonra
     * eklenmiş bir ürünse listenin altına düşüyor. Panelde bu yalnız kozmetik
     * değil — gün düzenleyici kalemleri o sırayla çiziyor ve kaydet'e basıldığı
     * anda `sort_order` O YANLIŞ SIRAYLA yeniden yazılıyor, yani yöneticinin
     * girdiği sıra kalıcı olarak kayboluyor.
     *
     * Bu yüzden sıra artık bağıntının tanımında: kalemleri nereden okursanız
     * okuyun çorba → ana yemek → pilav → tatlı gelir.
     *
     * @var array<string, array<string, mixed>>
     */
    public $relation = [
        'hasMany' => [
            'items' => [
                DailyMenuItem::class,
                'foreignKey' => 'daily_menu_id',
                // İkinci anahtar beraberliği bozar. `sort_order` göçte
                // varsayılan 0; `replaceItems()` dışında yazılan satırlar
                // (konsol, elle düzeltme) hepsi 0 ile doğar ve tek anahtarla
                // sıralanırsa liste istekten isteğe değişirdi.
                'order' => ['sort_order asc', 'id asc'],
            ],
        ],
    ];

    public function isPublished(): bool
    {
        return $this->status === self::STATUS_PUBLISHED;
    }

    /**
     * Paket satılıyor mu?
     *
     * `package_price_kurus` null ise o gün yalnız kalemler tek tek satılır.
     * Sıfır ayrı bir şey olurdu ("bedava") ve kabul edilmiyor.
     */
    public function sellsPackage(): bool
    {
        return $this->package_price_kurus !== null && $this->package_price_kurus > 0;
    }

    /**
     * Kalemlerin tek tek alınması hâlindeki toplam (kuruş).
     *
     * Sözleşmedeki `DailyMenu.items_total`. Sunucuda hesaplanıyor ki
     * "paketle şu kadar avantaj" cümlesini kuran istemci çıkarma yapmak
     * zorunda kalmasın — para hesabı tek yerde.
     */
    public function itemsTotalKurus(): int
    {
        $total = 0;

        foreach ($this->items as $item) {
            $total += $item->effectiveUnitPriceKurus() * max(1, (int) $item->quantity);
        }

        return $total;
    }

    /**
     * Panelde TL girilir, veritabanında kuruş durur.
     *
     * BOŞ GİRDİ SIFIR DEĞİL, NULL. `LiraField::toKurus('')` sıfır döndürüyor;
     * doğrudan kullansaydık paket fiyatı girilmemiş bir gün "paket bedava"
     * anlamına gelirdi. Null = o gün paket satılmıyor, yalnız kalemler.
     */
    public function getPackagePriceLiraAttribute(): string
    {
        $kurus = $this->attributes['package_price_kurus'] ?? null;

        return $kurus !== null ? LiraField::toInput((int) $kurus) : '';
    }

    public function setPackagePriceLiraAttribute(mixed $value): void
    {
        $this->attributes['package_price_kurus'] = trim((string) $value) === ''
            ? null
            : max(0, LiraField::toKurus($value));
    }

    public static function findPublished(int $locationId, Carbon $date): ?self
    {
        return self::query()
            // Sıra BURADA VERİLMİYOR: yöneticinin verdiği sıra (çorba → ana
            // yemek → pilav → tatlı) bağıntı tanımından geliyor. Burada da
            // tekrarlansaydı iki doğruluk kaynağı olurdu ve biri değişince
            // öteki sessizce eskirdi.
            ->with(['items', 'items.menu'])
            ->where('location_id', $locationId)
            ->whereDate('menu_date', $date->toDateString())
            ->where('status', self::STATUS_PUBLISHED)
            ->first();
    }

    /** Bu günün kalemi — yoksa `null`. */
    public function itemFor(int $menuId): ?DailyMenuItem
    {
        foreach ($this->items as $item) {
            if ((int) $item->menu_id === $menuId) {
                return $item;
            }
        }

        return null;
    }

    /**
     * Bu vitrinin "Günün Menüsü" paket ürünü kimliği.
     *
     * `location_options` içinden okunuyor; göç yazıyor
     * (`2026_08_15_000004`). Model kendi vitrinini bildiği için bu bilgiyi
     * dışarıdan almaya gerek yok.
     */
    public function packageMenuId(): ?int
    {
        return self::packageMenuIdFor((int) $this->location_id);
    }

    public static function packageMenuIdFor(int $locationId): ?int
    {
        $raw = DB::table('location_options')
            ->where('location_id', $locationId)
            ->where('item', self::PACKAGE_OPTION_KEY)
            ->value('value');

        $value = $raw !== null ? json_decode((string) $raw, true) : null;

        return is_numeric($value) && (int) $value > 0 ? (int) $value : null;
    }

    /**
     * Verilen ürün, herhangi bir vitrinin paket ürünü mü?
     *
     * `LineResolver` bunu bir GÜVENLİK KAPISI olarak kullanıyor: paket
     * ürününün kendi fiyatı 0,00 ve gerçek fiyat o günün paket fiyatı.
     * Gün çözülmeden fiyatlanmasına izin verilirse günün menüsü sıfır
     * liraya satılır.
     *
     * Yapıya (fiyat sıfır + kategorisiz) bakmak yerine KİMLİĞE bakılıyor:
     * kategorisi olmayan ücretsiz meşru bir ürün de o tarife uyar ve
     * sessizce satılamaz hâle gelirdi.
     */
    public static function isPackageProduct(int $menuId): bool
    {
        if ($menuId <= 0) {
            return false;
        }

        return DB::table('location_options')
            ->where('item', self::PACKAGE_OPTION_KEY)
            ->get('value')
            ->contains(
                static fn(object $row): bool
                    => (int) json_decode((string) $row->value, true) === $menuId,
            );
    }

    /**
     * Sipariş satırında görünecek ad.
     *
     * Ürünün kalıcı adı ("Günün Menüsü") tek başına hangi gün olduğunu
     * söylemiyor; fişte ve sipariş geçmişinde gün de görünmeli.
     */
    public function orderLineName(): string
    {
        $title = trim((string) ($this->title ?? ''));
        $date = $this->menu_date->format('d.m.Y');

        return $title !== ''
            ? "{$title} ({$date})"
            : "Günün Menüsü ({$date})";
    }
}
