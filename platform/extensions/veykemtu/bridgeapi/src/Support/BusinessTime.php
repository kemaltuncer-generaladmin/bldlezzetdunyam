<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Support;

use Illuminate\Support\Carbon;

/**
 * İşletme saati — Europe/Istanbul.
 *
 * İKİ AYRI KAVRAM VARDIR, KARIŞTIRILMAMALI:
 *
 * - **Depolama zamanı: UTC.** Veritabanındaki her zaman damgası UTC'dir,
 *   API'nin döndüğü her zaman damgası UTC'dir (`docs/03` §1.3).
 * - **İşletme günü: Europe/Istanbul.** "Bugünün siparişleri", "kesim saati
 *   16:00", "fişteki tarih" — bunların hepsi Türkiye duvar saatine göredir.
 *
 * `config('app.timezone')` bu iş için KULLANILMAZ: o depolama zaman dilimidir
 * (UTC) ve kurulumda yanlışlıkla başka bir değere kayarsa iş kuralları
 * sessizce bozulur. Gece 00:00–03:00 arasında "bugün" iki zaman diliminde
 * farklı gündür; UTC'ye göre filtrelenen bir mutfak ekranı o saatlerde
 * siparişleri kaybeder.
 *
 * Türkiye 2016'dan beri kalıcı UTC+3'tedir, yaz saati yoktur — ama yine de
 * IANA adı kullanılıyor: karar değişirse tek satır yeter.
 */
final class BusinessTime
{
    public const string ZONE = 'Europe/Istanbul';

    private function __construct() {}

    /** Şu anın Türkiye duvar saati. */
    public static function now(): Carbon
    {
        return Carbon::now(self::ZONE);
    }

    /** Herhangi bir anı Türkiye duvar saatine taşır. */
    public static function at(Carbon $moment): Carbon
    {
        return $moment->copy()->setTimezone(self::ZONE);
    }

    /** İşletme günü olarak bugünün tarihi (`Y-m-d`). */
    public static function today(): string
    {
        return self::now()->toDateString();
    }

    /**
     * İşletme gününün başlangıcı, veritabanıyla karşılaştırılmaya hazır.
     *
     * "Bugünkü siparişler" sorgusu bunu kullanır. UTC gece yarısını
     * kullanmak, 00:00–03:00 arasında verilen siparişleri "dün" sayardı —
     * catering'de gece siparişi olağan ve vardiya raporu yanlış çıkardı.
     */
    public static function startOfBusinessDay(): Carbon
    {
        return self::forStorage(self::now()->startOfDay());
    }

    /**
     * Dışarıdan gelen (UTC) bir anı **veritabanına yazılmaya hazır** hale getirir.
     *
     * NEDEN GEREKLİ — sessiz ve pahalı bir tuzak:
     *
     * TastyIgniter, PHP'nin varsayılan zaman dilimini `timezone` ayarından
     * (Europe/Istanbul) belirliyor. Eloquent bir `datetime` alanını **okurken**
     * bu varsayılanı kullanıyor, ama **yazarken** Carbon nesnesinin kendi
     * zaman dilimini kullanıyor. Sonuç: `Carbon::parse("...11:30:00Z")` UTC
     * olarak kaydediliyor, geri okunurken İstanbul sanılıyor ve zaman damgası
     * 3 saat kayıyor.
     *
     * Bu, `printed_at` alanında yakalandı: fiş 11:30'da basıldı, denetim
     * kaydı 08:30 gösterdi. Aynı hata `updated_at > since` karşılaştırmasını
     * da bozuyordu — KDS'in artımlı polling'i her seferinde tüm siparişleri
     * getiriyordu.
     *
     * Kural: veritabanına yazılacak veya veritabanı değeriyle karşılaştırılacak
     * her Carbon bu metottan geçer.
     */
    public static function forStorage(Carbon $moment): Carbon
    {
        return $moment->copy()->setTimezone(date_default_timezone_get());
    }
}
