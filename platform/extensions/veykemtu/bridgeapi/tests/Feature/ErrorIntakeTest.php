<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Illuminate\Routing\Middleware\ThrottleRequests;
use Illuminate\Support\Carbon;
use Illuminate\Testing\TestResponse;
use LogicException;
use RuntimeException;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ErrorEvent;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Services\MonitorRecorder;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * İstemci hata bildirimi (`POST /api/client-errors`), KDS aynalaması ve
 * sunucu istisnalarının monitöre yazılması (`Services\MonitorRecorder`).
 *
 * BU PAKET DÖRT SESSİZ FELAKETİ KİLİTLİYOR:
 *
 *   (a) **Tekilleştirmenin çalışmaması.** Bir çökme döngüsü aynı hatayı
 *       dakikada yüzlerce kez üretir. Parmak izi toplaması bozulursa tablo
 *       bir öğleden sonra okunamaz hâle gelir ve yanındaki gerçek — bir kez
 *       olmuş — hata sonsuza dek kaybolur.
 *
 *   (b) **Sahte kaynak.** Gövdeden `source` okunsaydı web sitesi `kds`
 *       yazan bir rapor üretebilir, mutfağın güvendiği monitöre sahte alarm
 *       düşerdi. O monitör sahada "kasada bir sorun var mı" sorusunun tek
 *       cevabı; zehirlendiğinde mutfak kör kalır.
 *
 *   (c) **Reddedilen rapor.** Bu ucun her hata yanıtı, hata bildirmeye
 *       çalışan istemcide İKİNCİ bir hata doğurur ve kendini besleyen bir
 *       döngü açılır. Uzun yığın, bilinmeyen alan, mesajsız gövde — hiçbiri
 *       reddedilmemeli; yanıt her zaman `204`.
 *
 *   (d) **Sessizce kopan sunucu kaynağı.** Monitörün dördüncü kaynağını
 *       besleyen tek yol `reportable()` kancasıdır ve o kanca uzun süre
 *       var olmayan bir sınıfı bekleyen bir `class_exists()` nöbetçisinin
 *       arkasında hiç bağlanmadı: ekran çalışıyor, `source = server` satırı
 *       hiç doğmuyordu. Buradaki testler bağlantının kendisini ölçüyor.
 */
class ErrorIntakeTest extends KitchenTestCase
{
    private const string ENDPOINT = '/api/client-errors';

    /** Aynalama testlerinde AYNI kasayı kullanmak için saklanan belirteç. */
    private ?string $kitchenToken = null;

    protected function tearDown(): void
    {
        Carbon::setTestNow();

        parent::tearDown();
    }

    // ── Tekilleştirme ────────────────────────────────────────────────────

    /**
     * AYNI ÇÖKME İKİ KEZ → TEK SATIR, `occurrences = 2`.
     *
     * `first_seen_at` donuyor ("bu ne zamandır oluyor"), `last_seen_at`
     * ilerliyor ("hâlâ oluyor mu"). İkisi tek kolona indirilseydi üç
     * haftadır süren bir arıza ile beş dakika önce başlayan arıza panelde
     * aynı görünürdü.
     */
    public function test_ayni_cokme_tek_satirda_toplanir(): void
    {
        Carbon::setTestNow(Carbon::parse('2026-09-08 09:00:00'));
        $this->postJson(self::ENDPOINT, $this->payload(), self::HEADERS)->assertNoContent();

        $first = ErrorEvent::firstOrFail();

        Carbon::setTestNow(Carbon::parse('2026-09-08 09:05:00'));
        $this->postJson(self::ENDPOINT, $this->payload(), self::HEADERS)->assertNoContent();

        $this->assertSame(1, ErrorEvent::query()->count(), 'Aynı hata tek satır olmalı.');

        $row = ErrorEvent::firstOrFail();
        $this->assertSame(2, $row->occurrences);
        $this->assertEquals($first->first_seen_at, $row->first_seen_at, '`first_seen_at` donuk kalmalı.');
        $this->assertTrue(
            $row->last_seen_at->greaterThan($first->last_seen_at),
            '`last_seen_at` ilerlemeli.',
        );
    }

    /**
     * Rakamlar parmak izine girmez: "Sipariş 8421 basılamadı" ile "Sipariş
     * 8422 basılamadı" tek hatanın iki tekrarıdır. Girseydi her sipariş
     * kendi satırını açar ve tekilleştirme hiçbir işe yaramazdı.
     */
    public function test_yalniz_sayisi_degisen_mesaj_ayni_satira_dusler(): void
    {
        $this->postJson(self::ENDPOINT, $this->payload([
            'message' => 'Sipariş 8421 basılamadı',
        ]), self::HEADERS)->assertNoContent();

        $this->postJson(self::ENDPOINT, $this->payload([
            'message' => 'Sipariş 8422 basılamadı',
        ]), self::HEADERS)->assertNoContent();

        $this->assertSame(1, ErrorEvent::query()->count());
        $row = ErrorEvent::firstOrFail();
        $this->assertSame(2, $row->occurrences);
        // Mesaj tazeleniyor: yöneticinin görmesi gereken EN SON hangi
        // siparişte olduğudur.
        $this->assertSame('Sipariş 8422 basılamadı', $row->message);
    }

    public function test_farkli_hata_ayri_satir_acar(): void
    {
        $this->postJson(self::ENDPOINT, $this->payload(['message' => 'Sepet çizilemedi']), self::HEADERS);
        $this->postJson(self::ENDPOINT, $this->payload(['message' => 'Menü ayrıştırılamadı']), self::HEADERS);

        $this->assertSame(2, ErrorEvent::query()->count());
    }

    // ── Kaynak sahteciliği ───────────────────────────────────────────────

    /**
     * GÖVDEDEKİ `source` YOK SAYILIR — başlık kazanır.
     *
     * Bu testin kaybı, mutfağın güvendiği monitörün zehirlenebilmesidir.
     */
    public function test_govdedeki_source_yok_sayilir_baslik_kazanir(): void
    {
        $this->postJson(self::ENDPOINT, $this->payload([
            'source' => ErrorEvent::SOURCE_KDS,
        ]), self::HEADERS)->assertNoContent();

        $this->assertSame(ErrorEvent::SOURCE_WEBSITE, ErrorEvent::firstOrFail()->source);
    }

    public function test_musteriapp_basligi_mobile_olarak_saklanir(): void
    {
        $this->postJson(self::ENDPOINT, $this->payload(), [
            'X-App-Id' => 'musteriapp',
            'X-App-Version' => '1.0.0',
            'Accept' => 'application/json',
        ])->assertNoContent();

        $this->assertSame(ErrorEvent::SOURCE_MOBILE, ErrorEvent::firstOrFail()->source);
    }

    // ── Hiçbir şey reddedilmez ───────────────────────────────────────────

    /**
     * 40 KB'lık yığın KESİLİR, reddedilmez.
     *
     * Sekiz kilobaytı aşan bir iz yüzünden raporu geri çevirmek, çöken
     * istemcinin tek kanıtını çöpe atmak olurdu.
     */
    public function test_uzun_yigin_kirpilir_rapor_kaydedilir(): void
    {
        $this->postJson(self::ENDPOINT, $this->payload([
            'stack' => str_repeat('a', 40000),
        ]), self::HEADERS)->assertNoContent();

        $row = ErrorEvent::firstOrFail();
        $this->assertSame(ErrorEvent::STACK_LIMIT, mb_strlen((string) $row->stack));
    }

    public function test_sinirlari_asan_mesaj_kesilir(): void
    {
        $this->postJson(self::ENDPOINT, $this->payload([
            'message' => str_repeat('ç', 900),
        ]), self::HEADERS)->assertNoContent();

        $this->assertSame(
            ErrorEvent::MESSAGE_LIMIT,
            mb_strlen(ErrorEvent::firstOrFail()->message),
        );
    }

    /**
     * Mesajsız gövde `204` alır ama satır AÇMAZ.
     *
     * Reddetmek sözleşmenin "yanıt her zaman 204" kuralını çiğner ve
     * istemcide ikinci bir hata doğururdu; kaydetmek ise monitörü hiçbir
     * şey anlatmayan boş satırlarla doldururdu.
     */
    public function test_mesajsiz_rapor_kaydedilmez_ama_204_doner(): void
    {
        $this->postJson(self::ENDPOINT, ['kind' => 'render'], self::HEADERS)->assertNoContent();

        $this->assertSame(0, ErrorEvent::query()->count());
    }

    /**
     * Bilinmeyen alanlar ve çözümlenemeyen tarih raporu düşürmez.
     *
     * Sitenin bir sürüm önde gitmesi, bütün hata akışını durdurmamalı.
     */
    public function test_bilinmeyen_alan_ve_bozuk_tarih_raporu_dusurmez(): void
    {
        $this->postJson(self::ENDPOINT, $this->payload([
            'occurred_at' => 'dün akşam',
            'utm_source' => 'bilinmeyen-alan',
        ]), self::HEADERS)->assertNoContent();

        $row = ErrorEvent::firstOrFail();
        $this->assertNull($row->occurred_at);
        $this->assertSame('Sepet çizilemedi', $row->message);
    }

    /**
     * Rota SORGU DİZESİZ saklanır: adres çubuğundaki parametreler zaman
     * zaman kişisel veri taşır ve hata kaydı onları saklamak için yanlış
     * yerdir.
     */
    public function test_rota_sorgu_dizesi_atilir(): void
    {
        $this->postJson(self::ENDPOINT, $this->payload([
            'route' => '/siparislerim/1234?telefon=5551234567',
        ]), self::HEADERS)->assertNoContent();

        $this->assertSame('/siparislerim/1234', ErrorEvent::firstOrFail()->context['route']);
    }

    // ── Toplu gönderim ve oran sınırı ────────────────────────────────────

    /**
     * Toplu gönderimde ilk 20 olay alınır; fazlası REDDEDİLMEZ, düşer.
     *
     * 21. olay yüzünden ilk 20'yi de kaybetmek en kötü sonuç olurdu.
     */
    public function test_toplu_gonderim_yirmi_olayla_sinirli(): void
    {
        $events = [];
        for ($i = 1; $i <= 25; $i++) {
            // Mesajlar rakamla değil harfle ayrışıyor: parmak izi rakamları
            // siliyor ve numaralı mesajlar tek satıra toplanırdı.
            $events[] = ['message' => 'Çökme türü '.chr(64 + $i), 'kind' => 'unhandled'];
        }

        $this->postJson(self::ENDPOINT, ['events' => $events], self::HEADERS)->assertNoContent();

        $this->assertSame(20, ErrorEvent::query()->count());
    }

    /**
     * DAKİKADA 60 İSTEK SERBEST, 61. `429`.
     *
     * Sınır sözleşmeden geliyor (`bld-hata`, 60/dakika/IP). Saatlik bir
     * kova, çökme anında art arda gelen — yani en çok ihtiyaç duyulan —
     * raporları ilk dakikada keserdi.
     */
    public function test_dakikada_altmis_birinci_istek_429_alir(): void
    {
        for ($i = 1; $i <= 60; $i++) {
            $this->postJson(self::ENDPOINT, $this->payload(), self::HEADERS)->assertNoContent();
        }

        $this->postJson(self::ENDPOINT, $this->payload(), self::HEADERS)
            ->assertStatus(429)
            ->assertJsonPath('error.code', 'RATE_LIMITED');
    }

    // ── KDS aynalaması ───────────────────────────────────────────────────

    /**
     * Kasanın bildirdiği `last_error` monitöre `kds` olarak düşer.
     *
     * Kasa zaten dakikada bir sağlık bildiriyor ve alanı zaten gönderiyor;
     * hata anında ikinci bir uca bel bağlamak, ağın en güvenilmez olduğu
     * anda ikinci bir isteğe güvenmek olurdu.
     */
    public function test_kasanin_son_hatasi_kds_olarak_aynalanir(): void
    {
        $this->health('Yazıcıya ulaşılamadı: /dev/usb/lp0 açılamıyor')->assertOk();

        $row = ErrorEvent::firstOrFail();

        $this->assertSame(ErrorEvent::SOURCE_KDS, $row->source);
        $this->assertSame('kds_last_error', $row->type);
        $this->assertSame('Yazıcıya ulaşılamadı: /dev/usb/lp0 açılamıyor', $row->message);
        $this->assertArrayHasKey('device_id', (array) $row->context);
    }

    /**
     * AYNI HATA TEKRAR BİLDİRİLİRSE YENİ OLAY YAZILMAZ.
     *
     * Kasa aynı hatayı düzelene kadar HER bildirimde (dakikada bir, gün
     * boyu) tekrar gönderir. Her bildirimi aynalamak `occurrences`'ı gerçek
     * tekrar sayısı yerine "arıza kaç dakika sürdü"ye çevirirdi.
     */
    public function test_degismeyen_hata_tekrar_aynalanmaz(): void
    {
        $this->health('Yazıcı kapağı açık')->assertOk();
        $this->health('Yazıcı kapağı açık')->assertOk();

        $this->assertSame(1, ErrorEvent::query()->count());
        $this->assertSame(1, ErrorEvent::firstOrFail()->occurrences);
    }

    /**
     * `null` aynalanmaz: "hata yok" bir hata değildir. Arızanın bittiğini
     * monitöre yazmak, açık duran satırın yanına ikinci bir satır koymak
     * olurdu.
     */
    public function test_hatasiz_saglik_bildirimi_olay_yazmaz(): void
    {
        $this->health(null)->assertOk();

        $this->assertSame(0, ErrorEvent::query()->count());
    }

    public function test_hata_degisince_yeni_olay_acilir(): void
    {
        $this->health('Yazıcı kapağı açık')->assertOk();
        $this->health('Kâğıt bitti')->assertOk();

        $this->assertSame(2, ErrorEvent::query()->count());
    }

    // ── Saklama (`veykemtu:hata-temizle`) ────────────────────────────────

    /**
     * SAKLAMA KURALI OLMADAN BU TABLO DİSKİ DOLDURUR.
     *
     * İki süre, iki farklı soru: çözülmüş olayda soru cevaplanmış (30 gün),
     * çözülmemişte hata hâlâ açık ve mevsimlik bir tekrarı görmeye yetecek
     * kadar beklenmeli (90 gün).
     */
    public function test_eskimis_olaylar_silinir_taze_olanlar_kalir(): void
    {
        $now = BusinessTime::forStorage(Carbon::now());

        $eskiCozulmus = $this->event('Eski çözülmüş', [
            'resolved_at' => $now->copy()->subDays(31),
            'last_seen_at' => $now->copy()->subDays(40),
        ]);
        $yeniCozulmus = $this->event('Yeni çözülmüş', [
            'resolved_at' => $now->copy()->subDays(10),
            'last_seen_at' => $now->copy()->subDays(12),
        ]);
        $eskiAcik = $this->event('Eski açık', [
            'last_seen_at' => $now->copy()->subDays(100),
        ]);
        $yeniAcik = $this->event('Yeni açık', [
            'last_seen_at' => $now->copy()->subDays(60),
        ]);

        $this->artisan('veykemtu:hata-temizle')->assertSuccessful();

        $this->assertNull(ErrorEvent::find($eskiCozulmus), 'Çözülmüş ve 30 günü geçmiş satır silinmeli.');
        $this->assertNull(ErrorEvent::find($eskiAcik), 'Açık ve 90 günü geçmiş satır silinmeli.');
        $this->assertNotNull(ErrorEvent::find($yeniCozulmus));
        $this->assertNotNull(
            ErrorEvent::find($yeniAcik),
            'Açık bir olay çözülmüşle aynı süreye tabi tutulmamalı.',
        );
    }

    /** Kuru prova hiçbir şey silmez — elle bakmak için. */
    public function test_kuru_prova_silmez(): void
    {
        $now = BusinessTime::forStorage(Carbon::now());
        $id = $this->event('Eski açık', ['last_seen_at' => $now->copy()->subDays(200)]);

        $this->artisan('veykemtu:hata-temizle', ['--kuru' => true])->assertSuccessful();

        $this->assertNotNull(ErrorEvent::find($id));
    }

    // ── Sunucu istisnaları (`MonitorRecorder`) ───────────────────────────

    /**
     * `report()` EDİLEN BİR İSTİSNA MONİTÖRE DÜŞER.
     *
     * Bu testin kaybı, görevin tamamının kaybıdır: kanca bağlanmazsa
     * `source = server` yazan hiçbir kod yolu kalmaz ve monitörün dört
     * kaynağından biri ekranda boş bir sütun olarak durur. Gece koşan
     * abonelik üretimi, stok tazeleme ve kuyruk işleri kimseye yanıt
     * döndürmüyor; arızaları YALNIZ buradan görünüyor.
     */
    public function test_sunucu_istisnasi_server_kaynagiyla_kaydedilir(): void
    {
        report(new RuntimeException('Gece abonelik üretimi çöktü'));

        $row = ErrorEvent::firstOrFail();

        $this->assertSame(ErrorEvent::SOURCE_SERVER, $row->source);
        $this->assertSame(ErrorEvent::LEVEL_ERROR, $row->level);
        $this->assertSame(RuntimeException::class, $row->type);
        $this->assertSame('Gece abonelik üretimi çöktü', $row->message);
        $this->assertStringContainsString(
            'ErrorIntakeTest.php',
            (string) $row->stack,
            'Yığın hatanın doğduğu dosyayı göstermeli.',
        );
        $this->assertArrayHasKey('origin', (array) $row->context);
        // Sunucu hatasında oluş anı ile alış anı aynı; `occurred_at`
        // çevrimdışı biriktirilen İSTEMCİ raporları için var.
        $this->assertNull($row->occurred_at);
    }

    /**
     * AYNI ÇÖKME İKİ KEZ → TEK SATIR, `occurrences = 2`.
     *
     * Bir çökme döngüsü aynı istisnayı dakikada yüzlerce kez üretir; her
     * tekrar ayrı satır olsaydı bir öğleden sonra bu tabloya bir milyon
     * satır yazılır ve gerçek hata kaybolurdu. `first_seen_at` donuyor
     * ("bu ne zamandır oluyor"), `last_seen_at` ilerliyor ("hâlâ oluyor
     * mu").
     */
    public function test_ayni_sunucu_istisnasi_tek_satirda_toplanir(): void
    {
        Carbon::setTestNow(Carbon::parse('2026-09-08 09:00:00'));
        report($this->serverFault());

        $first = ErrorEvent::firstOrFail();

        Carbon::setTestNow(Carbon::parse('2026-09-08 09:05:00'));
        report($this->serverFault());

        $this->assertSame(1, ErrorEvent::query()->count(), 'Aynı istisna tek satır olmalı.');

        $row = ErrorEvent::firstOrFail();
        $this->assertSame(2, $row->occurrences);
        $this->assertEquals($first->first_seen_at, $row->first_seen_at, '`first_seen_at` donuk kalmalı.');
        $this->assertTrue(
            $row->last_seen_at->greaterThan($first->last_seen_at),
            '`last_seen_at` ilerlemeli.',
        );
    }

    public function test_farkli_sunucu_istisnasi_ayri_satir_acar(): void
    {
        report(new RuntimeException('Stok tazelenemedi'));
        report(new LogicException('Menü çözülemedi'));

        $this->assertSame(2, ErrorEvent::query()->count());
    }

    /**
     * KAYIT SIRASINDA DOĞAN HATA ÇAĞIRANI ETKİLEMEZ.
     *
     * Senaryo gerçek: veritabanı düşer, ilk istisna kayıtçıya gelir, yazma
     * denemesi İKİNCİ bir istisna atar. Yutulmasaydı tek bir DB kesintisi
     * sonsuz döngüye ve dolan bir yığına dönerdi.
     *
     * İKİNCİ YARISI EN AZ İLKİ KADAR ÖNEMLİ: yeniden giriş bayrağı
     * `finally` ile sıfırlanmazsa monitör ilk arızadan sonra bir daha HİÇ
     * yazmaz ve bunu kimse fark etmez — tam da düzeltmeye çalıştığımız
     * sessiz ölüm.
     */
    public function test_kayit_hatasi_cagirani_etkilemez_ve_bayragi_kilitlemez(): void
    {
        $recorder = app(MonitorRecorder::class);
        $connection = config('database.default');

        try {
            // Yazmayı GERÇEKTEN bozan en küçük müdahale: var olmayan bir
            // bağlantı adı. `DB::table()` çözümlemede istisna atıyor, yani
            // kayıtçının içindeki hata gerçek bir hata.
            config(['database.default' => 'boyle-bir-baglanti-yok']);

            $recorder->recordServerException(new RuntimeException('Veritabanı düştü'));
        } finally {
            config(['database.default' => $connection]);
        }

        $this->assertSame(0, ErrorEvent::query()->count(), 'Bozuk yazma satır bırakmamalı.');

        $recorder->recordServerException(new RuntimeException('Arızadan sonraki hata'));

        $this->assertSame(
            1,
            ErrorEvent::query()->count(),
            'Yeniden giriş bayrağı sıfırlanmalı; yoksa monitör bir daha hiç yazmaz.',
        );
    }

    /**
     * 8 KB'ı AŞAN YIĞIN KESİLİR, RAPOR REDDEDİLMEZ.
     *
     * Özyinelemeye giren bir kod on binlerce çerçeve üretir. Tavanı bir
     * karakter aşan iz yüzünden kaydı hiç yazmamak, çöken sunucunun tek
     * kanıtını çöpe atmak olurdu.
     *
     * Derinlik 150 seçildi: çerçeve başına ~150 karakterle tavanın üç
     * katından fazlasını üretiyor ama PHP'nin (ve xdebug varsa onun)
     * yığın sınırlarının çok altında kalıyor.
     */
    public function test_uzun_sunucu_yigini_kirpilir(): void
    {
        report($this->deepFault(150));

        $this->assertSame(
            ErrorEvent::STACK_LIMIT,
            mb_strlen((string) ErrorEvent::firstOrFail()->stack),
        );
    }

    /**
     * MESAJSIZ İSTİSNA SINIF ADIYLA KAYDEDİLİR.
     *
     * `message` sütunu NOT NULL. Boş mesaj olduğu gibi geçseydi yazma SQL
     * hatasıyla düşerdi — yani "hata kaydedilemedi" durumu tam da bir hata
     * varken doğardı.
     */
    public function test_mesajsiz_istisna_sinif_adiyla_kaydedilir(): void
    {
        report(new RuntimeException(''));

        $this->assertSame(RuntimeException::class, ErrorEvent::firstOrFail()->message);
    }

    /**
     * 4xx MONİTÖRE YAZILMAZ, 5xx YAZILIR.
     *
     * `ApiException` düz bir `Exception` ve Laravel'in `dontReport`
     * listesine girmiyor; süzgeç olmasaydı süresi dolmuş her belirteç ve
     * bulunamayan her sipariş monitöre "sunucu hatası" olarak düşerdi. O
     * satırlar gerçek çökmeleri sayıca kat kat aşar ve ekranı tam da
     * görülmesi gereken şeyi gizleyecek biçimde doldururdu.
     */
    public function test_istemci_hatasi_yazilmaz_sunucu_hatasi_yazilir(): void
    {
        report(ApiException::unauthenticated());
        report(ApiException::forbidden());

        $this->assertSame(0, ErrorEvent::query()->count(), '4xx sunucunun hatası değil.');

        report(ApiException::serverError('Sanal POS yanıt vermedi'));

        $row = ErrorEvent::firstOrFail();
        $this->assertSame(ErrorEvent::SOURCE_SERVER, $row->source);
        $this->assertSame('Sanal POS yanıt vermedi', $row->message);
    }

    // ── `veykemtu_subscriptions.status` genişliği ────────────────────────

    /**
     * `awaiting_contract` YAZILIP GERİ OKUNABİLİYOR.
     *
     * Değer 17 karakter, kolon ise `varchar(16)` idi: MySQL katı kipte
     * "Data too long" ile reddeder, gevşek kipte sessizce
     * `awaiting_contrac` yazar — ikincisi daha kötü, çünkü durum
     * karşılaştırmaları bir daha hiç tutmaz. Sözleşmedeki durum, kolon
     * genişletilmeden HİÇ KULLANILAMIYORDU.
     *
     * Test bu dosyada çünkü göç bu görevin kulvarında; abonelik akışının
     * kendisi başka bir pakette sınanıyor.
     */
    public function test_awaiting_contract_durumu_yazilip_geri_okunabilir(): void
    {
        $subscription = $this->subscription();

        $subscription->status = 'awaiting_contract';
        $subscription->save();

        $this->assertSame(
            'awaiting_contract',
            Subscription::findOrFail($subscription->id)->status,
        );
    }

    /**
     * GENİŞLETME VARSAYILANI DÜŞÜRMEDİ.
     *
     * Laravel'in yerel `change()` uygulaması sütunu baştan tanımlıyor ve
     * göçte yazılmayan her değiştirici sessizce düşüyor. Varsayılan
     * kaybolsaydı durumu belirtmeden açılan her abonelik talebi boş
     * durumla doğar ve hiçbir süzgece takılmazdı.
     */
    public function test_status_varsayilani_pending_kalir(): void
    {
        $this->assertSame(Subscription::STATUS_PENDING, $this->subscription()->status);
    }

    // ── Yardımcılar ──────────────────────────────────────────────────────

    /**
     * Tekilleştirme testlerinin sunucu istisnası.
     *
     * İSTİSNA HEP AYNI SATIRDA doğuyor — parmak izi hatanın doğduğu yeri ve
     * ilk üç çerçeveyi kullanıyor. Testin gövdesinde `new` yazılsaydı iki
     * çağrı iki farklı satırdan gelir ve "aynı hata mı" sorusu, ölçmek
     * istediğimiz şey yerine test dosyasının biçimine bağlı olurdu.
     */
    private function serverFault(): RuntimeException
    {
        return new RuntimeException('Yazdırma kuyruğu boşaltılamadı');
    }

    /**
     * Verilen derinlikte özyineleyip istisnayı en dipte doğurur — uzun
     * yığın testi için.
     */
    private function deepFault(int $depth): RuntimeException
    {
        if ($depth > 0) {
            return $this->deepFault($depth - 1);
        }

        return new RuntimeException('Çok derin bir çağrıdan doğdu');
    }

    /**
     * En küçük geçerli abonelik satırı.
     *
     * `status` BİLEREK YAZILMIYOR: sütun varsayılanının göçten sağ çıktığını
     * ölçen test buna dayanıyor.
     */
    private function subscription(): Subscription
    {
        $subscription = new Subscription;
        // Müşteri kaydı gerekmiyor: tabloda yabancı anahtar yok ve ölçülen
        // şey abonelik akışı değil, `status` sütununun genişliği.
        $subscription->customer_id = 1;
        $subscription->location_id = $this->locationId();
        $subscription->start_date = BusinessTime::today();
        $subscription->delivery_type = 'delivery';
        $subscription->service_days = [1, 2, 3, 4, 5];
        $subscription->menu_mode = Subscription::MENU_DAILY;
        $subscription->default_quantity = 20;
        $subscription->payment_mode = Subscription::PAYMENT_PREPAID;
        $subscription->save();

        return $subscription->refresh();
    }

    /**
     * Doğrudan tabloya olay yazar — saklama testleri için.
     *
     * @param array<string, mixed> $overrides
     */
    private function event(string $message, array $overrides = []): int
    {
        $now = BusinessTime::forStorage(Carbon::now());

        $event = new ErrorEvent;
        $event->fill(array_merge([
            'source' => ErrorEvent::SOURCE_WEBSITE,
            'level' => ErrorEvent::LEVEL_ERROR,
            'fingerprint' => sha1($message),
            'type' => 'unhandled',
            'message' => $message,
            'first_seen_at' => $now->copy()->subDays(200),
            'last_seen_at' => $now,
            'occurrences' => 1,
        ], $overrides));
        $event->save();

        return (int) $event->id;
    }

    /**
     * @param array<string, mixed> $overrides
     * @return array<string, mixed>
     */
    private function payload(array $overrides = []): array
    {
        return array_merge([
            'message' => 'Sepet çizilemedi',
            'kind' => 'render',
            'stack' => "at CartScreen.build\nat Widget.rebuild",
            'route' => '/sepet',
            'app_build' => 'a1b2c3d',
            'device' => 'Chrome 141 / Linux',
            'context' => ['retry' => 2],
        ], $overrides);
    }

    /**
     * Kasadan sağlık bildirimi gönderir.
     *
     * TOKEN BİR KEZ ALINIYOR ve saklanıyor. `asKitchen()` her çağrıda YENİ
     * bir kasa eşliyor; aynalama kuralı ise "bir ÖNCEKİ bildirimin
     * hatasıyla karşılaştır" diyor. Her turda yeni kasa kullanılsaydı
     * önceki değer hep `null` olur, aynı hata her seferinde yeniden
     * aynalanır ve "değişmedi, yazma" kuralı hiç sınanmazdı.
     *
     * Oran sınırı KAPALI: ölçülen şey `bld-kitchen` kovası değil, aynalama
     * kuralı. Kovanın kendi testleri var.
     */
    private function health(?string $lastError): TestResponse
    {
        $this->withoutMiddleware(ThrottleRequests::class);

        $this->kitchenToken ??= (string) $this->pairedDevice()['token'];

        return $this->withToken($this->kitchenToken)->postJson('/api/kitchen/health', [
            'printer_ok' => $lastError === null,
            'print_queue_pending' => 0,
            'print_queue_failed' => 0,
            'last_error' => $lastError,
        ], self::HEADERS);
    }
}
