<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Admin;

use Igniter\Admin\Classes\AdminController;
use Igniter\Admin\Facades\AdminMenu;
use Igniter\Admin\Http\Actions\ListController;
use Veykemtu\BridgeApi\Admin\AdminRegistrar;
use Veykemtu\BridgeApi\Models\MenuSoldOut;

/**
 * Günlük "tükendi" geçmişi — B-17, salt okunur.
 *
 * Mutfağın gün içinde satıştan kaldırdığı ürünler (K-11) ertesi gün
 * kendiliğinden geri geliyor, yani hiçbir yerde birikmiyordu. Bu liste
 * birikimi gösteriyor: aynı ürün her hafta bitiyorsa sorun stokta değil
 * planlamada.
 *
 * BUGÜNÜN SATIŞINA BURADAN MÜDAHALE EDİLMEZ. O karar mutfağın
 * (`Services\MenuAvailability`); panelin de aynı anda karar vermesi, iki
 * ekranın birbirini ezmesi demek olurdu.
 */
class MenuSoldOuts extends AdminController
{
    public array $implement = [
        ListController::class,
    ];

    public array $listConfig = [
        'list' => [
            'model' => MenuSoldOut::class,
            'title' => 'lang:veykemtu.bridgeapi::monitor.soldout_title',
            'emptyMessage' => 'lang:veykemtu.bridgeapi::monitor.soldout_empty',
            'defaultSort' => ['sold_out_on', 'DESC'],
            'configFile' => 'menusoldout',
        ],
    ];

    protected null|string|array $requiredPermissions = AdminRegistrar::PERMISSION;

    public function __construct()
    {
        parent::__construct();

        AdminMenu::setContext('bld_menu_soldout', 'restaurant');
    }
}
