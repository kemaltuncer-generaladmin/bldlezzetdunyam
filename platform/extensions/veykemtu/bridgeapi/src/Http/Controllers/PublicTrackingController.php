<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers;

use Igniter\Cart\Models\Order;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Services\OrderPresenter;
use Veykemtu\BridgeApi\Support\SignedLink;

/**
 * Fişteki takip QR'ının arkasındaki uç — K-20.
 *
 * NEDEN AYRI DENETLEYİCİ: `OrderController` tümüyle `bld.auth` +
 * `bld.scope:customer` grubunun içinde yaşıyor ve her metodu oturumdaki
 * müşteriye güveniyor. Kimliksiz bir eylemi o sınıfın içine katmak, ileride
 * birinin ortak bir yardımcıya `$request->user()` eklemesiyle null
 * başvurusuna dönerdi. Ayrı sınıf, yetki sınırını bir dosya gerçeği yapıyor.
 *
 * NEDEN GİRİŞSİZ: eski takip bağlantısı `/siparis/{id}` idi ve o sayfa
 * oturum istiyordu; fişteki kareyi okutan müşteri sipariş durumunu değil
 * giriş ekranını görüyordu. Kâğıda basılan bir QR giriş isteyemez.
 */
class PublicTrackingController extends ApiController
{
    public function __construct(private readonly OrderPresenter $presenter) {}

    public function show(Request $request, int $order): JsonResponse
    {
        /*
         * İMZA ÖNCE, VERİTABANI SONRA.
         *
         * Sıra ters olsaydı, var olmayan sipariş `404`, var olan ama imzası
         * bozuk sipariş `403` dönerdi; ikisinin farkı, elinde imza olmayan
         * birine hangi sipariş numaralarının var olduğunu söylerdi. Aynı
         * disiplin `KitchenController::pair()` içinde de yazılı.
         */
        $this->assertSignature($request, $order);

        $model = Order::query()->find($order);
        if ($model === null) {
            throw ApiException::notFound('Sipariş bulunamadı.');
        }

        // SARMALANMIYOR — `GET /orders/{id}` ile aynı biçim. Sözleşmedeki
        // `200` şeması doğrudan `PublicOrderTracking`.
        return $this->json($this->presenter->publicTracking($model));
    }

    /**
     * `?e=` ve `?s=` doğrulaması.
     *
     * BOZUK İMZA İLE SÜRESİ DOLMUŞ BAĞLANTI AYNI KODU DÖNER. Ayırmak,
     * elinde geçersiz bağlantı olan kişiye "imza doğruydu ama süresi geçti"
     * bilgisini verirdi; mesaj farkı yeterli, kod farkı değil.
     *
     * @throws ApiException
     */
    private function assertSignature(Request $request, int $orderId): void
    {
        $expires = (int) $request->query('e', '0');
        $signature = (string) $request->query('s', '');

        if (!SignedLink::verify(SignedLink::PURPOSE_TRACK, $orderId, $expires, $signature)) {
            throw ApiException::forbidden('Takip bağlantısı geçersiz.');
        }

        if (SignedLink::isExpired($expires)) {
            throw ApiException::forbidden(
                'Takip bağlantısının süresi doldu. Siparişlerim sayfasından bakabilirsiniz.',
            );
        }
    }
}
