<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Kayıtlı adres desteği — `docs/03-api-sozlesmesi.md` §Adresler.
 *
 * TastyIgniter'ın `addresses` tablosu bugün YALNIZCA sipariş anlık
 * görüntüsü olarak kullanılıyor: her sipariş yeni bir satır açıyor.
 * Müşterinin "Ev / Ofis" diye seçebileceği bir adres defteri yok ve
 * her siparişte adresi yeniden yazması gerekiyor.
 *
 * ÜÇ SÜTUN EKLİYORUZ, TABLO AÇMIYORUZ. Ayrı bir tablo, siparişin
 * `address_id` yabancı anahtarını ikiye bölerdi.
 *
 * SÜTUN ADLARI `bld_` ÖNEKLİ. Bu tablo bizim değil, TastyIgniter'ın.
 * Öneksiz bir `label` sütunu, çekirdek ileride aynı adı eklerse göç
 * çakışmasıyla patlar ve sebebi hiç anlaşılmaz. Önek çirkin ama sahibi
 * belli.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('addresses', function (Blueprint $table): void {
            // "Ev", "Ofis", "Şantiye" — müşterinin verdiği ad.
            $table->string('bld_label', 64)->nullable()->after('address_id');

            // Adres defterinde görünür mü?
            //
            // Sipariş anlık görüntüleri `false` kalır. Bu ayrım olmadan
            // adres listesi, müşterinin verdiği her siparişin kopyasıyla
            // dolardı — 40 sipariş veren müşteri 40 satır görürdü.
            $table->boolean('bld_is_saved')->default(false)->index();

            $table->boolean('bld_is_default')->default(false);
        });
    }

    public function down(): void
    {
        Schema::table('addresses', function (Blueprint $table): void {
            $table->dropColumn(['bld_label', 'bld_is_saved', 'bld_is_default']);
        });
    }
};
