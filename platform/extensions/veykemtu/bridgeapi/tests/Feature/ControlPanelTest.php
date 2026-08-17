<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Order;
use Igniter\Local\Models\Location;
use Illuminate\Support\Carbon;
use Illuminate\Testing\TestResponse;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Models\ClosedDay;
use Veykemtu\BridgeApi\Models\ControlAudit;
use Veykemtu\BridgeApi\Services\LocationGate;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;

/**
 * Kontrol paneli uçları — `docs/control/` (14 alan).
 *
 * `ControlKdsTest` K-21'in KDS ailesini sınıyor; bu dosya onun yanına
 * gelen panel ailesini sınıyor. Kopya değil, üç ayrı soru soruyor:
 *
 * 1. **Kapı aynı mı?** İmza, zaman penceresi ve nonce yeni önekte de
 *    çalışıyor mu. Yeni bir rota grubu, ara katmanı yanlışlıkla dışarıda
 *    bırakmanın en kolay yoludur; testi bu yüzden tekrarlanıyor.
 * 2. **Kabuk aynı mı?** Gerekçe zorunluluğu, kuru prova ve denetim satırı
 *    `ControlController::write()`'tan geliyor — ama yalnız uçlar onu
 *    çağırıyorsa. Sözleşme "bir uç `write()` kullanmıyorsa o uç sözleşmeye
 *    aykırıdır" diyor ve bu testler onu yakalıyor.
 * 3. **Kovalar ayrı mı?** `bld-control-panel` ile `bld-control` aynı
 *    bütçeyi paylaşırsa paneldeki bir patlama MUTFAĞIN kasa yönetimini
 *    kilitler. Ayrılığın kendi testi var.
 *
 * Sır ortamdan okunuyor; test için sabitleniyor (`ControlKdsTest` deseni).
 */
class ControlPanelTest extends KitchenTestCase
{
    private const string SECRET = 'test-kontrol-merkezi-sirri';

    private const string ACTOR = 'Ayşe Yönetici';

    private const string REASON = 'Sahada denetim için yapıldı';

    protected function setUp(): void
    {
        parent::setUp();

        putenv('BLD_CONTROL_SECRET='.self::SECRET);
        $_ENV['BLD_CONTROL_SECRET'] = self::SECRET;
    }

    // ── 1. Kapı: imza katmanı yeni önekte de duruyor ──────────────────────

    public function test_imzali_panel_istegi_kabul_edilir(): void
    {
        $this->signed('GET', '/api/control/settings/sales')
            ->assertOk()
            ->assertJsonPath('data.location_id', $this->locationId());
    }

    public function test_IMZASIZ_panel_istegi_reddedilir(): void
    {
        $this->getJson('/api/control/settings/sales', ['Accept' => 'application/json'])
            ->assertStatus(401)
            ->assertJsonPath('error.code', 'UNAUTHENTICATED');
    }

    public function test_AYNI_NONCE_IKINCI_KEZ_reddedilir(): void
    {
        // TEKRAR (REPLAY) SALDIRISI. Pencere tek başına yetmez: pencere
        // içinde aynı isteği ikinci kez oynatmak hâlâ mümkün olurdu ve
        // "satışı durdur" isteğinin tekrarı dükkânı kapatırdı.
        $nonce = bin2hex(random_bytes(12));

        $this->signed('GET', '/api/control/settings/sales', nonce: $nonce)->assertOk();
        $this->signed('GET', '/api/control/settings/sales', nonce: $nonce)->assertStatus(401);
    }

    public function test_ALTI_DAKIKA_ONCEKI_IMZA_reddedilir(): void
    {
        // Pencere ±300 sn; 360 saniye önce imzalanmış bir istek, imzası
        // kusursuz olsa bile geçmemeli.
        $this->signed('GET', '/api/control/settings/sales', timestamp: time() - 360)
            ->assertStatus(401);

        $this->signed('GET', '/api/control/settings/sales', timestamp: time() + 360)
            ->assertStatus(401);
    }

    // ── 2. Gerekçe ────────────────────────────────────────────────────────

    public function test_GEREKCESIZ_YAZMA_422_VE_DENETIM_SATIRI_YOK(): void
    {
        // GEÇERLİ BİR İSTEK HİÇ OLUŞMADI: `write()` önce gerekçeyi
        // doğruluyor, denetim satırını sonra açıyor. Sıra tersine
        // dönseydi doğrulanmamış her istek izi kirletirdi.
        $this->signed('PUT', '/api/control/settings/sales', [
            'actor' => self::ACTOR,
            'order_cutoff' => '08:00',
        ])->assertStatus(422)->assertJsonPath('error.code', 'VALIDATION_FAILED');

        $this->assertSame(0, ControlAudit::count());
        $this->assertNull($this->sales()['order_cutoff']);
    }

    public function test_AKTORSUZ_YAZMA_reddedilir(): void
    {
        $this->signed('POST', '/api/control/settings/ordering/resume', [
            'reason' => self::REASON,
        ])->assertStatus(422);

        $this->assertSame(0, ControlAudit::count());
    }

    public function test_DOKUZ_KARAKTERLIK_GEREKCE_REDDEDILIR_ONUNCUSU_KABUL(): void
    {
        // On karakter bir cümlenin başlangıcını zorlar. Sınır olmasaydı
        // "ok" yazıp geçmek serbest olurdu ve denetim izi doldurulmuş ama
        // hiçbir şey anlatmayan bir sütuna dönerdi.
        $this->signed('POST', '/api/control/settings/ordering/resume', [
            'actor' => self::ACTOR,
            'reason' => str_repeat('a', 9),
        ])->assertStatus(422);

        $this->assertSame(0, ControlAudit::count());

        $this->signed('POST', '/api/control/settings/ordering/resume', [
            'actor' => self::ACTOR,
            'reason' => str_repeat('a', 10),
        ])->assertOk()->assertJsonPath('ok', true);

        $this->assertSame(1, ControlAudit::count());
    }

    // ── 3. Kuru prova ─────────────────────────────────────────────────────

    public function test_KURU_PROVA_AYARI_YAZMAZ_ama_denetim_birakir(): void
    {
        $response = $this->signed('PUT', '/api/control/settings/sales', $this->intent([
            'order_cutoff' => '08:00',
            'dry_run' => true,
        ]))->assertOk();

        $response->assertJsonPath('dry_run', true)
            ->assertJsonPath('would.action', 'settings.sales')
            ->assertJsonPath('would.changes.0.field', 'order_cutoff')
            ->assertJsonPath('would.changes.0.from', null)
            ->assertJsonPath('would.changes.0.to', '08:00');

        $this->assertNull($this->sales()['order_cutoff'], 'Kuru prova ayarı yazmamalı.');

        $audit = ControlAudit::firstOrFail();
        $this->assertSame(ControlAudit::RESULT_DRY_RUN, $audit->result);
        $this->assertSame('settings.sales', $audit->action);
    }

    public function test_KURU_PROVA_kapali_gun_yaratmaz(): void
    {
        $this->signed('POST', '/api/control/settings/closed-days', $this->intent([
            'date' => '2026-08-30',
            'description' => '30 Ağustos Zafer Bayramı',
            'dry_run' => true,
        ]))->assertOk()->assertJsonPath('would.date', '2026-08-30');

        $this->assertSame(0, ClosedDay::count());
        $this->assertSame(ControlAudit::RESULT_DRY_RUN, ControlAudit::firstOrFail()->result);
    }

    // ── 4. Denetim sonucu ─────────────────────────────────────────────────

    public function test_BASARILI_YAZMA_applied_isaretlenir(): void
    {
        $this->signed('PUT', '/api/control/settings/sales', $this->intent([
            'order_cutoff' => '08:00',
            'max_lookahead_days' => 7,
        ]))->assertOk()->assertJsonPath('data.order_cutoff', '08:00');

        $audit = ControlAudit::firstOrFail();

        $this->assertSame(ControlAudit::RESULT_APPLIED, $audit->result);
        $this->assertSame(ControlAudit::TARGET_SETTINGS, $audit->target_type);
        $this->assertSame($this->locationId(), (int) $audit->target_id);
        // `location_options` GEÇMİŞ TUTMAZ: "kesim saati ne zaman değişti"
        // sorusunun cevabı yalnız bu satırda.
        $this->assertSame('order_cutoff', $audit->payload_json['changes'][0]['field']);
    }

    public function test_ZORLANMIS_HATA_failed_ve_payload_error_dolu(): void
    {
        // "Denedim ve olmadı" tam da soruşturulması gereken hâl. Denetim
        // satırı işlemden ÖNCE açıldığı için yarıda kalan yazma da iz
        // bırakıyor.
        $order = $this->confirmedOrder();
        $this->advance((int) $order->order_id, [
            OrderStatusTransition::PREPARING,
            OrderStatusTransition::READY,
            OrderStatusTransition::ON_THE_WAY,
            OrderStatusTransition::DELIVERED,
        ]);

        $this->signed(
            'POST',
            '/api/control/orders/'.$order->order_id.'/revisions',
            $this->intent([
                'items' => [['menu_id' => $this->menuId('Tavuk Sote'), 'quantity' => 1]],
            ]),
        )->assertStatus(422);

        $audit = ControlAudit::firstOrFail();

        $this->assertSame(ControlAudit::RESULT_FAILED, $audit->result);
        $this->assertArrayHasKey('error', $audit->payload_json);
    }

    // ── 5. Hız sınırı kovaları ────────────────────────────────────────────

    public function test_PANEL_KOVASI_KDS_BUTCESINDEN_AYRI(): void
    {
        /*
         * KOVALARIN AYRILMASININ SEBEBİ: aynı bütçeyi paylaşsalardı
         * paneldeki bir yoklama patlaması `429` üretir ve MUTFAĞIN kasa
         * yönetimi kilitlenirdi — cihaz iptal edilemez, sipariş revize
         * edilemezdi. Test bunu sayaçlar üzerinden kanıtlıyor.
         */
        $kds = $this->signed('GET', '/api/control/kds/overview')->assertOk();
        $this->assertSame('1200', $kds->headers->get('X-RateLimit-Limit'));
        $kalanOnce = (int) $kds->headers->get('X-RateLimit-Remaining');

        $panel = $this->signed('GET', '/api/control/settings/sales')->assertOk();
        $this->assertSame('3000', $panel->headers->get('X-RateLimit-Limit'));

        // Üç panel isteği daha; KDS kovasına dokunmamalı.
        $this->signed('GET', '/api/control/settings/sales')->assertOk();
        $this->signed('GET', '/api/control/settings/closed-days')->assertOk();
        $this->signed('GET', '/api/control/orders')->assertOk();

        $kdsSonra = $this->signed('GET', '/api/control/kds/overview')->assertOk();

        $this->assertSame(
            $kalanOnce - 1,
            (int) $kdsSonra->headers->get('X-RateLimit-Remaining'),
            'Panel istekleri KDS bütçesini tüketmemeli.',
        );
    }

    // ── 6. Satış ayarları ─────────────────────────────────────────────────

    public function test_satis_ayarlari_sozlesmedeki_alanlari_tasir(): void
    {
        $response = $this->signed('GET', '/api/control/settings/sales')->assertOk();

        $response->assertJsonStructure([
            'data' => [
                'location_id', 'location_name', 'ordering_enabled', 'paused_until',
                'pause_reason', 'is_open', 'order_cutoff', 'max_lookahead_days',
                'min_order_total_kurus', 'delivery_fee_kurus',
                'payment_methods', 'busy', 'busy_message', 'prep_minutes',
                'delivery_minutes', 'busy_extra_minutes', 'daily_menu_enabled',
                'daily_package_menu_id', 'auto_invoice',
            ],
            'meta' => ['available_payment_methods', 'defaults'],
            'server_time',
        ]);

        // VARSAYILANLAR SUNUCUDAN SÖYLENİR: istemcinin kendi varsayılanını
        // gömmesi, sunucu varsayılanı değiştiğinde iki farklı gerçek
        // üretirdi.
        $response->assertJsonPath('meta.defaults.max_lookahead_days', 7)
            ->assertJsonPath('meta.available_payment_methods', ['online', 'cash']);
    }

    /**
     * KALDIRILMIŞ AYAR YANITTA HİÇ GEÇMEZ.
     *
     * `subscription_release_time` 17.08.2026'da kaldırıldı; sipariş servis
     * gününün kesim anında mutfağa düşüyor. Alan bir süre kalıntı olarak
     * yayınlanmaya devam etti ve sabit `"07:00"` döndürdü — hata vermeyen,
     * yalnızca YANLIŞ bir cevap. Bu iddia onun geri gelmesini engelliyor:
     * anahtarın VARLIĞI aranıyor, değeri değil.
     */
    public function test_KALDIRILAN_serbest_birakma_saati_yanitta_YOK(): void
    {
        $body = $this->signed('GET', '/api/control/settings/sales')->assertOk()->json();

        $this->assertArrayNotHasKey('subscription_release_time', $body['data']);
        $this->assertArrayNotHasKey('subscription_release_time', $body['meta']['defaults']);
    }

    /**
     * Kaldırılmış ayara yazma denemesi SESSİZCE YUTULMAZ, `422` verir.
     *
     * Alanı yalnızca yazılabilirler listesinden çıkarmak yetmezdi: eski bir
     * panel derlemesi `200` ve boş bir `changed` görüp saati kaydettiğini
     * sanardı. Kaldırılmış bir ayarın en tehlikeli hâli, yazılıyormuş gibi
     * davranmasıdır.
     */
    public function test_KALDIRILAN_serbest_birakma_saati_YAZILAMAZ(): void
    {
        $this->signed('PUT', '/api/control/settings/sales', $this->intent([
            'subscription_release_time' => '07:00',
        ]))
            ->assertStatus(422)
            ->assertJsonPath('error.details.field', 'subscription_release_time');
    }

    public function test_KISMI_YAZMA_gonderilmeyen_alani_degistirmez(): void
    {
        $this->signed('PUT', '/api/control/settings/sales', $this->intent([
            'min_order_total_kurus' => 15000,
            'delivery_fee_kurus' => 2500,
        ]))->assertOk();

        $this->signed('PUT', '/api/control/settings/sales', $this->intent([
            'order_cutoff' => '08:00',
        ]))->assertOk()->assertJsonPath('changed', ['order_cutoff']);

        $sales = $this->sales();

        $this->assertSame('08:00', $sales['order_cutoff']);
        $this->assertSame(15000, $sales['min_order_total_kurus'], 'Gönderilmeyen alan değişmemeli.');
        $this->assertSame(2500, $sales['delivery_fee_kurus']);
    }

    public function test_AYNI_DEGERI_YAZMAK_changed_listesine_girmez(): void
    {
        $this->signed('PUT', '/api/control/settings/sales', $this->intent([
            'order_cutoff' => '08:00',
        ]))->assertOk()->assertJsonPath('changed', ['order_cutoff']);

        $this->signed('PUT', '/api/control/settings/sales', $this->intent([
            'order_cutoff' => '08:00',
        ]))->assertOk()->assertJsonPath('changed', []);
    }

    public function test_MUTFAGIN_YOGUNLUK_TUSU_ILGISIZ_KAYITTA_geri_alinmaz(): void
    {
        /*
         * YOĞUNLUK YARIŞI. Mutfak ekranındaki tuş da `bld_busy`'yi
         * çeviriyor. Panel ilgisiz bir ayarı kaydettiğinde o tuşu geri
         * almamalı — mutfakta "tuş çalışmıyor" şikâyetine dönüşen ve
         * sebebi görünmeyen bir hatadır. Form yüzündeki `busy_snapshot`
         * çözümünün kontrol yüzündeki karşılığı KISMİ yazmadır.
         */
        $gate = resolve(LocationGate::class);
        $location = Location::findOrFail($this->locationId());

        $gate->setBusy($location, true);

        $this->signed('PUT', '/api/control/settings/sales', $this->intent([
            'order_cutoff' => '08:00',
        ]))->assertOk();

        $this->assertTrue($gate->isBusy($location->refresh()), 'Mutfağın yoğunluk tuşu geri alınmamalı.');
    }

    public function test_YAZILAMAZ_ALANLAR_reddedilir(): void
    {
        foreach (['is_open', 'daily_package_menu_id', 'ordering_enabled'] as $field) {
            $this->signed('PUT', '/api/control/settings/sales', $this->intent([
                $field => 1,
            ]))->assertStatus(422)->assertJsonPath('error.details.field', $field);
        }

        // Reddedilen istek hiç oluşmadı: denetim satırı da yok.
        $this->assertSame(0, ControlAudit::count());
    }

    public function test_ILERI_SIPARIS_PENCERESI_YEDI_GUNDEN_UZUN_olamaz(): void
    {
        // İş kararı 3: en fazla 7 gün. `LocationGate` bugün 30 varsayıyor;
        // panelden 30 girilebilmesi kararın sessizce delinmesi olurdu.
        $this->signed('PUT', '/api/control/settings/sales', $this->intent([
            'max_lookahead_days' => 8,
        ]))->assertStatus(422);

        $this->signed('PUT', '/api/control/settings/sales', $this->intent([
            'max_lookahead_days' => 0,
        ]))->assertOk();

        // Sıfır GEÇERLİ bir değer: "yalnız bugüne sipariş alınır".
        $this->assertSame(0, $this->sales()['max_lookahead_days']);
    }

    public function test_ODEME_YONTEMI_bos_liste_ve_cari_reddedilir(): void
    {
        $this->signed('PUT', '/api/control/settings/sales', $this->intent([
            'payment_methods' => [],
        ]))->assertStatus(422);

        // Cari hesap iş modelinden çıktı; `account` artık kabul edilmiyor.
        $this->signed('PUT', '/api/control/settings/sales', $this->intent([
            'payment_methods' => ['online', 'account'],
        ]))->assertStatus(422);

        $this->signed('PUT', '/api/control/settings/sales', $this->intent([
            'payment_methods' => ['online', 'cash'],
        ]))->assertOk()->assertJsonPath('data.payment_methods', ['online', 'cash']);
    }

    public function test_DAKIKA_ALANLARINDA_ARALIK_DISI_reddedilir_sessizce_duzeltilmez(): void
    {
        // `LocationGate::positiveMinutes()` aralık dışını sessizce
        // varsayılana çeviriyor; bu uç REDDEDİYOR. Sessizce düzeltilen bir
        // ayar, yöneticinin girdiğini sandığı değerle çalışmadığını hiç
        // öğrenmemesi demektir.
        $this->signed('PUT', '/api/control/settings/sales', $this->intent([
            'prep_minutes' => 0,
        ]))->assertStatus(422);

        $this->signed('PUT', '/api/control/settings/sales', $this->intent([
            'prep_minutes' => 481,
        ]))->assertStatus(422);
    }

    // ── 7. Satış şalteri ──────────────────────────────────────────────────

    public function test_durdurma_satisi_keser_ve_musteri_mesajini_yazar(): void
    {
        $until = Carbon::now()->utc()->addHours(3)->toIso8601ZuluString();

        $this->signed('POST', '/api/control/settings/ordering/pause', $this->intent([
            'until' => $until,
            'customer_message' => 'Teknik bir arıza nedeniyle bugün sipariş alamıyoruz.',
        ]))->assertOk()
            ->assertJsonPath('data.ordering_enabled', false)
            ->assertJsonPath('data.pause_reason', 'Teknik bir arıza nedeniyle bugün sipariş alamıyoruz.');

        // `reason` MÜŞTERİYE GÖSTERİLMEZ — o denetim izi içindir.
        $this->assertNotSame(self::REASON, $this->sales()['pause_reason']);

        $this->assertSame('settings.ordering.pause', ControlAudit::firstOrFail()->action);
    }

    public function test_GECMISTEKI_VE_COK_UZAK_BITIS_reddedilir(): void
    {
        $this->signed('POST', '/api/control/settings/ordering/pause', $this->intent([
            'until' => Carbon::now()->utc()->subHour()->toIso8601ZuluString(),
        ]))->assertStatus(422)->assertJsonPath('error.details.field', 'until');

        // 30 günden uzun bir durdurma "süreli" değil kapanıştır ve `null`
        // ile ifade edilmelidir.
        $this->signed('POST', '/api/control/settings/ordering/pause', $this->intent([
            'until' => Carbon::now()->utc()->addDays(45)->toIso8601ZuluString(),
        ]))->assertStatus(422);
    }

    public function test_devam_durdurma_izlerini_temizler(): void
    {
        $this->signed('POST', '/api/control/settings/ordering/pause', $this->intent([
            'until' => null,
            'customer_message' => 'Bugün sipariş alamıyoruz.',
        ]))->assertOk();

        $this->signed('POST', '/api/control/settings/ordering/resume', $this->intent())
            ->assertOk()
            ->assertJsonPath('data.ordering_enabled', true)
            ->assertJsonPath('data.paused_until', null)
            ->assertJsonPath('data.pause_reason', null);
    }

    // ── 8. Kapalı günler ──────────────────────────────────────────────────

    public function test_kapali_gun_eklenir_ve_listelenir(): void
    {
        $date = Carbon::now()->addDays(20)->toDateString();

        $this->signed('POST', '/api/control/settings/closed-days', $this->intent([
            'date' => $date,
            'description' => 'Planlı bakım',
        ]))->assertOk()->assertJsonPath('data.date', $date);

        $this->signed('GET', '/api/control/settings/closed-days')
            ->assertOk()
            ->assertJsonPath('data.0.date', $date)
            ->assertJsonPath('data.0.description', 'Planlı bakım');

        $audit = ControlAudit::firstOrFail();
        $this->assertSame('settings.closed_day.create', $audit->action);
        $this->assertSame(ControlAudit::TARGET_CLOSED_DAY, $audit->target_type);
    }

    public function test_AYNI_GUN_IKINCI_KEZ_409_doner(): void
    {
        $date = Carbon::now()->addDays(20)->toDateString();
        $body = $this->intent(['date' => $date]);

        $this->signed('POST', '/api/control/settings/closed-days', $body)->assertOk();

        $this->signed('POST', '/api/control/settings/closed-days', $body)
            ->assertStatus(409)
            ->assertJsonPath('error.code', 'CONFLICT')
            ->assertJsonPath('error.details.conflict', 'date');

        $this->assertSame(1, ClosedDay::count());
    }

    public function test_kapali_gun_silinir_ve_OLMAYAN_GUN_404_doner(): void
    {
        $date = Carbon::now()->addDays(20)->toDateString();

        $this->signed('POST', '/api/control/settings/closed-days', $this->intent(['date' => $date]))
            ->assertOk();

        $this->signed('DELETE', '/api/control/settings/closed-days/'.$date, $this->intent())
            ->assertOk()
            ->assertJsonPath('data.deleted', true);

        $this->assertSame(0, ClosedDay::count());

        // "ZATEN ÖYLE" HOŞGÖRÜSÜ YOK: var olmayan bir tatili silmeye
        // çalışan yönetici muhtemelen yanlış tarihe bakıyor.
        $this->signed('DELETE', '/api/control/settings/closed-days/'.$date, $this->intent())
            ->assertStatus(404)
            ->assertJsonPath('error.code', 'NOT_FOUND');
    }

    public function test_O_GUNE_SIPARIS_VARSA_uyari_doner_ama_engel_cikmaz(): void
    {
        $order = $this->confirmedOrder();
        $date = (string) Carbon::parse($order->bld_service_date)->toDateString();

        $response = $this->signed('POST', '/api/control/settings/closed-days', $this->intent([
            'date' => $date,
        ]))->assertOk();

        $this->assertNotEmpty($response->json('warnings'), 'O güne sipariş varsa uyarı dönmeli.');
    }

    // ── 9. Siparişler ─────────────────────────────────────────────────────

    public function test_panel_listesi_SAYFALI_VE_FIYATLI(): void
    {
        $order = $this->confirmedOrder(quantity: 3);

        $response = $this->signed('GET', '/api/control/orders?per_page=10')->assertOk();

        $response->assertJsonPath('meta.per_page', 10)
            ->assertJsonPath('meta.page', 1)
            ->assertJsonPath('meta.total', 1)
            ->assertJsonPath('data.0.id', (int) $order->order_id);

        $row = $response->json('data.0');

        // Kontrol Merkezi bir YÖNETİM yüzeyi ve ciro sorusuna cevap vermek
        // zorunda; ADR-08 mutfak kapsamını men ediyor, bunu değil.
        $this->assertIsInt($row['total_kurus']);
        $this->assertGreaterThan(0, $row['total_kurus']);
        $this->assertSame('cash', $row['payment_method']);
        $this->assertFalse($row['has_invoice']);
        $this->assertSame(0, $row['revision_no']);
    }

    public function test_panel_listesi_KDS_LISTESINDEN_FARKLI_KUME_doner(): void
    {
        // İki uç aynı kümeyi dönseydi KDS ekranının gördüğü sipariş
        // listesi panelin süzgeçleriyle değişirdi.
        $order = $this->confirmedOrder();

        $this->signed('POST', '/api/control/orders/'.$order->order_id.'/cancel', $this->intent())
            ->assertOk();

        $kds = $this->signed('GET', '/api/control/kds/orders')->assertOk()->json('data');
        $panel = $this->signed('GET', '/api/control/orders')->assertOk()->json('data');

        $this->assertCount(0, $kds, 'İptal edilmiş sipariş mutfak panosunda görünmez.');
        $this->assertCount(1, $panel, 'Panel listesi terminal siparişleri de gösterir.');
        $this->assertSame(OrderStatusTransition::CANCELLED, $panel[0]['status']);
    }

    public function test_durum_suzgeci_yalniz_istenen_kodlari_getirir(): void
    {
        $this->confirmedOrder();

        $this->signed('GET', '/api/control/orders?status=hazirlaniyor')
            ->assertOk()
            ->assertJsonPath('meta.total', 0);

        $this->signed('GET', '/api/control/orders?status=onaylandi,hazir')
            ->assertOk()
            ->assertJsonPath('meta.total', 1);
    }

    public function test_csv_disa_aktarim_BOM_ve_turkce_baslik_tasir(): void
    {
        $this->confirmedOrder();

        $response = $this->signed('GET', '/api/control/orders/export')->assertOk();

        $content = (string) $response->getContent();

        // BOM OLMADAN Excel Türkçe karakterleri bozar ve dosyayı açan
        // muhasebeci "ğ" yerine kutu görür.
        $this->assertStringStartsWith("\u{FEFF}", $content);
        $this->assertStringContainsString('"siparis_no","servis_gunu"', $content);
        $this->assertStringContainsString("\r\n", $content);
        $this->assertSame('false', $response->headers->get('X-Truncated'));
        $this->assertSame('1', $response->headers->get('X-Total-Rows'));
        $this->assertStringContainsString('text/csv', (string) $response->headers->get('Content-Type'));
    }

    public function test_iptal_STOK_SERBEST_BIRAKIR_ve_denetime_yazar(): void
    {
        $order = $this->confirmedOrder(quantity: 4);

        $response = $this->signed(
            'POST',
            '/api/control/orders/'.$order->order_id.'/cancel',
            $this->intent(),
        )->assertOk();

        // İPTALİN EN ÖNEMLİ YAN ETKİSİ: o kadar porsiyon yeniden
        // satılabilir hâle geliyor. Ekran göstermezse yönetici "neden
        // birden 4 yer açıldı" diye sorar.
        $response->assertJsonPath('data.stock_released.day', 4)
            ->assertJsonPath('data.stock_released.items.0.quantity', 4)
            ->assertJsonPath('order.status', OrderStatusTransition::CANCELLED);

        $this->assertSame('order.cancel', ControlAudit::firstOrFail()->action);
    }

    public function test_ZATEN_IPTAL_EDILMIS_siparis_409_doner(): void
    {
        $order = $this->confirmedOrder();

        $this->signed('POST', '/api/control/orders/'.$order->order_id.'/cancel', $this->intent())
            ->assertOk();

        $this->signed('POST', '/api/control/orders/'.$order->order_id.'/cancel', $this->intent())
            ->assertStatus(409)
            ->assertJsonPath('error.code', 'CONFLICT');
    }

    public function test_TESLIM_EDILMIS_siparis_iptal_edilemez(): void
    {
        // Teslim edilmiş bir siparişi iptal etmek, olmuş bir şeyi olmamış
        // saymaktır; iade gerekiyorsa revizyon yolu kullanılır.
        $order = $this->confirmedOrder();
        $this->advance((int) $order->order_id, [
            OrderStatusTransition::PREPARING,
            OrderStatusTransition::READY,
            OrderStatusTransition::ON_THE_WAY,
            OrderStatusTransition::DELIVERED,
        ]);

        $this->signed('POST', '/api/control/orders/'.$order->order_id.'/cancel', $this->intent())
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'INVALID_TRANSITION');
    }

    public function test_durum_yaniti_GERI_ALMA_PENCERESINI_yuzeye_cikarir(): void
    {
        // Ekran kendi 120 saniyesini saymamalı: saati kaymış bir istemci
        // ya kapıyı erken kapatır ya da kapanmış bir kapıyı açık gösterip
        // kullanıcıya 422 aldırır.
        $order = $this->confirmedOrder();

        $response = $this->signed(
            'POST',
            '/api/control/orders/'.$order->order_id.'/status',
            $this->intent(['status' => OrderStatusTransition::PREPARING]),
        )->assertOk();

        $response->assertJsonPath('transitions.current', OrderStatusTransition::PREPARING)
            ->assertJsonPath('transitions.can_undo', true)
            ->assertJsonPath('transitions.undo_to', OrderStatusTransition::CONFIRMED)
            ->assertJsonPath('transitions.undo_window_seconds', 120);

        $this->assertNotNull($response->json('transitions.undo_until'));
    }

    public function test_siparis_detayi_tutar_odeme_ve_fatura_tasir(): void
    {
        $order = $this->confirmedOrder();

        $this->signed('GET', '/api/control/orders/'.$order->order_id)
            ->assertOk()
            ->assertJsonPath('data.editable', true)
            ->assertJsonPath('data.not_editable_reason', null)
            ->assertJsonPath('data.totals.currency', 'TRY')
            ->assertJsonPath('data.payment.status', 'pending')
            ->assertJsonPath('data.invoice.id', null);
    }

    public function test_FATURASIZ_SIPARISTE_fatura_ucu_404_doner(): void
    {
        $order = $this->confirmedOrder();

        $this->signed('GET', '/api/control/orders/'.$order->order_id.'/invoice')
            ->assertStatus(404)
            ->assertJsonPath('error.code', 'NOT_FOUND');
    }

    public function test_ESKI_KDS_YOLU_AYNEN_calismaya_devam_eder(): void
    {
        // Yeni ev açılırken eski yol silinseydi Kontrol Merkezi'nin
        // `bld_kds` modülü kırılırdı. İki yol da yayında.
        $order = $this->confirmedOrder();

        $this->signed('GET', '/api/control/kds/orders/'.$order->order_id)
            ->assertOk()
            ->assertJsonPath('data.id', (int) $order->order_id);

        $this->signed('GET', '/api/control/orders/'.$order->order_id)
            ->assertOk()
            ->assertJsonPath('data.id', (int) $order->order_id);
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    /** @return array<string, mixed> */
    private function sales(): array
    {
        return $this->signed('GET', '/api/control/settings/sales')->assertOk()->json('data');
    }

    /**
     * İmzalı istek — `ControlKdsTest::signed()` ile aynı kanonik dize.
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
            // Sorgu dizesi imzaya GİRMEZ — ara katman `getPathInfo()`
            // okuyor ve iki taraf sorgu sırasını tutturamazdı.
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
     * Gövdeye zorunlu `actor` + `reason` alanlarını ekler.
     *
     * @param  array<string, mixed>  $extra
     * @return array<string, mixed>
     */
    private function intent(array $extra = []): array
    {
        return ['actor' => self::ACTOR, 'reason' => self::REASON, ...$extra];
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
