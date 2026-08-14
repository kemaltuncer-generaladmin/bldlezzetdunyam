<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Console;

use Igniter\Admin\Models\Status;
use Igniter\Cart\Models\Menu;
use Igniter\Local\Models\Location;
use Igniter\User\Models\CustomerGroup;
use Igniter\User\Models\UserRole;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Services\LocationGate;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Kurulum sonrası zorunlu yapılandırma — docs/04-platform.md §2.
 *
 * NEDEN KOMUT, ELLE DEĞİL: `igniter:install --no-interaction` vitrin ve
 * müşteri grubu oluşturmaz, varsayılan durumları da bizim kodlarımızla
 * uyuşmaz bırakır. Bunları elle yapmak, her yeni ortamda (staging, prod,
 * yeni geliştirici) sessizce farklı bir veritabanı demektir.
 *
 * Komut **idempotenttir**: tekrar tekrar koşulabilir, mevcut kaydı günceller,
 * kopya oluşturmaz.
 */
class SetupCommand extends Command
{
    protected $signature = 'veykemtu:setup';

    protected $description = 'BLD kurulum sonrası yapılandırması: durumlar, vitrin, müşteri grubu.';

    /** Menü paketi ürününün kalıcı adı (B-19). */
    private const string DAILY_PACKAGE_NAME = 'Günün Menüsü';

    /**
     * Sözleşmedeki yedi durum — docs/openapi.yaml `OrderStatus`.
     *
     * Sıra anlamlıdır: admin panelde bu sırayla görünür.
     * `notify_customer` yalnızca müşterinin gerçekten haber alması gereken
     * geçişlerde açıktır; `yeni` kendi verdiği siparişin bildirimidir, gereksiz.
     */
    private const array STATUSES = [
        ['code' => 'yeni',          'name' => 'Yeni',          'color' => '#f97316', 'notify' => false],
        ['code' => 'onaylandi',     'name' => 'Onaylandı',     'color' => '#2563eb', 'notify' => true],
        ['code' => 'hazirlaniyor',  'name' => 'Hazırlanıyor',  'color' => '#ca8a04', 'notify' => true],
        ['code' => 'hazir',         'name' => 'Hazır',         'color' => '#16a34a', 'notify' => true],
        ['code' => 'yolda',         'name' => 'Yolda',         'color' => '#0891b2', 'notify' => true],
        ['code' => 'teslim_edildi', 'name' => 'Teslim edildi', 'color' => '#57534e', 'notify' => true],
        ['code' => 'iptal',         'name' => 'İptal',         'color' => '#dc2626', 'notify' => true],
    ];

    public function handle(): int
    {
        $this->seedTimezone();
        $this->syncPaymentGateways();
        $this->seedStatuses();
        $this->seedLocation();
        $this->seedDailyMenuPackage();
        $this->seedCustomerGroup();
        $this->seedAdminRoles();

        $this->newLine();
        $this->info('BLD yapılandırması tamam.');

        return self::SUCCESS;
    }

    /**
     * Zaman dilimi — sessiz ama ciddi bir tuzak.
     *
     * TastyIgniter `timezone` ayarını **Europe/London** varsayılanıyla kurar
     * ve `System\ServiceProvider` bunu `date_default_timezone_set()` ile
     * PHP'ye dayatır (`app.timezone` ve `date.timezone` ini'si ezilir).
     * Sonuç: veritabanına yazılan her zaman damgası bir saat kayar, fiş
     * denetimi ve "bugünün siparişleri" yanlış çıkar.
     *
     * İstanbul'a çekiyoruz: hem depolama tutarlı olur hem yönetici admin
     * panelde doğru saati görür. API sınırında her zaman UTC'ye çevrilir.
     */
    private function seedTimezone(): void
    {
        $current = setting('timezone');

        if ($current === BusinessTime::ZONE) {
            return;
        }

        setting()->set('timezone', BusinessTime::ZONE);

        $this->components->info('Zaman dilimi ayarlandı: '.BusinessTime::ZONE);
        $this->components->twoColumnDetail('  önceki', (string) ($current ?? '-'));
    }

    /**
     * Ödeme geçitlerini `payments` tablosuna işler.
     *
     * NEDEN GEREKLİ: TastyIgniter `orders.payment` alanını `payments.code`
     * ile eşleştirir. Kod karşılığı olmayan bir sipariş için
     * `Order::$payment_method` ilişkisi `null` döner ve ödeme günlüğü
     * "property on null" ile patlar — bu, ödeme akışının ortasında çıkan
     * ve sebebi görünmeyen bir hatadır.
     *
     * Geçitler PASİF olarak eklenir; müşteriye hangi yöntemin görüneceğini
     * vitrinin `payment_methods` listesi belirler, admin panelindeki
     * etkinlik bayrağı değil.
     */
    private function syncPaymentGateways(): void
    {
        $sinif = 'Igniter\\PayRegister\\Models\\Payment';

        if (!class_exists($sinif)) {
            return;
        }

        $sinif::syncAll();

        $kodlar = $sinif::whereIn('code', ['cash', 'account', 'online'])
            ->pluck('code')->sort()->implode(', ');

        $this->components->twoColumnDetail('  ödeme geçitleri', $kodlar !== '' ? $kodlar : '-');
    }

    private function seedStatuses(): void
    {
        $this->components->info('Sipariş durumları yazılıyor...');

        foreach (self::STATUSES as $definition) {
            $status = Status::firstOrNew([
                'status_code' => $definition['code'],
            ]);

            $status->fill([
                'status_name' => $definition['name'],
                'status_for' => 'order',
                'status_color' => $definition['color'],
                'notify_customer' => $definition['notify'],
            ]);
            $status->status_code = $definition['code'];
            $status->save();

            $this->components->twoColumnDetail(
                "  {$definition['code']}",
                "#{$status->status_id} {$definition['name']}",
            );
        }

        // TastyIgniter'ın kendi varsayılan sipariş durumları bizim
        // makinemizde yer almaz. Silmiyoruz — geçmiş siparişler onlara
        // bağlı olabilir; yalnızca kodsuz bırakıp API'den gizliyoruz.
        $orphans = Status::where('status_for', 'order')
            ->whereNull('status_code')
            ->count();

        if ($orphans > 0) {
            $this->components->warn(
                "{$orphans} adet kodsuz sipariş durumu var (TastyIgniter varsayılanları). ".
                'API bunları döndürmez; admin panelden silinebilirler.',
            );
        }

        $this->setDefaultOrderStatus();
    }

    /**
     * Yeni siparişlerin başlangıç durumu `yeni` olmalı.
     *
     * TastyIgniter bunu `default_order_status` ayarından okur
     * (`Order::updateOrderStatus()` içinde `setting('default_order_status')`).
     */
    private function setDefaultOrderStatus(): void
    {
        $yeni = Status::where('status_code', 'yeni')->first();
        if ($yeni === null) {
            return;
        }

        // setting()->set() kendisi kaydeder; ayrıca ->save() çağırmak
        // Settings modelini boş satır insert etmeye zorlar ve 1062 verir.
        setting()->set('default_order_status', $yeni->status_id);

        $this->components->twoColumnDetail(
            '  varsayılan sipariş durumu',
            "#{$yeni->status_id} yeni",
        );
    }

    private function seedLocation(): void
    {
        $this->components->info('Vitrin yazılıyor...');

        // Kolonun adı `permalink_slug`'dır, `location_slug` değil —
        // kurulu şemadan doğrulandı (B-02).
        $location = Location::firstOrNew(['permalink_slug' => 'catering']);
        $location->fill([
            'location_name' => 'Benim Lezzet Dünyam',
            'location_email' => 'siparis@benimlezzetdunyam.com.tr',
            'location_status' => true,
            'is_default' => true,
            'is_auto_lat_lng' => false,
        ]);
        $location->permalink_slug = 'catering';
        $location->save();

        // Sipariş alım şalteri, asgari tutar ve açık ödeme yöntemleri.
        // Asgari tutar 250,00 TL (25000 kuruş) — docs/03 §3 örneği.
        //
        // `online` yalnızca çalışan bir ödeme geçidi VARSA açılır. Faz 1'de
        // bu geçit simülasyondur ve üretimde kapalıdır; yöntem listesine
        // çalışmayan bir seçenek koymak, müşteriye tıklayınca hiçbir şey
        // olmayan bir düğme göstermek demektir.
        $yontemler = LocationGate::DEFAULT_PAYMENT_METHODS;
        if ($this->onlineOdemeKullanilabilir()) {
            $yontemler[] = 'online';
        }

        app(LocationGate::class)->seedDefaults($location, 25000, $yontemler);

        $this->components->twoColumnDetail(
            '  catering',
            "#{$location->location_id} {$location->location_name}",
        );

        // TastyIgniter kurulumundan kalan "Default" vitrini API'ye sızıyordu.
        // SİLMİYORUZ — silme geri alınamaz ve bağlı sipariş olabilir.
        // Pasifleştirmek yeterli: katalog ucu `location_status` filtreliyor.
        $deactivated = Location::query()
            ->where('permalink_slug', '!=', 'catering')
            ->where('location_status', true)
            ->update(['location_status' => false]);

        if ($deactivated > 0) {
            $this->components->warn(
                "{$deactivated} adet fazladan vitrin pasifleştirildi (TastyIgniter varsayılanı). ".
                'Silinmedi; admin panelden geri açılabilir.',
            );
        }
    }

    /**
     * Online ödeme sunulabilir mi?
     *
     * Şu an tek geçit simülasyon; gerçek POS gelince bu kontrol ona da
     * bakacak. Sınıf yoksa (eklenti kurulmamışsa) sessizce hayır denir —
     * `veykemtu/payment` isteğe bağlı bir eklentidir.
     */
    private function onlineOdemeKullanilabilir(): bool
    {
        $sinif = 'Veykemtu\\Payment\\Payments\\SimulatedPos';

        if (!class_exists($sinif)) {
            return false;
        }

        $acik = $sinif::isAllowed();

        $this->components->twoColumnDetail(
            '  online ödeme',
            $acik ? 'açık (SİMÜLASYON — gerçek tahsilat yok)' : 'kapalı',
        );

        return $acik;
    }

    /**
     * "Günün Menüsü" paket ürünü — B-19.
     *
     * `order_menus.menu_id` çekirdekte `int NOT NULL` ve `OrderMenu` bir
     * `belongsTo menu` bağıntısı tanımlıyor; paket satırının da geçerli bir
     * ürün kimliği olmalı. `0` yazmak, çekirdeğin ya da ileride bir raporun
     * o bağıntıya dokunduğu ilk anda null-deref demek.
     *
     * ÜÇ ÖZELLİĞİ DE BİLİNÇLİ:
     *
     *   * KATEGORİSİZ. `CatalogController::menu()` yanıtı `$item->categories`
     *     üzerinden kuruyor ve kategorisi olmayan ürünü sessizce düşürüyor —
     *     yani bu kayıt hiçbir vitrine sızamaz, ayrı bir gizleme koduna
     *     gerek yok.
     *   * `menu_status = true`. Mutfak bu kaydı "bugün tükendi"
     *     işaretleyip YALNIZ PAKETİ kapatabilsin, kalemler tek tek
     *     satılmaya devam etsin diye.
     *   * `menu_price = 0.00`. Gerçek fiyat o günün `package_price_kurus`
     *     değeri. `LineResolver` bu kimliği çözülmüş bir gün olmadan
     *     gördüğünde İSTİSNA FIRLATIR, asla ürün fiyatına düşmez.
     */
    private function seedDailyMenuPackage(): void
    {
        $this->components->info('Günün menüsü paket ürünü yazılıyor...');

        $menu = Menu::firstOrNew(['menu_name' => self::DAILY_PACKAGE_NAME]);
        $menu->menu_name = self::DAILY_PACKAGE_NAME;
        $menu->menu_description = 'O günün menüsünün tamamı. Fiyatı takvimden gelir.';
        $menu->menu_price = 0;
        $menu->menu_status = true;
        $menu->minimum_qty = 1;
        $menu->menu_priority = 0;
        $menu->save();

        $menuId = (int) $menu->menu_id;

        foreach (Location::query()->pluck('location_id') as $locationId) {
            // Vitrine bağlanmayan ürün sipariş satırında çözülemez.
            DB::table('locationables')->updateOrInsert([
                'location_id' => $locationId,
                'locationable_id' => $menuId,
                'locationable_type' => 'menus',
            ], ['options' => null]);

            DB::table('location_options')->updateOrInsert(
                ['location_id' => $locationId, 'item' => DailyMenu::PACKAGE_OPTION_KEY],
                ['value' => json_encode($menuId)],
            );
        }

        $this->components->twoColumnDetail('  '.self::DAILY_PACKAGE_NAME, "#{$menuId}");
    }

    private function seedCustomerGroup(): void
    {
        $this->components->info('Müşteri grubu yazılıyor...');

        // Tek grup — öğrenci grubu iptal edildi (docs/00-genel-bakis.md §4).
        $group = CustomerGroup::firstOrNew(['group_name' => 'Catering Müşterisi']);
        $group->group_name = 'Catering Müşterisi';
        $group->save();

        $this->components->twoColumnDetail(
            '  Catering Müşterisi',
            "#{$group->customer_group_id}",
        );

        $this->warnAboutLeftovers(
            CustomerGroup::where('group_name', '!=', 'Catering Müşterisi')->count(),
            'müşteri grubu',
        );
    }

    /**
     * Admin rolleri — docs/04-platform.md §2 madde 4.
     *
     * `Yönetici` rolü yerine süper kullanıcı bayrağı da kullanılabilirdi ama
     * rol kaydı olmadan admin panelde ikinci bir yönetici açmak mümkün olmaz.
     *
     * `permissions` alanı boş bırakılıyor: TastyIgniter izin listesi kurulu
     * eklentilere göre değişir ve buraya sabit bir liste yazmak, eklenti
     * eklendiğinde sessizce eksik kalır. Yönetici izinleri admin panelden
     * verir; komut yalnızca rollerin var olduğunu garanti eder.
     */
    private function seedAdminRoles(): void
    {
        $this->components->info('Admin rolleri yazılıyor...');

        $roles = [
            ['code' => 'yonetici', 'name' => 'Yönetici',
                'description' => 'Tam yetki: menü, fiyat, ayarlar, raporlar.'],
            ['code' => 'operator', 'name' => 'Operatör',
                'description' => 'Sipariş görüntüleme ve durum ilerletme. Menü/fiyat/ayar yetkisi yok.'],
        ];

        foreach ($roles as $definition) {
            $role = UserRole::firstOrNew(['code' => $definition['code']]);
            $role->fill($definition);
            $role->code = $definition['code'];
            $role->save();

            $this->components->twoColumnDetail(
                "  {$definition['code']}",
                "#{$role->user_role_id} {$definition['name']}",
            );
        }
    }

    /**
     * TastyIgniter kurulumundan kalan varsayılan kayıtları bildirir.
     *
     * Silmiyoruz: silme geri alınamaz ve bu kayıtlara bağlı veri olup
     * olmadığını komut bilemez. Karar yöneticinindir.
     */
    private function warnAboutLeftovers(int $count, string $label): void
    {
        if ($count > 0) {
            $this->components->warn(
                "{$count} adet fazladan {$label} var (TastyIgniter varsayılanı). ".
                'API yalnızca bizimkini döndürür; admin panelden silinebilir.',
            );
        }
    }
}
