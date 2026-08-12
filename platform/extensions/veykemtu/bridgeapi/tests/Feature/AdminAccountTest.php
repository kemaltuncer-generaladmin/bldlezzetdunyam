<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\User\Facades\AdminAuth;
use Igniter\User\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use Veykemtu\BridgeApi\Models\AccountLedgerEntry;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Services\AccountLedger;
use Veykemtu\BridgeApi\Services\CreditLimit;

/**
 * Cari hesap kartı: limit, tahsilat ve ekstre — B-14.
 *
 * Ağırlık merkezi üç yerde ve üçü de PARA:
 *
 *  1. **Limitin üç hâli.** Boş (sınırsız), 0 (cari kapalı) ve bir sayı
 *     birbirinin zıddı. İkisi karışırsa ya veresiye sınırsız açılır ya da
 *     çalışan bir müşterinin siparişi durur.
 *  2. **Tahsilatın tekilliği.** Defter `insertOrIgnore` kullanıyor; aynı
 *     makbuz iki kez girilirse ikincisi SESSİZCE yutulur ve yönetici
 *     "kaydedildi" görüp ekstrede bulamaz. Açık hata vermek şart.
 *  3. **Bakiye yönü.** Pozitif = müşterinin borcu (`docs/02` §7.2). İşaret
 *     ters okunursa tahsilat borcu artırır.
 */
class AdminAccountTest extends TestCase
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

    private const string BASE_URI = '/admin/veykemtu/bridgeapi/customer_accounts';

    // ── Limit: üç hâl ─────────────────────────────────────────────────────

    /**
     * Boş limit sınırsızdır, `0` ise cari hesabı KAPATIR.
     *
     * `LiraField::toKurus('')` sıfır döndürüyor; doğrudan kullanılsaydı bu
     * iki zıt niyet aynı sonuca varırdı.
     */
    public function test_bos_limit_ile_sifir_limit_ayni_sey_degildir(): void
    {
        $customer = $this->corporateCustomer();

        $customer->credit_limit_lira = '';
        $this->assertNull(
            $customer->bld_credit_limit_kurus,
            'Boş bırakılan limit NULL (sınırsız) olmalı.',
        );

        $customer->credit_limit_lira = '0';
        $this->assertSame(
            0,
            (int) $customer->bld_credit_limit_kurus,
            'Sıfır yazmak cari hesabı kapatmalı, sınırsız yapmamalı.',
        );

        $customer->credit_limit_lira = '250,50';
        $this->assertSame(25050, (int) $customer->bld_credit_limit_kurus);
    }

    public function test_limitsiz_musteri_her_tutari_gecirir(): void
    {
        $customer = $this->corporateCustomer();
        $customer->bld_credit_limit_kurus = null;
        $customer->save();

        $this->assertTrue(resolve(CreditLimit::class)->allows($customer, 999_999_00));
        $this->assertNull(resolve(CreditLimit::class)->remaining($customer));
    }

    public function test_sifir_limitli_musteri_cari_ile_odeyemez(): void
    {
        $customer = $this->corporateCustomer();
        $customer->bld_credit_limit_kurus = 0;
        $customer->save();

        $this->assertFalse(resolve(CreditLimit::class)->allows($customer, 1));
    }

    /**
     * Limit MEVCUT BAKİYE + yeni tutar üzerinden değerlendirilir.
     *
     * Yalnız yeni tutara bakılsaydı, limiti 100 TL olan bir müşteri 90'ar
     * TL'lik siparişlerle sınırsız borçlanabilirdi.
     */
    public function test_limit_mevcut_bakiye_ustune_hesaplanir(): void
    {
        $customer = $this->corporateCustomer();
        $customer->bld_credit_limit_kurus = 10_000; // 100 TL
        $customer->save();

        resolve(AccountLedger::class)->record(
            customerId: (int) $customer->customer_id,
            type: AccountLedgerEntry::TYPE_DEBIT,
            amountKurus: 8_000,
            source: AccountLedgerEntry::SOURCE_ORDER,
            referenceType: 'order',
            referenceId: 4242,
        );

        $limit = resolve(CreditLimit::class);

        $this->assertSame(2_000, $limit->remaining($customer));
        $this->assertTrue($limit->allows($customer, 2_000), '2.000 kuruş tam limite oturur.');
        $this->assertFalse($limit->allows($customer, 2_001), '1 kuruş fazlası reddedilmeli.');
    }

    // ── Tahsilat ──────────────────────────────────────────────────────────

    public function test_tahsilat_deftere_alacak_yazar_ve_bakiyeyi_dusurur(): void
    {
        $this->actingAsAdmin();
        $customer = $this->corporateCustomer();

        resolve(AccountLedger::class)->record(
            customerId: (int) $customer->customer_id,
            type: AccountLedgerEntry::TYPE_DEBIT,
            amountKurus: 50_000,
            source: AccountLedgerEntry::SOURCE_ORDER,
            referenceType: 'order',
            referenceId: 99,
        );

        $this->post(self::BASE_URI.'/edit/'.$customer->customer_id, [
            '_handler' => 'onRecordPayment',
            'recordId' => $customer->customer_id,
            'payment_amount' => '200,00',
            'payment_receipt' => '10041',
        ])->assertRedirect();

        $this->assertSame(
            30_000,
            resolve(AccountLedger::class)->balance((int) $customer->customer_id),
            '500 TL borçtan 200 TL tahsilat düşünce 300 TL kalmalı.',
        );
    }

    /**
     * AYNI MAKBUZ İKİ KEZ İŞLENEMEZ — ve sessizce yutulmaz.
     *
     * Defterdeki `insertOrIgnore` ikinci satırı zaten yazmazdı; buradaki
     * asıl mesele yöneticinin bunu ÖĞRENMESİ. Sessiz başarı, bakiyenin
     * neden düşmediğini kimsenin anlayamaması demek.
     */
    public function test_ayni_makbuz_ikinci_kez_islenemez(): void
    {
        $this->actingAsAdmin();
        $customer = $this->corporateCustomer();

        $payload = [
            '_handler' => 'onRecordPayment',
            'recordId' => $customer->customer_id,
            'payment_amount' => '100,00',
            'payment_receipt' => '55555',
        ];

        $this->post(self::BASE_URI.'/edit/'.$customer->customer_id, $payload)
            ->assertRedirect();

        $this->post(self::BASE_URI.'/edit/'.$customer->customer_id, $payload);

        $this->assertSame(
            1,
            AccountLedgerEntry::query()
                ->where('source', AccountLedgerEntry::SOURCE_PAYMENT)
                ->where('reference_id', 55555)
                ->count(),
            'Makbuz bir kez yazılmalı.',
        );
    }

    public function test_makbuz_no_rakam_disinda_bir_sey_kabul_etmez(): void
    {
        $this->actingAsAdmin();
        $customer = $this->corporateCustomer();

        $this->post(self::BASE_URI.'/edit/'.$customer->customer_id, [
            '_handler' => 'onRecordPayment',
            'recordId' => $customer->customer_id,
            'payment_amount' => '100,00',
            'payment_receipt' => 'MKB-12',
        ]);

        $this->assertSame(
            0,
            AccountLedgerEntry::query()->count(),
            'Geçersiz makbuz numarasıyla hiçbir hareket yazılmamalı.',
        );
    }

    public function test_sifir_tutarli_tahsilat_yazilmaz(): void
    {
        $this->actingAsAdmin();
        $customer = $this->corporateCustomer();

        $this->post(self::BASE_URI.'/edit/'.$customer->customer_id, [
            '_handler' => 'onRecordPayment',
            'recordId' => $customer->customer_id,
            'payment_amount' => '0',
            'payment_receipt' => '777',
        ]);

        $this->assertSame(0, AccountLedgerEntry::query()->count());
    }

    // ── Ekranlar ──────────────────────────────────────────────────────────

    public function test_liste_yalnizca_kurumsal_musterileri_gosterir(): void
    {
        $this->actingAsAdmin();

        $this->corporateCustomer('Kurumsal Firma', 'kurumsal@ornek.com');

        $individual = $this->corporateCustomer('Birey', 'birey@ornek.com');
        $individual->bld_account_type = 'individual';
        $individual->bld_org_name = 'Gorunmemeli AS';
        $individual->save();

        $this->get(self::BASE_URI)
            ->assertOk()
            ->assertSee('Kurumsal Firma')
            ->assertDontSee('Gorunmemeli AS')
            ->assertDontSee('veykemtu.bridgeapi::accountledger');
    }

    public function test_musteri_karti_bakiye_limit_ve_ekstreyi_gosterir(): void
    {
        $this->actingAsAdmin();
        $customer = $this->corporateCustomer();
        $customer->bld_credit_limit_kurus = 100_000;
        $customer->save();

        resolve(AccountLedger::class)->record(
            customerId: (int) $customer->customer_id,
            type: AccountLedgerEntry::TYPE_DEBIT,
            amountKurus: 25_000,
            source: AccountLedgerEntry::SOURCE_ORDER,
            referenceType: 'order',
            referenceId: 7,
            description: 'Sipariş #7',
        );

        $this->get(self::BASE_URI.'/edit/'.$customer->customer_id)
            ->assertOk()
            ->assertSee(lang('veykemtu.bridgeapi::accountledger.summary_remaining'))
            // 100.000 − 25.000 = 75.000 kuruş = 750,00 ₺
            ->assertSee('750,00')
            ->assertSee('Sipariş #7')
            ->assertDontSee('veykemtu.bridgeapi::accountledger');
    }

    public function test_kart_giris_yapmadan_acilmaz(): void
    {
        $customer = $this->corporateCustomer();

        $this->get(self::BASE_URI.'/edit/'.$customer->customer_id)
            ->assertRedirect();
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    private function corporateCustomer(
        string $orgName = 'Test Kurumsal',
        string $email = 'kurumsal@ornek.com',
    ): ApiCustomer {
        $customer = new ApiCustomer;
        $customer->first_name = 'Yetkili';
        $customer->last_name = 'Kisi';
        $customer->email = $email;
        $customer->telephone = '05001112233';
        $customer->status = true;
        $customer->bld_account_type = 'corporate';
        $customer->bld_org_name = $orgName;
        $customer->bld_contact_person = 'Yetkili Kisi';
        $customer->save();

        return $customer;
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
