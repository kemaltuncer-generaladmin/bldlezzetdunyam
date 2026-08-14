<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * K-21: Kontrol Merkezi denetim izi.
 *
 * NEDEN SUNUCUDA, KONTROL MERKEZİ'NDE DEĞİL: gerekçeyi ve aktörü karşı
 * tarafın kaydetmesine güvenmek, kaydı isteyen tarafın kendi kendini
 * denetlemesi olurdu. Kontrol Merkezi arayüzünde gerekçe alanını
 * gizlemek ya da otomatik doldurmak tek satırlık bir değişiklik; sunucu
 * `reason`'ı ZORUNLU kılıyor ve BURAYA yazıyor. Aynı ilke KM tarafında
 * K9 ile konuldu.
 *
 * "Kim, ne zaman, hangi kasayı iptal etti ve neden" sorusunun cevabı bu
 * tablodur. Cihaz iptali mutfağı sipariş göremez hâle getirir; sipariş
 * revizyonu para hareketi üretir. İkisi de birilerinin sonradan hesabını
 * sorabileceği eylemler.
 *
 * SATIR SİLİNMEZ VE GÜNCELLEME YALNIZ SONUCA DOKUNUR. `result` alanı
 * `pending` doğar, işlem bitince `applied` ya da `failed` olur; `actor`,
 * `action`, `reason` ve hedef bir daha değişmez. Silme yolu bilinçli
 * olarak açılmıyor — denetim izini silebilen bir denetim izi denetim
 * izi değildir (`AGENTS.md` §2 ile aynı ruh).
 *
 * `payload_json` İSTEĞİN ÖZETİDİR, TAM GÖVDESİ DEĞİL: yalnız o eylemi
 * anlamlandıran alanlar yazılır (hangi ayar, hangi komut, kaç kalem).
 * Ham gövdeyi saklamak müşteri notu gibi kişisel veriyi ikinci bir yerde
 * çoğaltırdı; hata durumunda ayrıca `error` anahtarı ekleniyor ki
 * "denedim, olmadı" sahada teşhis edilebilsin.
 *
 * ZAMAN DAMGASI TEK: `updated_at` yok. Bir denetim satırının "güncellenme
 * saati" diye bir kavramı olmamalı; `created_at` eylemin anıdır ve
 * `result` o anın sonucudur.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('veykemtu_control_audit', function (Blueprint $table): void {
            $table->id();

            // İşlemi yapan kişinin adı — Kontrol Merkezi'nin bildirdiği
            // serbest metin. BLD'de o kişinin bir hesabı yok ve olmayacak
            // (Kontrol Merkezi ayrı bir depo, ayrı bir kullanıcı tablosu);
            // yabancı anahtar vermek iki sistemi birbirine bağlardı.
            $table->string('actor', 120);

            // `device.revoke`, `order.revise` gibi nokta ayrılmış eylem adı.
            $table->string('action', 64)->index();

            // Hedef: `kitchen_device` / `order` / `null` (cihaz yaratma).
            $table->string('target_type', 32)->nullable();
            $table->unsignedBigInteger('target_id')->nullable();

            // En az 10 karakter — sunucu zorluyor. "test" yazıp geçmek
            // denetim izini işe yaramaz hâle getirirdi.
            $table->string('reason', 500);

            $table->json('payload_json')->nullable();

            // `pending` | `applied` | `failed` | `dry_run`
            $table->string('result', 32)->index();

            $table->timestamp('created_at')->nullable();

            // "Bu kasaya ne yapıldı" sorgusunun dayanağı.
            $table->index(['target_type', 'target_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('veykemtu_control_audit');
    }
};
