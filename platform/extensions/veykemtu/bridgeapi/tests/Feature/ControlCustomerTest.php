<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Order;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Testing\TestResponse;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Models\ControlAudit;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Models\SubscriptionPayment;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Kontrol Merkezi — müşteriler (`docs/control/customers.md`).
 *
 * Bu dosya diğer kontrol testlerinin sorduğu üç soruyu (kapı duruyor mu,
 * kabuk aynı mı, rota adı metot adını tutuyor mu) **dördüncüsüyle**
 * genişletiyor: **okuma denetimi gerçekten açılıyor mu?**
 *
 * Dördüncü soru yalnız burada anlamlı. Sistemdeki tek "okuma denetim
 * satırı" biçimi bu ailededir (`00-genel.md` §9) ve eksikliği hiçbir yerde
 * hata üretmez: uç doğru veriyi döner, testler yeşil kalır, yalnız KVKK
 * sorusunun ("kim, ne zaman, kimin kaydını açtı") cevabı olmaz. Bu yüzden
 * beş okuma ucunun **hepsi** ayrı ayrı sınanıyor; birinin unutulması
 * sessiz bir açıktır.
 *
 * Rotalar `class_exists()` nöbetçisinin arkasında (`routes/api.php`):
 * denetleyici sınıfı yoksa grup HİÇ kaydedilmiyor ve uç `404` döner.
 * Yani bu dosyadaki her `assertOk()`, aynı zamanda "rota kaydoldu ve
 * metot adı tuttu" demektir.
 */
class ControlCustomerTest extends KitchenTestCase
{
    private const string SECRET = 'test-kontrol-merkezi-sirri';

    private const string ACTOR = 'Ayşe Yönetici';

    private const string REASON = 'Müşteri telefon numarasını değiştirdi';

    private const string BASE = '/api/control/customers';

    protected function setUp(): void
    {
        parent::setUp();

        putenv('BLD_CONTROL_SECRET='.self::SECRET);
        $_ENV['BLD_CONTROL_SECRET'] = self::SECRET;
    }

    // ── 1. Kapı ve rota kaydı ─────────────────────────────────────────────

    public function test_IMZASIZ_istek_401_doner(): void
    {
        $id = $this->customerId();

        foreach ([
            ['GET', self::BASE],
            ['GET', self::BASE.'/'.$id],
            ['PATCH', self::BASE.'/'.$id],
            ['GET', self::BASE.'/'.$id.'/orders'],
            ['GET', self::BASE.'/'.$id.'/subscriptions'],
            ['GET', self::BASE.'/'.$id.'/addresses'],
            ['POST', self::BASE.'/'.$id.'/disable'],
            ['POST', self::BASE.'/'.$id.'/enable'],
        ] as [$method, $path]) {
            $this->call($method, $path, [], [], [], ['HTTP_ACCEPT' => 'application/json'])
                ->assertStatus(401);
        }

        // İMZA DUVARI DENETİM İZİ AÇMAZ: istek denetleyiciye hiç ulaşmadı.
        $this->assertSame(0, ControlAudit::count());
    }

    /**
     * Sekiz rotanın hepsi kayıtlı mı?
     *
     * `php artisan route:list --path=control/customers` sekiz satır
     * göstermeli. Bunu elle koşmak yerine sınıyoruz: sayının düşmesi tek
     * bir metot adının ayrışmasıyla olur ve o ayrışma AÇILIŞTA DEĞİL,
     * yalnız uç çağrılınca patlar.
     */
    public function test_SEKIZ_ROTA_kayitli(): void
    {
        $paths = collect(Route::getRoutes()->getRoutes())
            ->filter(static fn($route): bool => str_starts_with($route->uri(), 'api/control/customers'))
            ->map(static fn($route): string => implode('|', $route->methods()).' '.$route->uri())
            ->values();

        $this->assertCount(8, $paths, 'Beklenen sekiz rota: '.$paths->implode(', '));
    }

    // ── 2. KVKK: `actor` zorunluluğu ve okuma denetimi ────────────────────

    public function test_AKTORSUZ_OKUMA_422_ve_denetim_satiri_yok(): void
    {
        $id = $this->customerId();

        foreach ([
            self::BASE,
            self::BASE.'/'.$id,
            self::BASE.'/'.$id.'/orders',
            self::BASE.'/'.$id.'/subscriptions',
            self::BASE.'/'.$id.'/addresses',
        ] as $path) {
            $this->signed('GET', $path)
                ->assertStatus(422)
                ->assertJsonPath('error.code', 'VALIDATION_FAILED')
                ->assertJsonPath('error.details.field', 'actor');
        }

        // GEÇERLİ BİR OKUMA HİÇ OLUŞMADI: kimliksiz erişim, izine de
        // yazılmayan bir erişim değil — hiç gerçekleşmeyen bir erişimdir.
        $this->assertSame(0, ControlAudit::count());
    }

    public function test_KISA_AKTOR_reddedilir(): void
    {
        $this->signed('GET', self::BASE.'?actor=A')
            ->assertStatus(422)
            ->assertJsonPath('error.details.field', 'actor');

        $this->assertSame(0, ControlAudit::count());
    }

    /**
     * BEŞ OKUMA UCUNUN HEPSİ bir `customer.read` satırı açar.
     *
     * Tek tek sınanıyor çünkü eksik kalan bir uç hiçbir yerde hata
     * vermez; yalnız denetim ekranında görünmez olur.
     */
    public function test_HER_OKUMA_UCU_DENETIM_SATIRI_ACAR(): void
    {
        $id = $this->customerId();

        $paths = [
            self::BASE,
            self::BASE.'/'.$id,
            self::BASE.'/'.$id.'/orders',
            self::BASE.'/'.$id.'/subscriptions',
            self::BASE.'/'.$id.'/addresses',
        ];

        foreach ($paths as $path) {
            $this->signed('GET', $path.'?actor='.rawurlencode(self::ACTOR))->assertOk();
        }

        $rows = ControlAudit::query()->orderBy('id')->get();

        $this->assertCount(count($paths), $rows);

        foreach ($rows as $index => $row) {
            $this->assertSame(ControlAudit::ACTION_CUSTOMER_READ, $row->action);
            $this->assertSame(ControlAudit::TARGET_CUSTOMER, $row->target_type);
            $this->assertSame(ControlAudit::RESULT_APPLIED, $row->result);
            $this->assertSame(self::ACTOR, $row->actor);
            $this->assertSame($paths[$index], $row->payload_json['path'] ?? null);
            $this->assertStringContainsString('Kişisel veri görüntüleme', (string) $row->reason);
        }

        // LİSTE UCUNDA HEDEF YOK, tekil uçlarda müşteri kimliği var.
        $this->assertNull($rows[0]->target_id);
        $this->assertSame($id, (int) $rows[1]->target_id);
    }

    public function test_OKUMA_YUKU_YALNIZ_SUZGECLERI_tasir(): void
    {
        $this->makeCustomer('acme@ornek.com', ['company_name' => 'Acme Gıda A.Ş.']);

        $this->signed('GET', self::BASE.'?actor='.rawurlencode(self::ACTOR).'&q=Acme&page=1')
            ->assertOk()
            ->assertJsonPath('data.0.org_name', 'Acme Gıda A.Ş.');

        $payload = ControlAudit::firstOrFail()->payload_json;

        // Anahtar sırası sınanmıyor: `payload_json` MySQL'in yerel JSON
        // tipi ve nesne anahtarlarını yeniden sıralıyor.
        $this->assertEqualsCanonicalizing(['q' => 'Acme', 'page' => 1], $payload['filters']);

        // SAYFA NUMARASI SAYI: denetim ekranı süzgeci olduğu gibi
        // gösteriyor, `"2"` ile `2` aynı erişimi iki farklı süzgeç gibi
        // okuturdu.
        $this->assertSame(1, $payload['filters']['page']);

        // `actor` SÜZGEÇ DEĞİL: kendi sütununda duruyor, yükte tekrarı
        // aynı veriyi iki kez yazmak olurdu.
        $this->assertArrayNotHasKey('actor', $payload['filters']);

        // DÖNEN KAYITLAR YAZILMAZ — iz, ikinci bir müşteri veritabanına
        // dönmemeli.
        $this->assertEqualsCanonicalizing(['path', 'filters'], array_keys($payload));
    }

    public function test_BULUNMAYAN_MUSTERI_404_ve_denetim_satiri_yok(): void
    {
        $this->signed('GET', self::BASE.'/999999?actor='.rawurlencode(self::ACTOR))
            ->assertStatus(404)
            ->assertJsonPath('error.code', 'NOT_FOUND');

        // Olmayan bir kimliğe atılan istek hiçbir kişisel veri göstermedi;
        // satır açsaydık iz, taranabilir bir gürültüyle dolardı.
        $this->assertSame(0, ControlAudit::count());
    }

    // ── 3. Yazma kabuğu ───────────────────────────────────────────────────

    public function test_GEREKCESIZ_YAZMA_422_VE_DENETIM_SATIRI_YOK(): void
    {
        $id = $this->customerId();

        $this->signed('PATCH', self::BASE.'/'.$id, [
            'actor' => self::ACTOR,
            'telephone' => '5329876543',
        ])->assertStatus(422)->assertJsonPath('error.code', 'VALIDATION_FAILED');

        $this->assertSame(0, ControlAudit::count());
        $this->assertSame('5551234567', ApiCustomer::findOrFail($id)->telephone);
    }

    public function test_AKTORSUZ_YAZMA_reddedilir(): void
    {
        $id = $this->customerId();

        $this->signed('POST', self::BASE.'/'.$id.'/disable', ['reason' => self::REASON])
            ->assertStatus(422);

        $this->assertSame(0, ControlAudit::count());
        $this->assertTrue((bool) ApiCustomer::findOrFail($id)->status);
    }

    public function test_KURU_PROVA_YAZMAZ_ama_denetim_birakir(): void
    {
        $id = $this->customerId();

        $this->signed('PATCH', self::BASE.'/'.$id, $this->intent([
            'telephone' => '5329876543',
            'dry_run' => true,
        ]))->assertOk()
            ->assertJsonPath('dry_run', true)
            ->assertJsonPath('would.action', 'customer.update')
            ->assertJsonPath('would.changed', ['telephone']);

        $this->assertSame('5551234567', ApiCustomer::findOrFail($id)->telephone);

        $audit = ControlAudit::firstOrFail();
        $this->assertSame(ControlAudit::RESULT_DRY_RUN, $audit->result);
        $this->assertSame('customer.update', $audit->action);
    }

    // ── 4. `update` — parola ve e-posta ───────────────────────────────────

    /**
     * Parola ve e-posta ASLA yazılmaz.
     *
     * Sözleşme bunları sessizce yok saymak yerine isteği TÜMÜYLE
     * reddediyor (`customers.md` → `PATCH /{id}`) ve gerekçesi somut:
     * e-posta değiştirdiğini sanan bir yöneticiye "başarılı" demek, yok
     * saymanın en pahalı hâli olurdu. Sınanan şey her iki okumada da
     * aynı: alanlar veritabanına YAZILMIYOR.
     */
    public function test_UPDATE_PAROLA_VE_EPOSTAYI_YAZMAZ(): void
    {
        $id = $this->customerId();
        $before = ApiCustomer::findOrFail($id);
        $hash = (string) $before->password;

        foreach ([
            ['email' => 'yeni@ornek.com'],
            ['password' => 'yeni-parola-123'],
            ['status' => false],
            ['account_type' => 'individual'],
        ] as $body) {
            $this->signed('PATCH', self::BASE.'/'.$id, $this->intent($body))
                ->assertStatus(422)
                ->assertJsonPath('error.code', 'VALIDATION_FAILED')
                ->assertJsonPath('error.details.field', array_key_first($body))
                ->assertJsonPath('error.details.reason', 'read_only');
        }

        $after = ApiCustomer::findOrFail($id);

        $this->assertSame('test@ornek.com', $after->email);
        $this->assertSame($hash, (string) $after->password);
        $this->assertTrue((bool) $after->status);
        $this->assertSame('corporate', $after->bld_account_type);

        // Reddedilen istek denetim satırı da açmaz: doğrulama kabuğun
        // ÖNÜNDE koşuyor.
        $this->assertSame(0, ControlAudit::count());
    }

    // ── 5. `update` — mutlu yol ve doğrulama ──────────────────────────────

    public function test_UPDATE_iletisim_ve_kurum_alanlarini_yazar(): void
    {
        $id = $this->customerId();

        $this->signed('PATCH', self::BASE.'/'.$id, $this->intent([
            'telephone' => '532 987 65 43',
            'org_name' => 'Acme Gıda ve Turizm A.Ş.',
            'tax_office' => 'Çankaya',
            'tax_no' => '1234567890',
            'contact_person' => 'Zeynep Demir',
            'org_phone' => '(312) 444-5566',
        ]))->assertOk()
            ->assertJsonPath('ok', true)
            ->assertJsonPath('data.telephone', '5329876543')
            ->assertJsonPath('data.org_name', 'Acme Gıda ve Turizm A.Ş.')
            ->assertJsonPath('data.email', 'test@ornek.com');

        $row = ApiCustomer::findOrFail($id);

        // BİÇİM DEĞİL RAKAM YAZILIYOR: müşteri uygulaması da numarayı
        // çıplak on hane olarak yazıyor; iki yol iki biçim yazsaydı
        // listedeki telefon araması aynı numarayı bulamazdı.
        $this->assertSame('5329876543', $row->telephone);
        $this->assertSame('3124445566', $row->bld_org_phone);
        $this->assertSame('1234567890', $row->bld_tax_no);
        $this->assertSame('Zeynep Demir', $row->bld_contact_person);
    }

    public function test_UPDATE_denetim_yukunde_TELEFONLAR_MASKELI(): void
    {
        $id = $this->customerId();

        $this->signed('PATCH', self::BASE.'/'.$id, $this->intent([
            'telephone' => '5329876543',
            'org_name' => 'Acme Gıda A.Ş.',
        ]))->assertOk()->assertJsonPath('changed', ['telephone', 'org_name']);

        $changes = ControlAudit::firstOrFail()->payload_json['changes'];

        /*
         * ANAHTAR SIRASINA GÜVENİLMEZ. `payload_json` MySQL'in yerel JSON
         * tipi ve nesne anahtarlarını normalleştiriyor (önce uzunluğa,
         * sonra alfabeye göre) — `assertSame` ile tam dizi karşılaştırmak,
         * kodda hiçbir şey değişmeden kırılan bir test olurdu.
         */
        $this->assertSame('telephone', $changes[0]['field']);
        $this->assertSame('555****567', $changes[0]['from']);
        $this->assertSame('532****543', $changes[0]['to']);

        // KURUM ADI MASKELENMEZ: kişisel veri değil, ticari unvan — ve
        // maskelenirse "ne değişti" sorusu cevapsız kalırdı.
        $this->assertSame('org_name', $changes[1]['field']);
        $this->assertNull($changes[1]['from']);
        $this->assertSame('Acme Gıda A.Ş.', $changes[1]['to']);
    }

    public function test_UPDATE_degismeyen_alani_degisti_saymaz(): void
    {
        $id = $this->customerId();

        $this->signed('PATCH', self::BASE.'/'.$id, $this->intent([
            'telephone' => '5551234567',
        ]))->assertOk()->assertJsonPath('changed', []);

        $this->assertSame([], ControlAudit::firstOrFail()->payload_json['changes']);
    }

    public function test_UPDATE_dogrulamalari(): void
    {
        $id = $this->customerId();

        foreach ([
            [['first_name' => ''], 'first_name'],
            [['last_name' => '  '], 'last_name'],
            [['tax_no' => '123456789'], 'tax_no'],
            [['tax_no' => '123456789012'], 'tax_no'],
            [['telephone' => '532123'], 'telephone'],
            [['telephone' => '532abc4567'], 'telephone'],
            [['org_name' => str_repeat('a', 161)], 'org_name'],
        ] as [$body, $field]) {
            $this->signed('PATCH', self::BASE.'/'.$id, $this->intent($body))
                ->assertStatus(422)
                ->assertJsonPath('error.details.field', $field);
        }

        $this->assertSame(0, ControlAudit::count());
    }

    public function test_UPDATE_bos_dize_alani_temizler(): void
    {
        $id = $this->customerId();

        $this->signed('PATCH', self::BASE.'/'.$id, $this->intent([
            'telephone' => '',
            'org_name' => '',
        ]))->assertOk()->assertJsonPath('data.telephone', null);

        $this->assertNull(ApiCustomer::findOrFail($id)->telephone);
    }

    // ── 6. `disable` / `enable` ───────────────────────────────────────────

    /**
     * Kapatılan müşteri LİSTEDE KALIR — silme yok.
     *
     * Silinseydi geçmiş siparişler müşterisi olmayan kayıtlara dönerdi;
     * muhasebe ve denetim açısından geri alınamaz bir kayıp.
     */
    public function test_DISABLE_EDILEN_MUSTERI_LISTEDE_KALIR_durumu_degisir(): void
    {
        $id = $this->customerId();

        $this->signed('POST', self::BASE.'/'.$id.'/disable', $this->intent())
            ->assertOk()
            ->assertJsonPath('data.status', false);

        $this->assertFalse((bool) ApiCustomer::findOrFail($id)->status);

        $row = $this->firstRow(self::BASE.'?actor='.rawurlencode(self::ACTOR));
        $this->assertSame($id, $row['customer_id']);
        $this->assertFalse($row['status']);

        // Süzgeçler de durumu görüyor.
        $this->signed('GET', self::BASE.'?actor='.rawurlencode(self::ACTOR).'&status=disabled')
            ->assertOk()->assertJsonPath('meta.total', 1);

        $this->signed('GET', self::BASE.'?actor='.rawurlencode(self::ACTOR).'&status=active')
            ->assertOk()->assertJsonPath('meta.total', 0);

        $this->signed('POST', self::BASE.'/'.$id.'/enable', $this->intent())
            ->assertOk()
            ->assertJsonPath('data.status', true);

        $this->assertTrue((bool) ApiCustomer::findOrFail($id)->status);
    }

    public function test_ZATEN_KAPALI_HESAP_409_VERMEZ(): void
    {
        $id = $this->customerId();

        $this->signed('POST', self::BASE.'/'.$id.'/disable', $this->intent())->assertOk();
        $this->signed('POST', self::BASE.'/'.$id.'/disable', $this->intent())
            ->assertOk()
            ->assertJsonPath('ok', true);

        // İki eylem, iki iz: ikincisi bir şeyi değiştirmese de yapılmış
        // bir eylemdir.
        $this->assertSame(2, ControlAudit::where('action', 'customer.disable')->count());
    }

    public function test_AKTIF_ABONELIK_UYARI_URETIR_ama_engellemez(): void
    {
        $id = $this->customerId();
        $subscription = $this->makeSubscription($id);

        $this->signed('POST', self::BASE.'/'.$id.'/disable', $this->intent())
            ->assertOk()
            ->assertJsonPath('warnings.0.code', 'active_subscriptions')
            ->assertJsonPath('warnings.0.subscription_ids', [(int) $subscription->id]);

        // Uyarı engel değil: hesap gerçekten kapandı.
        $this->assertFalse((bool) ApiCustomer::findOrFail($id)->status);
    }

    public function test_AKTIF_ABONELIK_YOKSA_UYARI_ALANI_HIC_YOK(): void
    {
        $id = $this->customerId();

        $body = $this->signed('POST', self::BASE.'/'.$id.'/disable', $this->intent())
            ->assertOk()
            ->json();

        $this->assertArrayNotHasKey('warnings', $body);
    }

    // ── 7. Arama ve sayfalama ─────────────────────────────────────────────

    public function test_ARAMA_ad_telefon_eposta_ve_kurumda_calisir(): void
    {
        $this->customerId();
        $acme = $this->makeCustomer('mehmet.kaya@acme.com.tr', [
            'first_name' => 'Mehmet',
            'last_name' => 'Kaya',
            'telephone' => '5321234567',
            'company_name' => 'Acme Gıda A.Ş.',
        ]);

        foreach (['Acme', 'Mehmet', 'Kaya', '5321234567', 'acme.com.tr'] as $term) {
            $this->assertSame(
                $acme,
                $this->firstRow(self::BASE.'?actor='.rawurlencode(self::ACTOR).'&q='.rawurlencode($term))['customer_id'],
                'Arama terimi eşleşmedi: '.$term,
            );
        }
    }

    public function test_TEK_HARFLIK_ARAMA_reddedilir(): void
    {
        $this->signed('GET', self::BASE.'?actor='.rawurlencode(self::ACTOR).'&q=a')
            ->assertStatus(422)
            ->assertJsonPath('error.details.field', 'q');

        $this->assertSame(0, ControlAudit::count());
    }

    /**
     * Sayfalama GERÇEKTEN sayfalıyor mu?
     *
     * Parametre adı **`per_page`** — `limit` değil. Kardeş bir projede
     * `per_page` sanılan alan aslında `limit`ti ve tarama sessizce
     * kırpılmıştı; bu test ikisini birden sınıyor.
     */
    public function test_SAYFALAMA_gercekten_sayfalar(): void
    {
        $this->customerId();

        foreach (['bir', 'iki', 'uc', 'dort'] as $index => $slug) {
            $this->makeCustomer($slug.'@ornek.com', [
                'first_name' => 'Sayfa'.$index,
                'telephone' => '53200000'.(10 + $index),
            ]);
        }

        $first = $this->signed('GET', self::BASE.'?actor='.rawurlencode(self::ACTOR).'&per_page=2&page=1')
            ->assertOk()
            ->assertJsonPath('meta.page', 1)
            ->assertJsonPath('meta.per_page', 2)
            ->assertJsonPath('meta.total', 5)
            ->assertJsonPath('meta.last_page', 3)
            ->assertJsonCount(2, 'data')
            ->json('data');

        $second = $this->signed('GET', self::BASE.'?actor='.rawurlencode(self::ACTOR).'&per_page=2&page=2')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->json('data');

        $this->assertSame(
            [],
            array_intersect(array_column($first, 'customer_id'), array_column($second, 'customer_id')),
            'İki sayfa aynı müşteriyi göstermemeli.',
        );

        // `limit` SÖZLEŞMEDE YOK ve tanınmamalı: tanınsaydı `per_page`
        // gönderen panel sessizce kırpılmış listeler görürdü.
        $this->signed('GET', self::BASE.'?actor='.rawurlencode(self::ACTOR).'&limit=1')
            ->assertOk()
            ->assertJsonCount(5, 'data');
    }

    public function test_PER_PAGE_TAVANI_100(): void
    {
        $this->customerId();

        $this->signed('GET', self::BASE.'?actor='.rawurlencode(self::ACTOR).'&per_page=5000')
            ->assertOk()
            ->assertJsonPath('meta.per_page', 100);
    }

    public function test_HAS_SUBSCRIPTION_suzgeci(): void
    {
        $withSubscription = $this->customerId();
        $this->makeSubscription($withSubscription);
        $this->makeCustomer('abonesiz@ornek.com', ['first_name' => 'Abonesiz']);

        $this->assertSame(
            $withSubscription,
            $this->firstRow(self::BASE.'?actor='.rawurlencode(self::ACTOR).'&has_subscription=true')['customer_id'],
        );

        $this->signed('GET', self::BASE.'?actor='.rawurlencode(self::ACTOR).'&has_subscription=false')
            ->assertOk()
            ->assertJsonPath('meta.total', 1)
            ->assertJsonPath('data.0.first_name', 'Abonesiz');
    }

    /**
     * Dizi biçimli sorgu parametresi 422 verir, 500 DEĞİL.
     *
     * `?actor[]=x` bir metin dönüşümünde PHP uyarısı üretip sunucu
     * hatasına düşerdi; KVKK kapısının biçimsizliği "beklenmeyen hata"
     * gibi görünmemeli — panel o farka bakarak isteği düzeltiyor.
     */
    public function test_DIZI_SORGU_PARAMETRESI_422_verir(): void
    {
        $this->signed('GET', self::BASE.'?actor[]=Ayse')
            ->assertStatus(422)
            ->assertJsonPath('error.details.field', 'actor');

        $this->signed('GET', self::BASE.'?actor='.rawurlencode(self::ACTOR).'&status[]=active')
            ->assertStatus(422)
            ->assertJsonPath('error.details.field', 'status');

        $this->assertSame(0, ControlAudit::count());
    }

    public function test_GECERSIZ_SIRALAMA_reddedilir(): void
    {
        $this->signed('GET', self::BASE.'?actor='.rawurlencode(self::ACTOR).'&sort=telefon')
            ->assertStatus(422)
            ->assertJsonPath('error.details.field', 'sort');
    }

    // ── 8. Detay, sipariş, abonelik, adres ────────────────────────────────

    public function test_SHOW_sema_ve_istatistikleri_doner(): void
    {
        $id = $this->customerId();
        $order = $this->confirmedOrder();
        $this->makeAddress();
        $subscription = $this->makeSubscription($id);
        $this->makePendingPayment($subscription, 640000);

        $data = $this->signed('GET', self::BASE.'/'.$id.'?actor='.rawurlencode(self::ACTOR))
            ->assertOk()
            ->assertJsonPath('data.customer_id', $id)
            ->assertJsonPath('data.email', 'test@ornek.com')
            ->assertJsonPath('data.account_type', 'corporate')
            ->json('data');

        // Parola HİÇBİR BİÇİMDE geçmez.
        $this->assertArrayNotHasKey('password', $data);

        $this->assertSame(1, $data['stats']['order_count']);
        $this->assertSame(0, $data['stats']['cancelled_order_count']);
        $this->assertSame(1, $data['stats']['active_subscription_count']);
        $this->assertSame(640000, $data['stats']['unpaid_total_kurus']);
        $this->assertSame(1, $data['stats']['address_count']);
        $this->assertNotNull($data['stats']['last_order_at']);
        $this->assertGreaterThan(0, $data['stats']['total_spent_kurus']);
        $this->assertSame(
            (int) round(((float) $order->order_total) * 100),
            $data['stats']['total_spent_kurus'],
        );
    }

    public function test_ORDERS_ucu_musterinin_siparislerini_doner(): void
    {
        $id = $this->customerId();
        $order = $this->confirmedOrder();

        $this->signed('GET', self::BASE.'/'.$id.'/orders?actor='.rawurlencode(self::ACTOR))
            ->assertOk()
            ->assertJsonPath('meta.total', 1)
            ->assertJsonPath('data.0.id', (int) $order->order_id)
            ->assertJsonPath('data.0.customer_id', $id)
            // SATIR BİÇİMİ `orders.md` ile aynı — ayrı bir üretici yok.
            ->assertJsonStructure([
                'data' => [['id', 'order_number', 'status', 'service_date', 'total_kurus']],
                'meta' => ['page', 'per_page', 'total', 'last_page'],
                'server_time',
            ]);
    }

    /**
     * Sipariş geçmişi VARSAYILAN PENCEREYE takılmamalı.
     *
     * Kardeş uç süzgeçsiz istekte son yedi güne düşüyor; müşteri kartında
     * soru "bu müşteri bize ne zaman ne sipariş etti" olduğu için pencere
     * müşterinin kendi geçmişine genişletiliyor.
     */
    public function test_ORDERS_ESKI_SIPARISI_de_doner(): void
    {
        $id = $this->customerId();
        $order = $this->confirmedOrder();

        $old = BusinessTime::now()->subDays(40)->toDateString();
        DB::table('orders')->where('order_id', $order->order_id)->update([
            'bld_service_date' => $old,
            'order_date' => $old,
        ]);

        $this->signed('GET', self::BASE.'/'.$id.'/orders?actor='.rawurlencode(self::ACTOR))
            ->assertOk()
            ->assertJsonPath('meta.total', 1)
            ->assertJsonPath('data.0.service_date', $old);
    }

    public function test_SUBSCRIPTIONS_ucu_META_DONDURMEZ(): void
    {
        $id = $this->customerId();
        $subscription = $this->makeSubscription($id);

        $body = $this->signed('GET', self::BASE.'/'.$id.'/subscriptions?actor='.rawurlencode(self::ACTOR))
            ->assertOk()
            ->assertJsonPath('data.0.id', (int) $subscription->id)
            ->assertJsonPath('data.0.customer_id', $id)
            ->json();

        // Sayfalanmayan uç `meta` yollamaz: boş bir sayfalayıcı çizdirirdi.
        $this->assertArrayNotHasKey('meta', $body);
        $this->assertArrayHasKey('server_time', $body);
    }

    public function test_ADRESLER_yalnizca_defter_satirlarini_doner(): void
    {
        $id = $this->customerId();
        $addressId = $this->makeAddress();

        // Sipariş, adresin İKİNCİ bir kopyasını (`bld_is_saved = false`)
        // yazıyor; defter ucu onu göstermemeli.
        $this->confirmedOrder();

        $snapshots = DB::table('addresses')
            ->where('customer_id', $id)
            ->where('bld_is_saved', false)
            ->count();

        $this->assertGreaterThan(0, $snapshots, 'Sipariş adres anlık görüntüsü yazmalıydı.');

        $this->signed('GET', self::BASE.'/'.$id.'/addresses?actor='.rawurlencode(self::ACTOR))
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.address_id', $addressId)
            ->assertJsonPath('data.0.label', 'Merkez ofis')
            ->assertJsonPath('data.0.district', 'Selçuklu')
            ->assertJsonPath('data.0.is_default', true)
            ->assertJsonStructure([
                'data' => [[
                    'address_id', 'label', 'line_1', 'line_2', 'city', 'district',
                    'neighbourhood', 'postcode', 'latitude', 'longitude', 'is_default',
                ]],
                'server_time',
            ]);
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    /**
     * İmzalı kontrol isteği — `ControlAreasTest` deseni.
     *
     * @param  array<string, mixed>|string|null  $body
     */
    private function signed(
        string $method,
        string $path,
        array|string|null $body = null,
        ?string $nonce = null,
        ?int $timestamp = null,
    ): TestResponse {
        $raw = is_array($body) ? (string) json_encode($body, JSON_UNESCAPED_UNICODE) : (string) ($body ?? '');
        $timestamp ??= time();
        $nonce ??= bin2hex(random_bytes(12));

        $canonical = implode("\n", [
            strtoupper($method),
            // Sorgu dizesi imzaya GİRMEZ — `actor` bu yüzden kriptografik
            // olarak bağlanmıyor (`00-genel.md` §9).
            (string) parse_url($path, PHP_URL_PATH),
            (string) $timestamp,
            $nonce,
            hash('sha256', $raw),
        ]);

        return $this->call($method, $path, [], [], [], [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_X_CONTROL_TIMESTAMP' => (string) $timestamp,
            'HTTP_X_CONTROL_NONCE' => $nonce,
            'HTTP_X_CONTROL_SIGNATURE' => 'sha256='.hash_hmac('sha256', $canonical, self::SECRET),
        ], $raw);
    }

    /**
     * @param  array<string, mixed>  $extra
     * @return array<string, mixed>
     */
    private function intent(array $extra = []): array
    {
        return ['actor' => self::ACTOR, 'reason' => self::REASON, ...$extra];
    }

    /** @return array<string, mixed> */
    private function firstRow(string $path): array
    {
        /** @var array<string, mixed> $row */
        $row = $this->signed('GET', $path)->assertOk()->json('data.0');

        return $row;
    }

    private function customerId(): int
    {
        $this->asCustomer();

        return (int) ApiCustomer::query()->where('email', 'test@ornek.com')->value('customer_id');
    }

    /**
     * Kayıt ucundan ikinci bir müşteri — model elle kurulmuyor.
     *
     * `customer_group_id` ve KVKK damgası gibi alanları elle yazmak,
     * kayıt akışı değiştiğinde sessizce eskiyen bir kopya olurdu.
     *
     * @param  array<string, mixed>  $overrides
     */
    private function makeCustomer(string $email, array $overrides = []): int
    {
        $payload = $this->registerPayload([
            'email' => $email,
            'telephone' => '5'.substr((string) (300000000 + crc32($email) % 99999999), 0, 9),
            ...$overrides,
        ]);

        $this->postJson('/api/auth/register', $payload, self::HEADERS)->assertStatus(201);

        return (int) ApiCustomer::query()->where('email', $email)->value('customer_id');
    }

    /**
     * Adres DEFTERİ satırı (`bld_is_saved = true`).
     *
     * Sipariş ucu adresi KOPYALIYOR, deftere yazmıyor — aynı tabloya
     * `bld_is_saved = false` ile bir anlık görüntü düşüyor. Defter satırı
     * yalnız bu uçtan doğar ve testin ayırt etmesi gereken fark budur.
     */
    private function makeAddress(): int
    {
        return (int) $this->asCustomer()->postJson('/api/addresses', [
            'label' => 'Merkez ofis',
            'line1' => 'Kızılırmak Mah. 1443. Cad. No:12',
            'district' => 'Selçuklu',
            'city' => 'Konya',
        ], self::HEADERS)->assertCreated()->json('id');
    }

    /**
     * Aktif abonelik — kontrol ucundan GEÇMEDEN.
     *
     * `POST /api/control/subscriptions` kendi denetim satırını yazardı ve
     * bu dosyadaki iz sayımlarını bulanıklaştırırdı; sınanan şey abonelik
     * oluşturma değil.
     */
    private function makeSubscription(
        int $customerId,
        string $status = Subscription::STATUS_ACTIVE,
    ): Subscription {
        $model = new Subscription;
        $model->customer_id = $customerId;
        $model->location_id = $this->locationId();
        $model->status = $status;
        $model->start_date = BusinessTime::now()->toDateString();
        $model->end_date = null;
        $model->delivery_type = 'delivery';
        $model->service_days = [1, 2, 3, 4, 5];
        $model->menu_mode = Subscription::MENU_FIXED_LIST;
        $model->default_quantity = 10;
        $model->agreed_unit_price_kurus = 16000;
        $model->payment_mode = Subscription::PAYMENT_PREPAID;
        $model->save();

        return $model;
    }

    private function makePendingPayment(Subscription $subscription, int $kurus): SubscriptionPayment
    {
        $payment = new SubscriptionPayment;
        $payment->subscription_id = $subscription->id;
        $payment->period_start = BusinessTime::now()->toDateString();
        $payment->period_end = BusinessTime::now()->addDays(29)->toDateString();
        $payment->amount_kurus = $kurus;
        $payment->status = SubscriptionPayment::STATUS_PENDING;
        $payment->save();

        return $payment;
    }

    private function confirmedOrder(int $quantity = 2): Order
    {
        $created = $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => $quantity]],
            'delivery_type' => 'delivery',
            'payment_method' => 'cash',
            'address' => [
                'line1' => 'Örnek Mah. 12. Sk No:3',
                'district' => 'Selçuklu',
                'city' => 'Konya',
            ],
        ], self::HEADERS)->assertCreated()->json();

        $this->advance((int) $created['id'], [OrderStatusTransition::CONFIRMED]);

        return Order::findOrFail((int) $created['id']);
    }
}
