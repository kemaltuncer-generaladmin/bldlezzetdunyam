<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Admin;

use Igniter\Admin\Classes\AdminController;
use Igniter\Admin\Facades\AdminMenu;
use Igniter\Admin\Http\Actions\ListController;
use Veykemtu\BridgeApi\Admin\AdminRegistrar;
use Veykemtu\BridgeApi\Models\ApiCustomer;

/**
 * Cari hesaplar — kurumsal müşterilerin güncel bakiyesi (salt liste).
 *
 * Mevcut TastyIgniter admin panelinin bir sayfası; çekirdeğin `ListController`
 * eylemini kullanır (tıpkı Teklif Talepleri gibi). Bakiye kaydedilmez, her
 * satırda defterden runtime hesaplanır (`_partials/customeraccounts/
 * column_balance`).
 *
 * OLUŞTURMA/DÜZENLEME YOK: müşteri kaydı çekirdeğin Müşteriler ekranındadır;
 * bu ekran yalnızca cari bakiyeyi gösterir. Hareket girişi ayrı ekrandadır.
 */
class CustomerAccounts extends AdminController
{
    public array $implement = [
        ListController::class,
    ];

    public array $listConfig = [
        'list' => [
            'model' => ApiCustomer::class,
            'title' => 'lang:veykemtu.bridgeapi::accountledger.accounts_title',
            'emptyMessage' => 'lang:veykemtu.bridgeapi::accountledger.accounts_empty',
            'defaultSort' => ['customer_id', 'DESC'],
            'configFile' => 'customeraccount',
        ],
    ];

    protected null|string|array $requiredPermissions = AdminRegistrar::PERMISSION_ACCOUNT;

    public function __construct()
    {
        parent::__construct();

        AdminMenu::setContext('bld_customer_accounts', AdminRegistrar::CORPORATE_MENU);
    }

    /**
     * Yalnızca kurumsal müşteriler listelenir — cari yalnız onlarda anlamlı.
     */
    public function listExtendQuery($query): void
    {
        $query->where('bld_account_type', 'corporate');
    }
}
