<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Illuminate\Support\Carbon;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Models\Announcement;
use Veykemtu\BridgeApi\Models\AnnouncementRead;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Uygulama-içi duyurular — `GET /api/announcements` ve işaret uçları.
 *
 * BU PAKETİN AĞIRLIK MERKEZİ: **yanlış kişiye yanlış duyuru gitmesin ve
 * kapatılan duyuru geri gelmesin.** Push yok; duyuru müşteriye ulaşan iki
 * kanaldan biri ve tek gösterim şansı var. Süzgeçlerin dördü de (yayın
 * durumu, pencere, kitle, kapatma) sunucuda ve dördü de burada tutuluyor —
 * biri sessizce bozulursa müşteri ya hiç duyuru görmez ya da yarım yazılmış
 * bir taslağı görür.
 *
 * `dismiss` ile `seen` ayrımı ayrıca sınanıyor: görülmek duyuruyu listeden
 * DÜŞÜRMEZ. İkisi karıştığında ekranda çizilen her duyuru ilk karede
 * kaybolur ve kimse okuyamaz — sessiz, kimsenin hata olarak bildirmeyeceği
 * bir arıza.
 */
class AnnouncementTest extends KitchenTestCase
{
    private const string ENDPOINT = '/api/announcements';

    protected function tearDown(): void
    {
        // Donmuş saat sızarsa sonraki paketler sebepsiz kırılır.
        Carbon::setTestNow();

        parent::tearDown();
    }

    // ── Listeleme ────────────────────────────────────────────────────────

    public function test_yayindaki_duyuru_sozlesme_alanlariyla_doner(): void
    {
        $announcement = $this->announcement([
            'title' => 'Yarın servis yok',
            'body' => 'Resmî tatil sebebiyle yarın teslimat yapılmayacaktır.',
            'placement' => 'home',
            'severity' => Announcement::SEVERITY_CRITICAL,
            'action_label' => 'Takvime bak',
            'action_type' => 'route',
            'action_value' => '/menu-takvimi',
        ]);

        $response = $this->asCustomer()->getJson(self::ENDPOINT, self::HEADERS);

        $response->assertOk()
            ->assertJsonPath('data.0.id', (int) $announcement->id)
            ->assertJsonPath('data.0.placement', 'home')
            ->assertJsonPath('data.0.severity', Announcement::SEVERITY_CRITICAL)
            ->assertJsonPath('data.0.title', 'Yarın servis yok')
            ->assertJsonPath('data.0.action_label', 'Takvime bak')
            ->assertJsonPath('data.0.action_url', '/menu-takvimi')
            ->assertJsonPath('data.0.dismissible', true)
            ->assertJsonPath('data.0.seen', false)
            ->assertJsonPath('data.0.dismissed', false);
    }

    /**
     * DUYURU YOKSA `[]` — 404 DEĞİL.
     *
     * Duyurusuz gün olağan hâldir. 404 dönseydi her istemci açılışta bir
     * hata yakalamak zorunda kalır, yakalamayı unutan istemci hiç duyuru
     * yokken kırmızı bir hata ekranı gösterirdi.
     */
    public function test_duyuru_yoksa_bos_liste_doner(): void
    {
        $this->asCustomer()->getJson(self::ENDPOINT, self::HEADERS)
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    public function test_taslak_ve_arsivlenmis_duyuru_donmez(): void
    {
        $this->announcement(['body' => 'Taslak', 'status' => Announcement::STATUS_DRAFT]);
        $this->announcement(['body' => 'Arşiv', 'status' => Announcement::STATUS_ARCHIVED]);
        $this->announcement(['body' => 'Yayında']);

        $response = $this->asCustomer()->getJson(self::ENDPOINT, self::HEADERS);

        $response->assertOk()->assertJsonCount(1, 'data');
        $this->assertSame('Yayında', $response->json('data.0.body'));
    }

    /**
     * Pencere sunucuda uygulanıyor.
     *
     * İstemciye bırakılsaydı saati kaymış bir telefon süresi dolmuş
     * duyuruyu göstermeye devam ederdi — hizmet kesintisi duyurusu bittikten
     * sonra da ekranda kalırdı.
     */
    public function test_pencere_disindaki_duyuru_donmez(): void
    {
        $now = BusinessTime::forStorage(Carbon::now());

        $this->announcement([
            'body' => 'Henüz başlamadı',
            'starts_at' => $now->copy()->addHour(),
        ]);
        $this->announcement([
            'body' => 'Süresi doldu',
            'ends_at' => $now->copy()->subHour(),
        ]);
        $this->announcement([
            'body' => 'Tam pencerede',
            'starts_at' => $now->copy()->subHour(),
            'ends_at' => $now->copy()->addHour(),
        ]);

        $response = $this->asCustomer()->getJson(self::ENDPOINT, self::HEADERS);

        $response->assertOk()->assertJsonCount(1, 'data');
        $this->assertSame('Tam pencerede', $response->json('data.0.body'));
    }

    /**
     * Bilinmeyen yerleşim `422` DEĞİL, boş liste üretir.
     *
     * Yerleşim kümesi panelde büyüyor; sözleşmede olmayan bir yerleşimi
     * soran istemcinin ekranı hata vermek yerine duyurusuz açılmalı.
     */
    public function test_bilinmeyen_yerlesim_bos_liste_doner(): void
    {
        $this->announcement(['placement' => 'home']);

        $this->asCustomer()->getJson(self::ENDPOINT.'?placement=uzay-istasyonu', self::HEADERS)
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->asCustomer()->getJson(self::ENDPOINT.'?placement=home', self::HEADERS)
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }

    /**
     * Sıralama sunucudan: önce `critical`, sonra öncelik, sonra yeni olan.
     *
     * Belirsiz bir sıra, aynı listeyi iki kez çeken istemcide duyuruların
     * yer değiştirmesi demek olurdu.
     */
    public function test_kritik_duyuru_once_doner(): void
    {
        $this->announcement(['body' => 'Yüksek öncelikli bilgi', 'priority' => 50]);
        $this->announcement([
            'body' => 'Kritik',
            'severity' => Announcement::SEVERITY_CRITICAL,
            'priority' => 0,
        ]);
        $this->announcement(['body' => 'Sıradan', 'priority' => 1]);

        $response = $this->asCustomer()->getJson(self::ENDPOINT, self::HEADERS);

        $response->assertOk()->assertJsonCount(3, 'data');
        $this->assertSame('Kritik', $response->json('data.0.body'));
        $this->assertSame('Yüksek öncelikli bilgi', $response->json('data.1.body'));
    }

    // ── Kitle ────────────────────────────────────────────────────────────

    /**
     * `audience = subscribers` YALNIZ ABONEYE gider.
     *
     * "Aboneliğinizi yenileyin" duyurusunu abone olmayana göstermek, satın
     * alması gereken şeyi zaten satın almış müşteriye "al" demek kadar
     * kötüdür — tersi de aynı derecede yanlış.
     */
    public function test_abone_kitlesi_duz_musteriye_donmez(): void
    {
        $this->announcement([
            'body' => 'Aboneliğe özel',
            'audience' => Announcement::AUDIENCE_SUBSCRIBERS,
        ]);
        $this->announcement([
            'body' => 'Abone olmayanlara',
            'audience' => Announcement::AUDIENCE_NON_SUBSCRIBERS,
        ]);
        $this->announcement(['body' => 'Herkese']);

        $response = $this->asCustomer()->getJson(self::ENDPOINT, self::HEADERS);

        $bodies = collect($response->assertOk()->json('data'))->pluck('body')->all();

        $this->assertContains('Herkese', $bodies);
        $this->assertContains('Abone olmayanlara', $bodies);
        $this->assertNotContains('Aboneliğe özel', $bodies);
    }

    public function test_abone_kitlesi_aboneye_doner(): void
    {
        $this->announcement([
            'body' => 'Aboneliğe özel',
            'audience' => Announcement::AUDIENCE_SUBSCRIBERS,
        ]);
        $this->announcement([
            'body' => 'Abone olmayanlara',
            'audience' => Announcement::AUDIENCE_NON_SUBSCRIBERS,
        ]);

        $this->asCustomer();
        $this->subscribe();

        $bodies = collect($this->getJson(self::ENDPOINT, self::HEADERS)->assertOk()->json('data'))
            ->pluck('body')
            ->all();

        $this->assertContains('Aboneliğe özel', $bodies);
        $this->assertNotContains('Abone olmayanlara', $bodies);
    }

    // ── Görüldü / kapat ──────────────────────────────────────────────────

    /**
     * GÖRÜLMEK LİSTEDEN DÜŞÜRMEZ — kapatmak düşürür.
     *
     * İkisi tek uca indirilseydi ekranda çizilen her duyuru ilk karede
     * kaybolur, müşteri okumaya fırsat bulamazdı.
     */
    public function test_gorulen_duyuru_listede_kalir_isaretli_doner(): void
    {
        $announcement = $this->announcement();

        $this->asCustomer()
            ->postJson(self::ENDPOINT.'/'.$announcement->id.'/seen', [], self::HEADERS)
            ->assertNoContent();

        $this->getJson(self::ENDPOINT, self::HEADERS)
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.seen', true)
            ->assertJsonPath('data.0.dismissed', false);
    }

    /**
     * `seen` İDEMPOTENT ve İLK ANI KORUR.
     *
     * İstemci ağ hatasında ucu tekrar çağırır. Damga her çağrıda
     * tazelenseydi "bu duyuru müşteriye ne zaman ulaştı" sorusunun cevabı,
     * en son ne zaman baktığına dönüşürdü.
     */
    public function test_gorulme_isareti_ilk_ani_degistirmez(): void
    {
        $announcement = $this->announcement();

        Carbon::setTestNow(Carbon::parse('2026-09-08 09:00:00'));
        $this->asCustomer()
            ->postJson(self::ENDPOINT.'/'.$announcement->id.'/seen', [], self::HEADERS)
            ->assertNoContent();

        $first = AnnouncementRead::firstOrFail()->seen_at;

        Carbon::setTestNow(Carbon::parse('2026-09-08 11:00:00'));
        $this->postJson(self::ENDPOINT.'/'.$announcement->id.'/seen', [], self::HEADERS)
            ->assertNoContent();

        $this->assertSame(1, AnnouncementRead::query()->count());
        $this->assertEquals(
            $first,
            AnnouncementRead::firstOrFail()->seen_at,
            'İlk görülme anı korunmalı.',
        );
    }

    public function test_kapatilan_duyuru_bir_daha_donmez(): void
    {
        $announcement = $this->announcement();

        $this->asCustomer()
            ->postJson(self::ENDPOINT.'/'.$announcement->id.'/dismiss', [], self::HEADERS)
            ->assertNoContent();

        $this->getJson(self::ENDPOINT, self::HEADERS)
            ->assertOk()
            ->assertJsonCount(0, 'data');

        // İdempotent: zaten kapatılmış duyuru için de 204.
        $this->postJson(self::ENDPOINT.'/'.$announcement->id.'/dismiss', [], self::HEADERS)
            ->assertNoContent();

        $this->assertSame(1, AnnouncementRead::query()->count());
    }

    /**
     * `dismissible = false` duyuru kapatılamaz.
     *
     * Kapatılamayan bir duyuruyu istemcinin isteğiyle kapatmak, hizmet
     * kesintisi duyurusunu ilk dokunuşta yok etmek olurdu.
     */
    public function test_kapatilamayan_duyuru_422_doner(): void
    {
        $announcement = $this->announcement(['dismissible' => false]);

        $this->asCustomer()
            ->postJson(self::ENDPOINT.'/'.$announcement->id.'/dismiss', [], self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED');

        $this->getJson(self::ENDPOINT, self::HEADERS)->assertOk()->assertJsonCount(1, 'data');
    }

    public function test_olmayan_duyuru_404_doner(): void
    {
        $this->asCustomer()
            ->postJson(self::ENDPOINT.'/999999/seen', [], self::HEADERS)
            ->assertStatus(404)
            ->assertJsonPath('error.code', 'NOT_FOUND');
    }

    public function test_kimliksiz_istek_401_doner(): void
    {
        $this->getJson(self::ENDPOINT, self::HEADERS)
            ->assertStatus(401)
            ->assertJsonPath('error.code', 'UNAUTHENTICATED');
    }

    // ── Yardımcılar ──────────────────────────────────────────────────────

    /** @param array<string, mixed> $overrides */
    private function announcement(array $overrides = []): Announcement
    {
        $announcement = new Announcement;
        $announcement->fill(array_merge([
            'title' => 'Duyuru',
            'body' => 'Duyuru metni.',
            'placement' => 'home',
            'severity' => Announcement::SEVERITY_INFO,
            'style' => Announcement::STYLE_BANNER,
            'audience' => Announcement::AUDIENCE_ALL,
            'status' => Announcement::STATUS_PUBLISHED,
            'dismissible' => true,
            'priority' => 0,
        ], $overrides));
        $announcement->save();

        return $announcement;
    }

    /** Test müşterisini aboneye çevirir. */
    private function subscribe(): void
    {
        $customer = ApiCustomer::where('email', 'test@ornek.com')->firstOrFail();

        $subscription = new Subscription;
        $subscription->fill([
            'customer_id' => (int) $customer->getKey(),
            'location_id' => $this->locationId(),
            'status' => Subscription::STATUS_ACTIVE,
            'start_date' => BusinessTime::today(),
            'service_days' => [1, 2, 3, 4, 5],
            'menu_mode' => Subscription::MENU_DAILY,
            'payment_mode' => Subscription::PAYMENT_PREPAID,
        ]);
        $subscription->save();
    }
}
