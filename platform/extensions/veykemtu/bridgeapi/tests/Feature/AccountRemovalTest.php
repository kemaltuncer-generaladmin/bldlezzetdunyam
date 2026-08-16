<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Order;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;

/**
 * Cari hesabın kaldırılması — kabul testi (Ajan 0-B).
 *
 * Bu dosyanın işi bir özelliği doğrulamak değil, bir özelliğin GERÇEKTEN
 * GİTTİĞİNİ ve GİDERKEN BİR ŞEY KIRMADIĞINI sabitlemek. Üç ayrı risk
 * ölçülüyor:
 *
 *  1. **Gerçekten gitti mi.** Uçlar 404, ödeme yöntemi 422, tablolar yok.
 *     Yarısı kaldırılmış bir özellik, hiç kaldırılmamış olandan kötüdür:
 *     kod okuyan onun çalıştığını sanır.
 *  2. **Tarihsel veri hâlâ okunuyor mu.** `orders.payment = 'account'` olan
 *     eski siparişler duruyor ve müşteri onları görebilmeli. Sipariş
 *     geçmişini 500 ile patlatmak, kaldırma işinin en olası yan hasarı.
 *  3. **Kapı gerçekten açıldı mı.** `CustomerGate` kalktı; `individual`
 *     işaretli bir hesap artık sipariş verebilmeli ve `can_order` sabit
 *     `true` dönmeli (alan sözleşmede kalıyor — `docs/03` §1.4).
 */
class AccountRemovalTest extends KitchenTestCase
{
    // ── 1. Uçlar gitti ────────────────────────────────────────────────────

    /**
     * Cari uçları 404 döner.
     *
     * Adresler bilerek yeniden kullanılmadı: eski bir istemci sürümü
     * çağırdığında 404 alması, başka bir anlama gelen 200 almasından iyidir.
     */
    public function test_cari_uclari_404_doner(): void
    {
        $this->asCustomer()->getJson('/api/account/summary', self::HEADERS)
            ->assertNotFound();

        $this->asCustomer()->getJson('/api/account/statement', self::HEADERS)
            ->assertNotFound();

        $this->asCustomer()->postJson('/api/account/payments', ['full' => true], self::HEADERS)
            ->assertNotFound();
    }

    /**
     * `payment_method: account` 422 ile reddedilir ve mesaj geçerli
     * yöntemleri SAYAR.
     *
     * Sayması şart: "seçilen değer geçersiz" diyen bir hata, `account`
     * gönderen eski bir istemcinin geliştiricisine ne yapacağını söylemez.
     */
    public function test_cari_odeme_yontemi_reddedilir(): void
    {
        $response = $this->asCustomer()->postJson(
            '/api/orders',
            $this->orderPayload(['payment_method' => 'account']),
            self::HEADERS,
        )->assertStatus(422);

        $mesaj = (string) $response->json('error.details.payment_method');

        $this->assertStringContainsString('online', $mesaj);
        $this->assertStringContainsString('cash', $mesaj);
        $this->assertStringNotContainsString('account', $mesaj);
    }

    // ── 2. Şema gitti ─────────────────────────────────────────────────────

    /**
     * Üç cari tablosu ve borç limiti kolonu düşürüldü.
     *
     * Test göçün KOŞTUĞUNU doğruluyor, yazıldığını değil: dosyayı yazıp
     * `up()` içinde yanlış tablo adı vermek sessizce hiçbir şey yapmaz.
     */
    public function test_cari_semasi_dusuruldu(): void
    {
        $this->assertFalse(Schema::hasTable('veykemtu_account_ledger'));
        $this->assertFalse(Schema::hasTable('veykemtu_account_periods'));
        $this->assertFalse(Schema::hasTable('veykemtu_account_payments'));
        $this->assertFalse(Schema::hasColumn('customers', 'bld_credit_limit_kurus'));
    }

    // ── 3. Tarihsel veri okunuyor ─────────────────────────────────────────

    /**
     * `payment = 'account'` olan eski sipariş 200 döner ve yöntemi olduğu
     * gibi gösterir.
     *
     * `payments` satırı bu yüzden silinmedi: `orders.payment` alanı
     * `payments.code` ile eşleşiyor ve karşılığı olmayan bir kod, ödeme
     * günlüğünü "property on null" ile patlatırdı.
     */
    public function test_eski_cari_siparis_okunmaya_devam_eder(): void
    {
        $orderId = $this->legacyAccountOrder();

        $this->asCustomer()->getJson('/api/orders/'.$orderId, self::HEADERS)
            ->assertOk()
            ->assertJsonPath('payment.method', 'account');
    }

    /**
     * Eski bir cari siparişin iptali artık ELLE İADE satırı açar.
     *
     * Eskiden `openRefundOnCancel()` `account` siparişinde erken dönüyordu:
     * para hareketi yoktu, borç deftere ters kayıtla nötrleniyordu. Defter
     * kalkınca o telafi de kalktı. `processed` işaretli bir sipariş, parası
     * bir yerde tahsil edilmiş demektir; iptali sessizce yutmak o parayı
     * kimsenin bakmadığı bir yerde bırakırdı.
     */
    public function test_odenmis_eski_cari_siparisin_iptali_elle_iade_acar(): void
    {
        $orderId = $this->legacyAccountOrder(processed: true);
        $order = Order::findOrFail($orderId);

        resolve(OrderStatusTransition::class)
            ->apply($order, OrderStatusTransition::CANCELLED);

        $refund = DB::table('veykemtu_payment_refunds')
            ->where('order_id', $orderId)
            ->first();

        $this->assertNotNull($refund, 'İptal edilen ödenmiş sipariş iade kaydı açmalı.');
        $this->assertSame('manual', $refund->gateway);
        $this->assertSame('manual', $refund->status);
    }

    // ── 4. Sipariş kapısı açıldı ──────────────────────────────────────────

    /**
     * `individual` işaretli hesap sipariş verebilir ve `can_order` `true`.
     *
     * İKİ İDDİA BİRLİKTE ÖLÇÜLÜYOR ve sebebi somut: alanı `true` sabitleyip
     * `OrderController`'daki kapıyı kaldırmayı unutmak (ya da tersi),
     * istemcinin "verebilirsin" deyip sunucunun 403 döndüğü bir hâl
     * yaratırdı — kullanıcı için açıklanamaz bir hata.
     */
    public function test_bireysel_hesap_siparis_verebilir(): void
    {
        $this->markCustomerIndividual();

        $this->asCustomer()->getJson('/api/auth/me', self::HEADERS)
            ->assertOk()
            ->assertJsonPath('account_type', 'individual')
            ->assertJsonPath('can_order', true);

        $this->asCustomer()->postJson('/api/orders', $this->orderPayload(), self::HEADERS)
            ->assertCreated();
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    /**
     * Asgari geçerli sipariş gövdesi.
     *
     * `collection` seçildi ki adres alanları teste gürültü katmasın; iki
     * porsiyon Tavuk Sote (2 × 185,00 TL) asgari sepet tutarını aşıyor.
     *
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function orderPayload(array $overrides = []): array
    {
        return array_merge([
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 2]],
            'delivery_type' => Order::COLLECTION,
            'payment_method' => 'cash',
        ], $overrides);
    }

    /**
     * Cari kaldırılmadan ÖNCE oluşmuş bir siparişi taklit eder.
     *
     * Sipariş normal yoldan (`cash`) yaratılıp `orders.payment` doğrudan
     * güncelleniyor: `account` artık uçtan geçmiyor ve geçmemeli. Aranan
     * şey zaten "veritabanında bu değer varsa ne oluyor" sorusunun cevabı.
     */
    private function legacyAccountOrder(bool $processed = false): int
    {
        $orderId = (int) $this->asCustomer()
            ->postJson('/api/orders', $this->orderPayload(), self::HEADERS)
            ->assertCreated()
            ->json('id');

        DB::table('orders')
            ->where('order_id', $orderId)
            ->update(['payment' => 'account', 'processed' => $processed ? 1 : 0]);

        return $orderId;
    }

    /** Test müşterisini bireysel işaretler (kayıt varsayılanı `corporate`). */
    private function markCustomerIndividual(): void
    {
        $this->asCustomer();

        $customer = ApiCustomer::where('email', 'test@ornek.com')->firstOrFail();
        $customer->bld_account_type = 'individual';
        $customer->save();
    }
}
