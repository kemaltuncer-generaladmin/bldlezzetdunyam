<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `veykemtu_subscriptions.status` 16 → 32 karakter.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * SÖZLÜKTE OLAN AMA KOLONA SIĞMAYAN BİR DURUM VAR.
 *
 * `docs/03-api-sozlesmesi.md` §15.1 abonelik sözlüğüne `awaiting_contract`
 * ve `awaiting_payment` ekledi. İkincisi tam 16 karakter, yani bugün de
 * yazılabiliyor; BİRİNCİSİ 17 KARAKTER ve `varchar(16)` kolona hiç
 * girmiyor. MySQL katı kipte "Data too long" ile reddeder, gevşek kipte
 * sessizce `awaiting_contrac` yazar — ikincisi daha kötü, çünkü durum
 * karşılaştırmaları hiçbir zaman tutmaz ve abonelik yaşam döngüsünde
 * sebebi görünmeyen bir sapma bırakır.
 *
 * Bugün akış ölmüyor: `ContractService` sınıf yorumunda anlattığı gibi
 * yedek yola (`awaiting_payment`) düşüyor. Ama sözleşmedeki durum, kolon
 * genişletilmeden HİÇ KULLANILAMAZ — yazan ilk kod satırı sahada patlardı.
 * ─────────────────────────────────────────────────────────────────────────
 *
 * NEDEN 32, NEDEN ENUM DEĞİL: sözlük ekleniyor (`docs/03` §1.4 — yalnız
 * ekleme). Enum her yeni durumda göç bekletirdi. 32 karakter, bugünkü en
 * uzun değerin yaklaşık iki katı; bir sonraki durum için ikinci bir göç
 * yazmamak adına seçildi ve `varchar` yalnız yazılan kadar yer kaplıyor.
 *
 * `status` üzerindeki indeks ELLENMİYOR: `MODIFY COLUMN` indeksi düşürmez,
 * yeniden oluşturmak da gereksiz bir yeniden yazma olurdu.
 *
 * VARSAYILAN AÇIKÇA TEKRARLANIYOR (`pending`). Laravel'in yerel `change()`
 * uygulaması sütunu BAŞTAN tanımlar; yazılmayan her değiştirici (varsayılan,
 * null'lanabilirlik, işaretsizlik) sessizce DÜŞER. Varsayılan kaybolsaydı
 * durumu belirtmeden açılan her abonelik talebi boş durumla doğardı.
 *
 * KOLONDAKİ VERİ ETKİLENMEZ: daraltma değil genişletme yapılıyor, her eski
 * değer yeni genişliğe olduğu gibi sığıyor.
 */
return new class extends Migration
{
    private const string TABLE = 'veykemtu_subscriptions';

    private const string DEFAULT_STATUS = 'pending';

    /** Kolona bugün sığmayan, yarın sığacak olan değer. */
    private const string AWAITING_CONTRACT = 'awaiting_contract';

    public function up(): void
    {
        Schema::table(self::TABLE, function (Blueprint $table): void {
            $table->string('status', 32)->default(self::DEFAULT_STATUS)->change();
        });
    }

    public function down(): void
    {
        /*
         * GERİ ALMADAN ÖNCE 17 HANELİ SATIRLAR TAŞINIR.
         *
         * Daraltma bu kez veri kaybettirebilir: kolonda `awaiting_contract`
         * duruyorsa MySQL katı kipte göçü ortasında düşürür, gevşek kipte
         * değeri `awaiting_contrac` diye keser ve o abonelik hiçbir duruma
         * uymayan bir kayıt hâline gelir. Geri alma, şemayı ÖNCEKİ hâline
         * döndürmek demektir; o hâlde bu değer hiç yoktu ve karşılığı
         * `pending`'dir — abonelik henüz fiyatlanmamış bir taleptir.
         *
         * `awaiting_payment` 16 karakter, yani daraltmadan sağ çıkıyor;
         * dokunulmuyor.
         */
        DB::table(self::TABLE)
            ->where('status', self::AWAITING_CONTRACT)
            ->update(['status' => self::DEFAULT_STATUS]);

        Schema::table(self::TABLE, function (Blueprint $table): void {
            $table->string('status', 16)->default(self::DEFAULT_STATUS)->change();
        });
    }
};
