<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Order;
use Illuminate\Support\Facades\Schema;
use Illuminate\Testing\TestResponse;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Models\ControlAudit;
use Veykemtu\BridgeApi\Models\SiteContent;
use Veykemtu\BridgeApi\Models\SitePost;
use Veykemtu\BridgeApi\Models\SmsTemplate;
use Veykemtu\BridgeApi\Models\SiteService;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;

/**
 * Kontrol paneli ALANLARI — `docs/control/{invoices,cms,sms,notifications,
 * monitor,audit,dashboard}.md`.
 *
 * `ControlPanelTest` menü/ürün/ayar/sipariş ailesini sınıyor; bu dosya onun
 * yanına gelen yedi alanı sınıyor. Kopya değil, dört soru soruyor:
 *
 * 1. **Kapı yeni önekte de duruyor mu?** Yeni bir rota grubu, imza ara
 *    katmanını yanlışlıkla dışarıda bırakmanın en kolay yoludur — testi bu
 *    yüzden her önek için tekrarlanıyor.
 * 2. **Kabuk aynı mı?** Sözleşme "bir uç `write()` kullanmıyorsa o uç
 *    sözleşmeye aykırıdır" diyor (`00-genel.md` §4). Gerekçe zorunluluğu,
 *    kuru prova ve denetim satırı sınanarak bu doğrulanıyor.
 * 3. **Rota adı ile metot adı tutuyor mu?** Ayrışma ne açılışta ne
 *    `route:list`'te hata veriyor; yalnız uç çağrılınca patlıyor. Her alanın
 *    her ucu bu dosyada en az bir kez çağrılıyor.
 * 4. **Tablosu henüz açılmamış alan paneli düşürüyor mu?** Fatura, SMS
 *    kaydı, duyuru ve izleme olayları başka kulvarlarda açılıyor; okumaları
 *    o tablolar olmadan da tutarlı cevap vermeli.
 *
 * Sır ortamdan okunuyor, test için sabitleniyor (`ControlPanelTest` deseni).
 */
class ControlAreasTest extends KitchenTestCase
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

    // ── 1. Kapı ───────────────────────────────────────────────────────────

    public function test_IMZASIZ_alan_istegi_401_doner(): void
    {
        foreach ([
            '/api/control/cms/content',
            '/api/control/sms/templates',
            '/api/control/notifications',
            '/api/control/monitor/summary',
            '/api/control/invoices',
            '/api/control/audit',
            '/api/control/dashboard/overview',
        ] as $path) {
            $this->getJson($path, ['Accept' => 'application/json'])
                ->assertStatus(401)
                ->assertJsonPath('error.code', 'UNAUTHENTICATED');
        }
    }

    public function test_AYNI_NONCE_IKINCI_KEZ_reddedilir(): void
    {
        // TEKRAR SALDIRISI. Pencere tek başına yetmez: pencere içinde aynı
        // isteği ikinci kez oynatmak hâlâ mümkün olurdu ve "duyuruyu gönder"
        // isteğinin tekrarı, müşteriye ikinci bir SMS demekti.
        $nonce = bin2hex(random_bytes(12));

        $this->signed('GET', '/api/control/cms/content', nonce: $nonce)->assertOk();
        $this->signed('GET', '/api/control/cms/content', nonce: $nonce)->assertStatus(401);
    }

    public function test_alan_uclari_PANEL_KOVASINI_kullanir(): void
    {
        // Kovalar ayrı olmasaydı paneldeki bir yoklama patlaması mutfağın
        // kasa yönetimini kilitlerdi (`00-genel.md` §2).
        $response = $this->signed('GET', '/api/control/audit')->assertOk();

        $this->assertSame('3000', $response->headers->get('X-RateLimit-Limit'));
    }

    // ── 2. Kabuk: gerekçe, kuru prova, denetim sonucu ─────────────────────

    public function test_GEREKCESIZ_YAZMA_422_VE_DENETIM_SATIRI_YOK(): void
    {
        // GEÇERLİ BİR İSTEK HİÇ OLUŞMADI: `write()` önce gerekçeyi
        // doğruluyor, denetim satırını sonra açıyor.
        $this->signed('PUT', '/api/control/cms/content/contact', [
            'actor' => self::ACTOR,
            'value' => ['phone' => '3124445566'],
        ])->assertStatus(422)->assertJsonPath('error.code', 'VALIDATION_FAILED');

        $this->assertSame(0, ControlAudit::count());
        $this->assertNull(SiteContent::find('contact'));
    }

    public function test_AKTORSUZ_YAZMA_reddedilir(): void
    {
        $this->signed('POST', '/api/control/cms/revalidate', [
            'reason' => self::REASON,
        ])->assertStatus(422);

        $this->assertSame(0, ControlAudit::count());
    }

    public function test_KURU_PROVA_ICERIGI_YAZMAZ_ama_denetim_birakir(): void
    {
        $this->signed('PUT', '/api/control/cms/content/contact', $this->intent([
            'value' => ['phone' => '3124445566'],
            'dry_run' => true,
        ]))->assertOk()
            ->assertJsonPath('dry_run', true)
            ->assertJsonPath('would.action', 'cms.content.update')
            ->assertJsonPath('would.key', 'contact');

        $this->assertNull(SiteContent::find('contact'), 'Kuru prova içeriği yazmamalı.');

        $audit = ControlAudit::firstOrFail();
        $this->assertSame(ControlAudit::RESULT_DRY_RUN, $audit->result);
        $this->assertSame('cms.content.update', $audit->action);
    }

    public function test_BASARILI_YAZMA_applied_isaretlenir(): void
    {
        $this->signed('PUT', '/api/control/cms/content/contact', $this->intent([
            'value' => ['phone' => '3124445566', 'email' => 'info@bld.example'],
        ]))->assertOk()
            ->assertJsonPath('ok', true)
            ->assertJsonPath('data.key', 'contact');

        $this->assertSame(
            '3124445566',
            SiteContent::findOrFail('contact')->value['phone'],
        );

        $audit = ControlAudit::firstOrFail();
        $this->assertSame(ControlAudit::RESULT_APPLIED, $audit->result);
        $this->assertSame(ControlAudit::TARGET_SITE_CONTENT, $audit->target_type);
        // `target_id` YOK: birincil anahtar metin, anahtar yükte.
        $this->assertNull($audit->target_id);
        $this->assertSame('contact', $audit->payload_json['key']);
    }

    public function test_ON_DENETIM_KURU_PROVADA_DA_kosar(): void
    {
        // "Kuru prova geçti" diyen bir ekran gerçek gönderimde patlamamalı
        // (`00-genel.md` §3.1). Çakışan bir `slug` kuru provada da 409
        // vermeli ve denetim satırı AÇILMAMALI — `write()` kabuğuna hiç
        // girilmedi, çünkü ön denetim ondan önce koşuyor.
        $this->signed('POST', '/api/control/cms/services', $this->intent($this->servicePayload()))
            ->assertOk();

        $this->assertSame(1, ControlAudit::count());

        $this->signed('POST', '/api/control/cms/services', $this->intent(
            $this->servicePayload(['dry_run' => true]),
        ))->assertStatus(409)->assertJsonPath('error.details.conflict', 'slug');

        $this->assertSame(1, ControlAudit::count(), 'Ön denetimde düşen prova iz bırakmamalı.');
    }

    // ── 3. CMS ────────────────────────────────────────────────────────────

    public function test_icerik_KAYDI_OLMAYAN_ANAHTARI_DA_dondurur(): void
    {
        // Eksik anahtarı atlamak, panelin "bu alan yok mu, yoksa boş mu"
        // sorusunu kendi cevaplamasını gerektirirdi.
        $response = $this->signed('GET', '/api/control/cms/content')->assertOk();

        $this->assertSame(SiteContent::KEYS, $response->json('meta.keys'));

        foreach (SiteContent::KEYS as $key) {
            $this->assertArrayHasKey($key, $response->json('data'));
        }
    }

    public function test_BILINMEYEN_icerik_anahtari_404(): void
    {
        // Anahtarlar sabit; uydurulan bir anahtar hiçbir yerde görünmeyen
        // bir kayıt olurdu.
        $this->signed('PUT', '/api/control/cms/content/uydurma', $this->intent([
            'value' => [],
        ]))->assertStatus(404)->assertJsonPath('error.code', 'NOT_FOUND');

        $this->assertSame(0, ControlAudit::count());
    }

    public function test_hizmet_olusturulur_ve_AYNI_SLUG_409_doner(): void
    {
        $body = $this->intent($this->servicePayload());

        $this->signed('POST', '/api/control/cms/services', $body)
            ->assertOk()
            ->assertJsonPath('data.slug', 'etkinlik-catering')
            ->assertJsonPath('data.is_published', false);

        $this->signed('POST', '/api/control/cms/services', $body)
            ->assertStatus(409)
            ->assertJsonPath('error.code', 'CONFLICT')
            ->assertJsonPath('error.details.conflict', 'slug');

        $this->assertSame(1, SiteService::count());
    }

    public function test_hizmet_govdesi_KAYIT_ANINDA_temizlenir(): void
    {
        // İkinci bir temizleyici EKLENMEDİ: temizlik modelin mutator'ında ve
        // içeriğin nereden geldiği fark etmiyor. Yanıt temizlenmiş hâli
        // döndürmezse, editör yaptığı yapıştırmanın kaybolduğunu fark etmez.
        $response = $this->signed('POST', '/api/control/cms/services', $this->intent(
            $this->servicePayload(['body_html' => '<p>Merhaba</p><script>alert(1)</script>']),
        ))->assertOk();

        $html = (string) $response->json('data.body_html');

        $this->assertStringNotContainsString('<script', $html);
        $this->assertStringContainsString('Merhaba', $html);
    }

    public function test_SLUG_DEGISIMI_uyari_uretir(): void
    {
        $this->signed('POST', '/api/control/cms/services', $this->intent($this->servicePayload()))
            ->assertOk();

        $id = (int) SiteService::firstOrFail()->id;

        $response = $this->signed('PATCH', '/api/control/cms/services/'.$id, $this->intent([
            'slug' => 'etkinlik-yemek',
        ]))->assertOk();

        $this->assertSame('slug_changed', $response->json('warnings.0.code'));
        $this->assertSame('etkinlik-catering', $response->json('warnings.0.from'));
    }

    public function test_hizmet_silinir_ve_OLMAYAN_KAYIT_404(): void
    {
        $this->signed('POST', '/api/control/cms/services', $this->intent($this->servicePayload()))
            ->assertOk();

        $id = (int) SiteService::firstOrFail()->id;

        $this->signed('DELETE', '/api/control/cms/services/'.$id, $this->intent())
            ->assertOk()
            ->assertJsonPath('data.deleted', true);

        $this->assertSame(0, SiteService::count());

        $this->signed('DELETE', '/api/control/cms/services/'.$id, $this->intent())
            ->assertStatus(404);
    }

    public function test_yazi_listesi_SAYFALI_ve_kategori_sozlugu_tasir(): void
    {
        $this->signed('POST', '/api/control/cms/posts', $this->intent($this->postPayload()))
            ->assertOk()
            ->assertJsonPath('data.slug', 'soguk-zincir')
            // İkisi ayrı: panel "hesaplandı" ipucunu ancak elle girilenin
            // boş olduğunu görerek gösterebilir.
            ->assertJsonPath('data.reading_minutes', null);

        $response = $this->signed('GET', '/api/control/cms/posts?per_page=10')->assertOk();

        $response->assertJsonPath('meta.per_page', 10)
            ->assertJsonPath('meta.total', 1)
            ->assertJsonPath('meta.categories', ['gida-guvenligi']);

        $this->assertGreaterThanOrEqual(1, (int) $response->json('data.0.reading_minutes_effective'));
        $this->assertSame(1, SitePost::count());
    }

    public function test_BOS_GOVDELI_yazi_reddedilir(): void
    {
        // Boş gövdeli bir yazı, sitede başlığı olan boş bir sayfa üretirdi.
        $this->signed('POST', '/api/control/cms/posts', $this->intent($this->postPayload([
            'body_html' => '',
        ])))->assertStatus(422);
    }

    public function test_yazi_guncellenir_ve_silinir(): void
    {
        $this->signed('POST', '/api/control/cms/posts', $this->intent($this->postPayload()))->assertOk();

        $id = (int) SitePost::firstOrFail()->id;

        $this->signed('PATCH', '/api/control/cms/posts/'.$id, $this->intent([
            'title' => 'Soğuk zincir nasıl korunur?',
            'reading_minutes' => 6,
        ]))->assertOk()
            ->assertJsonPath('data.title', 'Soğuk zincir nasıl korunur?')
            // Elle girilen değer kazanır: bazen yazının ağırlığı kelime
            // sayısıyla ölçülmez.
            ->assertJsonPath('data.reading_minutes_effective', 6);

        $this->signed('DELETE', '/api/control/cms/posts/'.$id, $this->intent())
            ->assertOk()
            ->assertJsonPath('data.deleted', true);

        $this->assertSame(0, SitePost::count());
    }

    public function test_revalidate_ICERIK_YAZILMADAN_da_calisir(): void
    {
        $this->signed('POST', '/api/control/cms/revalidate', $this->intent(['paths' => ['/hizmetler']]))
            ->assertOk()
            ->assertJsonPath('data.status', 'ok')
            ->assertJsonPath('data.requested', ['/hizmetler']);

        $this->assertSame('cms.revalidate', ControlAudit::firstOrFail()->action);
    }

    // ── 4. SMS ────────────────────────────────────────────────────────────

    public function test_sablon_listesi_TUM_ANAHTARLARI_ve_surucuyu_bildirir(): void
    {
        $response = $this->signed('GET', '/api/control/sms/templates')->assertOk();

        $keys = array_column((array) $response->json('data'), 'key');

        $this->assertContains('order_created', $keys);
        $this->assertContains('announcement', $keys);
        // `otp_login` BU LİSTEDE YOK VE OLMAYACAK: kimlik doğrulama metni
        // yönetim yüzeyinden uzak durur.
        $this->assertNotContains('otp_login', $keys);

        // Sağlayıcı sırrı testte tanımsız; panel bunu açıkça göstermeli.
        $response->assertJsonPath('meta.sender_configured', false)
            ->assertJsonPath('meta.sender_driver', 'log');
    }

    public function test_onizleme_COZULEMEYEN_degiskeni_oldugu_gibi_birakir(): void
    {
        // Sessizce boşaltılan bir değişken, müşteriye "Sayın , siparişiniz…"
        // diye giden bir SMS üretirdi.
        $response = $this->signed('POST', '/api/control/sms/templates/order_created/preview', $this->intent([
            'body' => 'Sayın {customer_name}, siparişiniz {service_date} günü hazır.',
            'sample' => ['customer_name' => 'Mehmet Kaya'],
        ]))->assertOk();

        $this->assertStringContainsString('Mehmet Kaya', (string) $response->json('data.rendered'));
        $this->assertStringContainsString('{service_date}', (string) $response->json('data.rendered'));
        $this->assertSame(['service_date'], $response->json('data.unresolved_variables'));
        // Türkçe karakter var → UCS-2, tek segment 70 karakter.
        $this->assertSame('ucs2', $response->json('data.encoding'));

        $this->assertSame('sms.template.preview', ControlAudit::firstOrFail()->action);
    }

    public function test_sablon_metni_guncellenir_ve_TANINMAYAN_DEGISKEN_reddedilir(): void
    {
        // Sessizce boş bırakılan bir değişken, müşteriye "Sayın ,
        // siparişiniz…" diye giden bir SMS üretirdi.
        $this->signed('PATCH', '/api/control/sms/templates/order_confirmed', $this->intent([
            'body' => 'Sayın {musteri_adi}, siparişiniz onaylandı.',
        ]))->assertStatus(422)
            ->assertJsonPath('error.details.unknown_variables', ['musteri_adi']);

        $response = $this->signed('PATCH', '/api/control/sms/templates/order_confirmed', $this->intent([
            'body' => '{order_no} numaralı siparişiniz onaylandı. Servis: {service_date}.',
            'enabled' => true,
        ]))->assertOk();

        $response->assertJsonPath('data.key', 'order_confirmed')
            ->assertJsonPath('data.enabled', true);

        $this->assertTrue(SmsTemplate::findByKey('order_confirmed')?->enabled);

        // `payload_json` METNİN TAMAMINI YAZMAZ — denetim izi "ne değişti"yi
        // anlatmalı, SMS gövdelerinin ikinci bir arşivi olmamalı.
        $payload = ControlAudit::firstOrFail()->payload_json;

        $this->assertSame('order_confirmed', $payload['key']);
        $this->assertArrayNotHasKey('body', $payload);
    }

    public function test_BILINMEYEN_sablon_anahtari_404(): void
    {
        $this->signed('POST', '/api/control/sms/templates/otp_login/preview', $this->intent())
            ->assertStatus(404);
    }

    public function test_deneme_SMSI_DENEME_onekiyle_gider(): void
    {
        $response = $this->signed('POST', '/api/control/sms/send-test', $this->intent([
            'phone' => '5321234567',
            'body' => 'Deneme mesajı',
        ]))->assertOk();

        // ÖNEK KALDIRILAMAZ: deneme SMS'inin gerçek bir bildirimden ayırt
        // edilememesi, yanlış numaraya giden bir mesajın müşteride panik
        // yaratması demekti.
        $this->assertStringStartsWith('[DENEME]', (string) $response->json('data.rendered'));
        $this->assertSame('sent', $response->json('data.status'));
        // DENETİME MASKELİ NUMARA yazılır.
        $this->assertSame('532****567', ControlAudit::firstOrFail()->payload_json['phone']);
    }

    public function test_deneme_SMSINDE_sablon_ve_metin_BIRLIKTE_reddedilir(): void
    {
        $this->signed('POST', '/api/control/sms/send-test', $this->intent([
            'phone' => '5321234567',
            'template_key' => 'order_created',
            'body' => 'Serbest metin',
        ]))->assertStatus(422);

        $this->signed('POST', '/api/control/sms/send-test', $this->intent([
            'phone' => '5321234567',
        ]))->assertStatus(422);
    }

    public function test_GECERSIZ_numara_reddedilir(): void
    {
        $this->signed('POST', '/api/control/sms/send-test', $this->intent([
            'phone' => '05321234567',
            'body' => 'Deneme',
        ]))->assertStatus(422);
    }

    public function test_duyuru_taslagi_yazilir_ve_TAHMIN_her_okumada_hesaplanir(): void
    {
        $this->signed('PUT', '/api/control/sms/announcement', $this->intent([
            'body' => 'Değerli müşterimiz, 30 Ağustos\'ta hizmet veremeyeceğiz.',
            'audience' => 'all_customers',
        ]))->assertOk()->assertJsonPath('data.audience', 'all_customers');

        $response = $this->signed('GET', '/api/control/sms/announcement')->assertOk();

        $response->assertJsonPath('data.audience', 'all_customers')
            ->assertJsonPath('data.last_run_at', null);

        $this->assertIsInt($response->json('data.estimate.recipients'));
    }

    public function test_duyuruda_ONAY_SAYISI_TUTMAZSA_409(): void
    {
        $this->signed('PUT', '/api/control/sms/announcement', $this->intent([
            'body' => 'Deneme duyurusu metni.',
            'audience' => 'all_customers',
        ]))->assertOk();

        // Yönetici ekranda gördüğü sayıyı onaylıyor; arada müşteri
        // eklendiyse gönderim sessizce büyümemeli.
        $this->signed('POST', '/api/control/sms/announcement/run', $this->intent([
            'confirm_recipients' => 9999,
        ]))->assertStatus(409)
            ->assertJsonPath('error.details.conflict', 'recipient_count');
    }

    public function test_duyuru_gonderilir_ve_ON_DAKIKA_beklemeden_ikincisi_409(): void
    {
        $this->signed('PUT', '/api/control/sms/announcement', $this->intent([
            'body' => 'Deneme duyurusu metni.',
            'audience' => 'all_customers',
        ]))->assertOk();

        $count = (int) $this->signed('GET', '/api/control/sms/announcement')
            ->assertOk()->json('data.estimate.recipients');

        $this->signed('POST', '/api/control/sms/announcement/run', $this->intent([
            'confirm_recipients' => $count,
        ]))->assertOk()->assertJsonPath('data.recipients', $count);

        // ÇİFT TIKLAMA ile aynı duyuruyu iki kez almak, müşterinin gördüğü
        // tek şeydir.
        $this->signed('POST', '/api/control/sms/announcement/run', $this->intent([
            'confirm_recipients' => $count,
        ]))->assertStatus(409)
            ->assertJsonPath('error.details.conflict', 'cooldown');
    }

    public function test_BOS_duyuru_gonderilemez(): void
    {
        $this->signed('POST', '/api/control/sms/announcement/run', $this->intent([
            'confirm_recipients' => 0,
        ]))->assertStatus(422);
    }

    public function test_sms_kaydi_TABLO_YOKKEN_da_tutarli_doner(): void
    {
        // Tablo başka bir kulvarda açılıyor; yoklanan bir ekran onun
        // yokluğunda `500` görmemeli — sayfalayıcı dörtlüsü ve maliyet
        // sayaçları her hâlde dolu gelmeli.
        $this->signed('GET', '/api/control/sms/log')
            ->assertOk()
            ->assertJsonStructure([
                'data',
                'meta' => ['page', 'per_page', 'total', 'last_page', 'sent_count', 'failed_count', 'segment_total'],
                'server_time',
            ])
            ->assertJsonPath('meta.page', 1);
    }

    // ── 5. Duyurular ──────────────────────────────────────────────────────

    public function test_duyuru_listesi_TABLO_YOKKEN_da_tutarli_doner(): void
    {
        $this->signed('GET', '/api/control/notifications')
            ->assertOk()
            ->assertJsonStructure([
                'data',
                'meta' => ['page', 'per_page', 'total', 'last_page', 'live_count'],
                'server_time',
            ])
            ->assertJsonPath('meta.page', 1);
    }

    public function test_duyuru_TASLAK_dogar_ve_yayinlanir(): void
    {
        $this->skipUnlessTable('veykemtu_announcements');

        $created = $this->signed('POST', '/api/control/notifications', $this->intent([
            'title' => '30 Ağustos\'ta kapalıyız',
            'body' => 'Zafer Bayramı nedeniyle üretim yapılmayacaktır.',
            'level' => 'warning',
            'audience' => 'subscribers',
        ]))->assertOk();

        // HER ZAMAN `draft` DOĞAR; yayın ayrı bir eylemdir.
        $created->assertJsonPath('data.status', 'draft')
            ->assertJsonPath('data.live', false);

        $id = (int) $created->json('data.id');

        $this->signed('POST', '/api/control/notifications/'.$id.'/publish', $this->intent())
            ->assertOk()
            ->assertJsonPath('data.status', 'published')
            ->assertJsonPath('data.live', true);

        // İkinci yayın çakışır: `unpublish` ucu yok ve yayından kaldırmanın
        // tek yolu arşiv ya da `ends_at`.
        $this->signed('POST', '/api/control/notifications/'.$id.'/publish', $this->intent())
            ->assertStatus(409);

        // YAYINLANMIŞ DUYURU DÜZENLENEBİLİR (yazım hatası, tarih uzatma)
        // ama kitle değişimi uyarı üretir.
        $patched = $this->signed('PATCH', '/api/control/notifications/'.$id, $this->intent([
            'audience' => 'all',
        ]))->assertOk();

        $this->assertSame('audience_changed_after_publish', $patched->json('warnings.0.code'));

        // `all` ÖLÇÜLEMEZ: giriş yapmamış ziyaretçinin kimliği yok.
        // `seen_count` SIFIR DEĞİL `null` — sıfır "kimse görmedi" demektir.
        $this->signed('GET', '/api/control/notifications/'.$id.'/stats')
            ->assertOk()
            ->assertJsonPath('data.trackable', false)
            ->assertJsonPath('data.seen_count', null)
            ->assertJsonPath('data.daily', null);

        $this->signed('DELETE', '/api/control/notifications/'.$id, $this->intent())
            ->assertOk()
            ->assertJsonPath('data.status', 'archived');
    }

    public function test_KAPATILAMAYAN_duyuru_yalniz_kritik_olabilir(): void
    {
        $this->skipUnlessTable('veykemtu_announcements');

        // Kapatılamayan bir bilgilendirme, uygulamayı kullanılamaz hâle
        // getirir.
        $this->signed('POST', '/api/control/notifications', $this->intent([
            'title' => 'Bilgi',
            'body' => 'Kapatılamayan bilgilendirme',
            'level' => 'info',
            'audience' => 'all',
            'dismissible' => false,
        ]))->assertStatus(422);
    }

    public function test_GUVENSIZ_dugme_adresi_reddedilir(): void
    {
        $this->skipUnlessTable('veykemtu_announcements');

        foreach (['http://ornek.com', 'javascript:alert(1)', '//ornek.com'] as $url) {
            $this->signed('POST', '/api/control/notifications', $this->intent([
                'title' => 'Duyuru',
                'body' => 'Gövde',
                'level' => 'info',
                'audience' => 'all',
                'action_label' => 'Aç',
                'action_url' => $url,
            ]))->assertStatus(422);
        }
    }

    // ── 6. İzleme ─────────────────────────────────────────────────────────

    public function test_izleme_cihaz_listesi_UC_DURUMLU_alanlari_korur(): void
    {
        $device = $this->pairedDevice()['model'];

        $response = $this->signed('GET', '/api/control/monitor/devices')->assertOk();

        $row = collect((array) $response->json('data'))
            ->firstWhere('device_id', (int) $device->id);

        $this->assertNotNull($row);
        // `null` "bilinmiyor" demektir, `false` değil. Sağlık bildirmemiş
        // bir kasa arızalı sayılmaz.
        $this->assertNull($row['printer_ok']);
        $this->assertFalse($row['revoked']);
        $this->assertSame(0, $response->json('meta.printer_fault'));
    }

    public function test_izleme_ozeti_HUKMU_sunucudan_verir(): void
    {
        $response = $this->signed('GET', '/api/control/monitor/summary')->assertOk();

        $response->assertJsonStructure([
            'data' => [
                'events' => ['open', 'open_total', 'critical_open', 'last_24h', 'oldest_open_at', 'by_source'],
                'devices' => ['total', 'online', 'revoked', 'printer_fault', 'queue_pending', 'queue_failed'],
                'health' => ['status', 'reasons'],
            ],
            'server_time',
        ]);

        $this->assertContains($response->json('data.health.status'), ['ok', 'degraded', 'down']);
    }

    public function test_izleme_olaylari_TABLO_YOKKEN_da_tutarli_doner(): void
    {
        $this->signed('GET', '/api/control/monitor/events')
            ->assertOk()
            ->assertJsonStructure([
                'data',
                'meta' => ['page', 'per_page', 'total', 'last_page', 'open_counts'],
                'server_time',
            ]);
    }

    public function test_OLMAYAN_olay_404(): void
    {
        $this->signed('GET', '/api/control/monitor/events/99999')->assertStatus(404);

        $this->signed('POST', '/api/control/monitor/events/99999/resolve', $this->intent())
            ->assertStatus(404);

        // Var olmayan bir kayda yazma denemesi denetime düşmez: `write()`
        // kabuğuna hiç girilmedi.
        $this->assertSame(0, ControlAudit::count());
    }

    // ── 7. Fatura ─────────────────────────────────────────────────────────

    public function test_fatura_listesi_TABLO_YOKKEN_da_tutarli_doner(): void
    {
        $this->signed('GET', '/api/control/invoices')
            ->assertOk()
            ->assertJsonStructure([
                'data',
                'meta' => ['page', 'per_page', 'total', 'last_page', 'issued_total_kurus'],
                'server_time',
            ]);
    }

    public function test_fatura_kipi_SECILMELI(): void
    {
        $this->skipUnlessTable('veykemtu_invoices');

        // İkisi birden ya da hiçbiri → 422.
        $this->signed('POST', '/api/control/invoices', $this->intent([
            'order_id' => 1,
            'subscription_id' => 1,
        ]))->assertStatus(422);

        $this->signed('POST', '/api/control/invoices', $this->intent())->assertStatus(422);
    }

    public function test_siparis_belgesi_kesilir_IKINCISI_409_ve_iptal_edilir(): void
    {
        $this->skipUnlessTable('veykemtu_invoices');

        $order = $this->confirmedOrder();
        $body = $this->intent(['order_id' => (int) $order->order_id]);

        $created = $this->signed('POST', '/api/control/invoices', $body)->assertOk();

        $created->assertJsonPath('data.status', 'issued')
            ->assertJsonPath('ok', true);

        $id = (int) $created->json('data.id');
        $no = (string) $created->json('data.invoice_no');

        // Numara boşluksuz ve yıl önekli: `BLD-2026-000001`.
        $this->assertMatchesRegularExpression('/^BLD-\d{4}-\d{6}$/', $no);

        // İKİNCİ BELGE YOK: önce eskisi iptal edilir, yoksa müşterinin
        // elinde aynı hizmetin iki belgesi olur.
        $this->signed('POST', '/api/control/invoices', $body)
            ->assertStatus(409)
            ->assertJsonPath('error.details.conflict', 'existing_invoice')
            ->assertJsonPath('error.details.invoice_no', $no);

        // Yazdırılabilir belge JSON DEĞİL.
        $html = $this->signed('GET', '/api/control/invoices/'.$id.'/html')->assertOk();

        $this->assertStringContainsString('text/html', (string) $html->headers->get('Content-Type'));
        $this->assertStringContainsString(
            'Bu belge bilgilendirme amaçlıdır, mali değeri yoktur.',
            (string) $html->getContent(),
        );
        // Laravel başlığa `private` ekliyor; aranan şey `no-store`'un
        // varlığı — belge kişisel veri taşıyor ve ara önbellekte kalmamalı.
        $this->assertStringContainsString('no-store', (string) $html->headers->get('Cache-Control'));

        $this->signed('POST', '/api/control/invoices/'.$id.'/void', $this->intent())
            ->assertOk()
            ->assertJsonPath('data.status', 'void')
            // `void_reason` ORTAK `reason` metnidir; ayrı bir alan istenmez.
            ->assertJsonPath('data.void_reason', self::REASON);

        // İptal edilmiş numara SERBEST KALMAZ; listede `void` olarak durur.
        $this->signed('GET', '/api/control/invoices')
            ->assertOk()
            ->assertJsonPath('meta.total', 1)
            ->assertJsonPath('data.0.status', 'void')
            ->assertJsonPath('meta.issued_total_kurus', 0);

        $this->signed('POST', '/api/control/invoices/'.$id.'/void', $this->intent())
            ->assertStatus(409);
    }

    public function test_IPTAL_EDILMIS_siparise_belge_kesilemez(): void
    {
        $this->skipUnlessTable('veykemtu_invoices');

        $order = $this->confirmedOrder();

        $this->signed('POST', '/api/control/orders/'.$order->order_id.'/cancel', $this->intent())
            ->assertOk();

        // Olmamış bir hizmetin belgesi olurdu.
        $this->signed('POST', '/api/control/invoices', $this->intent([
            'order_id' => (int) $order->order_id,
        ]))->assertStatus(422)
            ->assertJsonPath('error.details.reason', 'order_cancelled');
    }

    public function test_OLMAYAN_belge_404(): void
    {
        $this->signed('GET', '/api/control/invoices/9999')->assertStatus(404);
        $this->signed('GET', '/api/control/invoices/9999/html')->assertStatus(404);
    }

    // ── 8. Denetim izi ────────────────────────────────────────────────────

    public function test_denetim_listesi_ONEK_SUZGECI_kabul_eder(): void
    {
        $this->signed('PUT', '/api/control/cms/content/brand', $this->intent([
            'value' => ['name' => 'BLD Catering'],
        ]))->assertOk();

        $this->signed('POST', '/api/control/cms/revalidate', $this->intent())->assertOk();

        // Otuz küsur eylem adını tek tek seçtirmek, panelin kullanılamaz bir
        // süzgeç çizmesi demekti.
        $this->signed('GET', '/api/control/audit?action=cms.*')
            ->assertOk()
            ->assertJsonPath('meta.total', 2);

        $this->signed('GET', '/api/control/audit?action=cms.revalidate')
            ->assertOk()
            ->assertJsonPath('meta.total', 1);

        $response = $this->signed('GET', '/api/control/audit')->assertOk();

        // Varsayılan sayfa boyu 50 — sözleşmedeki tek istisna.
        $response->assertJsonPath('meta.per_page', 50)
            ->assertJsonPath('meta.counts_by_result.applied', 2)
            ->assertJsonPath('meta.counts_by_result.pending', 0);

        // Sıra `id` azalan: en son ne yapıldı, en sık sorulan soru.
        $this->assertSame('cms.revalidate', $response->json('data.0.action'));
    }

    public function test_denetim_satiri_TAM_YUKUYLE_okunur(): void
    {
        $this->signed('PUT', '/api/control/cms/content/brand', $this->intent([
            'value' => ['name' => 'BLD Catering'],
        ]))->assertOk();

        $id = (int) ControlAudit::firstOrFail()->id;

        $this->signed('GET', '/api/control/audit/'.$id)
            ->assertOk()
            ->assertJsonPath('data.id', $id)
            ->assertJsonPath('data.payload_truncated', false)
            ->assertJsonPath('data.payload_json.key', 'brand');

        $this->signed('GET', '/api/control/audit/999999')->assertStatus(404);
    }

    public function test_denetim_sozlugu_HIC_KULLANILMAYAN_eylemi_de_dondurur(): void
    {
        $response = $this->signed('GET', '/api/control/audit/actions')->assertOk();

        $rows = collect((array) $response->json('data'));

        $this->assertNotNull($rows->firstWhere('action', 'invoice.void'));
        $this->assertSame(0, $rows->firstWhere('action', 'invoice.void')['count']);
        // Etiket TÜRKÇE ve SUNUCUDAN gelir; panelin kendi çeviri tablosunu
        // tutması, yeni bir eylemde ham `snake_case` ad göstermekle biterdi.
        $this->assertSame('Kişisel veri görüntülendi', $rows->firstWhere('action', 'customer.read')['label']);
        $this->assertContains('monitor', (array) $response->json('meta.groups'));
    }

    public function test_denetim_izinde_YAZMA_UCU_YOKTUR(): void
    {
        // Denetim izini silebilen bir denetim izi, denetim izi değildir.
        foreach ([['POST', '/api/control/audit'], ['DELETE', '/api/control/audit/1']] as [$method, $path]) {
            $response = $this->signed($method, $path, $this->intent());

            $this->assertContains(
                $response->getStatusCode(),
                [404, 405],
                $method.' '.$path.' bir yazma ucu olmamalı.',
            );
        }
    }

    // ── 9. Gösterge paneli ────────────────────────────────────────────────

    public function test_gosterge_paneli_YEDI_BLOGU_tek_istekte_doner(): void
    {
        $response = $this->signed('GET', '/api/control/dashboard/overview')->assertOk();

        $response->assertJsonStructure([
            'data' => [
                'date', 'location_id',
                'sales' => [
                    'ordering_enabled', 'paused_until', 'busy', 'cutoff_time', 'cutoff_at',
                    'cutoff_passed_for_today', 'seconds_to_next_cutoff', 'next_cutoff_date',
                ],
                'orders' => [
                    'by_status', 'active', 'delivered_today', 'cancelled_today',
                    'created_today', 'late', 'revenue_today_kurus', 'unreleased_subscription_orders',
                ],
                'capacity' => [
                    'menu_published', 'capacity_total', 'sold_total', 'sold_orders',
                    'sold_subscriptions', 'remaining_total', 'fill_rate', 'blocked_items',
                ],
                'subscriptions' => [
                    'active', 'pending', 'paused', 'portions_today',
                    'contracts_awaiting_signature', 'unpaid_periods', 'unpaid_total_kurus',
                    'overdue_periods', 'overdue_total_kurus',
                ],
                'devices' => ['total', 'online', 'revoked', 'printer_fault'],
                'monitor' => ['open_total', 'critical_open', 'error_open', 'warning_open', 'health_status'],
                'pending_tasks',
            ],
            'server_time',
        ]);

        // TERMİNAL KODLAR ANAHTAR DEĞİL: her seferinde `0` dönerlerdi.
        $byStatus = (array) $response->json('data.orders.by_status');

        $this->assertArrayHasKey('yeni', $byStatus);
        $this->assertArrayNotHasKey('teslim_edildi', $byStatus);
        $this->assertArrayNotHasKey('iptal', $byStatus);
    }

    public function test_MENU_YAYINLANMAMISSA_kapasite_null_doner(): void
    {
        // `null` ile `0` asla karıştırılmamalı: sıfır "doldu" anlamına
        // gelirdi ve menüsü olmayan bir gün dolu görünürdü.
        $response = $this->signed('GET', '/api/control/dashboard/overview')->assertOk();

        if ($response->json('data.capacity.menu_published') === true) {
            $this->markTestSkipped('Demo kurulumda bugüne yayınlanmış menü var.');
        }

        $response->assertJsonPath('data.capacity.capacity_total', null)
            ->assertJsonPath('data.capacity.sold_total', null)
            ->assertJsonPath('data.capacity.fill_rate', null);
    }

    public function test_gosterge_paneli_izleme_SAYILARI_IZLEME_UCUYLA_ayni(): void
    {
        // İki ekranın aynı duruma bakıp farklı sayı göstermesi, hangisine
        // inanılacağını belirsiz kılardı.
        $this->pairedDevice();

        $summary = $this->signed('GET', '/api/control/monitor/summary')->assertOk()->json('data');
        $dashboard = $this->signed('GET', '/api/control/dashboard/overview')->assertOk()->json('data');

        $this->assertSame($summary['devices']['total'], $dashboard['devices']['total']);
        $this->assertSame($summary['devices']['online'], $dashboard['devices']['online']);
        $this->assertSame($summary['health']['status'], $dashboard['monitor']['health_status']);
        $this->assertSame($summary['events']['open_total'], $dashboard['monitor']['open_total']);
    }

    public function test_SATIS_DURDURULMUSSA_bekleyen_is_listesinde_gorunur(): void
    {
        $this->signed('POST', '/api/control/settings/ordering/pause', $this->intent([
            'until' => null,
            'customer_message' => 'Bugün sipariş alamıyoruz.',
        ]))->assertOk();

        $tasks = (array) $this->signed('GET', '/api/control/dashboard/overview')
            ->assertOk()->json('data.pending_tasks');

        $codes = array_column($tasks, 'code');

        $this->assertContains('ordering_paused', $codes);
        // SIRA: critical → warning → info.
        $this->assertSame('critical', $tasks[0]['level']);
    }

    public function test_gosterge_paneli_OKUMASI_denetlenmez(): void
    {
        // Gösterge paneli 30 saniyede bir yoklanıyor; her yoklamayı
        // denetlemek, izi tamamen bu trafiğe boğardı.
        $this->signed('GET', '/api/control/dashboard/overview')->assertOk();
        $this->signed('GET', '/api/control/audit')->assertOk();
        $this->signed('GET', '/api/control/monitor/summary')->assertOk();

        $this->assertSame(0, ControlAudit::count());
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    /** Belge kesilebilir bir sipariş — `ControlPanelTest` ile aynı kurulum. */
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

    private function skipUnlessTable(string $table): void
    {
        if (!Schema::hasTable($table)) {
            $this->markTestSkipped($table.' tablosu bu kurulumda henüz açılmamış (başka kulvar).');
        }
    }

    /** @return array<string, mixed> */
    private function servicePayload(array $overrides = []): array
    {
        return [
            'slug' => 'etkinlik-catering',
            'title' => 'Etkinlik Catering',
            'summary' => 'Toplantı, açılış ve organizasyonlar için',
            'intro' => 'Anahtar teslim etkinlik yemeği.',
            'icon' => 'PartyPopper',
            'menu_planning' => 'Menü birlikte belirlenir.',
            'audience' => ['Ajanslar'],
            'how_it_works' => ['Brief alınır'],
            'benefits' => ['Anahtar teslim'],
            'quote_needs' => ['Kişi sayısı'],
            'sort_order' => 40,
            'is_published' => false,
            ...$overrides,
        ];
    }

    /** @return array<string, mixed> */
    private function postPayload(array $overrides = []): array
    {
        return [
            'slug' => 'soguk-zincir',
            'title' => 'Toplu yemekte soğuk zincir',
            'description' => 'Taşıma sırasında sıcaklık nasıl korunur?',
            'category' => 'gida-guvenligi',
            'body_html' => '<p>Soğuk zincir, üretimden teslimata kadar kesintisiz sürdürülmelidir.</p>',
            'published_at' => '2026-08-01',
            'is_published' => true,
            ...$overrides,
        ];
    }

    /**
     * İmzalı istek — `ControlPanelTest::signed()` ile aynı kanonik dize.
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
}
