<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `veykemtu_subscription_payments` → `due_date` + `note` — I2.
 *
 * ═════════════════════════════════════════════════════════════════════════
 * SÖZLEŞMEDE VAR, TABLODA YOKTU — VE YOKLUK HER YAZMADA UYARI ÜRETİYORDU.
 *
 * `docs/control/subscriptions.md` borç kaydında `due_date` ve `note`
 * alanlarını yayınlıyor; Kontrol Merkezi ekranı ikisini de ZORUNLU tutuyor
 * ve her borç açılışında gönderiyor. Sunucu ise ikisini de saklayamadığı
 * için `due_date_derived` / `note_not_stored` uyarısı döndürüyordu. Yani
 * yönetici her seferinde doldurduğu iki alanın hiçbir yere yazılmadığını
 * söyleyen bir uyarı alıyor (ya da — panel uyarıyı göstermediği için —
 * hiç almıyor) ve girdiği notu boşuna yazıyordu.
 * ═════════════════════════════════════════════════════════════════════════
 *
 * ─────────────────────────────────────────────────────────────────────────
 * `due_date` NEDEN AYRI BİR KOLON: TÜRETİLMİŞ HÂLİ YETMİYOR.
 *
 * Bugüne kadar son ödeme günü `period_start` idi ve gerekçesi de sağlamdı:
 * model 30 günlük PEŞİN tahsilat, ikisi arasındaki bir fark "ödenmemiş bir
 * dönem üretim yapıyor" penceresi demekti. Ama kurumsal abonede o pencere
 * GERÇEK: sözleşmeli müşteri ayın 15'inde ödüyor ve dönem 1'inde başlıyor.
 * Türetilmiş bir tarih o müşteriyi her dönem başında "gecikmiş" gösterir,
 * gecikme uyarısı gönderir ve tahsilat ekibini olmayan bir borcun peşine
 * takardı.
 *
 * VARSAYILAN DAVRANIŞ DEĞİŞMİYOR: alan gönderilmezse `period_start`
 * yazılıyor, yani bugünkü kural. Değişen tek şey, farklı bir günün artık
 * TEMSİL EDİLEBİLİR olması.
 * ─────────────────────────────────────────────────────────────────────────
 *
 * `note` 255 KARAKTER ve serbest metin: "Ağustos ayı sözleşme gereği 15
 * gün ertelendi" gibi bir cümlenin yaşayacağı yer. Denetim izinin gerekçesi
 * bunun yerine geçmiyor — o, İŞLEMİ yapan kişinin gerekçesi; bu ise BORCUN
 * kendisine iliştirilen not ve ödeme ekranında görünmeli.
 *
 * GERİYE DÖNÜK DOLDURMA VAR ve gerekli: `due_date` `NULL` kalsaydı eski
 * satırlarda "son ödeme günü yok" görünürdü ve gecikme hesabı (`overdue`)
 * onları hiçbir zaman kırmızıya çevirmezdi. Eski kural neyse o yazılıyor.
 */
return new class extends Migration
{
    private const string TABLE = 'veykemtu_subscription_payments';

    public function up(): void
    {
        if (!Schema::hasTable(self::TABLE)) {
            return;
        }

        Schema::table(self::TABLE, function (Blueprint $table): void {
            if (!Schema::hasColumn(self::TABLE, 'due_date')) {
                // NULLABLE doğuyor ki aşağıdaki geriye dönük doldurma
                // yapılabilsin; doldurmadan sonra da nullable kalıyor çünkü
                // "son ödeme günü belirtilmedi" ile "dönem başı" ayrımını
                // korumanın bir bedeli yok ve okuma yolu `?? period_start`
                // ile zaten tek bir cevaba iniyor.
                $table->date('due_date')->nullable()->after('period_end');
            }

            if (!Schema::hasColumn(self::TABLE, 'note')) {
                $table->string('note', 255)->nullable()->after('amount_kurus');
            }
        });

        $this->backfillDueDates();
    }

    public function down(): void
    {
        if (!Schema::hasTable(self::TABLE)) {
            return;
        }

        Schema::table(self::TABLE, function (Blueprint $table): void {
            foreach (['due_date', 'note'] as $column) {
                if (Schema::hasColumn(self::TABLE, $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }

    /**
     * Eski satırların son ödeme günü = dönemin ilk günü.
     *
     * O günün kuralı buydu (`SubscriptionController::paymentRow()`); başka
     * bir değer yazmak, geçmişteki gecikmeleri geriye dönük olarak
     * değiştirmek olurdu.
     */
    private function backfillDueDates(): void
    {
        if (!Schema::hasColumn(self::TABLE, 'due_date')) {
            return;
        }

        DB::table(self::TABLE)
            ->whereNull('due_date')
            ->update(['due_date' => DB::raw('period_start')]);
    }
};
