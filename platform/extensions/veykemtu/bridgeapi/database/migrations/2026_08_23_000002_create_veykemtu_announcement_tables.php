<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Uygulama-içi duyurular — `docs/openapi.yaml` §Duyuru.
 *
 * PUSH (FCM) YOK. Müşteriye ulaşmanın iki yolu kaldı: SMS ve bu tablo.
 * Duyuru yalnız istemci açıkken çekilir; "teslim edildi" diye bir kavram
 * yoktur, "ekranda çizildi" vardır (`veykemtu_announcement_reads.seen_at`).
 *
 * ─────────────────────────────────────────────────────────────────────────
 * OKUMA TABLOSU BU ÖZELLİĞİN YARISIDIR — süs değil.
 *
 * Duyuru "açılışta göster" mantığıyla çiziliyor. Kapatma işareti sunucuda
 * tutulmasaydı müşteri aynı bandı her açılışta, her cihazda yeniden görürdü
 * ve duyuru bir süre sonra okunmadan kapatılan bir gürültüye dönerdi.
 * İşaret istemci yerelinde tutulsaydı da web'de kapatılan duyuru mobilde
 * yeniden açılırdı — üç istemcinin üç ayrı hafızası olurdu.
 *
 * Aynı satır Kontrol Merkezi'nin "kaç kişi gördü / kaç kişi kapattı"
 * istatistiğini de besliyor; duyurunun işe yarayıp yaramadığını gösteren
 * tek ölçü budur.
 * ─────────────────────────────────────────────────────────────────────────
 *
 * `UNIQUE(announcement_id, customer_id)` müşteri başına TEK satır garantisi
 * verir: `seen` ile `dismiss` ayrı uçlar ve ikisi de aynı satırı yazıyor.
 * Kısıt olmasaydı, iki isteği aynı anda gönderen bir istemci (duyuru
 * çizildi + hemen kapatıldı) iki satır yazar ve kapatma işareti görülme
 * işaretiyle yarışırdı — duyuru bazen kapanmış, bazen kapanmamış görünürdü.
 *
 * `placement` ve `severity` KOLONLARI SÖZLEŞMEDEN GELİYOR
 * (`Announcement` şeması: `placement` zorunlu alan, `severity` enum).
 * `style` ile karıştırılmamalı: `placement` duyurunun HANGİ EKRANDA
 * duracağını, `style` NASIL çizileceğini (bant mı kart mı), `severity` ise
 * TONUNU söyler. Üçü tek kolona sıkıştırılsaydı "ana sayfada kart olarak
 * duran kritik duyuru" ifade edilemezdi.
 *
 * `placement` KAPALI ENUM DEĞİLDİR (sözleşme): yerleşimler panelde
 * tanımlanıyor ve yeni bir ekran açıldığında sözleşmeyi beklemek duyurunun
 * haftalarca yayınlanamaması demek olurdu. Bu yüzden kolon `string`,
 * `enum` değil.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('veykemtu_announcements')) {
            Schema::create('veykemtu_announcements', function (Blueprint $table): void {
                $table->bigIncrements('id');

                // Sözleşmede `title` boş olabilir (`[string, 'null']`):
                // kısa bir bant duyurusunun başlığa ihtiyacı yok, gövde
                // tek cümledir.
                $table->string('title', 120)->nullable();
                $table->string('body', 1000);

                // Görsel YOLU saklanıyor, URL DEĞİL. URL alan adı ya da
                // şema değiştiğinde (http → https, alan adı taşınması)
                // tablodaki bütün satırlar bir anda kırık bağlantıya
                // dönerdi; yol ise sunucudan bağımsızdır.
                $table->string('image_path')->nullable();

                $table->string('placement', 32)->default('home');
                $table->string('severity', 16)->default('info');
                $table->string('style', 16)->default('banner');

                /*
                 * EYLEM ÜÇ PARÇADIR ve üçü de ayrı kolonda:
                 *
                 *   `action_label` düğmenin metni — boşsa DÜĞME ÇİZİLMEZ
                 *                  (sözleşme).
                 *   `action_type`  hedefin cinsi (uygulama-içi yol mu, dış
                 *                  bağlantı mı). İstemci bunu bilmeden
                 *                  tanımadığı bir yolu tarayıcıda açmaya
                 *                  kalkar.
                 *   `action_value` hedefin kendisi.
                 *
                 * Tek kolona ("url") indirilseydi uygulama-içi bir yol ile
                 * dış bağlantı ayırt edilemezdi; istemci `/siparislerim`
                 * yolunu tarayıcıda açıp müşteriyi uygulamadan çıkarırdı.
                 */
                $table->string('action_label', 80)->nullable();
                $table->string('action_type', 16)->nullable();
                $table->string('action_value', 500)->nullable();

                /*
                 * KİTLE SUNUCUDA SÜZÜLÜR.
                 *
                 * "Aboneliğinizi yenileyin" duyurusunu abone olmayana
                 * göstermek, satın alması gereken şeyi zaten satın almış
                 * müşteriye "al" demek kadar kötüdür. Süzgeç istemciye
                 * bırakılsaydı üç istemci aynı kuralı üç kez yazardı ve
                 * biri unutulduğunda yanlış kitle duyuruyu görürdü.
                 */
                $table->string('audience', 16)->default('all');

                // Pencere: `null` = sınırsız. İkisi de indeksli çünkü
                // listeleme sorgusu her açılışta ikisine birden vuruyor.
                $table->dateTime('starts_at')->nullable();
                $table->dateTime('ends_at')->nullable();

                // Sıralama ağırlığı. Aynı anda üç duyuru yayındaysa hangisi
                // üstte durur sorusunun cevabı; `critical` olanlar zaten
                // önde (denetleyicideki sıralama yorumuna bakın).
                $table->integer('priority')->default(0);

                // `draft` doğar: kaydedilir kaydedilmez yayına giren bir
                // duyuru, yarım yazılmış metni bütün müşterilere gösterirdi.
                $table->string('status', 16)->default('draft');

                $table->boolean('dismissible')->default(true);

                // Duyuruyu kim yazdı (panel kullanıcısı). Yabancı anahtar
                // YOK: kullanıcı silindiğinde duyurunun kaybolması değil,
                // yazarının bilinmemesi doğru davranıştır.
                $table->unsignedInteger('created_by')->nullable();

                $table->timestamps();

                // Listeleme sorgusunun tam kalıbı: yayında + pencerede.
                $table->index(['status', 'placement'], 'veykemtu_duyuru_durum');
                $table->index('starts_at', 'veykemtu_duyuru_baslangic');
                $table->index('ends_at', 'veykemtu_duyuru_bitis');
            });
        }

        if (Schema::hasTable('veykemtu_announcement_reads')) {
            return;
        }

        Schema::create('veykemtu_announcement_reads', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->unsignedBigInteger('announcement_id');
            $table->unsignedBigInteger('customer_id');

            /*
             * İKİ AYRI DAMGA, TEK SATIR.
             *
             * `seen_at` duyuruyu listeden DÜŞÜRMEZ, `dismissed_at` düşürür.
             * Tek bir bayrağa indirilseydi ekranda çizilen her duyuru ilk
             * karede kaybolurdu — müşteri okumaya fırsat bulamazdı.
             *
             * `seen_at` İLK görülme anıdır ve bir daha DEĞİŞMEZ: "bu duyuru
             * müşteriye ne zaman ulaştı" sorusunun cevabı, en son ne zaman
             * ekranda belirdiği değildir.
             */
            $table->dateTime('seen_at')->nullable();
            $table->dateTime('dismissed_at')->nullable();

            $table->unique(
                ['announcement_id', 'customer_id'],
                'veykemtu_duyuru_okuma_essiz',
            );

            // Listeleme her açılışta "bu müşterinin işaretleri" diye
            // soruyor; benzersiz indeks duyurudan başladığı için o soruya
            // yardım etmiyor.
            $table->index('customer_id', 'veykemtu_duyuru_okuma_musteri');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('veykemtu_announcement_reads');
        Schema::dropIfExists('veykemtu_announcements');
    }
};
