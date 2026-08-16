<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Komut teslimatına sayaç, son kullanma ve yineleme koruması — `K-23`.
 *
 * SAHADAKİ BELİRTİ: mutfak ekranı her on dakikada bir test fişi basıyordu.
 * `KitchenCommand::pendingFor()` sonucu gelmemiş her komutu on dakikada bir
 * yeniden teslim ediyor, `takeCommands()` de `delivered_at`'i yeniden
 * damgalayıp saati sıfırlıyordu: kusursuz ve kalıcı bir on dakikalık
 * döngü. Kaç kez denendiğini sayan bir sütun ve komutun ne zaman
 * anlamsızlaştığını söyleyen bir damga olmadan bu döngünün duracağı bir
 * yer yoktu.
 *
 * İKİ SAYAÇ DA GEREKLİ, biri diğerini kapsamıyor:
 *
 * - `attempts` ULAŞILABİLEN ama komutu sürekli düşüren kasayı sınırlar.
 *   Kasa her dakika sağlık bildiriyor, komutu alıyor, çalıştıramıyor ve
 *   sonucu bildiremiyor — `expires_at` tek başına burada da otuz dakika
 *   boyunca üç yerine altı kez fiş bastırırdı.
 * - `expires_at` ULAŞILAMAYAN kasayı sınırlar. Hafta sonu kapalı kalan
 *   bir kasa pazartesi açıldığında `attempts` hâlâ sıfırdır ve cuma
 *   akşamından kalma bir test fişi basılırdı.
 *
 * `dedupe_key` üçüncü kapı: aynı düğmeye iki kez basmak iki bağımsız
 * döngü açıyordu. Anahtar YALNIZ idempotent komutlarda dolu; `reprint`
 * bilerek dışarıda (aynı fişi ikinci kez basmak o düğmenin tek varlık
 * sebebi). `NULL`'lar tekil dizinde ayrı sayıldığı için anahtarsız
 * satırlar birbirini engellemez.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('veykemtu_kitchen_commands', function (Blueprint $table): void {
            // Kaç kez teslim edildi? `takeCommands()` teslimi damgalayan
            // AYNI ifadede artırıyor; iki ayrı sorgu, arada düşen bir
            // isteğin sayacı atlamasına izin verirdi.
            $table->unsignedTinyInteger('attempts')->default(0);

            // Bu andan sonra komut anlamını yitirir ve hiç teslim edilmez.
            // Nullable: eski satırların ve sonsuza kadar geçerli olması
            // istenen bir komutun (bugün yok) damgası boş kalır.
            $table->timestamp('expires_at')->nullable();

            $table->string('dedupe_key', 64)->nullable();

            // ANAHTAR CİHAZ BAŞINA TEKİL. Kapsam cihaz olmalı: iki kasaya
            // aynı anda test fişi göndermek meşru bir istek ve anahtar
            // yalnız komut adı ile yükten türetildiği için iki kasada
            // aynı çıkar.
            $table->unique(['device_id', 'dedupe_key'], 'kitchen_commands_dedupe_uq');

            // `pendingFor()` sorgusunun yeni hâli. Eski
            // `(device_id, delivered_at)` dizini duruyor: `delivered_at`
            // koşulu sorguda hâlâ var.
            $table->index(
                ['device_id', 'executed_at', 'expires_at'],
                'kitchen_commands_pending_idx',
            );
        });

        $this->closeStuckCommands();
    }

    public function down(): void
    {
        Schema::table('veykemtu_kitchen_commands', function (Blueprint $table): void {
            // Dizinler ÖNCE düşürülüyor: sütunu taşıyan bir dizin varken
            // `dropColumn` çağırmak MySQL'de sürüme göre değişen davranış
            // gösteriyor ve geri alma sessizce yarım kalabilirdi.
            $table->dropUnique('kitchen_commands_dedupe_uq');
            $table->dropIndex('kitchen_commands_pending_idx');
            $table->dropColumn(['attempts', 'expires_at', 'dedupe_key']);
        });
    }

    /**
     * Şu anda DÖNGÜDE OLAN satırları kesin sonuca bağlar.
     *
     * Yeni sütunlar sahadaki bir satırı geriye dönük kurtarmıyor: teslim
     * edilmiş ama onaylanmamış komutların `attempts` değeri sıfır
     * başlıyor, yani göçten sonra üç kez daha fiş basarlardı. Yönetici
     * bu görevden bekleneni "artık basmıyor" diye ölçecek.
     *
     * YALNIZ EN AZ BİR KEZ TESLİM EDİLMİŞLER kapatılıyor. Hiç teslim
     * edilmemiş bir komut kasaya varma şansını hiç kullanmadı; onu
     * kapatmak yöneticinin dakikalar önce bastığı düğmeyi sessizce
     * yutmak olurdu. O satırlar da `attempts` ile sınırlı.
     */
    private function closeStuckCommands(): void
    {
        $now = Carbon::now();

        DB::table('veykemtu_kitchen_commands')
            ->whereNull('executed_at')
            ->whereNotNull('delivered_at')
            ->update([
                'executed_at' => $now,
                'succeeded' => false,
                'result' => 'Kasaya ulaşmadı (göç ile kapatıldı)',
                'updated_at' => $now,
            ]);
    }
};
