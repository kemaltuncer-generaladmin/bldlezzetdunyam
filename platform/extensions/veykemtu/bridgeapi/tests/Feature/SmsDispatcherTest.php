<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Igniter\Cart\Models\Menu;
use Igniter\Local\Models\Location;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Override;
use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Models\DailyMenuItem;
use Veykemtu\BridgeApi\Models\SmsLog;
use Veykemtu\BridgeApi\Models\SmsTemplate;
use Veykemtu\BridgeApi\Services\LocationGate;
use Veykemtu\BridgeApi\Services\Sms\SmsDispatcher;
use Veykemtu\BridgeApi\Services\Sms\SmsException;
use Veykemtu\BridgeApi\Services\Sms\SmsSender;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * SMS şablonları, gönderici ve günün menüsü duyurusu — B1.
 *
 * Bu paket dört sözü kilitliyor; dördü de "yanlış giderse müşteriye
 * gider" sınıfından:
 *
 *  1. **Kapalı şablon hiçbir iz bırakmaz.** Şablonlar KAPALI doğuyor;
 *     bu, tek bir deploy'un binlerce SMS'e dönüşmesini engelleyen kural.
 *  2. **Aynı olay iki mesaj üretmez.** Kapı veritabanındaki benzersiz
 *     indeks; uygulama katmanındaki bir kontrol iki eşzamanlı işçi
 *     arasında hiçbir şey garanti etmezdi.
 *  3. **Sağlayıcı hatası çağırana ulaşmaz.** Ölü bir SMS sağlayıcısı bir
 *     sipariş durum değişimini geri almamalı.
 *  4. **Kuru koşum ağa çıkmaz.** Kanıt casusun kendisi: `SmsSender` hiç
 *     çağrılmıyor.
 */
class SmsDispatcherTest extends KitchenTestCase
{
    private const string TABLE = 'veykemtu_sms_log';

    private const string PHONE = '5551112233';

    /** Duyuru kuru koşumunun ölçek testi — iş kuralındaki sayı. */
    private const int AUDIENCE = 500;

    private SmsDispatcherTestSender $spy;

    #[Override]
    protected function setUp(): void
    {
        parent::setUp();

        /*
         * Casus gönderici. `SmsSender` arayüzü tam olarak bunun için var:
         * testin gerçek sağlayıcıya bağlanması ya da gönderilen metni
         * günlük dosyasından ayrıştırması gerekmiyor (`OtpLoginTest` ile
         * aynı kalıp).
         */
        $this->spy = new SmsDispatcherTestSender;
        $this->app->instance(SmsSender::class, $this->spy);
    }

    // ── Şablon durumu ─────────────────────────────────────────────────────

    /**
     * TOHUMLANAN HER ŞABLON KAPALI DOĞAR.
     *
     * Bu paketteki en önemli tek doğrulama. Bir şablon açık doğsaydı, göç
     * koştuğu anda o gün açık olan her siparişin her durum geçişi müşteriye
     * mesaj olarak giderdi: geri alınamaz, faturası gelir ve kimse deploy'u
     * suçlamayı akıl etmez.
     */
    public function test_tum_sablonlar_kapali_dogar(): void
    {
        $templates = SmsTemplate::query()->get();

        $this->assertGreaterThan(0, $templates->count(), 'Şablonlar tohumlanmamış.');

        foreach ($templates as $template) {
            $this->assertFalse(
                $template->enabled,
                "`{$template->key}` şablonu AÇIK doğmuş.",
            );
        }
    }

    /**
     * Kapalı şablon: ne gönderim, ne kayıt satırı.
     *
     * Kayıt satırı yazılsaydı `GET /log` ekranı "gönderildi" sanılan
     * satırlarla dolar ve kapalı bir şablonun kapalı olduğu görünmezdi.
     */
    public function test_kapali_sablon_ne_gonderir_ne_kaydeder(): void
    {
        $this->dispatcher()->send(
            'order_confirmed',
            self::PHONE,
            ['order_no' => 'BLD-1', 'service_date' => '17.08.2026'],
            'order',
            1,
        );

        $this->assertSame([], $this->spy->sent);
        $this->assertSame(0, DB::table(self::TABLE)->count());
    }

    /** Bilinmeyen anahtar da çağırana patlamaz — yalnız hiçbir şey olmaz. */
    public function test_bilinmeyen_sablon_anahtari_firlatmaz(): void
    {
        $this->dispatcher()->send('boyle_bir_sablon_yok', self::PHONE, [], 'order', 1);

        $this->assertSame([], $this->spy->sent);
        $this->assertSame(0, DB::table(self::TABLE)->count());
    }

    // ── Gönderim ──────────────────────────────────────────────────────────

    /**
     * Açık şablon: tam bir satır, işlenmiş ve GSM-7'ye inmiş gövde.
     *
     * Türkçe karakter denetimi kozmetik değil PARASAL: GSM-7 dışına çıkan
     * tek karakter segment başına karakteri 160'tan 70'e düşürür.
     */
    public function test_acik_sablon_tek_satir_yazar_ve_gsm7_e_iner(): void
    {
        $this->enable('order_created');

        $this->dispatcher()->send(
            'order_created',
            self::PHONE,
            [
                'customer_name' => 'Ayşe Çiğdem',
                'service_date' => '17.08.2026',
                'order_no' => 'BLD-8421',
                'total' => '180,00',
            ],
            'order',
            8421,
        );

        $this->assertCount(1, $this->spy->sent);
        $this->assertSame(self::PHONE, $this->spy->sent[0]['phone']);
        $this->assertStringContainsString('Sayin Ayse Cigdem', $this->spy->sent[0]['message']);
        $this->assertStringContainsString('BLD-8421', $this->spy->sent[0]['message']);
        $this->assertStringNotContainsString('{', $this->spy->sent[0]['message']);

        $rows = DB::table(self::TABLE)->get();
        $this->assertCount(1, $rows);
        $this->assertSame(SmsLog::STATUS_SENT, $rows[0]->status);
        $this->assertSame('order', $rows[0]->reference_type);
        $this->assertSame(8421, (int) $rows[0]->reference_id);
        $this->assertNull($rows[0]->error);
        $this->assertStringContainsString('Sayin Ayse Cigdem', (string) $rows[0]->body);

        /*
         * PANELİN OKUDUĞU KOLONLAR DA DOLU.
         *
         * `Control\SmsController` `GET /log` içinde `order_id`, `segments`,
         * `context` ve `sent_at` alanlarını doğrudan okuyor. Dispatcher
         * bunları yazmasaydı kayıt ekranı, satır orada dururken, boş bir
         * sipariş bağlantısı ve sıfır maliyet gösterirdi.
         */
        $this->assertSame(8421, (int) $rows[0]->order_id);
        $this->assertNull($rows[0]->customer_id);
        $this->assertSame(1, (int) $rows[0]->segments);
        $this->assertSame('auto', $rows[0]->context);
        $this->assertNotNull($rows[0]->sent_at);
    }

    /**
     * Aynı referansla ikinci çağrı: yeni satır yok, yeni SMS yok.
     *
     * Gerçek hayattaki karşılığı, aynı durum geçişinin iki kez uygulanması:
     * KDS'in yeniden denemesi, çift tıklama, kuyruk işinin tekrar koşması.
     * Kapı veritabanındaki benzersiz indekstir — "önce sorgula, sonra yaz"
     * iki eşzamanlı işçi arasında hiçbir şey garanti etmezdi.
     */
    public function test_ayni_referans_ikinci_kez_gonderilmez(): void
    {
        $this->enable('order_confirmed');

        $vars = ['order_no' => 'BLD-8421', 'service_date' => '17.08.2026'];

        $this->dispatcher()->send('order_confirmed', self::PHONE, $vars, 'order', 8421);
        $this->dispatcher()->send('order_confirmed', self::PHONE, $vars, 'order', 8421);

        $this->assertCount(1, $this->spy->sent, 'Aynı geçiş iki SMS üretti.');
        $this->assertSame(1, DB::table(self::TABLE)->count());
    }

    /**
     * Referans yoksa tekilleştirme de yok.
     *
     * MySQL benzersiz indekste NULL'ları ayrı sayar ve bu BURADA İSTENEN
     * ŞEYDİR: 500 alıcıya giden bir duyurunun 500 satır yazması gerekir.
     * NULL'ları tek sayan bir kısıt, duyurunun ilk alıcıdan sonrasını
     * sessizce yutardı.
     */
    public function test_referanssiz_gonderim_tekillestirilmez(): void
    {
        $this->enable('order_delivered');

        $this->dispatcher()->send('order_delivered', self::PHONE, ['order_no' => 'BLD-1']);
        $this->dispatcher()->send('order_delivered', self::PHONE, ['order_no' => 'BLD-1']);

        $this->assertCount(2, $this->spy->sent);
        $this->assertSame(2, DB::table(self::TABLE)->count());
    }

    /**
     * SAĞLAYICI PATLASA DA ÇAĞIRAN ETKİLENMEZ.
     *
     * `SmsDispatcher` sipariş durum değişiminin, abonelik onayının,
     * fatura kesiminin İÇİNDEN çağrılıyor. İstisna dışarı sızsaydı, ölü
     * bir SMS sağlayıcısı çağıranın işlemini geri alırdı: sipariş durumu
     * değişmez, mutfak yanlış ekranı görürdü.
     *
     * Çağıranın kendi yazımının COMMIT olduğu ayrıca doğrulanıyor — sadece
     * "istisna fırlamadı" demek, sessiz bir geri almayı yakalamazdı.
     */
    public function test_saglayici_patlarsa_cagirana_firlatilmaz(): void
    {
        $this->enable('order_cancelled');
        $this->spy->throws = true;

        $sms = $this->dispatcher();

        DB::transaction(function () use ($sms): void {
            // Çağıranın "asıl işi" — geçişin geri alınmadığının kanıtı.
            DB::table('veykemtu_sms_templates')
                ->where('key', 'order_cancelled')
                ->update(['updated_by' => 'cagiranin-isi']);

            $sms->send(
                'order_cancelled',
                self::PHONE,
                ['order_no' => 'BLD-1', 'service_date' => '17.08.2026', 'reason' => 'Test'],
                'order',
                1,
            );
        });

        $this->assertSame(
            'cagiranin-isi',
            DB::table('veykemtu_sms_templates')->where('key', 'order_cancelled')->value('updated_by'),
            'SMS hatası çağıranın işlemini geri almış.',
        );

        $row = DB::table(self::TABLE)->first();
        $this->assertNotNull($row, 'Başarısız gönderim kayıtsız kaldı.');
        $this->assertSame(SmsLog::STATUS_FAILED, $row->status);
        $this->assertNotNull($row->error);
    }

    /**
     * SMS alamayacak numara: `skipped` satırı, gönderim yok.
     *
     * Sessizce yutulsaydı "müşteriye haber verildi mi" sorusunun cevabı
     * "kayıt yok" olurdu ve bu, "göndermedik" ile "gönderemedik"
     * arasındaki farkı silerdi.
     */
    public function test_sms_alamayan_numara_skipped_yazar(): void
    {
        $this->enable('order_delivered');

        $this->dispatcher()->send(
            'order_delivered',
            '03322223344', // sabit hat
            ['order_no' => 'BLD-1'],
            'order',
            1,
        );

        $this->assertSame([], $this->spy->sent);

        $row = DB::table(self::TABLE)->first();
        $this->assertNotNull($row);
        $this->assertSame(SmsLog::STATUS_SKIPPED, $row->status);
    }

    // ── Günün menüsü duyurusu ─────────────────────────────────────────────

    /**
     * KURU KOŞUM: 500 alıcı, 500 `dry_run` satırı, SIFIR gönderim.
     *
     * Kanıt casusun kendisi — `SmsSender` hiç çağrılmıyor. "Kuru koşum"
     * diyen ama ağa çıkan bir komut, provayı gerçek gönderime çevirirdi ve
     * bunu ancak alıcılar fark ederdi.
     */
    public function test_menu_duyurusu_kuru_kosumda_hic_gondermez(): void
    {
        $this->enable(SmsTemplate::KEY_DAILY_MENU_ANNOUNCE);
        $today = $this->announceDay();
        $this->seedAudience(self::AUDIENCE);

        $this->artisan('veykemtu:menu-duyur', [
            '--date' => $today->toDateString(),
            '--dry-run' => true,
        ])->assertSuccessful();

        $this->assertSame([], $this->spy->sent, 'Kuru koşum ağa çıktı.');

        $rows = DB::table(self::TABLE)->where('status', SmsLog::STATUS_DRY_RUN);
        $this->assertSame(self::AUDIENCE, $rows->count());

        /*
         * KURU KOŞUM REFERANSSIZ YAZILIR: referanslar korunsaydı prova
         * satırı gerçek gönderimin idempotans yuvasını işgal ederdi ve
         * önce prova edip sonra göndermek isteyen yönetici — hata da
         * almadan — hiçbir şey gönderemezdi.
         */
        $this->assertSame(0, (clone $rows)->whereNotNull('reference_type')->count());
    }

    /**
     * Gerçek koşum: menü metni gidiyor ve ikinci koşum tekrar göndermiyor.
     *
     * Günün referansı `reference_type` içinde taşınıyor; taşınmasaydı
     * yarının duyurusu bugünkünün satırına çarpar ve hiç gitmezdi.
     */
    public function test_menu_duyurusu_ayni_gun_ikinci_kez_gitmez(): void
    {
        $this->enable(SmsTemplate::KEY_DAILY_MENU_ANNOUNCE);
        $today = $this->announceDay();
        $this->seedAudience(3);

        $this->artisan('veykemtu:menu-duyur', ['--date' => $today->toDateString()])
            ->assertSuccessful();

        $this->assertCount(3, $this->spy->sent);
        $this->assertStringContainsString('Mercimek Corbasi', $this->spy->sent[0]['message']);
        $this->assertStringContainsString($today->format('d.m.Y'), $this->spy->sent[0]['message']);

        // Duyuru satırları panelde `announcement` bağlamında ve müşteriye
        // bağlı görünmeli: "bu müşteriye ne gitti" sorusunun sorulduğu tek
        // kanal toplu gönderimdir.
        $row = DB::table(self::TABLE)->first();
        $this->assertSame('announcement', $row->context);
        $this->assertNotNull($row->customer_id);

        $this->artisan('veykemtu:menu-duyur', ['--date' => $today->toDateString()])
            ->assertSuccessful();

        $this->assertCount(3, $this->spy->sent, 'Duyuru ikinci koşumda tekrar gitti.');
        $this->assertSame(3, DB::table(self::TABLE)->count());
    }

    /**
     * ŞABLON KAPALIYKEN DUYURU HİÇBİR ŞEY YAPMAZ.
     *
     * `dailymenu.announce` İYS/KVKK imzası gelene kadar kapalı kalıyor.
     * Zamanlama her gün koşuyor; kapalı şablon o koşumun tamamını sessiz
     * bir hiçliğe çeviriyor.
     */
    public function test_menu_duyurusu_kapali_sablonda_hicbir_sey_yapmaz(): void
    {
        $today = $this->announceDay();
        $this->seedAudience(3);

        $this->artisan('veykemtu:menu-duyur', ['--date' => $today->toDateString()])
            ->assertSuccessful();

        $this->assertSame([], $this->spy->sent);
        $this->assertSame(0, DB::table(self::TABLE)->count());
    }

    /** Reddeden müşteri kitleden düşer. */
    public function test_opt_out_musteri_duyuru_almaz(): void
    {
        $this->enable(SmsTemplate::KEY_DAILY_MENU_ANNOUNCE);
        $today = $this->announceDay();
        $ids = $this->seedAudience(3);

        DB::table('customers')->where('customer_id', $ids[0])->update(['bld_sms_opt_out' => 1]);

        $this->artisan('veykemtu:menu-duyur', ['--date' => $today->toDateString()])
            ->assertSuccessful();

        $this->assertCount(2, $this->spy->sent);
    }

    /** `--limit` gerçekten sınırlar — büyük kitlede ilk denemenin frenidir. */
    public function test_limit_aliciyi_sinirlar(): void
    {
        $this->enable(SmsTemplate::KEY_DAILY_MENU_ANNOUNCE);
        $today = $this->announceDay();
        $this->seedAudience(5);

        $this->artisan('veykemtu:menu-duyur', [
            '--date' => $today->toDateString(),
            '--limit' => 2,
        ])->assertSuccessful();

        $this->assertCount(2, $this->spy->sent);
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    private function dispatcher(): SmsDispatcher
    {
        return app(SmsDispatcher::class);
    }

    private function enable(string $key): void
    {
        DB::table('veykemtu_sms_templates')->where('key', $key)->update(['enabled' => true]);
    }

    private function location(): Location
    {
        return Location::query()->where('location_id', $this->locationId())->firstOrFail();
    }

    /**
     * Duyurulacak günün menüsünü yayınlar ve o günü döndürür.
     *
     * Gün BUGÜN: duyuru "günün menüsü" duyurusu ve komutun varsayılanı da
     * bugün. Sipariş vermiyoruz, yalnız menü yayınlıyoruz — bu yüzden
     * kesim saati bu testi bağlamıyor.
     */
    private function announceDay(): Carbon
    {
        $today = BusinessTime::now()->startOfDay();

        $menu = DailyMenu::create([
            'location_id' => $this->locationId(),
            'menu_date' => $today->toDateString(),
            'title' => 'Ev Yemeği Menüsü',
            'status' => DailyMenu::STATUS_PUBLISHED,
            'published_at' => BusinessTime::forStorage(BusinessTime::now()),
        ]);

        foreach (['Tavuk Sote', 'Mercimek Çorbası'] as $index => $name) {
            DailyMenuItem::create([
                'daily_menu_id' => $menu->id,
                'menu_id' => Menu::query()->where('menu_name', $name)->firstOrFail()->menu_id,
                'quantity' => 1,
                'sort_order' => $index,
            ]);
        }

        return $today;
    }

    /**
     * Duyuru kitlesi üretir: müşteri + bu vitrinden yakın tarihli sipariş.
     *
     * SATIRLAR GERÇEK BİR PROTOTİPTEN ÇOĞALTILIYOR. Elle yazılmış bir
     * `INSERT`, çekirdeğin `customers`/`orders` şemasındaki zorunlu
     * kolonları er ya da geç ıskalar ve test şemayla birlikte sessizce
     * eskir; API üzerinden doğan bir satırı kopyalamak her zaman geçerli
     * kalır.
     *
     * @return list<int> Üretilen müşteri kimlikleri.
     */
    private function seedAudience(int $count): array
    {
        $prototype = $this->prototypeOrder();

        /*
         * PROTOTİP SİPARİŞ İKİ YIL GERİYE ALINIYOR.
         *
         * Onu üreten müşteri de bu vitrinden sipariş vermiş sayılır ve
         * kitleye girerdi; sayılar bir fazla çıkardı. Silmek yerine
         * eskitmek, aynı hamlede 180 günlük kitle penceresinin gerçekten
         * eleme yaptığını da kanıtlıyor.
         */
        DB::table('orders')
            ->where('order_id', $prototype->order_id)
            ->update(['order_date' => BusinessTime::now()->subYears(2)->toDateString()]);

        $customer = (array) DB::table('customers')
            ->where('customer_id', $prototype->customer_id)
            ->first();

        unset($customer['customer_id']);

        $customers = [];
        for ($i = 0; $i < $count; $i++) {
            $row = $customer;
            $row['email'] = 'duyuru'.$i.'@ornek.com';
            $row['telephone'] = sprintf('55%08d', $i);
            $row['bld_sms_opt_out'] = 0;
            $row['status'] = 1;
            $customers[] = $row;
        }

        DB::table('customers')->insert($customers);

        $ids = DB::table('customers')
            ->where('email', 'like', 'duyuru%@ornek.com')
            ->orderBy('customer_id')
            ->pluck('customer_id')
            ->all();

        $order = (array) $prototype;
        unset($order['order_id']);

        $orders = [];
        foreach ($ids as $id) {
            $row = $order;
            $row['customer_id'] = $id;
            $row['hash'] = 'duyuru-'.$id;
            // Kitle penceresinin İÇİNDE: prototip geriye alındı, kopyalar
            // bugünün tarihini taşımalı.
            $row['order_date'] = BusinessTime::now()->toDateString();
            $orders[] = $row;
        }

        DB::table('orders')->insert($orders);

        return array_map(static fn($id): int => (int) $id, $ids);
    }

    /**
     * Kopyalanacak gerçek sipariş satırı — API üzerinden doğar.
     *
     * Servis günü İLERİ BİR HAFTA İÇİ: bugüne sipariş vermek testi kesim
     * saatine bağlar ve öğleden sonra koşturulduğunda arıza SMS'le hiç
     * ilgisi olmayan bir yerden gelir (`DailyStockTest` ile aynı gerekçe).
     * `order_date` yine BUGÜN olur, yani kitle penceresine düşer.
     */
    private function prototypeOrder(): object
    {
        $gate = app(LocationGate::class);
        $gate->setDailyMenuEnabled($this->location(), true);
        $gate->setMinOrderTotal($this->location(), 0);

        $date = BusinessTime::now()->addDay()->startOfDay();
        while (in_array($date->dayOfWeekIso, [6, 7], true)) {
            $date->addDay();
        }

        $menu = DailyMenu::create([
            'location_id' => $this->locationId(),
            'menu_date' => $date->toDateString(),
            'title' => 'Ev Yemeği Menüsü',
            'status' => DailyMenu::STATUS_PUBLISHED,
            'published_at' => BusinessTime::forStorage(BusinessTime::now()),
        ]);

        $product = Menu::query()->where('menu_name', 'Tavuk Sote')->firstOrFail();

        DailyMenuItem::create([
            'daily_menu_id' => $menu->id,
            'menu_id' => $product->menu_id,
            'quantity' => 1,
            'sort_order' => 0,
        ]);

        $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            'items' => [['menu_id' => $product->menu_id, 'quantity' => 1]],
            'delivery_type' => 'pickup',
            'payment_method' => 'cash',
            'service_date' => $date->toDateString(),
        ], self::HEADERS)->assertCreated();

        $order = DB::table('orders')->orderByDesc('order_id')->first();
        $this->assertNotNull($order, 'Prototip sipariş üretilemedi.');

        return $order;
    }
}

/**
 * Kaydeden (ve istendiğinde patlayan) sahte gönderici.
 *
 * Ayrı bir sınıf, anonim sınıf değil: `throws` bayrağı testin ortasında
 * çevriliyor ve bayrağı dışarıdaki bir değişkene REFERANSLA bağlamak,
 * kolay bozulan bir kurulum olurdu.
 */
final class SmsDispatcherTestSender implements SmsSender
{
    /** @var list<array{phone: string, message: string}> */
    public array $sent = [];

    public bool $throws = false;

    #[Override]
    public function send(string $phone, string $message): void
    {
        if ($this->throws) {
            throw new SmsException('Sağlayıcıya ulaşılamadı.');
        }

        $this->sent[] = ['phone' => $phone, 'message' => $message];
    }
}
