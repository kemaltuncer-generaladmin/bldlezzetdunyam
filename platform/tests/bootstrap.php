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

require __DIR__.'/../vendor/autoload.php';
