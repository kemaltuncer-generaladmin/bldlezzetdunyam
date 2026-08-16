<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Illuminate\Support\Carbon;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Models\AppRelease;

/**
 * Sürüm yayınlama ve `GET /api/app-version` — `docs/05-mutfakapp.md` §9, `B-10`.
 *
 * NEDEN VAR: `veykemtu_app_releases` tablosu bu turdan önce hiç
 * oluşturulmamıştı; uç her çağrıda `fallback()`'e düşüp `download_url: null`
 * dönüyordu ve sahadaki hiçbir kasa güncellenemiyordu.
 *
 * EN KRİTİK TEST: `test_kayit_yokken_uc_kimseyi_kilitlemez`. Bu uç kimlik
 * istemiyor ve her istemci açılışta çağırıyor; burada 500 dönmek ya da
 * `min_supported`'ı yükseltmek, sahadaki her kasayı aynı anda engelleyici
 * ekrana düşürürdü.
 */
class AppReleaseTest extends KitchenTestCase
{
    /**
     * Sürüm kaydı hiç yokken uç güvenli varsayılana düşer.
     *
     * `min_supported` = `latest` olması ÖNEMLİ: ikisi eşit olduğu sürece
     * hiçbir istemci "çok eski" sayılmaz.
     */
    public function test_kayit_yokken_uc_kimseyi_kilitlemez(): void
    {
        $this->getJson('/api/app-version?app_id=mutfakapp', self::HEADERS)
            ->assertOk()
            ->assertJson([
                'latest' => '1.0.0',
                'min_supported' => '1.0.0',
                'download_url' => null,
                'sha256' => null,
                'size_bytes' => null,
            ]);
    }

    public function test_yayinlanan_surum_ozetiyle_birlikte_doner(): void
    {
        $this->release([
            'version' => '1.1.0',
            'download_url' => 'https://ornek.test/mutfakapp_1.1.0_amd64.deb',
            'sha256' => str_repeat('a', 64),
            'size_bytes' => 42_000_000,
            'notes' => 'Fiş kod sayfası düzeltmesi',
        ]);

        $this->getJson('/api/app-version?app_id=mutfakapp', self::HEADERS)
            ->assertOk()
            ->assertJson([
                'app_id' => 'mutfakapp',
                'latest' => '1.1.0',
                'min_supported' => '1.0.0',
                'download_url' => 'https://ornek.test/mutfakapp_1.1.0_amd64.deb',
                'sha256' => str_repeat('a', 64),
                'size_bytes' => 42_000_000,
                'notes' => 'Fiş kod sayfası düzeltmesi',
            ]);
    }

    /**
     * SIRALAMA `released_at`'e göre, `id`'ye değil.
     *
     * Bir sürüm kaydı düzeltilmek için silinip yeniden girilebilir ve o zaman
     * daha büyük bir `id` alır. `1.0.9`'u düzelten yeni bir satır, çoktan
     * yayınlanmış `1.1.0`'ı geçmiş sayılmamalı — kasa eski sürüme "güncelle"
     * derdi.
     */
    public function test_en_yeni_surum_yayin_tarihine_gore_secilir(): void
    {
        $this->release([
            'version' => '1.1.0',
            'released_at' => Carbon::parse('2026-08-10 10:00:00'),
        ]);

        // Sonra yazılmış ama daha ESKİ tarihli kayıt.
        $this->release([
            'version' => '1.0.9',
            'released_at' => Carbon::parse('2026-08-01 10:00:00'),
        ]);

        $this->getJson('/api/app-version?app_id=mutfakapp', self::HEADERS)
            ->assertOk()
            ->assertJson(['latest' => '1.1.0']);
    }

    /**
     * Uygulamalar birbirinin sürümünü görmemeli: `musteriapp` mağazadan
     * güncelleniyor ve `download_url`'i yok; kasanın onu görmesi, indirmeye
     * çalışıp her seferinde başarısız olması demek olurdu.
     */
    public function test_uygulamalar_birbirinin_surumunu_gormez(): void
    {
        $this->release(['app_id' => AppRelease::MUSTERIAPP, 'version' => '2.5.0']);

        $this->getJson('/api/app-version?app_id=mutfakapp', self::HEADERS)
            ->assertOk()
            ->assertJson(['latest' => '1.0.0', 'download_url' => null]);

        $this->getJson('/api/app-version?app_id=musteriapp', self::HEADERS)
            ->assertOk()
            ->assertJson(['latest' => '2.5.0']);
    }

    public function test_bilinmeyen_uygulama_reddedilir(): void
    {
        $this->getJson('/api/app-version?app_id=korsan', self::HEADERS)
            ->assertStatus(422);
    }

    // ── Konsol komutu ───────────────────────────────────────────────────

    public function test_komut_surum_yayinlar(): void
    {
        $this->artisan('veykemtu:surum', [
            '--publish' => true,
            '--app' => 'mutfakapp',
            '--version' => '1.2.0',
            '--url' => 'https://ornek.test/paket.deb',
            '--sha256' => str_repeat('b', 64),
        ])->assertSuccessful();

        $this->assertDatabaseHas('veykemtu_app_releases', [
            'app_id' => 'mutfakapp',
            'version' => '1.2.0',
            'sha256' => str_repeat('b', 64),
        ]);
    }

    /**
     * Aynı sürümün iki kez yayınlanması, hangi `.deb`'in sahada olduğunu
     * belirsizleştirir.
     */
    public function test_ayni_surum_iki_kez_yayinlanamaz(): void
    {
        $this->release(['version' => '1.3.0']);

        $this->artisan('veykemtu:surum', [
            '--publish' => true,
            '--app' => 'mutfakapp',
            '--version' => '1.3.0',
            '--url' => 'https://ornek.test/paket.deb',
            '--sha256' => str_repeat('c', 64),
        ])->assertFailed();
    }

    /**
     * Paket kasaya kurulacak kod taşıyor; düz HTTP üzerinden indirilen bir
     * yürütülebilir, yolda değiştirilebilir demektir.
     */
    public function test_http_adres_reddedilir(): void
    {
        $this->artisan('veykemtu:surum', [
            '--publish' => true,
            '--app' => 'mutfakapp',
            '--version' => '1.4.0',
            '--url' => 'http://ornek.test/paket.deb',
            '--sha256' => str_repeat('d', 64),
        ])->assertFailed();

        $this->assertDatabaseMissing('veykemtu_app_releases', ['version' => '1.4.0']);
    }

    /**
     * Kasa `.deb`'i `--url`'den indiriyor; adres yoksa yayın anlamsız.
     */
    public function test_mutfakapp_icin_adres_zorunlu(): void
    {
        $this->artisan('veykemtu:surum', [
            '--publish' => true,
            '--app' => 'mutfakapp',
            '--version' => '1.5.0',
            '--sha256' => str_repeat('e', 64),
        ])->assertFailed();
    }

    /**
     * ALT SINIR VARSAYILAN OLARAK DEĞİŞMEZ.
     *
     * Yayınlanan sürüme eşitlemek kolay bir varsayılan olurdu ve her yayında
     * sahadaki tüm kasaları engelleyici ekrana düşürürdü.
     */
    public function test_alt_sinir_varsayilan_olarak_tasinir(): void
    {
        $this->release(['version' => '1.6.0', 'min_supported' => '1.0.0']);

        $this->artisan('veykemtu:surum', [
            '--publish' => true,
            '--app' => 'mutfakapp',
            '--version' => '1.7.0',
            '--url' => 'https://ornek.test/paket.deb',
            '--sha256' => str_repeat('f', 64),
        ])->assertSuccessful();

        $this->assertDatabaseHas('veykemtu_app_releases', [
            'version' => '1.7.0',
            'min_supported' => '1.0.0',
        ]);
    }

    /** @param array<string, mixed> $overrides */
    private function release(array $overrides = []): AppRelease
    {
        $release = new AppRelease;
        $release->fill(array_merge([
            'app_id' => AppRelease::MUTFAKAPP,
            'version' => '1.0.0',
            'min_supported' => '1.0.0',
            'released_at' => Carbon::now(),
        ], $overrides));
        $release->save();

        return $release;
    }
}
