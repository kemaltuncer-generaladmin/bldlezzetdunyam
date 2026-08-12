<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Order;
use Illuminate\Support\Facades\DB;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;
use Veykemtu\BridgeApi\Support\SignedLink;

/**
 * Kuryenin fişteki QR'la verdiği teslim onayı — K-20.
 *
 * EN KRİTİK İKİ TEST:
 *
 * 1. `test_hazir_durumdaki_siparis_once_yolda_yazilir` — fiş `hazir`da
 *    basılıyor ama durum makinesi adrese gönderimde `hazir ->
 *    teslim_edildi` geçişini reddediyor. İki adımlı yürüyüş bu yüzden var;
 *    matris gevşetilmedi.
 * 2. `test_ayni_baglanti_ikinci_kez_kullanilamaz` — tek kullanımlık olması
 *    ayrı bir bayrakla değil, `teslim_edildi`nin terminal olmasıyla
 *    sağlanıyor.
 */
class DeliveryConfirmTest extends KitchenTestCase
{
    private const string SECRET = 'test-baglanti-sirri-0123456789abcdef';

    protected function setUp(): void
    {
        parent::setUp();

        putenv('BLD_LINK_SECRET='.self::SECRET);
        $_ENV['BLD_LINK_SECRET'] = self::SECRET;
    }

    protected function tearDown(): void
    {
        putenv('BLD_LINK_SECRET');
        unset($_ENV['BLD_LINK_SECRET']);

        parent::tearDown();
    }

    public function test_kurye_qr_ile_siparisi_teslim_edildi_yapar(): void
    {
        $orderId = $this->orderAt([
            OrderStatusTransition::CONFIRMED,
            OrderStatusTransition::PREPARING,
            OrderStatusTransition::READY,
            OrderStatusTransition::ON_THE_WAY,
        ]);

        $this->post($this->deliverUrl($orderId), $this->form($orderId))
            ->assertOk()
            ->assertSee('Teslim alındı');

        $this->assertSame(
            OrderStatusTransition::DELIVERED,
            $this->statusOf($orderId),
        );
    }

    /**
     * `hazir` durumundaki sipariş önce `yolda` yazılır, sonra teslim edilir.
     *
     * Fiş `hazir`da basılıyor ve mutfakta kimse "yolda" düğmesine basmamış
     * olabilir. Matrisi gevşetmek `yolda` adımını atlama iznini BÜTÜN
     * istemcilere verirdi; onun yerine burada iki dürüst geçiş yapılıyor.
     */
    public function test_hazir_durumdaki_siparis_once_yolda_yazilir(): void
    {
        $orderId = $this->orderAt([
            OrderStatusTransition::CONFIRMED,
            OrderStatusTransition::PREPARING,
            OrderStatusTransition::READY,
        ]);

        $this->post($this->deliverUrl($orderId), $this->form($orderId))->assertOk();

        $this->assertSame(OrderStatusTransition::DELIVERED, $this->statusOf($orderId));
        $this->assertContains(
            OrderStatusTransition::ON_THE_WAY,
            $this->historyOf($orderId),
            'kurye gerçekten yola çıktı; geçmiş bunu göstermeli',
        );
    }

    /**
     * TEK KULLANIMLIK. İkinci okutma siparişe dokunmuyor ve HATA EKRANI
     * göstermiyor: çift dokunan kurye kırmızı ekran görmemeli, iş olmuş.
     */
    public function test_ayni_baglanti_ikinci_kez_kullanilamaz(): void
    {
        $orderId = $this->orderAt([
            OrderStatusTransition::CONFIRMED,
            OrderStatusTransition::PREPARING,
            OrderStatusTransition::READY,
            OrderStatusTransition::ON_THE_WAY,
        ]);

        $this->post($this->deliverUrl($orderId), $this->form($orderId))->assertOk();
        $historyAfterFirst = $this->historyOf($orderId);

        $this->post($this->deliverUrl($orderId), $this->form($orderId))
            ->assertOk()
            ->assertSee('zaten teslim edildi');

        $this->assertSame(
            $historyAfterFirst,
            $this->historyOf($orderId),
            'ikinci okutma yeni bir durum kaydı açmamalı',
        );
    }

    public function test_teslim_onayi_status_history_yorumu_birakir(): void
    {
        $orderId = $this->orderAt([
            OrderStatusTransition::CONFIRMED,
            OrderStatusTransition::PREPARING,
            OrderStatusTransition::READY,
            OrderStatusTransition::ON_THE_WAY,
        ]);

        $this->post($this->deliverUrl($orderId), $this->form($orderId))->assertOk();

        $comments = DB::table('status_history')
            ->where('object_id', $orderId)
            ->where('object_type', 'orders')
            ->pluck('comment')
            ->filter()
            ->all();

        $this->assertContains(
            'Kurye QR ile teslim onayı',
            $comments,
            'nasıl kapandığının tek izi bu yorum',
        );
    }

    public function test_iptal_edilmis_siparis_teslim_edilemez(): void
    {
        $orderId = $this->orderAt([
            OrderStatusTransition::CONFIRMED,
            OrderStatusTransition::CANCELLED,
        ]);

        $this->post($this->deliverUrl($orderId), $this->form($orderId))
            ->assertOk()
            ->assertSee('iptal edilmiş');

        $this->assertSame(OrderStatusTransition::CANCELLED, $this->statusOf($orderId));
    }

    public function test_hazir_olmayan_siparis_teslim_edilemez(): void
    {
        $orderId = $this->orderAt([OrderStatusTransition::CONFIRMED]);

        $this->post($this->deliverUrl($orderId), $this->form($orderId))
            ->assertOk()
            ->assertSee('henüz hazır değil');

        $this->assertSame(OrderStatusTransition::CONFIRMED, $this->statusOf($orderId));
    }

    public function test_gecersiz_imza_siparisi_degistirmez(): void
    {
        $orderId = $this->orderAt([
            OrderStatusTransition::CONFIRMED,
            OrderStatusTransition::PREPARING,
            OrderStatusTransition::READY,
            OrderStatusTransition::ON_THE_WAY,
        ]);

        $expires = time() + 3600;

        $this->post("/teslimat/{$orderId}?e={$expires}&s=uydurma", [
            'e' => (string) $expires,
            's' => 'uydurma',
        ])->assertOk()->assertSee('Bağlantı geçersiz');

        $this->assertSame(OrderStatusTransition::ON_THE_WAY, $this->statusOf($orderId));
    }

    public function test_suresi_dolmus_baglanti_reddedilir(): void
    {
        $orderId = $this->orderAt([
            OrderStatusTransition::CONFIRMED,
            OrderStatusTransition::PREPARING,
            OrderStatusTransition::READY,
            OrderStatusTransition::ON_THE_WAY,
        ]);

        $expires = time() - 60;
        $signature = SignedLink::sign(SignedLink::PURPOSE_DELIVER, $orderId, $expires);

        $this->get("/teslimat/{$orderId}?e={$expires}&s={$signature}")
            ->assertOk()
            ->assertSee('süresi doldu');

        $this->assertSame(OrderStatusTransition::ON_THE_WAY, $this->statusOf($orderId));
    }

    /** Takip imzası teslim sayfasında geçmez — amaç imzanın içinde. */
    public function test_takip_imzasi_teslim_sayfasinda_kabul_edilmez(): void
    {
        $orderId = $this->orderAt([
            OrderStatusTransition::CONFIRMED,
            OrderStatusTransition::PREPARING,
            OrderStatusTransition::READY,
            OrderStatusTransition::ON_THE_WAY,
        ]);

        $expires = time() + 3600;
        $signature = SignedLink::sign(SignedLink::PURPOSE_TRACK, $orderId, $expires);

        $this->get("/teslimat/{$orderId}?e={$expires}&s={$signature}")
            ->assertOk()
            ->assertSee('Bağlantı geçersiz');
    }

    /** Gel-al siparişinde kurye yok; sayfa açılmamalı. */
    public function test_gel_al_siparisi_teslim_sayfasi_acmaz(): void
    {
        $orderId = $this->orderAt(
            [OrderStatusTransition::CONFIRMED, OrderStatusTransition::PREPARING,
                OrderStatusTransition::READY],
            deliveryType: 'pickup',
        );

        $this->get($this->deliverUrl($orderId))
            ->assertOk()
            ->assertSee('Bağlantı geçersiz');
    }

    /** Onay sayfası tahsil edilecek tutarı gösterir — kuryenin ilk sorusu. */
    public function test_onay_sayfasi_tahsil_edilecek_tutari_gosterir(): void
    {
        $orderId = $this->orderAt([
            OrderStatusTransition::CONFIRMED,
            OrderStatusTransition::PREPARING,
            OrderStatusTransition::READY,
        ]);

        $this->get($this->deliverUrl($orderId))
            ->assertOk()
            ->assertSee('Tahsil edilecek')
            ->assertSee('TESLİM ETTİM');
    }

    private function deliverUrl(int $orderId): string
    {
        $expires = time() + 3600;
        $signature = SignedLink::sign(SignedLink::PURPOSE_DELIVER, $orderId, $expires);

        return "/teslimat/{$orderId}?e={$expires}&s={$signature}";
    }

    /** @return array<string, string> */
    private function form(int $orderId): array
    {
        $expires = time() + 3600;

        return [
            'e' => (string) $expires,
            's' => SignedLink::sign(SignedLink::PURPOSE_DELIVER, $orderId, $expires),
        ];
    }

    private function statusOf(int $orderId): string
    {
        return app(OrderStatusTransition::class)->codeOf(Order::findOrFail($orderId));
    }

    /** @return list<string> */
    private function historyOf(int $orderId): array
    {
        return DB::table('status_history')
            ->join('statuses', 'statuses.status_id', '=', 'status_history.status_id')
            ->where('status_history.object_id', $orderId)
            ->where('status_history.object_type', 'orders')
            ->orderBy('status_history.status_history_id')
            ->pluck('statuses.status_code')
            ->all();
    }

    /** @param list<string> $statuses */
    private function orderAt(array $statuses, string $deliveryType = 'delivery'): int
    {
        $payload = [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 2]],
            'delivery_type' => $deliveryType,
            'payment_method' => 'cash',
        ];

        if ($deliveryType === 'delivery') {
            $payload['address'] = [
                'line1' => 'Örnek Mah. 12. Sk No:3',
                'district' => 'Selçuklu',
                'city' => 'Konya',
            ];
        }

        $created = $this->asCustomer()
            ->postJson('/api/orders', $payload, self::HEADERS)
            ->assertCreated()
            ->json();

        $this->advance((int) $created['id'], $statuses);

        return (int) $created['id'];
    }
}
