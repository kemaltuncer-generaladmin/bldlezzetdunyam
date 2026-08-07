<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Kurumsal sitedeki "Teklif Al" formunun talepleri.
 *
 * ## Neden tablo, neden dış servis değil?
 *
 * Form bugüne kadar `QUOTE_WEBHOOK_URL` ile dışarıya POST ediyordu ve o
 * değişken tanımsız olduğu için gelen her talep kayboluyordu. Bir e-posta
 * servisine bağlamak sorunu taşırdı: firma sahibinin gelen kutusuna düşen
 * talebin "cevaplandı mı" bilgisi hiçbir yerde durmaz, ikinci bir kişi aynı
 * müşteriyi tekrar arar. Talep zaten her gün açılan panelde, durumuyla
 * birlikte durmalı.
 *
 * ## KİŞİSEL VERİ TABLOSUDUR
 *
 * `full_name`, `telephone`, `email` KVKK kapsamında kişisel veridir ve bu
 * tablo sistemdeki tek "müşteri olmayan kişi" havuzudur. Bu yüzden:
 *
 *  - Onay ZAMAN DAMGASIYLA saklanır (`kvkk_accepted_at`), boolean ile değil.
 *    Bir denetimde sorulan soru "onayladı mı" değil, "ne zaman onayladı"dır;
 *    boolean o soruya cevap veremez. Onaysız kayıt hiç oluşmaz — uç 422 döner.
 *  - Ekranın yetkisi ayrıdır (`AdminRegistrar::PERMISSION_QUOTES`); gerekçesi
 *    o sabitin üzerindedir.
 *  - Ziyaretçinin IP'si SAKLANMIYOR. Spam'i oran sınırı durduruyor; IP'yi
 *    tutmak, işe yaramayacağı bir yerde bir kişisel veri daha biriktirmek
 *    olurdu.
 *
 * ## Alanların çoğu neden `nullable`?
 *
 * Uç bilinçli olarak GEVŞEK doğrular (gerekçe `QuoteRequestController`
 * üzerinde). Sıkı `NOT NULL` sütunlar, sitenin bir alanı boş göndermesi
 * hâlinde talebi veritabanı seviyesinde reddederdi — yani müşteri kaybı.
 * Zorunlu olan tek şey ad ve onaydır; geri kalan eksik gelse bile talep
 * saklanır, firma telefonla tamamlar.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('veykemtu_quote_requests', function (Blueprint $table): void {
            $table->id();

            // ── Kim ────────────────────────────────────────────────────────
            $table->string('full_name', 120);
            $table->string('organization', 160)->nullable();
            // Telefon 32 hane: site 10 haneli gönderiyor ama uç ham metni de
            // kabul ediyor (uluslararası numara, dahili no). Kesip atmak
            // yerine yer bırakmak ucuz.
            $table->string('telephone', 32)->nullable();
            $table->string('email', 160)->nullable();

            // ── Ne isteniyor ───────────────────────────────────────────────
            // `enum` DEĞİL. Değerler `website/content/services.ts` slug'larından
            // geliyor ve site yeni bir hizmet eklediğinde önce orada doğar;
            // enum sütun o ilk talebi veritabanı hatasıyla kaybederdi.
            $table->string('service_type', 64)->nullable();
            $table->unsignedInteger('headcount')->nullable();
            $table->string('frequency', 32)->nullable();
            // Tek seferlik hizmetlerde etkinlik tarihi, sürekli hizmetlerde
            // başlangıç tercihi — ikisi de aynı sütun, ikisi de isteğe bağlı.
            $table->date('start_date')->nullable();
            $table->string('location', 160)->nullable();
            $table->string('menu_preference', 32)->nullable();
            $table->text('kitchen_note')->nullable();
            $table->text('message')->nullable();

            // ── Onay ve zaman ──────────────────────────────────────────────
            $table->timestamp('kvkk_accepted_at');
            // Sitenin bildirdiği gönderim anı. `created_at` ile aynı olmak
            // zorunda değil: site kuyruğa alıp gecikmeli iletebilir.
            $table->timestamp('submitted_at')->nullable();

            // ── Takip ──────────────────────────────────────────────────────
            // Varsayılan `yeni`; geçerli değerler `QuoteRequest::STATUSES`.
            $table->string('status', 16)->default('yeni');
            // Firma içi not. Ziyaretçiye HİÇ gösterilmez, API'den dönmez.
            $table->text('admin_note')->nullable();

            $table->timestamps();

            // Panelin varsayılan görünümü "önce yeni talepler, en yenisi
            // üstte" — filtre ve sıralama bu iki sütunu birlikte kullanıyor.
            $table->index(['status', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('veykemtu_quote_requests');
    }
};
