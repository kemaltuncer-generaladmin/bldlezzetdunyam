<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Veykemtu\BridgeApi\Console\AccountArchiveCommand;

/**
 * Cari verisini kaldırma göçünden ÖNCE dosyaya döker — ikinci emniyet kemeri.
 *
 * SIRA ÖNEMLİ: bu göç `..._000002_drop_account_tables`'tan önce koşar.
 * Dosya adındaki `000001` bunun tek garantisidir; ikisinin sırası
 * değiştirilirse arşiv boş çıkar ve düşürme sessizce veriyi yok eder.
 *
 * ASIL YOL BU DEĞİL. Operatör `veykemtu:cari-arsivle` komutunu ELLE koşup
 * ürettiği dizini dağıtımdan ÖNCE sunucudan indirmelidir
 * (`docs/RUNBOOK.md` §9). Sebebi: buradaki kopya sunucudaki Docker
 * biriminden dışarı çıkmaz ve veritabanı yedek rotasyonuna girmez —
 * birim silindiğinde arşiv de gider. Yani bu göç yalnızca "elle adım
 * atlandıysa veri en azından bir yerde duruyor" der.
 *
 * `down()` BİLEREK NO-OP: geri alma yalnızca şemayı ilgilendirir. Yazılan
 * arşiv dosyalarını silmek, geri almanın en olası sebebiyle (bir şeyler
 * ters gitti, veriye ihtiyaç var) taban tabana zıt olurdu.
 */
return new class extends Migration
{
    public function up(): void
    {
        AccountArchiveCommand::export();
    }

    public function down(): void
    {
        // Bilinçli no-op — gerekçe sınıf docblock'unda.
    }
};
