<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Admin;

use Igniter\Admin\Classes\AdminController;
use Igniter\Admin\Facades\AdminMenu;
use Igniter\Admin\Http\Actions\ListController;
use Igniter\Flame\Exception\FlashException;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Request;
use Veykemtu\BridgeApi\Admin\AdminRegistrar;
use Veykemtu\BridgeApi\Models\PaymentRefund;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * İade takibi — B-15.
 *
 * K-13'te sipariş düzenleme ve iptal iade üretmeye başladı, ama iadelerin
 * gittiği tek yer veritabanıydı. Kartla ödenmiş bir siparişin iadesi
 * sağlayıcıya gidiyor; kapıda ödeme ya da nakit iadeleri ise `manual`
 * durumunda bekliyor ve bir insanın parayı göndermesini gerektiriyor.
 * Görünmeyen bekleme listesi, yapılmayan iştir.
 *
 * SALT LİSTE + TEK EYLEM: iade burada AÇILMAZ (onu `RefundManager` yapar,
 * siparişin kendi akışında). Panelden yapılabilen tek şey, elle gönderilen
 * paranın işaretlenmesi.
 *
 * VARSAYILAN SIRALAMA EN ESKİDEN YENİYE — listelerin çoğunun tersine.
 * Sebep: bu bir gelen kutusu, arşiv değil. En uzun bekleyen iade en tepede
 * durmalı; en yenisi tepede olsaydı, unutulan iade listenin dibine iner ve
 * orada kalırdı.
 */
class Refunds extends AdminController
{
    public array $implement = [
        ListController::class,
    ];

    public array $listConfig = [
        'list' => [
            'model' => PaymentRefund::class,
            'title' => 'lang:veykemtu.bridgeapi::refund.text_title',
            'emptyMessage' => 'lang:veykemtu.bridgeapi::refund.text_empty',
            'defaultSort' => ['created_at', 'ASC'],
            'configFile' => 'refund',
        ],
    ];

    /**
     * PARA HAREKETİ kutusu — bu ekran artık kutunun tek sakini.
     *
     * Yetki eskiden cari hesap ekranlarıyla paylaşılıyordu
     * (`PERMISSION_ACCOUNT` / `Veykemtu.AccountLedger`); cari kalkınca kutu
     * yalnız iadeye kaldı ve adı da onu anlatıyor. Ayrımın kendisi
     * korundu: iade defterini görmek, blog yazmakla aynı yetki olmamalı.
     */
    protected null|string|array $requiredPermissions = AdminRegistrar::PERMISSION_REFUNDS;

    public function __construct()
    {
        parent::__construct();

        AdminMenu::setContext('bld_refunds', AdminRegistrar::CORPORATE_MENU);
    }

    /**
     * Elle gönderilen iadeyi tamamlanmış olarak işaretler.
     *
     * DURUM `succeeded` OLUR, `manual` KALMAZ: `manual` "birinin yapması
     * gerekiyor" demek; iş yapıldıktan sonra o durumda bırakmak listeyi
     * hiç boşalmayan bir bekleme kuyruğuna çevirirdi.
     *
     * `provider_ref` alanına yöneticinin girdiği dekont/havale numarası
     * yazılıyor: gerçek sağlayıcı iadelerinde aynı sütunda sağlayıcının
     * işlem numarası duruyor. İkisi de "bu paranın nereye gittiğinin kanıtı"
     * sorusunu yanıtlıyor, bu yüzden ayrı bir sütun açmadık.
     *
     * ZATEN KAPANMIŞ İADE İKİNCİ KEZ İŞARETLENEMEZ — iki kez para gönderme
     * riskinin panel tarafındaki kapısı bu.
     *
     * KAYIT NUMARASI URL'DEN DEĞİL GÖNDERİDEN OKUNUYOR. Bu bir LİSTE
     * sayfası: adreste kayıt numarası yok ve çekirdek işleyiciye
     * `[$this->action]` (yani `["index"]`) gönderiyor. Numara satırdaki
     * düğmenin `data-request-data` alanından geliyor.
     */
    public function onMarkSettled(): RedirectResponse
    {
        $recordId = Request::post('recordId');

        $refund = PaymentRefund::query()->find((int) $recordId);

        throw_unless($refund instanceof PaymentRefund, new FlashException(
            lang('veykemtu.bridgeapi::refund.alert_missing'),
        ));

        throw_unless($refund->needsAction(), new FlashException(
            lang('veykemtu.bridgeapi::refund.alert_already_settled'),
        ));

        $reference = trim((string) (Request::post('provider_ref') ?? ''));

        $refund->status = PaymentRefund::STATUS_SUCCEEDED;
        $refund->provider_ref = $reference !== '' ? $reference : null;
        $refund->settled_at = BusinessTime::forStorage(BusinessTime::now());
        $refund->save();

        flash()->success(sprintf(
            lang('veykemtu.bridgeapi::refund.alert_settled'),
            $refund->order_id,
        ));

        return $this->redirect(AdminRegistrar::REFUNDS_URI);
    }
}
