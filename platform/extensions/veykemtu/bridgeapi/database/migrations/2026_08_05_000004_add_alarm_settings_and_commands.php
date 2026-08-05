<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Alarm ayarları ve komut kanalı — `docs/05-mutfakapp.md` §8.
 *
 * Yöneticinin isteği: "uyarı ne zaman çalacaktan uyarı susturma ayarına
 * kadar en ince detayına kadar admin panel yönetsin, gerekirse uygulamaya
 * komut göndersin, uygulama onu uygulasın."
 *
 * KOMUTLAR AYRI TABLODA, ayar sütunu değil. Bir ayar "şu anda böyle
 * olsun" der ve kalıcıdır; bir komut "şunu bir kez yap" der ve tüketilir.
 * İkisini aynı yere koymak, "test fişi bas" ayarının sonsuza kadar açık
 * kalıp her yoklamada fiş bastırmasıyla biterdi.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('veykemtu_kitchen_devices', function (Blueprint $table): void {
            // Sağlık bildiriminin sıklığı. Komutlar bu yanıtla taşındığı
            // için aynı zamanda "komut ne kadar sürede varır" demek.
            $table->unsignedSmallInteger('health_seconds')->nullable();

            // Bağlantı uyarısının tekrar aralığı.
            $table->unsignedSmallInteger('connection_alarm_seconds')->nullable();

            // Mutfak, yeni sipariş alarmını susturabilsin mi?
            //
            // Bağlantı uyarısı zaten susturulamaz (yönetici kararı); bu
            // bayrak yeni sipariş alarmı içindir. Kapatılırsa alarmı
            // durdurmanın tek yolu siparişi onaylamaktır.
            $table->boolean('alarm_silenceable')->nullable();
        });

        Schema::create('veykemtu_kitchen_commands', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('device_id')->constrained('veykemtu_kitchen_devices')->cascadeOnDelete();
            $table->string('command', 32);
            $table->json('payload')->nullable();

            // Üç ayrı damga, üç ayrı soru: gönderildi mi, kasaya ulaştı mı,
            // çalıştı mı? Tek bir "durum" sütunu, "kasa aldı ama
            // çalıştıramadı" hâlini anlatamazdı.
            $table->timestamp('delivered_at')->nullable();
            $table->timestamp('executed_at')->nullable();
            $table->boolean('succeeded')->nullable();
            $table->string('result', 255)->nullable();
            $table->timestamps();

            // Bekleyen komutları çekmenin sorgusu bu.
            $table->index(['device_id', 'delivered_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('veykemtu_kitchen_commands');

        Schema::table('veykemtu_kitchen_devices', function (Blueprint $table): void {
            $table->dropColumn([
                'health_seconds',
                'connection_alarm_seconds',
                'alarm_silenceable',
            ]);
        });
    }
};
