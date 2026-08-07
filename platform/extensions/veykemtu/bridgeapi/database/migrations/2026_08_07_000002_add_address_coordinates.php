<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Adrese harita koordinatı — `docs/03-api-sozlesmesi.md` §Adresler.
 *
 * Serbest metin adres kuryeyi kapıya götürmüyor: "Atatürk Cad. No:12" aynı
 * ilçede birden fazla yere denk gelebiliyor ve sokak tabelası olmayan
 * şantiye/site teslimatlarında adres tek başına yetersiz kalıyor. Müşteri
 * haritadan iğneyi bıraktığında kuryenin gideceği nokta belirsizlik
 * bırakmıyor.
 *
 * ## Neden NULLABLE
 *
 * Koordinat ZORUNLU DEĞİL ve olmamalı. Bugüne kadar kaydedilmiş adreslerin
 * hiçbirinde koordinat yok; zorunlu yapmak onları geçersiz kılardı. Ayrıca
 * konum izni vermeyen ya da haritayı kullanmak istemeyen müşteri adresi elle
 * yazıp sipariş verebilmeli — harita bir kolaylık, kapı değil.
 *
 * ## Neden DECIMAL, FLOAT değil
 *
 * `DECIMAL(10,7)` ~1 cm çözünürlük verir ve kayıpsızdır. `FLOAT` yuvarlama
 * hatası taşır: aynı iğne kaydedilip okunduğunda birkaç metre kayabilir ve
 * "adresi düzelttim ama harita eski yeri gösteriyor" şikâyetine dönüşür.
 * Enlem en fazla ±90, boylam ±180 olduğu için 10 hanenin 3'ü tam kısma
 * yetiyor, kalan 7'si ondalık.
 *
 * Sütun adları `bld_` önekli: tablo TastyIgniter'ın, sahibi belli olsun
 * (2026_08_05_000001 ile aynı gerekçe).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('addresses', function (Blueprint $table): void {
            $table->decimal('bld_latitude', 10, 7)->nullable()->after('bld_is_default');
            $table->decimal('bld_longitude', 10, 7)->nullable()->after('bld_latitude');
        });
    }

    public function down(): void
    {
        Schema::table('addresses', function (Blueprint $table): void {
            $table->dropColumn(['bld_latitude', 'bld_longitude']);
        });
    }
};
