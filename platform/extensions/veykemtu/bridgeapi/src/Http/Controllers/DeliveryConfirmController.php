<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers;

use Igniter\Cart\Models\Order;
use Illuminate\Contracts\View\View;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Services\OrderPresenter;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;
use Veykemtu\BridgeApi\Support\Money;
use Veykemtu\BridgeApi\Support\SignedLink;

/**
 * Kuryenin fişteki QR'ı okutunca açtığı onay sayfası — K-20.
 *
 * NEDEN HTML, JSON DEĞİL: bunu açan şey bir istemci uygulaması değil,
 * kuryenin telefonundaki kamera. Sayfa sunucuda çiziliyor; emsali
 * `veykemtu/payment` içindeki sanal POS simülasyon sayfası.
 *
 * NEDEN KURYE GİRİŞİ YOK: kuryenin sistemde hesabı yok ve olması bu işin
 * on katı bir iş (rol, giriş ekranı, oturum yönetimi). Yetki URL'deki
 * imzada; imza sipariş kimliğine, amaca ve son geçerlilik anına bağlı.
 *
 * KABUL EDİLEN RİSK: fişi fotoğraflayan biri siparişi teslim edilmiş
 * işaretleyebilir. Sınırlı bir zarar (yemek zaten gitti), bağlantı tek
 * kullanımlık ve süresi kısa. Alternatif, kuryeyi kapıda giriş yapmaya
 * zorlamaktı.
 */
class DeliveryConfirmController extends Controller
{
    public function __construct(
        private readonly OrderPresenter $presenter,
        private readonly OrderStatusTransition $transitions,
    ) {}

    public function show(Request $request, int $order): View
    {
        [$model, $state] = $this->resolve($request, $order);

        return $this->render($model, $state, $request);
    }

    public function confirm(Request $request, int $order): View
    {
        [$model, $state] = $this->resolve($request, $order);

        if ($state !== 'confirm') {
            return $this->render($model, $state, $request);
        }

        try {
            $this->transitions->confirmDelivery($model, 'Kurye QR ile teslim onayı');
        } catch (ApiException) {
            /*
             * YARIŞ DURUMU BURADA BİTİYOR. İki kurye (ya da çift dokunuş)
             * aynı anda onaylarsa ikincisi geçersiz geçiş alır. Bu bir hata
             * ekranı değil: iş zaten istenen sonuca varmış durumda.
             */
            return $this->render($model->refresh(), 'already', $request);
        }

        return $this->render($model->refresh(), 'done', $request);
    }

    /**
     * İmzayı doğrular ve sayfanın hangi hâlde çizileceğini söyler.
     *
     * İMZA ÖNCE, VERİTABANI SONRA: geçersiz imza ile var olmayan sipariş
     * ayırt edilememeli, yoksa elinde imza olmayan biri sipariş
     * numaralarını tarayabilirdi.
     *
     * @return array{0: Order|null, 1: string}
     */
    private function resolve(Request $request, int $orderId): array
    {
        $expires = (int) $request->query('e', '0');
        $signature = (string) $request->query('s', '');

        if (!SignedLink::verify(SignedLink::PURPOSE_DELIVER, $orderId, $expires, $signature)) {
            return [null, 'invalid'];
        }

        if (SignedLink::isExpired($expires)) {
            return [null, 'expired'];
        }

        $model = Order::query()->find($orderId);
        if ($model === null) {
            return [null, 'invalid'];
        }

        // Gel-al siparişinde kurye yok; `deliver_url` zaten null üretiliyor,
        // buraya ancak elle gelinir.
        if ($model->order_type !== Order::DELIVERY) {
            return [$model, 'invalid'];
        }

        return [$model, $this->stateFor($model)];
    }

    private function stateFor(Order $model): string
    {
        return match ($this->transitions->codeOf($model)) {
            OrderStatusTransition::DELIVERED => 'already',
            OrderStatusTransition::CANCELLED => 'cancelled',
            OrderStatusTransition::READY, OrderStatusTransition::ON_THE_WAY => 'confirm',
            // `yeni` / `onaylandi` / `hazirlaniyor`: yemek daha çıkmadı.
            default => 'too_early',
        };
    }

    private function render(?Order $model, string $state, Request $request): View
    {
        $collect = 0;
        if ($model !== null && !(bool) $model->processed) {
            $collect = Money::toKurus($model->order_total);
        }

        return view('veykemtu.bridgeapi::delivery.confirm', [
            'state' => $state,
            'orderNumber' => $model === null ? null : $this->presenter->number($model),
            'customerName' => $model === null ? null : $this->presenter->customerName($model),
            'address' => $model === null ? null : $this->presenter->address($model),
            'collectKurus' => $collect,
            'expires' => (string) $request->query('e', ''),
            'signature' => (string) $request->query('s', ''),
        ]);
    }
}
