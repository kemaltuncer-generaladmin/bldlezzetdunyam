<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Fatura belgesi ve numara sayacı — `docs/control/invoices.md` (B2).
 *
 * BU BELGENİN MALİ DEĞERİ YOKTUR. e-Fatura değil, e-Arşiv değil, GİB'e
 * gitmiyor, KDV hesaplamıyor. Müşterinin "bir belge verin" talebini
 * karşılayan, yazdırılabilir bir A4 dökümüdür. Yine de numarası boşluksuz:
 * gerçek entegrasyon bir gün buraya takılacaksa, o gün geriye dönük
 * numaralandırma yapmak imkânsız olur.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * NEDEN AYRI BİR SAYAÇ TABLOSU — `MAX(sequence)+1` ASLA
 *
 * `SELECT MAX(sequence)+1 FROM veykemtu_invoices` eşzamanlı iki kesimde
 * AYNI sayıyı döndürür: ikisi de aynı en büyük değeri okur, ikisi de bir
 * ekler. Sonra `UNIQUE(series, year, sequence)` ikincisini reddeder ve
 * kullanıcı yazdır düğmesinde 500 görür. Hata ayıklaması en zor an, en
 * yoğun andır.
 *
 * `veykemtu_invoice_counters` bunun yerine TEK BİR SATIR kilitletir:
 * `SELECT ... FOR UPDATE` ile satır işlem sonuna kadar tutulur, ikinci
 * kesim bekler ve artmış değeri okur. Sıra tablosu belge tablosundan
 * bağımsızdır — belge silinse bile (silinmiyor; `DELETE` yok) numara geri
 * kullanılmaz.
 *
 * Bileşik birincil anahtar `(series, year)`: sıra YIL BAŞINDA SIFIRLANIR ve
 * her seri kendi sayacını taşır. Yeni yılın ilk kesimi satırı kendisi açar.
 * ─────────────────────────────────────────────────────────────────────────
 *
 * KOLON ADLARI DONMUŞ SÖZLEŞMEDEN: `invoice_no`, `status`, `void_at`,
 * `void_reason`, `created_by_actor` adlarını `docs/control/invoices.md`
 * sabitliyor ve `Control\OrderController::invoiceOf()` bu adlarla ZATEN
 * okuyor (`Schema::hasTable` arkasında bekliyor). Başka bir ad seçmek,
 * tablo doğduğu gün o denetleyiciyi "undefined property" ile düşürürdü.
 * `series`/`year`/`sequence`, `type`, `replaces_invoice_id`, tutar kırılımı
 * ve `pdf_path` sözleşmenin üstüne EKLENEN alanlardır.
 *
 * `replaces_invoice_id` BUGÜN KULLANILMASA BİLE VAR: düzeltme, belgeyi
 * düzenlemek değil, eskisini iptal edip yenisini kesmektir; yeni belge
 * hangisinin yerine geçtiğini taşımalı. Kolonu sonradan eklemek, o güne
 * kadar kesilmiş bütün düzeltmeleri elle geriye doldurmak demek.
 *
 * `pdf_path` NULLABLE VE BUGÜN BOŞ: v1'de PDF üretilmiyor (dompdf/mpdf gibi
 * yeni bir bağımlılık AGENTS §4/§6.3 gereği ayrı bir karar). Belge
 * `GET /api/control/invoices/{id}/html` ile basılıyor. Kolon, o karar
 * verildiğinde şema değişikliği gerekmesin diye şimdiden duruyor.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('veykemtu_invoice_counters')) {
            Schema::create('veykemtu_invoice_counters', function (Blueprint $table): void {
                // Seri kodu — bugün tek seri var (`BLD`). Kolon, ileride
                // ayrı bir seri (örn. abonelik) açılırsa numara alanını
                // ayrıştırmak için duruyor.
                $table->string('series', 8);
                $table->unsignedSmallInteger('year');

                // BİR SONRAKİ sıra — kesilmiş son sıra DEĞİL. Fark önemli:
                // satır ilk kez 1 ile doğar ve ilk kesim 1'i alır; "son
                // kesilen" tutulsaydı boş sayaç için 0/null ayrımı
                // gerekirdi.
                $table->unsignedInteger('next_sequence')->default(1);

                $table->timestamps();

                $table->primary(['series', 'year'], 'veykemtu_fatura_sayac_pk');
            });
        }

        if (Schema::hasTable('veykemtu_invoices')) {
            return;
        }

        Schema::create('veykemtu_invoices', function (Blueprint $table): void {
            $table->bigIncrements('id');

            // `{seri}-{yıl}-{sıra:6}` → `BLD-2026-000001`. Tekil indeks
            // sayaç kilidinin SON güvencesidir; kilit bir gün bozulursa
            // yanlış numara basılmaz, istek patlar.
            $table->string('invoice_no', 32)->unique('veykemtu_fatura_no_essiz');

            // Numaranın parçaları ayrı kolonlarda: "2026'nın kaçıncı
            // belgesi" sorusu bir dize ayrıştırmadan cevaplanmalı ve
            // boşluksuzluk denetimi (`sequence` sürekliliği) tek sorgu
            // olmalı.
            $table->string('series', 8);
            $table->unsignedSmallInteger('year');
            $table->unsignedInteger('sequence');

            // order | subscription | void — belgenin TÜRÜ.
            $table->string('type', 16);

            // issued | void — BU belgenin yaşam durumu. `type` ile
            // karıştırılmamalı: `type` belgenin ne olduğunu, `status`
            // hâlâ geçerli olup olmadığını söyler.
            $table->string('status', 16)->default('issued')->index();

            // Bu belge hangi belgenin yerine kesildi. Fatura DÜZENLENMEZ.
            $table->unsignedBigInteger('replaces_invoice_id')->nullable();

            $table->unsignedBigInteger('order_id')->nullable()->index();
            $table->unsignedBigInteger('subscription_id')->nullable()->index();
            $table->unsignedBigInteger('subscription_payment_id')->nullable();
            $table->unsignedBigInteger('customer_id')->index();

            $table->timestamp('issued_at')->index();

            // Dönem belgesinde dolu, sipariş belgesinde boş.
            $table->date('period_start')->nullable();
            $table->date('period_end')->nullable();

            $table->char('currency', 3)->default('TRY');

            // Para TAM SAYI KURUŞ. Kırılım ayrı kolonlarda çünkü belge
            // ara toplam / teslimat / toplam satırlarını ayrı basıyor ve
            // bunları `snapshot_json` içinden sorgulamak (rapor, toplam)
            // JSON ayrıştırması demekti.
            $table->bigInteger('subtotal_kurus')->default(0);
            $table->bigInteger('delivery_kurus')->default(0);
            $table->bigInteger('total_kurus')->default(0);

            // BELGENİN DONMUŞ İÇERİĞİ. Belge canlı tablodan çizilseydi,
            // müşteri adı ya da ürün fiyatı değiştiğinde aynı belge iki
            // farklı kâğıt üretirdi. HTML render'ı YALNIZ buradan okur.
            $table->json('snapshot_json');

            // v1'de boş; PDF kararı verildiğinde dolar.
            $table->string('pdf_path', 255)->nullable();

            $table->timestamp('void_at')->nullable();
            $table->string('void_reason', 255)->nullable();

            // Kim kesti — Kontrol Merkezi kullanıcısı ya da `sistem`
            // (auto_invoice). Serbest metin: kaynaklar ayrı tablolarda
            // yaşıyor ve birini ötekinin kimliğiyle karıştırmak yanlış
            // kişiyi suçlar.
            $table->string('created_by_actor', 120);

            $table->timestamps();

            // BOŞLUKSUZLUĞUN ŞEMADAKİ GÜVENCESİ.
            $table->unique(['series', 'year', 'sequence'], 'veykemtu_fatura_sira_essiz');

            // Müşterinin belgeleri, en yeniden eskiye — panelin ilk
            // ekranı bu sorgu.
            $table->index(['customer_id', 'issued_at'], 'veykemtu_fatura_musteri_tarih');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('veykemtu_invoices');
        Schema::dropIfExists('veykemtu_invoice_counters');
    }
};
