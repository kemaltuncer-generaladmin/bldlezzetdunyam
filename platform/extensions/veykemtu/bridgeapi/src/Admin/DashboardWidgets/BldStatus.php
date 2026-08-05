<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Admin\DashboardWidgets;

use Igniter\Admin\Classes\BaseDashboardWidget;
use Override;
use Veykemtu\BridgeApi\Admin\BldSettings;
use Veykemtu\BridgeApi\Admin\OperationsSnapshot;
use Veykemtu\BridgeApi\Support\Money;

/**
 * Gösterge paneli parçacığı: işletmenin o anki durumu tek kutuda.
 *
 * Yalnızca çizer; sayılar `OperationsSnapshot`ten gelir.
 */
class BldStatus extends BaseDashboardWidget
{
    protected string $defaultAlias = 'bldstatus';

    #[Override]
    public function render(): string
    {
        $snapshot = resolve(OperationsSnapshot::class)->collect();

        $this->vars['bld'] = $snapshot;
        $this->vars['revenueToday'] = Money::toDecimal($snapshot['revenue_today_kurus']);
        $this->vars['settingsUrl'] = admin_url(
            'extensions/edit/veykemtu/bridgeapi/'.BldSettings::SETTINGS_CODE,
        );

        return $this->makePartial('bldstatus/bldstatus');
    }

    /**
     * Parçacığın ayarı yoktur.
     *
     * Bilinçli: tarih aralığı veya kart seçimi eklemek, parçacığı çekirdeğin
     * istatistik kartlarının kopyasına çevirirdi. Bu kutu tek bir soruya
     * cevap verir — "şu an ne durumdayız".
     */
    #[Override]
    public function defineProperties(): array
    {
        return [];
    }
}
