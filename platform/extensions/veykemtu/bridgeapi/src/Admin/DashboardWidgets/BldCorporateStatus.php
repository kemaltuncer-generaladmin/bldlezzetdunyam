<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Admin\DashboardWidgets;

use Igniter\Admin\Classes\BaseDashboardWidget;
use Override;
use Veykemtu\BridgeApi\Admin\CorporateSnapshot;

/**
 * Gösterge paneli parçacığı: kurumsal (abonelik + cari) özet.
 *
 * Tek soruya cevap verir — "kaç aktif abonelik var, yarın kaç porsiyon
 * üretilecek, toplam açık cari bakiye ne". Yalnızca çizer; sayılar
 * `CorporateSnapshot`ten gelir.
 */
class BldCorporateStatus extends BaseDashboardWidget
{
    protected string $defaultAlias = 'bldcorporatestatus';

    #[Override]
    public function render(): string
    {
        $snapshot = resolve(CorporateSnapshot::class)->collect();

        $this->vars['bld'] = $snapshot;
        $this->vars['openBalance'] = $snapshot['open_balance_kurus'] / 100;
        $this->vars['subscriptionsUrl'] = admin_url('veykemtu/bridgeapi/subscriptions');
        $this->vars['accountsUrl'] = admin_url('veykemtu/bridgeapi/customer_accounts');

        return $this->makePartial('corporatestatus/corporatestatus');
    }

    #[Override]
    public function defineProperties(): array
    {
        return [];
    }
}
