<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Hata olayları — durum monitörünün tek havuzu (`docs/control/monitor.md`).
 *
 * Dört bileşenin (sunucu, KDS kasası, mobil, site) hataları burada
 * buluşuyor. "Bir şey çalışmıyor" şikâyeti geldiğinde bakılacak ilk ekran
 * bu tabloyu okur.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * `fingerprint` ÜZERİNDEKİ UNIQUE, TASARIMIN TAMAMIDIR.
 *
 * Tek bir çökme döngüsü aynı hatayı dakikada yüzlerce kez üretir: yazıcıya
 * ulaşamayan bir kasa her yoklamada, sonsuz döngüye giren bir ekran her
 * karede. Her tekrar ayrı satır olsaydı bir öğleden sonra bu tabloya bir
 * milyon satır yazılır, monitör ekranı açılamaz hâle gelir ve GERÇEK hata
 * — yanında duran, bir kez olmuş, kimsenin göremediği satır — kaybolurdu.
 *
 * Benzersiz parmak izi sayesinde aynı hata TEK satırdır ve tekrar yalnızca
 * `occurrences` sayacını artırır. Sayaç bilgi kaybı değil, bilgi kazancıdır:
 * "47 kez oldu" cümlesi 47 satırdan daha çok şey anlatır.
 *
 * Kısıt VERİTABANINDA, uygulamada değil: iki eşzamanlı istek "önce ara,
 * yoksa yaz" yaparsa ikisi de "yok" görüp iki satır yazar. Yarış bugün
 * değil, tablo büyüdüğü gün ortaya çıkar.
 * ─────────────────────────────────────────────────────────────────────────
 *
 * `first_seen_at` HİÇ DEĞİŞMEZ — "bu ne zamandır oluyor" sorusunun cevabı.
 * `last_seen_at` her tekrarda ilerler — "hâlâ oluyor mu" sorusunun cevabı.
 * İkisi tek kolona indirilseydi, üç haftadır süren bir arıza ile beş dakika
 * önce başlayan bir arıza panelde aynı görünürdü.
 *
 * `source` SUNUCUDA TÜRETİLİR (`X-App-Id`), gövdeden okunmaz — gerekçe
 * `ClientErrorController` sınıf yorumunda.
 *
 * SAKLAMA ŞART: `veykemtu:hata-temizle` (03:30) çözülmüş satırları 30,
 * çözülmemişleri 90 günden sonra siler. Saklama kuralı olmadan bu tablo,
 * hiç kimsenin silmeyi düşünmediği için diski dolduran tablo olurdu.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('veykemtu_error_events')) {
            return;
        }

        Schema::create('veykemtu_error_events', function (Blueprint $table): void {
            $table->bigIncrements('id');

            // `server` | `kds` | `mobile` | `website`. Enum DEĞİL: yeni bir
            // bileşen (ör. kurye uygulaması) eklendiğinde göç beklemek,
            // o bileşenin hatalarını hiç görememek demek olurdu.
            $table->string('source', 16)->index('veykemtu_hata_kaynak');
            $table->string('level', 16)->index('veykemtu_hata_seviye');

            /*
             * Toplama anahtarı — SHA-1, 40 onaltılık hane.
             *
             * Kriptografik güç aranmıyor; aranan, aynı hatanın iki
             * tekrarının aynı dizeyi üretmesi. Sabit genişlikte `char`
             * seçildi: benzersiz indeksin dayandığı kolon değişken
             * uzunlukta olsaydı indeks gereksiz yere büyürdü.
             */
            $table->char('fingerprint', 40)->unique('veykemtu_hata_izi');

            $table->string('type', 120)->nullable();
            $table->string('message', 500);
            $table->text('stack')->nullable();

            // Serbest bağlam: rota, cihaz, yapı numarası, ekrandaki kayıt
            // kimliği. JSON çünkü dört bileşenin dördü de farklı şeyler
            // biliyor ve hepsini kolona açmak, çoğu satırda boş duran
            // otuz kolon demekti.
            $table->json('context')->nullable();

            // Hatanın İSTEMCİDE oluştuğu an. Sunucunun alış anı
            // (`last_seen_at`) ayrı tutuluyor: ikisi arasındaki fark,
            // çevrimdışıyken biriktirilip sonra gönderilen raporları
            // ayırt eden tek işarettir.
            $table->dateTime('occurred_at')->nullable()->index('veykemtu_hata_an');

            $table->dateTime('first_seen_at');
            $table->dateTime('last_seen_at')->index('veykemtu_hata_son');

            $table->unsignedInteger('occurrences')->default(1);

            /*
             * ÇÖZÜM İŞARETİ, SİLME DEĞİL. Bir hata kaydını silmek o hatanın
             * hiç olmadığını iddia etmektir; çözülen olay işaretlenir ve
             * varsayılan süzgeçten düşer (`docs/control/monitor.md`:
             * "`DELETE` yoktur").
             *
             * `resolved_by` SERBEST METİN: Kontrol Merkezi ayrı bir depo,
             * ayrı bir kullanıcı tablosu. Yabancı anahtar iki sistemi
             * birbirine bağlardı.
             */
            $table->dateTime('resolved_at')->nullable()->index('veykemtu_hata_cozum');
            $table->string('resolved_by', 120)->nullable();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('veykemtu_error_events');
    }
};
