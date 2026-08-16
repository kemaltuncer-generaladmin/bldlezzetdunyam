<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Yayınlanmış uygulama sürümleri — `docs/05-mutfakapp.md` §9, görev `B-10`.
 *
 * `AppVersionController` bu tablodan okuyor ve tablo bugüne kadar HİÇ
 * OLUŞTURULMAMIŞTI: uç her çağrıda `fallback()`'e düşüp `download_url: null`
 * dönüyordu, yani sahada bir kasayı güncellemenin yolu yoktu.
 *
 * VARSAYIM (`AGENTS.md` §6): `docs/09-gorev-plani.md` `B-10` bu tabloyu ayrı
 * bir `veykemtu/appversion` eklentisine koyuyor. Tek tablo için ayrı bir
 * TastyIgniter eklentisi (composer.json, Extension.php, kayıt, autoload)
 * karşılığı olmayan bir iskele; tabloyu okuyan denetleyici zaten burada.
 * Karar geri alınabilir: eklenti bir gün gerekirse taşınacak olan bu göç
 * dosyası ile modeldir, şema aynı kalır.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('veykemtu_app_releases', function (Blueprint $table): void {
            $table->id();

            // `musteriapp` | `mutfakapp` — uçtaki `Rule::in` ile aynı küme.
            // Enum sütunu DEĞİL: yeni bir istemci eklendiğinde göç yazmak
            // gerekmesin; doğrulama zaten istek katmanında yapılıyor.
            $table->string('app_id', 16);

            $table->string('version', 32);

            // Bundan eski istemciler engelleyici güncelleme ekranı görür.
            $table->string('min_supported', 32);

            // Paketin adresi. GitHub Releases varlığını gösteriyor
            // (`infra/kasa/paketle.sh` yükler). `musteriapp` için boş
            // kalır: mağaza sürümlerinin indirme adresi olmaz.
            $table->string('download_url', 512)->nullable();

            // İNDİRİLENİN DOĞRULANDIĞI YER.
            //
            // `AppUpdater` tek başına yalnız `.deb`'in ilk sekiz baytına
            // (`!<arch>\n`) bakabiliyordu; yarım inmiş ama doğru başlayan
            // bir dosya o kontrolü geçer ve bozuk paket `dpkg-deb`'e kadar
            // gider. Kasa uzakta ve elle kurtarılması pahalı olduğu için
            // bütünlük tel üzerinde taşınmalı, tahmin edilmemeli.
            //
            // Nullable: eski satırlar ve `musteriapp` için doğal olarak boş.
            // Kasa tarafı boş özeti "doğrulama yok" diye ele alır, hata
            // değil — sürüm kaydı girilmiş bir kasayı kilitlemek istemiyoruz.
            $table->char('sha256', 64)->nullable();

            // Beklenen boyut; indirme tamamlanmadan kesildiyse ucuz eleme.
            $table->unsignedBigInteger('size_bytes')->nullable();

            $table->text('notes')->nullable();

            // `created_at` DEĞİL ayrı bir damga: bir sürüm kaydı düzeltilmek
            // için silinip yeniden girilebilir ve o zaman `created_at`
            // değişir. "Hangisi en yeni sürüm" sorusunun cevabı, satırın ne
            // zaman yazıldığından bağımsız olmalı.
            $table->timestamp('released_at');

            $table->timestamps();

            // Aynı sürüm iki kez yayınlanamaz: `--yayinla` yanlışlıkla iki
            // kez koşulduğunda ikinci satır sessizce birincinin önüne
            // geçerdi ve hangi `.deb`'in sahada olduğu belirsizleşirdi.
            $table->unique(['app_id', 'version']);

            // Denetleyicinin sorgusu bu: `where(app_id)->orderByDesc(released_at)`.
            $table->index(['app_id', 'released_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('veykemtu_app_releases');
    }
};
