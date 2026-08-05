<?php

declare(strict_types=1);

use Igniter\System\Models\Language;
use Illuminate\Database\Migrations\Migration;

/**
 * Panelin dilini Türkçeye çeker.
 *
 * NEDEN GÖÇ, ELLE BİR SATIR DEĞİL: yerel, `.env` içindeki `APP_LOCALE`
 * ile değil, veritabanındaki VARSAYILAN DİL KAYDIYLA belirleniyor
 * (`Igniter\System\ServiceProvider::loadLocalizationConfiguration`).
 * `APP_LOCALE=tr` yazılıydı ve hiçbir işe yaramıyordu; tabloda yalnızca
 * İngilizce kayıt olduğu için etkin yerel `en` kalıyordu. Bu satır elle
 * eklenseydi, veritabanı yeniden kurulduğunda panel sessizce İngilizceye
 * dönerdi.
 *
 * ÇEVRİLMEMİŞ ANAHTAR PANELİ BOZMAZ. Laravel `tr` altında bulamadığı
 * anahtarı `app.fallback_locale` (`en`) ile karşılar; sahada ölçüldü:
 * çevrilmemiş bir anahtar ham `igniter::admin.…` değil, İngilizce
 * karşılığını gösteriyor. Bu sayede çeviri parça parça ilerleyebilir.
 *
 * Çevirilerin kendisi `platform/lang/vendor/<ad-alanı>/tr/` altındadır.
 */
return new class extends Migration
{
    private const CODE = 'tr';

    public function up(): void
    {
        $language = Language::firstOrNew(['code' => self::CODE]);

        $language->fill([
            'name' => 'Türkçe',
            // `idiom` TastyIgniter'ın dil paketi eşleşmesinde kullandığı
            // İngilizce ad; `code` ile karıştırılmamalı.
            'idiom' => 'turkish',
            'status' => true,
            // Silinebilir olmalı: İngilizce `can_delete = 0` ile geliyor
            // çünkü çekirdeğin yedeği o. Türkçe kaydı yönetici panelden
            // kaldırabilmeli, yoksa geri dönüş yolu yalnızca göç geri
            // alma olurdu.
            'can_delete' => true,
        ])->save();

        $language->makeDefault();

        // `supported_languages` parametresi ayrı tutuluyor ve yerelleştirme
        // ara katmanı DESTEKLENMEYEN bir yerele geçmeyi reddediyor. Bu
        // çağrı olmadan varsayılan Türkçe olur ama istek yine `en` ile
        // servis edilirdi.
        Language::applySupportedLanguages();
    }

    public function down(): void
    {
        // Önce İngilizceyi varsayılana al: varsayılan kaydı silmek
        // `getDefault()` çağrısını null'a düşürür ve panel açılmaz.
        Language::where('code', 'en')->first()?->makeDefault();

        Language::where('code', self::CODE)->delete();

        Language::applySupportedLanguages();
    }
};
