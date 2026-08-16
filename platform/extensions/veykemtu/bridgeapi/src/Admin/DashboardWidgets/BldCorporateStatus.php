<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Admin\DashboardWidgets;

use Igniter\Admin\Classes\BaseDashboardWidget;
use Override;
use Veykemtu\BridgeApi\Admin\CorporateSnapshot;

/**
 * Gösterge paneli parçacığı: abonelik özeti.
 *
 * Tek soruya cevap verir — "kaç aktif abonelik var, yarın kaç porsiyon
 * üretilecek". Yalnızca çizer; sayılar `CorporateSnapshot`ten gelir.
 *
 * Üçüncü rakam (toplam açık cari bakiye) cari hesapla birlikte kaldırıldı.
 */
class BldCorporateStatus extends BaseDashboardWidget
{
    protected string $defaultAlias = 'bldcorporatestatus';

    #[Override]
    public function render(): string
    {
        $this->vars['bld'] = resolve(CorporateSnapshot::class)->collect();
        $this->vars['subscriptionsUrl'] = admin_url('veykemtu/bridgeapi/subscriptions');

        return $this->makePartial('corporatestatus/corporatestatus');
    }

    #[Override]
    public function defineProperties(): array
    {
        return [];
    }
}
