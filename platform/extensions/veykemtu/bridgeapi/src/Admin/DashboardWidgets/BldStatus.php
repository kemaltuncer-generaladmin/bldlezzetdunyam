<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Admin\DashboardWidgets;

use Igniter\Admin\Classes\BaseDashboardWidget;
use Illuminate\Support\Carbon;
use Override;
use Veykemtu\BridgeApi\Admin\AdminRegistrar;
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
        $this->vars['missingMenuLabel'] = $this->humanDays($snapshot['missing_menu_days']);
        $this->vars['dailyMenusUrl'] = admin_url(AdminRegistrar::DAILY_MENUS_URI);

        return $this->makePartial('bldstatus/bldstatus');
    }

    /**
     * Gün listesini Türkçe okunur tek satıra çevirir: "15, 17 ve 18 Ağustos".
     *
     * NEDEN PARÇACIKTA, `OperationsSnapshot`TE DEĞİL: hangi günlerin eksik
     * olduğu iş kuralı (ve orada test ediliyor); o günlerin nasıl yazıldığı
     * çizim. Ay adı yalnız grup sonunda tekrarlanıyor — yedi günlük bir
     * boşlukta "15 Ağustos, 16 Ağustos, 17 Ağustos..." satırı kutuyu taşırdı.
     *
     * @param  list<string>  $days  `YYYY-AA-GG`
     */
    private function humanDays(array $days): string
    {
        if ($days === []) {
            return '';
        }

        /** @var array<string, list<string>> $byMonth */
        $byMonth = [];

        foreach ($days as $day) {
            $date = Carbon::parse($day)->locale('tr');
            $byMonth[$date->isoFormat('MMMM')][] = $date->isoFormat('D');
        }

        $groups = [];
        foreach ($byMonth as $month => $numbers) {
            $groups[] = implode(', ', $numbers).' '.$month;
        }

        return implode(' — ', $groups);
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
