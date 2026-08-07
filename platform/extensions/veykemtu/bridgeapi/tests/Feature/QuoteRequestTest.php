<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\User\Facades\AdminAuth;
use Igniter\User\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;
use Veykemtu\BridgeApi\Models\QuoteRequest;

/**
 * Teklif talebi ucu ve panel ekranı.
 *
 * Testlerin ağırlık merkezi TEK BİR SORUDA: **talep kayboluyor mu?** Bu uç
 * için "hatalı istek" diye bir şey yok, "kaybedilmiş müşteri" var. Bu yüzden
 * mutlu yoldan çok, sitenin beklenmedik bir şey gönderdiği yollar test
 * ediliyor: bilinmeyen alan, bilinmeyen enum değeri, çözümlenemeyen tarih,
 * sınırı aşan metin. Hepsi 201 dönmeli.
 *
 * Reddedilmesi GEREKEN iki yol da burada: KVKK onayı yoksa ve kişiye
 * ulaşmanın hiçbir yolu yoksa. Bu ikisi bilinçli kayıptır.
 */
class QuoteRequestTest extends TestCase
{
    // `refreshTestDatabase` bir trait metodudur; `parent::` ile çağrılamaz.
    use RefreshDatabase {
        refreshTestDatabase as private laravelRefreshTestDatabase;
    }

    private const array HEADERS = [
        'X-App-Id' => 'website',
        'X-App-Version' => '1.0.0',
        'Accept' => 'application/json',
    ];

    private const string ENDPOINT = '/api/quote-requests';

    private const string ADMIN_URI = '/admin/veykemtu/bridgeapi/quote_requests';

    /**
     * Form parçacığının alan adlarını kuşattığı dizi adı — çekirdek bunu
     * modelin sınıf adından türetiyor (`Widgets\Form::initForm`).
     */
    private const string FORM_ARRAY = 'QuoteRequest';

    /** Gerekçe `ContractTest::refreshTestDatabase` üzerinde. */
    protected function refreshTestDatabase(): void
    {
        $this->assertTestDatabase();

        $this->laravelRefreshTestDatabase();

        $this->artisan('igniter:up');
    }

    /** Gerekçe `ContractTest::assertTestDatabase` üzerinde — aynı koruma. */
    private function assertTestDatabase(): void
    {
        $name = (string) DB::connection()->getDatabaseName();

        if (! str_ends_with($name, '_test')) {
            $this->fail(
                "Testler '{$name}' veritabanına bağlı ve bir sonraki adım tüm "
                .'tabloları düşürecekti. Test veritabanı adı "_test" ile bitmelidir.',
            );
        }
    }

    // ── Uç: kabul edilen yollar ───────────────────────────────────────────

    public function test_tam_govde_kaydedilir(): void
    {
        $response = $this->postJson(self::ENDPOINT, $this->payload(), self::HEADERS);

        $response->assertCreated()->assertJson(['status' => QuoteRequest::STATUS_NEW]);

        $quote = QuoteRequest::firstOrFail();

        $this->assertSame('Ayşe Yılmaz', $quote->full_name);
        $this->assertSame('Örnek Sanayi A.Ş.', $quote->organization);
        $this->assertSame('5551234567', $quote->telephone);
        $this->assertSame('kurumsal-toplu-yemek', $quote->service_type);
        $this->assertSame(250, $quote->headcount);
        $this->assertSame('2026-09-01', $quote->start_date?->toDateString());
        $this->assertNotNull($quote->kvkk_accepted_at);
    }

    /**
     * Yanıt kaydın kendisini DÖNMEZ.
     *
     * Uç herkese açık; `id` dönmek, formu iki kez dolduran herkese firmanın
     * aldığı talep sayısını sızdırırdı. Gerekçe denetleyicide.
     */
    public function test_yanit_kisisel_veri_ve_kimlik_sizdirmaz(): void
    {
        $response = $this->postJson(self::ENDPOINT, $this->payload(), self::HEADERS);

        $response->assertCreated()->assertJsonStructure(['status', 'received_at']);

        $this->assertArrayNotHasKey('id', (array) $response->json());
        $response->assertJsonMissing(['telephone' => '5551234567']);
    }

    /**
     * SÖZLEŞME DIŞI ALANLAR TALEBİ DÜŞÜRMEZ.
     *
     * Bu testin varlık sebebi: site bir sürüm önde gidip gövdeye yeni bir
     * alan eklediğinde (`utm_source` gibi) uç 422 dönseydi, talep akışı
     * tamamen dururdu ve bunu kimse fark etmezdi — form "gönderildi" demeye
     * devam ederdi.
     */
    public function test_bilinmeyen_alanlar_sessizce_yok_sayilir(): void
    {
        $payload = $this->payload([
            'utm_source' => 'google',
            'utm_campaign' => 'yaz-2026',
            'nested' => ['a' => 1],
            'liste' => [1, 2, 3],
        ]);

        $this->postJson(self::ENDPOINT, $payload, self::HEADERS)->assertCreated();

        $this->assertSame(1, QuoteRequest::count());
    }

    /**
     * `status` ve `admin_note` GÖVDEDEN ATANAMAZ.
     *
     * Model `$guarded = []` ile korumasız; alanlar beyaz listeyle tek tek
     * okunmasaydı, ziyaretçi kendi talebini "cevaplandı" işaretleyip
     * listenin dibine gönderebilirdi.
     */
    public function test_takip_alanlari_disaridan_atanamaz(): void
    {
        $payload = $this->payload([
            'status' => 'kapandi',
            'admin_note' => 'sızdırma denemesi',
        ]);

        $this->postJson(self::ENDPOINT, $payload, self::HEADERS)->assertCreated();

        $quote = QuoteRequest::firstOrFail();

        $this->assertSame(QuoteRequest::STATUS_NEW, $quote->status);
        $this->assertNull($quote->admin_note);
    }

    /**
     * Bilinmeyen hizmet/sıklık/menü değerleri saklanır, reddedilmez.
     *
     * Slug'lar `website/content/services.ts` içinde doğuyor; enum kısıtı,
     * yeni bir hizmetin eklendiği gün gelen her talebi çöpe atardı.
     */
    public function test_bilinmeyen_enum_degerleri_kabul_edilir(): void
    {
        $payload = $this->payload([
            'service_type' => 'henuz-tanimsiz-hizmet',
            'frequency' => 'her-ay-bir-kere',
            'menu_preference' => 'vegan-mutlaka',
        ]);

        $this->postJson(self::ENDPOINT, $payload, self::HEADERS)->assertCreated();

        $this->assertSame('henuz-tanimsiz-hizmet', QuoteRequest::firstOrFail()->service_type);
    }

    /** Çözümlenemeyen tarih ve rakam olmayan kişi sayısı boş kalır, talep durur. */
    public function test_bozuk_tarih_ve_sayi_talebi_dusurmez(): void
    {
        $payload = $this->payload([
            'start_date' => 'yazın',
            'headcount' => 'bin kişi',
        ]);

        $this->postJson(self::ENDPOINT, $payload, self::HEADERS)->assertCreated();

        $quote = QuoteRequest::firstOrFail();

        $this->assertNull($quote->start_date);
        $this->assertNull($quote->headcount);
    }

    /** Sütun sınırını aşan metin kesilir; 100 karakter fazlalık için müşteri kaybedilmez. */
    public function test_uzun_metin_kesilir_reddedilmez(): void
    {
        $payload = $this->payload([
            'full_name' => str_repeat('a', 300),
            'message' => str_repeat('b', 9000),
        ]);

        $this->postJson(self::ENDPOINT, $payload, self::HEADERS)->assertCreated();

        $quote = QuoteRequest::firstOrFail();

        $this->assertSame(120, mb_strlen((string) $quote->full_name));
        $this->assertSame(5000, mb_strlen((string) $quote->message));
    }

    /** Telefon yoksa e-posta yeter; ikisini birden istemek formu terk ettirir. */
    public function test_tek_iletisim_kanali_yeterlidir(): void
    {
        $payload = $this->payload(['telephone' => null]);

        $this->postJson(self::ENDPOINT, $payload, self::HEADERS)->assertCreated();
    }

    /**
     * AYNI KİŞİNİN İKİNCİ GÖNDERİMİ AYRI KAYITTIR.
     *
     * Tekilleştirme yok: aynı firma iki farklı etkinlik için iki teklif
     * isteyebilir ve ikincisini "kopya" sayıp yutmak gerçek bir işi
     * sessizce kaybetmek olurdu.
     */
    public function test_ikinci_gonderim_ikinci_kayit_olur(): void
    {
        $this->postJson(self::ENDPOINT, $this->payload(), self::HEADERS)->assertCreated();
        $this->postJson(self::ENDPOINT, $this->payload(), self::HEADERS)->assertCreated();

        $this->assertSame(2, QuoteRequest::count());
    }

    // ── Uç: bilinçli olarak reddedilen yollar ─────────────────────────────

    /** Onaysız kişisel veri saklamak hukuki sorundur; kayıt hiç oluşmaz. */
    public function test_kvkk_onayi_olmadan_reddedilir(): void
    {
        $response = $this->postJson(
            self::ENDPOINT,
            $this->payload(['kvkk_accepted' => false]),
            self::HEADERS,
        );

        $response->assertStatus(422)->assertJsonPath('error.code', 'VALIDATION_FAILED');

        $this->assertSame(0, QuoteRequest::count());
    }

    public function test_kvkk_alani_hic_gonderilmezse_reddedilir(): void
    {
        $payload = $this->payload();
        unset($payload['kvkk_accepted']);

        $this->postJson(self::ENDPOINT, $payload, self::HEADERS)->assertStatus(422);

        $this->assertSame(0, QuoteRequest::count());
    }

    /**
     * Ulaşılamayan talep kayıt değil, gereksiz kişisel veridir.
     *
     * Firma teklifi kimseye gönderemez; kaydı tutmak yalnızca saklanacak
     * veri yığınını büyütür.
     */
    public function test_iletisim_kanali_yoksa_reddedilir(): void
    {
        $response = $this->postJson(
            self::ENDPOINT,
            $this->payload(['telephone' => null, 'email' => null]),
            self::HEADERS,
        );

        $response->assertStatus(422);

        $this->assertSame(0, QuoteRequest::count());
    }

    public function test_ad_olmadan_reddedilir(): void
    {
        $this->postJson(self::ENDPOINT, $this->payload(['full_name' => '']), self::HEADERS)
            ->assertStatus(422);
    }

    /** Zorunlu istemci başlıkları burada da geçerli (`docs/03` §1.1). */
    public function test_basliksiz_istek_reddedilir(): void
    {
        $this->postJson(self::ENDPOINT, $this->payload())->assertStatus(422);
    }

    // ── Panel ekranı ──────────────────────────────────────────────────────

    public function test_panel_ekranlari_acilir(): void
    {
        $this->actingAsAdmin();

        $quote = $this->makeQuote();

        $this->get(self::ADMIN_URI)->assertOk();
        $this->get(self::ADMIN_URI.'/edit/'.$quote->id)->assertOk();
    }

    /**
     * Talep panelden oluşturulamaz: kaynağı yalnızca sitedeki formdur.
     *
     * BEKLENEN KOD 404 DEĞİL 406. `formConfig`'te `create` bağlamı tanımlı
     * olmadığı için çekirdek sayfayı `FlashException` ile durduruyor ve o
     * sınıfın varsayılan kodu 406'dır — panelin tamamında geçerli kural,
     * bizim seçimimiz değil. Listede zaten "Yeni" düğmesi yok; bu adrese
     * ancak elle yazarak gelinir.
     */
    public function test_panelden_yeni_talep_olusturulamaz(): void
    {
        $this->actingAsAdmin();

        $this->get(self::ADMIN_URI.'/create')->assertStatus(406);
    }

    public function test_durum_ve_ic_not_panelden_degistirilir(): void
    {
        $this->actingAsAdmin();

        $quote = $this->makeQuote();

        $this->post(self::ADMIN_URI.'/edit/'.$quote->id, [
            '_handler' => 'onSave',
            self::FORM_ARRAY => [
                'status' => 'cevaplandi',
                'admin_note' => 'Teklif gönderildi, salı aranacak.',
            ],
        ])->assertRedirect();

        $quote->refresh();

        $this->assertSame('cevaplandi', $quote->status);
        $this->assertSame('Teklif gönderildi, salı aranacak.', $quote->admin_note);
    }

    /**
     * ZİYARETÇİNİN BEYANI PANELDEN DEĞİŞTİRİLEMEZ.
     *
     * Alanlar formda hiç yok (tek bir salt okunur `partial`), ama forma elle
     * gönderilen değerin de geçmediği burada sabitleniyor: bir beyanın
     * sonradan "düzeltilebilmesi" kaydın değerini bitirir.
     */
    public function test_ziyaretcinin_beyani_panelden_degistirilemez(): void
    {
        $this->actingAsAdmin();

        $quote = $this->makeQuote();

        $this->post(self::ADMIN_URI.'/edit/'.$quote->id, [
            '_handler' => 'onSave',
            self::FORM_ARRAY => [
                'status' => 'okundu',
                'admin_note' => null,
                'full_name' => 'Başka Biri',
                'telephone' => '5000000000',
            ],
        ])->assertRedirect();

        $quote->refresh();

        $this->assertSame('Ayşe Yılmaz', $quote->full_name);
        $this->assertSame('5551234567', $quote->telephone);
    }

    /** Sözleşme dışı bir durum değeri kaydedilmez. */
    public function test_gecersiz_durum_kaydedilmez(): void
    {
        $this->actingAsAdmin();

        $quote = $this->makeQuote();

        $response = $this->post(self::ADMIN_URI.'/edit/'.$quote->id, [
            '_handler' => 'onSave',
            self::FORM_ARRAY => ['status' => 'uydurma', 'admin_note' => null],
        ]);

        // Doğrulama düşünce çekirdek YÖNLENDİRMİYOR, formda kalıp hatayı
        // gösteriyor (`FormController::edit_onSave` `null` döndürüyor).
        // Ölçüt bu yüzden yönlendirme yokluğu ve kaydın değişmemesi.
        $this->assertFalse($response->isRedirect(), 'Geçersiz durum kaydedilip yönlendirilmemeli.');

        $this->assertSame(QuoteRequest::STATUS_NEW, $quote->refresh()->status);
    }

    /**
     * KİŞİSEL VERİ İÇERİK YETKİSİYLE AÇILMAZ.
     *
     * `PERMISSION_QUOTES`'un ayrı bir kutu olmasının bütün anlamı bu.
     * Beklenen kod 403 değil 406: gerekçe `AdminSiteContentTest` içindeki
     * aynı testin üzerindedir (çekirdek `FlashException` kullanıyor).
     */
    public function test_yetkisiz_yonetici_ekrani_acamaz(): void
    {
        $this->actingAsAdmin(superUser: false);

        $this->get(self::ADMIN_URI)->assertStatus(406);
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    /**
     * Sitenin gönderdiği gövde (`website/app/actions/quote.ts`).
     *
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function payload(array $overrides = []): array
    {
        return array_merge([
            'full_name' => 'Ayşe Yılmaz',
            'organization' => 'Örnek Sanayi A.Ş.',
            'telephone' => '5551234567',
            'email' => 'ayse@ornek.com',
            'service_type' => 'kurumsal-toplu-yemek',
            'headcount' => 250,
            'frequency' => 'haftaici',
            'start_date' => '2026-09-01',
            'location' => 'İstanbul / Tuzla',
            'menu_preference' => 'dort-kap',
            'message' => 'Öğle servisi, iki vardiya.',
            'kvkk_accepted' => true,
            'submitted_at' => '2026-08-07T09:15:00.000Z',
        ], $overrides);
    }

    private function makeQuote(): QuoteRequest
    {
        $quote = new QuoteRequest;
        $quote->fill([
            'full_name' => 'Ayşe Yılmaz',
            'organization' => 'Örnek Sanayi A.Ş.',
            'telephone' => '5551234567',
            'email' => 'ayse@ornek.com',
            'service_type' => 'kurumsal-toplu-yemek',
            'headcount' => 250,
            'frequency' => 'haftaici',
            // Tarih ve uzun metin bilinçli olarak dolu: detay ekranının
            // künye parçacığı bu iki alanı biçimlendiriyor ve boş kayıtla
            // test edilseydi biçimlendirme hatası hiç görünmezdi.
            'start_date' => '2026-09-01',
            'location' => 'İstanbul / Tuzla',
            'menu_preference' => 'dort-kap',
            'message' => "Öğle servisi.\nİki vardiya.",
            'kvkk_accepted_at' => now(),
            'submitted_at' => now(),
            'status' => QuoteRequest::STATUS_NEW,
        ]);
        $quote->save();

        return $quote;
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
