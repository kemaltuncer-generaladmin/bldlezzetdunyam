<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Kurumsal site içeriği — panelden yönetilir, siteye API ile gider.
 *
 * ## Neden üç tablo, tek tablo değil?
 *
 * İçeriğin iki farklı doğası var ve tek şemaya sıkıştırmak ikisini de bozardı:
 *
 * 1. **Kayıt olanlar** (hizmet, yazı) zamanla çoğalır, kendi adresi olur,
 *    taslakta bekler, sıralanır. Bunlar satır olmalı — yoksa panelde tek bir
 *    devasa alanın içinde düzenlenir, taslak/yayın ayrımı yapılamaz ve iki
 *    kişi aynı anda kaydettiğinde biri diğerinin yazısını ezer.
 *
 * 2. **Sınırlı listeler** (iletişim, SSS, sektörler, kalite zinciri) sabit
 *    sayıda ve birlikte okunur. Bunlar için ayrı tablo açmak, dört maddelik
 *    bir SSS'yi yönetmek üzere panele ayrı bir bölüm koymak demekti.
 *    `veykemtu_site_content` bunları anahtar → JSON olarak tutar.
 *
 * ## `body_html` neden var?
 *
 * Kart ve ızgaraları besleyen alanlar yapılandırılmıştır (başlık, özet, madde
 * listesi) — görsel düzen oradan doğuyor. `body_html` bunun yanında serbest
 * anlatım için: zengin metin editöründen gelir, KAYDEDİLİRKEN izin listesine
 * göre temizlenir (`HtmlPurifier`). Ham HTML'e güvenilmez; panelde yetkisi
 * olan biri kötü niyetli olmasa da yapıştırdığı Word içeriği sayfayı bozar.
 */
return new class extends Migration
{
    public function up(): void
    {
        // ── Sınırlı listeler ve tekil değerler: anahtar → JSON ──────────────
        Schema::create('veykemtu_site_content', function (Blueprint $table): void {
            // Anahtar kod olarak sabittir (`contact`, `faq`, `sectors` …);
            // site bu anahtarlara göre okur, yönetici anahtarı değiştiremez.
            $table->string('key', 64)->primary();
            $table->json('value');
            $table->timestamps();
        });

        // ── Hizmetler ──────────────────────────────────────────────────────
        Schema::create('veykemtu_site_services', function (Blueprint $table): void {
            $table->id();
            // Adres parçası. Değişirse eski bağlantı kırılır; bu yüzden panelde
            // düzenlenebilir ama uyarı gösterilir.
            $table->string('slug', 96)->unique();
            $table->string('title', 160);
            $table->string('summary', 400);
            $table->text('intro');
            // Lucide ikon adı (`Building2`, `Truck` …). Site bilinmeyen adı
            // sessizce varsayılana düşürür, boş kutu göstermez.
            $table->string('icon', 48)->default('UtensilsCrossed');
            /** @see veykemtu_site_content yorumu — serbest anlatım alanı. */
            $table->text('body_html')->nullable();
            // Kimler için / nasıl işler / ne kazandırır / teklif için gerekenler.
            $table->json('audience');
            $table->json('how_it_works');
            $table->json('benefits');
            $table->text('menu_planning');
            $table->json('quote_needs');
            $table->unsignedSmallInteger('sort_order')->default(0);
            $table->boolean('is_published')->default(true);
            $table->timestamps();

            // Site yalnızca yayınlananları sıralı çeker; sorgu bu iki sütunu
            // birlikte kullanıyor.
            $table->index(['is_published', 'sort_order']);
        });

        // ── Bilgi merkezi yazıları ─────────────────────────────────────────
        Schema::create('veykemtu_site_posts', function (Blueprint $table): void {
            $table->id();
            $table->string('slug', 96)->unique();
            $table->string('title', 200);
            $table->string('description', 400);
            $table->string('category', 64);
            $table->text('body_html');
            // Yayın tarihi yazarın kararı; `created_at` ile aynı olmak zorunda
            // değil (geçmişe tarihli yazı, ileri tarihli planlama).
            $table->date('published_at');
            // Okuma süresi elle girilebilir; boşsa gövdeden hesaplanır.
            $table->unsignedSmallInteger('reading_minutes')->nullable();
            $table->boolean('is_published')->default(true);
            $table->timestamps();

            $table->index(['is_published', 'published_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('veykemtu_site_posts');
        Schema::dropIfExists('veykemtu_site_services');
        Schema::dropIfExists('veykemtu_site_content');
    }
};
