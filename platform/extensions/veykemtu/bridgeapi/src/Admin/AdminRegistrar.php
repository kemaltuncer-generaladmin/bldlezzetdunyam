<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Admin;

use Veykemtu\BridgeApi\Admin\DashboardWidgets\BldCorporateStatus;
use Veykemtu\BridgeApi\Admin\DashboardWidgets\BldStatus;

/**
 * Eklentinin admin panel yüzeylerinin kayıt tanımları.
 *
 * `Extension.php` bu sınıfın statik metotlarını doğrudan döndürür. Tanımların
 * ayrı bir dosyada durmasının sebebi `Extension.php`'nin API tarafıyla
 * (rotalar, ara katmanlar, oran sınırları) admin tarafını aynı dosyada
 * büyütmemesi; iki taraf farklı zamanlarda ve farklı sebeplerle değişiyor.
 */
final class AdminRegistrar
{
    /** Ayarlar ekranına erişim yetkisi. */
    public const string PERMISSION = 'Veykemtu.BldSettings';

    /**
     * Mutfak kasaları ekranına erişim yetkisi — AYRI, çünkü kapsamı farklı.
     *
     * Bu yetkiyi taşıyan kişi kasaya "yeniden başlat" gönderebilir ve bir
     * cihazı iptal edip mutfağı sipariş göremez hâle getirebilir. Fiyat ve
     * şalter yetkisiyle (`PERMISSION`) aynı kutuya konsaydı, birini vermek
     * istediğinde diğerini de vermek zorunda kalınırdı.
     */
    public const string PERMISSION_DEVICES = 'Veykemtu.KitchenDevices';

    /**
     * Kurumsal site içeriği ekranlarına erişim yetkisi — ÜÇÜNCÜ bir kutu.
     *
     * İçerik yazan kişi ile işletmeyi yöneten kişi aynı kişi değil. Hizmet
     * metni veya blog yazısı girmek için panele alınan biri, `PERMISSION`
     * verilseydi asgari sepet tutarını ve sipariş alım şalterini de
     * değiştirebilirdi; `PERMISSION_DEVICES` verilseydi mutfak kasasını iptal
     * edip servisi durdurabilirdi. İçerik hatası geri alınabilir, o ikisi
     * ciro kaybettirir — bu yüzden ayrı yetki.
     */
    public const string PERMISSION_CONTENT = 'Veykemtu.SiteContent';

    /**
     * Teklif talepleri ekranına erişim yetkisi — DÖRDÜNCÜ kutu.
     *
     * `PERMISSION_CONTENT` yeniden kullanılmadı ve gerekçesi tek kelime:
     * KİŞİSEL VERİ. İçerik yetkisi, herkese açık pazarlama metinlerini
     * yazma yetkisidir — o metinlerin tamamı zaten sitede yayında, yani
     * yetkiyi vermek hiçbir mahremiyet kararı içermez. Teklif talepleri ise
     * ad, telefon ve e-posta taşıyor: sistemdeki tek "müşteri olmayan kişi"
     * havuzu. İki ekranı aynı kutuya koymak, blog yazısı girmesi için panele
     * alınan serbest çalışan bir metin yazarına firmanın bütün satış
     * adaylarının iletişim listesini açmak olurdu; KVKK'nın "erişim en dar
     * çevreyle sınırlanır" ilkesi bunun tersini söylüyor.
     *
     * Menüde yine de İçerikler grubunun altında duruyor: kaynağı sitedir ve
     * yöneticinin onu arayacağı yer orasıdır. Menü YERİ ile erişim KUTUSU
     * ayrı sorular.
     */
    public const string PERMISSION_QUOTES = 'Veykemtu.QuoteRequests';

    /**
     * Cari hesap ekranlarına erişim yetkisi — BEŞİNCİ kutu.
     *
     * PARA HAREKETİ. Cari bakiye ve hareketler, hangi kurumsal müşterinin ne
     * kadar borcu olduğunu gösterir — ticari olarak hassas veri. İçerik veya
     * teklif yetkisiyle aynı kutuya konsaydı, blog yazan birine tüm müşteri
     * bakiyeleri açılırdı. Ayrı yetki, "en dar çevre" ilkesinin gereği.
     */
    public const string PERMISSION_ACCOUNT = 'Veykemtu.AccountLedger';

    /**
     * Abonelik ekranlarına erişim yetkisi — ALTINCI kutu.
     *
     * Cari (para hareketi) ile abonelik (sipariş üreten kural + fiyatlandırma)
     * farklı işler: satış ekibi aboneliği fiyatlandırır, muhasebe cariyi
     * yönetir. Ayrı yetki, "en dar çevre" ilkesi.
     */
    public const string PERMISSION_SUBSCRIPTIONS = 'Veykemtu.Subscriptions';

    /** Mutfak kasaları ekranının admin paneldeki adresi. */
    public const string DEVICES_URI = 'veykemtu/bridgeapi/kitchen_devices';

    /** Hizmetler ekranının admin paneldeki adresi. */
    public const string SERVICES_URI = 'veykemtu/bridgeapi/site_services';

    /** Bilgi merkezi yazıları ekranının admin paneldeki adresi. */
    public const string POSTS_URI = 'veykemtu/bridgeapi/site_posts';

    /** Teklif talepleri ekranının admin paneldeki adresi. */
    public const string QUOTES_URI = 'veykemtu/bridgeapi/quote_requests';

    /** İçerik ekranlarının ortak üst menü grubu kodu. */
    public const string CONTENT_MENU = 'bld_content';

    /** Cari hesaplar ekranının admin paneldeki adresi. */
    public const string ACCOUNTS_URI = 'veykemtu/bridgeapi/customer_accounts';

    /** Cari hareketler ekranının admin paneldeki adresi. */
    public const string ACCOUNT_ENTRIES_URI = 'veykemtu/bridgeapi/account_entries';

    /** Abonelikler ekranının admin paneldeki adresi. */
    public const string SUBSCRIPTIONS_URI = 'veykemtu/bridgeapi/subscriptions';

    /** Kapalı günler ekranının admin paneldeki adresi. */
    public const string CLOSED_DAYS_URI = 'veykemtu/bridgeapi/closed_days';

    /** Kurumsal (cari/abonelik) ekranların ortak üst menü grubu kodu. */
    public const string CORPORATE_MENU = 'bld_corporate';

    private function __construct() {}

    /**
     * Ayarlar → Eklentiler altındaki "BLD Ayarları" girdisi.
     *
     * Sayfayı çekirdeğin `Extensions::edit` ucu çizer; kendi denetleyicimizi
     * yazmıyoruz. Adres: `admin/extensions/edit/veykemtu/bridgeapi/settings`.
     *
     * @return array<string, array<string, mixed>>
     */
    public static function registerSettings(): array
    {
        return [
            BldSettings::SETTINGS_CODE => [
                'label' => 'lang:veykemtu.bridgeapi::default.settings.label',
                'description' => 'lang:veykemtu.bridgeapi::default.settings.description',
                'icon' => 'fa fa-sliders',
                'priority' => 10,
                'permissions' => [self::PERMISSION],
                'model' => BldSettings::class,
            ],
            /*
             * Site İçeriği de bir "ayar sayfası" olarak kaydediliyor çünkü
             * kayıt değil, sınırlı sayıda alanın tek formda düzenlenmesi —
             * hizmet ve yazılar gibi liste ekranı gerektirmiyor. Yetkisi
             * `PERMISSION_CONTENT`: içerik yazan kişi fiyat ve şaltere
             * dokunamamalı.
             */
            SiteContentSettings::SETTINGS_CODE => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.title',
                'description' => 'lang:veykemtu.bridgeapi::sitecontent.section_brand_comment',
                'icon' => 'fa fa-newspaper',
                'priority' => 20,
                'permissions' => [self::PERMISSION_CONTENT],
                'model' => SiteContentSettings::class,
            ],
        ];
    }

    /**
     * Yan menüde "Restoran" altına kısayol.
     *
     * NEDEN SİSTEM ALTINA DEĞİL: bunlar günlük işletme anahtarlarıdır
     * (yoğunluk, kesim saati), kurulum ayarı değil. Ayarlar → Eklentiler
     * yolundan geçmek zorunda kalan yönetici, yoğun bir öğle servisinde
     * yoğunluk anahtarını bulamaz.
     *
     * @return array<string, array<string, mixed>>
     */
    public static function registerNavigation(): array
    {
        return [
            'restaurant' => [
                'child' => [
                    'bld_settings' => [
                        'priority' => 90,
                        'class' => 'bld_settings',
                        'href' => admin_url('extensions/edit/veykemtu/bridgeapi/'.BldSettings::SETTINGS_CODE),
                        'title' => lang('veykemtu.bridgeapi::default.side_menu.settings'),
                        'permission' => self::PERMISSION,
                    ],
                    // Kasa yönetimi de günlük işletme işidir: yazıcı sustuğunda
                    // veya alarm çalmaya devam ettiğinde yöneticinin bu sayfayı
                    // Ayarlar → Eklentiler yolunu izleyerek araması gerekmemeli.
                    'bld_kitchen_devices' => [
                        'priority' => 91,
                        'class' => 'bld_kitchen_devices',
                        'href' => admin_url(self::DEVICES_URI),
                        'title' => lang('veykemtu.bridgeapi::default.side_menu_devices'),
                        'permission' => self::PERMISSION_DEVICES,
                    ],
                ],
            ],

            /*
             * KENDİ ÜST GRUBU — "Restoran"ın altına DEĞİL.
             *
             * "Restoran" başlığı işletmenin günlük işini taşıyor (menüler,
             * konumlar, kasalar, şalterler). Kurumsal sitenin metinleri o işin
             * parçası değil: farklı kişi girer, farklı sıklıkta değişir ve
             * yanlış girildiğinde servis durmaz. Aynı başlığa konsalardı hem
             * liste on maddeye çıkardı hem de içerik yetkisi olan kişiye
             * dokunamayacağı beş ekran gösterilmiş olurdu.
             *
             * ÇOCUKLARIN HEPSİNDE `priority` VAR, ÇÜNKÜ ZORUNLU: çekirdek
             * hem `child` hem de kendi anahtarları olan bir grup tanımında
             * üst girdiyi ham diziyle EZİYOR (`Navigation::registerNavItems`
             * → `addNavItem`), yani çocuklar `$navItemDefaults` ile
             * birleştirilmeden saklanıyor. `getVisibleNavItems` çocukları
             * `priority` alanına göre sıralıyor; alan yazılmasaydı menü
             * çizilirken tanımsız anahtar hatası verirdi.
             */
            self::CONTENT_MENU => [
                // 40 "Restoran", 50 "Pazarlama". İçerik ikisinin arasına
                // giriyor: sipariş akışından sonra, kampanyalardan önce.
                'priority' => 45,
                'class' => self::CONTENT_MENU,
                'icon' => 'fa-newspaper',
                'title' => lang('veykemtu.bridgeapi::default.side_menu.content'),
                'child' => [
                    /*
                     * En üstte: marka ve iletişim en sık aranan bilgi. Hizmet
                     * ve yazı ekranlarının altında kalsaydı, telefon numarasını
                     * güncellemek isteyen yönetici önce blog listesini görürdü.
                     */
                    'bld_site_content' => [
                        'priority' => 5,
                        'class' => 'bld_site_content',
                        'href' => admin_url(
                            'extensions/edit/veykemtu/bridgeapi/'.SiteContentSettings::SETTINGS_CODE,
                        ),
                        'title' => lang('veykemtu.bridgeapi::sitecontent.title'),
                        'permission' => self::PERMISSION_CONTENT,
                    ],
                    'bld_site_services' => [
                        'priority' => 10,
                        'class' => 'bld_site_services',
                        'href' => admin_url(self::SERVICES_URI),
                        'title' => lang('veykemtu.bridgeapi::default.side_menu.services'),
                        'permission' => self::PERMISSION_CONTENT,
                    ],
                    'bld_site_posts' => [
                        'priority' => 20,
                        'class' => 'bld_site_posts',
                        'href' => admin_url(self::POSTS_URI),
                        'title' => lang('veykemtu.bridgeapi::default.side_menu.posts'),
                        'permission' => self::PERMISSION_CONTENT,
                    ],
                    /*
                     * EN ALTTA VE AYRI YETKİYLE. Üstündeki üç girdi içerik
                     * ÜRETİR, bu girdi içeriğin GETİRDİĞİNİ toplar; yönü
                     * ters olduğu için listenin sonunda duruyor. Yetkisi de
                     * ayrı: gerekçe `PERMISSION_QUOTES` üzerinde.
                     */
                    'bld_quote_requests' => [
                        'priority' => 30,
                        'class' => 'bld_quote_requests',
                        'href' => admin_url(self::QUOTES_URI),
                        'title' => lang('veykemtu.bridgeapi::quoterequest.side_menu'),
                        'permission' => self::PERMISSION_QUOTES,
                    ],
                ],
            ],

            /*
             * KURUMSAL üst grubu — cari hesap (ve ileride abonelik) ekranları.
             *
             * "İçerikler"in (45) hemen ardında (46): sipariş/içerik akışından
             * sonra, kurumsal muhasebe yüzeyi. Kendi yetkisi (`PERMISSION_ACCOUNT`)
             * ve kendi grubu — para hareketi verisi içerik/teklifle karışmaz.
             * Çocukların hepsinde `priority` zorunlu (CONTENT_MENU gerekçesi).
             */
            self::CORPORATE_MENU => [
                'priority' => 46,
                'class' => self::CORPORATE_MENU,
                'icon' => 'fa-building',
                'title' => lang('veykemtu.bridgeapi::accountledger.side_menu_group'),
                'child' => [
                    'bld_subscriptions' => [
                        'priority' => 5,
                        'class' => 'bld_subscriptions',
                        'href' => admin_url(self::SUBSCRIPTIONS_URI),
                        'title' => lang('veykemtu.bridgeapi::subscription.side_menu'),
                        'permission' => self::PERMISSION_SUBSCRIPTIONS,
                    ],
                    'bld_customer_accounts' => [
                        'priority' => 10,
                        'class' => 'bld_customer_accounts',
                        'href' => admin_url(self::ACCOUNTS_URI),
                        'title' => lang('veykemtu.bridgeapi::accountledger.side_menu_accounts'),
                        'permission' => self::PERMISSION_ACCOUNT,
                    ],
                    'bld_account_entries' => [
                        'priority' => 20,
                        'class' => 'bld_account_entries',
                        'href' => admin_url(self::ACCOUNT_ENTRIES_URI),
                        'title' => lang('veykemtu.bridgeapi::accountledger.side_menu_entries'),
                        'permission' => self::PERMISSION_ACCOUNT,
                    ],
                    'bld_closed_days' => [
                        'priority' => 30,
                        'class' => 'bld_closed_days',
                        'href' => admin_url(self::CLOSED_DAYS_URI),
                        'title' => lang('veykemtu.bridgeapi::subscription.closed_side_menu'),
                        'permission' => self::PERMISSION_SUBSCRIPTIONS,
                    ],
                ],
            ],
        ];
    }

    /**
     * `Operatör` rolü bu yetkiyi ALMAZ (`docs/04-platform.md` §2.4): sipariş
     * görüntüleyip durum ilerletebilir, ama fiyat ve şalterlere dokunamaz.
     *
     * @return array<string, array<string, string>>
     */
    public static function registerPermissions(): array
    {
        return [
            self::PERMISSION => [
                'label' => 'lang:veykemtu.bridgeapi::default.permission_settings',
                'group' => 'igniter::admin.permissions.name',
            ],
            self::PERMISSION_DEVICES => [
                'label' => 'lang:veykemtu.bridgeapi::default.permission_devices',
                'group' => 'igniter::admin.permissions.name',
            ],
            self::PERMISSION_CONTENT => [
                'label' => 'lang:veykemtu.bridgeapi::default.permission_content',
                'group' => 'igniter::admin.permissions.name',
            ],
            self::PERMISSION_QUOTES => [
                'label' => 'lang:veykemtu.bridgeapi::quoterequest.permission',
                'group' => 'igniter::admin.permissions.name',
            ],
            self::PERMISSION_ACCOUNT => [
                'label' => 'lang:veykemtu.bridgeapi::accountledger.permission',
                'group' => 'igniter::admin.permissions.name',
            ],
            self::PERMISSION_SUBSCRIPTIONS => [
                'label' => 'lang:veykemtu.bridgeapi::subscription.permission',
                'group' => 'igniter::admin.permissions.name',
            ],
        ];
    }

    /**
     * @return array<class-string, array<string, mixed>>
     */
    public static function registerDashboardWidgets(): array
    {
        return [
            BldStatus::class => [
                'label' => 'lang:veykemtu.bridgeapi::default.dashboard.label',
                'context' => 'dashboard',
            ],
            BldCorporateStatus::class => [
                'label' => 'lang:veykemtu.bridgeapi::subscription.dashboard_label',
                'context' => 'dashboard',
            ],
        ];
    }
}
