<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Abonelik motoru tabloları — `docs/11-yol-haritasi.md` §7.5 (F2-09).
 *
 * İLKE: Abonelik bir sipariş DEĞİL, sipariş üreten KURALDIR. Bir gece işi her
 * gün ertesi günün siparişlerini üretip KDS'e normal sipariş olarak düşürür.
 * Üretilen sipariş kendi hayatını yaşar; abonelik değişse üretilmiş sipariş
 * değişmez.
 *
 * İDEMPOTENCY ŞEMADA: `veykemtu_subscription_runs` üzerindeki
 * `UNIQUE(subscription_id, delivery_point_id, service_date)`, üretim komutu
 * iki kez koşsa da aynı gün için ikinci siparişin doğmasını engeller —
 * güvence koddaki `if` değil, veritabanı kısıtıdır.
 *
 * `veykemtu_` öneki: tablolar bizim. Çekirdek `orders` tablosuna eklenen
 * `bld_subscription_id` ayrı migration'da (additive, `bld_` önekli).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('veykemtu_subscriptions', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->unsignedBigInteger('customer_id')->index();
            $table->unsignedBigInteger('location_id');
            // pending (talep, fiyatsız) | active | paused | cancelled
            $table->string('status', 16)->default('pending')->index();
            $table->date('start_date');
            $table->date('end_date')->nullable(); // null = süresiz
            $table->string('delivery_type', 16)->default('delivery'); // delivery | pickup
            $table->time('delivery_time_from')->nullable();
            $table->time('delivery_time_to')->nullable();
            // Hangi günler — ISO hafta günü listesi [1=Pzt .. 7=Paz], JSON.
            $table->json('service_days');
            // fixed_list (satır listesi) | daily_menu (günün menüsü — Faz sonrası)
            $table->string('menu_mode', 16)->default('fixed_list');
            $table->unsignedInteger('default_quantity')->default(1);
            // Porsiyon başı anlaşmalı fiyat (kuruş); pending'de null, admin belirler.
            $table->bigInteger('agreed_unit_price_kurus')->nullable();
            $table->string('payment_mode', 16)->default('account'); // account | prepaid_monthly
            $table->unsignedBigInteger('created_by')->nullable();
            $table->timestamps();
        });

        // Satır listesi: 20 porsiyonun 3'ü vejetaryen gibi varyantlar. Tek ürün
        // yerine LİSTE — diyet/alerjen ayrımı buradan çözülür.
        Schema::create('veykemtu_subscription_lines', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->unsignedBigInteger('subscription_id')->index();
            $table->unsignedBigInteger('menu_id')->nullable();
            $table->unsignedInteger('quantity')->default(1);
            $table->bigInteger('agreed_unit_price_kurus')->nullable();
            $table->string('label', 120)->nullable(); // "Vejetaryen" vb.
        });

        // Teslimat noktaları — adres defterinden, ÇOKLU olabilir. Nokta başına
        // bir sipariş üretilir.
        Schema::create('veykemtu_subscription_delivery_points', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->unsignedBigInteger('subscription_id')->index();
            $table->unsignedBigInteger('address_id');
            $table->unsignedInteger('quantity')->nullable(); // o noktaya porsiyon
            $table->string('note', 255)->nullable();
        });

        // Duraklatma — İPTAL DEĞİL. Aralık boyunca üretim durur, sonra aynı
        // fiyatla devam eder.
        Schema::create('veykemtu_subscription_pauses', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->unsignedBigInteger('subscription_id')->index();
            $table->date('start_date');
            $table->date('end_date');
            $table->string('reason', 255)->nullable();
        });

        // Tek-günlük istisna: "yarın 20 değil 12" ya da "yarın atla". Kural
        // değişimi DEĞİL. `UNIQUE(subscription_id, service_date)`.
        Schema::create('veykemtu_subscription_exceptions', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->unsignedBigInteger('subscription_id');
            $table->date('service_date');
            $table->boolean('skip')->default(false);
            $table->unsignedInteger('quantity_override')->nullable();
            $table->string('note', 255)->nullable();
            $table->unique(['subscription_id', 'service_date'], 'veykemtu_sub_exc_essiz');
        });

        // Resmî tatil / kapalı gün — kurala bağlanır. Bayram sabahı 400 porsiyon
        // pişmesin diye üretim bu günleri atlar. Global (aboneliğe özel değil).
        Schema::create('veykemtu_closed_days', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->date('closed_on')->unique('veykemtu_closed_day_essiz');
            $table->string('description', 160)->nullable();
        });

        // ÜRETİM DEFTERİ — idempotency garantisi. Bir (abonelik × nokta × gün)
        // en fazla bir sipariş. `delivery_point_id` 0 = tek/noktasız üretim
        // (null yerine 0: MySQL null'ları tekil sayar, idempotency bozulurdu).
        Schema::create('veykemtu_subscription_runs', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->unsignedBigInteger('subscription_id')->index();
            $table->unsignedBigInteger('delivery_point_id')->default(0);
            $table->date('service_date');
            $table->unsignedBigInteger('order_id')->nullable();
            $table->timestamp('created_at')->nullable();
            $table->unique(
                ['subscription_id', 'delivery_point_id', 'service_date'],
                'veykemtu_sub_run_essiz',
            );
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('veykemtu_subscription_runs');
        Schema::dropIfExists('veykemtu_closed_days');
        Schema::dropIfExists('veykemtu_subscription_exceptions');
        Schema::dropIfExists('veykemtu_subscription_pauses');
        Schema::dropIfExists('veykemtu_subscription_delivery_points');
        Schema::dropIfExists('veykemtu_subscription_lines');
        Schema::dropIfExists('veykemtu_subscriptions');
    }
};
