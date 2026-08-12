<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Fiş basım denetimi revizyon bazlı oluyor — K-20.
 *
 * ESKİ HÂLİN HATASI: tekillik `(order_id, type)` idi ve `PrintJob::record()`
 * ilk-yazan-kazanır çalışıyordu. Sipariş düzenlenip fiş yeniden basıldığında
 * gelen `ack` **sessizce yutuluyordu**; sonucu `printed_at` alanında
 * görünüyordu: yeniden basılan fiş, yerini aldığı ESKİ fişin saatiyle
 * damgalanıyordu. Elinde iki kâğıt olan kurye hangisinin yeni olduğunu
 * kâğıttaki tek zaman damgasından anlayamıyordu — tam da "GÜNCEL FİŞ"
 * bandının çözmek için var olduğu sorun.
 *
 * Denetim sorusu değişmedi, daraldı: "ilk ne zaman basıldı" yerine "bu
 * revizyon ilk ne zaman basıldı".
 *
 * MySQL, SQLite'ın aksine tekilliği yerinde değiştirebiliyor; tablo yeniden
 * kurulmuyor, veri kopyalanmıyor. Mevcut satırlar `revision = 0` kovasına
 * düşüyor ve bu doğru: düzenlenmemiş siparişin revizyonu zaten sıfır.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('veykemtu_print_jobs', function (Blueprint $table): void {
            $table->unsignedInteger('revision')->default(0)->after('type');
        });

        // Sütun eklemeden AYRI bir çağrı: aynı `Schema::table` bloğunda
        // sütun ekleyip aynı sütun üzerinde indeks değiştirmek, sürücüye
        // göre farklı sıralanabiliyor.
        Schema::table('veykemtu_print_jobs', function (Blueprint $table): void {
            $table->dropUnique('veykemtu_print_jobs_order_id_type_unique');
            $table->unique(['order_id', 'type', 'revision']);
        });
    }

    public function down(): void
    {
        /*
         * GERİ ALIRKEN ÖNCE FAZLA SATIRLAR SİLİNİYOR. Tekillik daralıyor:
         * aynı `(order_id, type)` için birden çok revizyon satırı varsa
         * `unique(['order_id','type'])` kurulamaz ve göç yarıda kalırdı.
         * En eski satır korunuyor — eski şemanın anlamı da "ilk basım" idi.
         */
        DB::statement(
            'DELETE p FROM veykemtu_print_jobs p
             JOIN veykemtu_print_jobs keep
               ON keep.order_id = p.order_id
              AND keep.type = p.type
              AND keep.id < p.id',
        );

        Schema::table('veykemtu_print_jobs', function (Blueprint $table): void {
            $table->dropUnique('veykemtu_print_jobs_order_id_type_revision_unique');
            $table->unique(['order_id', 'type']);
        });

        Schema::table('veykemtu_print_jobs', function (Blueprint $table): void {
            $table->dropColumn('revision');
        });
    }
};
