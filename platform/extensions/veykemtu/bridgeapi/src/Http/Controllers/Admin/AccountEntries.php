<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Admin;

use Igniter\Admin\Classes\AdminController;
use Igniter\Admin\Facades\AdminMenu;
use Igniter\Admin\Http\Actions\ListController;
use Veykemtu\BridgeApi\Admin\AdminRegistrar;
use Veykemtu\BridgeApi\Models\AccountLedgerEntry;

/**
 * Cari hareketler — defterin salt-okunur görünümü (ekstre).
 *
 * Append-only defter panelde de append-only görünür: satır düzenlenmez/
 * silinmez. Hareket girişi (elle tahsilat) `veykemtu:cari-hareket` komutuyla
 * yapılır; sunucuya erişimi olan yönetici zaten artisan komutlarını kullanıyor
 * (RUNBOOK). Bu ekran "kim, ne zaman, ne kadar borç/alacak" sorusunu
 * yanıtlar.
 */
class AccountEntries extends AdminController
{
    public array $implement = [
        ListController::class,
    ];

    public array $listConfig = [
        'list' => [
            'model' => AccountLedgerEntry::class,
            'title' => 'lang:veykemtu.bridgeapi::accountledger.entries_title',
            'emptyMessage' => 'lang:veykemtu.bridgeapi::accountledger.entries_empty',
            'defaultSort' => ['id', 'DESC'],
            'configFile' => 'accountentry',
        ],
    ];

    protected null|string|array $requiredPermissions = AdminRegistrar::PERMISSION_ACCOUNT;

    public function __construct()
    {
        parent::__construct();

        AdminMenu::setContext('bld_account_entries', AdminRegistrar::CORPORATE_MENU);
    }
}
