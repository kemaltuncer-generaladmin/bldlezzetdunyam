<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\User\Facades\AdminAuth;
use Igniter\User\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;
use Veykemtu\BridgeApi\Http\Middleware\RequireAdminPanel;
use Veykemtu\BridgeApi\Models\SitePost;
use Veykemtu\BridgeApi\Models\SiteService;
use Veykemtu\BridgeApi\Services\SiteContentRepository;

/**
 * Kurumsal site içeriği yönetim ekranları.
 *
 * Testlerin ağırlık merkezi dört yerdedir:
 *
 *  1. **Tekrarlayıcı alanların iki biçimi.** `audience`, `benefits` ve
 *     `quote_needs` formda satır dizisi, veritabanında düz metin listesidir.
 *     Çeviri bozulursa hata VERMEZ — alan sessizce yanlış biçimde kaydedilir
 *     ve site o bölümü hiç çizmez. Bu yüzden gidiş-dönüş burada sabitlenir.
 *  2. **Maddenin silinebilmesi.** Son maddeyi silip kaydetmek, doğrulanmış
 *     dizinin boş anahtarı atlaması yüzünden "sildim ama geri geldi"ye
 *     dönüşebilir; bu yol ayrıca test edilir.
 *  3. **Adresin benzersizliği kendi kaydını saymaz.** Bir hizmeti açıp
 *     adresine dokunmadan kaydetmek hata vermemeli.
 *  4. **Önbelleğin düşmesi.** Yönetici kaydetti ama sitede göremiyorsa
 *     ekranın çalışması bir işe yaramaz.
 */
class AdminSiteContentTest extends TestCase
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
     * Form parçacığının alan adlarını kuşattığı dizi adları.
     *
     * Çekirdek bunları modelin sınıf adından türetiyor
     * (`Form::initForm` → `str_singular(strip_class_basename($model))`).
     */
    private const string SERVICE_ARRAY = 'SiteService';

    private const string POST_ARRAY = 'SitePost';

    private const string SERVICES_URI = '/admin/veykemtu/bridgeapi/site_services';

    private const string POSTS_URI = '/admin/veykemtu/bridgeapi/site_posts';

    /**
     * Panel şalteri TEST İÇİN AÇILIYOR — F4.
     *
     * `/admin/*` üretimde kapalı (`RequireAdminPanel`, varsayılan kapalı):
     * tek yönetim yüzeyi Kontrol Merkezi. Panel bir YEDEK olarak duruyor ve
     * yedeğin değeri, ihtiyaç anında çalıştığının bilinmesinde — bu yüzden
     * testler silinmedi, şalteri açıp koşuyorlar. Kapatmanın kendi testi
     * `AdminPanelClosedTest`.
     */
    protected function setUp(): void
    {
        parent::setUp();

        config([RequireAdminPanel::CONFIG_KEY => true]);
    }

    // ── Ekranların açılması ───────────────────────────────────────────────

    public function test_hizmet_ekranlari_acilir(): void
    {
        $this->actingAsAdmin();

        $service = $this->makeService();

        $this->get(self::SERVICES_URI)->assertOk();
        $this->get(self::SERVICES_URI.'/create')->assertOk();
        $this->get(self::SERVICES_URI.'/edit/'.$service->id)->assertOk();
    }

    public function test_yazi_ekranlari_acilir(): void
    {
        $this->actingAsAdmin();

        $post = $this->makePost();

        $this->get(self::POSTS_URI)->assertOk();
        $this->get(self::POSTS_URI.'/create')->assertOk();
        $this->get(self::POSTS_URI.'/edit/'.$post->id)->assertOk();
    }

    // ── Tekrarlayıcı ↔ düz liste çevirisi ─────────────────────────────────

    /**
     * Formdan gelen satırlar düz metin listesi olarak kaydedilir.
     *
     * Biçim `SiteContentRepository` paketinin yayınladığı biçimdir; site
     * (`website/content/services.ts`) düz metin listesi bekliyor.
     */
    public function test_tekrarlayici_satirlari_duz_liste_olarak_kaydedilir(): void
    {
        $this->actingAsAdmin();

        $service = $this->makeService();

        $this->saveService($service->id, [
            'audience' => [['text' => 'Ofisler'], ['text' => 'Fabrikalar']],
            'benefits' => [['text' => 'Öngörülebilir maliyet']],
            'quote_needs' => [['text' => 'Kişi sayısı']],
        ])->assertRedirect();

        $service->refresh();

        $this->assertSame(['Ofisler', 'Fabrikalar'], $service->audience);
        $this->assertSame(['Öngörülebilir maliyet'], $service->benefits);
        $this->assertSame(['Kişi sayısı'], $service->quote_needs);
    }

    /** Kaydedilen düz liste formda yeniden satır olarak çizilir. */
    public function test_duz_liste_formda_satir_olarak_cizilir(): void
    {
        $this->actingAsAdmin();

        $service = $this->makeService();
        $service->audience = ['Ofisler', 'Fabrikalar'];
        $service->save();

        $this->get(self::SERVICES_URI.'/edit/'.$service->id)
            ->assertOk()
            ->assertSee('Fabrikalar', false);
    }

    /**
     * Boş satırlar düşürülür — "ekle"ye basıp doldurmadan kaydetmek sık olur
     * ve boş bir madde sitede içi boş bir madde işareti çizerdi.
     */
    public function test_bos_satirlar_kaydedilmez(): void
    {
        $this->actingAsAdmin();

        $service = $this->makeService();

        $this->saveService($service->id, [
            'audience' => [['text' => 'Ofisler'], ['text' => '   '], ['text' => '']],
            'how_it_works' => [
                ['title' => 'Görüşme', 'body' => 'İhtiyaç konuşulur.'],
                ['title' => '', 'body' => ''],
            ],
        ])->assertRedirect();

        $service->refresh();

        $this->assertSame(['Ofisler'], $service->audience);
        $this->assertCount(1, $service->how_it_works);
    }

    /**
     * SON MADDE SİLİNEBİLMELİ.
     *
     * Alan POST'ta boş dizi olarak gelir; doğrulanmış diziye güvenilseydi
     * anahtar atlanır ve eski maddeler kayıtta kalırdı — yönetici için
     * "sildim ama geri geldi" demektir.
     */
    public function test_son_madde_silinebilir(): void
    {
        $this->actingAsAdmin();

        $service = $this->makeService();
        $service->audience = ['Ofisler'];
        $service->save();

        $this->saveService($service->id, ['audience' => []])->assertRedirect();

        $this->assertSame([], $service->refresh()->audience);
    }

    // ── Adres (slug) ──────────────────────────────────────────────────────

    /** Kendi adresiyle kaydetmek çakışma sayılmaz. */
    public function test_kayit_kendi_adresiyle_cakismaz(): void
    {
        $this->actingAsAdmin();

        $service = $this->makeService();

        $this->saveService($service->id, [])->assertRedirect();

        $this->assertSame('test-hizmet', $service->refresh()->slug);
    }

    /** Başka bir kaydın adresi alınamaz. */
    public function test_baska_kaydin_adresi_alinamaz(): void
    {
        $this->actingAsAdmin();

        $this->makeService('ilk-hizmet');
        $second = $this->makeService('ikinci-hizmet');

        // BAŞARISIZ KAYDETME YÖNLENDİRMEZ, FORMU YENİDEN ÇİZER (200).
        // Yönlendirme yalnızca kayıt gerçekten yazıldığında olur
        // (`FormController::edit_onSave` doğrulama düşerse `null` döner);
        // bu yüzden başarının ölçütü durum kodu değil, veritabanıdır.
        $this->saveService($second->id, ['slug' => 'ilk-hizmet'])->assertOk();

        $this->assertSame('ikinci-hizmet', $second->refresh()->slug);
    }

    /** Büyük harf ve Türkçe karakter içeren adres reddedilir. */
    public function test_bozuk_adres_reddedilir(): void
    {
        $this->actingAsAdmin();

        $service = $this->makeService();

        $this->saveService($service->id, ['slug' => 'Kurumsal Yemek'])->assertOk();

        $this->assertSame('test-hizmet', $service->refresh()->slug);
    }

    // ── Yazılar ───────────────────────────────────────────────────────────

    /**
     * Boş okuma süresi `0` değil `null` kaydedilir.
     *
     * `SitePost::readingMinutes()` "elle girildi mi" sorusunu `null`
     * kontrolüyle cevaplıyor; `0` yazılsaydı sütun dolu görünür ve formu bir
     * daha açan yönetici oraya kendisinin değer girdiğini sanırdı.
     */
    public function test_bos_okuma_suresi_null_kaydedilir(): void
    {
        $this->actingAsAdmin();

        $post = $this->makePost();
        $post->reading_minutes = 7;
        $post->save();

        $this->savePost($post->id, ['reading_minutes' => ''])->assertRedirect();

        $post->refresh();

        $this->assertNull($post->reading_minutes);
        // Elle değer yokken süre gövdeden hesaplanır, sıfır dönmez.
        $this->assertGreaterThan(0, $post->readingMinutes());
    }

    public function test_yazi_govdesi_zorunludur(): void
    {
        $this->actingAsAdmin();

        $post = $this->makePost();

        $this->savePost($post->id, ['body_html' => ''])->assertOk();

        $this->assertNotSame('', $post->refresh()->body_html);
    }

    // ── Önbellek ──────────────────────────────────────────────────────────

    /**
     * Kaydet ve sil, site paketinin önbelleğini düşürmeli.
     *
     * Düşmezse yönetici değişikliğini sitede bir saat boyunca göremez ve
     * ekranın çalıştığına inanmaz.
     */
    public function test_kayit_ve_silme_site_onbellegini_dusurur(): void
    {
        $repository = resolve(SiteContentRepository::class);

        $repository->bundle();
        $this->assertTrue(Cache::has(SiteContentRepository::CACHE_KEY));

        $service = $this->makeService();
        $this->assertFalse(Cache::has(SiteContentRepository::CACHE_KEY));

        $repository->bundle();
        $service->delete();
        $this->assertFalse(Cache::has(SiteContentRepository::CACHE_KEY));
    }

    /** Panelden girilen kayıt site paketinde görünür. */
    public function test_kayit_site_paketinde_gorunur(): void
    {
        $this->actingAsAdmin();

        $service = $this->makeService();
        $this->saveService($service->id, [
            'audience' => [['text' => 'Ofisler']],
        ])->assertRedirect();

        $bundle = resolve(SiteContentRepository::class)->bundle();

        $published = collect($bundle['services'])->firstWhere('slug', 'test-hizmet');

        $this->assertNotNull($published);
        $this->assertSame(['Ofisler'], $published['audience']);
    }

    // ── Yetki ─────────────────────────────────────────────────────────────

    /**
     * İçerik yetkisi olmayan yönetici ekranı açamaz.
     *
     * Yetkinin ayrı bir kutu olmasının bütün anlamı bu: içerik yazarı fiyata
     * ve mutfak kasasına, işletmeci de yanlışlıkla siteye dokunmamalı.
     *
     * BEKLENEN KOD 403 DEĞİL 406: çekirdek yetkisiz erişimi `FlashException`
     * ile durduruyor ve o sınıfın varsayılan kodu 406'dır
     * (`Igniter\Flame\Exception\FlashException::__construct`). Kod bizim
     * seçimimiz değil, panelin tamamında geçerli kural.
     */
    public function test_yetkisiz_yonetici_ekrani_acamaz(): void
    {
        $this->actingAsAdmin(superUser: false);

        $this->get(self::SERVICES_URI)->assertStatus(406);
        $this->get(self::POSTS_URI)->assertStatus(406);
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    private function makeService(string $slug = 'test-hizmet'): SiteService
    {
        $service = new SiteService;
        $service->fill($this->serviceAttributes($slug));
        $service->save();

        return $service;
    }

    private function makePost(string $slug = 'test-yazi'): SitePost
    {
        $post = new SitePost;
        $post->fill($this->postAttributes($slug));
        $post->save();

        return $post;
    }

    /** @return array<string, mixed> */
    private function serviceAttributes(string $slug = 'test-hizmet'): array
    {
        return [
            'slug' => $slug,
            'title' => 'Test hizmet',
            'summary' => 'Tek cümlelik özet.',
            'intro' => 'Giriş paragrafı.',
            'icon' => 'Building2',
            'audience' => [],
            'how_it_works' => [],
            'benefits' => [],
            'menu_planning' => 'Menü profile göre kurgulanır.',
            'quote_needs' => [],
            'sort_order' => 0,
            'is_published' => true,
        ];
    }

    /** @return array<string, mixed> */
    private function postAttributes(string $slug = 'test-yazi'): array
    {
        return [
            'slug' => $slug,
            'title' => 'Test yazı',
            'description' => 'Kısa açıklama.',
            'category' => 'Gıda güvenliği',
            'body_html' => '<p>'.str_repeat('kelime ', 300).'</p>',
            'published_at' => '2026-08-01',
            'is_published' => true,
        ];
    }

    /**
     * Düzenleme formunu, tarayıcının yapacağı gibi TÜM alanlarla gönderir.
     *
     * Yalnızca değişen alanı göndermek gerçekçi olmazdı: tarayıcı formun
     * tamamını gönderiyor ve eksik gönderilen zorunlu alan doğrulamaya
     * takılırdı — yani test, ölçmek istediği şeyi değil kendi eksiğini
     * ölçerdi.
     *
     * @param  array<string, mixed>  $overrides
     */
    private function saveService(int $id, array $overrides): TestResponse
    {
        $payload = array_merge($this->serviceAttributes(), [
            'body_html' => '',
        ], $overrides);

        return $this->post(self::SERVICES_URI.'/edit/'.$id, [
            '_handler' => 'onSave',
            self::SERVICE_ARRAY => $payload,
        ]);
    }

    /** @param  array<string, mixed>  $overrides */
    private function savePost(int $id, array $overrides): TestResponse
    {
        $payload = array_merge($this->postAttributes(), $overrides);

        return $this->post(self::POSTS_URI.'/edit/'.$id, [
            '_handler' => 'onSave',
            self::POST_ARRAY => $payload,
        ]);
    }

    private function actingAsAdmin(bool $superUser = true): void
    {
        $user = new User;
        $user->fill([
            'name' => 'Test Yönetici',
            'username' => 'testyonetici',
            'email' => 'yonetici@ornek.com',
            'status' => true,
            'super_user' => $superUser,
        ]);
        $user->password = 'parola123';
        $user->is_activated = true;
        $user->activated_at = now();
        $user->save();

        AdminAuth::login($user);
    }
}
