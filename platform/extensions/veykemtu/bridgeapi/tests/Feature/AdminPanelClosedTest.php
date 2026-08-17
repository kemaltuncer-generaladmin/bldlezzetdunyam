<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Illuminate\Testing\TestResponse;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Http\Middleware\RequireAdminPanel;

/**
 * TastyIgniter admin paneli kapalıdır — F4.
 *
 * Kontrol Merkezi tek yönetim yüzeyi oldu ve `/admin/*` bir ortam
 * değişkeniyle kapatıldı (`BLD_ADMIN_ENABLED`, varsayılan kapalı).
 * Kapatmanın kendisi tek satır; bu paket, o tek satırın sessizce etkisiz
 * kalabileceği DÖRT yolu kapatıyor:
 *
 *  1. **Giriş formu ayrı listede.** Admin ekranları
 *     `igniter-routes.adminMiddleware`, giriş/çıkış/parola sıfırlama ise
 *     `igniter-routes.middleware` üzerinden kayıtlı
 *     (`Igniter\User\Classes\RouteRegistrar`). Yalnız birincisi kapatılsa
 *     bütün ekranlar `404` döner, `/admin/login` açık kalırdı — yani
 *     kapattığımızı sandığımız hâlde asıl saldırı yüzeyi ayakta olurdu.
 *  2. **Yanıt kodu panelin varlığını ele vermemeli.** Ara katman `web`
 *     grubundan sonra koşsaydı token'sız bir `POST /admin/login` `419`
 *     alırdı; `404` beklemek bu sıralamayı da kilitliyor.
 *  3. **API etkilenmemeli.** Kapatma iki genel ara katman listesine
 *     dokunuyor ve o listelerden biri storefront tarafında da kullanılıyor.
 *     Yol denetimi bozulursa `/api/*` de kapanır — yani bütün sistem.
 *  4. **Şalter gerçekten açılabilmeli.** Geri alınabilirlik bu kararın
 *     tek gerekçesi; açıldığında panelin döndüğü doğrulanmazsa "geri
 *     alınabilir" bir iddiadan ibaret kalır.
 *
 * `KitchenTestCase` tabanı seçildi çünkü imzalı kontrol ucunu gerçek bir
 * vitrinle çağırmak gerekiyor; imza yardımcısı `ControlPanelTest`
 * desenidir.
 */
class AdminPanelClosedTest extends KitchenTestCase
{
    private const string SECRET = 'test-kontrol-merkezi-sirri';

    /** Bizim ekranlarımızdan biri — `AdminRegistrar::REFUNDS_URI`. */
    private const string ADMIN_PAGE = '/admin/veykemtu/bridgeapi/refunds';

    protected function setUp(): void
    {
        parent::setUp();

        putenv('BLD_CONTROL_SECRET='.self::SECRET);
        $_ENV['BLD_CONTROL_SECRET'] = self::SECRET;
    }

    // ── 1. Kapalı panel ───────────────────────────────────────────────────

    /**
     * Varsayılan KAPALI.
     *
     * Test ortamında `BLD_ADMIN_ENABLED` tanımlı değil ve bu, üretimdeki
     * "değişkeni yazmayı unut" hâlinin aynısı. Varsayılan açık olsaydı
     * unutulan bir satırın cezası "panel açık kaldı" olurdu.
     */
    public function test_panel_varsayilan_olarak_kapalidir(): void
    {
        $this->assertFalse(
            RequireAdminPanel::enabled(),
            'Şalter varsayılan olarak KAPALI doğmalı.',
        );
    }

    /**
     * Panelin bütün yüzeyi — ekranlar, giriş, çıkış, parola sıfırlama.
     *
     * Adresler tek tek yazılı çünkü ikisi İKİ AYRI ara katman listesinden
     * geliyor ve tek bir adres denemek, kapatmanın yarısının çalıştığını
     * doğrulamakla aynı şey olurdu.
     */
    public function test_butun_admin_yollari_404_doner(): void
    {
        foreach ([
            '/admin',
            '/admin/login',
            '/admin/login/reset',
            '/admin/logout',
            '/admin/dashboard',
            self::ADMIN_PAGE,
            '/admin/veykemtu/bridgeapi/daily_menus',
        ] as $uri) {
            $this->get($uri)->assertNotFound();
        }
    }

    /**
     * `POST /admin/login` de `404` — `419` DEĞİL.
     *
     * CSRF ara katmanı bizden önce koşsaydı yanıt `419 Page Expired`
     * olurdu ve o kod, arkasında gerçek bir form olduğunu söyler. Kapatmanın
     * amacı panelin VARLIĞINI gizlemek; bu test ara katman sırasını
     * (`array_unshift`, `web` grubundan önce) kilitliyor.
     */
    public function test_giris_gonderimi_419_degil_404_doner(): void
    {
        $this->post('/admin/login', [
            'email' => 'yonetici@ornek.com',
            'password' => 'parola123',
        ])->assertNotFound();
    }

    // ── 2. API etkilenmiyor ───────────────────────────────────────────────

    /**
     * Sağlık ucu panel kapalıyken de ayakta.
     *
     * Harici uptime izlemesi buradan bakıyor; kapatma onu da düşürseydi
     * "sistem çöktü" alarmı üretirdik.
     */
    public function test_saglik_ucu_panel_kapaliyken_calisir(): void
    {
        $this->getJson('/api/health', self::HEADERS)->assertOk();
    }

    /**
     * Kontrol Merkezi ucu panel kapalıyken de ayakta.
     *
     * Bu, kapatmanın anlamlı olmasının şartı: yönetim KM'ye taşındığı için
     * paneli kapatıyoruz. KM'nin yolu da kapansaydı sistem yönetilemez
     * hâle gelirdi.
     */
    public function test_kontrol_ucu_panel_kapaliyken_calisir(): void
    {
        $this->signed('GET', '/api/control/settings/sales')
            ->assertOk()
            ->assertJsonPath('data.location_id', $this->locationId());
    }

    // ── 3. Şalter geri alınabilir ─────────────────────────────────────────

    /**
     * Şalter açılınca panel geri geliyor.
     *
     * `404` YERİNE YÖNLENDİRME bekleniyor: oturum açılmadığı için çekirdek
     * giriş ekranına yönlendiriyor. Aranan şey sayfanın içeriği değil, ara
     * katmanın artık kesmediği — panelin kendi davranışını
     * `AdminRefundTest` ve kardeşleri sınıyor.
     */
    public function test_salter_acilinca_panel_geri_gelir(): void
    {
        config([RequireAdminPanel::CONFIG_KEY => true]);

        $this->get(self::ADMIN_PAGE)->assertRedirect();
        $this->get('/admin/login')->assertOk();
    }

    // ── 4. Ortam değişkeninin okunuşu ─────────────────────────────────────

    /**
     * Tanınmayan her değer KAPALI sayılır.
     *
     * `.env` elle yazılan bir dosya: `1`, `on` ve `evet` denemeleri olacak.
     * İlk ikisi kabul ediliyor; geri kalan her şey — boş dize, `evet`,
     * harf hatası — kapalı. Yön bilinçli: yanlış yazılmış bir satır paneli
     * açmamalı.
     */
    public function test_ortam_degiskeni_yalnizca_bilinen_degerlerde_acar(): void
    {
        foreach (['1' => true, 'true' => true, 'TRUE' => true, 'on' => true,
            '0' => false, 'false' => false, 'evet' => false, '' => false] as $raw => $expected) {
            putenv(RequireAdminPanel::ENV_KEY.'='.$raw);
            $_ENV[RequireAdminPanel::ENV_KEY] = (string) $raw;

            $this->assertSame(
                $expected,
                RequireAdminPanel::enabledByEnvironment(),
                sprintf('"%s" değeri için beklenen sonuç alınamadı.', $raw),
            );
        }

        putenv(RequireAdminPanel::ENV_KEY);
        unset($_ENV[RequireAdminPanel::ENV_KEY]);

        $this->assertFalse(
            RequireAdminPanel::enabledByEnvironment(),
            'Değişken hiç tanımlanmamışken panel KAPALI olmalı.',
        );
    }

    /**
     * İmzalı kontrol isteği — `ControlPanelTest::signed()` ile aynı tarif.
     *
     * Yardımcı kopyalandı çünkü `ControlPanelTest` içinde `private` ve o
     * dosya başka bir kulvarda; kalıtım için oradan çıkarmak, bu turda
     * ilgisiz bir paketi riske atmak olurdu.
     */
    private function signed(string $method, string $path): TestResponse
    {
        $timestamp = time();
        $nonce = bin2hex(random_bytes(12));

        $canonical = implode("\n", [
            strtoupper($method),
            (string) parse_url($path, PHP_URL_PATH),
            (string) $timestamp,
            $nonce,
            hash('sha256', ''),
        ]);

        return $this->call($method, $path, [], [], [], [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_X_CONTROL_TIMESTAMP' => (string) $timestamp,
            'HTTP_X_CONTROL_NONCE' => $nonce,
            'HTTP_X_CONTROL_SIGNATURE' => 'sha256='.hash_hmac('sha256', $canonical, self::SECRET),
        ], '');
    }
}
