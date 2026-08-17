<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Abonelik sözleşmesi — iş kararı 9 (imzalı link + SMS OTP onayı).
 *
 * Sözleşme bir PDF değil, tek kullanımlık bir BAĞLANTIDIR: müşteri açar,
 * metni okur, telefonuna gelen kodu girer ve onaylar. Bu tablo o onayın
 * hukuki izidir.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * `body_html` DONMUŞ SAKLANIR — YALNIZ SÜRÜM ETİKETİ YETMEZ.
 *
 * Metnin kendisi yerine yalnız `version` saklansaydı, şablon sonradan
 * değiştiğinde müşterinin "imzaladığı" metin de SESSİZCE değişirdi: kayıtta
 * `v1` yazar, ekranda bugünkü metin çizilirdi ve hiçbir denetim bu farkı
 * göremezdi. "Neyi onayladı" sorusunun cevabı, sorulduğu güne değil
 * onaylandığı ana ait olmalıdır. Denetim izi ile hukuki risk arasındaki
 * fark tam olarak budur.
 *
 * Aynı gerekçe `terms_json` için de geçerli: fiyat, servis günleri ve
 * porsiyon sayısı abonelikte sonradan değişirse sözleşme değişmez.
 * `agreed_unit_price_kurus` ayrıca kendi kolonunda duruyor çünkü onay
 * anında aboneliğe geri kopyalanan tek sayı odur ve JSON'un içinden
 * sorgulanması gerekmesin.
 * ─────────────────────────────────────────────────────────────────────────
 *
 * HAM TOKEN SAKLANMAZ, YALNIZ `token_hash`.
 *
 * Bağlantının kendisi bir anahtardır: onu bilen sözleşmeyi okur ve (SMS
 * koduyla birlikte) onaylar. Açık saklansaydı bir yedek sızıntısı, o anda
 * geçerli her sözleşme bağlantısını kullanılabilir hâle getirirdi — üstelik
 * `docs/control/subscriptions.md` panele bile token döndürmüyor. Sunucunun
 * ham tokeni yeniden üretebilmesi imza sırrına bağlı (`Support\SignedLink`),
 * yani veritabanı tek başına yetmez.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * KULVAR NOTU — `docs/control/subscriptions.md` §Sözleşmeler bu tabloyu
 * "başka ajanın kulvarı" diye tarif ederken farklı kolon adları öneriyor
 * (`token`, `terms_snapshot`, `signed_at`, `signed_ip`, `created_by_actor`).
 * Buradaki adlar A3 kulvar tarifinden ve `docs/openapi.yaml`'dan geliyor;
 * durum sözlüğü de sözleşmedeki `ContractStatus` enum'ıdır
 * (`draft|sent|approved|expired|cancelled`). Panelin beklediği sözlüğe
 * çeviri `SubscriptionContract::controlStatus()` içinde tek yerde duruyor.
 * ─────────────────────────────────────────────────────────────────────────
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('veykemtu_subscription_contracts')) {
            return;
        }

        Schema::create('veykemtu_subscription_contracts', function (Blueprint $table): void {
            $table->bigIncrements('id');
            $table->unsignedBigInteger('subscription_id')->index();

            /*
             * Şablon sürümü. `docs/openapi.yaml` → `SubscriptionContract`
             * bunu TAM SAYI olarak yayınlıyor, kolon ise varchar: sürüm
             * ileride `1.1` gibi bir biçime kayarsa göç gerekmesin diye.
             * Yazılan değer sayısal bir dizedir ve uçta `(int)` ile
             * sunulur — `v1` yazılırsa yayınlanan değer 0'a düşer ve
             * sözleşmenin `minimum: 1` kuralı kırılır.
             */
            $table->string('version', 32);

            // Onay anında donmuş metin. `mediumText`: 64 KB'lik `text`
            // uzun bir kurumsal sözleşmeye dar gelebilir ve taşan metin
            // MySQL'de SESSİZCE kırpılır — hukuki bir belgede kabul
            // edilemez.
            $table->mediumText('body_html');

            $table->bigInteger('agreed_unit_price_kurus');

            // Peşin ödenen dönem uzunluğu (iş kuralı: 30 günlük peşin
            // ödeme). Sabit değil kolon, çünkü kurumsal pazarlıkta 15 ya da
            // 60 gün çıkabiliyor ve o gün sözleşme metniyle birlikte
            // donmalı.
            $table->unsignedInteger('term_days')->default(30);

            // İmzalandığı andaki koşulların tamamı (servis günleri, porsiyon,
            // başlangıç/bitiş, aylık tahmin). Aboneliğe SONRADAN yapılan
            // değişiklik buraya dokunmaz.
            $table->json('terms_json');

            // `docs/openapi.yaml` → `ContractStatus`.
            $table->string('status', 16)->default('draft')->index();

            /*
             * Ham tokenin SHA-256 özeti. UNIQUE: aynı bağlantı iki
             * sözleşmeye çözülemesin. `char(64)` çünkü özet sabit uzunlukta
             * ve `varchar` bir bayt uzunluk öneki taşırdı.
             */
            $table->char('token_hash', 64)->unique('veykemtu_sozlesme_token_essiz');

            $table->timestamp('sent_at')->nullable();

            // Normalleştirilmiş 10 hane (`OtpService::normalize`). Kodun
            // gideceği numara İSTEKTE ALINMAZ, burada saklanır: istemciden
            // alınsaydı bağlantıyı ele geçiren kodu kendi telefonuna
            // ısmarlardı.
            $table->string('sent_to_phone', 16)->nullable();

            $table->timestamp('otp_verified_at')->nullable();
            $table->timestamp('approved_at')->nullable();

            /*
             * ONAYIN DELİLİ. `approved_ip` ters vekil arkasında ancak
             * `TrustProxies` ayarlıysa gerçek istemciyi gösterir; bu depoda
             * `app/Http/Middleware/TrustProxies.php` özel ağ aralıklarıyla
             * ayarlı, yani değer Caddy'nin iç adresi değil müşterinin
             * adresidir. Ayar bir gün geri alınırsa bu kolon sessizce
             * değersizleşir — var olmayan bir delilden kötüsü, var sanılan
             * yanlış bir delildir.
             */
            $table->string('approved_ip', 45)->nullable();
            $table->string('approved_user_agent', 255)->nullable();

            /*
             * KULVAR TARİFİNE EK KOLON. `docs/openapi.yaml` →
             * `approveContract` gövdesinde `full_name` (opsiyonel) var ve
             * "onayın kimin elinden geçtiğini belgeye yazmak için alınır"
             * diyor. Sözleşmenin topladığını söylediği veriyi atmak, ucu
             * yalancı yapardı; metnin kendisi donmuş olduğu için beyan
             * gövdeye değil bu kolona yazılır.
             */
            $table->string('approved_full_name', 120)->nullable();

            // Bağlantının son geçerlilik anı. İmzanın İÇİNDE de var
            // (`SignedLink`), yani kolonu elle ileri almak bağlantıyı
            // uzatmaz — imza tutmaz.
            $table->timestamp('expires_at')->nullable();

            /*
             * KULVAR TARİFİNE EK İKİ KOLON — `docs/control/subscriptions.md`
             * §`POST /contracts/{contract}/cancel` bunları yanıtta
             * yayınlıyor. Panelin ucunu yazan ajanın aynı tabloya ikinci bir
             * göç açmasındansa bugün eklemek bedava.
             */
            $table->timestamp('cancelled_at')->nullable();
            $table->string('cancel_reason', 255)->nullable();

            // Sözleşmeyi kim hazırladı: Kontrol Merkezi kullanıcısı, panel
            // ya da konsol. Serbest metin — kaynaklar ayrı tablolarda
            // yaşıyor ve birini ötekinin kimliğiyle karıştırmak yanlış
            // kişiyi suçlar (`veykemtu_daily_menu_stock.updated_by` ile aynı
            // gerekçe).
            $table->string('created_by', 120)->nullable();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('veykemtu_subscription_contracts');
    }
};
