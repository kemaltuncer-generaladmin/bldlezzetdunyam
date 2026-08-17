<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Müşterinin toplu SMS reddi — B1.
 *
 * ═════════════════════════════════════════════════════════════════════════
 * BU KOLON TEKNİK BİR AYAR DEĞİL, HUKUKİ BİR ZORUNLULUKTUR.
 *
 * Sipariş durum SMS'i (`order_confirmed`, `order_on_the_way` …) müşterinin
 * kendi verdiği siparişin BİLGİLENDİRMESİDİR ve izin gerektirmez. Günün
 * menüsü duyurusu (`dailymenu.announce`) ile toplu duyuru (`announcement`)
 * ise TİCARİ ELEKTRONİK İLETİDİR: İYS (İleti Yönetim Sistemi) kaydı ve
 * alıcının önceden onayı ister, her iletide çıkış hakkı sunmayı zorunlu
 * kılar (6563 sayılı kanun + KVKK). Bu, sunucunun çözebileceği bir sorun
 * değildir; onay ve İYS entegrasyonu iş tarafının imzasını bekler.
 *
 * BU YÜZDEN `dailymenu.announce` ŞABLONU İMZA GELENE KADAR **KAPALI**
 * KALIR. Kolon bugün açılıyor ki, izin akışı geldiğinde reddi tutacak yer
 * hazır olsun ve "kim istemiyordu" bilgisi geriye dönük toplanmak zorunda
 * kalmasın.
 * ═════════════════════════════════════════════════════════════════════════
 *
 * VARSAYILAN `false` = "REDDETMEDİ", "ONAYLADI" DEĞİL. İkisi aynı şey
 * değildir ve karıştırılması tam olarak yukarıdaki ihlali üretir. Onay
 * kaydı ayrı bir alandır ve bu göçün konusu değildir; duyuru komutu bugün
 * kimseye gitmediği için (şablon kapalı) aradaki boşluk kimseyi
 * etkilemiyor.
 *
 * SÜTUN ADI `bld_` ÖNEKLİ: tablo bizim değil TastyIgniter'ın; öneksiz bir
 * ad, çekirdek ileride aynısını eklerse göç çakışmasıyla patlar
 * (`2026_08_08_000001_add_corporate_columns_to_customers` ile aynı kural).
 *
 * İNDEKSLİ: duyuru kitlesi her koşumda bu kolonla eleniyor ve tablo müşteri
 * sayısıyla büyüyor.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasColumn('customers', 'bld_sms_opt_out')) {
            return;
        }

        Schema::table('customers', function (Blueprint $table): void {
            $table->boolean('bld_sms_opt_out')->default(false)->index('veykemtu_musteri_sms_ret');
        });
    }

    public function down(): void
    {
        if (!Schema::hasColumn('customers', 'bld_sms_opt_out')) {
            return;
        }

        Schema::table('customers', function (Blueprint $table): void {
            $table->dropIndex('veykemtu_musteri_sms_ret');
            $table->dropColumn('bld_sms_opt_out');
        });
    }
};
