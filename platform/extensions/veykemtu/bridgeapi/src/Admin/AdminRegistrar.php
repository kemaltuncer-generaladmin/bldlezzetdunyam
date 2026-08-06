<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Admin;

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

    /** Mutfak kasaları ekranının admin paneldeki adresi. */
    public const string DEVICES_URI = 'veykemtu/bridgeapi/kitchen_devices';

    /** Hizmetler ekranının admin paneldeki adresi. */
    public const string SERVICES_URI = 'veykemtu/bridgeapi/site_services';

    /** Bilgi merkezi yazıları ekranının admin paneldeki adresi. */
    public const string POSTS_URI = 'veykemtu/bridgeapi/site_posts';

    /** İçerik ekranlarının ortak üst menü grubu kodu. */
    public const string CONTENT_MENU = 'bld_content';

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
        ];
    }
}
