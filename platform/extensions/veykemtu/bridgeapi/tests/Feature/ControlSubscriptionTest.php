<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Menu;
use Igniter\Cart\Models\Order;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Models\ClosedDay;
use Veykemtu\BridgeApi\Models\ControlAudit;
use Veykemtu\BridgeApi\Models\QuoteRequest;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Models\SubscriptionContract;
use Veykemtu\BridgeApi\Models\SubscriptionException;
use Veykemtu\BridgeApi\Models\SubscriptionPause;
use Veykemtu\BridgeApi\Services\DailyStock;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Kontrol Merkezi — abonelik, talep, sözleşme, ödeme
 * (`/api/control/subscriptions/*`).
 *
 * Sözleşme: `docs/control/subscriptions.md`. Beklentiler o dosyadan gelir,
 * koddan değil: kod sözleşmeden saparsa test kırılmalıdır, tersi değil.
 *
 * Bu paketin koruduğu üç şey:
 *
 * 1. **Abonelik `pending` doğar ve imzasız aktifleşmez.** Kural fiyatsız ya
 *    da sözleşmesiz üretime girerse, tutarı sıfır siparişler mutfağa düşer
 *    ve bunu gören ilk yer fatura değil tabak olur.
 * 2. **Üretilmiş sipariş dokunulmazdır.** Kural değişikliği, duraklatma ve
 *    iptal onu değiştirmez; uçlar bunu `warnings` ile söylemek zorunda,
 *    çünkü sessiz kalan bir yanıt yöneticiye yapmadığı bir değişikliği
 *    yaptığını düşündürür.
 * 3. **İdempotency veritabanı kısıtından gelir.** `generate` ikinci kez
 *    çağrıldığında 500 değil `409` dönmeli; ikisi arasındaki fark, panelin
 *    "tazele ve tekrar sor" diyebilmesidir.
 *
 * ## İKİ SÖZLÜK
 *
 * Sözleşme ve ödeme kayıtları müşteri yüzünün sözlüğünü saklıyor
 * (`draft|sent|approved`, `pending|succeeded|failed`), panel başka bir
 * sözlük bekliyor (`pending|sent|signed`, `pending|paid|void`). Buradaki
 * beklentiler PANELİN sözlüğünü sabitliyor: çeviri tek noktada kalmazsa
 * aynı kayıt iki ekranda farklı durumda görünür.
 *
 * Kapı (imza, nonce, zaman penceresi) `ControlKdsTest`'te ayrıntılı
 * sınanıyor; burada yalnız bu rota ailesinin de aynı kapıdan geçtiği
 * doğrulanıyor.
 */
class ControlSubscriptionTest extends KitchenTestCase
{
    private const string SECRET = 'test-kontrol-merkezi-sirri';

    private const string ACTOR = 'Ayşe Yönetici';

    private const string REASON = 'Abonelik düzenlemesi için yapıldı';

    private const string BASE = '/api/control/subscriptions';

    protected function setUp(): void
    {
        parent::setUp();

        putenv('BLD_CONTROL_SECRET='.self::SECRET);
        $_ENV['BLD_CONTROL_SECRET'] = self::SECRET;
    }

    // ── Kapı ──────────────────────────────────────────────────────────────

    public function test_IMZASIZ_istek_reddedilir(): void
    {
        $this->getJson(self::BASE, ['Accept' => 'application/json'])
            ->assertStatus(401)
            ->assertJsonPath('error.code', 'UNAUTHENTICATED');
    }

    // ── Oluşturma ─────────────────────────────────────────────────────────

    public function test_yeni_abonelik_pending_dogar(): void
    {
        $body = $this->signed('POST', self::BASE, $this->newPayload())
            ->assertStatus(201)
            ->json();

        $this->assertTrue($body['ok']);
        $this->assertFalse($body['dry_run']);
        $this->assertSame(Subscription::STATUS_PENDING, $body['data']['status']);
        $this->assertSame(Subscription::PAYMENT_PREPAID, $body['data']['payment_mode']);
        $this->assertSame([1, 2, 3, 4, 5], $body['data']['service_days']);
        $this->assertSame(16000, $body['data']['agreed_unit_price_kurus']);
        $this->assertCount(1, $body['data']['delivery_points']);
        $this->assertNull($body['data']['contract'], 'Yeni abonelikte sözleşme olmamalı.');

        $audit = ControlAudit::query()->where('action', 'subscription.create')->latest('id')->first();
        $this->assertNotNull($audit, 'Yazma denetim satırı bırakmadı.');
        $this->assertSame(ControlAudit::RESULT_APPLIED, $audit->result);
        $this->assertSame(ControlAudit::TARGET_SUBSCRIPTION, $audit->target_type);
    }

    /**
     * Kuru provanın ASIL FAYDASI `first_service_dates`: yönetici kuralın
     * gerçekten hangi günleri ürettiğini kaydetmeden görür.
     */
    public function test_kuru_prova_kayit_yazmaz_ama_ilk_gunleri_hesaplar(): void
    {
        $before = Subscription::query()->count();

        $body = $this->signed('POST', self::BASE, $this->newPayload(['dry_run' => true]))
            ->assertOk()
            ->json();

        $this->assertTrue($body['dry_run']);
        $this->assertArrayNotHasKey('data', $body, 'Kuru provada `data` dönmemeli.');
        $this->assertCount(3, $body['would']['first_service_dates']);
        $this->assertGreaterThan(0, $body['would']['monthly_estimate_kurus']);
        $this->assertSame($before, Subscription::query()->count(), 'Kuru prova kayıt yazdı.');

        $audit = ControlAudit::query()->where('action', 'subscription.create')->latest('id')->first();
        $this->assertSame(ControlAudit::RESULT_DRY_RUN, $audit->result);
    }

    public function test_gunun_menusu_modunda_kalem_gonderilemez(): void
    {
        $this->signed('POST', self::BASE, $this->newPayload([
            'menu_mode' => Subscription::MENU_DAILY,
            'lines' => [['menu_id' => $this->anyMenuId(), 'quantity' => 1]],
        ]))->assertStatus(422)->assertJsonPath('error.details.field', 'lines');
    }

    public function test_sabit_liste_modunda_kalem_zorunlu(): void
    {
        $this->signed('POST', self::BASE, $this->newPayload([
            'menu_mode' => Subscription::MENU_FIXED_LIST,
            'lines' => [],
        ]))->assertStatus(422)->assertJsonPath('error.details.field', 'lines');
    }

    public function test_teslimatli_abonelikte_nokta_zorunlu(): void
    {
        $this->signed('POST', self::BASE, $this->newPayload(['delivery_points' => []]))
            ->assertStatus(422)
            ->assertJsonPath('error.details.field', 'delivery_points');
    }

    /** Başkasının adres defterindeki kayıt seçilemez. */
    public function test_musteriye_ait_olmayan_adres_reddedilir(): void
    {
        $this->signed('POST', self::BASE, $this->newPayload([
            'delivery_points' => [['address_id' => 999999, 'quantity' => 20]],
        ]))
            ->assertStatus(422)
            ->assertJsonPath('error.details.field', 'delivery_points.0.address_id');
    }

    /**
     * Cari hesap kalktı (iş kararı 1): `account` artık bir ödeme yöntemi
     * değil. Sabit ve kolon duruyor, değişen yalnız kabul edilen küme.
     */
    public function test_cari_hesap_odeme_modu_reddedilir(): void
    {
        $this->signed('POST', self::BASE, $this->newPayload(['payment_mode' => 'account']))
            ->assertStatus(422)
            ->assertJsonPath('error.details.field', 'payment_mode')
            ->assertJsonPath('error.details.allowed', [Subscription::PAYMENT_PREPAID]);
    }

    public function test_gerekcesiz_yazma_reddedilir_ve_denetim_satiri_yazilmaz(): void
    {
        $before = ControlAudit::query()->count();

        $payload = $this->newPayload();
        unset($payload['reason']);

        $this->signed('POST', self::BASE, $payload)->assertStatus(422);

        $this->assertSame(
            $before,
            ControlAudit::query()->count(),
            'Geçersiz istek hiç oluşmadı; denetim satırı da olmamalı.',
        );
    }

    // ── Liste ve detay ────────────────────────────────────────────────────

    public function test_liste_sayfali_ve_durum_suzgecli(): void
    {
        $this->makeSubscription();
        $cancelled = $this->makeSubscription();
        $cancelled->status = Subscription::STATUS_CANCELLED;
        $cancelled->save();

        $body = $this->signed('GET', self::BASE.'?per_page=1&page=1')->assertOk()->json();

        $this->assertCount(1, $body['data']);
        $this->assertSame(2, $body['meta']['total']);
        $this->assertSame(2, $body['meta']['last_page']);
        $this->assertArrayHasKey('unpaid_periods', $body['data'][0]);
        $this->assertArrayHasKey('contract_status', $body['data'][0]);
        $this->assertSame('none', $body['data'][0]['contract_status']);

        $filtered = $this->signed('GET', self::BASE.'?status=cancelled')->assertOk()->json();
        $this->assertCount(1, $filtered['data']);
        $this->assertSame((int) $cancelled->id, $filtered['data'][0]['id']);
    }

    public function test_bilinmeyen_durum_suzgeci_reddedilir(): void
    {
        $this->signed('GET', self::BASE.'?status=uyduruk')
            ->assertStatus(422)
            ->assertJsonPath('error.details.field', 'status');
    }

    public function test_detay_alt_kayitlari_dondurur(): void
    {
        $model = $this->makeSubscription();

        $body = $this->signed('GET', self::BASE.'/'.$model->id)->assertOk()->json('data');

        $this->assertSame((int) $model->id, $body['id']);
        $this->assertCount(1, $body['delivery_points']);
        $this->assertSame([], $body['pauses']);
        $this->assertSame([], $body['exceptions']);
        $this->assertArrayHasKey('customer_label', $body);
    }

    public function test_olmayan_abonelik_404(): void
    {
        $this->signed('GET', self::BASE.'/999999')
            ->assertStatus(404)
            ->assertJsonPath('error.code', 'NOT_FOUND');
    }

    // ── Güncelleme ────────────────────────────────────────────────────────

    public function test_musteri_degistirilemez(): void
    {
        $model = $this->makeSubscription();

        $this->signed('PATCH', self::BASE.'/'.$model->id, $this->intent(['customer_id' => 5]))
            ->assertStatus(422)
            ->assertJsonPath('error.details.field', 'customer_id');
    }

    public function test_iptal_edilmis_abonelik_guncellenemez(): void
    {
        $model = $this->makeSubscription();
        $model->status = Subscription::STATUS_CANCELLED;
        $model->save();

        $this->signed('PATCH', self::BASE.'/'.$model->id, $this->intent(['default_quantity' => 30]))
            ->assertStatus(409)
            ->assertJsonPath('error.code', 'CONFLICT')
            ->assertJsonPath('error.details.conflict', 'cancelled');
    }

    /**
     * Kural değişikliği ÜRETİLMİŞ SİPARİŞİ ETKİLEMEZ ve yanıt bunu söyler.
     * Sessiz kalsaydı yönetici yarının adedini değiştirdiğini sanıp mutfağa
     * eski adedi gönderirdi.
     */
    public function test_guncelleme_uretilmis_siparisleri_uyarir(): void
    {
        $model = $this->activeSubscription();
        $date = $this->nextServiceDay($model);
        $orderId = $this->makeRun($model, $date);

        $body = $this->signed('PATCH', self::BASE.'/'.$model->id, $this->intent([
            'default_quantity' => 30,
        ]))->assertOk()->json();

        $this->assertSame(30, $body['data']['default_quantity']);
        $this->assertSame('generated_orders_unaffected', $body['warnings'][0]['code']);
        $this->assertContains($orderId, $body['warnings'][0]['order_ids']);
    }

    // ── Durum uçları ──────────────────────────────────────────────────────

    public function test_fiyatsiz_abonelik_aktiflestirilemez(): void
    {
        $model = $this->makeSubscription();
        $model->agreed_unit_price_kurus = null;
        $model->save();

        $this->signed('POST', self::BASE.'/'.$model->id.'/activate', $this->intent())
            ->assertStatus(422)
            ->assertJsonPath('error.details.field', 'agreed_unit_price_kurus');
    }

    /** İş kararı 9: imzalı sözleşme olmadan aktifleşme yok. */
    public function test_imzasiz_sozlesme_ile_aktiflestirilemez(): void
    {
        $model = $this->makeSubscription();

        $this->signed('POST', self::BASE.'/'.$model->id.'/activate', $this->intent())
            ->assertStatus(422)
            ->assertJsonPath('error.details.reason', 'contract_not_signed')
            ->assertJsonPath('error.details.contract_status', 'none');
    }

    public function test_duraklatma_gecmise_alinamaz(): void
    {
        $model = $this->activeSubscription();

        $this->signed('POST', self::BASE.'/'.$model->id.'/pause', $this->intent([
            'start_date' => BusinessTime::now()->subDay()->toDateString(),
            'end_date' => BusinessTime::now()->addDays(3)->toDateString(),
        ]))->assertStatus(422)->assertJsonPath('error.details.field', 'start_date');
    }

    /**
     * Süresiz duraklatma İPTALİN ADI KONMAMIŞ HÂLİDİR; `end_date` zorunlu.
     */
    public function test_suresiz_duraklatma_kabul_edilmez(): void
    {
        $model = $this->activeSubscription();

        $this->signed('POST', self::BASE.'/'.$model->id.'/pause', $this->intent([
            'start_date' => BusinessTime::now()->addDay()->toDateString(),
            'end_date' => null,
        ]))->assertStatus(422);
    }

    public function test_duraklat_ve_devam_et(): void
    {
        $model = $this->activeSubscription();
        $start = BusinessTime::now()->addDay();
        $end = BusinessTime::now()->addDays(10);

        $paused = $this->signed('POST', self::BASE.'/'.$model->id.'/pause', $this->intent([
            'start_date' => $start->toDateString(),
            'end_date' => $end->toDateString(),
            'pause_reason' => 'Kurum tatili',
        ]))->assertOk()->json('data');

        $this->assertSame(Subscription::STATUS_PAUSED, $paused['status']);
        $this->assertSame($start->toDateString(), $paused['pause']['start_date']);

        // Çakışan ikinci duraklatma yok.
        $this->signed('POST', self::BASE.'/'.$model->id.'/pause', $this->intent([
            'start_date' => $start->toDateString(),
            'end_date' => $end->toDateString(),
        ]))->assertStatus(409);

        $resumed = $this->signed('POST', self::BASE.'/'.$model->id.'/resume', $this->intent())
            ->assertOk()->json('data');

        $this->assertSame(Subscription::STATUS_ACTIVE, $resumed['status']);

        // SATIR SİLİNMEDİ, yalnız kapandı: "ne zaman duraklatıldı, ne zaman
        // devam edildi" sorusunun cevabı kalmalı.
        $pause = SubscriptionPause::query()->where('subscription_id', $model->id)->first();
        $this->assertNotNull($pause);
        $this->assertSame(
            BusinessTime::now()->subDay()->toDateString(),
            Carbon::parse($pause->end_date)->toDateString(),
        );
    }

    public function test_duraklatma_cakismasi_409(): void
    {
        $model = $this->activeSubscription();

        $pause = new SubscriptionPause;
        $pause->subscription_id = $model->id;
        $pause->start_date = BusinessTime::now()->addDays(2)->toDateString();
        $pause->end_date = BusinessTime::now()->addDays(6)->toDateString();
        $pause->save();

        $this->signed('POST', self::BASE.'/'.$model->id.'/pause', $this->intent([
            'start_date' => BusinessTime::now()->addDays(5)->toDateString(),
            'end_date' => BusinessTime::now()->addDays(9)->toDateString(),
        ]))
            ->assertStatus(409)
            ->assertJsonPath('error.details.conflict', 'overlapping_pause');
    }

    /** İptal GERİ DÖNÜŞSÜZDÜR; ikinci çağrı `409`. */
    public function test_iptal_geri_donusuzdur(): void
    {
        $model = $this->activeSubscription();
        $effective = BusinessTime::now()->addDays(5);

        $body = $this->signed('POST', self::BASE.'/'.$model->id.'/cancel', $this->intent([
            'effective_date' => $effective->toDateString(),
        ]))->assertOk()->json('data');

        $this->assertSame(Subscription::STATUS_CANCELLED, $body['status']);
        $this->assertSame($effective->toDateString(), $body['end_date']);

        $this->signed('POST', self::BASE.'/'.$model->id.'/cancel', $this->intent())
            ->assertStatus(409)
            ->assertJsonPath('error.details.conflict', 'cancelled');
    }

    public function test_iptal_gunu_gecmise_alinamaz(): void
    {
        $model = $this->activeSubscription();

        $this->signed('POST', self::BASE.'/'.$model->id.'/cancel', $this->intent([
            'effective_date' => BusinessTime::now()->subDay()->toDateString(),
        ]))->assertStatus(422)->assertJsonPath('error.details.field', 'effective_date');
    }

    // ── Takvim ────────────────────────────────────────────────────────────

    /**
     * YALNIZ ÜRETİM YAPILACAK GÜNLER döner; kapalı gün GÖRÜNÜR ama
     * `closed: true` ile — yöneticinin "o gün neden üretim yok" sorusunun
     * cevabı listede olmalı.
     */
    public function test_takvim_yalniz_servis_gunlerini_dondurur(): void
    {
        $model = $this->activeSubscription();
        $closed = $this->nextServiceDay($model);

        $day = new ClosedDay;
        $day->closed_on = $closed->toDateString();
        $day->description = 'Test tatili';
        $day->save();

        $body = $this->signed('GET', self::BASE.'/'.$model->id.'/calendar?days=14')->assertOk()->json();

        $this->assertNotEmpty($body['data']);
        $this->assertSame((int) $model->id, $body['meta']['subscription_id']);
        $this->assertArrayNotHasKey('page', $body['meta'], 'Takvim sayfalanmaz (§5).');

        foreach ($body['data'] as $row) {
            $this->assertContains($row['weekday'], [1, 2, 3, 4, 5], 'Servis günü olmayan gün döndü.');
        }

        $closedRow = collect($body['data'])->firstWhere('date', $closed->toDateString());
        $this->assertNotNull($closedRow, 'Kapalı gün listeden çıkarılmış.');
        $this->assertTrue($closedRow['closed']);
        $this->assertSame('Test tatili', $closedRow['note']);
    }

    public function test_takvim_penceresi_tavani_asamaz(): void
    {
        $model = $this->activeSubscription();

        $this->signed('GET', self::BASE.'/'.$model->id.'/calendar?days=400')->assertStatus(422);
    }

    // ── İstisnalar ────────────────────────────────────────────────────────

    public function test_istisna_servis_gunu_olmayan_gune_girilemez(): void
    {
        $model = $this->activeSubscription();
        $saturday = BusinessTime::now()->startOfDay()->next(Carbon::SATURDAY);

        $this->signed('POST', self::BASE.'/'.$model->id.'/exceptions', $this->intent([
            'service_date' => $saturday->toDateString(),
            'quantity_override' => 12,
        ]))
            ->assertStatus(422)
            ->assertJsonPath('error.details.reason', 'not_a_service_day')
            ->assertJsonPath('error.details.weekday', 6);
    }

    /** "Atla ama 12 yap" tutarsız. */
    public function test_atlanan_gunde_adet_verilemez(): void
    {
        $model = $this->activeSubscription();

        $this->signed('POST', self::BASE.'/'.$model->id.'/exceptions', $this->intent([
            'service_date' => $this->nextServiceDay($model)->toDateString(),
            'skip' => true,
            'quantity_override' => 12,
        ]))->assertStatus(422)->assertJsonPath('error.details.field', 'quantity_override');
    }

    /**
     * Aynı gün için ikinci istisna ÜZERİNE YAZILIR, `409` verilmez:
     * yönetici aynı güne iki kez karar verebilir ve son karar geçerlidir.
     */
    public function test_ayni_gune_ikinci_istisna_uzerine_yazilir(): void
    {
        $model = $this->activeSubscription();
        $date = $this->nextServiceDay($model);

        $this->signed('POST', self::BASE.'/'.$model->id.'/exceptions', $this->intent([
            'service_date' => $date->toDateString(),
            'quantity_override' => 12,
        ]))->assertOk();

        $second = $this->signed('POST', self::BASE.'/'.$model->id.'/exceptions', $this->intent([
            'service_date' => $date->toDateString(),
            'quantity_override' => 8,
        ]))->assertOk()->json('data');

        $this->assertSame(8, $second['quantity_override']);
        $this->assertSame(
            1,
            SubscriptionException::query()->where('subscription_id', $model->id)->count(),
            'İkinci istisna yeni satır açtı; tekil kısıt kırılmış.',
        );

        // İki karar da denetim izinde görünmeli.
        $this->assertSame(
            2,
            ControlAudit::query()->where('action', 'subscription.exception.create')->count(),
        );
    }

    public function test_uretilmis_gune_istisna_409(): void
    {
        $model = $this->activeSubscription();
        $date = $this->nextServiceDay($model);
        $orderId = $this->makeRun($model, $date);

        $this->signed('POST', self::BASE.'/'.$model->id.'/exceptions', $this->intent([
            'service_date' => $date->toDateString(),
            'quantity_override' => 12,
        ]))
            ->assertStatus(409)
            ->assertJsonPath('error.details.conflict', 'already_generated')
            ->assertJsonPath('error.details.order_id', $orderId);
    }

    public function test_istisna_silinir_yoksa_404(): void
    {
        $model = $this->activeSubscription();
        $date = $this->nextServiceDay($model);

        $this->signed('POST', self::BASE.'/'.$model->id.'/exceptions', $this->intent([
            'service_date' => $date->toDateString(),
            'quantity_override' => 12,
        ]))->assertOk();

        $path = self::BASE.'/'.$model->id.'/exceptions/'.$date->toDateString();

        $this->signed('DELETE', $path, $this->intent())->assertOk();
        $this->assertSame(0, SubscriptionException::query()->where('subscription_id', $model->id)->count());

        $this->signed('DELETE', $path, $this->intent())->assertStatus(404);
    }

    // ── Üretim ────────────────────────────────────────────────────────────

    public function test_elle_uretim_siparis_ve_defter_yazar(): void
    {
        $model = $this->activeSubscription();
        $date = $this->nextServiceDay($model);

        $body = $this->signed('POST', self::BASE.'/'.$model->id.'/generate', $this->intent([
            'service_date' => $date->toDateString(),
        ]))->assertOk()->json('data');

        $this->assertSame($date->toDateString(), $body['service_date']);
        $this->assertCount(1, $body['created']);
        $this->assertSame([], $body['skipped']);

        $orderId = $body['created'][0]['order_id'];
        $order = Order::find($orderId);
        $this->assertNotNull($order);
        $this->assertSame((int) $model->id, (int) $order->bld_subscription_id);

        $this->assertSame(1, DB::table('veykemtu_subscription_runs')
            ->where('subscription_id', $model->id)
            ->where('service_date', $date->toDateString())
            ->count());
    }

    /**
     * İdempotency güvencesi veritabanı kısıtından gelir; uç onu 500 yerine
     * `409`'a çevirir.
     */
    public function test_ayni_gun_ikinci_uretim_409(): void
    {
        $model = $this->activeSubscription();
        $date = $this->nextServiceDay($model);

        $this->signed('POST', self::BASE.'/'.$model->id.'/generate', $this->intent([
            'service_date' => $date->toDateString(),
        ]))->assertOk();

        $this->signed('POST', self::BASE.'/'.$model->id.'/generate', $this->intent([
            'service_date' => $date->toDateString(),
        ]))
            ->assertStatus(409)
            ->assertJsonPath('error.details.conflict', 'already_generated');
    }

    public function test_servis_gunu_olmayan_gunde_uretim_reddedilir(): void
    {
        $model = $this->activeSubscription();
        $saturday = BusinessTime::now()->startOfDay()->next(Carbon::SATURDAY);

        $this->signed('POST', self::BASE.'/'.$model->id.'/generate', $this->intent([
            'service_date' => $saturday->toDateString(),
        ]))->assertStatus(422)->assertJsonPath('error.details.reason', 'not_a_service_day');
    }

    public function test_pencere_disi_gun_reddedilir(): void
    {
        $model = $this->activeSubscription();

        $this->signed('POST', self::BASE.'/'.$model->id.'/generate', $this->intent([
            'service_date' => BusinessTime::now()->addDays(30)->toDateString(),
        ]))->assertStatus(422)->assertJsonPath('error.details.field', 'service_date');
    }

    /**
     * Abonelikler stoku ÖNCE rezerve eder; elle üretim o rezervasyonun
     * dışında kalan bir taleptir ve tavana takılabilir.
     */
    public function test_stok_tavani_dolu_ise_uretim_reddedilir(): void
    {
        $model = $this->activeSubscription();
        $date = $this->nextServiceDay($model);

        DB::table('veykemtu_daily_menu_stock')->insert([
            'location_id' => $model->location_id,
            'service_date' => $date->toDateString(),
            'menu_id' => DailyStock::DAY_TOTAL,
            'capacity' => 20,
            'reserved' => 0,
            'sold' => 19,
            'created_at' => BusinessTime::forStorage(BusinessTime::now()),
            'updated_at' => BusinessTime::forStorage(BusinessTime::now()),
        ]);

        $this->signed('POST', self::BASE.'/'.$model->id.'/generate', $this->intent([
            'service_date' => $date->toDateString(),
        ]))
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'STOCK_EXCEEDED')
            ->assertJsonPath('error.details.scope', 'day')
            ->assertJsonPath('error.details.capacity', 20)
            ->assertJsonPath('error.details.sold', 19);
    }

    public function test_kuru_prova_uretim_yapmaz(): void
    {
        $model = $this->activeSubscription();
        $date = $this->nextServiceDay($model);

        $body = $this->signed('POST', self::BASE.'/'.$model->id.'/generate', $this->intent([
            'service_date' => $date->toDateString(),
            'dry_run' => true,
        ]))->assertOk()->json();

        $this->assertCount(1, $body['would']['would_create']);
        $this->assertSame(0, DB::table('veykemtu_subscription_runs')
            ->where('subscription_id', $model->id)
            ->count(), 'Kuru prova defter satırı yazdı.');
    }

    public function test_uretim_defteri_sayfalanir(): void
    {
        $model = $this->activeSubscription();
        $date = $this->nextServiceDay($model);
        $this->makeRun($model, $date);

        $body = $this->signed('GET', self::BASE.'/'.$model->id.'/runs')->assertOk()->json();

        $this->assertCount(1, $body['data']);
        $this->assertSame(1, $body['meta']['total']);
        $this->assertSame($date->toDateString(), $body['data'][0]['service_date']);
        $this->assertNotNull($body['data'][0]['order_number']);
    }

    // ── Erken serbest bırakma ─────────────────────────────────────────────

    public function test_abonelikten_uretilmemis_siparis_serbest_birakilamaz(): void
    {
        $order = $this->plainOrder();

        $this->signed('POST', self::BASE.'/orders/'.$order->order_id.'/release', $this->intent())
            ->assertStatus(422)
            ->assertJsonPath('error.details.reason', 'not_a_subscription_order');
    }

    /**
     * ZATEN AÇILMIŞSA `409` DEĞİL `ok: true`: yönetici için sonuç aynı ve
     * çift tıklamayı hata olarak göstermek hiçbir şeyi düzeltmezdi.
     */
    public function test_serbest_birakma_iki_kez_cagrilabilir(): void
    {
        $model = $this->activeSubscription();
        $orderId = $this->makeRun($model, $this->nextServiceDay($model));
        $path = self::BASE.'/orders/'.$orderId.'/release';

        $first = $this->signed('POST', $path, $this->intent())->assertOk()->json();
        $this->assertTrue($first['ok']);
        $this->assertSame($orderId, $first['data']['order_id']);
        $this->assertNotNull($first['data']['released_at']);

        $this->signed('POST', $path, $this->intent())->assertOk()->assertJsonPath('ok', true);
    }

    // ── Talepler ──────────────────────────────────────────────────────────

    /**
     * Liste ekranında tam iletişim bilgisine ihtiyaç yok; arayacak kişi
     * kaydı açar ve orada her şey maskesizdir.
     */
    public function test_talep_listesi_iletisim_bilgisini_maskeler(): void
    {
        $quote = $this->makeQuote();

        $row = $this->signed('GET', self::BASE.'/requests')->assertOk()->json('data.0');

        $this->assertSame((int) $quote->id, $row['id']);
        $this->assertSame('Mehmet K.', $row['full_name']);
        $this->assertSame('532****567', $row['telephone']);
        $this->assertStringStartsWith('m***@', $row['email']);
        $this->assertStringNotContainsString('5321234567', json_encode($row, JSON_UNESCAPED_UNICODE));
    }

    public function test_tek_talep_maskesiz_doner(): void
    {
        $quote = $this->makeQuote();

        $row = $this->signed('GET', self::BASE.'/requests/'.$quote->id)->assertOk()->json('data');

        $this->assertSame('Mehmet Kaya', $row['full_name']);
        $this->assertSame('5321234567', $row['telephone']);
        // Onaysız kayıt hiç oluşmaz.
        $this->assertNotNull($row['kvkk_accepted_at']);
    }

    /**
     * Talebin KENDİSİ değiştirilemez: bir kaydın içeriğini düzeltebilen bir
     * panel, o kaydın delil değerini yok eder.
     */
    public function test_talep_yalniz_durum_ve_ic_not_kabul_eder(): void
    {
        $quote = $this->makeQuote();

        $body = $this->signed('PATCH', self::BASE.'/requests/'.$quote->id, $this->intent([
            'status' => 'cevaplandi',
            'admin_note' => '16.08 arandı, teklif gönderildi.',
            'full_name' => 'Değiştirilmiş Ad',
        ]))->assertOk()->json('data');

        $this->assertSame('cevaplandi', $body['status']);
        $this->assertSame('Mehmet Kaya', $quote->fresh()->full_name, 'Talep gövdesi değiştirildi.');
    }

    public function test_talep_bilinmeyen_duruma_gecirilemez(): void
    {
        $quote = $this->makeQuote();

        $this->signed('PATCH', self::BASE.'/requests/'.$quote->id, $this->intent([
            'status' => 'uyduruk',
        ]))->assertStatus(422);
    }

    /** Abonelik yine `pending` doğar: sözleşme imzalanmadan aktifleşmez. */
    public function test_talep_abonelige_cevrilir(): void
    {
        $quote = $this->makeQuote();
        $payload = $this->newPayload();

        $body = $this->signed('POST', self::BASE.'/requests/'.$quote->id.'/convert', $this->intent([
            'customer_id' => $this->customerId(),
            'subscription' => array_diff_key(
                $payload,
                array_flip(['actor', 'reason', 'dry_run', 'customer_id']),
            ),
        ]))->assertOk()->json('data');

        $this->assertSame((int) $quote->id, $body['request_id']);
        $this->assertSame('kapandi', $body['request_status']);
        $this->assertSame(Subscription::STATUS_PENDING, $body['subscription']['status']);
        $this->assertSame('kapandi', $quote->fresh()->status);
    }

    public function test_talep_donusumu_musteri_zorunlu_kilar(): void
    {
        $quote = $this->makeQuote();

        $this->signed('POST', self::BASE.'/requests/'.$quote->id.'/convert', $this->intent([
            'subscription' => ['location_id' => $this->locationId()],
        ]))->assertStatus(422);
    }

    // ── Sözleşmeler ───────────────────────────────────────────────────────

    public function test_sozlesme_olusturulur_ve_link_sms_yerine_doner(): void
    {
        $model = $this->makeSubscription();

        $body = $this->signed('POST', self::BASE.'/'.$model->id.'/contracts', $this->intent([
            'phone' => '5321234567',
            'send_sms' => false,
        ]))->assertOk()->json('data');

        $this->assertSame('pending', $body['status']);
        $this->assertSame('5321234567', $body['sent_to_phone']);
        $this->assertNotNull($body['sign_url'], 'SMS gönderilmedi; link yanıtta olmalı.');
        $this->assertFalse($body['sms_sent']);

        // BELİRTEÇ HİÇBİR YERDE GÖRÜNMEZ — ne yanıtta ne denetim yükünde.
        $token = DB::table('veykemtu_subscription_contracts')->where('id', $body['id'])->value('token_hash');
        $audit = ControlAudit::query()->where('action', 'subscription.contract.create')->latest('id')->first();

        $this->assertStringNotContainsString(
            (string) $token,
            json_encode([$body, $audit->payload_json], JSON_UNESCAPED_UNICODE),
        );

        $detail = $this->signed('GET', self::BASE.'/contracts/'.$body['id'])->assertOk()->json('data');
        $this->assertArrayNotHasKey('token', $detail);
        $this->assertArrayNotHasKey('sign_url', $detail);
        $this->assertSame(16000, $detail['terms_snapshot']['agreed_unit_price_kurus']);
    }

    /** İki geçerli bağlantı, hangisinin imzalandığını belirsiz kılardı. */
    public function test_ikinci_acik_sozlesme_409(): void
    {
        $model = $this->makeSubscription();
        $payload = $this->intent(['phone' => '5321234567', 'send_sms' => false]);

        $first = $this->signed('POST', self::BASE.'/'.$model->id.'/contracts', $payload)
            ->assertOk()->json('data');

        $this->signed('POST', self::BASE.'/'.$model->id.'/contracts', $payload)
            ->assertStatus(409)
            ->assertJsonPath('error.details.conflict', 'open_contract')
            ->assertJsonPath('error.details.contract_id', $first['id']);
    }

    /**
     * İmzalanmış bir sözleşmeyi iptal edilmiş göstermek, imzanın kendisini
     * geçersiz kılmaktır.
     */
    public function test_imzali_sozlesme_iptal_edilemez(): void
    {
        $model = $this->makeSubscription();
        $id = $this->signedContract($model);

        $this->signed('POST', self::BASE.'/contracts/'.$id.'/cancel', $this->intent())
            ->assertStatus(409)
            ->assertJsonPath('error.details.conflict', 'signed');

        $this->signed('POST', self::BASE.'/contracts/'.$id.'/resend', $this->intent())
            ->assertStatus(409);
    }

    /** Sözleşme gönderildikten sonra porsiyon fiyatı değişmez. */
    public function test_imzali_sozlesmeden_sonra_fiyat_degistirilemez(): void
    {
        $model = $this->makeSubscription();
        $this->signedContract($model);

        $this->signed('PATCH', self::BASE.'/'.$model->id, $this->intent([
            'agreed_unit_price_kurus' => 19000,
        ]))
            ->assertStatus(409)
            ->assertJsonPath('error.details.conflict', 'contract_signed');
    }

    public function test_imzali_sozlesme_ile_aktiflestirilir(): void
    {
        $model = $this->makeSubscription();
        $this->signedContract($model);

        $body = $this->signed('POST', self::BASE.'/'.$model->id.'/activate', $this->intent())
            ->assertOk()->json('data');

        $this->assertSame(Subscription::STATUS_ACTIVE, $body['status']);
        $this->assertNotNull($body['next_service_date']);
    }

    // ── Ödemeler ──────────────────────────────────────────────────────────

    /**
     * TUTAR SUNUCUDA HESAPLANIR: dönemde kaç porsiyon üretileceği gün
     * kuralından çıkar. Elle yazmak serbest ama varsayılan hesaplanmış
     * olmalı — yönetici her ay çarpma yapmamalı.
     */
    public function test_donem_borcu_plandan_hesaplanir(): void
    {
        $model = $this->activeSubscription();
        $date = $this->nextServiceDay($model);
        $this->makeRun($model, $date);

        $body = $this->signed('POST', self::BASE.'/'.$model->id.'/payments', $this->intent([
            'period_start' => BusinessTime::now()->toDateString(),
        ]))->assertOk()->json('data');

        $this->assertSame('calculated', $body['amount_source']);
        $this->assertGreaterThan(0, $body['portions_planned']);
        $this->assertSame(16000, $body['unit_price_kurus']);
        $this->assertSame(
            $body['portions_planned'] * 16000,
            $body['amount_kurus'],
            'Tutar porsiyon × porsiyon fiyatı olmalı.',
        );
        $this->assertSame(1, $body['order_count'], 'Üretilmiş sipariş sayısı yanlış.');
        $this->assertSame('pending', $body['status']);

        // DÖNEM 30 GÜN SABİT, takvim ayı değil.
        $this->assertSame(
            BusinessTime::now()->addDays(29)->toDateString(),
            $body['period_end'],
        );
        // PEŞİN MODEL: son ödeme günü dönemin ilk günü.
        $this->assertSame($body['period_start'], $body['due_date']);
    }

    /**
     * Gönderilen ama türetilen alanlar SESSİZCE YUTULMAZ: yönetici
     * `due_date` yazıp kaydettiğinde onun tutulduğunu sanır ve gecikmeyi
     * yanlış günden sayardı.
     */
    public function test_turetilen_alanlar_uyari_ile_bildirilir(): void
    {
        $model = $this->activeSubscription();

        $body = $this->signed('POST', self::BASE.'/'.$model->id.'/payments', $this->intent([
            'period_start' => BusinessTime::now()->toDateString(),
            'due_date' => BusinessTime::now()->addDays(20)->toDateString(),
            'note' => 'Elden tahsil edilecek',
        ]))->assertOk()->json();

        $codes = array_column($body['warnings'], 'code');
        $this->assertContains('due_date_derived', $codes);
        $this->assertContains('note_not_stored', $codes);
    }

    public function test_elle_tutar_manual_olarak_isaretlenir(): void
    {
        $model = $this->activeSubscription();

        $body = $this->signed('POST', self::BASE.'/'.$model->id.'/payments', $this->intent([
            'period_start' => BusinessTime::now()->toDateString(),
            'amount_kurus' => 123400,
        ]))->assertOk()->json('data');

        $this->assertSame('manual', $body['amount_source']);
        $this->assertSame(123400, $body['amount_kurus']);
    }

    public function test_ayni_donem_iki_kez_borclandirilamaz(): void
    {
        $model = $this->activeSubscription();
        $payload = $this->intent(['period_start' => BusinessTime::now()->toDateString()]);

        $this->signed('POST', self::BASE.'/'.$model->id.'/payments', $payload)->assertOk();

        $this->signed('POST', self::BASE.'/'.$model->id.'/payments', $payload)
            ->assertStatus(409)
            ->assertJsonPath('error.details.conflict', 'period');
    }

    /** İkinci kez tahsil işaretlemek, tutarı iki kez saydırırdı. */
    public function test_tahsilat_ikinci_kez_isaretlenemez(): void
    {
        $model = $this->activeSubscription();
        $payment = $this->makePayment($model);
        $path = self::BASE.'/payments/'.$payment['id'].'/mark-paid';

        $paid = $this->signed('POST', $path, $this->intent([
            'method' => 'online',
            'reference' => 'TR12 0001 4455',
        ]))->assertOk()->json('data');

        $this->assertSame('paid', $paid['status']);
        $this->assertSame('online', $paid['method']);
        $this->assertSame('TR12 0001 4455', $paid['reference']);
        $this->assertNotNull($paid['paid_at']);

        $this->signed('POST', $path, $this->intent(['method' => 'cash']))
            ->assertStatus(409)
            ->assertJsonPath('error.details.conflict', 'paid');
    }

    /**
     * Tahsilat aboneliği AKTİF YAPAR — geçiş `SubscriptionLifecycle`'da.
     *
     * Burada sınanan şey, panelin elle işaretlemesinin de o tek geçiş
     * noktasından geçtiği: geçmeseydi "para alındı ama abonelik pending"
     * hâli ancak mutfakta fark edilirdi.
     */
    public function test_tahsilat_abonelik_aktif_yapar(): void
    {
        $model = $this->makeSubscription();
        $payment = $this->makePayment($model);

        $this->signed('POST', self::BASE.'/payments/'.$payment['id'].'/mark-paid', $this->intent([
            'method' => 'cash',
        ]))->assertOk();

        $this->assertSame(Subscription::STATUS_ACTIVE, $model->fresh()->status);
    }

    public function test_gelecek_tarihli_tahsilat_reddedilir(): void
    {
        $model = $this->activeSubscription();
        $payment = $this->makePayment($model);

        $this->signed('POST', self::BASE.'/payments/'.$payment['id'].'/mark-paid', $this->intent([
            'method' => 'cash',
            'paid_at' => BusinessTime::now()->addDays(2)->utc()->toIso8601ZuluString(),
        ]))->assertStatus(422)->assertJsonPath('error.details.field', 'paid_at');
    }

    /** `overdue` SUNUCUDA hesaplanır; saati kaymış bir panel yanılmasın. */
    public function test_odeme_listesi_gecikmeyi_sunucuda_hesaplar(): void
    {
        $model = $this->activeSubscription();
        $start = BusinessTime::now()->subDays(11);

        $created = $this->signed('POST', self::BASE.'/'.$model->id.'/payments', $this->intent([
            'period_start' => $start->toDateString(),
        ]))->assertOk()->json('data');

        $body = $this->signed('GET', self::BASE.'/'.$model->id.'/payments')->assertOk()->json();

        $this->assertTrue($body['data'][0]['overdue']);
        $this->assertSame(11, $body['data'][0]['overdue_days']);
        $this->assertSame($created['amount_kurus'], $body['meta']['overdue_kurus']);
        $this->assertSame(0, $body['meta']['paid_kurus']);
        $this->assertArrayNotHasKey('page', $body['meta'], 'Ödeme listesi sayfalanmaz.');
    }

    /** Liste süzgeci PANEL sözlüğünü konuşur, kaydın ham durumunu değil. */
    public function test_odeme_suzgeci_panel_sozlugunu_kullanir(): void
    {
        $model = $this->activeSubscription();
        $payment = $this->makePayment($model);

        $this->signed('POST', self::BASE.'/payments/'.$payment['id'].'/mark-paid', $this->intent([
            'method' => 'cash',
        ]))->assertOk();

        $paid = $this->signed('GET', self::BASE.'/'.$model->id.'/payments?status=paid')
            ->assertOk()->json('data');

        $this->assertCount(1, $paid);
        $this->assertSame('succeeded', $paid[0]['provider_status'], 'Ham durum da dönmeli.');

        $pending = $this->signed('GET', self::BASE.'/'.$model->id.'/payments?status=pending')
            ->assertOk()->json('data');

        $this->assertCount(0, $pending);
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    /** @param array<string, mixed>|null $body */
    private function signed(string $method, string $path, ?array $body = null): TestResponse
    {
        $raw = $body === null ? '' : (string) json_encode($body, JSON_UNESCAPED_UNICODE);
        $timestamp = time();
        $nonce = bin2hex(random_bytes(12));

        $canonical = implode("\n", [
            strtoupper($method),
            // Sorgu dizesi imzaya GİRMEZ.
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

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function newPayload(array $overrides = []): array
    {
        return $this->intent([
            'customer_id' => $this->customerId(),
            'location_id' => $this->locationId(),
            'start_date' => BusinessTime::now()->addDay()->toDateString(),
            'end_date' => null,
            'delivery_type' => 'delivery',
            'delivery_time_from' => '11:30',
            'delivery_time_to' => '12:30',
            'service_days' => [1, 2, 3, 4, 5],
            // Testlerin çoğu üretim yapıyor ve `daily_menu` her gün için
            // yayınlanmış bir menü isterdi; sabit liste o kurulumu tek
            // satıra indiriyor ve sınanan şey menü yayını değil.
            'menu_mode' => Subscription::MENU_FIXED_LIST,
            'default_quantity' => 20,
            'agreed_unit_price_kurus' => 16000,
            'payment_mode' => Subscription::PAYMENT_PREPAID,
            'lines' => [['menu_id' => $this->anyMenuId(), 'quantity' => 1, 'label' => 'Standart']],
            'delivery_points' => [['address_id' => $this->addressId(), 'quantity' => 20]],
            ...$overrides,
        ]);
    }

    private function makeSubscription(): Subscription
    {
        $id = (int) $this->signed('POST', self::BASE, $this->newPayload())
            ->assertStatus(201)
            ->json('data.id');

        return Subscription::query()
            ->with(['lines', 'delivery_points', 'pauses', 'exceptions'])
            ->findOrFail($id);
    }

    /**
     * Aktif abonelik — `activate` UCUNDAN GEÇMEDEN.
     *
     * O uç imzalı sözleşme istiyor ve sözleşme tablosu henüz başka bir
     * kulvarda; durumu doğrudan yazmak, sınanan şeyi (duraklatma, üretim,
     * takvim) ulaşılamaz kılan bir önkoşuldan kurtarıyor.
     */
    private function activeSubscription(): Subscription
    {
        $model = $this->makeSubscription();
        $model->status = Subscription::STATUS_ACTIVE;
        $model->save();

        return $model->fresh(['lines', 'delivery_points', 'pauses', 'exceptions']);
    }

    /** Aboneliğin bugünden sonraki ilk servis günü. */
    private function nextServiceDay(Subscription $model): Carbon
    {
        $cursor = BusinessTime::now()->startOfDay()->addDay();

        for ($i = 0; $i < 14; $i++, $cursor->addDay()) {
            if (in_array($cursor->dayOfWeekIso, [1, 2, 3, 4, 5], true)
                && !ClosedDay::isClosed($cursor)
            ) {
                return $cursor->copy();
            }
        }

        $this->fail('İki hafta içinde servis günü bulunamadı.');
    }

    /** Üretilmiş bir gün: sipariş + defter satırı. */
    private function makeRun(Subscription $model, Carbon $date): int
    {
        return (int) $this->signed('POST', self::BASE.'/'.$model->id.'/generate', $this->intent([
            'service_date' => $date->toDateString(),
        ]))->assertOk()->json('data.created.0.order_id');
    }

    /** Abonelikten gelmeyen bir sipariş — serbest bırakma reddi için. */
    private function plainOrder(): Order
    {
        $order = new Order;
        $order->customer_id = $this->customerId();
        $order->location_id = $this->locationId();
        $order->order_type = Order::DELIVERY;
        $order->order_date = BusinessTime::now()->toDateString();
        $order->order_time = '12:00:00';
        $order->order_time_is_asap = false;
        $order->total_items = 1;
        $order->order_total = 100.0;
        $order->payment = 'cash';
        $order->cart = serialize([]);
        $order->save();

        return $order;
    }

    private function makeQuote(): QuoteRequest
    {
        $quote = new QuoteRequest;
        $quote->full_name = 'Mehmet Kaya';
        $quote->organization = 'Acme Gıda A.Ş.';
        $quote->telephone = '5321234567';
        $quote->email = 'mehmet@acme.com.tr';
        $quote->service_type = 'kurumsal-catering';
        $quote->headcount = 20;
        $quote->frequency = 'haftalik';
        $quote->location = 'Ankara / Çankaya';
        $quote->kvkk_accepted_at = BusinessTime::forStorage(BusinessTime::now());
        $quote->status = QuoteRequest::STATUS_NEW;
        $quote->save();

        return $quote;
    }

    /** İmzalanmış bir sözleşme satırı yazar ve kimliğini döndürür. */
    private function signedContract(Subscription $model): int
    {
        $id = (int) $this->signed('POST', self::BASE.'/'.$model->id.'/contracts', $this->intent([
            'phone' => '5321234567',
            'send_sms' => false,
        ]))->assertOk()->json('data.id');

        /*
         * ONAY AKIŞI ATLANIYOR. Gerçek onay müşteri yüzünde (OTP + imza) ve
         * `ContractTest` orada sınanıyor; burada sınanan şey panelin imzalı
         * bir sözleşme KARŞISINDA ne yaptığı. Kayıt `approved` yazılıyor,
         * panel sözlüğündeki karşılığı `signed`.
         */
        DB::table('veykemtu_subscription_contracts')->where('id', $id)->update([
            'status' => SubscriptionContract::STATUS_APPROVED,
            'approved_at' => BusinessTime::forStorage(BusinessTime::now()),
            'otp_verified_at' => BusinessTime::forStorage(BusinessTime::now()),
        ]);

        return $id;
    }

    /**
     * Bir dönem borcu açar ve yanıtını döndürür.
     *
     * @return array<string, mixed>
     */
    private function makePayment(Subscription $model): array
    {
        return $this->signed('POST', self::BASE.'/'.$model->id.'/payments', $this->intent([
            'period_start' => BusinessTime::now()->toDateString(),
        ]))->assertOk()->json('data');
    }

    private function customerId(): int
    {
        $this->asCustomer();

        return (int) ApiCustomer::query()->where('email', 'test@ornek.com')->value('customer_id');
    }

    private function addressId(): int
    {
        $existing = DB::table('addresses')->where('customer_id', $this->customerId())->value('address_id');

        if ($existing !== null) {
            return (int) $existing;
        }

        return (int) $this->asCustomer()->postJson('/api/addresses', [
            'line1' => 'Atatürk Caddesi No:12',
            'district' => 'Selçuklu',
            'city' => 'Konya',
        ], self::HEADERS)->json('id');
    }

    private function anyMenuId(): int
    {
        return (int) Menu::query()->where('menu_status', true)->orderBy('menu_id')->value('menu_id');
    }
}
