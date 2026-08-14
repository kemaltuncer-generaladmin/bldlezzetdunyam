<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Adresin parçalanmış hâli — B-21, `docs/openapi.yaml` §Address / §SavedAddress.
 *
 * Bugün adres tek bir serbest metin (`address_1`). Kurye onu OKUYOR ama
 * sistem hiçbir parçasını BİLMİYOR: "Feritpaşa Mah. Kültür Sk. No:12 Kat:3"
 * ile "kultur sk 12/3 feritpasa" veritabanında birbirine hiç benzemeyen iki
 * satır. Bunun iki somut bedeli var — aynı binaya giden iki sipariş
 * eşleştirilemiyor ve daire/kat bilgisi cümlenin ortasında kaybolduğu için
 * kurye kapıda telefon açıyor.
 *
 * ## Neden ESKİ SATIRLAR AYRIŞTIRILMIYOR
 *
 * Geriye dönük bir ayrıştırma (regex ile "No:" arayıp bölmek) satırların
 * çoğunda çalışır, azında çalışmaz — ve çalışmadığı her satırda kuryeyi
 * yanlış kapıya götürür. Yanlış bir mahalle adı, boş bir mahalle alanından
 * çok daha pahalıdır. Eski kayıtlarda bu sütunlar `null` kalır ve öyle
 * kalmalıdır; `address_1` onların tek doğru kaynağı olmayı sürdürür.
 *
 * ## Neden HEPSİ NULLABLE ve neden hepsi METİN
 *
 * Beş alanın hepsi isteğe bağlı: adresi elle tek satır yazan müşteri de
 * sipariş verebilmeli (öneri bir kolaylık, kapı değil — bkz.
 * `Services\Geocoding`).
 *
 * `building_no` ve `door_no` SAYI DEĞİL: sahada `12/A`, `3-5`, `B blok`
 * gibi değerler yaygın. `floor` da metin: `Zemin`, `Bodrum`, `Asma kat`
 * geçerli cevaplar ve tamsayı sütunu bunları sessizce `0`'a çevirirdi.
 *
 * Uzunluklar sözleşmedeki `maxLength` değerlerinin birebir aynısı; sütun
 * daha darsa doğrulamayı geçen bir değer veritabanında kırpılırdı.
 *
 * Sütun adları `bld_` önekli — tablo TastyIgniter'ın, sahibi belli olsun
 * (2026_08_05_000001 ve 2026_08_07_000002 ile aynı gerekçe).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('addresses', function (Blueprint $table): void {
            $table->string('bld_neighbourhood', 96)->nullable()->after('bld_longitude');
            $table->string('bld_street', 128)->nullable()->after('bld_neighbourhood');
            $table->string('bld_building_no', 24)->nullable()->after('bld_street');
            $table->string('bld_floor', 16)->nullable()->after('bld_building_no');
            $table->string('bld_door_no', 16)->nullable()->after('bld_floor');
        });
    }

    public function down(): void
    {
        Schema::table('addresses', function (Blueprint $table): void {
            $table->dropColumn([
                'bld_neighbourhood',
                'bld_street',
                'bld_building_no',
                'bld_floor',
                'bld_door_no',
            ]);
        });
    }
};
