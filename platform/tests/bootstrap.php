<?php

declare(strict_types=1);

/**
 * Test önyüklemesi — testlerin geliştirme veritabanına bağlanmasını
 * ENGELLEMEK için var.
 *
 * SORUN: `RefreshDatabase` ilk testte `migrate:fresh` koşar, yani bağlı
 * olduğu veritabanının BÜTÜN TABLOLARINI DÜŞÜRÜR. Yanlış veritabanına
 * bağlıysa geliştiricinin verisi gider. İki kez yaşandı: yerel `bld`
 * boşaldı.
 *
 * NEDEN phpunit.xml YETMEDİ: PHPUnit'in `<env>` girdisi, ortamda ZATEN
 * TANIMLI bir değişkeni ezmez ve konteyner `DB_DATABASE=bld` veriyor.
 * `force="true"` özniteliği de işe yaramadı — yapılandırma eski (deprecated)
 * şemaya göre doğrulanıyor ve öznitelik sessizce yok sayılıyor.
 *
 * ÇÖZÜM: değişkeni Laravel açılmadan önce, burada zorluyoruz. Bu dosya
 * `phpunit.xml`'deki `bootstrap` girdisidir ve her şeyden önce koşar.
 *
 * Ad SABİT DEĞİL, TÜRETİLİYOR: hangi veritabanı verilirse verilsin sonuna
 * `_test` ekleniyor. Sabit bir ad yazmak, CI'da başka bir veritabanı adı
 * kullanıldığında korumayı geçersiz kılardı; türetme her ortamda çalışır
 * ve sonuç asla geliştirme veritabanı olamaz.
 */

$gelistirme = getenv('DB_DATABASE') ?: 'bld';
$test = getenv('DB_DATABASE_TEST') ?: $gelistirme.'_test';

putenv('DB_DATABASE='.$test);
$_ENV['DB_DATABASE'] = $test;
$_SERVER['DB_DATABASE'] = $test;

/** @var \Composer\Autoload\ClassLoader $autoloader */
$autoloader = require __DIR__.'/../vendor/autoload.php';

/*
 * Eklenti ad alanlarını test ortamında kaydeder.
 *
 * SORUN: `extensions/veykemtu/*` composer'ın PSR-4 yapılandırmasında yok;
 * ad alanlarını TastyIgniter uygulama açılışında kaydediyor. Laravel'i açan
 * testler (`Tests\TestCase` türevleri) bundan etkilenmiyor ama **düz PHPUnit
 * testleri** açmıyor ve eklenti sınıfını hiç bulamıyor:
 *
 *   Class "Veykemtu\BridgeApi\Services\TranslationAudit" not found
 *
 * `TranslationOverrideTest` tam da bu yüzden kırmızıydı — veritabanı
 * gerektirmeyen, iki diziyi karşılaştıran bir test olduğu için bilinçli
 * olarak Laravel açmıyor. `composer dump-autoload` çözmüyor: sınıf haritaya
 * hiç girmiyor.
 *
 * Burada kaydetmek yalnızca testleri etkiliyor; üretim autoload'ı kirlenmiyor.
 *
 * Ad alanı DİZİN ADINDAN TÜRETİLMİYOR, eklentinin kendi `composer.json`'ından
 * okunuyor: dizin `bridgeapi`, ad alanı ise `BridgeApi`. Büyük harfleri
 * tahmin etmeye çalışmak (`ucfirst`) `Bridgeapi` üretiyor ve sınıf yine
 * bulunamıyor — sessizce yanlış çalışan bir kayıt, hiç kayıt olmamasından
 * daha kötü.
 */
foreach (glob(__DIR__.'/../extensions/*/*/composer.json') ?: [] as $tanim) {
    $paket = json_decode((string) file_get_contents($tanim), true);
    if (! is_array($paket)) {
        continue;
    }

    /** @var array<string, string> $psr4 */
    $psr4 = $paket['autoload']['psr-4'] ?? [];

    foreach ($psr4 as $adAlani => $yol) {
        $mutlak = dirname($tanim).'/'.trim($yol, '/');

        if (is_dir($mutlak)) {
            $autoloader->addPsr4($adAlani, $mutlak);
        }
    }
}
