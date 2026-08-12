<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Admin;

use Igniter\Admin\Classes\AdminController;
use Igniter\Admin\Facades\AdminMenu;
use Igniter\Admin\Http\Actions\ListController;
use Veykemtu\BridgeApi\Admin\AdminRegistrar;
use Veykemtu\BridgeApi\Models\OrderRevision;

/**
 * Sipariş düzenleme geçmişi — B-17, salt okunur.
 *
 * Mutfak bir siparişi düzenlediğinde (K-12) tam bir önce/sonra anlık
 * görüntüsü yazılıyor ama panelde hiç görünmüyordu. Bu ekran o kaydı
 * yönetime açıyor: hangi sipariş, ne zaman, hangi sebeple, tutar ne kadar
 * değişti ve iade doğdu mu.
 *
 * NE YAZMA NE SİLME: revizyon bir denetim kaydı. Düzenlenebilseydi
 * "müşteri şunu söylüyor, kayıt bunu diyor" tartışmasında hiçbir değeri
 * kalmazdı.
 */
class OrderRevisions extends AdminController
{
    public array $implement = [
        ListController::class,
    ];

    public array $listConfig = [
        'list' => [
            'model' => OrderRevision::class,
            'title' => 'lang:veykemtu.bridgeapi::monitor.revisions_title',
            'emptyMessage' => 'lang:veykemtu.bridgeapi::monitor.revisions_empty',
            'defaultSort' => ['created_at', 'DESC'],
            'configFile' => 'orderrevision',
        ],
    ];

    /**
     * Sipariş yetkisi değil AYAR yetkisi: revizyon kayıtları tutarları ve
     * iade kararlarını gösteriyor — sipariş listesini görmekten daha geniş
     * bir bakış. Kendi kutusunu açmadık çünkü bu ekranı okuyacak kişi
     * zaten işletmeyi yöneten kişi.
     */
    protected null|string|array $requiredPermissions = AdminRegistrar::PERMISSION;

    public function __construct()
    {
        parent::__construct();

        AdminMenu::setContext('bld_order_revisions', 'restaurant');
    }
}
