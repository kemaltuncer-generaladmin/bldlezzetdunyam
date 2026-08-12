<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\User\Facades\AdminAuth;
use Igniter\User\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use Veykemtu\BridgeApi\Models\MenuSoldOut;
use Veykemtu\BridgeApi\Models\OrderRevision;
use Veykemtu\BridgeApi\Models\PaymentRefund;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * İade takibi (B-15) ve salt okunur izleme ekranları (B-17).
 *
 * İadedeki asıl risk ÇİFT ÖDEME: `manual` bir iade birinin elle para
 * göndermesini bekliyor ve kapanmış bir iadenin yeniden işaretlenebilmesi,
 * ikinci kez para gönderilmesine açık bir davet olurdu. Testler o kapıyı
 * sabitliyor.
 */
class AdminRefundTest extends TestCase
{
    use RefreshDatabase {
        refreshTestDatabase as private laravelRefreshTestDatabase;
    }

    /** Çekirdek şeması yalnızca `igniter:up` ile kurulur — bkz. ContractTest. */
    protected function refreshTestDatabase(): void
    {
        $this->laravelRefreshTestDatabase();

        $this->artisan('igniter:up');
    }

    private const string REFUNDS_URI = '/admin/veykemtu/bridgeapi/refunds';

    private const string REVISIONS_URI = '/admin/veykemtu/bridgeapi/order_revisions';

    private const string SOLDOUT_URI = '/admin/veykemtu/bridgeapi/menu_sold_outs';

    // ── İadeler ───────────────────────────────────────────────────────────

    public function test_iade_listesi_bekleyenleri_gosterir(): void
    {
        $this->actingAsAdmin();
        $this->refund(status: PaymentRefund::STATUS_MANUAL, reason: 'Sipariş iptal edildi');

        $this->get(self::REFUNDS_URI)
            ->assertOk()
            ->assertSee(lang('veykemtu.bridgeapi::refund.status_manual'))
            ->assertSee('Sipariş iptal edildi')
            ->assertDontSee('veykemtu.bridgeapi::refund');
    }

    public function test_liste_giris_yapmadan_acilmaz(): void
    {
        $this->get(self::REFUNDS_URI)->assertRedirect();
    }

    public function test_elle_iade_tamamlandi_isaretlenir(): void
    {
        $this->actingAsAdmin();
        $refund = $this->refund(status: PaymentRefund::STATUS_MANUAL);

        $this->post(self::REFUNDS_URI, [
            '_handler' => 'onMarkSettled',
            'recordId' => $refund->id,
            'provider_ref' => 'HAVALE-8891',
        ])->assertRedirect();

        $refund->refresh();

        $this->assertSame(PaymentRefund::STATUS_SUCCEEDED, $refund->status);
        $this->assertSame('HAVALE-8891', $refund->provider_ref);
        $this->assertNotNull($refund->settled_at);
    }

    /**
     * ÇİFT ÖDEME KAPISI: kapanmış iade ikinci kez işaretlenemez.
     */
    public function test_kapanmis_iade_ikinci_kez_isaretlenemez(): void
    {
        $this->actingAsAdmin();
        $refund = $this->refund(status: PaymentRefund::STATUS_SUCCEEDED);
        $refund->provider_ref = 'ILK-KAYIT';
        $refund->save();

        $this->post(self::REFUNDS_URI, [
            '_handler' => 'onMarkSettled',
            'recordId' => $refund->id,
            'provider_ref' => 'IKINCI-DENEME',
        ]);

        $this->assertSame(
            'ILK-KAYIT',
            $refund->refresh()->provider_ref,
            'İlk kayıt korunmalı; ikinci deneme hiçbir şeyi değiştirmemeli.',
        );
    }

    /**
     * `failed` de bir iş bekliyor: sağlayıcı reddetti, biri müdahale etmeli.
     */
    public function test_basarisiz_iade_de_isaretlenebilir(): void
    {
        $this->actingAsAdmin();
        $refund = $this->refund(status: PaymentRefund::STATUS_FAILED);

        $this->post(self::REFUNDS_URI, [
            '_handler' => 'onMarkSettled',
            'recordId' => $refund->id,
            'provider_ref' => 'ELDEN',
        ])->assertRedirect();

        $this->assertSame(PaymentRefund::STATUS_SUCCEEDED, $refund->refresh()->status);
    }

    public function test_saglayicidaki_iade_elle_kapatilamaz(): void
    {
        $this->actingAsAdmin();
        $refund = $this->refund(status: PaymentRefund::STATUS_PENDING);

        $this->post(self::REFUNDS_URI, [
            '_handler' => 'onMarkSettled',
            'recordId' => $refund->id,
        ]);

        $this->assertSame(
            PaymentRefund::STATUS_PENDING,
            $refund->refresh()->status,
            'Sağlayıcıda bekleyen iadeyi elle kapatmak, sonucu gelmeden karar vermek olurdu.',
        );
    }

    // ── İzleme ekranları (B-17) ───────────────────────────────────────────

    public function test_revizyon_listesi_tutar_etkisini_gosterir(): void
    {
        $this->actingAsAdmin();

        $revision = new OrderRevision;
        $revision->order_id = 41;
        $revision->revision_no = 1;
        $revision->reason = 'Müşteri porsiyon azalttı';
        $revision->before_json = ['items' => [['a'], ['b'], ['c']]];
        $revision->after_json = ['items' => [['a']]];
        $revision->subtotal_before_kurus = 30_000;
        $revision->subtotal_after_kurus = 10_000;
        $revision->total_before_kurus = 30_000;
        $revision->total_after_kurus = 10_000;
        $revision->refund_kurus = 20_000;
        $revision->created_at = BusinessTime::forStorage(BusinessTime::now());
        $revision->save();

        $this->get(self::REVISIONS_URI)
            ->assertOk()
            /*
             * "Müşteri" DEĞİL "porsiyon azalttı" aranıyor.
             *
             * Çekirdeğin liste sütunu metni `htmlentities()` ile geçiriyor
             * ve bu, Latin-1 aralığındaki harfleri varlık koduna çeviriyor:
             * "ü" → `&uuml;`. Türkçeye özgü "ş" ve "ı" aralığın dışında
             * olduğu için olduğu gibi kalıyor. Yani ekranda doğru görünen
             * metin, kaynakta yarı kodlanmış duruyor.
             *
             * Latin-1'e düşen harf içermeyen bir parça seçmek, testi bu
             * çekirdek ayrıntısına bağımlı olmaktan kurtarıyor.
             */
            ->assertSee('porsiyon azalttı')
            // 3 kalemden 1 kaleme düştü
            ->assertSee('3 → 1', false)
            // İade 200,00 ₺
            ->assertSee('200,00')
            ->assertDontSee('veykemtu.bridgeapi::monitor');
    }

    public function test_tukenen_urun_listesi_acilir(): void
    {
        $this->actingAsAdmin();

        $soldOut = new MenuSoldOut;
        $soldOut->menu_id = 1;
        $soldOut->sold_out_on = BusinessTime::now()->toDateString();
        $soldOut->reason = 'Malzeme bitti';
        $soldOut->created_at = BusinessTime::forStorage(BusinessTime::now());
        $soldOut->save();

        $this->get(self::SOLDOUT_URI)
            ->assertOk()
            ->assertSee('Malzeme bitti')
            ->assertDontSee('veykemtu.bridgeapi::monitor');
    }

    public function test_izleme_ekranlari_giris_yapmadan_acilmaz(): void
    {
        $this->get(self::REVISIONS_URI)->assertRedirect();
        $this->get(self::SOLDOUT_URI)->assertRedirect();
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    private function refund(string $status, string $reason = 'İptal'): PaymentRefund
    {
        $refund = new PaymentRefund;
        $refund->order_id = 41;
        $refund->amount_kurus = 12_500;
        $refund->gateway = 'manual';
        $refund->status = $status;
        $refund->reason = $reason;
        $refund->created_at = BusinessTime::forStorage(BusinessTime::now());
        $refund->save();

        return $refund;
    }

    private function actingAsAdmin(): void
    {
        $user = new User;
        $user->fill([
            'name' => 'Test Yönetici',
            'username' => 'testyonetici',
            'email' => 'yonetici@ornek.com',
            'status' => true,
            'super_user' => true,
        ]);
        $user->password = 'parola123';
        $user->is_activated = true;
        $user->activated_at = now();
        $user->save();

        AdminAuth::login($user);
    }
}
