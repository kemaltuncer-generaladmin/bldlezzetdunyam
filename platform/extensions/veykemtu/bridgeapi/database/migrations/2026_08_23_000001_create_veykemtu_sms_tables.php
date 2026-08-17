<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * SMS şablonları ve gönderim kaydı — B1 (`docs/control/sms.md`).
 *
 * İki tablo, iki ayrı soru: "hangi metin gidecek" (`veykemtu_sms_templates`)
 * ve "ne gitti" (`veykemtu_sms_log`). Sağlayıcının kendi paneli ikincisinin
 * yerini tutmaz: orada bizim sipariş numaramız, abonelik kimliğimiz ve
 * hangi şablondan çıktığı yoktur.
 *
 * ═════════════════════════════════════════════════════════════════════════
 * ŞABLONLAR **KAPALI** DOĞAR (`enabled` default 0) — bu göçteki tek en
 * önemli seçim.
 *
 * Açık doğan bir şablon, tek bir deploy'u binlerce SMS'e çevirir: göç
 * koştuğu anda sipariş durum tetikleyicileri canlanır ve o gün açık olan
 * her siparişin her geçişi müşteriye mesaj olarak gider. Geri alınamaz,
 * özür dilenemez ve faturası gelir. Kapalı doğan bir şablonun bedeli ise
 * yalnızca "yönetici anahtarı açmayı unuttu" — fark edilir ve düzeltilir.
 *
 * Aynı sebeple tohumlama `insertOrIgnore`: göç yeniden koşarsa yöneticinin
 * ELLE AÇTIĞI bir şablon tekrar kapanmamalı ve düzenlenmiş metin
 * ezilmemeli.
 * ═════════════════════════════════════════════════════════════════════════
 *
 * ─────────────────────────────────────────────────────────────────────────
 * `UNIQUE(template_key, reference_type, reference_id)` BİR İŞLEV DEĞİL,
 * BİR KAPIDIR.
 *
 * SMS gönderimi ağ üzerinden yapılan, zaman aşımına uğrayabilen bir iştir.
 * Zaman aşımına uğrayan istek yeniden denenir; kuyruk işi tekrar koşar;
 * kullanıcı düğmeye iki kez basar. Bu üçü aynı sonuca çıkar: aynı sipariş
 * geçişi için müşteriye beş mesaj. İdempotansı uygulama katmanında
 * ("önce bak, sonra yaz") kurmak, iki eşzamanlı işçi arasında hiçbir şey
 * garanti etmez — kontrol ile yazma arasındaki pencere tam olarak o beş
 * mesajın çıktığı yerdir. Tek doğru kilit veritabanındadır ve
 * `insertOrIgnore` ile atomiktir.
 *
 * NULL REFERANSLAR BİLİNÇLİ OLARAK **AYRI SAYILIR.** MySQL benzersiz
 * indekste NULL'ları birbirinden ayrı görür (aynı davranış
 * `veykemtu_daily_menu_stock` göçünde NULL nöbetçiyi reddettirmişti).
 * Burada bu tam olarak istenen şeydir: referansı olmayan bir gönderim
 * (deneme SMS'i, toplu duyuru) tekilleştirilecek bir "olay"a bağlı
 * değildir; 500 alıcıya giden duyurunun 500 satır yazması gerekir.
 * İdempotans yalnızca REFERANSI OLAN mesajlar için vardır ve orada
 * gerçekten uygulanır.
 * ─────────────────────────────────────────────────────────────────────────
 *
 * `otp_login` BU LİSTEDE YOKTUR ve olmayacaktır (`docs/control/sms.md`):
 * giriş kodu metni `OtpService` içindedir. Panelden düzenlenebilir olsaydı,
 * kodun kendisini metinden çıkarmak ya da metne bağlantı gömmek tek
 * satırlık bir değişiklik olurdu.
 */
return new class extends Migration
{
    /**
     * Sabit şablon kümesi — anahtarlar `docs/control/sms.md` tablosundan.
     *
     * `dailymenu.announce` o tablonun dışındadır ve B1 ile geliyor: günün
     * menüsü duyurusu zamanlanmış bir iştir (`veykemtu:menu-duyur`),
     * panelden elle tetiklenen `announcement` toplu duyurusuyla aynı şey
     * değildir. Aynı satıra sıkıştırılsalardı, birini açmak ötekini de
     * açardı.
     *
     * BAŞLIKLAR `Control\SmsController::TEMPLATES` SÖZLÜĞÜYLE BİREBİR.
     * O denetleyici `PATCH /templates/{key}` içinde `updateOrInsert` ile
     * başlığı kendi sözlüğünden yeniden yazıyor; ayrışsalardı aynı şablon
     * panelde bir, veritabanında başka bir adla görünürdü.
     *
     * @var list<array{key: string, title: string, body: string}>
     */
    private const array TEMPLATES = [
        [
            'key' => 'order_created',
            'title' => 'Sipariş alındı',
            'body' => 'Sayın {customer_name}, {service_date} tarihli {order_no} numaralı '
                .'siparişiniz alındı. Tutar: {total} TL.',
        ],
        [
            'key' => 'order_confirmed',
            'title' => 'Sipariş onaylandı',
            'body' => '{order_no} numaralı siparişiniz onaylandı. Servis günü: {service_date}.',
        ],
        [
            'key' => 'order_on_the_way',
            'title' => 'Kurye yola çıktı',
            'body' => '{order_no} numaralı siparişiniz yola çıktı. Tahmini teslim: {eta}.',
        ],
        [
            'key' => 'order_delivered',
            'title' => 'Teslim edildi',
            'body' => '{order_no} numaralı siparişiniz teslim edildi. Afiyet olsun.',
        ],
        [
            'key' => 'order_cancelled',
            'title' => 'Sipariş iptal edildi',
            'body' => '{order_no} numaralı, {service_date} tarihli siparişiniz iptal edildi. '
                .'Sebep: {reason}',
        ],
        [
            'key' => 'order_revised',
            'title' => 'Sipariş düzenlendi',
            'body' => '{order_no} numaralı siparişiniz güncellendi. Sebep: {reason}',
        ],
        [
            'key' => 'subscription_contract',
            'title' => 'Sözleşme bağlantısı',
            'body' => 'Sayın {customer_name}, abonelik sözleşmeniz hazır: {link} '
                .'Bağlantı {expires_at} tarihine kadar geçerlidir.',
        ],
        [
            'key' => 'subscription_payment_due',
            'title' => 'Dönem borcu hatırlatma',
            'body' => 'Sayın {customer_name}, {period} dönemi aboneliğiniz için {amount} TL '
                .'ödemeniz {due_date} tarihinde beklenmektedir.',
        ],
        [
            'key' => 'invoice_issued',
            'title' => 'Fatura belgesi kesildi',
            'body' => '{invoice_no} numaralı belgeniz hazır. Tutar: {total} TL. {link}',
        ],
        [
            // Metni panelden yazılır (`bld_sms_announcement_body`); bu satır
            // anahtarın PATCH edilebilmesi ve açma/kapama anahtarının bir
            // yerde durması için var.
            'key' => 'announcement',
            'title' => 'Toplu duyuru',
            'body' => 'Sayın {customer_name}, bir duyurumuz var.',
        ],
        [
            'key' => 'dailymenu.announce',
            'title' => 'Günün menüsü duyurusu',
            'body' => 'Sayın {customer_name}, {date} günü menümüz: {menu}. '
                .'Siparişleriniz için bekliyoruz.',
        ],
    ];

    public function up(): void
    {
        $this->createTemplates();
        $this->createLog();
        $this->seedTemplates();
    }

    public function down(): void
    {
        Schema::dropIfExists('veykemtu_sms_log');
        Schema::dropIfExists('veykemtu_sms_templates');
    }

    private function createTemplates(): void
    {
        if (Schema::hasTable('veykemtu_sms_templates')) {
            return;
        }

        Schema::create('veykemtu_sms_templates', function (Blueprint $table): void {
            $table->bigIncrements('id');

            // Anahtar SABİTTİR: kodda `send('order_confirmed', …)` diye
            // geçer. Ayrı bir `id` var ama tekilliği asıl uygulayan bu
            // indeks — anahtarı birincil yapmak, ileride bir anahtarı
            // yeniden adlandırmayı yabancı anahtar avına çevirirdi.
            $table->string('key', 64)->unique('veykemtu_sms_sablon_anahtar');

            /*
             * `title`, `name` DEĞİL — ve bu bilinçli bir uyum.
             *
             * B1 planı kolonu `name` diye adlandırıyordu, ama panel
             * denetleyicisi (`Control\SmsController`) zaten yazılmış ve
             * `updateOrInsert(['key' => …], ['title' => …, …])` ile bu
             * kolona yazıyor. Ad ayrışsaydı `PATCH /templates/{key}`
             * "Unknown column 'title'" ile patlardı — ve yalnız o uç
             * çağrıldığında, ne açılışta ne göçte. Tüketici sözleşmeyi
             * sabitler, tablo ona uyar.
             */
            $table->string('title', 120);
            $table->string('body', 500);

            // ↓ VARSAYILAN 0. Dosya başındaki kutuya bakın.
            $table->boolean('enabled')->default(false);

            // Bugün tek dil var; kolon şimdi bedava, sonradan eklemek
            // "hangi satır hangi dilin" sorusunu geriye dönük çözmek demek.
            $table->string('locale', 5)->default('tr');

            // Kim düzenledi: panel kullanıcısı, Kontrol Merkezi ya da
            // konsol. Serbest metin — kaynaklar ayrı tablolarda yaşıyor ve
            // birini ötekinin kimliğiyle karıştırmak yanlış kişiyi suçlar
            // (`veykemtu_daily_menu_stock.updated_by` ile aynı gerekçe).
            $table->string('updated_by', 120)->nullable();

            $table->timestamps();
        });
    }

    private function createLog(): void
    {
        if (Schema::hasTable('veykemtu_sms_log')) {
            return;
        }

        Schema::create('veykemtu_sms_log', function (Blueprint $table): void {
            $table->bigIncrements('id');

            /*
             * `template_key` ve `phone` NULLABLE: panelin serbest metin
             * deneme gönderimi (`POST /send-test`, `body` ile) hiçbir
             * şablona bağlı değildir. NOT NULL olsalardı o uç, kaydı
             * yazamadığı için değil, kaydı yazarken patladığı için 500
             * dönerdi.
             */
            $table->string('template_key', 64)->nullable()->index('veykemtu_sms_log_sablon');

            // Normalleştirilmiş 10 hane (`5xxxxxxxxx`) — `OtpService::normalize`
            // ile aynı biçim. Ham biçim yazılsaydı "aynı numaraya ne gitti"
            // sorgusu yazıma göre bölünürdü.
            $table->string('phone', 16)->nullable();

            /*
             * KİMİN, HANGİ SİPARİŞİN, HANGİ ABONELİĞİN — üçü de nullable.
             *
             * `docs/control/sms.md` `GET /log` süzgeçlerinde bu üçünü
             * istiyor ve panel denetleyicisi zaten bunlara yazıyor. Ayrı
             * kolon olmaları `reference_type`/`reference_id` çiftiyle
             * çakışmıyor: o çift İDEMPOTANS ANAHTARIDIR (yazılabilir tek
             * bir üçlü), bunlar ise SORGU ALANIDIR. Tek bir çifte
             * yüklenseydi, "bu müşteriye ne gitti" sorgusu referans
             * türünün metnini ayrıştırmak zorunda kalırdı.
             */
            $table->unsignedBigInteger('customer_id')->nullable()->index('veykemtu_sms_log_musteri');
            $table->unsignedBigInteger('order_id')->nullable();
            $table->unsignedBigInteger('subscription_id')->nullable();

            // GÖNDERİLEN metnin kendisi, şablonun değil. Şablon yarın
            // düzenlenince dünkü kayıt yalan söylememeli.
            $table->string('body', 500);

            // Segment sayısı DOĞRUDAN MALİYETTİR ve satır bazında
            // saklanıyor: şablon sonradan kısaltılırsa dünkü mesajın kaça
            // mal olduğu bilgisi kaybolmamalı (`meta.segment_total`).
            $table->unsignedTinyInteger('segments')->default(1);

            // sent | failed | skipped | dry_run
            $table->string('status', 16);

            $table->string('provider_ref', 64)->nullable();
            $table->string('error', 255)->nullable();

            // auto | test | announcement — otomatik tetiklenen bir mesajı
            // yöneticinin elle attığı denemeden ayırır. Şikâyet geldiğinde
            // sorulan ilk soru budur.
            $table->string('context', 32)->default('auto');

            // Mesajın bağlı olduğu olay: `order`, `subscription`,
            // `dailymenu:2026-08-23` … Serbest metin, çünkü referans
            // kaynakları ayrı tablolarda ve morph haritasına bağlamak bu
            // kaydı çekirdek modellerin ömrüne zincirlerdi.
            $table->string('reference_type', 32)->nullable();
            $table->unsignedBigInteger('reference_id')->nullable();

            /*
             * İKİ ZAMAN DAMGASI, AYNI AN — ve bu bir uzlaşma.
             *
             * `created_at` satırın doğuşu (B1 sözleşmesi), `sent_at`
             * panelin sıraladığı ve `from`/`to` ile süzdüğü alan
             * (`docs/control/sms.md`, `Control\SmsController`). Ayrışmıyorlar
             * çünkü satır gönderim DENEMESİYLE BİRLİKTE doğuyor; ikisini
             * tek kolona indirmek iki kulvardan birinin sözleşmesini
             * kırardı ve o kırık yalnız uç çağrılınca görünürdü.
             *
             * `sent_at` BAŞARISIZ SATIRLARDA DA DOLU: boş bırakılsaydı
             * `GET /log?status=failed&from=…` hiçbir şey döndürmezdi — yani
             * tam da hataları aramaya gelen kişi hiçbir şey bulamazdı.
             *
             * `updated_at` YOK: satır bir olay kaydıdır, düzenlenmez.
             */
            $table->timestamp('created_at')->nullable()->index('veykemtu_sms_log_zaman');
            $table->timestamp('sent_at')->nullable()->index('veykemtu_sms_log_gonderim');

            // ↓ İDEMPOTANS KAPISI. Dosya başındaki kutuya bakın.
            $table->unique(
                ['template_key', 'reference_type', 'reference_id'],
                'veykemtu_sms_log_essiz',
            );
        });
    }

    /**
     * Sabit anahtarları yazar — hepsi KAPALI.
     *
     * `insertOrIgnore`: göç yeniden koşarsa yöneticinin açtığı anahtar
     * tekrar kapanmaz, düzenlediği metin ezilmez.
     */
    private function seedTemplates(): void
    {
        $now = now();

        $rows = array_map(static fn(array $t): array => [
            'key' => $t['key'],
            'title' => $t['title'],
            'body' => $t['body'],
            'enabled' => false,
            'locale' => 'tr',
            'updated_by' => 'migration',
            'created_at' => $now,
            'updated_at' => $now,
        ], self::TEMPLATES);

        DB::table('veykemtu_sms_templates')->insertOrIgnore($rows);
    }
};
