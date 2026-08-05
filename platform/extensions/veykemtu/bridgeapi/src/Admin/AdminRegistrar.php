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
