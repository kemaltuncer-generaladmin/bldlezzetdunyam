<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Kurumsal (B2B) müşteri alanları — `docs/00-genel-bakis.md` B2B kararı.
 *
 * İş modeli kurumsala dönüyor: bireysel self-servis satış kapanıyor, sipariş
 * yalnızca kurumsal müşterilerden alınacak. Bunun için kurum/birey ayrımını
 * `customers` tablosuna taşıyoruz.
 *
 * ADR-09 ADDITIVE: çekirdek `customers` tablosuna yalnızca `bld_` önekli,
 * nullable kolon ekliyoruz — hiçbir istemci (website, mobil, admin) bu
 * göçten etkilenmez. Ayrı bir tablo AÇMIYORUZ; müşteri kimliği tek satırda
 * kalmalı.
 *
 * GRANDFATHER: `bld_account_type` varsayılanı `corporate`. Bir kolon default
 * ile eklendiğinde MySQL mevcut satırları o değerle doldurur — yani bugüne
 * kadar kayıtlı herkes otomatik "kurumsal" sayılır ve sipariş vermeye devam
 * eder. Kapatma (bireysel engeli) ayrı ve kademeli yapılır; bu göç kimseyi
 * kırmaz.
 *
 * SÜTUN ADLARI `bld_` ÖNEKLİ: tablo bizim değil TastyIgniter'ın; öneksiz bir
 * ad çekirdek ileride aynısını eklerse göç çakışmasıyla patlar.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customers', function (Blueprint $table): void {
            // corporate | individual — sipariş kapısı bunu okur.
            $table->string('bld_account_type', 16)->default('corporate')->index();

            // Kurumsal kimlik alanları (ticari unvan, vergi, yetkili kişi).
            $table->string('bld_org_name', 160)->nullable();
            $table->string('bld_tax_office', 120)->nullable();
            $table->string('bld_tax_no', 32)->nullable();
            $table->string('bld_contact_person', 120)->nullable();
            $table->string('bld_org_phone', 32)->nullable();
        });

        // Açık grandfather: default zaten mevcut satırları doldurur, ama olası
        // NULL'ları da (bazı sürücülerde default sonradan uygulanmayabilir)
        // güvenceye alıyoruz. Idempotent: yalnızca boş olanları set eder.
        DB::table('customers')
            ->whereNull('bld_account_type')
            ->update(['bld_account_type' => 'corporate']);
    }

    public function down(): void
    {
        Schema::table('customers', function (Blueprint $table): void {
            $table->dropColumn([
                'bld_account_type',
                'bld_org_name',
                'bld_tax_office',
                'bld_tax_no',
                'bld_contact_person',
                'bld_org_phone',
            ]);
        });
    }
};
