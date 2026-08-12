<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\User\Facades\AdminAuth;
use Igniter\User\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use Veykemtu\BridgeApi\Admin\NavigationTrimmer;

/**
 * Panel giydirmesi ve menü sadeleştirmesi — B-11 / B-12.
 *
 * NEDEN AYRI TEST: marka CSS'i bir olay dinleyicisiyle ekleniyor
 * (`admin.controller.beforeRemap`) ve dosya `public/` altına
 * YAYINLANMIYOR — çekirdeğin varlık birleştiricisi onu doğrudan eklenti
 * klasöründen okuyor. Bu zincirin herhangi bir halkası koparsa panel
 * sessizce stoksuz açılır: hata yok, yalnızca giydirme yok.
 *
 * Aynı sessizlik menü gizlemede de var — `NavigationTrimmer::HIDDEN`
 * içindeki bir kod yanlış yazılırsa girdi menüde kalır ve kimse fark etmez.
 */
class AdminBrandingTest extends TestCase
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

    /**
     * Giydirme ve menü her admin sayfasında aynı düzenden geliyor; hangisini
     * açtığımız fark etmiyor.
     *
     * `/admin/dashboard` KULLANILMIYOR: temiz bir test veritabanında vitrin
     * logosu ayarı boş kalıyor ve çekirdeğin düzeni `media_url(null)` ile
     * patlıyor. Bu bizim kodumuzla ilgili değil, ama testi ona bağlamak
     * ilgisiz bir sebeple kırmızı yanan bir test demekti.
     */
    private const string ADMIN_PAGE = '/admin/veykemtu/bridgeapi/refunds';

    /**
     * Marka CSS'i panelin HTML'ine giriyor.
     *
     * Birleştirici varlıkları `/_assets/{hash}.css` altında sunuyor; aranan
     * şey o bağlantının VARLIĞI değil (o zaten çekirdeğin kendi CSS'i için
     * de var), bizim dosyamızın birleştirilen kümeye girmiş olması.
     */
    public function test_marka_css_i_panele_ekleniyor(): void
    {
        $this->actingAsAdmin();

        $html = $this->get(self::ADMIN_PAGE)->assertOk()->getContent();

        $this->assertMatchesRegularExpression(
            '#<link[^>]+_assets/[^"]+\.css#',
            (string) $html,
            'Panel hiç birleştirilmiş CSS yüklemiyor — varlık zinciri kopuk.',
        );

        // Dosyanın kendisi çözülebiliyor mu: yol simgesi (`veykemtu.bridgeapi::`)
        // yanlış yazılsaydı `addCss` sessizce ham dizeyi geçirir ve dosya
        // birleştirmeye hiç girmezdi.
        $resolved = \Igniter\Flame\Support\Facades\File::symbolizePath(
            'veykemtu.bridgeapi::/css/admin.css',
        );

        $this->assertFileExists(
            $resolved,
            'Marka CSS yolu çözülemiyor; `addCss` çağrısındaki ad alanı yanlış.',
        );
    }

    /**
     * Gizlenen menü girdileri gerçekten kaybolmuş; kalanlar duruyor.
     *
     * Kodlar elle yazılan dizeler: biri yanlış yazılırsa `removeNavItem`
     * sessizce hiçbir şey yapmaz.
     */
    public function test_gereksiz_menuler_gizli_ama_gunluk_isler_duruyor(): void
    {
        $this->actingAsAdmin();

        $html = (string) $this->get(self::ADMIN_PAGE)->assertOk()->getContent();

        foreach (['themes', 'mail_templates', 'updates', 'system_logs', 'reservations'] as $code) {
            $this->assertStringNotContainsString(
                'nav-link mb-1 '.$code,
                $html,
                sprintf('`%s` menüde hâlâ görünüyor.', $code),
            );
        }

        // Günlük iş yüzeyleri kaybolmamalı — sadeleştirme fazla ileri gitmesin.
        $this->assertStringContainsString('bld_phone_orders', $html);
        $this->assertStringContainsString('bld_corporate', $html);
    }

    /** Gizlenen her kodun gerekçesi yazılı — altı ay sonra soran için. */
    public function test_her_gizlenen_menunun_gerekcesi_var(): void
    {
        $reflection = new \ReflectionClass(NavigationTrimmer::class);
        /** @var array<string, string> $hidden */
        $hidden = $reflection->getConstant('HIDDEN');

        foreach ($hidden as $code => $reason) {
            $this->assertNotSame('', trim($reason), sprintf('`%s` gerekçesiz.', $code));
        }
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
